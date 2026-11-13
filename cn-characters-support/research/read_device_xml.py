"""Summarize a GarminDevice.xml without printing the unit id or unlock codes."""
import re
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
root = ET.parse(path).getroot()


def strip(tag):
    return tag.split("}", 1)[-1]


def child(el, name):
    for c in el:
        if strip(c.tag) == name:
            return c
    return None


def text(el, name, default=""):
    c = child(el, name)
    return (c.text or "").strip() if c is not None else default


model = child(root, "Model")
print("MODEL")
print("  part number     :", text(model, "PartNumber"))
print("  software version:", text(model, "SoftwareVersion"))
print("  description     :", text(model, "Description"))

print("\nUPDATE COMPONENTS (part number, version, description, path)")
seen = set()
for el in root.iter():
    if strip(el.tag) != "UpdateFile":
        continue
    part = text(el, "PartNumber")
    desc = text(el, "Description")
    ver = child(el, "Version")
    v = ""
    if ver is not None:
        v = "%s.%s" % (text(ver, "Major"), text(ver, "Minor"))
    p = text(el, "Path")
    fn = text(el, "FileName")
    row = (part, v, desc, (p + "/" + fn).strip("/"))
    if row not in seen:
        seen.add(row)
        print("  %-14s %-8s %-34s %s" % row)

print("\nDATA TYPES THAT MENTION TEXT, LANGUAGE OR FONT")
for el in root.iter():
    if strip(el.tag) != "DataType":
        continue
    name = text(el, "Name")
    blob = ET.tostring(el, encoding="unicode")
    if re.search(r"text|lang|font|ln4|gtt", blob, re.I):
        paths = sorted(set(re.findall(r"<(?:\w+:)?Path>([^<]*)<", blob)))
        exts = sorted(set(re.findall(r"<(?:\w+:)?FileExtension>([^<]*)<", blob)))
        print("  %-28s paths=%s ext=%s" % (name, paths, exts))

raw = open(path, encoding="utf-8", errors="replace").read()
print("\nKEYWORD COUNTS IN THE WHOLE RECORD")
for kw in ["chinese", "japanese", "korean", "thai", "vietnam", "font", "cjk", "apac", "asia", "unicode"]:
    print("  %-9s %d" % (kw, len(re.findall(kw, raw, re.I))))
