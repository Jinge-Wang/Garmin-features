"""Inspect a Garmin bitmap font container (.fnt) from Garmin/ExtData.

Layout worked out from 006-D8168-00.fnt on a fenix 6X Pro
(firmware 28.02). All integers are little-endian.

  header, 36 bytes
     u16 header size (36)      u8 ?  u8 ?
     u32 body size (file size minus the trailer)
     u32 offset of the range table
     u32 offset of the glyph offset table
     u32 offset of the glyph data
     ... (fields not yet understood)
  range table
     u32 magic 0x12345678, u32 record size (12), u32 table size in bytes,
     u32 ?, u32 ?, then records of (first code point, last code point,
     glyph index of the first code point)
  glyph offset table
     one u32 per glyph: low 24 bits = offset into the glyph data,
     high 8 bits = glyph width in pixels
  glyph data
     width x height bytes per glyph, one byte per pixel
  trailer, 21 bytes
     u32 check value, u16 ?, u16 version (210 = 2.10), part number string

usage: fnt_inspect.py <file.fnt> [<contact sheet.png>]
"""
import struct
import sys
import zlib


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def block_name(cp):
    table = [
        (0x0000, 0x024F, "Latin"), (0x2000, 0x2BFF, "symbols and arrows"),
        (0x3000, 0x303F, "CJK punctuation"), (0x3040, 0x30FF, "kana"),
        (0x3200, 0x32FF, "enclosed CJK"), (0x4E00, 0x9FFF, "CJK ideographs"),
        (0xAC00, 0xD7AF, "Hangul"), (0xFE00, 0xFE0F, "variation selectors"),
        (0x1F000, 0x1F2FF, "emoji: tiles, cards, enclosed"),
        (0x1F300, 0x1F5FF, "emoji: symbols and pictographs"),
        (0x1F600, 0x1F64F, "emoji: faces"), (0x1F680, 0x1F6FF, "emoji: transport"),
        (0x1F900, 0x1FAFF, "emoji: supplemental"),
    ]
    for lo, hi, name in table:
        if lo <= cp <= hi:
            return name
    return "other"


def write_png(path, width, height, rgb_rows):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + bytes(row) for row in rgb_rows)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def main(path, sheet=None):
    data = open(path, "rb").read()
    n = len(data)
    hdr_size = struct.unpack_from("<H", data, 0)[0]
    body = u32(data, 4)
    off_ranges, off_index, off_glyphs = u32(data, 8), u32(data, 12), u32(data, 16)
    print("file size        :", n)
    print("header size      :", hdr_size, " bytes 2,3:", data[2], data[3])
    print("body size        :", body, " trailer:", n - body, "bytes")
    print("range table at   : 0x%x" % off_ranges)
    print("glyph index at   : 0x%x" % off_index)
    print("glyph data at    : 0x%x" % off_glyphs)
    print("other header u32 :", [hex(u32(data, o)) for o in (20, 24, 28, 32)])

    magic, rec, tsize = u32(data, off_ranges), u32(data, off_ranges + 4), u32(data, off_ranges + 8)
    print("range table magic: 0x%08x  record size: %d  table bytes: %d" % (magic, rec, tsize))
    print("two words after  :", u32(data, off_ranges + 12), u32(data, off_ranges + 16))

    # Glyph index: u24 offset + u8 width
    nglyph = (off_glyphs - off_index) // 4
    entries = [u32(data, off_index + 4 * i) for i in range(nglyph)]
    offs = [e & 0xFFFFFF for e in entries]
    widths = [e >> 24 for e in entries]
    glyph_bytes = body - off_glyphs
    sizes = [(offs[i + 1] if i + 1 < nglyph else glyph_bytes) - offs[i] for i in range(nglyph)]
    heights = sorted({s // w for s, w in zip(sizes, widths) if w and s % w == 0})
    print("glyphs           :", nglyph, " widths:", sorted(set(widths)), " heights:", heights)
    print("glyph data bytes :", glyph_bytes, " last glyph ends at body end:", offs[-1] + sizes[-1] == glyph_bytes)
    height = heights[-1] if heights else 0

    # Range records: try the two plausible starts and keep the one that is consistent
    best = None
    for start in (off_ranges + 12, off_ranges + 16, off_ranges + 20):
        recs, o = [], start
        while o + 12 <= off_index:
            a, b, g = struct.unpack_from("<III", data, o)
            recs.append((a, b, g))
            o += 12
        ok = sum(1 for i, (a, b, g) in enumerate(recs)
                 if a <= b and (i == 0 or (a > recs[i - 1][1] and g == recs[i - 1][2] + recs[i - 1][1] - recs[i - 1][0] + 1)))
        if best is None or ok > best[0]:
            best = (ok, start, recs)
    ok, start, recs = best
    # drop trailing records that break the pattern (padding or terminator)
    good = []
    for i, (a, b, g) in enumerate(recs):
        if a <= b and (not good or (a > good[-1][1] and g == good[-1][2] + good[-1][1] - good[-1][0] + 1)):
            good.append((a, b, g))
        else:
            break
    total = sum(b - a + 1 for a, b, _ in good)
    print("range records    : %d starting at 0x%x (of %d slots); code points covered: %d" % (len(good), start, len(recs), total))
    print("first records    :", ", ".join("U+%04X-%04X>%d" % r for r in good[:6]))
    print("last records     :", ", ".join("U+%04X-%04X>%d" % r for r in good[-4:]))
    if len(good) < len(recs):
        print("after the last   :", recs[len(good):len(good) + 2])
    print("highest glyph index used: %d (glyph count %d)" % (good[-1][2] + good[-1][1] - good[-1][0], nglyph))
    by_block = {}
    for a, b, _ in good:
        for cp in range(a, b + 1):
            by_block[block_name(cp)] = by_block.get(block_name(cp), 0) + 1
    for name, cnt in sorted(by_block.items(), key=lambda kv: -kv[1]):
        print("   %-34s %5d" % (name, cnt))

    # Pixel values
    hist = {}
    for v in data[off_glyphs:body]:
        hist[v] = hist.get(v, 0) + 1
    top = sorted(hist.items(), key=lambda kv: -kv[1])[:10]
    print("distinct pixel values:", len(hist), " most common:", ", ".join("0x%02x:%d" % kv for kv in top))
    print("values above 0x3f other than 0xff:", sorted(v for v in hist if 0x3F < v < 0xFF)[:12])

    # Trailer
    tr = data[body:]
    print("trailer          :", tr[:8].hex(" "), repr(tr[8:]))
    stored = u32(tr, 0)
    body_bytes = data[:body]
    cands = {
        "crc32(body)": zlib.crc32(body_bytes) & 0xFFFFFFFF,
        "adler32(body)": zlib.adler32(body_bytes) & 0xFFFFFFFF,
        "sum of bytes": sum(body_bytes) & 0xFFFFFFFF,
        "crc32(glyph data)": zlib.crc32(data[off_glyphs:body]) & 0xFFFFFFFF,
        "sum of u32 words": sum(struct.unpack("<%dI" % (body // 4), body_bytes[:body // 4 * 4])) & 0xFFFFFFFF,
    }
    print("stored check     : 0x%08x (little-endian), 0x%08x (big-endian)" % (stored, struct.unpack(">I", tr[:4])[0]))
    for name, v in cands.items():
        hit = v in (stored, struct.unpack(">I", tr[:4])[0], stored ^ 0xFFFFFFFF, (-stored) & 0xFFFFFFFF)
        print("   %-18s 0x%08x %s" % (name, v, "MATCH" if hit else ""))

    if sheet and height:
        cols, rows_n = 16, 5
        pad = 3
        cell = max(widths) + pad
        W, H = cols * cell + pad, rows_n * (height + pad) + pad
        canvas = [[(255, 255, 255)] * W for _ in range(H)]
        # glyphs 1.. are pictures; show the first 40 and a spread of 40 more
        picks = list(range(1, 41)) + [1 + i * (nglyph - 2) // 40 for i in range(40)]
        for k, gi in enumerate(picks[:cols * rows_n]):
            w, o = widths[gi], off_glyphs + offs[gi]
            cx, cy = pad + (k % cols) * cell, pad + (k // cols) * (height + pad)
            for y in range(height):
                for x in range(w):
                    v = data[o + y * w + x]
                    if v == 0xFF:
                        continue
                    r, g, b = (v >> 4) & 3, (v >> 2) & 3, v & 3
                    canvas[cy + y][cx + x] = (r * 85, g * 85, b * 85)
        scale = 3
        rows = []
        for row in canvas:
            line = []
            for px in row:
                line.extend(px * scale)
            for _ in range(scale):
                rows.append(line)
        write_png(sheet, W * scale, H * scale, rows)
        print("contact sheet    :", sheet)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
