"""Describe what a Garmin .ln4 language file holds: text, or text plus glyph data."""
import math
import sys
from collections import Counter

for path in sys.argv[1:]:
    data = open(path, "rb").read()
    n = len(data)
    print("=" * 70)
    print(path.rsplit("/", 1)[-1], n, "bytes")
    print("first 64 bytes :", data[:64].hex(" "))
    print("first 64 ascii :", "".join(chr(b) if 32 <= b < 127 else "." for b in data[:64]))

    # How much of the file decodes as UTF-8 text?
    try:
        data.decode("utf-8")
        whole_utf8 = True
    except UnicodeDecodeError as e:
        whole_utf8 = False
        print("utf-8 decode   : fails at offset", e.start)
    print("whole file is valid UTF-8:", whole_utf8)

    # Entropy per 4 KiB block: text sits near 4-5 bits/byte, packed glyph
    # bitmaps or compressed data near 7-8.
    block = 4096
    ent = []
    for i in range(0, n, block):
        chunk = data[i:i + block]
        c = Counter(chunk)
        h = -sum(v / len(chunk) * math.log2(v / len(chunk)) for v in c.values())
        ent.append(h)
    print("entropy bits/byte: min %.2f  mean %.2f  max %.2f over %d blocks"
          % (min(ent), sum(ent) / len(ent), max(ent), len(ent)))
    hi = [i for i, h in enumerate(ent) if h > 7.0]
    print("blocks above 7.0 bits/byte (binary-looking):", len(hi), hi[:10])

    # Byte classes
    zero = data.count(0)
    ascii_print = sum(1 for b in data if 32 <= b < 127)
    high = sum(1 for b in data if b >= 0x80)
    print("NUL bytes %.1f%%  printable ASCII %.1f%%  bytes >= 0x80 %.1f%%"
          % (100 * zero / n, 100 * ascii_print / n, 100 * high / n))

    # Split on NUL and show a few strings from the middle of the file
    parts = [p for p in data.split(b"\x00") if p]
    print("NUL-separated pieces:", len(parts))
    shown = 0
    for p in parts[len(parts) // 2:]:
        try:
            s = p.decode("utf-8")
        except UnicodeDecodeError:
            continue
        if 6 <= len(s) <= 60 and s.isprintable():
            print("   sample:", s)
            shown += 1
            if shown == 6:
                break

    # Which Unicode blocks do the decoded strings use?
    blocks = Counter()
    for p in parts:
        try:
            s = p.decode("utf-8")
        except UnicodeDecodeError:
            blocks["(undecodable piece)"] += 1
            continue
        for ch in s:
            o = ord(ch)
            if o < 0x80:
                blocks["Basic Latin"] += 1
            elif o < 0x250:
                blocks["Latin extended"] += 1
            elif 0x370 <= o < 0x400:
                blocks["Greek"] += 1
            elif 0x400 <= o < 0x530:
                blocks["Cyrillic"] += 1
            elif 0x4E00 <= o < 0xA000:
                blocks["CJK ideographs"] += 1
            else:
                blocks["other"] += 1
    print("characters by block:", dict(blocks.most_common()))
