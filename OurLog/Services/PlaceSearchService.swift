//
//  PlaceSearchService.swift
//  OurLog
//
//  장소 검색.
//
//  NaverKeys.plist 에 검색 키가 있으면 네이버 지역검색, 없으면 MapKit 으로 검색한다.
//

import Foundation
import MapKit

@MainActor
protocol PlaceSearchService {
    func search(query: String, near center: CLLocationCoordinate2D?) async throws -> [PlaceSearchResult]
}

// MARK: - MapKit

@MainActor
final class MapKitPlaceSearchService: PlaceSearchService {
    func search(query: String, near center: CLLocationCoordinate2D?) async throws -> [PlaceSearchResult] {
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
        let category: String
        let address: String
        let roadAddress: String
        let mapx: String
        let mapy: String
    }

    func search(query: String, near center: CLLocationCoordinate2D?) async throws -> [PlaceSearchResult] {
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
                longitude: coordinate.longitude
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
