//
//  PlaceSearchService.swift
//  OurLog
//
//  장소 검색.
//
//  우선순위: 카카오 로컬(KakaoKeys.plist) → 네이버 지역검색(NaverKeys.plist) → Apple 지도(MapKit)
//

import Foundation
import MapKit

/// 검색 결과 한 페이지. next 가 있으면 "더 보기"로 이어서 받을 수 있다.
nonisolated struct PlaceSearchPage: Sendable {
    var results: [PlaceSearchResult]
    var next: PlaceSearchCursor?
    /// 어디를 기준으로 찾았는지 (목록 위에 보여준다). nil 이면 표시하지 않는다.
    var scope: String?
}

/// 다음 페이지를 받기 위한 정보
nonisolated struct PlaceSearchCursor: Sendable {
    let query: String
    let center: CLLocationCoordinate2D?
    let radius: Int?
    let page: Int
}

@MainActor
protocol PlaceSearchService {
    func search(query: String, near center: CLLocationCoordinate2D?) async throws -> PlaceSearchPage
    func more(_ cursor: PlaceSearchCursor) async throws -> PlaceSearchPage
}

extension PlaceSearchService {
    /// 페이지가 없는 검색(네이버·Apple)은 더 받을 게 없다
    func more(_ cursor: PlaceSearchCursor) async throws -> PlaceSearchPage {
        PlaceSearchPage(results: [], next: nil)
    }
}

// MARK: - 카카오

/// 카카오 로컬 키워드 검색. 지도 가운데 기준 20km 안에서 정확도순으로 찾고,
/// 없으면 전국에서 다시 찾는다. 한 페이지 15개, 최대 3페이지(45개).
@MainActor
final class KakaoPlaceSearchService: PlaceSearchService {
    private static let nearbyRadius = 20_000   // 카카오가 허용하는 최대 반경(m)
    private static let pageSize = 15

    private struct Response: Decodable {
        struct Meta: Decodable {
            let is_end: Bool
        }
        struct Document: Decodable {
            let id: String
            let place_name: String
            let category_name: String
            let address_name: String
            let road_address_name: String
            let x: String
            let y: String
            let place_url: String
            let distance: String?
        }
        let meta: Meta
        let documents: [Document]
    }

    func search(query: String, near center: CLLocationCoordinate2D?) async throws -> PlaceSearchPage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return PlaceSearchPage(results: [], next: nil) }

        if center != nil {
            let nearby = try await fetch(PlaceSearchCursor(query: trimmed, center: center, radius: Self.nearbyRadius, page: 1))
            if !nearby.results.isEmpty { return nearby }
        }
        // 주변에 없으면 전국에서 (다른 동네 가게 이름을 칠 때). 거리는 계속 지도 가운데 기준으로 보여준다.
        return try await fetch(PlaceSearchCursor(query: trimmed, center: center, radius: nil, page: 1))
    }

    func more(_ cursor: PlaceSearchCursor) async throws -> PlaceSearchPage {
        try await fetch(cursor)
    }

    private func fetch(_ cursor: PlaceSearchCursor) async throws -> PlaceSearchPage {
        guard let key = KakaoKeys.restApiKey else { return PlaceSearchPage(results: [], next: nil) }

        var items = [
            URLQueryItem(name: "query", value: cursor.query),
            URLQueryItem(name: "page", value: String(cursor.page)),
            URLQueryItem(name: "size", value: String(Self.pageSize)),
            URLQueryItem(name: "sort", value: "accuracy"),
        ]
        if let center = cursor.center {
            items.append(URLQueryItem(name: "x", value: String(center.longitude)))
            items.append(URLQueryItem(name: "y", value: String(center.latitude)))
        }
        if let radius = cursor.radius {
            items.append(URLQueryItem(name: "radius", value: String(radius)))
        }
        var components = URLComponents(string: "https://dapi.kakao.com/v2/local/search/keyword.json")!
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.setValue("KakaoAK \(key)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse, userInfo: [
                NSLocalizedDescriptionKey: "카카오 검색 오류 (\(http.statusCode)): \(String(data: data, encoding: .utf8) ?? "")",
            ])
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let results = decoded.documents.compactMap { doc -> PlaceSearchResult? in
            guard let lng = Double(doc.x), let lat = Double(doc.y) else { return nil }
            return PlaceSearchResult(
                id: "kakao-\(doc.id)",
                name: doc.place_name,
                address: doc.road_address_name.isEmpty ? doc.address_name : doc.road_address_name,
                // "음식점 > 카페 > 커피전문점" → "커피전문점"
                category: doc.category_name.components(separatedBy: " > ").last ?? "",
                latitude: lat,
                longitude: lng,
                // 카카오맵 장소 페이지 (영업시간·메뉴·리뷰). http 로 와서 https 로 바꾼다.
                link: doc.place_url.replacingOccurrences(of: "http://", with: "https://"),
                distance: doc.distance.flatMap(Double.init)
            )
        }

        let next = decoded.meta.is_end || cursor.page >= 3
            ? nil
            : PlaceSearchCursor(query: cursor.query, center: cursor.center, radius: cursor.radius, page: cursor.page + 1)
        let scope: String? = cursor.center == nil ? nil : (cursor.radius == nil ? "주변엔 없어서 전국에서 찾았어요" : "지도 가운데 근처에서 찾았어요")
        return PlaceSearchPage(results: results, next: next, scope: scope)
    }
}

// MARK: - MapKit

@MainActor
final class MapKitPlaceSearchService: PlaceSearchService {
    func search(query: String, near center: CLLocationCoordinate2D?) async throws -> PlaceSearchPage {
        PlaceSearchPage(results: try await results(query: query, near: center), next: nil)
    }

    private func results(query: String, near center: CLLocationCoordinate2D?) async throws -> [PlaceSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        if let center {
            request.region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: 20_000,
                longitudinalMeters: 20_000
            )
        }

        let response = try await MKLocalSearch(request: request).start()

        return response.mapItems.enumerated().map { index, item in
            PlaceSearchResult(
                id: "mk-\(index)-\(item.placemark.coordinate.latitude),\(item.placemark.coordinate.longitude)",
                name: item.name ?? "이름 없는 장소",
                address: item.placemark.formattedKoreanAddress,
                category: item.pointOfInterestCategory?.readableName ?? "",
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
        }
    }
}

// MARK: - 네이버

/// 네이버 지역검색 — NAVER API HUB (네이버 클라우드 플랫폼). 하루 25,000회, 한 번에 최대 5건.
/// (예전 개발자센터 openapi.naver.com 은 2026-07-31 부터 신규 신청이 막혔고 2027-06-30 에 종료된다)
@MainActor
final class NaverPlaceSearchService: PlaceSearchService {
    private struct Response: Decodable {
        let items: [Item]
    }

    private struct Item: Decodable {
        let title: String
        let link: String
        let category: String
        let address: String
        let roadAddress: String
        let mapx: String
        let mapy: String
    }

    func search(query: String, near center: CLLocationCoordinate2D?) async throws -> PlaceSearchPage {
        PlaceSearchPage(results: try await results(query: query), next: nil)
    }

    private func results(query: String) async throws -> [PlaceSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let clientID = NaverKeys.searchClientId,
              let secret = NaverKeys.searchClientSecret
        else { return [] }

        var components = URLComponents(string: "https://naverapihub.apigw.ntruss.com/search/v1/local")!
        components.queryItems = [
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "display", value: "5"),
            URLQueryItem(name: "sort", value: "random"),   // 정확도순
            URLQueryItem(name: "format", value: "json"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(clientID, forHTTPHeaderField: "X-NCP-APIGW-API-KEY-ID")
        request.setValue(secret, forHTTPHeaderField: "X-NCP-APIGW-API-KEY")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse, userInfo: [
                NSLocalizedDescriptionKey: "네이버 검색 오류 (\(http.statusCode)): \(String(data: data, encoding: .utf8) ?? "")",
            ])
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.items.enumerated().compactMap { index, item in
            guard let coordinate = Self.coordinate(mapx: item.mapx, mapy: item.mapy) else { return nil }
            return PlaceSearchResult(
                id: "naver-\(index)-\(item.mapx),\(item.mapy)",
                name: Self.stripTags(item.title),
                address: item.roadAddress.isEmpty ? item.address : item.roadAddress,
                // "음식점>카페,디저트" → "카페,디저트"
                category: item.category.split(separator: ">").last.map(String.init) ?? "",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                link: item.link.hasPrefix("http") ? item.link : nil
            )
        }
    }

    /// mapx = 경도, mapy = 위도 (WGS84).
    /// 위경도에 10^7 을 곱한 정수(1270369447)로 오기도 하고 소수(127.0369447)로 오기도 해서 둘 다 받는다.
    /// 한반도 범위를 벗어나는 값(예전 KATEC 좌표 등)은 버린다.
    private static func coordinate(mapx: String, mapy: String) -> CLLocationCoordinate2D? {
        guard var lng = Double(mapx), var lat = Double(mapy) else { return nil }
        if lng > 1_000 { lng /= 1e7 }
        if lat > 1_000 { lat /= 1e7 }
        guard (120...135).contains(lng), (30...45).contains(lat) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// 검색어가 <b>태그</b> 로 감싸져 오고, &amp; 같은 엔티티도 섞여 온다.
    private static func stripTags(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}

// MARK: - 보조

extension MKPlacemark {
    /// 한국 주소는 "대한민국 서울특별시 ..." 순서라 앞의 국가명을 떼고 보여준다.
    var formattedKoreanAddress: String {
        let parts = [administrativeArea, locality, subLocality, thoroughfare, subThoroughfare]
            .compactMap { $0 }
        return parts.isEmpty ? (title ?? "") : parts.joined(separator: " ")
    }
}

extension MKPointOfInterestCategory {
    var readableName: String {
        switch self {
        case .restaurant: "음식점"
        case .cafe: "카페"
        case .bakery: "베이커리"
        case .park: "공원"
        case .museum: "박물관"
        case .movieTheater: "영화관"
        case .hotel: "숙소"
        case .store: "상점"
        case .beach: "해변"
        case .aquarium: "아쿠아리움"
        case .zoo: "동물원"
        case .amusementPark: "놀이공원"
        default: ""
        }
    }
}
