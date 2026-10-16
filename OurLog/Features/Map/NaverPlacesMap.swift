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
    var onSelectPlace: (SavedPlace) -> Void = { _ in }
    var onSelectResult: (PlaceSearchResult) -> Void = { _ in }
    var onCenterChange: (CLLocationCoordinate2D) -> Void = { _ in }

    @Environment(\.palette) private var palette

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverView = NMFNaverMapView(frame: .zero)
        naverView.showZoomControls = false
        naverView.showLocationButton = false
        naverView.showScaleBar = interactive
        naverView.showCompass = interactive

        let map = naverView.mapView
        map.addCameraDelegate(delegate: context.coordinator)
        map.isScrollGestureEnabled = interactive
        map.isZoomGestureEnabled = interactive
        map.isRotateGestureEnabled = false
        map.isTiltGestureEnabled = false

        let start = focus?.coordinate ?? .seoulCenter
        map.moveCamera(NMFCameraUpdate(scrollTo: NMGLatLng(lat: start.latitude, lng: start.longitude),
                                       zoomTo: focus?.zoom ?? 12))
        context.coordinator.lastFocusID = focus?.id
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

    final class Coordinator: NSObject, NMFMapViewCameraDelegate {
        var parent: NaverPlacesMap?
        var lastFocusID: UUID?
        private var markers: [NMFMarker] = []
        /// 같은 모양 마커 이미지를 매번 다시 굽지 않도록
        private var iconCache: [String: NMFOverlayImage] = [:]

        func syncMarkers(on map: NMFMapView, places: [SavedPlace], results: [PlaceSearchResult], palette: ThemePalette) {
            // 마커가 많지 않아서 통째로 다시 그린다
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
}
