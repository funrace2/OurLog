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
            createdBy: userID,
            link: result.link
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
                            .foregroundStyle(isSelected ? palette.ink : category.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .sketchBox(
                                seed: sketchSeed(category.id),
                                fill: isSelected ? category.color.opacity(0.28) : palette.card,
                                stroke: isSelected ? palette.ink : category.color,
                                roughness: 1.2,
                                lineWidth: isSelected ? 2.2 : 1.4
                            )
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
    @State private var info = PlaceInfo()
    @State private var isLoadingInfo = PlaceInfoService.isAvailable
    @State private var openedPhoto: PlacePhoto?
    @State private var webPage: WebPage?

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        photoStrip

                        placePreviewMap
                            .frame(height: 150)
                            .clipShape(.rect(cornerRadius: 6))
                            .sketchBox(seed: sketchSeed(place.id), fill: .clear)
                            .allowsHitTesting(false)

                        infoCard
                        reviewsSection

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

                        if AppEnvironment.useNaverMaps {
                            Button {
                                openNaverPlacePage()
                            } label: {
                                Label("네이버 지도에서 자세히 보기", systemImage: "info.circle")
                            }
                            .buttonStyle(.softTinted)
                        }

                        Button {
                            openInMaps()
                        } label: {
                            Label("길찾기", systemImage: "arrow.triangle.turn.up.right.circle.fill")
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
            .sheet(item: $webPage) { page in
                SafariView(url: page.url).ignoresSafeArea()
            }
            .fullScreenCover(item: $openedPhoto) { photo in
                PhotoViewer(photos: info.photos, selection: photo)
            }
            .task {
                guard PlaceInfoService.isAvailable else { return }
                info = await PlaceInfoService.shared.info(for: place)
                isLoadingInfo = false
            }
        }
    }

    // MARK: 사진

    @ViewBuilder
    private var photoStrip: some View {
        if isLoadingInfo {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { index in
                        palette.paperDeep
                            .frame(width: 130, height: 160)
                            .sketchBox(seed: UInt64(index) &+ 440, fill: .clear, roughness: 1.2, lineWidth: 1.6)
                    }
                }
                .padding(.horizontal, 2)
            }
            .redacted(reason: .placeholder)
        } else if !info.photos.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(Array(info.photos.enumerated()), id: \.element.id) { index, photo in
                            Button {
                                openedPhoto = photo
                            } label: {
                                RemoteImage(url: photo.url, maxPixel: 600)
                                    .frame(width: 130, height: 160)
                                    .clipped()
                                    .sketchBox(seed: UInt64(index) &+ 440, fill: .clear, roughness: 1.2, lineWidth: 1.6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                Text("네이버 검색에서 찾은 사진이라 다른 곳이 섞여 있을 수 있어요")
                    .font(.hand(14))
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    // MARK: 정보

    private var infoCard: some View {
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

                if let link = place.link, let url = URL(string: link) {
                    Button {
                        webPage = WebPage(url: url)
                    } label: {
                        Label(Self.linkTitle(url), systemImage: "link")
                            .font(.hand(18, bold: true))
                            .foregroundStyle(palette.pen)
                    }
                    .buttonStyle(.plain)
                }

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
    }

    /// 링크 종류에 맞는 버튼 이름
    private static func linkTitle(_ url: URL) -> String {
        let host = url.host() ?? ""
        if host.contains("place.map.kakao") { return "카카오맵 정보 (영업시간·메뉴·리뷰)" }
        if host.contains("instagram") { return "인스타그램" }
        if host.contains("blog.naver") { return "블로그" }
        return "홈페이지"
    }

    // MARK: 후기

    @ViewBuilder
    private var reviewsSection: some View {
        if !info.posts.isEmpty {
            VStack(spacing: 10) {
                SectionHeader(title: "블로그 후기")

                CuteCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(info.posts.enumerated()), id: \.element.id) { index, post in
                            Button {
                                webPage = WebPage(url: post.url)
                            } label: {
                                BlogPostRow(post: post)
                            }
                            .buttonStyle(.plain)

                            if index < info.posts.count - 1 {
                                SketchDivider(seed: UInt64(index) &+ 80)
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: 네이버 지도

    private func openNaverPlacePage() {
        let query = PlaceInfoService.query(for: place)
        let web = NaverMapLink.searchWebURL(query: query)
        guard let appURL = NaverMapLink.searchAppURL(query: query) else {
            if let web { webPage = WebPage(url: web) }
            return
        }
        UIApplication.shared.open(appURL) { opened in
            if !opened, let web { webPage = WebPage(url: web) }
        }
    }

    @ViewBuilder
    private var placePreviewMap: some View {
        if AppEnvironment.useNaverMaps {
            NaverPlacesMap(
                places: [place],
                categoryFor: { app.category(id: $0) },
                focus: MapFocus(coordinate: place.coordinate, zoom: 16),
                interactive: false
            )
        } else {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: place.coordinate,
                latitudinalMeters: 600,
                longitudinalMeters: 600
            ))) {
                Annotation(place.name, coordinate: place.coordinate) {
                    PlacePin(category: app.category(id: place.categoryID), isVisited: place.isVisited)
                }
            }
        }
    }

    /// 네이버 지도 앱이 있으면 거기서, 없으면 Apple 지도에서 연다.
    private func openInMaps() {
        let openApple = {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
            item.name = place.name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        }
        guard let url = NaverMapLink.placeURL(name: place.name, coordinate: place.coordinate) else {
            openApple()
            return
        }
        UIApplication.shared.open(url) { opened in
            if !opened { openApple() }
        }
    }
}

// MARK: - 후기 한 줄

private struct BlogPostRow: View {
    let post: BlogPost
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(post.title)
                .font(.hand(19, bold: true))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
            Text(post.summary)
                .font(.hand(16))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text([post.blogger, post.date?.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ko_KR")))]
                .compactMap { $0 }.joined(separator: " · "))
                .font(.hand(14))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(.rect)
    }
}

// MARK: - 사진 크게 보기

private struct PhotoViewer: View {
    let photos: [PlacePhoto]
    @State var selection: PlacePhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(photos) { photo in
                    RemoteImage(url: photo.url, maxPixel: 2000, contentMode: .fit)
                        .tag(photo)
                }
            }
            .tabViewStyle(.page)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.4), in: .circle)
            }
            .padding()
        }
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
            .foregroundStyle(isSelected ? palette.ink : color)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .sketchBox(seed: sketchSeed(name), fill: isSelected ? color.opacity(0.28) : palette.card, stroke: isSelected ? palette.ink : color, roughness: 1.1, lineWidth: isSelected ? 2.2 : 1.4)
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
