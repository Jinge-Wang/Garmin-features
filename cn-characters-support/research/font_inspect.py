"""Inspect the font files a Garmin watch keeps in Garmin/ExtData.

Finding on a fenix 6X Pro (firmware 28.02): the 006-D0952-NN.bin
files are ordinary TrueType fonts with every byte XOR-ed with 0x76. This script
undoes that mask in memory, reads the standard tables, and reports the font's
names, glyph count and which Unicode blocks its character map covers.

Nothing is written unless --save <dir> is given.

usage: font_inspect.py [--save <dir>] <file.bin> [...]
"""
import struct
import sys

MASK = 0x76

BLOCKS = [
    (0x0000, 0x007F, "Basic Latin"),
    (0x0080, 0x024F, "Latin extended"),
    (0x0370, 0x03FF, "Greek"),
    (0x0400, 0x052F, "Cyrillic"),
    (0x0590, 0x05FF, "Hebrew"),
    (0x0600, 0x06FF, "Arabic"),
    (0x0750, 0x077F, "Arabic supplement"),
    (0x0E00, 0x0E7F, "Thai"),
    (0x1100, 0x11FF, "Hangul jamo"),
    (0x2000, 0x206F, "General punctuation"),
    (0x3000, 0x303F, "CJK punctuation"),
    (0x3040, 0x30FF, "Hiragana and katakana"),
    (0x3400, 0x4DBF, "CJK extension A"),
    (0x4E00, 0x9FFF, "CJK ideographs"),
    (0xAC00, 0xD7AF, "Hangul syllables"),
    (0xFB1D, 0xFB4F, "Hebrew presentation forms"),
    (0xFB50, 0xFDFF, "Arabic presentation forms A"),
    (0xFE70, 0xFEFF, "Arabic presentation forms B"),
    (0xFF00, 0xFFEF, "Fullwidth forms"),
]


def unmask(data):
    return bytes(b ^ MASK for b in data)


def tables(font):
    num = struct.unpack(">H", font[4:6])[0]
    out = {}
    for i in range(num):
        tag, _chk, off, length = struct.unpack(">4sLLL", font[12 + 16 * i:28 + 16 * i])
        out[tag.decode("latin-1")] = (off, length)
    return out


def names(font, tabs):
    if "name" not in tabs:
        return {}
    off, _ = tabs["name"]
    _fmt, count, string_off = struct.unpack(">HHH", font[off:off + 6])
    out = {}
    for i in range(count):
        pid, eid, _lid, nid, length, noff = struct.unpack(">6H", font[off + 6 + 12 * i:off + 18 + 12 * i])
        raw = font[off + string_off + noff:off + string_off + noff + length]
        try:
            s = raw.decode("utf-16-be") if pid in (0, 3) else raw.decode("latin-1")
        except UnicodeDecodeError:
            continue
        if nid in (1, 2, 4, 5, 6) and nid not in out:
            out[nid] = s
    return out


def cmap_codepoints(font, tabs):
    off, _ = tabs["cmap"]
    _ver, n = struct.unpack(">HH", font[off:off + 4])
    best = None
    for i in range(n):
        pid, eid, sub = struct.unpack(">HHL", font[off + 4 + 8 * i:off + 12 + 8 * i])
        fmt = struct.unpack(">H", font[off + sub:off + sub + 2])[0]
        rank = {12: 3, 4: 2}.get(fmt, 0)
        if pid in (0, 3) and (best is None or rank > best[0]):
            best = (rank, fmt, off + sub)
    if best is None:
        return set(), None
    _, fmt, p = best
    cps = set()
    if fmt == 4:
        segx2 = struct.unpack(">H", font[p + 6:p + 8])[0]
        seg = segx2 // 2
        ends = struct.unpack(">%dH" % seg, font[p + 14:p + 14 + segx2])
        starts = struct.unpack(">%dH" % seg, font[p + 16 + segx2:p + 16 + 2 * segx2])
        for s, e in zip(starts, ends):
            if s <= e and e != 0xFFFF:
                cps.update(range(s, e + 1))
    elif fmt == 12:
        ngroups = struct.unpack(">L", font[p + 12:p + 16])[0]
        for g in range(ngroups):
            s, e, _gid = struct.unpack(">LLL", font[p + 16 + 12 * g:p + 28 + 12 * g])
            cps.update(range(s, e + 1))
    return cps, fmt


def main(argv):
    save = None
    if argv and argv[0] == "--save":
        save, argv = argv[1], argv[2:]
    for path in argv:
        raw = open(path, "rb").read()
        font = unmask(raw)
        base = path.rsplit("/", 1)[-1]
        print("=" * 72)
        print(base, len(raw), "bytes")
        sig = font[:4]
        ok = sig in (b"\x00\x01\x00\x00", b"OTTO", b"true", b"ttcf")
        print("signature after unmasking:", sig.hex(), "(TrueType)" if ok else "(not a font signature)")
        if not ok:
            continue
        tabs = tables(font)
        print("tables:", " ".join(sorted(tabs)))
        nm = names(font, tabs)
        for nid, label in ((1, "family"), (2, "style"), (4, "full name"), (5, "version")):
            if nid in nm:
                print("  %-9s: %s" % (label, nm[nid]))
        if "maxp" in tabs:
            print("  glyphs   :", struct.unpack(">H", font[tabs["maxp"][0] + 4:tabs["maxp"][0] + 6])[0])
        if "head" in tabs:
            print("  units/em :", struct.unpack(">H", font[tabs["head"][0] + 18:tabs["head"][0] + 20])[0])
        print("  outlines :", "TrueType (glyf)" if "glyf" in tabs else "CFF" if "CFF " in tabs else "bitmap only" if "EBDT" in tabs else "?")
        cps, fmt = cmap_codepoints(font, tabs)
        print("  character map format %s, %d code points" % (fmt, len(cps)))
        rest = set(cps)
        for lo, hi, name in BLOCKS:
            n = sum(1 for c in cps if lo <= c <= hi)
            rest -= set(range(lo, hi + 1))
            if n:
                print("     %-28s %5d" % (name, n))
        if rest:
            print("     %-28s %5d  (%s...)" % ("other", len(rest), " ".join("U+%04X" % c for c in sorted(rest)[:6])))
        if save:
            out = save.rstrip("/") + "/" + base.rsplit(".", 1)[0] + ".ttf"
            with open(out, "wb") as f:
                f.write(font)
            print("  unmasked copy saved to", out)


if __name__ == "__main__":
    main(sys.argv[1:])
