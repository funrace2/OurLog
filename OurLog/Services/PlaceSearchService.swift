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

/// 네이버 지역검색 API (openapi.naver.com). 하루 25,000회 무료, 한 번에 최대 5건.
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

        var components = URLComponents(string: "https://openapi.naver.com/v1/search/local.json")!
        components.queryItems = [
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "display", value: "5"),
            URLQueryItem(name: "sort", value: "random"),   // 정확도순
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(clientID, forHTTPHeaderField: "X-Naver-Client-Id")
        request.setValue(secret, forHTTPHeaderField: "X-Naver-Client-Secret")

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

    /// 지금 API 는 WGS84 위경도에 10^7 을 곱한 정수를 준다 (예: 1270369447 → 127.0369447).
    /// 문서 예시에는 예전 좌표계(KATEC) 값이 남아 있어서, 그런 값이 오면 버린다.
    private static func coordinate(mapx: String, mapy: String) -> CLLocationCoordinate2D? {
        guard let x = Double(mapx), let y = Double(mapy), x > 1e8, y > 1e7 else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: y / 1e7, longitude: x / 1e7)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
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
