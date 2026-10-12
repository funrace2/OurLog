"""
OurLog 고양이 최종 스프라이트 — 레퍼런스(사용자 제공) 기준.

  #  외곽선 갈색     w  흰 털      v  흰 털 그늘
  g  회색           s  줄무늬     k  분홍(볼·귀속)
  c  상자/알 밝은면  C  상자 그늘   r  하트   *  반짝임
"""
from pix import Grid, egg_shape, ellipse

ADULT = [
    "....##...........##......",
    "...#gg#........##gg#.....",
    "...#gggg########gggg#....",
    "..#gkkggggggggggggkkg#...",
    "..#gkkgggsgggsssgkkgs#...",
    ".#ggkkksggggggggssggg#...",
    ".#gggggggggwggggggggg#...",
    ".#ssggggggwwwggggggsss#..",
    "#sssgggggwwwwwgggggssg#..",
    "#ggggggggwwwwwwggggggg#..",
    "#ssggggwwwwwwwwwgggsss#..",
    "#ggggg###wwwwww###ggggg#.",
    "#ggggg#ww#w#w#www#ggggg#.",
    "#gggwkkwww#w#wwwkkwgggg#.",
    ".#wwkkkwwwwwwwwwkkkwww#..",
    ".#wwwwwwwwwwwwwwwwwww#...",
    "..##wwwwwwwwwwwwwww#####.",
    "....#wwwwwwwwwwwww##gggg#",
    "...#wwwwwwwwwwwwww##gggg#",
    "...#wwwwwwwwwwwwww##gggg#",
    "...#wwwwwwwwwwwwww##ssss#",
    "...#wwwwwwwwwwwwwww##ggg#",
    "...#vwwwwwwwwwwwww##gggg#",
    "...#vw#vwwwwwww#vw##ssss#",
    "...#vw#vwww#vww#vw#ssss#.",
    "....#w#vwww#vww#vw#sss#..",
    "....#w#v##w##w##vw#gg#...",
    "....#################....",
]

KITTEN = [
    "....##.........###......",
    "...#gg#......##ggg#.....",
    "..#gkgg#######ggkg#.....",
    "..#gkgggsgggsggkkg#.....",
    ".#ggkksgggggggskkgg#....",
    ".#gggsggggwggggsggg#....",
    ".#ggggggggwwggggggg#....",
    "#sssgggggwwwwgggggss#...",
    "#gggggggwwwwwggggggg#...",
    "#sgggggwwwwwwwggggss#...",
    "#ssgggwwwwwwwwwgggggg#..",
    "#ggg####wwwwww####ggg#..",
    "#ggwwwww#w##w#wwwwggg#..",
    "#gwkkkwww#ww#wwkkkwww#..",
    ".#wwwwwwwwwwwwwwwww#gg#.",
    "..#wwwwwwwwwwwwwww#gggg#",
    "...#wwwwwwwwwwwww##gggg#",
    "....#wwwwwwwwwwww##ssss#",
    "...#wwwwwwwwwwwww##gggg#",
    "...#vw#vwwwwww#ww#ssssg#",
    "...#vw#vwwwwww#ww#ssss#.",
    "....#v#vwwwwww#w#ssg#...",
    "....#v#w#w#w#ww#wsg#....",
    ".....##############.....",
]

CRACKED = [
    "................###....",
    "....##.........#ggg#...",
    "...#gg##......#gggg#...",
    "...#gggg######ggkkgg#..",
    "..#gkggggggggggskkgg#..",
    "..#gkkggssgggssgssggg#.",
    ".#ggkksgggggggggggggg#.",
    ".#gggsgggggwwggggggss#.",
    ".#ssgggggggwwwgggggggg#",
    ".#sgggggggwwwwwggggggg#",
    "#sgggg##wwwwwww##gggss#",
    "#ssggg##wwwwwww##ggggg#",
    "#ggggg##w#w#w#w##wgggg#",
    "#gggwkkwww#w#wwwkkwwww#",
    ".#ggwkkkwwwwwwwwkkkww#.",
    ".##wwwwwwwwwwwwwwwww#..",
    "...####wwwwwwwww####...",
    "..#wwww#wwwwwww#wwww#..",
    "..#w#ww#########ww#w#..",
    "..#CCCcccccccccccccc#..",
    "..#CCCcccccccccccccc#..",
    "..#CCCcccccccccccccc#..",
    "..#CCCcccccccccccccc#..",
    "..#CCCcccccccccccccc#..",
    "..#CCCcccccccccccccc#..",
    "..#CCCcccccccccccccc#..",
    "..#CCCcccccccccccccc#..",
    "..#CCCcccccccccccccc#..",
    "...#CCccccccccccccc#...",
    "....###############....",
]


def teen_from_adult():
    """청소년 = 어른과 같은 몸, 한 줄 작고, 눈을 뜨고 있다."""
    rows = [list(r) for r in ADULT]
    # 감은 눈 지우기
    for x in (6, 7, 8):
        rows[11][x] = 'g'
    for x in (15, 16, 17):
        rows[11][x] = 'g' if x == 17 else 'w'
    rows[12][6] = 'g'
    rows[12][17] = 'w'
    # 뜬 눈 (2x3)
    for y in (10, 11, 12):
        for x in (6, 7, 16, 17):
            rows[y][x] = '#'
    del rows[16]          # 몸 한 줄 줄이기
    return ["".join(r) for r in rows]


def with_blink(rows, eyes):
    """뜬 눈(2x3)을 감은 눈으로 바꾼 프레임. eyes: [(x, y_top), ...]"""
    g = [list(r) for r in rows]
    for ex, ey in eyes:
        fill = g[ey][ex - 1]
        for y in range(ey, ey + 3):
            for x in (ex, ex + 1):
                g[y][x] = fill if fill in 'gw' else 'g'
        # 웃는 곡선 ‾‾ + 양 끝 한 칸 아래
        g[ey + 1][ex] = '#'
        g[ey + 1][ex + 1] = '#'
        g[ey + 2][ex - 1] = '#'
        g[ey + 2][ex + 2] = '#'
    return ["".join(r) for r in g]


def egg_outline(cx, cy, rx, ry):
    """t=-1(위)에서 좁고 t=+1(아래)에서 넓은 달걀."""
    def f(x, y):
        t = (y - cy) / ry
        if abs(t) > 1:
            return False
        return abs(x - cx) <= rx * (1 - t * t) ** 0.5 * (1 + 0.16 * t)
    return f


def egg():
    """무늬 없는 평범한 알."""
    g = Grid(20, 25)
    g.fill(egg_outline(10.0, 12.6, 8.2, 11.3), 'w')
    # 오른쪽 아래 그늘 초승달
    shade = egg_outline(9.0, 11.6, 7.6, 10.6)
    for x, y in g.cells():
        if g.g[y][x] == 'w' and not shade(x + 0.5, y + 0.5) and (x > 9 or y > 14):
            g.g[y][x] = 'v'
    # 왼쪽 위 하이라이트
    g.stamp(5, 6, ["h", "h", "hh"])
    g.outline("wvh")
    return g.rows()


def radiant():
    """어른 + 하트 + 반짝임. 레퍼런스 배치를 따른다."""
    W, H = 33, 33
    canvas = [['.'] * W for _ in range(H)]
    ox, oy = 4, 5
    for y, r in enumerate(ADULT):
        for x, ch in enumerate(r):
            if ch != '.':
                canvas[oy + y][ox + x] = ch
    heart = [".rr.rr.", "rrrrrrr", "rrrrrrr", ".rrrrr.", "..rrr..", "...r..."]
    sparkle = [".*.", "***", ".*."]
    tiny = ["*"]
    for dy, line in enumerate(heart):
        for dx, ch in enumerate(line):
            if ch != '.':
                canvas[0 + dy][24 + dx] = ch
    for (sx, sy, art) in ((0, 7, sparkle), (0, 19, sparkle), (2, 28, sparkle),
                          (30, 8, tiny), (29, 21, sparkle)):
        for dy, line in enumerate(art):
            for dx, ch in enumerate(line):
                if ch != '.':
                    canvas[sy + dy][sx + dx] = ch
    return ["".join(r) for r in canvas]


TEEN = teen_from_adult()

STAGES = {
    'egg': {'frames': [egg()]},
    'cracked': {'frames': [CRACKED], 'blink': with_blink(CRACKED, [(6, 10), (15, 10)])},
    'kitten': {'frames': [KITTEN]},
    'teen': {'frames': [TEEN], 'blink': with_blink(TEEN, [(6, 10), (16, 10)])},
    'adult': {'frames': [ADULT]},
    'radiant': {'frames': [radiant()]},
}

ALL = [(k, v['frames'][0]) for k, v in STAGES.items()]


def check():
    for name, st in STAGES.items():
        for f in st['frames'] + ([st['blink']] if 'blink' in st else []):
            widths = {len(r) for r in f}
            assert len(widths) == 1, f"{name}: 줄 길이가 제각각 {widths}"


if __name__ == "__main__":
    import pix
    check()
    pix.sheet("final.png", ALL, cols=6, scale=9, gap=14)
    blinks = [(k + " 깜빡", v['blink']) for k, v in STAGES.items() if 'blink' in v]
    pix.sheet("final_blink.png", blinks, cols=2, scale=9, gap=14)
    for k, v in STAGES.items():
        f = v['frames'][0]
        print(k, len(f[0]), "x", len(f))
