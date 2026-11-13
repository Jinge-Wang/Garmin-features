"""Preview how lines of text come out of a picture-font table.

Each line is drawn twice, on a black strip and on a white strip, using only
the pictures in the table and no extra gap between them. Characters the table
does not hold (Latin letters, digits) are shown as a thin grey bar of 12 px,
only to mark their place. This is a check of the pictures on the Mac, not a
simulation of the watch's layout.

usage: preview_lines.py <file.fnt> <output.png> <line> [<line> ...]
"""
import sys

import os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import fnt_build      # noqa: E402
import fnt_inspect    # noqa: E402


def main(argv):
    # optional first argument: --light or --dark draws one background only
    sides = ((0, (0, 0, 0)), (1, (255, 255, 255)))
    if argv[0] == "--light":
        sides, argv = ((0, (255, 255, 255)),), argv[1:]
    elif argv[0] == "--dark":
        sides, argv = ((0, (0, 0, 0)),), argv[1:]
    # optional: --gap N adds N px after every picture, to imitate a watch that
    # spaces pictures itself (N is an assumption until measured on the watch)
    gap = 0
    if argv[0] == "--gap":
        gap, argv = int(argv[1]), argv[2:]
    font = fnt_build.parse(open(argv[0], "rb").read())
    out, lines = argv[1], argv[2:]
    h = font["height"]
    pad, scale, missing_w = 4, 3, 12
    width = max(sum(font["glyphs"].get(ord(c), (missing_w - gap, b""))[0] + gap for c in s) for s in lines) + 2 * pad
    row_h = h + 2 * pad
    W, H = width * len(sides) + pad * (len(sides) - 1), row_h * len(lines)
    canvas = [[(60, 60, 60)] * W for _ in range(H)]
    for li, s in enumerate(lines):
        for side, bg in sides:
            x0 = side * (width + pad)
            for y in range(li * row_h + 1, (li + 1) * row_h - 1):
                for x in range(x0, x0 + width):
                    canvas[y][x] = bg
            x = x0 + pad
            for c in s:
                g = font["glyphs"].get(ord(c))
                if g is None:
                    for yy in range(h // 2 - 1, h // 2 + 1):
                        for xx in range(2, missing_w - 2):
                            canvas[li * row_h + pad + yy][x + xx] = (128, 128, 128)
                    x += missing_w
                    continue
                w, pic = g
                for yy in range(h):
                    for xx in range(w):
                        v = pic[yy * w + xx]
                        if v != 0xFF:
                            canvas[li * row_h + pad + yy][x + xx] = (((v >> 4) & 3) * 85, ((v >> 2) & 3) * 85, (v & 3) * 85)
                x += w + gap
    rows = []
    for row in canvas:
        line = []
        for px in row:
            line.extend(px * scale)
        for _ in range(scale):
            rows.append(line)
    fnt_inspect.write_png(out, W * scale, H * scale, rows)
    print("preview:", out, "%dx%d" % (W * scale, H * scale))


if __name__ == "__main__":
    main(sys.argv[1:])
