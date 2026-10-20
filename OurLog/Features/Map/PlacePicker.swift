//
//  PlacePicker.swift
//  OurLog
//
//  일정·일기에 저장한 장소를 연결하는 칸과, 검색해서 고르는 창.
//  장소가 많아져도 가로 스크롤로 하나하나 넘기지 않고 이름·주소·메모로 찾는다.
//

import SwiftUI
import CoreLocation

// MARK: - 입력 칸

/// 편집 화면에 들어가는 "장소 연결" 칸. 고른 장소 한 줄만 보여주고, 누르면 고르기 창을 연다.
/// 저장한 장소가 없어도 눌러서 새 장소를 찾아 추가할 수 있다.
struct PlaceLinkField: View {
    let title: String
    let emptyMessage: String
    @Binding var placeID: String?

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @State private var showPicker = false
    @State private var openedPlace: SavedPlace?

    var body: some View {
        CuteCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.hand(18, bold: true))
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                    if app.place(id: placeID) != nil {
                        Button("바꾸기") { showPicker = true }
                            .font(.hand(17, bold: true))
                            .foregroundStyle(palette.pen)
                    }
                }

                // 연결된 장소가 있으면 누를 때 상세정보를, 없으면 고르기 창을 연다
                Button {
                    if let place = app.place(id: placeID) {
                        openedPlace = place
                    } else {
                        showPicker = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        if let place = app.place(id: placeID) {
                            PlaceIcon(category: app.category(id: place.categoryID))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(place.name)
                                    .font(.hand(19, bold: true))
                                    .foregroundStyle(palette.textPrimary)
                                    .lineLimit(1)
                                Text(place.address)
                                    .font(.hand(15))
                                    .foregroundStyle(palette.textSecondary)
                                    .lineLimit(1)
                            }
                        } else {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(palette.pen)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("장소 고르기")
                                    .font(.hand(19, bold: true))
                                    .foregroundStyle(palette.pen)
                                Text(app.places.isEmpty ? emptyMessage : "저장한 장소에서 고르거나 새로 찾기")
                                    .font(.hand(15))
                                    .foregroundStyle(palette.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(palette.textSecondary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showPicker) {
            PlacePickerView(selection: $placeID)
        }
        .sheet(item: $openedPlace) { PlaceDetailView(place: $0) }
    }
}

// MARK: - 고르기 창

struct PlacePickerView: View {
    @Binding var selection: String?

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var categoryID: String?
    /// 저장한 장소 목록과 같은 정렬 설정을 쓴다
    @AppStorage("savedPlaces.sort") private var sort: SavedPlaceListView.PlaceSort = .latest

    private var results: [SavedPlace] {
        var list = app.places
        if let categoryID { list = list.filter { $0.categoryID == categoryID } }

        let keyword = Self.normalize(query)
        if !keyword.isEmpty {
            list = list.filter { place in
                let category = app.category(id: place.categoryID)?.name ?? ""
                return [place.name, place.address, place.memo, category]
                    .contains { Self.normalize($0).contains(keyword) }
            }
        }

        switch sort {
        case .nearest:
            if let me = MyLocation.current {
                func distance(_ place: SavedPlace) -> CLLocationDistance {
                    me.distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude))
                }
                return list.sorted { distance($0) < distance($1) }
            }
            return list.sorted { $0.createdAt > $1.createdAt }
        case .latest:
            return list.sorted { $0.createdAt > $1.createdAt }
        }
    }

    /// 띄어쓰기·대소문자 무시 ("성수 카페" 로도 "성수카페" 가 찾아지게)
    private static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: " ", with: "").lowercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 12) {
                        NavigationLink {
                            NewPlaceSearchView { place in
                                // 저장(또는 이미 저장된 곳 선택)하면 바로 연결하고 창들을 한 번에 닫는다
                                selection = place.id
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.magnifyingglass")
                                    .font(.system(size: 16, weight: .bold))
                                Text("새 장소 찾아서 추가")
                                    .font(.hand(20, bold: true))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(palette.ink)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .sketchBox(seed: 55, fill: palette.penSoft)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)

                        if !app.places.isEmpty {
                            Text("저장한 장소")
                                .font(.hand(17, bold: true))
                                .foregroundStyle(palette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .padding(.top, 6)
                        }

                        searchField
                        categoryChips
                        SketchPicker(selection: $sort, options: SavedPlaceListView.PlaceSort.allCases.map { ($0, $0.title) })
                            .padding(.horizontal, 20)

                        if results.isEmpty {
                            CuteCard {
                                EmptyStateView(title: "맞는 장소가 없어요", message: "이름, 주소, 메모로 찾아보세요")
                            }
                            .padding(.horizontal, 20)
                        } else {
                            CuteCard(padding: 0) {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(results.enumerated()), id: \.element.id) { index, place in
                                        Button {
                                            selection = place.id
                                            dismiss()
                                        } label: {
                                            row(place)
                                        }
                                        .buttonStyle(.plain)

                                        if index < results.count - 1 {
                                            SketchDivider(seed: UInt64(index) &+ 300).padding(.horizontal, 12)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .paperTitle("장소 고르기")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selection != nil {
                        ToolbarTextButton("연결 안 함") {
                            selection = nil
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarTextButton("닫기") { dismiss() }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.textSecondary)
            TextField("이름, 주소, 메모로 찾기", text: $query)
                .font(.hand(20))
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
        .sketchField()
        .padding(.horizontal, 20)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(id: nil, name: "전체", symbol: "square.grid.2x2.fill", color: palette.primary)
                ForEach(app.categories) { category in
                    chip(id: category.id, name: category.name, symbol: category.symbol, color: category.color)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chip(id: String?, name: String, symbol: String, color: Color) -> some View {
        let isSelected = categoryID == id
        return Button {
            withAnimation(.snappy) { categoryID = isSelected ? nil : id }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                Text(name).font(.hand(17, bold: true))
            }
            .foregroundStyle(isSelected ? palette.ink : color)
            .padding(.vertical, 7)
            .padding(.horizontal, 11)
            .sketchBox(
                seed: sketchSeed(name),
                fill: isSelected ? color.opacity(0.28) : palette.card,
                stroke: isSelected ? palette.ink : color,
                roughness: 1.1,
                lineWidth: isSelected ? 2.2 : 1.4
            )
        }
        .buttonStyle(.plain)
    }

    private func row(_ place: SavedPlace) -> some View {
        HStack(spacing: 10) {
            PlaceIcon(category: app.category(id: place.categoryID))

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.hand(19, bold: true))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                Text(place.memo.isEmpty ? place.address : place.memo)
                    .font(.hand(15))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if let distance = PlaceFormat.distanceFromMe(to: place.coordinate) {
                Text(distance)
                    .font(.hand(15))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize()
            }

            if selection == place.id {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(palette.pen)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .contentShape(.rect)
    }
}

// MARK: - 새 장소 찾기

/// 고르기 창 안에서 저장 안 한 장소를 검색한다. 결과를 누르면 미리보기 → 저장 → 바로 연결.
struct NewPlaceSearchView: View {
    let onPick: (SavedPlace) -> Void

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    @State private var query = ""
    @State private var results: [PlaceSearchResult] = []
    @State private var isSearching = false
    @State private var didSearch = false
    @State private var preview: PlaceSearchResult?
    @FocusState private var focused: Bool

    private let searchService = AppEnvironment.makePlaceSearchService()

    var body: some View {
        ZStack {
            CuteBackground()

            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.textSecondary)
                        TextField("가게·장소 이름으로 찾기", text: $query)
                            .font(.hand(20))
                            .submitLabel(.search)
                            .focused($focused)
                            .onSubmit { Task { await search() } }
                        if isSearching { ProgressView().controlSize(.small) }
                    }
                    .sketchField()
                    .padding(.horizontal, 20)

                    if results.isEmpty {
                        if didSearch && !isSearching {
                            CuteCard {
                                EmptyStateView(title: "검색 결과가 없어요", message: "가게 이름이나 동네 이름을 바꿔서 찾아보세요")
                            }
                            .padding(.horizontal, 20)
                        } else {
                            Text("내 위치 근처부터 찾아요")
                                .font(.hand(16))
                                .foregroundStyle(palette.textSecondary)
                        }
                    } else {
                        CuteCard(padding: 0) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                    Button {
                                        preview = result
                                    } label: {
                                        row(result)
                                    }
                                    .buttonStyle(.plain)

                                    if index < results.count - 1 {
                                        SketchDivider(seed: UInt64(index) &+ 700).padding(.horizontal, 12)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .paperTitle("새 장소 찾기")
        .sheet(item: $preview) { result in
            PlacePreviewView(result: result, onPick: onPick)
        }
        .onAppear { focused = true }
    }

    private func row(_ result: PlaceSearchResult) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.hand(19, bold: true))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                Text([PlaceFormat.distanceFromMe(to: result.coordinate), result.category.isEmpty ? nil : result.category, result.address]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.hand(15))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .contentShape(.rect)
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        defer {
            isSearching = false
            didSearch = true
        }
        do {
            // 내 위치를 알면 그 근처부터, 모르면 전국에서
            results = try await searchService.search(query: trimmed, near: MyLocation.current?.coordinate).results
        } catch {
            print("새 장소 검색 실패: \(error)")
            app.errorMessage = "검색에 실패했어요. 잠시 후 다시 시도해 주세요."
        }
    }
}

/// 카테고리 색 동그라미 아이콘
struct PlaceIcon: View {
    let category: PlaceCategory?
    @Environment(\.palette) private var palette

    var body: some View {
        Image(systemName: category?.symbol ?? "mappin")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .sketchCircle(fill: category?.color ?? palette.primary, seed: sketchSeed(category?.id ?? "-"), size: 34)
    }
}
