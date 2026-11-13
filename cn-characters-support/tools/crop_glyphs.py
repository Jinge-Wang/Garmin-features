"""Cut a column window out of every glyph in a render_glyphs file.

Characters are drawn in a wide cell so that nothing is lost, then cropped to
the columns the ink actually uses. The cropped width becomes the picture's
width, which is how far the watch advances for that character.

usage: crop_glyphs.py <in.txt> <out.txt> <first column> <last column> [--fit]

--fit: a glyph whose ink pokes one or two columns outside the window is slid
sideways, when its ink is narrow enough, so that nothing is cut off. Glyphs
too wide for the window are still clipped.

Reports how many glyphs were slid and how many still lose ink.
"""
import sys

INK = 110


def main(argv):
    src, dst, first, last = argv[0], argv[1], int(argv[2]), int(argv[3])
    fit = len(argv) > 4 and argv[4] == "--fit"
    width = last - first + 1
    out, clipped, slid, n = [], 0, 0, 0
    for line in open(src, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        cp, w, h, hexdata = line.split()
        w, h = int(w), int(h)
        cov = bytes.fromhex(hexdata)
        cols = [x for x in range(w) if any(cov[y * w + x] >= INK for y in range(h))]
        start = first
        if cols and fit:
            lo, hi = cols[0], cols[-1]
            if hi - lo + 1 <= width:
                if lo < first:
                    start = lo
                elif hi > last:
                    start = hi - width + 1
                if start != first:
                    slid += 1
        start = max(0, min(start, w - width))
        if cols and (cols[0] < start or cols[-1] > start + width - 1):
            clipped += 1
        n += 1
        new = b"".join(cov[y * w + start:y * w + start + width] for y in range(h))
        out.append("%s %d %d %s" % (cp, width, h, new.hex()))
    with open(dst, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print("%s: %d glyphs cropped to %d px wide, %d slid to fit, %d lose some ink" % (
        dst.rsplit("/", 1)[-1], n, width, slid, clipped))


if __name__ == "__main__":
    main(sys.argv[1:])
