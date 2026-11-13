"""Add character shapes from a source font to one of the watch's own
TrueType font files (Garmin/ExtData/006-D0952-NN.bin).

The watch's file is a TrueType font with every byte XOR-ed with 0x76, followed
by a 16-byte clear trailer: one byte (0x89 in the files seen), a version byte
(210 = 2.10), a zero, the 12-character part number, a zero.

This tool unmasks the font, copies the outlines of the requested characters
from the source font (scaled to the target's units per em), adds them to the
glyph table, the character map and every per-glyph table the target carries
(hmtx, hdmx, LTSH), and writes the result masked again with a trailer.

Run it with the Python that has fontTools:
  /opt/homebrew/opt/fonttools/libexec/bin/python ttf_add_cjk.py ...

usage:
  ttf_add_cjk.py <watch font.bin> <source font> <weight or -> <characters> <output.bin>
                 [--part 006-D0952-NN] [--dy <units>] [--ttf <unmasked copy.ttf>]
"""
import io
import sys

from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

MASK = 0x76
TRAILER = 16


def xor(data):
    return bytes(b ^ MASK for b in data)


def main(argv):
    base_path, src_path, weight, chars, out_path = argv[:5]
    part = None
    ttf_copy = None
    dy = 0
    rest = argv[5:]
    while rest:
        if rest[0] == "--part":
            part, rest = rest[1], rest[2:]
        elif rest[0] == "--dy":
            # shift the added shapes vertically, in the target font's units, so
            # they stay inside the font's own ascent and descent
            dy, rest = int(rest[1]), rest[2:]
        elif rest[0] == "--ttf":
            ttf_copy, rest = rest[1], rest[2:]
        else:
            raise SystemExit("unknown option " + rest[0])

    raw = open(base_path, "rb").read()
    trailer = bytearray(raw[-TRAILER:])
    assert trailer[2] == 0 and trailer[-1] == 0, "unexpected trailer"
    font = TTFont(io.BytesIO(xor(raw[:-TRAILER])))

    src = TTFont(src_path, fontNumber=0)
    if "fvar" in src and weight != "-":
        from fontTools.varLib import instancer
        src = instancer.instantiateVariableFont(src, {"wght": float(weight)})
    assert "glyf" in src, "the source font must have TrueType outlines"
    src_cmap = src.getBestCmap()
    src_set = src.getGlyphSet()
    scale = font["head"].unitsPerEm / src["head"].unitsPerEm

    order = font.getGlyphOrder()
    glyf, hmtx = font["glyf"], font["hmtx"]
    unicode_tables = [t for t in font["cmap"].tables if t.isUnicode()]
    have = set(font.getBestCmap())
    if "hdmx" in font:
        # fontTools hands these records out read-only; make them plain dicts
        font["hdmx"].hdmx = {ppem: dict(w) for ppem, w in font["hdmx"].hdmx.items()}
    added = []
    for ch in chars:
        cp = ord(ch)
        if cp in have:
            continue
        assert cp in src_cmap, "source font lacks U+%04X" % cp
        rec = DecomposingRecordingPen(src_set)
        src_set[src_cmap[cp]].draw(rec)
        pen = TTGlyphPen(None)
        rec.replay(TransformPen(pen, (scale, 0, 0, scale, 0, dy)))
        glyph = pen.glyph()
        # whole-unit coordinates
        if glyph.numberOfContours > 0:
            glyph.coordinates.toInt()
        name = "uni%04X" % cp
        order.append(name)
        glyf[name] = glyph
        glyph.recalcBounds(glyf)
        advance = round(src["hmtx"][src_cmap[cp]][0] * scale)
        hmtx[name] = (advance, glyph.xMin if glyph.numberOfContours > 0 else 0)
        if "hdmx" in font:
            upm = font["head"].unitsPerEm
            for ppem, widths in font["hdmx"].hdmx.items():
                widths[name] = min(255, round(advance * ppem / upm))
        if "LTSH" in font:
            font["LTSH"].yPels[name] = 1
        for t in unicode_tables:
            t.cmap[cp] = name
        added.append(ch)
    font.setGlyphOrder(order)
    glyf.glyphOrder = order
    font["maxp"].numGlyphs = len(order)   # the per-glyph tables size themselves from this

    # Say in the OS/2 table that the font now covers Chinese
    os2 = font["OS/2"]
    os2.ulUnicodeRange2 |= 1 << (59 - 32)      # CJK Unified Ideographs
    if hasattr(os2, "ulCodePageRange1"):
        os2.ulCodePageRange1 |= 1 << 18        # Chinese, simplified

    buf = io.BytesIO()
    font.save(buf)
    data = buf.getvalue()
    if part:
        assert len(part) == 12
        trailer[3:15] = part.encode("ascii")
    with open(out_path, "wb") as f:
        f.write(xor(data) + bytes(trailer))
    if ttf_copy:
        with open(ttf_copy, "wb") as f:
            f.write(data)

    check = TTFont(io.BytesIO(data))
    cm = check.getBestCmap()
    print("%s -> %s" % (base_path.rsplit("/", 1)[-1], out_path.rsplit("/", 1)[-1]))
    print("  added %d characters: %s" % (len(added), "".join(added)))
    print("  glyphs %d -> %d, font bytes %d -> %d, trailer %s %r" % (
        len(order) - len(added), check["maxp"].numGlyphs, len(raw) - TRAILER, len(data),
        bytes(trailer[:3]).hex(" "), bytes(trailer[3:15]).decode()))
    print("  every added character maps to a glyph with outlines:",
          all(check["glyf"][cm[ord(c)]].numberOfContours > 0 for c in added))
    print("  tables:", " ".join(sorted(check.keys())))


if __name__ == "__main__":
    main(sys.argv[1:])
