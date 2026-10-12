//
//  PlaceViews.swift
//  OurLog
//
//  장소 저장 / 상세 / 목록.
//

import SwiftUI
import MapKit

// MARK: - 저장하기

struct SavePlaceView: View {
    let result: PlaceSearchResult

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var categoryID = PlaceCategory.date.id
    @State private var memo = ""

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        CuteCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(result.name)
                                    .font(.hand(26, bold: true))
                                    .foregroundStyle(palette.textPrimary)
                                Text(result.address)
                                    .font(.hand(18))
                                    .foregroundStyle(palette.textSecondary)
                                if !result.category.isEmpty {
                                    Chip(text: result.category).padding(.top, 4)
                                }
                            }
                        }

                        CategoryPicker(selection: $categoryID)

                        CuteCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("메모")
                                    .font(.hand(18, bold: true))
                                    .foregroundStyle(palette.textSecondary)
                                TextField("여기 왜 가고 싶은지 적어두면 좋아요", text: $memo, axis: .vertical)
                                    .font(.hand(20))
                                    .lineLimit(3...6)
                            }
                        }

                        Button("저장하기") { save() }
                            .buttonStyle(.soft)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("장소 저장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    private func save() {
        guard let userID = app.me?.id else { return }
        let place = SavedPlace(
            name: result.name,
            address: result.address,
            latitude: result.latitude,
            longitude: result.longitude,
            categoryID: categoryID,
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
            createdBy: userID
        )
        Task { await app.addPlace(place) }
        dismiss()
    }
}

// MARK: - 카테고리 고르기

struct CategoryPicker: View {
    @Binding var selection: String

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        CuteCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("카테고리")
                    .font(.hand(18, bold: true))
                    .foregroundStyle(palette.textSecondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                    ForEach(app.categories) { category in
                        let isSelected = selection == category.id

                        Button {
                            selection = category.id
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: category.symbol).font(.system(size: 12, weight: .bold))
                                Text(category.name)
                                    .font(.hand(18, bold: true))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(isSelected ? .white : category.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? category.color : category.color.opacity(0.12),
                                        in: .rect(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - 상세

struct PlaceDetailView: View {
    let place: SavedPlace

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: place.coordinate,
                            latitudinalMeters: 600,
                            longitudinalMeters: 600
                        ))) {
                            Annotation(place.name, coordinate: place.coordinate) {
                                PlacePin(category: app.category(id: place.categoryID), isVisited: place.isVisited)
                            }
                        }
                        .frame(height: 180)
                        .clipShape(.rect(cornerRadius: 22))
                        .allowsHitTesting(false)

                        CuteCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(place.name)
                                        .font(.hand(27, bold: true))
                                        .foregroundStyle(palette.textPrimary)
                                    Spacer()
                                    if let category = app.category(id: place.categoryID) {
                                        Chip(text: category.name, systemImage: category.symbol, tint: category.color)
                                    }
                                }

                                Text(place.address)
                                    .font(.hand(18))
                                    .foregroundStyle(palette.textSecondary)

                                if !place.memo.isEmpty {
                                    Text(place.memo)
                                        .font(.hand(19))
                                        .foregroundStyle(palette.textPrimary)
                                        .padding(.top, 6)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .sketchBox(seed: 312, fill: palette.surfaceAlt, roughness: 1.3, lineWidth: 1.6)
                                }

                                Text("\(app.couple?.member(id: place.createdBy)?.displayName ?? "누군가") 님이 저장했어요")
                                    .font(.hand(15))
                                    .foregroundStyle(palette.textSecondary)
                                    .padding(.top, 4)
                            }
                        }

                        Button {
                            Task { await app.toggleVisited(place) }
                            dismiss()
                        } label: {
                            Label(
                                place.isVisited ? "아직 안 가봤어요" : "여기 다녀왔어요",
                                systemImage: place.isVisited ? "arrow.uturn.backward" : "checkmark.circle.fill"
                            )
                        }
                        .buttonStyle(place.isVisited ? .softTinted : .soft)

                        Button {
                            openInMaps()
                        } label: {
                            Label("지도 앱에서 길찾기", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                        }
                        .buttonStyle(.softTinted)

                        Button("삭제", role: .destructive) { showDeleteConfirm = true }
                            .buttonStyle(.softPlain)
                            .foregroundStyle(.red)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("장소")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .confirmationDialog("이 장소를 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    Task { await app.deletePlace(id: place.id) }
                    dismiss()
                }
            }
        }
    }

    private func openInMaps() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        item.name = place.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// MARK: - 저장 목록

struct SavedPlaceListView: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategoryID: String?
    @State private var selectedPlace: SavedPlace?

    private var filtered: [SavedPlace] {
        let base = selectedCategoryID.map { id in app.places.filter { $0.categoryID == id } } ?? app.places
        return base.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                categoryChip(nil, name: "전체", symbol: "square.grid.2x2.fill", color: palette.primary)
                                ForEach(app.categories) { category in
                                    categoryChip(category.id, name: category.name,
                                                 symbol: category.symbol, color: category.color)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        if filtered.isEmpty {
                            CuteCard {
                                EmptyStateView(
                                    title: "저장된 장소가 없어요",
                                    message: "지도에서 검색해서 가보고 싶은 곳을 담아보세요"
                                )
                            }
                            .padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(filtered) { place in
                                    Button { selectedPlace = place } label: {
                                        PlaceRow(place: place)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("저장한 장소")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(item: $selectedPlace) { PlaceDetailView(place: $0) }
        }
    }

    private func categoryChip(_ id: String?, name: String, symbol: String, color: Color) -> some View {
        let isSelected = selectedCategoryID == id

        return Button {
            withAnimation(.snappy) { selectedCategoryID = isSelected ? nil : id }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                Text(name).font(.hand(18, bold: true))
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .sketchBox(seed: 305, fill: isSelected ? color : palette.surface, roughness: 1.1, lineWidth: 1.4)
        }
        .buttonStyle(.plain)
    }
}

struct PlaceRow: View {
    let place: SavedPlace

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        let category = app.category(id: place.categoryID)

        CuteCard(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: category?.symbol ?? "mappin")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .sketchCircle(fill: category?.color ?? palette.primary, seed: 298, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(place.name)
                            .font(.hand(20, bold: true))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)

                        if place.isVisited {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                        }
                    }

                    Text(place.memo.isEmpty ? place.address : place.memo)
                        .font(.hand(16))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}
