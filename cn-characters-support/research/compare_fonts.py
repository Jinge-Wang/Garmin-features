"""Put several render_glyphs files one above another for comparison.

Each row is one file (one font or weight). The left panel draws the row in
black on white with smooth edges, the right panel in white on black, with the
2 px gap the watch adds after every picture.

usage: compare_fonts.py <output.png> <glyphs1.txt> [<glyphs2.txt> ...]
"""
import sys

import os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import fnt_build      # noqa: E402
import fnt_inspect    # noqa: E402

GAP, PAD, SCALE, H = 2, 5, 3, 27


def load(path, style):
    order = [int(l.split()[0], 16) for l in open(path, encoding="utf-8") if l.strip()]
    glyphs = fnt_build.read_glyphs(path, H, style)
    return [glyphs[cp] for cp in order]


def main(out, files):
    rows = [(load(f, "dark-ink"), load(f, "light-ink")) for f in files]
    width = max(sum(w + GAP for w, _ in r[0]) for r in rows) + 2 * PAD
    row_h = H + 2 * PAD
    W, Ht = 2 * width + PAD, row_h * len(rows)
    canvas = [[(90, 90, 90)] * W for _ in range(Ht)]
    for ri, pair in enumerate(rows):
        for side, (pics, bg) in enumerate(zip(pair, ((255, 255, 255), (0, 0, 0)))):
            x0 = side * (width + PAD)
            for y in range(ri * row_h + 1, (ri + 1) * row_h - 1):
                for x in range(x0, x0 + width):
                    canvas[y][x] = bg
            x = x0 + PAD
            for w, pic in pics:
                for yy in range(H):
                    for xx in range(w):
                        v = pic[yy * w + xx]
                        if v != 0xFF:
                            canvas[ri * row_h + PAD + yy][x + xx] = (((v >> 4) & 3) * 85, ((v >> 2) & 3) * 85, (v & 3) * 85)
                x += w + GAP
    lines = []
    for row in canvas:
        line = []
        for px in row:
            line.extend(px * SCALE)
        for _ in range(SCALE):
            lines.append(line)
    fnt_inspect.write_png(out, W * SCALE, Ht * SCALE, lines)
    print("comparison:", out, "%dx%d" % (W * SCALE, Ht * SCALE), "rows:", len(rows))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
