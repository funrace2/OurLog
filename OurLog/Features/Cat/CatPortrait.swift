//
//  CatPortrait.swift
//  OurLog
//
//  도트 고양이 한 마리. 단계 스프라이트 위에 착용 아이템을 얹고,
//  숨쉬기 · 깜빡임 · 쓰다듬으면 폴짝 같은 작은 움직임을 붙인다.
//

import SwiftUI

// MARK: - 합성

enum CatComposer {
    /// 모든 단계를 같은 칸 크기로 그리는 공통 캔버스.
    /// 가장 큰 단계(반짝 고양이 33칸)와, 머리 위로 솟는 왕관 높이까지 들어가는 크기.
    static let canvas = 33

    private static var cache: [String: PixelSprite] = [:]

    static func compose(stage: CatStage, accessoryIDs: [AccessorySlot: String], blink: Bool) -> PixelSprite {
        let key = "\(stage.rawValue)|\(blink)|" + AccessorySlot.allCases.map { accessoryIDs[$0] ?? "-" }.joined(separator: ",")
        if let cached = cache[key] { return cached }

        let base = (blink ? CatSprites.blink(stage) : nil) ?? CatSprites.idle(stage)
        var grid = PixelSprite.blank(width: canvas, height: canvas)
        // 아래 가운데 정렬
        let ox = (canvas - base.width) / 2
        let oy = canvas - base.height
        PixelSprite.stamp(base, at: ox, oy, into: &grid)

        // 얼굴 → 목 → 머리 순으로 얹는다 (모자가 맨 위에 오도록)
        for slot in [AccessorySlot.face, .neck, .head] {
            guard let id = accessoryIDs[slot],
                  let item = AccessorySprites.all[id],
                  let anchor = CatSprites.anchor(stage, slot)
            else { continue }

            // 스크립트(파이썬 round)와 똑같이 반올림해야 미리보기와 위치가 맞는다
            let x = Int((anchor.x - Double(item.width) / 2).rounded(.toNearestOrEven))
            let y: Int
            switch slot {
            case .head: y = anchor.y - item.height + 1
            case .face: y = Int((Double(anchor.y) - Double(item.height) / 2).rounded(.toNearestOrEven))
            case .neck: y = anchor.y
            }
            PixelSprite.stamp(item, at: ox + x, oy + y, into: &grid)
        }

        let sprite = PixelSprite(grid: grid)
        cache[key] = sprite
        return sprite
    }
}

// MARK: - 고양이

struct CatPortrait: View {
    let stage: CatStage
    var accessories: [AccessorySlot: CatAccessory] = [:]
    var size: CGFloat = 200
    /// 쓰다듬는 순간 폴짝 뛴다.
    var isBeingPetted: Bool = false

    @State private var blinking = false
    @State private var breathe = false
    @State private var hop = false
    @State private var tilt: Double = 0

    private var accessoryIDs: [AccessorySlot: String] {
        accessories.mapValues(\.id)
    }

    var body: some View {
        PixelSpriteView(
            sprite: CatComposer.compose(stage: stage, accessoryIDs: accessoryIDs, blink: blinking)
        )
        .frame(width: size, height: size)
        // 숨쉬기: 바닥에 붙은 채로 살짝 눌렸다 펴진다
        .scaleEffect(x: breathe ? 1.025 : 1, y: breathe ? 0.97 : 1, anchor: .bottom)
        .rotationEffect(.degrees(tilt), anchor: .bottom)
        .offset(y: hop ? -size * 0.07 : 0)
        .onAppear {
            withAnimation(.easeInOut(duration: stage == .egg ? 1.8 : 1.3).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .task(id: stage) { await blinkLoop() }
        .task(id: stage) { await idleLoop() }
        .onChange(of: isBeingPetted) { _, petted in
            guard petted else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) { hop = true }
            Task {
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { hop = false }
            }
        }
        .accessibilityLabel("\(stage.displayName)")
    }

    /// 눈 뜬 단계는 가끔 깜빡인다.
    private func blinkLoop() async {
        guard CatSprites.blink(stage) != nil else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.5...5)))
            blinking = true
            try? await Task.sleep(for: .milliseconds(160))
            blinking = false
        }
    }

    /// 알은 가끔 들썩이고, 고양이는 고개를 갸웃한다.
    private func idleLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 3...6)))
            if stage == .egg || stage == .crackedEgg {
                for angle in [-5.0, 5, -3, 3, 0] {
                    withAnimation(.easeInOut(duration: 0.09)) { tilt = angle }
                    try? await Task.sleep(for: .milliseconds(90))
                }
            } else {
                let angle = Bool.random() ? 3.0 : -3.0
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { tilt = angle }
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { tilt = 0 }
            }
        }
    }
}

// MARK: - 방

/// 도트 방. 배경과 벽·창가·바닥 아이템을 깔고, 고양이를 그 위에, 옆자리 소품을 맨 앞에 둔다.
struct PixelRoomView: View {
    let stage: CatStage
    var accessories: [AccessorySlot: CatAccessory] = [:]
    var placedItems: [RoomSlot: RoomItem] = [:]
    var isBeingPetted = false

    var body: some View {
        GeometryReader { geo in
            let unit = geo.size.width / CGFloat(RoomSprites.width)
            let catSize = unit * CGFloat(CatComposer.canvas)

            ZStack(alignment: .topLeading) {
                PixelSpriteView(sprite: backLayer)

                CatPortrait(stage: stage, accessories: accessories, size: catSize, isBeingPetted: isBeingPetted)
                    .offset(
                        x: unit * CGFloat(RoomSprites.catCenterX) - catSize / 2 + unit / 2,
                        y: unit * CGFloat(RoomSprites.catFootY + 1) - catSize
                    )

                PixelSpriteView(sprite: frontLayer)
                    .allowsHitTesting(false)
            }
        }
        .aspectRatio(CGFloat(RoomSprites.width) / CGFloat(RoomSprites.height), contentMode: .fit)
    }

    private var backLayer: PixelSprite {
        var grid = RoomSprites.background.rows.map(Array.init)
        for slot in [RoomSlot.wall, .window, .floor] {
            stampItem(slot, into: &grid)
        }
        return PixelSprite(grid: grid)
    }

    private var frontLayer: PixelSprite {
        var grid = PixelSprite.blank(width: RoomSprites.width, height: RoomSprites.height)
        stampItem(.side, into: &grid)
        return PixelSprite(grid: grid)
    }

    private func stampItem(_ slot: RoomSlot, into grid: inout [[Character]]) {
        guard let item = placedItems[slot], let entry = RoomSprites.items[item.id] else { return }
        PixelSprite.stamp(entry.sprite, at: entry.x, entry.y, into: &grid)
    }
}

// MARK: - 미리보기

#Preview("진화 단계") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 20) {
            ForEach(CatStage.allCases) { stage in
                VStack(spacing: 6) {
                    CatPortrait(stage: stage, size: 110)
                    Text("\(stage.rawValue)단계 · \(stage.displayName)").font(.caption)
                }
            }
        }
        .padding()
    }
}

#Preview("방") {
    PixelRoomView(
        stage: .adult,
        accessories: [.head: DecorCatalog.accessory(id: "acc-ribbon")!],
        placedItems: [
            .wall: DecorCatalog.roomItem(id: "room-frame")!,
            .window: DecorCatalog.roomItem(id: "room-plant")!,
            .floor: DecorCatalog.roomItem(id: "room-rug")!,
            .side: DecorCatalog.roomItem(id: "room-ball")!,
        ]
    )
    .padding()
}
