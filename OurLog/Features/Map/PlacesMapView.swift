//
//  PlacesMapView.swift
//  OurLog
//
//  지도에서 장소를 찾고, 카테고리를 나눠 저장한다. 저장 목록은 둘이 함께 본다.
//
//  NaverKeys.plist 에 지도 키가 있으면 네이버 지도, 없으면 MapKit 으로 그린다.
//

import SwiftUI
import MapKit

struct PlacesMapView: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    /// MapKit 지도는 내 위치에서 시작하고, 위치를 모르면 서울에서 시작한다
    @State private var camera: MapCameraPosition = .userLocation(fallback: .region(.seoul))
    @State private var searchText = ""
    @State private var searchResults: [PlaceSearchResult] = []
    /// "더 보기"로 이어 받을 다음 페이지
    @State private var searchNext: PlaceSearchCursor?
    /// 어디 기준으로 찾았는지 안내 문구
    @State private var searchScope: String?
    @State private var isLoadingMore = false
    @State private var isSearching = false
    /// 검색한 뒤 손으로 지도를 옮기면 "현 지도에서 검색" 버튼을 띄운다
    @State private var showSearchHere = false
    /// 아래에서 올라오는 검색 결과 판의 높이 단계
    @State private var panelLevel: ResultsPanelLevel = .middle
    @State private var selectedCategoryID: String?
    @State private var showList = false

    /// 검색 결과를 눌러 미리 보는 장소 (여기서 저장한다)
    @State private var previewResult: PlaceSearchResult?
    /// 지도에서 누른 가게 이름 (정보를 찾는 동안 보여준다)
    @State private var resolvingSymbol: String?
    /// 지도에서 누른 저장된 장소
    @State private var selectedPlace: SavedPlace?

    /// 지도 중심 (검색할 때만 쓴다). @State 로 두면 지도가 멈출 때마다 화면 전체가 다시 그려져서,
    /// 관찰되지 않는 보관함에 담는다.
    @State private var center = MapCenterBox()
    /// 네이버 지도를 옮겨 달라는 요청 (검색 결과로 이동할 때)
    @State private var naverFocus: MapFocus?
    /// MapKit 지도에서 위치 권한을 묻는 데 쓴다 (네이버 지도는 래퍼 안에서 따로 묻는다)
    @State private var locationManager = CLLocationManager()
    private let searchService = AppEnvironment.makePlaceSearchService()

    private var visiblePlaces: [SavedPlace] {
        guard let selectedCategoryID else { return app.places }
        return app.places.filter { $0.categoryID == selectedCategoryID }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let panelHeights = ResultsPanelHeights(available: geo.size.height)
                ZStack(alignment: .top) {
                    map(bottomInset: searchResults.isEmpty ? 0 : panelHeights.inset(for: panelLevel))

                    VStack(spacing: 10) {
                        searchBar
                        categoryFilter
                        if showSearchHere && !searchResults.isEmpty {
                            searchHereButton
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }
                .overlay(alignment: .bottom) {
                    if !searchResults.isEmpty {
                        ResultsPanel(level: $panelLevel, heights: panelHeights) {
                            resultsHeader
                        } content: {
                            resultsList
                        }
                        .transition(.move(edge: .bottom))
                    }
                }
                .overlay(alignment: .bottom) {
                    resolvingBanner
                        .padding(.bottom, searchResults.isEmpty ? 0 : panelHeights.inset(for: panelLevel))
                }
            }
            .animation(.snappy, value: searchResults.isEmpty)
            .animation(.snappy, value: showSearchHere)
            .animation(.easeInOut(duration: 0.2), value: resolvingSymbol)
            // 필터로 고른 카테고리가 지워지면 "전체"로
            .onChange(of: app.categories.map(\.id)) { _, ids in
                if let selected = selectedCategoryID, !ids.contains(selected) { selectedCategoryID = nil }
            }
            // 바탕이 종이가 아니라 지도라서, 상단바·탭바 색을 직접 맞춘다 (다른 탭과 같은 모양)
            .paperBars()
            .paperTitle("우리 지도")
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
            .sheet(item: $previewResult) { result in
                PlacePreviewView(result: result, onSaved: { _ in clearSearch() })
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailView(place: place)
            }
        }
    }

    /// 지도에서 누른 가게 정보를 찾는 동안 아래에 잠깐 뜨는 안내
    @ViewBuilder
    private var resolvingBanner: some View {
        if let resolvingSymbol {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("\(resolvingSymbol) 정보 찾는 중…")
                    .font(.hand(17))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .sketchBox(seed: 91, fill: palette.card, roughness: 1.1, lineWidth: 1.4)
            .padding(.bottom, 24)
            .transition(.opacity)
        }
    }

    // MARK: 지도

    @ViewBuilder
    private func map(bottomInset: CGFloat) -> some View {
        if AppEnvironment.useNaverMaps {
            NaverPlacesMap(
                places: visiblePlaces,
                searchResults: searchResults,
                categoryFor: { app.category(id: $0) },
                focus: naverFocus,
                showsMyLocation: true,
                compassTopInset: 112,   // 검색창 + 카테고리 칩 아래
                bottomInset: bottomInset,
                onSelectPlace: { selectedPlace = $0 },
                onSelectResult: { previewResult = $0 },
                onAreaChange: { area, movedByUser in mapAreaChanged(area, movedByUser: movedByUser) },
                onSelectSymbol: { name, coordinate in
                    Task { await openSymbol(name: name, at: coordinate) }
                }
            )
            .ignoresSafeArea(edges: .bottom)
        } else {
            appleMap
        }
    }

    private var appleMap: some View {
        MapReader { _ in
            Map(position: $camera) {
                UserAnnotation()

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
                            .onTapGesture { previewResult = result }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                let region = context.region
                let area = MapArea(
                    center: region.center,
                    southWest: CLLocationCoordinate2D(
                        latitude: region.center.latitude - region.span.latitudeDelta / 2,
                        longitude: region.center.longitude - region.span.longitudeDelta / 2
                    ),
                    northEast: CLLocationCoordinate2D(
                        latitude: region.center.latitude + region.span.latitudeDelta / 2,
                        longitude: region.center.longitude + region.span.longitudeDelta / 2
                    )
                )
                // MapKit 은 누가 움직였는지 알려 주지 않아서, 검색으로 옮긴 직후 한 번은 사용자가 아닌 걸로 본다
                let byUser = !center.expectingProgrammaticMove
                center.expectingProgrammaticMove = false
                mapAreaChanged(area, movedByUser: byUser)
            }
            .onAppear {
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestWhenInUseAuthorization()
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: 검색

    /// 검색어와 검색 결과 핀을 모두 걷어낸다. (저장을 마치면 저장한 핀만 남도록)
    private func clearSearch() {
        searchText = ""
        searchResults = []
        searchNext = nil
        searchScope = nil
        showSearchHere = false
    }

    /// 지도가 멈췄을 때. 검색 결과를 보는 중에 손으로 옮겼으면 판을 내리고 "현 지도에서 검색"을 띄운다.
    private func mapAreaChanged(_ area: MapArea, movedByUser: Bool) {
        center.coordinate = area.center
        center.area = area
        guard movedByUser, !searchResults.isEmpty else { return }
        if !showSearchHere { showSearchHere = true }
        if panelLevel != .collapsed { withAnimation(.snappy) { panelLevel = .collapsed } }
    }

    private var searchHereButton: some View {
        Button {
            Task { await searchHere() }
        } label: {
            HStack(spacing: 6) {
                if isSearching {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .bold))
                }
                Text("현 지도에서 검색").font(.hand(18, bold: true))
            }
            .foregroundStyle(palette.ink)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .sketchBox(seed: 345, fill: palette.surface, roughness: 1.1, lineWidth: 1.6)
        }
        .buttonStyle(.plain)
        .disabled(isSearching)
    }

    /// 같은 검색어로 지금 보이는 지도 안에서 다시 찾는다. 지도는 그대로 둔다.
    private func searchHere() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty, let area = center.area else { return }

        isSearching = true
        defer { isSearching = false }

        do {
            let page = try await searchService.search(query: query, in: area)
            showSearchHere = false
            if page.results.isEmpty {
                app.toast = Toast(text: "이 지도 안에는 검색 결과가 없어요")
                return
            }
            searchResults = page.results
            searchNext = page.next
            searchScope = page.scope
            withAnimation(.snappy) { panelLevel = .middle }
        } catch {
            print("장소 검색(현 지도) 실패: \(error)")
            app.errorMessage = "검색에 실패했어요. 잠시 후 다시 시도해 주세요."
        }
    }

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
                    clearSearch()
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
            let page = try await searchService.search(query: query, near: center.coordinate)
            searchResults = page.results
            searchNext = page.next
            searchScope = page.scope
            showSearchHere = false
            panelLevel = .middle
            if page.results.isEmpty {
                app.toast = Toast(text: "검색 결과가 없어요")
            }
            if let first = searchResults.first {
                center.expectingProgrammaticMove = true
                naverFocus = MapFocus(coordinate: first.coordinate)
                withAnimation {
                    camera = .region(MKCoordinateRegion(
                        center: first.coordinate,
                        latitudinalMeters: 3_000,
                        longitudinalMeters: 3_000
                    ))
                }
            }
        } catch {
            print("장소 검색 실패: \(error)")
            app.errorMessage = "검색에 실패했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    /// 지도에서 누른 가게를 찾아 미리보기로 연다. 못 찾으면 이름과 위치만으로 연다.
    private func openSymbol(name: String, at coordinate: CLLocationCoordinate2D) async {
        guard resolvingSymbol == nil else { return }
        resolvingSymbol = name
        defer { resolvingSymbol = nil }

        let found = await searchService.resolve(name: name, at: coordinate)
        previewResult = found ?? PlaceSearchResult(
            id: "symbol-\(coordinate.latitude),\(coordinate.longitude)",
            name: name,
            address: "",
            category: "",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    private func loadMore() async {
        guard let cursor = searchNext, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await searchService.more(cursor)
            // 같은 장소가 두 번 나오지 않게
            let known = Set(searchResults.map(\.id))
            searchResults += page.results.filter { !known.contains($0.id) }
            searchNext = page.next
        } catch {
            print("장소 검색(더 보기) 실패: \(error)")
            searchNext = nil
        }
    }

    private var resultsHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("검색 결과 \(searchResults.count)곳")
                .font(.hand(20, bold: true))
                .foregroundStyle(palette.textPrimary)
            if let searchScope {
                Text(searchScope)
                    .font(.hand(15))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                clearSearch()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(searchResults) { result in
                Button {
                    previewResult = result
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                                .font(.hand(20, bold: true))
                                .foregroundStyle(palette.textPrimary)
                            Text([PlaceFormat.distanceFromMe(to: result.coordinate), result.category.isEmpty ? nil : result.category, result.address]
                                .compactMap { $0 }.joined(separator: " · "))
                                .font(.hand(16))
                                .foregroundStyle(palette.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.textSecondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                SketchDivider().padding(.leading, 16)
            }

            if searchNext != nil {
                Button {
                    Task { await loadMore() }
                } label: {
                    HStack(spacing: 6) {
                        if isLoadingMore { ProgressView().controlSize(.small) }
                        Text("더 보기")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.softPlain)
                .disabled(isLoadingMore)
                .padding(.vertical, 4)
            }
        }
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
            .foregroundStyle(isSelected ? palette.ink : color)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .sketchBox(seed: sketchSeed(title), fill: isSelected ? color.opacity(0.28) : palette.card, stroke: isSelected ? palette.ink : color, roughness: 1.1, lineWidth: isSelected ? 2.2 : 1.4)
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
        .environment(\.palette, AppTheme.default.palette)
}

/// 바뀌어도 화면을 다시 그리지 않는 지도 중심 보관함 (일부러 @Observable 이 아니다)
final class MapCenterBox {
    var coordinate = CLLocationCoordinate2D.seoulCenter
    /// 지금 보이는 영역 ("현 지도에서 검색"에 쓴다)
    var area: MapArea?
    /// MapKit 지도를 코드로 옮기는 중인지 (그 움직임은 사용자가 한 게 아니다)
    var expectingProgrammaticMove = false
}
