import struct, sys, zlib
for path in sys.argv[1:]:
    d = open(path, "rb").read()
    name = path.rsplit("/", 1)[-1]
    n = len(d)
    pn = d[-13:-1]
    print("=" * 64)
    print(name, n, "bytes; part number in trailer:", pn, " byte before it: 0x%02x" % d[-14])
    print("  version byte d[-15] = %d ; bytes before: %s" % (d[-15], d[-23:-15].hex(" ")))
    for label, span in (("whole file", d), ("all but last 14", d[:-14]), ("all but last 15", d[:-15]),
                        ("all but last 16", d[:-16]), ("all but last 21", d[:-21])):
        print("  sum mod 256 of %-16s = 0x%02x   xor = 0x%02x" % (label, sum(span) & 0xFF, __import__("functools").reduce(lambda a, b: a ^ b, span, 0)))
    if name.endswith(".bin"):
        f = bytes(b ^ 0x76 for b in d)
        num = struct.unpack(">H", f[4:6])[0]
        end = 0
        for i in range(num):
            tag, chk, off, ln = struct.unpack(">4sLLL", f[12 + 16 * i:28 + 16 * i])
            end = max(end, off + ln)
        print("  font tables end at %d (padded %d); bytes after the font: %d -> %s" % (end, (end + 3) & ~3, n - ((end + 3) & ~3), d[(end + 3) & ~3:].hex(" ")[:90]))
