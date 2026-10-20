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
    /// 아래에서 올라온 검색 결과 판 높이. 내 위치 버튼을 그 위로 올리고, 지도 가운데도 판 위쪽으로 잡는다.
    var bottomInset: CGFloat = 0
    var onSelectPlace: (SavedPlace) -> Void = { _ in }
    var onSelectResult: (PlaceSearchResult) -> Void = { _ in }
    /// 지도가 멈출 때마다 보이는 영역과, 사용자가 손으로 움직였는지를 알려 준다
    var onAreaChange: (MapArea, _ movedByUser: Bool) -> Void = { _, _ in }
    /// 지도에 그려진 가게·장소 이름(심볼)을 눌렀을 때. nil 이면 심볼을 눌러도 아무 일도 없다.
    var onSelectSymbol: ((String, CLLocationCoordinate2D) -> Void)?

    @Environment(\.palette) private var palette

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverView = NMFNaverMapView(frame: .zero)
        naverView.showZoomControls = false
        // 내장 내 위치 버튼은 자리를 못 옮겨서 검색 결과 판에 가린다 → 끄고 따로 둔다
        naverView.showLocationButton = false
        naverView.showScaleBar = interactive
        // 내장 나침반은 왼쪽 위라 검색창에 가린다 → 끄고 오른쪽에 따로 둔다 (회전하면 나타난다)
        naverView.showCompass = false

        let map = naverView.mapView
        map.addCameraDelegate(delegate: context.coordinator)
        map.addOptionDelegate(delegate: context.coordinator)
        if interactive && onSelectSymbol != nil {
            map.touchDelegate = context.coordinator
        }
        map.isScrollGestureEnabled = interactive
        map.isZoomGestureEnabled = interactive
        map.isRotateGestureEnabled = interactive   // 두 손가락으로 돌리기 (나침반을 누르면 북쪽으로 돌아온다)
        map.isTiltGestureEnabled = false

        // 시작 위치: 보여줄 곳이 있으면 거기, 아니면 폰이 마지막으로 알던 내 위치, 그것도 없으면 서울
        let lastKnown = (showsMyLocation && focus == nil) ? Coordinator.lastKnownLocation() : nil
        let start = focus?.coordinate ?? lastKnown ?? .seoulCenter
        let zoom = focus?.zoom ?? (lastKnown != nil ? 15 : 12)
        map.moveCamera(NMFCameraUpdate(scrollTo: NMGLatLng(lat: start.latitude, lng: start.longitude), zoomTo: zoom))
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
            let locationButton = NMFLocationButton()
            locationButton.mapView = map
            locationButton.translatesAutoresizingMaskIntoConstraints = false
            naverView.addSubview(locationButton)
            let bottom = locationButton.bottomAnchor.constraint(
                equalTo: naverView.safeAreaLayoutGuide.bottomAnchor, constant: -(12 + bottomInset)
            )
            NSLayoutConstraint.activate([
                locationButton.leadingAnchor.constraint(equalTo: naverView.safeAreaLayoutGuide.leadingAnchor, constant: 12),
                bottom,
            ])
            context.coordinator.locationButtonBottom = bottom
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

        if coordinator.appliedBottomInset != bottomInset {
            coordinator.appliedBottomInset = bottomInset
            coordinator.locationButtonBottom?.constant = -(12 + bottomInset)
            // 보이는 영역은 그대로 두고, 판에 가린 부분만 지도 콘텐츠에서 뺀다
            let safeBottom = naverView.safeAreaInsets.bottom
            map.setContentInset(
                UIEdgeInsets(top: 0, left: 0, bottom: bottomInset > 0 ? safeBottom + bottomInset : 0, right: 0),
                keepCamera: false
            )
            UIView.animate(withDuration: 0.25) { naverView.layoutIfNeeded() }
        }

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

    final class Coordinator: NSObject, NMFMapViewCameraDelegate, NMFMapViewOptionDelegate, NMFMapViewTouchDelegate, CLLocationManagerDelegate {
        var parent: NaverPlacesMap?
        private let locationManager = CLLocationManager()
        private weak var locationMap: NMFMapView?
        private var followUser = false
        /// 위치 추적은 처음 한 번만 켠다. 이후엔 사용자가 내 위치 버튼으로 고른 모드를 건드리지 않는다.
        private var didStartTracking = false
        /// 처음 들어왔을 때 내 위치로 한 번 옮겼는지
        private var didCenterOnUser = false
        /// 그 전에 사용자가 손으로 지도를 움직였는지 (그랬으면 강제로 옮기지 않는다)
        private var userMovedMap = false
        /// 지금 움직임이 손으로 한 것인지 (멈췄을 때 "현 지도에서 검색"을 띄울지 정한다)
        private var movingByGesture = false
        var locationButtonBottom: NSLayoutConstraint?
        var appliedBottomInset: CGFloat = 0

        /// 폰이 마지막으로 알던 위치 (권한이 있을 때만). 지도를 서울이 아니라 여기서 시작한다.
        static func lastKnownLocation() -> CLLocationCoordinate2D? {
            let manager = CLLocationManager()
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                return manager.location?.coordinate
            default:
                return nil
            }
        }
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
            // 파란 점과 내 위치 버튼을 켠다. 카메라는 SDK 에 맡기지 않고 아래에서 직접 옮긴다
            // (따라가기 모드만 켜 두면 위치를 받기 전이라 무시될 때가 있었다).
            map.positionMode = .normal
            if followUser {
                locationManager.requestLocation()   // 지금 위치를 한 번 받아서 옮긴다
            }
        }

        private func centerOnUser(_ coordinate: CLLocationCoordinate2D) {
            guard followUser, !didCenterOnUser, !userMovedMap, let map = locationMap else { return }
            didCenterOnUser = true
            let update = NMFCameraUpdate(scrollTo: NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude), zoomTo: 15)
            update.animation = .easeIn
            map.moveCamera(update)
        }

        nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            MainActor.assumeIsolated {
                guard let location = locations.last else { return }
                centerOnUser(location.coordinate)
            }
        }

        nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("[지도] 현재 위치를 받지 못했어요: \(error.localizedDescription)")
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
        @objc(mapViewOptionChanged:)
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

        // NMFMapViewTouchDelegate — 지도에 그려진 가게 이름을 누르면
        // 선택 구현 함수라 이름이 조금만 달라도 조용히 안 불린다 → Objective-C 이름을 직접 적는다
        @objc(mapView:didTapSymbol:)
        nonisolated func mapView(_ mapView: NMFMapView, didTap symbol: NMFSymbol) -> Bool {
            MainActor.assumeIsolated {
                guard let onSelectSymbol = parent?.onSelectSymbol else { return false }
                // 두 줄짜리 이름("스타벅스\n성수점")은 한 줄로
                let name = symbol.caption.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return false }
                onSelectSymbol(name, CLLocationCoordinate2D(latitude: symbol.position.lat, longitude: symbol.position.lng))
                return true
            }
        }

        // NMFMapViewCameraDelegate — 지도 콜백은 메인 스레드에서 온다

        @objc(mapView:cameraWillChangeByReason:animated:)
        nonisolated func mapView(_ mapView: NMFMapView, cameraWillChangeByReason reason: Int, animated: Bool) {
            MainActor.assumeIsolated {
                movingByGesture = reason == NMFMapChangedByGesture
                if movingByGesture { userMovedMap = true }
            }
        }

        @objc(mapViewCameraIdle:)
        nonisolated func mapViewCameraIdle(_ mapView: NMFMapView) {
            MainActor.assumeIsolated {
                let target = mapView.cameraPosition.target
                let bounds = mapView.contentBounds
                let area = MapArea(
                    center: CLLocationCoordinate2D(latitude: target.lat, longitude: target.lng),
                    southWest: CLLocationCoordinate2D(latitude: bounds.southWestLat, longitude: bounds.southWestLng),
                    northEast: CLLocationCoordinate2D(latitude: bounds.northEastLat, longitude: bounds.northEastLng)
                )
                parent?.onAreaChange(area, movingByGesture)
                movingByGesture = false
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
