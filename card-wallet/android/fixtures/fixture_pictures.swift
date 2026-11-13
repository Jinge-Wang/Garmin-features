// fixture_pictures: draws the dummy QR pictures that the phone app's tests read,
// and checks the Mac tool's answer for them.
//
//   fixture_pictures <folder> <source grids .json>
//       draws qr-*.png and writes list.json (the list given to cardtool) into
//       the folder, and the grid each picture was drawn from into the second file
//   fixture_pictures check <expected.json> <source grids .json>
//       compares the grids cardtool wrote with the grids the pictures were drawn
//       from; exit code 1 when one differs
//
// Every code here is a dummy made up for the tests. Runs on this computer only.

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Fail: Error, CustomStringConvertible {
    let description: String
    init(_ text: String) { description = text }
}

/// The picture as 8-bit grey, row 0 at the top.
func greyPixels(_ image: CGImage) -> (width: Int, height: Int, pixels: [UInt8]) {
    let w = image.width
    let h = image.height
    var buffer = [UInt8](repeating: 255, count: w * h)
    buffer.withUnsafeMutableBytes { raw in
        guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return (w, h, buffer)
}

/// The module grid Core Image encodes for a text at an error-correction level.
func sourceGrid(_ text: String, level: String) throws -> [[Bool]] {
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { throw Fail("CIQRCodeGenerator is missing") }
    filter.setValue(Data(text.utf8), forKey: "inputMessage")
    filter.setValue(level, forKey: "inputCorrectionLevel")
    let context = CIContext(options: [.useSoftwareRenderer: true])
    guard let drawn = filter.outputImage,
          let image = context.createCGImage(drawn, from: drawn.extent.integral) else {
        throw Fail("Core Image could not draw a code")
    }
    let (w, h, pixels) = greyPixels(image)
    var minX = w, maxX = -1, minY = h, maxY = -1
    for y in 0..<h {
        for x in 0..<w where pixels[y * w + x] < 128 {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    let n = maxX - minX + 1
    guard maxX >= 0, n == maxY - minY + 1, n >= 21, n <= 177, (n - 17) % 4 == 0 else {
        throw Fail("the drawn code has an unexpected size")
    }
    var grid = [[Bool]](repeating: [Bool](repeating: false, count: n), count: n)
    for r in 0..<n {
        for c in 0..<n {
            grid[r][c] = pixels[(minY + r) * w + (minX + c)] < 128
        }
    }
    return grid
}

/// Each row as hex, as tools/cardtool.swift writes it.
func hexRows(of grid: [[Bool]]) -> [String] {
    let digits = Array("0123456789abcdef")
    return grid.map { row in
        var out = ""
        var c = 0
        while c < row.count {
            var v = 0
            for k in 0..<4 {
                v = v << 1
                if c + k < row.count, row[c + k] { v |= 1 }
            }
            out.append(digits[v])
            c += 4
        }
        return out
    }
}

/// The grid as exact pixels: `scale` px per module, `quiet` modules of white around it.
func plain(_ grid: [[Bool]], scale: Int, quiet: Int) throws -> CGImage {
    let n = grid.count
    let side = (n + 2 * quiet) * scale
    var buffer = [UInt8](repeating: 255, count: side * side)
    for r in 0..<n {
        for c in 0..<n where grid[r][c] {
            for dy in 0..<scale {
                let line = ((r + quiet) * scale + dy) * side + (c + quiet) * scale
                for dx in 0..<scale { buffer[line + dx] = 0 }
            }
        }
    }
    guard let provider = CGDataProvider(data: Data(buffer) as CFData),
          let image = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: side,
                              space: CGColorSpaceCreateDeviceGray(),
                              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                              provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
        throw Fail("cannot build a picture")
    }
    return image
}

/// The code inside a larger picture, as a screenshot or a photo holds it: a
/// background, an optional dark bar at the top, the code at a module size that
/// need not be a whole number of pixels, optionally turned by a few degrees.
func scene(_ grid: [[Bool]], width: Int, height: Int, background: CGFloat, centerX: CGFloat, centerY: CGFloat,
           modulePx: CGFloat, degrees: CGFloat, bar: Bool) throws -> CGImage {
    guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                              space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
        throw Fail("cannot build a picture")
    }
    ctx.setFillColor(gray: background, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    if bar {
        // Core Graphics counts rows from the bottom.
        ctx.setFillColor(gray: 0.15, alpha: 1)
        ctx.fill(CGRect(x: 0, y: height - 170, width: width, height: 170))
    }
    let quiet = 4
    let tile = try plain(grid, scale: 8, quiet: quiet)
    let side = CGFloat(grid.count + 2 * quiet) * modulePx
    ctx.saveGState()
    ctx.translateBy(x: centerX, y: CGFloat(height) - centerY)
    ctx.rotate(by: degrees * .pi / 180)
    ctx.interpolationQuality = .high
    ctx.draw(tile, in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
    ctx.restoreGState()
    guard let image = ctx.makeImage() else { throw Fail("cannot build a picture") }
    return image
}

func savePNG(_ image: CGImage, _ path: String) throws {
    let url = URL(fileURLWithPath: path)
    guard let out = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw Fail("cannot write \(path)")
    }
    CGImageDestinationAddImage(out, image, nil)
    guard CGImageDestinationFinalize(out) else { throw Fail("cannot write \(path)") }
}

/// A dummy text of a given length.
func filler(_ length: Int, tag: String) -> String {
    var text = "SAMPLE-CARD-\(tag)"
    var k = 0
    while text.count < length {
        text += " dummy-\(k)"
        k += 1
    }
    return String(text.prefix(length))
}

enum Look {
    case plain(scale: Int)
    case screenshot
    case photo
}

struct Case {
    let name: String
    let file: String
    let text: String
    let level: String
    let look: Look
}

let cases: [Case] = [
    Case(name: "Short L", file: "qr-short-l.png", text: "SAMPLE-0001", level: "L", look: .plain(scale: 12)),
    Case(name: "Medium M", file: "qr-medium-m.png", text: "SAMPLE-CARD-0000 dummy membership 0123456789", level: "M",
         look: .plain(scale: 8)),
    Case(name: "Long Q", file: "qr-long-q.png", text: filler(90, tag: "Q"), level: "Q", look: .plain(scale: 6)),
    Case(name: "Longer H", file: "qr-longer-h.png", text: filler(150, tag: "H"), level: "H", look: .plain(scale: 5)),
    Case(name: "Digits M", file: "qr-digits-m.png", text: "0000123456789012345678901234567890", level: "M",
         look: .plain(scale: 10)),
    Case(name: "Large M", file: "qr-large-m.png", text: filler(420, tag: "LARGE"), level: "M", look: .plain(scale: 4)),
    Case(name: "Screenshot", file: "qr-screenshot.png", text: "SAMPLE-CARD-0001 dummy membership screenshot", level: "M",
         look: .screenshot),
    Case(name: "Photo", file: "qr-photo.png", text: "SAMPLE-CARD-0002 dummy photo", level: "Q", look: .photo),
]

let barCodes: [(name: String, number: String)] = [
    ("Bar even digits", "000012345678"),
    ("Bar odd digits", "1234567"),
    ("Bar text", "SAMPLE-0042"),
]

func draw(into folder: String, gridsPath: String) throws {
    var list: [[String: String]] = []
    var grids: [String: Any] = [:]
    for item in cases {
        let grid = try sourceGrid(item.text, level: item.level)
        let image: CGImage
        switch item.look {
        case .plain(let scale):
            image = try plain(grid, scale: scale, quiet: 4)
        case .screenshot:
            image = try scene(grid, width: 1080, height: 2400, background: 0.96, centerX: 540, centerY: 1300,
                              modulePx: 13, degrees: 0, bar: true)
        case .photo:
            image = try scene(grid, width: 1600, height: 1200, background: 0.55, centerX: 830, centerY: 590,
                              modulePx: 9.3, degrees: 6, bar: false)
        }
        try savePNG(image, "\(folder)/\(item.file)")
        list.append(["name": item.name, "image": item.file])
        grids[item.name] = ["n": grid.count, "g": hexRows(of: grid)]
        print("\(item.name): \(grid.count) x \(grid.count) modules, level \(item.level), \(image.width) x \(image.height) px")
    }
    for bar in barCodes {
        list.append(["name": bar.name, "number": bar.number])
    }
    let listData = try JSONSerialization.data(withJSONObject: ["cards": list], options: [.prettyPrinted, .sortedKeys])
    try listData.write(to: URL(fileURLWithPath: "\(folder)/list.json"))
    let gridData = try JSONSerialization.data(withJSONObject: grids, options: [.sortedKeys])
    try gridData.write(to: URL(fileURLWithPath: gridsPath))
}

func check(expectedPath: String, gridsPath: String) throws {
    let expected = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: expectedPath)))
    let source = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: gridsPath)))
    guard let cards = (expected as? [String: Any])?["cards"] as? [[String: Any]],
          let grids = source as? [String: [String: Any]] else {
        throw Fail("cannot read the two files")
    }
    var bad = 0
    var seen = 0
    for card in cards where card["kind"] as? String == "qr" {
        guard let name = card["name"] as? String, let drawn = grids[name] else {
            throw Fail("a card in the tool's answer has no drawn code")
        }
        seen += 1
        let same = (card["n"] as? Int) == (drawn["n"] as? Int) && (card["g"] as? [String]) == (drawn["g"] as? [String])
        if !same { bad += 1 }
        print("\(name): the tool's grid is identical to the drawn code: \(same ? "yes" : "NO")")
    }
    guard seen == grids.count else { throw Fail("the tool's answer holds \(seen) QR cards, \(grids.count) were drawn") }
    if bad > 0 { exit(1) }
}

do {
    let arguments = CommandLine.arguments
    if arguments.count == 4, arguments[1] == "check" {
        try check(expectedPath: arguments[2], gridsPath: arguments[3])
    } else if arguments.count == 3 {
        try draw(into: arguments[1], gridsPath: arguments[2])
    } else {
        throw Fail("usage: fixture_pictures <folder> <source grids .json>\n"
            + "       fixture_pictures check <expected.json> <source grids .json>")
    }
} catch {
    FileHandle.standardError.write("fixture_pictures: \(error)\n".data(using: .utf8)!)
    exit(1)
}
