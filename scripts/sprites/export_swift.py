#!/usr/bin/env python3
"""
도트 스프라이트를 Swift 소스(SpriteData.swift)로 내보낸다.

    python3 scripts/sprites/export_swift.py

final.py (고양이) · decor.py (착용 아이템) · room.py (방) 을 고친 뒤 다시 돌리면 된다.
"""
import os
import final, decor, room

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'OurLog', 'Features', 'Cat', 'SpriteData.swift')

final.check()

CAT_PALETTE = {
    '#': 0x5B3B34, 'w': 0xF9F3EF, 'v': 0xEEE2DA, 'h': 0xFFFFFF, 'g': 0xB7ABAA,
    's': 0x948280, 'k': 0xF4C0BC, 'c': 0xF6E9DB, 'C': 0xECDAC0, 'r': 0xF06080, '*': 0xF2CC55,
}
PALETTE = dict(CAT_PALETTE)
for k, (r, g, b) in list(decor.EXTRA.items()) + list(room.ROOM_EXTRA.items()):
    assert k not in PALETTE, f"팔레트 문자 겹침: {k}"
    PALETTE[k] = (r << 16) | (g << 8) | b

STAGE_CASES = [('egg', 'egg'), ('cracked', 'crackedEgg'), ('kitten', 'kitten'),
               ('teen', 'teen'), ('adult', 'adult'), ('radiant', 'radiant')]

ACC_NAMES = {
    'acc-ribbon': '리본', 'acc-crown': '왕관', 'acc-flower': '꽃 핀', 'acc-beret': '베레모',
    'acc-scarf': '목도리', 'acc-bell': '방울 목걸이', 'acc-bowtie': '나비 넥타이',
    'acc-glasses': '금테 안경', 'acc-sunglasses': '선글라스',
}


def sprite(rows, indent=8):
    pad = ' ' * indent
    body = "".join(f'{pad}    "{r}",\n' for r in rows)
    return f"PixelSprite(rows: [\n{body}{pad}])"


def check_chars(name, rows):
    for r in rows:
        for ch in r:
            assert ch == '.' or ch in PALETTE, f"{name}: 팔레트에 없는 문자 {ch!r}"


L = []
L.append('''//
//  SpriteData.swift
//  OurLog
//
//  도트 스프라이트 데이터. 자동 생성 파일이니 직접 고치지 말고
//  scripts/sprites/ 의 파이썬 원본을 고친 뒤 export_swift.py 를 다시 돌릴 것.
//

import SwiftUI

// MARK: - 팔레트

nonisolated enum PixelPalette {
    static let colors: [Character: Color] = [
''')
for k, v in PALETTE.items():
    key = k.replace('\\', '\\\\').replace('"', '\\"')
    L.append(f'        "{key}": Color(hex: 0x{v:06X}),\n')
L.append('    ]\n}\n\n')

# ── 고양이
L.append('// MARK: - 고양이\n\nnonisolated enum CatSprites {\n')
for key, case in STAGE_CASES:
    st = final.STAGES[key]
    check_chars(key, st['frames'][0])
    L.append(f"    static let {case}Idle = {sprite(st['frames'][0], 4)}\n\n")
    if 'blink' in st:
        check_chars(key + ' blink', st['blink'])
        L.append(f"    static let {case}Blink = {sprite(st['blink'], 4)}\n\n")
L.append('''    static func idle(_ stage: CatStage) -> PixelSprite {
        switch stage {
        case .egg: eggIdle
        case .crackedEgg: crackedEggIdle
        case .kitten: kittenIdle
        case .teen: teenIdle
        case .adult: adultIdle
        case .radiant: radiantIdle
        }
    }

    /// 눈을 뜨고 있는 단계만 깜빡임 프레임이 있다.
    static func blink(_ stage: CatStage) -> PixelSprite? {
        switch stage {
        case .crackedEgg: crackedEggBlink
        case .teen: teenBlink
        default: nil
        }
    }

    /// 착용 아이템이 붙는 자리 (스프라이트 안 좌표, 칸 단위).
    /// head 는 아이템 아랫줄 가운데, face 는 아이템 가운데, neck 은 아이템 윗줄 가운데가 여기에 온다.
    static func anchor(_ stage: CatStage, _ slot: AccessorySlot) -> (x: Double, y: Int)? {
        switch (stage, slot) {
''')
for key, case in STAGE_CASES:
    if key not in decor.ANCHORS:
        continue
    for slot, (x, y) in decor.ANCHORS[key].items():
        L.append(f"        case (.{case}, .{slot}): ({x}, {y})\n")
L.append('        default: nil\n        }\n    }\n}\n\n')

# ── 착용 아이템
L.append('// MARK: - 착용 아이템\n\nnonisolated enum AccessorySprites {\n    static let all: [String: PixelSprite] = [\n')
for acc_id, (slot, art) in decor.ACCESSORIES.items():
    check_chars(acc_id, art)
    L.append(f'        "{acc_id}": {sprite(art, 8)},\n')
L.append('    ]\n}\n\n')

# ── 방
L.append('// MARK: - 방\n\nnonisolated enum RoomSprites {\n')
L.append(f'    static let width = {room.ROOM_W}\n    static let height = {room.ROOM_H}\n')
L.append(f'    /// 고양이 발바닥 줄과 가운데 x (칸 단위)\n')
L.append(f'    static let catFootY = {room.CAT_FOOT_Y}\n    static let catCenterX = {room.CAT_CENTER_X}\n\n')
bg = room.background()
check_chars('background', bg)
L.append(f'    static let background = {sprite(bg, 4)}\n\n')
L.append('    /// 아이템 스프라이트와 방 안에서의 왼쪽 위 좌표\n')
L.append('    static let items: [String: (sprite: PixelSprite, x: Int, y: Int)] = [\n')
for item_id, (slot, name, art) in room.ROOM_ITEMS.items():
    check_chars(item_id, art)
    x, y = room.slot_origin(slot, art)
    L.append(f'        "{item_id}": ({sprite(art, 8)}, {x}, {y}),\n')
L.append('    ]\n}\n\n')

# ── 카탈로그
L.append('// MARK: - 카탈로그\n\nnonisolated enum DecorCatalog {\n    static let accessories: [CatAccessory] = [\n')
for acc_id, (slot, art) in decor.ACCESSORIES.items():
    L.append(f'        CatAccessory(id: "{acc_id}", name: "{ACC_NAMES[acc_id]}", slot: .{slot}),\n')
L.append('    ]\n\n    static let roomItems: [RoomItem] = [\n')
for item_id, (slot, name, art) in room.ROOM_ITEMS.items():
    L.append(f'        RoomItem(id: "{item_id}", name: "{name}", slot: .{slot}),\n')
L.append('''    ]

    static func accessory(id: String) -> CatAccessory? { accessories.first { $0.id == id } }
    static func roomItem(id: String) -> RoomItem? { roomItems.first { $0.id == id } }
}
''')

src = "".join(L)
open(OUT, 'w').write(src)
print("wrote", os.path.normpath(OUT), len(src), "bytes")
