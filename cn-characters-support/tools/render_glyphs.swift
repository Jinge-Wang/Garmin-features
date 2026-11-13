// Draw characters as small coverage maps for a Garmin picture-font table.
//
// usage: render_glyphs <font name> <cell width> <cell height> <glyph px> <characters> <output.txt> [--skip-missing]
//
// By default the program stops if the font lacks any requested character.
// With --skip-missing it draws the characters the font has and reports how
// many it left out.
//
// Every character is placed the same way: the ink box of the reference
// character 国 is centred in the cell, and all other characters use that same
// origin, so they share one baseline and one left edge rule.
//
// Output: one line per character, "<code point hex> <width> <height> <hex>",
// where hex is width*height two-digit coverage values (00 = empty, ff = full),
// row by row from the top. fnt_build.py turns coverage into palette values.

import AppKit
import CoreText
import Foundation

let args = CommandLine.arguments
let skipMissing = args.count == 8 && args[7] == "--skip-missing"
guard args.count == 7 || skipMissing,
      let cellW = Int(args[2]), let cellH = Int(args[3]), let glyphPx = Double(args[4]) else {
    FileHandle.standardError.write("usage: render_glyphs <font> <cell w> <cell h> <glyph px> <chars> <out> [--skip-missing]\n".data(using: .utf8)!)
    exit(2)
}
let fontName = args[1]
var chars = args[5]
let outPath = args[6]

// The font is either a name known to the system ("PingFangSC-Semibold") or a
// path to a font file, optionally followed by "@<weight>" for a variable font
// ("~/Library/Fonts/NotoSansSC[wght].ttf@600", with ~ written out in full).
func makeFont(_ spec: String, _ size: CGFloat) -> CTFont {
    if spec.hasPrefix("/") {
        let parts = spec.split(separator: "@", maxSplits: 1).map(String.init)
        let url = URL(fileURLWithPath: parts[0]) as CFURL
        guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor], !descs.isEmpty else {
            FileHandle.standardError.write("cannot read font file \(parts[0])\n".data(using: .utf8)!)
            exit(1)
        }
        var d = descs[0]
        if parts.count > 1, let w = Double(parts[1]) {
            let wght: UInt32 = 0x77676874  // 'wght'
            d = CTFontDescriptorCreateCopyWithVariation(d, NSNumber(value: wght), CGFloat(w))
        }
        return CTFontCreateWithFontDescriptor(d, size, nil)
    }
    return CTFontCreateWithName(spec as CFString, size, nil)
}

let font = makeFont(fontName, CGFloat(glyphPx))
let resolved = CTFontCopyPostScriptName(font) as String

// Refuse to draw from a substitute: CoreText silently borrows another font for
// characters this one lacks, which would make a comparison meaningless.
var missing = 0
var kept = String.UnicodeScalarView()
for scalar in chars.unicodeScalars {
    var present = true
    if scalar.value > 0x20 {
        var units = Array(String(scalar).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        present = CTFontGetGlyphsForCharacters(font, &units, &glyphs, units.count)
    }
    if present { kept.append(scalar) } else { missing += 1 }
}
if missing > 0 && !skipMissing {
    FileHandle.standardError.write("\(resolved) lacks \(missing) of the requested characters; not drawing from a substitute\n".data(using: .utf8)!)
    exit(1)
}
if missing > 0 {
    FileHandle.standardError.write("\(resolved) lacks \(missing) of the requested characters; skipped\n".data(using: .utf8)!)
    chars = String(kept)
}

func line(_ s: String) -> CTLine {
    let attr = NSAttributedString(string: s, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
    ])
    return CTLineCreateWithAttributedString(attr)
}

// Common origin from the reference character
let ref = CTLineGetBoundsWithOptions(line("国"), .useGlyphPathBounds)
let originX = ((CGFloat(cellW) - ref.width) / 2 - ref.minX).rounded()
let originY = ((CGFloat(cellH) - ref.height) / 2 - ref.minY).rounded()

var lines: [String] = []
for scalar in chars.unicodeScalars {
    if scalar.value <= 0x20 { continue }
    var pixels = [UInt8](repeating: 0, count: cellW * cellH)
    let ctx = CGContext(data: &pixels, width: cellW, height: cellH, bitsPerComponent: 8,
                        bytesPerRow: cellW, space: CGColorSpaceCreateDeviceGray(),
                        bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    ctx.setFillColor(gray: 0, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: cellW, height: cellH))
    ctx.setShouldAntialias(true)
    ctx.setShouldSmoothFonts(false)
    ctx.textPosition = CGPoint(x: originX, y: originY)
    CTLineDraw(line(String(scalar)), ctx)

    var hex = ""
    hex.reserveCapacity(cellW * cellH * 2)
    for v in pixels { hex += String(format: "%02x", v) }
    lines.append(String(format: "%04X %d %d ", scalar.value, cellW, cellH) + hex)
}
try! (lines.joined(separator: "\n") + "\n").write(toFile: outPath, atomically: true, encoding: .utf8)
FileHandle.standardError.write("\(resolved) \(glyphPx)px in \(cellW)x\(cellH): \(lines.count) glyphs -> \(outPath)\n".data(using: .utf8)!)
