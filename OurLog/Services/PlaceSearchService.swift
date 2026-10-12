//
//  PlaceSearchService.swift
//  OurLog
//
//  장소 검색.
//
//  지금은 MapKit 으로 검색한다 (키가 필요 없고 바로 동작).
//  네이버 지역검색 API 키가 준비되면 NaverPlaceSearchService 를 채우고
//  AppEnvironment.useNaverMaps 만 켜면 화면 코드는 그대로 둔 채 교체된다.
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

/// 네이버 지역검색 API 연동 자리.
///
/// 주의: 네이버 지역검색(openapi.naver.com)은 Client Secret 을 함께 보내야 해서
/// 앱에서 직접 부르면 키가 노출된다. Firebase Cloud Functions 같은 서버를 하나 두고
/// 그쪽을 호출하는 형태로 만드는 것을 권한다. 자세한 내용은 SETUP.md 참고.
@MainActor
final class NaverPlaceSearchService: PlaceSearchService {
    func search(query: String, near center: CLLocationCoordinate2D?) async throws -> [PlaceSearchResult] {
        // TODO: 프록시 서버 주소가 정해지면 연결한다.
        assertionFailure("네이버 검색이 아직 연결되지 않았습니다. AppEnvironment.useNaverMaps 를 확인하세요.")
        return []
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
