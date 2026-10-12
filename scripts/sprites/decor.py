"""
꾸미기 아이템 도트 스프라이트 + 단계별 부착 위치(앵커).

앵커 규칙 (스프라이트 좌표, 칸 단위)
  head : 아이템의 아래 가운데를 머리 꼭대기 가운데에 붙인다
  face : 아이템의 가운데를 두 눈 사이 가운데에 붙인다
  neck : 아이템의 위 가운데를 턱 밑 가운데에 붙인다
"""
import final

# 추가 색
EXTRA = {
    'p': (0xF2, 0x9C, 0xB2),  # 진한 분홍 (꽃잎)
    'R': (0xC8, 0x4A, 0x64),  # 진한 빨강
    'y': (0xF6, 0xD3, 0x65),  # 금색
    'Y': (0xC8, 0x96, 0x3C),  # 진한 금색
    'u': (0xC4, 0xAC, 0xE2),  # 라일락
    'U': (0x9C, 0x84, 0xC4),  # 진한 라일락
    'm': (0x96, 0xD0, 0xBE),  # 민트
    'M': (0x62, 0xA6, 0x92),  # 진한 민트
    'b': (0x96, 0xBC, 0xE6),  # 하늘
    'B': (0x62, 0x8C, 0xC4),  # 진한 하늘
    'G': (0x86, 0xC0, 0x78),  # 잎 초록
    'e': (0x3A, 0x32, 0x36),  # 선글라스 렌즈
}

ACCESSORIES = {
    # ── 머리
    'acc-ribbon': ('head', [
        ".##...##.",
        "#pp#.#pp#",
        "#ppp#ppp#",
        "#pp#R#pp#",
        ".##.#.##.",
    ]),
    'acc-crown': ('head', [
        "#...#...#",
        "##.###.##",
        "#y#yyy#y#",
        "#yyyyyyy#",
        "#yRyyyRy#",
        "#########",
    ]),
    'acc-flower': ('head', [
        "..#.#..",
        ".#p#p#.",
        "#ppypp#",
        ".#ppp#.",
        "..#G#..",
        "...#...",
    ]),
    'acc-beret': ('head', [
        "......#....",
        "...######..",
        ".##uuuuuu#.",
        "#uuuuuuuuu#",
        "#UUUUUUUUU#",
        ".#########.",
    ]),
    # ── 목
    'acc-scarf': ('neck', [
        ".###########.",
        "#mmMmmMmmMmm#",
        ".#####mm####.",
        ".....#mm#....",
        ".....#MM#....",
        "......##.....",
    ]),
    'acc-bell': ('neck', [
        "###########",
        "#RRRRRRRRR#",
        "####yyy####",
        "...#yYy#...",
        "....###....",
    ]),
    'acc-bowtie': ('neck', [
        "##.....##",
        "#bb###bb#",
        "#bbbBbbb#",
        "#bb###bb#",
        "##.....##",
    ]),
    # ── 얼굴
    'acc-glasses': ('face', [
        ".YYY.......YYY.",
        "Y...YYYYYYY...Y",
        "Y...Y.....Y...Y",
        ".YYY.......YYY.",
    ]),
    'acc-sunglasses': ('face', [
        "###############",
        "#eheee#.#eheee#",
        ".#eee#...#eee#.",
        "..###.....###..",
    ]),
}

# 단계별 앵커 (x 는 반 칸 단위가 될 수 있다)
ANCHORS = {
    'cracked': {'head': (11.5, 3), 'face': (11.5, 11), 'neck': (11.5, 16)},
    'kitten':  {'head': (10.5, 2), 'face': (10.5, 11), 'neck': (10.5, 15)},
    'teen':    {'head': (11.5, 2), 'face': (12.0, 11), 'neck': (11.5, 15)},
    'adult':   {'head': (11.5, 2), 'face': (12.0, 11), 'neck': (11.5, 16)},
    'radiant': {'head': (15.5, 7), 'face': (16.0, 16), 'neck': (15.5, 21)},
}


def place(slot, anchor, art):
    w, h = len(art[0]), len(art)
    ax, ay = anchor
    x0 = round(ax - w / 2)
    if slot == 'head':
        y0 = ay - h + 1        # 아이템 아래줄이 머리 꼭대기 줄과 겹친다
    elif slot == 'face':
        y0 = round(ay - h / 2)
    else:
        y0 = ay
    return x0, y0


def compose(stage, equipped):
    base = final.STAGES[stage]['frames'][0]
    pad_top = 6
    W = len(base[0])
    canvas = [['.'] * W for _ in range(pad_top)] + [list(r) for r in base]
    for acc_id in equipped:
        slot, art = ACCESSORIES[acc_id]
        x0, y0 = place(slot, ANCHORS[stage][slot], art)
        y0 += pad_top
        for dy, line in enumerate(art):
            for dx, ch in enumerate(line):
                if ch == '.':
                    continue
                x, y = x0 + dx, y0 + dy
                if 0 <= x < W and 0 <= y < len(canvas):
                    canvas[y][x] = ch
    return ["".join(r) for r in canvas]


if __name__ == "__main__":
    import pix
    pix.PALETTE.update({'#': (0x5B, 0x3B, 0x34), 'w': (0xF9, 0xF3, 0xEF), 'v': (0xEE, 0xE2, 0xDA),
                        'k': (0xF4, 0xC0, 0xBC), 'h': (0xFF, 0xFF, 0xFF), 'g': (0xB7, 0xAB, 0xAA),
                        's': (0x94, 0x82, 0x80), 'c': (0xF6, 0xE9, 0xDB), 'C': (0xEC, 0xDA, 0xC0),
                        'r': (0xF0, 0x60, 0x80), '*': (0xF2, 0xCC, 0x55)})
    pix.PALETTE.update(EXTRA)
    for k, (slot, art) in ACCESSORIES.items():
        assert len({len(r) for r in art}) == 1, k
    combos = [
        ('adult', ['acc-ribbon']), ('adult', ['acc-crown', 'acc-bell']),
        ('teen', ['acc-beret', 'acc-glasses']), ('kitten', ['acc-flower', 'acc-scarf']),
        ('cracked', ['acc-ribbon']), ('adult', ['acc-sunglasses', 'acc-bowtie']),
        ('radiant', ['acc-crown', 'acc-scarf']), ('teen', ['acc-flower', 'acc-bowtie']),
    ]
    pix.sheet('decor.png', [(f"{s}", compose(s, e)) for s, e in combos], cols=4, scale=8, gap=14)
    items = [(k, art) for k, (slot, art) in ACCESSORIES.items()]
    pix.sheet('decor_items.png', items, cols=9, scale=10, gap=14)
    print("ok")
