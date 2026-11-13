"""Try common 32-bit check algorithms against the 4 bytes stored after a .fnt body."""
import hashlib, struct, sys, zlib

d = open(sys.argv[1], "rb").read()
body = struct.unpack_from("<I", d, 4)[0]
stored = d[body:body + 4]
targets = {stored, stored[::-1]}
print("stored bytes:", stored.hex(" "))

def rev32(x):
    return int("{:032b}".format(x)[::-1], 2)

def make_table(poly, refl):
    t = []
    for i in range(256):
        if refl:
            c = i
            for _ in range(8):
                c = (c >> 1) ^ (rev32(poly) if c & 1 else 0)
        else:
            c = i << 24
            for _ in range(8):
                c = ((c << 1) ^ poly) & 0xFFFFFFFF if c & 0x80000000 else (c << 1) & 0xFFFFFFFF
        t.append(c)
    return t

def crc(data, table, refl, init):
    c = init
    if refl:
        for b in data:
            c = table[(c ^ b) & 0xFF] ^ (c >> 8)
    else:
        for b in data:
            c = table[((c >> 24) ^ b) & 0xFF] ^ ((c << 8) & 0xFFFFFFFF)
    return c

spans = {
    "body": d[:body],
    "body after header": d[36:body],
    "glyph data": d[struct.unpack_from("<I", d, 16)[0]:body],
    "body + rest of trailer": d[:body] + d[body + 4:],
    "whole file with check zeroed": d[:body] + b"\0\0\0\0" + d[body + 4:],
}
hits = []
polys = {"CRC-32": 0x04C11DB7, "CRC-32C": 0x1EDC6F41, "CRC-32K": 0x741B8CD7, "CRC-32Q": 0x814141AB, "CRC-32D": 0xA833982B}
for sname, span in spans.items():
    for pname, poly in polys.items():
        for refl in (True, False):
            table = make_table(poly, refl)
            base0 = crc(span, table, refl, 0)
            baseF = crc(span, table, refl, 0xFFFFFFFF)
            for init, val in ((0, base0), (0xFFFFFFFF, baseF)):
                for xo in (0, 0xFFFFFFFF):
                    v = val ^ xo
                    for enc in (struct.pack("<I", v), struct.pack(">I", v)):
                        if enc in targets:
                            hits.append((sname, pname, refl, hex(init), hex(xo)))
    # simple sums and digests
    s16 = sum(struct.unpack("<%dH" % (len(span) // 2), span[:len(span) // 2 * 2])) & 0xFFFFFFFF
    a = b = 0
    for i in range(0, len(span) - 1, 2):
        a = (a + span[i] + (span[i + 1] << 8)) % 65535
        b = (b + a) % 65535
    for label, v in (("sum16", s16), ("fletcher32", (b << 16) | a), ("neg sum8", (-sum(span)) & 0xFFFFFFFF),
                     ("adler32", zlib.adler32(span) & 0xFFFFFFFF)):
        for enc in (struct.pack("<I", v), struct.pack(">I", v)):
            if enc in targets:
                hits.append((sname, label))
    for h in ("md5", "sha1", "sha256"):
        dg = hashlib.new(h, span).digest()
        if dg[:4] in targets or dg[-4:] in targets:
            hits.append((sname, h))
print("matches:", hits if hits else "none among %d spans x CRC variants, sums and digests" % len(spans))
