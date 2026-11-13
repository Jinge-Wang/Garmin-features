"""Rebuild a Garmin picture-font container (.fnt), optionally with extra glyphs.

The layout is documented in fnt_inspect.py. This tool reads an original file
into a map {code point: picture}, optionally adds pictures, and writes the
container again: ranges sorted by code point, glyph indices running in table
order, offsets and sizes recomputed, the header's other fields and the trailer
copied from the original.

Self-check: rebuilding with nothing added must reproduce the original byte for
byte. That is the test of whether the layout is fully understood.

Measured on a fenix 6X Pro (firmware 28.02): a rebuilt
file is accepted, the bytes after the body are not checked, and the menus and
the notifications draw any code point the table lists, emoji or not.

usage:
  fnt_build.py --selftest <original.fnt>
  fnt_build.py <original.fnt> <output.fnt> --add <glyphs.txt> <style> [--add ...]
                                           [--add-pack <pack.gz>] [--write-pack <pack.gz>]

--add-pack adds finished pictures from a pack file (see below); a code point the
table already holds is skipped. --write-pack saves every picture this run added
as a pack file, so the table can later be rebuilt from an original and the pack
alone, with no font and no drawing step.

pack file: gzip of "GFPK1\n", u16 height, u32 count, then per picture
u32 code point, u8 width, width x height palette bytes. All little-endian.

glyphs.txt (written by render_glyphs): one glyph per line,
  "<code point hex> <width> <height> <hex coverage>", two hex digits per pixel.
The height must equal the table's height; the width is free (1 to 255) and
becomes the picture's width, which is also how far the watch advances.

style: how coverage becomes one of the watch's 64 colours (6-bit RRGGBB) or
transparent (0xFF):
  mono:<colour hex>:<threshold>   one colour where coverage >= threshold
  light-ink                       white ink with two grey edge levels, for a dark screen
  dark-ink                        black ink with two grey edge levels, for a light screen
  dark-ink-halo[:N]               the same with a white rim of N pixels around every stroke
  dark-ink-plate                  the same on an opaque white cell
"""
import struct
import sys

HEADER = 36
TRANSPARENT = 0xFF


def parse(data):
    body = struct.unpack_from("<I", data, 4)[0]
    off_ranges, off_index, off_glyphs = struct.unpack_from("<III", data, 8)
    rec_size, table_bytes, zero, count = struct.unpack_from("<IIII", data, off_ranges)
    assert rec_size == 12, rec_size
    recs_at = off_ranges + 16
    assert recs_at + 12 * count == off_index, "range table does not end at the glyph index"
    assert table_bytes == 16 + 12 * count, table_bytes
    nglyph = (off_glyphs - off_index) // 4
    entries = struct.unpack_from("<%dI" % nglyph, data, off_index)
    offs = [e & 0xFFFFFF for e in entries]
    widths = [e >> 24 for e in entries]
    glyph_bytes = body - off_glyphs
    pics = []
    for i in range(nglyph):
        end = offs[i + 1] if i + 1 < nglyph else glyph_bytes
        pics.append((widths[i], data[off_glyphs + offs[i]:off_glyphs + end]))
    height = len(pics[0][1]) // pics[0][0]
    glyphs = {}
    for k in range(count):
        a, b, g = struct.unpack_from("<III", data, recs_at + 12 * k)
        for cp in range(a, b + 1):
            glyphs[cp] = pics[g + cp - a]
    return {
        "header": data[:HEADER],
        "zero": zero,
        "blank": pics[0],
        "glyphs": glyphs,
        "height": height,
        "trailer": data[body:],
        "used": 1 + len(glyphs) == nglyph,
    }


def build(font):
    glyphs = font["glyphs"]
    cps = sorted(glyphs)
    ranges = []
    for cp in cps:
        if ranges and cp == ranges[-1][1] + 1:
            ranges[-1][1] = cp
        else:
            ranges.append([cp, cp])
    pics = [font["blank"]] + [glyphs[cp] for cp in cps]

    recs = b""
    index = 1
    for a, b in ranges:
        recs += struct.pack("<III", a, b, index)
        index += b - a + 1
    table = struct.pack("<IIII", 12, 16 + len(recs), font["zero"], len(ranges)) + recs

    chunks, idx, pos = [], [], 0
    for w, pic in pics:
        assert pos <= 0xFFFFFF, "glyph data exceeds the 3-byte offsets"
        assert 1 <= w <= 255 and len(pic) == w * font["height"]
        idx.append(struct.pack("<I", pos | (w << 24)))
        chunks.append(pic)
        pos += len(pic)
    idx = b"".join(idx)
    glyph_data = b"".join(chunks)

    off_ranges = HEADER
    off_index = off_ranges + len(table)
    off_glyphs = off_index + len(idx)
    body = off_glyphs + len(glyph_data)
    header = bytearray(font["header"])
    struct.pack_into("<I", header, 4, body)
    struct.pack_into("<III", header, 8, off_ranges, off_index, off_glyphs)
    return bytes(header) + table + idx + glyph_data + font["trailer"], len(ranges), len(pics)


def _dark(c):
    return TRANSPARENT if c < 40 else 0x2A if c < 104 else 0x15 if c < 184 else 0x00


def make_style(style):
    """Return a function (coverage bytes, width, height) -> palette bytes."""
    if style.startswith("mono:"):
        _, colour, threshold = style.split(":")
        colour, threshold = int(colour, 16), int(threshold)
        return lambda cov, w, h: bytes(colour if c >= threshold else TRANSPARENT for c in cov)
    if style.startswith("dither:"):
        # dither:<colour a>:<colour b>:<threshold>  two of every three ink pixels
        # take colour a, the third takes colour b, in a diagonal pattern. With
        # dark grey and light grey this gives a neutral mid grey that neither
        # palette grey provides, readable on white and on black.
        _, a, b, threshold = style.split(":")
        a, b, threshold = int(a, 16), int(b, 16), int(threshold)
        return lambda cov, w, h: bytes(
            TRANSPARENT if cov[y * w + x] < threshold else (b if (x + y) % 3 == 0 else a)
            for y in range(h) for x in range(w))
    if style == "light-ink":   # white on a dark screen
        return lambda cov, w, h: bytes(
            TRANSPARENT if c < 40 else 0x15 if c < 104 else 0x2A if c < 184 else 0x3F for c in cov)
    if style == "dark-ink":    # black on a light screen; vanishes on a dark one
        return lambda cov, w, h: bytes(_dark(c) for c in cov)
    if style == "dark-ink-plate":
        # black ink on an opaque white cell: seamless on a light screen,
        # a white label behind each character on a dark one
        return lambda cov, w, h: bytes(0x3F if c < 40 else _dark(c) for c in cov)
    if style.startswith("dark-ink-halo"):
        # black ink with a white rim of N pixels (default 1) around every stroke:
        # the rim is invisible on a light screen and outlines the strokes on a dark one
        reach = int(style.split(":")[1]) if ":" in style else 1

        def halo(cov, w, h):
            out = bytearray(_dark(c) for c in cov)
            ink = [c >= 104 for c in cov]
            for y in range(h):
                for x in range(w):
                    if cov[y * w + x] >= 40:
                        continue
                    near = False
                    for dy in range(-reach, reach + 1):
                        for dx in range(-reach, reach + 1):
                            yy, xx = y + dy, x + dx
                            if 0 <= yy < h and 0 <= xx < w and ink[yy * w + xx]:
                                near = True
                    if near:
                        out[y * w + x] = 0x3F
            return bytes(out)
        return halo
    raise SystemExit("unknown style: " + style)


def read_glyphs(path, height, style):
    to_palette = make_style(style)
    out = {}
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        cp_hex, w, h, hexdata = line.split()
        w, h = int(w), int(h)
        assert h == height, "glyph %s has height %d, table height is %d" % (cp_hex, h, height)
        cov = bytes.fromhex(hexdata)
        assert len(cov) == w * h, "glyph %s: %d values for %dx%d" % (cp_hex, len(cov), w, h)
        out[int(cp_hex, 16)] = (w, to_palette(cov, w, h))
    return out


PACK_MAGIC = b"GFPK1\n"


def write_pack(path, glyphs, height):
    import gzip
    with open(path, "wb") as raw:
        # no file name and no time stamp in the gzip header: same input, same bytes
        with gzip.GzipFile(filename="", fileobj=raw, mode="wb", compresslevel=9, mtime=0) as f:
            f.write(PACK_MAGIC + struct.pack("<HI", height, len(glyphs)))
            for cp in sorted(glyphs):
                w, pic = glyphs[cp]
                assert len(pic) == w * height
                f.write(struct.pack("<IB", cp, w) + pic)


def read_pack(path):
    import gzip
    with gzip.open(path, "rb") as f:
        data = f.read()
    assert data[:len(PACK_MAGIC)] == PACK_MAGIC, "not a picture pack: %s" % path
    pos = len(PACK_MAGIC)
    height, count = struct.unpack_from("<HI", data, pos)
    pos += 6
    out = {}
    for _ in range(count):
        cp, w = struct.unpack_from("<IB", data, pos)
        pos += 5
        out[cp] = (w, data[pos:pos + w * height])
        pos += w * height
    assert pos == len(data), "pack file has trailing or missing bytes"
    return height, out


def main(argv):
    if argv[0] == "--selftest":
        data = open(argv[1], "rb").read()
        font = parse(data)
        rebuilt, nr, ng = build(font)
        print("parsed: %d glyphs, height %d, every picture used: %s" % (len(font["glyphs"]), font["height"], font["used"]))
        print("rebuilt: %d ranges, %d pictures, %d bytes" % (nr, ng, len(rebuilt)))
        print("byte-for-byte identical to the original:", rebuilt == data)
        return 0 if rebuilt == data else 1

    src, dst = argv[0], argv[1]
    steps, pack_out = [], None
    rest = argv[2:]
    while rest:
        if rest[0] == "--add" and len(rest) >= 3:
            steps.append(("glyphs", rest[1], rest[2]))
            rest = rest[3:]
        elif rest[0] == "--add-pack" and len(rest) >= 2:
            steps.append(("pack", rest[1], None))
            rest = rest[2:]
        elif rest[0] == "--write-pack" and len(rest) >= 2:
            pack_out, rest = rest[1], rest[2:]
        else:
            raise SystemExit("expected --add <glyphs.txt> <style>, --add-pack <file> or --write-pack <file>")
    data = open(src, "rb").read()
    font = parse(data)
    original = dict(font["glyphs"])
    added = {}
    for kind, path, style in steps:
        if kind == "glyphs":
            extra = read_glyphs(path, font["height"], style)
            clash = sorted(set(extra) & set(font["glyphs"]))
            assert not clash, "code points already in the table: %s" % ["U+%04X" % c for c in clash[:5]]
            label = style
        else:
            height, extra = read_pack(path)
            assert height == font["height"], "pack height %d, table height %d" % (height, font["height"])
            skipped = sum(1 for cp in extra if cp in font["glyphs"])
            extra = {cp: g for cp, g in extra.items() if cp not in font["glyphs"]}
            label = "pack" + (" (%d skipped)" % skipped if skipped else "")
        font["glyphs"].update(extra)
        added.update(extra)
        widths = sorted({w for w, _ in extra.values()})
        print("  + %-28s %-16s %4d glyphs, width %s" % (path.rsplit("/", 1)[-1], label, len(extra), widths))
    out, nr, ng = build(font)
    with open(dst, "wb") as f:
        f.write(out)
    print("output: %d ranges, %d pictures, %d bytes (original %d), %d added" % (nr, ng, len(out), len(data), len(added)))
    check = parse(out)
    same = all(check["glyphs"][cp] == pic for cp, pic in original.items())
    print("every original picture still maps to the same code point:", same)
    if pack_out and same:
        write_pack(pack_out, added, font["height"])
        print("pack: %s, %d pictures" % (pack_out.rsplit("/", 1)[-1], len(added)))
    return 0 if same else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
