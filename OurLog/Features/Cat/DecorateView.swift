//
//  DecorateView.swift
//  OurLog
//
//  고양이 꾸미기 / 집 꾸미기.
//  모든 아이템은 처음부터 열려 있다. 진화 단계와 무관하게 마음대로 골라 입힌다.
//

import SwiftUI

struct DecorateView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case cat, room
        var id: String { rawValue }
        var title: String {
            switch self {
            case .cat: "고양이 꾸미기"
            case .room: "집 꾸미기"
            }
        }
    }

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var tab: Tab = .cat

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                VStack(spacing: 14) {
                    preview

                    Picker("", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)

                    ScrollView {
                        VStack(spacing: 18) {
                            switch tab {
                            case .cat:
                                ForEach(AccessorySlot.allCases, id: \.self) { slot in
                                    accessorySection(slot)
                                }
                            case .room:
                                ForEach(RoomSlot.allCases, id: \.self) { slot in
                                    roomSection(slot)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("꾸미기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
            }
        }
    }

    // MARK: 미리보기

    private var preview: some View {
        Group {
            switch tab {
            case .cat:
                CatPortrait(stage: app.cat.stage, accessories: app.equippedAccessories, size: 170)
            case .room:
                PixelRoomView(
                    stage: app.cat.stage,
                    accessories: app.equippedAccessories,
                    placedItems: app.placedRoomItems
                )
                .clipShape(.rect(cornerRadius: 12))
            }
        }
        .frame(height: 180)
        .padding(.horizontal, 20)
    }

    // MARK: 액세서리

    private func accessorySection(_ slot: AccessorySlot) -> some View {
        let items = DecorCatalog.accessories.filter { $0.slot == slot }
        let equippedID = app.cat.equippedAccessories[slot]

        return VStack(spacing: 10) {
            SectionHeader(title: slot.label)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 10)], spacing: 10) {
                DecorTile(
                    sprite: nil,
                    name: "없음",
                    isSelected: equippedID == nil
                ) {
                    Task { await app.equip(nil, slot: slot) }
                }

                ForEach(items) { item in
                    DecorTile(
                        sprite: AccessorySprites.all[item.id],
                        name: item.name,
                        isSelected: equippedID == item.id
                    ) {
                        Task { await app.equip(item, slot: slot) }
                    }
                }
            }
        }
    }

    // MARK: 방 아이템

    private func roomSection(_ slot: RoomSlot) -> some View {
        let items = DecorCatalog.roomItems.filter { $0.slot == slot }
        let placedID = app.cat.placedRoomItems[slot]

        return VStack(spacing: 10) {
            SectionHeader(title: slot.label)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 10)], spacing: 10) {
                DecorTile(
                    sprite: nil,
                    name: "없음",
                    isSelected: placedID == nil
                ) {
                    Task { await app.placeRoomItem(nil, slot: slot) }
                }

                ForEach(items) { item in
                    DecorTile(
                        sprite: RoomSprites.items[item.id]?.sprite,
                        name: item.name,
                        isSelected: placedID == item.id
                    ) {
                        Task { await app.placeRoomItem(item, slot: slot) }
                    }
                }
            }
        }
    }
}

// MARK: - 타일

private struct DecorTile: View {
    /// nil 이면 "없음" 타일
    let sprite: PixelSprite?
    let name: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Group {
                    if let sprite {
                        PixelSpriteView(sprite: sprite)
                    } else {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .frame(width: 40, height: 34)

                Text(name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? palette.primarySoft : palette.surface, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? palette.primary : palette.outline, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DecorateView()
        .environment(AppEnvironment.makeAppState())
        .environment(\.palette, AppTheme.peach.palette)
}
