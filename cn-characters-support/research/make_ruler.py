"""Write ruler pictures that let the eye measure the gap the watch puts
between two pictures.

  U+2588  a solid block 10 px wide  (a row of them shows the watch's gap)
  U+2589  a solid block 20 px wide  (the gap should be the same if the watch
                                     advances by picture width)
  U+2460..U+2465  (circled 1 to 6): two 10 px bars with a KNOWN gap of
                  1, 2, 3, 4, 5, 6 px between them, inside one 27 px picture
  U+2467, U+2469, U+246B, U+246D  (circled 8, 10, 12, 14): two 6 px bars with
                  a known gap of 8, 10, 12, 14 px

The reader compares the unknown gap in the block row with the known gaps.

usage: make_ruler.py <out.txt>
"""
import sys

H = 27


def picture(width, ink_columns):
    row = bytes(0xFF if x in ink_columns else 0x00 for x in range(width))
    return (row * H).hex()


def pair(width, bar, gap):
    """Two bars joined along the bottom, so each pair reads as one "U" whose
    opening is the known gap. The join keeps a pair from being confused with
    the space between two neighbouring pictures."""
    left = (width - 2 * bar - gap) // 2
    cols = set(range(left, left + bar)) | set(range(left + bar + gap, left + 2 * bar + gap))
    span = set(range(left, left + 2 * bar + gap))
    rows = []
    for y in range(H):
        ink = span if y >= H - 5 else cols
        rows.append(bytes(0xFF if x in ink else 0x00 for x in range(width)))
    return b"".join(rows).hex()


lines = [
    "2588 10 %d %s" % (H, picture(10, set(range(10)))),
    "2589 20 %d %s" % (H, picture(20, set(range(20)))),
]
for i, gap in enumerate((1, 2, 3, 4, 5, 6)):
    lines.append("%04X 27 %d %s" % (0x2460 + i, H, pair(27, 10, gap)))
for cp, gap in ((0x2467, 8), (0x2469, 10), (0x246B, 12), (0x246D, 14)):
    lines.append("%04X 27 %d %s" % (cp, H, pair(27, 6, gap)))
open(sys.argv[1], "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("ruler pictures:", len(lines))
