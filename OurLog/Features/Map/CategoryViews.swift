//
//  CategoryViews.swift
//  OurLog
//
//  장소 카테고리 관리 — 추가 · 수정 · 삭제. 두 사람에게 공유된다.
//

import SwiftUI

// MARK: - 목록

struct CategoryManagerView: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var editing: PlaceCategory?
    @State private var isAdding = false
    @State private var deleting: PlaceCategory?

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        CuteCard(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(Array(app.categories.enumerated()), id: \.element.id) { index, category in
                                    row(category)
                                    if index < app.categories.count - 1 {
                                        SketchDivider(seed: UInt64(index) &+ 120).padding(.horizontal, 12)
                                    }
                                }
                            }
                        }

                        Button {
                            isAdding = true
                        } label: {
                            Label("카테고리 추가", systemImage: "plus")
                        }
                        .buttonStyle(.soft)

                        Text("카테고리는 둘이 함께 써요. 지우면 그 안의 장소는 다른 카테고리로 옮겨져요.")
                            .font(.hand(15))
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                }
            }
            .paperTitle("카테고리")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarTextButton("닫기") { dismiss() }
                }
            }
            .sheet(item: $editing) { CategoryEditorView(category: $0) }
            .sheet(isPresented: $isAdding) { CategoryEditorView(category: nil) }
            .confirmationDialog(
                deleteTitle,
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible,
                presenting: deleting
            ) { category in
                Button("삭제", role: .destructive) {
                    Task { await app.deleteCategory(category) }
                }
            } message: { category in
                Text(deleteMessage(category))
            }
        }
    }

    private func row(_ category: PlaceCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .sketchCircle(fill: category.color, seed: sketchSeed(category.id), size: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(category.name)
                    .font(.hand(20, bold: true))
                    .foregroundStyle(palette.textPrimary)
                Text("장소 \(app.placeCount(in: category.id))곳")
                    .font(.hand(15))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()

            Button {
                editing = category
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            // 마지막 하나는 지울 수 없다
            if app.categories.count > 1 {
                Button {
                    deleting = category
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }

    private var deleteTitle: String {
        deleting.map { "'\($0.name)' 카테고리를 지울까요?" } ?? ""
    }

    private func deleteMessage(_ category: PlaceCategory) -> String {
        let count = app.placeCount(in: category.id)
        guard count > 0, let fallback = app.fallbackCategory(excluding: category.id) else {
            return "이 카테고리에는 장소가 없어요."
        }
        return "이 카테고리의 장소 \(count)곳은 '\(fallback.name)'(으)로 옮겨져요."
    }
}

// MARK: - 추가 / 수정

struct CategoryEditorView: View {
    /// nil 이면 새로 만든다
    let category: PlaceCategory?

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var symbol: String
    @State private var colorHex: UInt32

    static let symbols = [
        "fork.knife", "cup.and.saucer.fill", "heart.fill", "airplane", "star.fill",
        "wineglass.fill", "birthday.cake.fill", "cart.fill", "bag.fill", "film.fill",
        "music.note", "book.fill", "camera.fill", "leaf.fill", "tree.fill",
        "figure.walk", "gamecontroller.fill", "pawprint.fill", "house.fill", "sparkles",
    ]

    static let colors: [UInt32] = [
        0xF08A6E, 0xFF8FA3, 0xE06C9F, 0xA78BFA, 0x5BA9E8,
        0x4FB6B0, 0x76C08A, 0xF0C04E, 0xB08663, 0x8E8A84,
    ]

    init(category: PlaceCategory?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _symbol = State(initialValue: category?.symbol ?? "star.fill")
        _colorHex = State(initialValue: category?.colorHex ?? 0xFF8FA3)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        // 미리보기
                        HStack(spacing: 6) {
                            Image(systemName: symbol).font(.system(size: 12, weight: .bold))
                            Text(trimmedName.isEmpty ? "카테고리" : trimmedName)
                                .font(.hand(19, bold: true))
                        }
                        .foregroundStyle(Color(hex: colorHex))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .sketchBox(seed: 71, fill: palette.card, stroke: Color(hex: colorHex), roughness: 1.1, lineWidth: 1.6)

                        CuteCard {
                            VStack(alignment: .leading, spacing: 8) {
                                label("이름")
                                TextField("예: 전시회, 산책길", text: $name)
                                    .font(.hand(20))
                                    .sketchField()
                            }
                        }

                        CuteCard {
                            VStack(alignment: .leading, spacing: 10) {
                                label("아이콘")
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                                    ForEach(Self.symbols, id: \.self) { item in
                                        Button { symbol = item } label: {
                                            Image(systemName: item)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(symbol == item ? palette.ink : palette.inkSoft)
                                                .sketchCircle(
                                                    fill: symbol == item ? Color(hex: colorHex).opacity(0.3) : palette.card,
                                                    seed: sketchSeed(item),
                                                    size: 44
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        CuteCard {
                            VStack(alignment: .leading, spacing: 10) {
                                label("색")
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                                    ForEach(Self.colors, id: \.self) { hex in
                                        Button { colorHex = hex } label: {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .heavy))
                                                .foregroundStyle(.white)
                                                .opacity(colorHex == hex ? 1 : 0)
                                                .sketchCircle(fill: Color(hex: hex), seed: UInt64(hex), size: 40)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Button(category == nil ? "추가하기" : "저장하기") { save() }
                            .buttonStyle(.soft)
                            .disabled(trimmedName.isEmpty || isDuplicateName)

                        if isDuplicateName {
                            Text("같은 이름의 카테고리가 이미 있어요")
                                .font(.hand(15))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(20)
                }
            }
            .paperTitle(category == nil ? "새 카테고리" : "카테고리 수정")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ToolbarTextButton("취소") { dismiss() }
                }
            }
        }
    }

    private var isDuplicateName: Bool {
        app.categories.contains { $0.name == trimmedName && $0.id != category?.id }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.hand(18, bold: true))
            .foregroundStyle(palette.textSecondary)
    }

    private func save() {
        var updated = category ?? PlaceCategory(
            id: "cat-\(UUID().uuidString)",
            name: trimmedName,
            symbol: symbol,
            colorHex: colorHex,
            createdAt: .now
        )
        updated.name = trimmedName
        updated.symbol = symbol
        updated.colorHex = colorHex
        Task { await app.saveCategory(updated) }
        dismiss()
    }
}
