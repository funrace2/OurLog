"""픽셀 스프라이트 공용 도구: 도형, 격자, PNG 저장."""
import math, zlib, struct

# ───────────────────────────── 도형

def ellipse(cx, cy, rx, ry):
    return lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def poly(points):
    def f(x, y):
        inside, n = False, len(points)
        for i in range(n):
            x1, y1 = points[i]
            x2, y2 = points[(i + 1) % n]
            if (y1 > y) != (y2 > y) and x < x1 + (y - y1) / (y2 - y1) * (x2 - x1):
                inside = not inside
        return inside
    return f


def stroke(path, radius):
    pts = []
    for i in range(len(path) - 1):
        (x1, y1), (x2, y2) = path[i], path[i + 1]
        steps = int(max(abs(x2 - x1), abs(y2 - y1)) * 3) + 2
        for s in range(steps + 1):
            t = s / steps
            pts.append((x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, (i + t) / (len(path) - 1)))

    def f(x, y):
        for px, py, u in pts:
            r = radius[0] + (radius[1] - radius[0]) * u
            if (x - px) ** 2 + (y - py) ** 2 <= r * r:
                return True
        return False
    return f


def bezier(p0, p1, p2, n=26):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1])
            for t in (i / n for i in range(n + 1))]


def union(*shapes):
    return lambda x, y: any(s(x, y) for s in shapes)


def egg_shape(cx, cy, rx, ry):
    def f(x, y):
        t = (y - (cy - ry)) / (2 * ry)
        if not (0.0 <= t <= 1.0):
            return False
        return abs(x - cx) <= rx * (math.sin(math.pi * t) ** 0.58) * (0.74 + 0.26 * t)
    return f


# ───────────────────────────── 격자

class Grid:
    def __init__(self, w, h=None):
        self.w, self.h = w, h or w
        self.g = [['.'] * self.w for _ in range(self.h)]

    def cells(self):
        for y in range(self.h):
            for x in range(self.w):
                yield x, y

    def fill(self, shape, ch):
        for x, y in self.cells():
            if shape(x + 0.5, y + 0.5):
                self.g[y][x] = ch

    def fill_if(self, shape, ch, over):
        for x, y in self.cells():
            if self.g[y][x] in over and shape(x + 0.5, y + 0.5):
                self.g[y][x] = ch

    def put(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = ch

    def at(self, x, y):
        return self.g[y][x] if 0 <= x < self.w and 0 <= y < self.h else '.'

    def stamp(self, col, row, art):
        for dy, line in enumerate(art):
            for dx, ch in enumerate(line):
                if ch != ' ':
                    self.put(col + dx, row + dy, ch)

    def outline(self, body, ch='#'):
        add = [(x, y) for x, y in self.cells() if self.g[y][x] == '.' and
               any(self.at(x + dx, y + dy) in body for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        for x, y in add:
            self.g[y][x] = ch

    def rows(self):
        return ["".join(r) for r in self.g]


# ───────────────────────────── PNG

PALETTE = {
    '#': (0x58, 0x3C, 0x34), 'w': (0xFF, 0xF6, 0xF2), 'v': (0xF0, 0xE4, 0xDC),
    'g': (0xB8, 0xAC, 0xAC), 's': (0x94, 0x80, 0x7E), 'k': (0xFC, 0xC4, 0xC0),
    'r': (0xF0, 0x6C, 0x84), 'R': (0xC8, 0x48, 0x64), 'c': (0xFB, 0xF1, 0xE0),
    'C': (0xEC, 0xDD, 0xC6), '*': (0xF8, 0xD0, 0x6A), 'y': (0xFF, 0xF4, 0xC8),
    'o': (0xE8, 0xA8, 0x50), 'b': (0x8C, 0xB4, 0xE0), 'B': (0x5C, 0x84, 0xB8),
    'n': (0xB0, 0x84, 0x60), 'N': (0x84, 0x5C, 0x40), 'G': (0x9C, 0xC8, 0x88),
    'D': (0x6C, 0x9C, 0x5C), 'p': (0xC8, 0xA8, 0xE0), 'P': (0x98, 0x78, 0xC0),
    'm': (0xF4, 0xE8, 0xA0), 'x': (0xE0, 0xE0, 0xE8), 'X': (0xA8, 0xA8, 0xB8),
}
BG = (0xFF, 0xFF, 0xFF)


def save_png(path, pixels, w, h):
    raw = b"".join(b"\x00" + bytes(v for x in range(w) for v in pixels[y][x]) for y in range(h))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def sheet(path, sprites, cols=3, scale=8, gap=8, bg=BG):
    sw = max(len(s[0]) for _, s in sprites)
    sh = max(len(s) for _, s in sprites)
    rows = (len(sprites) + cols - 1) // cols
    cw, ch = sw * scale + gap, sh * scale + gap
    W, H = cw * cols + gap, ch * rows + gap
    buf = [[bg] * W for _ in range(H)]
    for i, (_, sp) in enumerate(sprites):
        ox, oy = gap + (i % cols) * cw, gap + (i // cols) * ch
        # 가운데 정렬
        ox += (sw - len(sp[0])) * scale // 2
        oy += (sh - len(sp)) * scale
        for y, row in enumerate(sp):
            for x, c in enumerate(row):
                col = PALETTE.get(c)
                if col is None:
                    continue
                for dy in range(scale):
                    for dx in range(scale):
                        buf[oy + y * scale + dy][ox + x * scale + dx] = col
    save_png(path, buf, W, H)
