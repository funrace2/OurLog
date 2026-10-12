//
//  PlacesMapView.swift
//  OurLog
//
//  지도에서 장소를 찾고, 카테고리를 나눠 저장한다. 저장 목록은 둘이 함께 본다.
//
//  지도 렌더링은 지금 MapKit 을 쓴다. 네이버 지도 SDK 로 바꿀 때는
//  이 파일의 Map { } 부분만 NMFMapView 래퍼로 교체하면 되고,
//  검색은 PlaceSearchService 구현만 갈아끼우면 된다.
//

import SwiftUI
import MapKit

struct PlacesMapView: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    @State private var camera: MapCameraPosition = .region(.seoul)
    @State private var searchText = ""
    @State private var searchResults: [PlaceSearchResult] = []
    @State private var isSearching = false
    @State private var selectedCategoryID: String?
    @State private var showList = false

    /// 검색 결과를 눌러 저장하려는 장소
    @State private var placeToSave: PlaceSearchResult?
    /// 지도에서 누른 저장된 장소
    @State private var selectedPlace: SavedPlace?

    @State private var mapCenter = CLLocationCoordinate2D.seoulCenter
    private let searchService = AppEnvironment.makePlaceSearchService()

    private var visiblePlaces: [SavedPlace] {
        guard let selectedCategoryID else { return app.places }
        return app.places.filter { $0.categoryID == selectedCategoryID }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                map

                VStack(spacing: 10) {
                    searchBar
                    categoryFilter
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                if !searchResults.isEmpty {
                    searchResultList
                        .padding(.top, 108)
                }
            }
            .navigationTitle("우리 지도")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showList = true } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
            .sheet(isPresented: $showList) {
                SavedPlaceListView()
            }
            .sheet(item: $placeToSave) { result in
                SavePlaceView(result: result)
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailView(place: place)
            }
        }
    }

    // MARK: 지도

    private var map: some View {
        MapReader { _ in
            Map(position: $camera) {
                ForEach(visiblePlaces) { place in
                    Annotation(place.name, coordinate: place.coordinate) {
                        PlacePin(
                            category: app.category(id: place.categoryID),
                            isVisited: place.isVisited
                        )
                        .onTapGesture { selectedPlace = place }
                    }
                }

                ForEach(searchResults) { result in
                    Annotation(result.name, coordinate: result.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(palette.accent)
                            .onTapGesture { placeToSave = result }
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange { context in
                mapCenter = context.region.center
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: 검색

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.textSecondary)

            TextField("장소, 가게 이름으로 검색", text: $searchText)
                .font(.hand(20))
                .submitLabel(.search)
                .onSubmit { Task { await runSearch() } }

            if isSearching {
                ProgressView().controlSize(.small)
            } else if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .sketchBox(seed: 319, fill: palette.surface, roughness: 1.1, lineWidth: 1.4)
    }

    private func runSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await searchService.search(query: query, near: mapCenter)
            if let first = searchResults.first {
                withAnimation {
                    camera = .region(MKCoordinateRegion(
                        center: first.coordinate,
                        latitudinalMeters: 3_000,
                        longitudinalMeters: 3_000
                    ))
                }
            }
        } catch {
            app.errorMessage = "검색에 실패했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    private var searchResultList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(searchResults) { result in
                    Button {
                        placeToSave = result
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name)
                                    .font(.hand(20, bold: true))
                                    .foregroundStyle(palette.textPrimary)
                                Text(result.address)
                                    .font(.hand(16))
                                    .foregroundStyle(palette.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(palette.primary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)

                    SketchDivider().padding(.leading, 16)
                }
            }
        }
        .frame(maxHeight: 280)
        .sketchBox(seed: 333, fill: palette.surface, roughness: 1.3, lineWidth: 1.6)
        .padding(.horizontal, 16)
    }

    // MARK: 카테고리 필터

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "전체", symbol: "square.grid.2x2.fill", color: palette.primary, id: nil)

                ForEach(app.categories) { category in
                    filterChip(
                        title: category.name,
                        symbol: category.symbol,
                        color: category.color,
                        id: category.id
                    )
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func filterChip(title: String, symbol: String, color: Color, id: String?) -> some View {
        let isSelected = selectedCategoryID == id

        return Button {
            withAnimation(.snappy) { selectedCategoryID = isSelected ? nil : id }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                Text(title).font(.hand(18, bold: true))
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .sketchBox(seed: 326, fill: isSelected ? color : palette.surface, roughness: 1.1, lineWidth: 1.4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 핀

struct PlacePin: View {
    let category: PlaceCategory?
    let isVisited: Bool

    @Environment(\.palette) private var palette

    var body: some View {
        let color = category?.color ?? palette.primary

        ZStack {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)

            Image(systemName: category?.symbol ?? "mappin")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(alignment: .topTrailing) {
            if isVisited {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white, .green)
                    .offset(x: 3, y: -3)
            }
        }
    }
}

// MARK: - 기본 위치

extension MKCoordinateRegion {
    /// 키가 없을 때의 기본 화면. 서울 시청 근처.
    static let seoul = MKCoordinateRegion(
        center: .seoulCenter,
        latitudinalMeters: 6_000,
        longitudinalMeters: 6_000
    )
}

extension CLLocationCoordinate2D {
    static let seoulCenter = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
}

#Preview {
    PlacesMapView()
        .environment(AppEnvironment.makeAppState())
        .environment(\.palette, AppTheme.peach.palette)
}
