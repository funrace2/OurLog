"""
방 배경 + 방 꾸미기 아이템 도트.

방은 56x44 칸. 벽(위) / 바닥(아래) / 창문(오른쪽 위)으로 나뉘고,
아이템은 슬롯마다 정해진 자리에 놓인다.
"""
import final, decor

ROOM_EXTRA = {
    'n': (0xC4, 0x9A, 0x74),  # 나무
    'N': (0x9C, 0x72, 0x50),  # 진한 나무
    'o': (0xE4, 0x9C, 0x6C),  # 화분 테라코타
    'D': (0x5E, 0x9A, 0x58),  # 진한 잎
    'a': (0xF7, 0xEE, 0xE2),  # 벽
    'A': (0xEF, 0xE3, 0xD3),  # 벽 무늬
    'f': (0xE6, 0xCC, 0xAA),  # 바닥
    'F': (0xD6, 0xB8, 0x92),  # 바닥 이음새
    'l': (0xCF, 0xE6, 0xF6),  # 창밖 하늘
    'L': (0xFF, 0xFF, 0xFF),  # 구름
}

ROOM_ITEMS = {
    # ── 벽
    'room-frame': ('wall', "우리 사진 액자", [
        "#############",
        "#nnnnnnnnnnn#",
        "#n#########n#",
        "#n#ccccccc#n#",
        "#n#crrcrrc#n#",
        "#n#crrrrrc#n#",
        "#n#ccrrrcc#n#",
        "#n#cccrccc#n#",
        "#n#########n#",
        "#nnnnnnnnnnn#",
        "#############",
    ]),
    'room-garland': ('wall', "가랜드", [
        "#################",
        "#ppp#yyy#bbb#mmm#",
        ".#p#.#y#.#b#.#m#.",
        "..#...#...#...#..",
    ]),
    'room-clock': ('wall', "벽시계", [
        "...####...",
        ".##wwww##.",
        ".#ww#www#.",
        "#www#wwww#",
        "#www#wwww#",
        "#www###ww#",
        "#wwwwwwww#",
        ".#wwwwww#.",
        ".##wwww##.",
        "...####...",
    ]),
    # ── 바닥 (고양이 발밑)
    'room-rug': ('floor', "동그란 러그", [
        "...##########################...",
        ".##pppppppppppppppppppppppppp##.",
        "#pppkkpkkpkkpkkpkkpkkpkkpkkpkpp#",
        "#ppkkkkkkkkkkkkkkkkkkkkkkkkkkpp#",
        ".##pppppppppppppppppppppppppp##.",
        "...##########################...",
    ]),
    'room-cushion': ('floor', "방석", [
        ".############################.",
        "#uuuuuuuuuuuuuuuuuuuuuuuuuuuu#",
        "#uuuuUuuuuuuuuuuuuuuuuuuUuuuu#",
        "#uuuuuuuuuuuuuuuuuuuuuuuuuuuu#",
        "#UUUUUUUUUUUUUUUUUUUUUUUUUUUU#",
        ".############################.",
    ]),
    # ── 창가
    'room-plant': ('window', "화분", [
        "....##....",
        "..##GG##..",
        ".#GG##GG#.",
        "#GGDGGDGG#",
        ".#GDGGDG#.",
        "..##GG##..",
        "....##....",
        ".########.",
        ".#oooooo#.",
        "..#oooo#..",
        "..#oooo#..",
        "...####...",
    ]),
    'room-curtain': ('window', "레이스 커튼", [
        "##################",
        "#pkpkpkpkpkpkpkpk#",
        "##################",
        "#kk#..........#kk#",
        "#kk#..........#kk#",
        "#kkk#........#kkk#",
        "#kkk#........#kkk#",
        "#kkkk#......#kkkk#",
        "#kkk#........#kkk#",
        "#kk#..........#kk#",
        "#kk#..........#kk#",
        "####..........####",
    ]),
    'room-moon': ('window', "달 조명", [
        "..#####..",
        ".#yyyyy#.",
        "#yyYyyyy#",
        "#yyyyyYy#",
        "#yYyyyyy#",
        ".#yyyyy#.",
        "..#####..",
        "....#....",
        "....#....",
        "..#nnn#..",
        "..#####..",
    ]),
    # ── 옆자리
    'room-ball': ('side', "털실 공", [
        "..#####...",
        ".#ppppp#..",
        "#pkpppkp#.",
        "#ppkpkpp#.",
        "#pppkppp#.",
        ".#pkpkp#..",
        "..######..",
        ".......###",
    ]),
    'room-bowl': ('side', "밥그릇", [
        "...#n#n#...",
        ".#nnnnnnn#.",
        "###########",
        "#bbbbbbbbb#",
        ".#bbbbbbb#.",
        "..#######..",
    ]),
    'room-cake': ('side', "케이크", [
        ".....y.....",
        ".....#.....",
        "..#######..",
        ".#kkkkkkk#.",
        "#kwkkwkkwk#",
        "#wwwwwwwww#",
        "#ccccccccc#",
        "#kkkkkkkkk#",
        "#ccccccccc#",
        "###########",
    ]),
}

ROOM_W, ROOM_H = 56, 44
FLOOR_Y = 29                 # 걸레받이 줄
CAT_CENTER_X = 22
CAT_FOOT_Y = 41              # 고양이 발바닥(외곽선) 줄
WINDOW = (36, 4, 18, 12)     # x, y, w, h (커튼과 같은 크기)


def background():
    g = [['a'] * ROOM_W for _ in range(ROOM_H)]
    # 벽지 무늬 (작은 점)
    for y in range(2, FLOOR_Y, 4):
        for x in range((y // 4) % 2 * 3, ROOM_W, 6):
            g[y][x] = 'A'
    # 걸레받이
    for x in range(ROOM_W):
        g[FLOOR_Y][x] = '#'
        g[FLOOR_Y + 1][x] = 'n'
        g[FLOOR_Y + 2][x] = '#'
    # 바닥 마루
    for y in range(FLOOR_Y + 3, ROOM_H):
        for x in range(ROOM_W):
            g[y][x] = 'f'
        if (y - FLOOR_Y) % 4 == 2:
            for x in range(ROOM_W):
                g[y][x] = 'F'
        else:
            off = 7 if (y // 4) % 2 else 0
            for x in range(off, ROOM_W, 14):
                g[y][x] = 'F'
    # 창문
    wx, wy, ww, wh = WINDOW
    for y in range(wy, wy + wh):
        for x in range(wx, wx + ww):
            edge = y in (wy, wy + wh - 1) or x in (wx, wx + ww - 1)
            bar = x == wx + ww // 2 or y == wy + wh // 2
            g[y][x] = '#' if edge else ('n' if bar else 'l')
    # 구름 하나
    for dx, dy in ((2, 2), (3, 2), (4, 2), (3, 1), (5, 3), (2, 3), (3, 3), (4, 3)):
        g[wy + dy][wx + dx] = 'L'
    # 창틀 선반
    for x in range(wx - 1, wx + ww + 1):
        g[wy + wh][x] = 'n'
        g[wy + wh + 1][x] = '#'
    return ["".join(r) for r in g]


def slot_origin(slot, art):
    w, h = len(art[0]), len(art)
    wx, wy, ww, wh = WINDOW
    if slot == 'wall':
        return 12 - w // 2, 10 - h // 2
    if slot == 'window':
        if h >= wh:                       # 커튼: 창문 위에 그대로 겹친다
            return wx, wy
        return wx + ww // 2 - w // 2, wy + wh - h   # 창틀 위에 놓는다
    if slot == 'floor':
        return CAT_CENTER_X - w // 2, CAT_FOOT_Y - h + 2
    if slot == 'side':
        return 41 - w // 2, CAT_FOOT_Y - h + 1
    raise ValueError(slot)


def stamp(g, x0, y0, art):
    for dy, line in enumerate(art):
        for dx, ch in enumerate(line):
            if ch != '.' and 0 <= y0 + dy < len(g) and 0 <= x0 + dx < len(g[0]):
                g[y0 + dy][x0 + dx] = ch


def compose(stage, items, accessories=()):
    g = [list(r) for r in background()]
    order = ['wall', 'window', 'floor', 'side']
    for slot in order:
        for item in items:
            s, _, art = ROOM_ITEMS[item]
            if s == slot and slot != 'side':
                stamp(g, *slot_origin(s, art), art)
    cat = decor.compose(stage, accessories)
    cw, ch = len(cat[0]), len(cat)
    # 고양이 스프라이트 맨 아래줄이 CAT_FOOT_Y 에 오도록
    stamp(g, CAT_CENTER_X - cw // 2, CAT_FOOT_Y - ch + 1, cat)
    for item in items:
        s, _, art = ROOM_ITEMS[item]
        if s == 'side':
            stamp(g, *slot_origin(s, art), art)
    return ["".join(r) for r in g]


if __name__ == "__main__":
    import pix
    pix.PALETTE.update({'#': (0x5B, 0x3B, 0x34), 'w': (0xF9, 0xF3, 0xEF), 'v': (0xEE, 0xE2, 0xDA),
                        'k': (0xF4, 0xC0, 0xBC), 'h': (0xFF, 0xFF, 0xFF), 'g': (0xB7, 0xAB, 0xAA),
                        's': (0x94, 0x82, 0x80), 'c': (0xF6, 0xE9, 0xDB), 'C': (0xEC, 0xDA, 0xC0),
                        'r': (0xF0, 0x60, 0x80), '*': (0xF2, 0xCC, 0x55)})
    pix.PALETTE.update(decor.EXTRA)
    pix.PALETTE.update(ROOM_EXTRA)
    for k, (_, _, art) in ROOM_ITEMS.items():
        assert len({len(r) for r in art}) == 1, k
    scenes = [
        ("빈 방", compose('adult', [])),
        ("꾸민 방", compose('adult', ['room-frame', 'room-plant', 'room-rug', 'room-ball'], ['acc-ribbon'])),
        ("꾸민 방2", compose('teen', ['room-garland', 'room-curtain', 'room-cushion', 'room-cake'], ['acc-beret'])),
        ("꾸민 방3", compose('kitten', ['room-clock', 'room-moon', 'room-rug', 'room-bowl'], ['acc-flower', 'acc-scarf'])),
    ]
    pix.sheet('room.png', scenes, cols=2, scale=7, gap=14)
    pix.sheet('room_items.png', [(k, a) for k, (_, _, a) in ROOM_ITEMS.items()], cols=6, scale=8, gap=14)
    print("ok")
