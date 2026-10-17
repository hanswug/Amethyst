"""Box-drawing diagrams for docs/layouts.md, from the layouts' geometry (unit square, y down).

Each layout returns tiles: (x, y, w, h, label) as Fractions. Twins are made by mirroring, so they follow the rule by
construction. Run: python3 -I scripts/docs/diagrams.py (prints them); python3 -I scripts/docs/fill.py writes docs/layouts.md
"""
from fractions import Fraction as F

R = F(1, 2)  # main pane ratio


def split(n):
    return [F(i, n) for i in range(n)], F(1, n)


def fill(n, main_max, sides):
    """Pane sizes after n windows arrive at the end: main while it has room and the sides are empty, then the
    shortest side pane, ties to the first (PaneCounts.paneForNewWindow)."""
    counts = [0] * (sides + 1)
    for _ in range(n):
        if counts[0] == 0 or (counts[0] < main_max and all(c == 0 for c in counts[1:])):
            counts[0] += 1
        else:
            side = min(range(1, sides + 1), key=lambda i: (counts[i], i))
            counts[side] += 1
    return counts


def labels(counts):
    out, k = [], 1
    for c in counts:
        out.append([str(k + i) for i in range(c)])
        k += c
    return out


def rows(x, w, names):
    ys, h = split(len(names))
    return [(x, y, w, h, s) for y, s in zip(ys, names)]


def cols(y, h, names, x0=F(0), width=F(1)):
    xs, w = split(len(names))
    return [(x0 + x * width, y, w * width, h, s) for x, s in zip(xs, names)]


def tall(n, m=1):
    main, stack = labels(fill(n, m, 1))
    mw = R if stack else F(1)
    return rows(F(0), mw, main) + (rows(mw, 1 - mw, stack) if stack else [])


def wide(n, m=1):
    main, stack = labels(fill(n, m, 1))
    mh = R if stack else F(1)
    return cols(F(0), mh, main) + (cols(mh, 1 - mh, stack) if stack else [])


def widescreen_tall(n, m=1):
    main, stack = labels(fill(n, m, 1))
    mw = R if stack else F(1)
    return cols(F(0), F(1), main, F(0), mw) + (rows(mw, 1 - mw, stack) if stack else [])


def two_pane(n):
    main, rest = labels(fill(n, 1, 1))
    tiles = [(F(0), F(0), R if rest else F(1), F(1), main[0])]
    if rest:
        behind = " ".join(rest[1:])
        tiles.append((R, F(0), 1 - R, F(1), rest[0] + (f" ({behind})" if behind else "")))
    return tiles


def three_column(n, m=1, where="left", counts=None):
    counts = counts or fill(n, m, 2)
    main, sec, ter = labels(counts)
    if not sec:
        return rows(F(0), F(1), main)
    side = (1 - R) / 2
    x = {"left": (F(0), R, R + side), "middle": (side, F(0), side + R)}[where]
    tiles = rows(x[0], R, main) + rows(x[1], side, sec)
    return tiles + rows(x[2], side, ter or ["·"])  # an empty column keeps its width


def four_column(n, m=1, counts=None):
    counts = counts or fill(n, m, 3)
    main, sec, ter, quat = labels(counts)
    q = F(1, 4)
    tiles = rows(q, q, main)  # main is the second column
    for x, names in ((2 * q, sec), (F(0), ter), (3 * q, quat)):
        tiles += rows(x, q, names or ["·"])  # every column keeps its quarter
    return tiles


def column(n, m=1):
    k = min(n, m)
    main = [str(i + 1) for i in range(k)]
    rest = [str(i + 1) for i in range(k, n)]
    mw = R if rest else F(1)
    return cols(F(0), F(1), main, F(0), mw) + (cols(F(0), F(1), rest, mw, 1 - mw) if rest else [])


def row(n, m=1):
    return [(y, x, h, w, s) for x, y, w, h, s in column(n, m)]  # Column turned


def fullscreen(n):
    return [(F(0), F(0), F(1), F(1), "focused window, the others behind")]


def bsp():
    # Five windows, each new one splitting the newest (focused) along its longer side on a 16:9 screen.
    return [
        (F(0), F(0), R, F(1), "1"),
        (R, F(0), R, R, "2"),
        (R, R, F(1, 4), R, "3"),
        (F(3, 4), R, F(1, 4), F(1, 4), "4"),
        (F(3, 4), F(3, 4), F(1, 4), F(1, 4), "5"),
    ]


def padded(tiles, left=0, right=0, top=0, bottom=0, screen=(3840, 2160)):
    """The screen's outline with `tiles` laid out in the area a padding mode leaves (padding in points)."""
    width, height = screen
    x0, y0 = F(left, width), F(top, height)
    w, h = F(width - left - right, width), F(height - top - bottom, height)
    inner = [(x0 + x * w, y0 + y * h, tw * w, th * h, label) for x, y, tw, th, label in tiles]
    return [(F(0), F(0), F(1), F(1), "")] + inner


def mirror_x(tiles):
    return [(1 - x - w, y, w, h, s) for x, y, w, h, s in tiles]


def mirror_y(tiles):
    return [(x, 1 - y - h, w, h, s) for x, y, w, h, s in tiles]


CHARS = {
    frozenset("lr"): "─", frozenset("ud"): "│", frozenset("rd"): "┌", frozenset("ld"): "┐",
    frozenset("ru"): "└", frozenset("lu"): "┘", frozenset("udr"): "├", frozenset("udl"): "┤",
    frozenset("lrd"): "┬", frozenset("lru"): "┴", frozenset("udlr"): "┼",
}


def render(tiles, width=40, height=8):
    grid = {}

    def link(a, b, da, db):
        grid.setdefault(a, set()).add(da)
        grid.setdefault(b, set()).add(db)

    boxes = []
    for x, y, w, h, s in tiles:
        x0, x1 = round(x * width), round((x + w) * width)
        y0, y1 = round(y * height), round((y + h) * height)
        assert x1 - x0 >= 2 and y1 - y0 >= 2, (s, x0, x1, y0, y1)
        for cx in range(x0, x1):
            link((cx, y0), (cx + 1, y0), "r", "l")
            link((cx, y1), (cx + 1, y1), "r", "l")
        for cy in range(y0, y1):
            link((x0, cy), (x0, cy + 1), "d", "u")
            link((x1, cy), (x1, cy + 1), "d", "u")
        boxes.append((x0, y0, x1, y1, s))

    lines = [[" "] * (width + 1) for _ in range(height + 1)]
    for (cx, cy), dirs in grid.items():
        lines[cy][cx] = CHARS[frozenset(dirs)]
    for x0, y0, x1, y1, s in boxes:
        inner = x1 - x0 - 1
        assert len(s) <= inner, (s, inner)
        cy = (y0 + y1) // 2
        start = x0 + 1 + (inner - len(s)) // 2
        for i, ch in enumerate(s):
            lines[cy][start + i] = ch
    return ["".join(l) for l in lines]


def side_by_side(*named, gap=4):
    blocks = [(title, render(tiles, **kw)) for title, tiles, kw in named]
    width = [max(len(title), len(b[0])) for title, b in blocks]
    out = ["".ljust(0).join(t.ljust(w + gap) for (t, _), w in zip(blocks, width)).rstrip()]
    for i in range(len(blocks[0][1])):
        out.append("".join(b[i].ljust(w + gap) for (_, b), w in zip(blocks, width)).rstrip())
    return "\n".join(out)


def pair(name_a, name_b, tiles, mirror, **kw):
    return side_by_side((name_a, tiles, kw), (name_b, mirror(tiles), kw))


if __name__ == "__main__":
    S = dict(width=16, height=6)
    M = dict(width=24, height=8)
    P = dict(width=30, height=8)
    sections = {
        "fill-3column": side_by_side(*[(f"{n} window{'s' if n > 1 else ''}", three_column(n), S) for n in (1, 2, 3)]) + "\n\n"
        + side_by_side(*[(f"{n} windows", three_column(n), S) for n in (4, 5, 6)]),
        "max-tall": side_by_side(
            ("main 2 of 2", tall(3, 2), S),
            ("2 closes: 1 of 2", [(F(0), F(0), R, F(1), "1"), (R, F(0), R, F(1), "3")], S),
            ("new window, last: 1 of 2", [(F(0), F(0), R, F(1), "1")] + rows(R, R, ["3", "4"]), S),
            ("new window, first: 2 of 2", rows(F(0), R, ["4", "1"]) + rows(R, R, ["3"]), S)),
        "leave-3column": side_by_side(
            ("5 windows: 1|2|2", three_column(5), S),
            ("3 closes: 1|1|2", rows(F(0), R, ["1"]) + rows(R, F(1, 4), ["2"]) + rows(F(3, 4), F(1, 4), ["4", "5"]), S),
            ("2 closes: 1|1|1", rows(F(0), R, ["1"]) + rows(R, F(1, 4), ["4"]) + rows(F(3, 4), F(1, 4), ["5"]), S)),
        "twins-3column": pair("3Column Left, 4 windows", "3Column Right, 4 windows", three_column(4), mirror_x),
        "tall": pair("Tall Left", "Tall Right", tall(5), mirror_x),
        "tall-m2": pair("Tall Left, main count 2", "Tall Right, main count 2", tall(5, 2), mirror_x),
        "wide": pair("Wide Top", "Wide Bottom", wide(5), mirror_y),
        "wide-m2": pair("Wide Top, main count 2", "Wide Bottom, main count 2", wide(5, 2), mirror_y),
        "two-pane": pair("Two Pane A", "Two Pane B", two_pane(5), mirror_x),
        "two-pane-portrait": pair("Two Pane A, portrait", "Two Pane B, portrait",
                                  [(y, x, h, w, s) for x, y, w, h, s in two_pane(5)], mirror_y, width=18, height=14),
        "3column": pair("3Column Left", "3Column Right", three_column(5), mirror_x),
        "3column-middle": side_by_side(("3Column Middle", three_column(5, where="middle"), {})),
        "4column": pair("4Column Left", "4Column Right", four_column(5), mirror_x),
        "4column-fill": side_by_side(*[(f"{n} window{'s' if n > 1 else ''}", four_column(n), S) for n in (1, 2, 3, 4)]),
        "widescreen": pair("Widescreen Tall Left", "Widescreen Tall Right", widescreen_tall(5), mirror_x),
        "widescreen-m2": pair("Widescreen Tall Left, main count 2", "Widescreen Tall Right, main count 2",
                              widescreen_tall(5, 2), mirror_x),
        "column": pair("Column Left", "Column Right", column(5), mirror_x),
        "column-m2": pair("Column Left, main count 2", "Column Right, main count 2", column(5, 2), mirror_x),
        "row": pair("Row Top", "Row Bottom", row(5), mirror_y, width=30, height=16),
        "row-m2": pair("Row Top, main count 2", "Row Bottom, main count 2", row(5, 2), mirror_y, width=30, height=12),
        "fullscreen": side_by_side(("Fullscreen", fullscreen(5), {})),
        "bsp": side_by_side(("BSP, 5 windows opened in order", bsp(), dict(width=36, height=12))),
        # docs/my-setup.md: Hans's padding modes on his 55" 4K (3840 x 2160 points).
        "my-laptop": side_by_side(("Fullscreen", fullscreen(4), {}), ("Two Pane A", two_pane(4), {})),
        "my-padding": side_by_side(
            ("full: the whole space", padded([(F(0), F(0), F(1), F(1), "entertainment")]), P),
            ("wide: many windows", padded(three_column(4, where="middle", counts=[2, 1, 1]), top=540), P),
            ("27 screen: browsing", padded([(F(0), F(0), F(1), F(1), "browser")], left=640, right=640, top=720), P)),
        "my-tall": side_by_side(
            ("1/3", tall(4), M), ("1/2", tall(3), M), ("2/2", tall(4, 2), M)),
        "my-3column": side_by_side(
            ("1/2/1", three_column(4, where="middle", counts=[2, 1, 1]), M),
            ("2/1/2", three_column(5, where="middle", counts=[1, 2, 2]), M),
            ("3/2/3", three_column(8, where="middle", counts=[2, 3, 3]), M)),
        "my-browse": side_by_side(
            ("Fullscreen in 27 screen, on the 55\"", padded([(F(0), F(0), F(1), F(1), "browser")], left=640, right=640, top=720),
             dict(width=48, height=12))),
        "flip-tall": side_by_side(
            ("Tall Left", tall(5), M),
            ("flip-twin: Tall Right", mirror_x(tall(5)), M),
            ("flip-rows", rows(F(0), R, ["1"]) + rows(R, R, ["5", "4", "3", "2"]), M)),
        "flip-wide": side_by_side(
            ("Wide Top, main count 2", wide(5, 2), {}),
            ("flip-columns", cols(F(0), R, ["2", "1"]) + cols(R, R, ["5", "4", "3"]), {})),
        "flip-3column-middle": side_by_side(
            ("3Column Middle", three_column(4, where="middle"), {}),
            ("flip-twin: sides swapped", rows(F(1, 4), R, ["1"]) + rows(F(0), F(1, 4), ["4"]) + rows(F(3, 4), F(1, 4), ["2", "3"]), {})),
        "flip-bsp": side_by_side(
            ("BSP", bsp(), dict(width=36, height=12)),
            ("flip-columns", mirror_x(bsp()), dict(width=36, height=12))),
    }
    for name, text in sections.items():
        print(f"## {name}\n```\n{text}\n```\n")
