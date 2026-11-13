"""Build the one-file language test for a Garmin .ln4 language file.

A .ln4 file is UTF-8 text: one header line, then one line per string,
"<8 hex id> <translation>". This script copies a source file and changes a
small, fixed set of lines so that one look at the watch answers three things:

  1. does the watch accept an edited language file at all (the Latin lines);
  2. what does it draw for Chinese, Japanese and Korean (blank, box or glyph);
  3. does it draw Arabic, Hebrew, Cyrillic, Greek and Thai while the selected
     language is another one, that is, does it choose a font per character.

Every test string starts with a two-character Latin tag so that a line can be
identified on the watch even when the script after the tag does not render.

The lines needed to get back to the language setting are left alone.

usage: make_test_ln4.py <source.ln4> <output.ln4>
"""
import sys

# Danish text of the line to change  ->  what to show instead.
# Chosen from the Settings list and the main menu of the watch.
BY_TEXT = {
    "Aktiviteter og apps": "A1 Latin edited",
    "Widgets": "B2 中文测试",
    "Sensorer og tilbehør": "C3 繁體中文",
    "Fysiologiske målinger": "D4 عربي",
    "Brugerprofil": "E5 עברית",
    "Strømstyring": "F6 Русский",
    "Musik": "G7 日本語 かな",
    "Telefon": "H8 한국어",
    "Wi-Fi": "I9 ไทย",
    "Urskive": "J0 Ελληνικά",
    "Historik": "K1 历史记录",
}

# The string each file uses for its own name in the language list.
BY_ID = {
    "b30b1c44": "Dansk TEST 中文",
}

# Second test (after the first showed: edited files are accepted, the menus
# choose a font per character, and Chinese, Japanese, Korean and Thai come out
# as diamonds). It asks: do the menus use the emoji picture table, and do
# characters added to that table show up?
BY_TEXT_2 = {
    "Aktiviteter og apps": "A1 ⌚☀❤",        # emoji below U+10000, already in the table
    "Widgets": "B2 😀🚀",                      # emoji above U+10000, already in the table
    "Sensorer og tilbehør": "C3 ㊗㊙",         # CJK-block symbols, already in the table
    "Fysiologiske målinger": "D4 中文测试",     # added to the table by the test
    "Brugerprofil": "E5 汉字你好",              # added
    "Strømstyring": "F6 かな 한국",             # added
    "Musik": "G7 中a文b",                      # added, mixed with Latin
    "Telefon": "H8 上下",                      # NOT added: the control, expect diamonds
    "Historik": "K1 历史记录",                  # added, shown in the main menu
}
BY_ID_2 = {}

# Third test (after the second showed: the menus and the notifications draw any
# character the picture table lists, and the 24 px characters in 27 px cells
# looked too widely spaced). A calibration: each line uses its own characters,
# drawn at its own size and cell width, so one photo settles size and spacing.
BY_TEXT_3 = {
    "Aktiviteter og apps": "S1 █████",        # solid 27 px blocks: shows the gap the watch adds itself
    "Widgets": "S2 你好中文",                   # 26 px in 27 px cells, smooth white
    "Sensorer og tilbehør": "S3 测试汉字",      # 24 px in 25 px cells, smooth white
    "Fysiologiske målinger": "S4 历史记录",     # 22 px in 23 px cells, smooth white
    "Brugerprofil": "S5 上下左右",              # 20 px in 21 px cells, smooth white
    "Strømstyring": "S6 设置系统",              # 24 px in 25 px cells, hard-edged white
    "Musik": "S7 语言时间",                     # 24 px in 25 px cells, smooth black (for a light screen)
    "Telefon": "S8 测a试b汉1字2",               # the S3 characters mixed with Latin: baseline check
    "Historik": "K1 历史记录",                  # main menu, the S4 characters
}
BY_ID_3 = {}

# Fourth test (after the third showed: menus and notifications have a light
# background, so white ink vanished and black ink read well; spacing and
# baseline were right; 20 px was too small). It asks: which size and weight in
# dark ink, and which single ink stays readable on a dark screen as well.
BY_TEXT_4 = {
    "Aktiviteter og apps": "T1 你好中文",        # 26 px in 27, black, smooth, regular weight
    "Widgets": "T2 测试汉字",                    # 24 px in 25, black, smooth, regular
    "Sensorer og tilbehør": "T3 历史记录",       # 22 px in 23, black, smooth, regular
    "Fysiologiske målinger": "T4 设置系统",      # 24 px in 25, black, hard edges, regular
    "Brugerprofil": "T5 语言时间",               # 24 px in 25, black, smooth, semibold
    "Strømstyring": "T6 上下左右",               # 24 px in 25, red, hard edges
    "Musik": "T7 天气日月",                      # 24 px in 25, mauve, hard edges
    "Telefon": "T8 运动心率",                    # 24 px in 25, blue, hard edges
    "Historik": "K1 历史记录",                   # main menu
    # One character of each ink (black, red, mauve, blue) on screens that may be dark:
    "Skridt": "W 测上天运",                      # Steps widget
    "Vejr": "W 测上天运",                        # Weather widget
    "Kalender": "W 测上天运",                    # Calendar widget
    "Meddelelser": "W 测上天运",                 # Notifications widget
    "Body Battery": "W 测上天运",                # Body Battery widget
    "Løb": "R 测上天运",                         # Run, in the activity list
    "Cykling": "R 测上天运",                     # Bike, in the activity list
}
BY_ID_4 = {}

# Fifth test = the fourth plus two inks made for dark screens: black with a
# white rim around the strokes, and black on an opaque white cell.
SAMPLE_5 = "测上天运开保"   # black, red, mauve, blue, rimmed, on a white cell
BY_TEXT_5 = dict(BY_TEXT_4)
BY_TEXT_5.update({
    "Wi-Fi": "T9 开始结束",                      # 24 px in 25, black with a white rim
    "Urskive": "T0 保存返回",                    # 24 px in 25, black on a white cell (main menu)
    "Skridt": "W " + SAMPLE_5,
    "Vejr": "W " + SAMPLE_5,
    "Kalender": "W " + SAMPLE_5,
    "Meddelelser": "W " + SAMPLE_5,
    "Body Battery": "W " + SAMPLE_5,
    "Løb": "R " + SAMPLE_5,
    "Cykling": "R " + SAMPLE_5,
})
BY_ID_5 = {}

# Sixth test (after the fifth: heavy strokes at about 25 px and the
# black-on-white-cell ink were preferred; dark title bands exist inside the menus; the gap
# between characters is still too wide). A ruler measures the gap the watch
# itself adds between pictures, and the text lines use cells cut to the ink.
BY_TEXT_6 = {
    "Aktiviteter og apps": "R1 ██████",          # 10 px solid blocks: the gap between them is the watch's own
    "Widgets": "R2 ①②③④⑤⑥",                     # pairs of bars with known gaps of 1 to 6 px
    "Sensorer og tilbehør": "R3 ⑧⑩⑫⑭",          # pairs with known gaps of 8, 10, 12, 14 px
    "Fysiologiske målinger": "R4 ▉▉▉▉",          # 20 px solid blocks: same gap as R1?
    "Brugerprofil": "F1 设置系统语言",            # 25 px semibold, white cell, 23 px wide (cut to the ink)
    "Strømstyring": "F2 你好中文测试",            # same, 25 px wide
    "Musik": "F3 历史记录上下",                   # same, 24 px wide
    "Telefon": "F4 天气日月运动",                 # 25 px semibold, red, 23 px wide
    "Wi-Fi": "F5 开始结束保存",                   # 24 px semibold, white cell, 22 px wide
    "Historik": "K1 语言 abc 设置 123",           # main menu: mixed with Latin
}
BY_ID_6 = {}

# Seventh test (after the sixth: the watch adds 2 px after every picture and
# advances by picture width; 25 px semibold in 23 px cells looks right; white
# cells behind the characters look odd on the black title band). One geometry,
# nine inks chosen for contrast against both white and black.
BY_TEXT_7 = {
    "Aktiviteter og apps": "C1 设置系统语言",     # red            0x30
    "Widgets": "C2 你好中文测试",                 # mauve          0x26
    "Sensorer og tilbehør": "C3 历史记录上下",    # violet         0x23
    "Fysiologiske målinger": "C4 天气日月运动",   # dusty red      0x25
    "Brugerprofil": "C5 开始结束保存",            # blue           0x17
    "Strømstyring": "C6 时间心率左右",            # brown          0x24
    "Musik": "C7 返回确认取消",                   # vivid blue     0x07
    "Telefon": "C8 音乐电话通知",                 # slate          0x16
    "Wi-Fi": "C9 地图导航距离",                   # neutral grey, dithered
    "Historik": "K1 设置 12:30 abc",             # main menu: red characters beside Latin
}
BY_ID_7 = {}

# Eighth test: Chinese as a real font. Shapes are added to copies of the
# watch's Hebrew fonts (006-D0952-07/08) and to a new file under the Chinese
# slot name (006-D0952-01). If the watch draws them, Chinese takes the system's
# own colours and sizes.
BY_TEXT_8 = {
    "Aktiviteter og apps": "H1 设置系统语言",     # shapes inside the Hebrew font files
    "Widgets": "N1 你好中文测试",                 # shapes inside the new Chinese-slot file
    "Sensorer og tilbehør": "P1 历史记录上下",    # control: blue pictures in the emoji table
    "Fysiologiske målinger": "X1 天气日月运动",   # control: nowhere, expect diamonds
    "Brugerprofil": "H2 设a置b系1统2",            # Hebrew-font shapes beside Latin
    "Strømstyring": "E1 עברית",                  # Hebrew itself still draws
    "Historik": "K1 设置系统",                    # main menu
}
BY_ID_8 = {}

# Ninth test (after the eighth: the watch reads my rebuilt Hebrew fonts but
# never looks in them for Chinese, and ignores a font named for the Chinese
# slot). Two questions: does the watch take a picture table with the whole
# Chinese block (14 MB), and does it read a font under any other slot name.
BY_TEXT_9 = {
    "Aktiviteter og apps": "M1 设置系统语言",      # pictures: everyday simplified
    "Widgets": "M2 繁體中文測試",                  # pictures: traditional
    "Sensorer og tilbehør": "M3 你好，世界！（测试）",  # pictures: punctuation
    "Fysiologiske målinger": "Q1 龘靐齉爨灪麤",    # probe: only in the slot-name fonts, not in the table
    "Brugerprofil": "Q2 かな 한국 ไทย",            # probe: Japanese, Korean, Thai, only in the slot-name fonts
    "Historik": "K1 历史记录",                    # main menu
}
BY_ID_9 = {}

# Never touch these: they are the way back to the language setting.
KEEP = {"Indstillinger", "System", "Sprog"}


def main(src, dst, which="1"):
    global BY_TEXT, BY_ID
    if which == "2":
        BY_TEXT, BY_ID = BY_TEXT_2, BY_ID_2
    elif which == "3":
        BY_TEXT, BY_ID = BY_TEXT_3, BY_ID_3
    elif which == "4":
        BY_TEXT, BY_ID = BY_TEXT_4, BY_ID_4
    elif which == "5":
        BY_TEXT, BY_ID = BY_TEXT_5, BY_ID_5
    elif which == "6":
        BY_TEXT, BY_ID = BY_TEXT_6, BY_ID_6
    elif which == "7":
        BY_TEXT, BY_ID = BY_TEXT_7, BY_ID_7
    elif which == "8":
        BY_TEXT, BY_ID = BY_TEXT_8, BY_ID_8
    elif which == "9":
        BY_TEXT, BY_ID = BY_TEXT_9, BY_ID_9
    with open(src, "rb") as f:
        raw = f.read()
    text = raw.decode("utf-8")  # raises if the source is not valid UTF-8
    lines = text.split("\n")
    assert lines[-1] == "", "source must end with a newline"
    body = lines[:-1]
    header = body[0]

    changed = []
    out = [header]
    for line in body[1:]:
        ident, sep, value = line.partition(" ")
        assert len(ident) == 8 and sep == " ", "unexpected line: %r" % line
        new = value
        if ident in BY_ID:
            new = BY_ID[ident]
        elif value in BY_TEXT and value not in KEEP:
            new = BY_TEXT[value]
        if new != value:
            changed.append((ident, value, new))
        out.append(ident + " " + new)

    result = ("\n".join(out) + "\n").encode("utf-8")
    with open(dst, "wb") as f:
        f.write(result)

    # Checks: same number of lines, same ids in the same order, header intact.
    new_lines = result.decode("utf-8").split("\n")[:-1]
    assert len(new_lines) == len(body)
    assert new_lines[0] == header
    assert [l[:8] for l in new_lines[1:]] == [l[:8] for l in body[1:]]
    assert b"\r" not in result

    print("header      :", header)
    print("lines       :", len(body), "(unchanged)")
    print("bytes       :", len(raw), "->", len(result))
    print("lines edited:", len(changed))
    for ident, old, new in changed:
        print("  %s  %-24s -> %s" % (ident, old, new))
    missing = [t for t in BY_TEXT if t not in {c[1] for c in changed}]
    if missing:
        print("not found in the source:", missing)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "1")
