//
//  PlaceViews.swift
//  OurLog
//
//  장소 미리보기(저장 전) / 저장 / 상세(저장 후) / 목록.
//  흐름: 검색 결과 → 미리보기(사진·후기 확인) → 저장(카테고리·메모) → 상세
//

import SwiftUI
import MapKit

// MARK: - 미리보기 (검색 결과, 저장 전)

struct PlacePreviewView: View {
    let result: PlaceSearchResult

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var info: PlaceInfo
    @State private var isLoadingInfo: Bool
    @State private var showSave = false
    @State private var openedPhoto: PlacePhoto?
    @State private var webPage: WebPage?
    @State private var savedToOpen: SavedPlace?

    init(result: PlaceSearchResult) {
        self.result = result
        let cached = PlaceInfoService.shared.cachedInfo(for: result.lookup)
        _info = State(initialValue: cached ?? PlaceInfo())
        _isLoadingInfo = State(initialValue: cached == nil && PlaceInfoService.isAvailable)
    }

    /// 이미 저장한 곳인지 (이름이 같고 100m 안)
    private var alreadySaved: SavedPlace? {
        let here = CLLocation(latitude: result.latitude, longitude: result.longitude)
        return app.places.first {
            $0.name == result.name
                && CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: here) < 100
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        PlacePhotoStrip(photos: info.photos, isLoading: isLoadingInfo) { openedPhoto = $0 }

                        PlaceMapPreview(result: result)

                        CuteCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(result.name)
                                        .font(.hand(27, bold: true))
                                        .foregroundStyle(palette.textPrimary)
                                    Spacer()
                                    if !result.category.isEmpty {
                                        Chip(text: result.category)
                                    }
                                }

                                Text([PlaceFormat.distanceFromMe(to: result.coordinate).map { "내 위치에서 \($0)" }, result.address]
                                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.hand(18))
                                    .foregroundStyle(palette.textSecondary)

                                if let link = result.link, let url = URL(string: link) {
                                    PlaceLinkButton(url: url) { webPage = WebPage(url: url) }
                                }
                            }
                        }

                        PlaceReviewsSection(posts: info.posts) { webPage = WebPage(url: $0) }

                        if let saved = alreadySaved {
                            VStack(spacing: 8) {
                                Text("이미 저장한 장소예요")
                                    .font(.hand(17))
                                    .foregroundStyle(palette.textSecondary)
                                Button {
                                    savedToOpen = saved
                                } label: {
                                    Label("저장된 장소 열기", systemImage: "bookmark.fill")
                                }
                                .buttonStyle(.soft)
                            }
                        } else {
                            Button {
                                showSave = true
                            } label: {
                                Label("이 장소 저장하기", systemImage: "plus")
                            }
                            .buttonStyle(.soft)
                        }

                        PlaceActionButtons(
                            lookup: result.lookup,
                            name: result.name,
                            coordinate: result.coordinate,
                            openWeb: { webPage = WebPage(url: $0) }
                        )
                    }
                    .padding(20)
                }
            }
            .navigationTitle("장소 미리보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            // 저장이 끝나면 미리보기까지 한 번에 닫는다
            .sheet(isPresented: $showSave) {
                SavePlaceView(result: result, onSaved: { dismiss() })
            }
            .sheet(item: $savedToOpen) { PlaceDetailView(place: $0) }
            .sheet(item: $webPage) { page in
                SafariView(url: page.url).ignoresSafeArea()
            }
            .fullScreenCover(item: $openedPhoto) { photo in
                PhotoViewer(photos: info.photos, selection: photo)
            }
            .task {
                guard isLoadingInfo else { return }
                info = await PlaceInfoService.shared.info(for: result.lookup)
                isLoadingInfo = false
            }
        }
    }
}

// MARK: - 저장하기 (카테고리 · 메모)

struct SavePlaceView: View {
    let result: PlaceSearchResult
    /// 저장 후 부를 것. 있으면 이 화면을 직접 닫지 않고 부른 쪽에 맡긴다 (미리보기까지 한 번에 닫으려고).
    var onSaved: (() -> Void)?

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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                                .font(.hand(24, bold: true))
                                .foregroundStyle(palette.textPrimary)
                            Text(result.address)
                                .font(.hand(16))
                                .foregroundStyle(palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

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
        if let onSaved {
            onSaved()
        } else {
            dismiss()
        }
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

// MARK: - 상세 (저장한 장소)

struct PlaceDetailView: View {
    /// 열 때 받은 장소. 화면에는 아래 place(최신 저장 정보)를 쓴다.
    private let opened: SavedPlace

    @Environment(AppState.self) private var app

    /// 수정하거나 상대방이 바꾸면 바로 반영되도록 늘 최신 저장 정보를 읽는다
    private var place: SavedPlace {
        app.places.first { $0.id == opened.id } ?? opened
    }
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var showEdit = false
    @State private var info: PlaceInfo
    @State private var isLoadingInfo: Bool
    @State private var openedPhoto: PlacePhoto?
    @State private var webPage: WebPage?

    init(place: SavedPlace) {
        self.opened = place
        // 미리보기에서 이미 받아 둔 사진·후기가 있으면 바로 쓴다
        let cached = PlaceInfoService.shared.cachedInfo(for: place.lookup)
        _info = State(initialValue: cached ?? PlaceInfo())
        _isLoadingInfo = State(initialValue: cached == nil && PlaceInfoService.isAvailable)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        PlacePhotoStrip(photos: info.photos, isLoading: isLoadingInfo) { openedPhoto = $0 }

                        PlaceMapPreview(place: place)

                        infoCard

                        PlaceReviewsSection(posts: info.posts) { webPage = WebPage(url: $0) }

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

                        PlaceActionButtons(
                            lookup: place.lookup,
                            name: place.name,
                            coordinate: place.coordinate,
                            openWeb: { webPage = WebPage(url: $0) }
                        )

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
                ToolbarItem(placement: .topBarLeading) {
                    Button("수정") { showEdit = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showEdit) {
                EditPlaceView(place: place)
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
                guard isLoadingInfo else { return }
                info = await PlaceInfoService.shared.info(for: place.lookup)
                isLoadingInfo = false
            }
        }
    }

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

                Text([PlaceFormat.distanceFromMe(to: place.coordinate).map { "내 위치에서 \($0)" }, place.address]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.hand(18))
                    .foregroundStyle(palette.textSecondary)

                if let link = place.link, let url = URL(string: link) {
                    PlaceLinkButton(url: url) { webPage = WebPage(url: url) }
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
}

// MARK: - 수정 (카테고리 · 메모)

struct EditPlaceView: View {
    let place: SavedPlace

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var categoryID: String
    @State private var memo: String

    init(place: SavedPlace) {
        self.place = place
        _categoryID = State(initialValue: place.categoryID)
        _memo = State(initialValue: place.memo)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(.hand(24, bold: true))
                                .foregroundStyle(palette.textPrimary)
                            Text(place.address)
                                .font(.hand(16))
                                .foregroundStyle(palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                        CategoryPicker(selection: $categoryID)

                        CuteCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("메모")
                                    .font(.hand(18, bold: true))
                                    .foregroundStyle(palette.textSecondary)
                                TextField("여기 왜 가고 싶은지 적어두면 좋아요", text: $memo, axis: .vertical)
                                    .font(.hand(20))
                                    .lineLimit(3...8)
                            }
                        }

                        Button("저장하기") { save() }
                            .buttonStyle(.soft)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("장소 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    private func save() {
        var updated = place
        updated.categoryID = categoryID
        updated.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { await app.updatePlace(updated) }
        dismiss()
    }
}

// MARK: - 공용 부품

enum PlaceFormat {
    /// 350m / 1.2km
    nonisolated static func distance(_ meters: Double) -> String {
        meters < 1000 ? "\(Int(meters.rounded()))m" : String(format: "%.1fkm", meters / 1000)
    }

    /// 내 위치에서 그곳까지의 거리. 위치 권한이 없거나 아직 위치를 모르면 nil.
    /// (검색 API 가 주는 거리는 검색 기준점 — 지도 가운데나 누른 자리 — 에서 잰 값이라 쓰지 않는다)
    static func distanceFromMe(to coordinate: CLLocationCoordinate2D) -> String? {
        guard let me = MyLocation.current else { return nil }
        let there = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return distance(me.distance(from: there))
    }
}

/// 폰이 알고 있는 내 현재 위치 (지도가 위치를 받는 동안 계속 새로 고쳐진다)
enum MyLocation {
    private static let manager = CLLocationManager()

    static var current: CLLocation? {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // 너무 오래된 위치(30분 이상)는 거리 표시에 쓰지 않는다
            guard let location = manager.location, location.timestamp.timeIntervalSinceNow > -1800 else { return nil }
            return location
        default:
            return nil
        }
    }
}

/// 가로로 넘기는 사진 줄. 받는 동안은 빈 칸을 보여준다.
struct PlacePhotoStrip: View {
    let photos: [PlacePhoto]
    let isLoading: Bool
    let onOpen: (PlacePhoto) -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        if isLoading {
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
        } else if !photos.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            Button {
                                onOpen(photo)
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
}

/// 블로그 후기 목록
struct PlaceReviewsSection: View {
    let posts: [BlogPost]
    let onOpen: (URL) -> Void

    var body: some View {
        if !posts.isEmpty {
            VStack(spacing: 10) {
                SectionHeader(title: "블로그 후기")

                CuteCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            Button {
                                onOpen(post.url)
                            } label: {
                                BlogPostRow(post: post)
                            }
                            .buttonStyle(.plain)

                            if index < posts.count - 1 {
                                SketchDivider(seed: UInt64(index) &+ 80)
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// 손으로 움직일 수 없는 작은 지도
struct PlaceMapPreview: View {
    private enum Pin {
        case saved(SavedPlace)
        case result(PlaceSearchResult)
    }

    private let pin: Pin

    init(place: SavedPlace) { pin = .saved(place) }
    init(result: PlaceSearchResult) { pin = .result(result) }

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    private var coordinate: CLLocationCoordinate2D {
        switch pin {
        case .saved(let place): place.coordinate
        case .result(let result): result.coordinate
        }
    }

    var body: some View {
        map
            .frame(height: 150)
            .clipShape(.rect(cornerRadius: 6))
            .sketchBox(seed: sketchSeed("\(coordinate.latitude),\(coordinate.longitude)"), fill: .clear)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var map: some View {
        if AppEnvironment.useNaverMaps {
            switch pin {
            case .saved(let place):
                NaverPlacesMap(places: [place], categoryFor: { app.category(id: $0) },
                               focus: MapFocus(coordinate: coordinate, zoom: 16), interactive: false)
            case .result(let result):
                NaverPlacesMap(places: [], searchResults: [result], categoryFor: { app.category(id: $0) },
                               focus: MapFocus(coordinate: coordinate, zoom: 16), interactive: false)
            }
        } else {
            Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 600, longitudinalMeters: 600))) {
                switch pin {
                case .saved(let place):
                    Annotation(place.name, coordinate: coordinate) {
                        PlacePin(category: app.category(id: place.categoryID), isVisited: place.isVisited)
                    }
                case .result(let result):
                    Annotation(result.name, coordinate: coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(palette.pen)
                    }
                }
            }
        }
    }
}

/// 가게 링크 (카카오맵 정보 / 인스타그램 / 홈페이지)
struct PlaceLinkButton: View {
    let url: URL
    let onOpen: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: onOpen) {
            Label(Self.title(for: url), systemImage: "link")
                .font(.hand(18, bold: true))
                .foregroundStyle(palette.pen)
        }
        .buttonStyle(.plain)
    }

    static func title(for url: URL) -> String {
        let host = url.host() ?? ""
        if host.contains("place.map.kakao") { return "카카오맵 정보 (영업시간·메뉴·리뷰)" }
        if host.contains("instagram") { return "인스타그램" }
        if host.contains("blog.naver") { return "블로그" }
        return "홈페이지"
    }
}

/// 네이버 지도에서 자세히 보기 + 길찾기
struct PlaceActionButtons: View {
    let lookup: PlaceLookup
    let name: String
    let coordinate: CLLocationCoordinate2D
    /// 앱이 없을 때 웹페이지를 앱 안에서 연다
    let openWeb: (URL) -> Void

    var body: some View {
        VStack(spacing: 16) {
            if AppEnvironment.useNaverMaps {
                Button {
                    openNaverPlacePage()
                } label: {
                    Label("네이버 지도에서 자세히 보기", systemImage: "info.circle")
                }
                .buttonStyle(.softTinted)
            }

            Button {
                openDirections()
            } label: {
                Label("길찾기", systemImage: "arrow.triangle.turn.up.right.circle.fill")
            }
            .buttonStyle(.softTinted)
        }
    }

    /// 네이버 지도 앱이 있으면 앱에서, 없으면 웹페이지로 검색
    private func openNaverPlacePage() {
        let query = PlaceInfoService.query(for: lookup)
        let web = NaverMapLink.searchWebURL(query: query)
        guard let appURL = NaverMapLink.searchAppURL(query: query) else {
            if let web { openWeb(web) }
            return
        }
        UIApplication.shared.open(appURL) { opened in
            if !opened, let web { openWeb(web) }
        }
    }

    /// 네이버 지도 앱이 있으면 거기서, 없으면 Apple 지도에서 연다.
    private func openDirections() {
        let openApple = {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            item.name = name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        }
        guard let url = NaverMapLink.placeURL(name: name, coordinate: coordinate) else {
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
    /// 마지막으로 고른 정렬을 기억한다 (기본: 최신순)
    @AppStorage("savedPlaces.sort") private var sort: PlaceSort = .latest

    enum PlaceSort: String, CaseIterable {
        case latest, nearest
        var title: String {
            switch self {
            case .latest: "최신순"
            case .nearest: "가까운순"
            }
        }
    }

    private var filtered: [SavedPlace] {
        let base = selectedCategoryID.map { id in app.places.filter { $0.categoryID == id } } ?? app.places
        switch sort {
        case .nearest:
            // 내 위치를 모르면 가까운순을 할 수 없어서 최신순으로 보여준다
            guard let me = MyLocation.current else { return base.sorted { $0.createdAt > $1.createdAt } }
            func distance(_ place: SavedPlace) -> CLLocationDistance {
                me.distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude))
            }
            return base.sorted { distance($0) < distance($1) }
        case .latest:
            return base.sorted { $0.createdAt > $1.createdAt }
        }
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

                        if !app.places.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                SketchPicker(selection: $sort, options: PlaceSort.allCases.map { ($0, $0.title) })
                                if sort == .nearest && MyLocation.current == nil {
                                    Text("내 위치를 알 수 없어서 최신순으로 보여주고 있어요")
                                        .font(.hand(14))
                                        .foregroundStyle(palette.textSecondary)
                                        .padding(.horizontal, 4)
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

                if let distance = PlaceFormat.distanceFromMe(to: place.coordinate) {
                    Text(distance)
                        .font(.hand(16))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}
