//
//  NaverPlacesMap.swift
//  OurLog
//
//  네이버 지도(NMFMapView)를 SwiftUI 에서 쓰기 위한 래퍼.
//  저장한 장소와 검색 결과를 마커로 찍고, 마커를 누르면 알려 준다.
//

import SwiftUI
import CoreLocation
import NMapsMap
import NMapsGeometry

/// 지도를 특정 위치로 옮겨 달라는 요청. id 가 바뀔 때만 한 번 움직인다.
struct MapFocus: Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    var zoom: Double = 15

    static func == (lhs: MapFocus, rhs: MapFocus) -> Bool { lhs.id == rhs.id }
}

struct NaverPlacesMap: UIViewRepresentable {
    var places: [SavedPlace]
    var searchResults: [PlaceSearchResult] = []
    var categoryFor: (String) -> PlaceCategory?
    var focus: MapFocus?
    /// false 면 손으로 움직일 수 없는 미리보기 지도 (상세 화면)
    var interactive = true
    /// 내 위치(파란 점)와 내 위치 버튼을 보여줄지
    var showsMyLocation = false
    /// 나침반을 지도 위쪽에서 얼마나 내려 둘지 (검색창 같은 위 오버레이에 가리지 않게)
    var compassTopInset: CGFloat = 12
    var onSelectPlace: (SavedPlace) -> Void = { _ in }
    var onSelectResult: (PlaceSearchResult) -> Void = { _ in }
    var onCenterChange: (CLLocationCoordinate2D) -> Void = { _ in }

    @Environment(\.palette) private var palette

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverView = NMFNaverMapView(frame: .zero)
        naverView.showZoomControls = false
        naverView.showLocationButton = showsMyLocation
        naverView.showScaleBar = interactive
        // 내장 나침반은 왼쪽 위라 검색창에 가린다 → 끄고 오른쪽에 따로 둔다 (회전하면 나타난다)
        naverView.showCompass = false

        let map = naverView.mapView
        map.addCameraDelegate(delegate: context.coordinator)
        map.addOptionDelegate(delegate: context.coordinator)
        map.isScrollGestureEnabled = interactive
        map.isZoomGestureEnabled = interactive
        map.isRotateGestureEnabled = interactive   // 두 손가락으로 돌리기 (나침반을 누르면 북쪽으로 돌아온다)
        map.isTiltGestureEnabled = false

        let start = focus?.coordinate ?? .seoulCenter
        map.moveCamera(NMFCameraUpdate(scrollTo: NMGLatLng(lat: start.latitude, lng: start.longitude),
                                       zoomTo: focus?.zoom ?? 12))
        context.coordinator.lastFocusID = focus?.id

        if interactive {
            let compass = NMFCompassView()
            compass.mapView = map
            compass.translatesAutoresizingMaskIntoConstraints = false
            naverView.addSubview(compass)
            NSLayoutConstraint.activate([
                compass.trailingAnchor.constraint(equalTo: naverView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
                compass.topAnchor.constraint(equalTo: naverView.safeAreaLayoutGuide.topAnchor, constant: compassTopInset),
            ])
        }

        if showsMyLocation {
            // 따로 보여줄 곳이 없으면 내 위치로 가서 따라간다. 손으로 지도를 움직이면 SDK 가 추적을 풀어 준다.
            context.coordinator.startLocation(on: map, followUser: focus == nil)
        }
        return naverView
    }

    func updateUIView(_ naverView: NMFNaverMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        let map = naverView.mapView

        coordinator.syncMarkers(on: map, places: places, results: searchResults, palette: palette)

        if let focus, focus.id != coordinator.lastFocusID {
            coordinator.lastFocusID = focus.id
            let update = NMFCameraUpdate(
                scrollTo: NMGLatLng(lat: focus.coordinate.latitude, lng: focus.coordinate.longitude),
                zoomTo: focus.zoom
            )
            update.animation = .easeIn
            map.moveCamera(update)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NMFMapViewCameraDelegate, NMFMapViewOptionDelegate, CLLocationManagerDelegate {
        var parent: NaverPlacesMap?
        private let locationManager = CLLocationManager()
        private weak var locationMap: NMFMapView?
        private var followUser = false
        /// 위치 추적은 처음 한 번만 켠다. 이후엔 사용자가 내 위치 버튼으로 고른 모드를 건드리지 않는다.
        private var didStartTracking = false
        private var lastPositionMode: NMFMyPositionMode?

        /// 권한이 없으면 먼저 물어보고, 허락되면 위치 표시를 켠다.
        func startLocation(on map: NMFMapView, followUser: Bool) {
            locationMap = map
            self.followUser = followUser
            locationManager.delegate = self
            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                beginTracking(on: map)
            default:
                break   // 거절한 경우엔 지도만 보여준다
            }
        }

        private func beginTracking(on map: NMFMapView) {
            guard !didStartTracking else { return }
            didStartTracking = true
            map.positionMode = followUser ? .direction : .normal
        }

        nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            MainActor.assumeIsolated {
                guard let map = locationMap else { return }
                // 이 콜백은 앱이 다시 활성화될 때도 불린다. 처음 허락받았을 때만 추적을 켠다.
                switch manager.authorizationStatus {
                case .authorizedWhenInUse, .authorizedAlways:
                    beginTracking(on: map)
                default:
                    break
                }
            }
        }
        var lastFocusID: UUID?
        private var markers: [NMFMarker] = []
        /// 같은 모양 마커 이미지를 매번 다시 굽지 않도록
        private var iconCache: [String: NMFOverlayImage] = [:]

        /// 지금 찍혀 있는 마커가 어떤 데이터로 그려졌는지. 같으면 다시 그리지 않는다.
        private var markerSignature: [AnyHashable] = []

        func syncMarkers(on map: NMFMapView, places: [SavedPlace], results: [PlaceSearchResult], palette: ThemePalette) {
            let signature: [AnyHashable] = places.map { AnyHashable($0) } + results.map { AnyHashable($0) } + [AnyHashable("\(palette.pen)")]
            guard signature != markerSignature else { return }
            markerSignature = signature

            // 마커가 많지 않아서 바뀌었을 때는 통째로 다시 그린다
            markers.forEach { $0.mapView = nil }
            markers.removeAll()

            for place in places {
                let category = parent?.categoryFor(place.categoryID)
                let key = "place|\(category?.id ?? "-")|\(place.isVisited)"
                let marker = makeMarker(at: place.coordinate, caption: place.name, icon: icon(key) {
                    PlacePin(category: category, isVisited: place.isVisited)
                        .environment(\.palette, palette)
                })
                marker.touchHandler = { [weak self] _ in
                    self?.parent?.onSelectPlace(place)
                    return true
                }
                marker.mapView = map
                markers.append(marker)
            }

            for result in results {
                let marker = makeMarker(at: result.coordinate, caption: result.name, icon: icon("result|\(palette.pen)") {
                    SearchResultPin().environment(\.palette, palette)
                })
                marker.zIndex = 10
                marker.touchHandler = { [weak self] _ in
                    self?.parent?.onSelectResult(result)
                    return true
                }
                marker.mapView = map
                markers.append(marker)
            }
        }

        private func makeMarker(at coordinate: CLLocationCoordinate2D, caption: String, icon: NMFOverlayImage) -> NMFMarker {
            let marker = NMFMarker(position: NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude))
            marker.iconImage = icon
            marker.captionText = caption
            marker.captionTextSize = 12
            marker.captionColor = UIColor(Theme.ink)
            marker.captionHaloColor = .white
            marker.anchor = CGPoint(x: 0.5, y: 0.5)
            return marker
        }

        /// SwiftUI 핀을 이미지로 구워 마커 아이콘으로 쓴다.
        private func icon<V: View>(_ key: String, @ViewBuilder _ view: () -> V) -> NMFOverlayImage {
            if let cached = iconCache[key] { return cached }
            let renderer = ImageRenderer(content: view())
            renderer.scale = UIScreen.main.scale
            let image = NMFOverlayImage(image: renderer.uiImage ?? UIImage())
            iconCache[key] = image
            return image
        }

        // NMFMapViewOptionDelegate — 내 위치 버튼으로 모드가 바뀌는 걸 콘솔에 남긴다 (방향 모드 문제 확인용)
        nonisolated func mapViewOptionChanged(_ mapView: NMFMapView) {
            MainActor.assumeIsolated {
                let mode = mapView.positionMode
                guard mode != lastPositionMode else { return }
                lastPositionMode = mode
                let name = switch mode {
                case .disabled: "꺼짐"
                case .normal: "위치만 표시"
                case .direction: "따라가기"
                case .compass: "방향 따라 회전"
                @unknown default: "알 수 없음(\(mode.rawValue))"
                }
                print("[지도] 내 위치 모드 → \(name)")
            }
        }

        // NMFMapViewCameraDelegate — 지도 콜백은 메인 스레드에서 온다
        nonisolated func mapViewCameraIdle(_ mapView: NMFMapView) {
            MainActor.assumeIsolated {
                let target = mapView.cameraPosition.target
                parent?.onCenterChange(CLLocationCoordinate2D(latitude: target.lat, longitude: target.lng))
            }
        }
    }
}

/// 아직 저장하지 않은 검색 결과 자리
private struct SearchResultPin: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(palette.ink)
            .sketchCircle(fill: palette.penSoft, seed: 77, size: 30)
            .padding(2)
    }
}

// MARK: - 네이버 지도 앱으로 열기

enum NaverMapLink {
    /// 네이버 지도 앱이 있으면 그 장소를 열고, 없으면 nil 을 돌려준다 (호출부가 대체 동작을 정한다).
    static func placeURL(name: String, coordinate: CLLocationCoordinate2D) -> URL? {
        var components = URLComponents()
        components.scheme = "nmap"
        components.host = "place"
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lng", value: String(coordinate.longitude)),
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "appname", value: Bundle.main.bundleIdentifier ?? "gaeuni.OurLog"),
        ]
        return components.url
    }

    /// 네이버 지도 앱에서 검색 (가게를 눌러 영업시간·메뉴·리뷰를 볼 수 있다)
    static func searchAppURL(query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "nmap"
        components.host = "search"
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "appname", value: Bundle.main.bundleIdentifier ?? "gaeuni.OurLog"),
        ]
        return components.url
    }

    /// 앱이 없을 때 쓰는 모바일 웹 검색
    static func searchWebURL(query: String) -> URL? {
        var components = URLComponents(string: "https://m.map.naver.com/search")
        components?.queryItems = [URLQueryItem(name: "query", value: query)]
        return components?.url
    }
}
