//
//  RecentSearchViews.swift
//  OurLog
//
//  검색창을 누르면 뜨는 최근 검색어 · 최근 본 장소 목록과, 여러 개를 골라 지우는 편집 화면.
//

import SwiftUI
import CoreLocation

// MARK: - 목록

struct RecentSearchList: View {
    /// 검색창에 친 글자. 비어 있지 않으면 그 글자가 들어간 기록만 보여준다.
    let filter: String
    let onSelect: (RecentSearch) -> Void

    @Environment(\.palette) private var palette
    @State private var store = RecentSearchStore.shared
    @State private var isEditing = false
    /// 목록 내용 높이 (적으면 그만큼만 창을 그린다)
    @State private var rowsHeight: CGFloat = 0
    /// 키보드 윗변 위치(화면 기준). 키보드가 올라오면 창을 그 위까지만 그린다.
    @State private var keyboardTop: CGFloat = .infinity
    @State private var boxTop: CGFloat = 0

    private var maxBoxHeight: CGFloat {
        keyboardTop == .infinity ? .infinity : max(120, keyboardTop - boxTop - 8)
    }

    private var visibleItems: [RecentSearch] {
        let keyword = Self.normalize(filter)
        guard !keyword.isEmpty else { return store.items }
        return store.items.filter { Self.normalize($0.title).contains(keyword) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("최근 기록")
                    .font(.hand(19, bold: true))
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                if !store.items.isEmpty {
                    Button("편집") { isEditing = true }
                        .font(.hand(18, bold: true))
                        .foregroundStyle(palette.pen)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            SketchDivider(seed: 61).padding(.horizontal, 12)

            if visibleItems.isEmpty {
                Text(store.items.isEmpty ? "최근 검색한 기록이 없어요" : "맞는 기록이 없어요")
                    .font(.hand(17))
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else {
                // 기록이 적으면 그만큼만, 많으면 화면 끝까지 늘리고 스크롤한다
                ScrollView {
                    rows.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowsHeight = $0 }
                }
                .frame(maxHeight: rowsHeight)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: maxBoxHeight, alignment: .top)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { boxTop = $0 }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.25)) { keyboardTop = frame.minY }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardTop = .infinity }
        }
        .sketchBox(seed: 357, fill: palette.surface, roughness: 1.3, lineWidth: 1.6)
        .sheet(isPresented: $isEditing) {
            RecentSearchEditView()
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(visibleItems) { item in
                HStack(spacing: 12) {
                    Button { onSelect(item) } label: {
                        RecentSearchRow(item: item)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.snappy) { store.remove(ids: [item.id]) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 10)
                .padding(.leading, 16)
                .padding(.trailing, 8)

                if item.id != visibleItems.last?.id {
                    SketchDivider(seed: sketchSeed(item.key))
                        .padding(.leading, 62)
                        .padding(.trailing, 12)
                }
            }
        }
        .padding(.bottom, 4)
    }

    static func normalize(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace }
    }
}

/// 아이콘 + 이름 + 날짜 한 줄 (목록·편집 화면 공용)
private struct RecentSearchRow: View {
    let item: RecentSearch

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            icon

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.hand(19, bold: true))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                if case .place(let result) = item.kind, !result.address.isEmpty {
                    Text(result.address)
                        .font(.hand(15))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(Self.dateText(item.date))
                .font(.hand(16))
                .foregroundStyle(palette.textSecondary)
        }
        .contentShape(.rect)
    }

    /// "10.20." 처럼 붙여서 쓴다
    private static func dateText(_ date: Date) -> String {
        let parts = Calendar.dday.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0).\(parts.day ?? 0)."
    }

    @ViewBuilder
    private var icon: some View {
        switch item.kind {
        case .query:
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(palette.ink)
                .sketchCircle(fill: palette.surfaceAlt, seed: 365, size: 34)
        case .place(let result):
            // 저장한 곳이면 그 카테고리 아이콘으로
            if let saved = app.savedPlace(matching: result) {
                PlaceIcon(category: app.category(id: saved.categoryID))
            } else {
                Image(systemName: "mappin")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .sketchCircle(fill: palette.surfaceAlt, seed: 366, size: 34)
            }
        }
    }

}

extension AppState {
    /// 검색 결과(또는 기록)가 이미 저장한 곳인지 (이름이 같고 100m 안)
    func savedPlace(matching result: PlaceSearchResult) -> SavedPlace? {
        let here = CLLocation(latitude: result.latitude, longitude: result.longitude)
        return places.first {
            $0.name == result.name
                && CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: here) < 100
        }
    }
}

// MARK: - 편집

struct RecentSearchEditView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var store = RecentSearchStore.shared
    @State private var selected: Set<RecentSearch.ID> = []

    private var allSelected: Bool {
        !store.items.isEmpty && selected.count == store.items.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.items) { item in
                                let isOn = selected.contains(item.id)
                                Button {
                                    if isOn { selected.remove(item.id) } else { selected.insert(item.id) }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundStyle(isOn ? palette.pen : palette.inkSoft)
                                        RecentSearchRow(item: item)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)

                                SketchDivider(seed: sketchSeed(item.key))
                                    .padding(.leading, 50)
                                    .padding(.trailing, 16)
                            }
                        }
                        .padding(.top, 8)
                    }

                    HStack(spacing: 10) {
                        Button(allSelected ? "선택 해제" : "전체 선택") {
                            selected = allSelected ? [] : Set(store.items.map(\.id))
                        }
                        .buttonStyle(.softTinted)

                        Button("삭제 \(selected.count)") {
                            store.remove(ids: selected)
                            selected = []
                            if store.items.isEmpty { dismiss() }
                        }
                        .buttonStyle(.soft)
                        .disabled(selected.isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
            .paperTitle("최근 기록 편집")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarTextButton("닫기") { dismiss() }
                }
            }
        }
    }
}
