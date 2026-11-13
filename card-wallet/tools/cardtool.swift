// cardtool: turns a list of cards into the data the watch app is built with.
//
// Everything runs on this computer with the system's own frameworks: Vision
// reads a code from a picture, Core Image draws one. The tool opens no network
// connection and prints no card content, only sizes and check results.
//
//   cardtool <cards.json> <out cards resource .json> <preview folder> [screen px]
//   cardtool same <picture 1> <picture 2>
//
// A card in the list is a QR code ({"name", "image"} or {"name", "text"}) or a
// bar code ({"name", "number"}). The resource is {"stamp", "cards"}: the QR
// cards in the watch's storage format (n, g), the bar codes as {"name", "kind":
// "bar", "t"}. The watch works out the bar widths itself, with its one encoder.
// The stamp is a hash of the cards, so the watch imports a changed list once.

import CoreGraphics
import CoreImage
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

struct CardIn: Decodable {
    let name: String
    let image: String?
    let text: String?
    let number: String?
}

struct CardsIn: Decodable {
    let cards: [CardIn]
}

struct Fail: Error, CustomStringConvertible {
    let description: String
    init(_ text: String) { description = text }
}

struct Reading {
    let text: String?
    let descriptor: CIQRCodeDescriptor
}

// MARK: pictures

func loadImage(_ path: String) throws -> CGImage {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw Fail("cannot open the picture \(path)")
    }
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

// MARK: reading a code

func readQR(_ image: CGImage, from what: String) throws -> Reading {
    let request = VNDetectBarcodesRequest()
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    let found = request.results ?? []
    var readings: [Reading] = []
    for item in found where item.symbology == .qr {
        guard let descriptor = item.barcodeDescriptor as? CIQRCodeDescriptor else { continue }
        if !readings.contains(where: { $0.descriptor.errorCorrectedPayload == descriptor.errorCorrectedPayload }) {
            readings.append(Reading(text: item.payloadStringValue, descriptor: descriptor))
        }
    }
    if readings.isEmpty {
        let others = Set(found.map { $0.symbology.rawValue.replacingOccurrences(of: "VNBarcodeSymbology", with: "") })
        let note = others.isEmpty ? "" : " (it holds another kind of code: \(others.sorted().joined(separator: ", ")))"
        throw Fail("no QR code found in \(what)\(note)")
    }
    if readings.count > 1 {
        throw Fail("\(readings.count) different QR codes found in \(what); crop the picture to the one you want")
    }
    return readings[0]
}

// MARK: the module grid

func isFinder(_ grid: [[Bool]], row: Int, column: Int) -> Bool {
    for r in 0..<7 {
        for c in 0..<7 {
            let ring = max(abs(r - 3), abs(c - 3))
            let dark = ring != 2
            if grid[row + r][column + c] != dark { return false }
        }
    }
    return true
}

/// The grid of a code that Core Image drew at one pixel per module.
func modules(of drawn: CIImage) throws -> [[Bool]] {
    let context = CIContext(options: [.useSoftwareRenderer: true])
    guard let image = context.createCGImage(drawn, from: drawn.extent.integral) else {
        throw Fail("Core Image could not draw the code")
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
    // A QR code has its three position squares at top left, top right and
    // bottom left. A flipped or rotated grid fails here.
    guard isFinder(grid, row: 0, column: 0), isFinder(grid, row: 0, column: n - 7),
          isFinder(grid, row: n - 7, column: 0), !isFinder(grid, row: n - 7, column: n - 7) else {
        throw Fail("the drawn code is not the right way up")
    }
    return grid
}

func grid(copying descriptor: CIQRCodeDescriptor) throws -> [[Bool]] {
    guard let filter = CIFilter(name: "CIBarcodeGenerator") else { throw Fail("CIBarcodeGenerator is missing") }
    filter.setValue(descriptor, forKey: "inputBarcodeDescriptor")
    guard let drawn = filter.outputImage else { throw Fail("Core Image could not copy the code") }
    return try modules(of: drawn)
}

func grid(encoding text: String) throws -> [[Bool]] {
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { throw Fail("CIQRCodeGenerator is missing") }
    filter.setValue(Data(text.utf8), forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    guard let drawn = filter.outputImage else { throw Fail("Core Image could not draw the code") }
    return try modules(of: drawn)
}

/// The grid as a picture, for reading it back.
func picture(of grid: [[Bool]], scale: Int, quiet: Int) throws -> CGImage {
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
        throw Fail("cannot build the check picture")
    }
    return image
}

// MARK: the watch screen

struct Layout {
    let pixelsPerModule: Int
    let origin: Int
    let side: Int
}

/// The same arithmetic as CardView.mc: the code sits in the square that fits
/// inside the round screen, with one module of margin on each side.
func layout(screen: Int, modules n: Int) -> Layout {
    let square = screen * 707 / 1000
    let px = max(1, square / (n + 2))
    let side = px * n
    return Layout(pixelsPerModule: px, origin: (screen - side) / 2, side: side)
}

/// What the watch will show, as a picture: white round screen, the code, the name above it.
func preview(of grid: [[Bool]], name: String, screen: Int) throws -> CGImage {
    let n = grid.count
    let place = layout(screen: screen, modules: n)
    guard let ctx = CGContext(data: nil, width: screen, height: screen, bitsPerComponent: 8, bytesPerRow: screen,
                              space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
        throw Fail("cannot build the preview")
    }
    let full = CGRect(x: 0, y: 0, width: screen, height: screen)
    ctx.setFillColor(gray: 0, alpha: 1)
    ctx.fill(full)
    ctx.setFillColor(gray: 1, alpha: 1)
    ctx.fillEllipse(in: full)
    ctx.setShouldAntialias(false)
    ctx.setFillColor(gray: 0, alpha: 1)
    let px = place.pixelsPerModule
    for r in 0..<n {
        for c in 0..<n where grid[r][c] {
            // Core Graphics counts rows from the bottom.
            let y = screen - (place.origin + (r + 1) * px)
            ctx.fill(CGRect(x: place.origin + c * px, y: y, width: px, height: px))
        }
    }
    ctx.setShouldAntialias(true)
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 18, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: name, attributes: attributes))
    let bounds = CTLineGetBoundsWithOptions(line, [])
    let textTop = place.origin - 2 * px - Int(bounds.height.rounded(.up))
    if textTop >= 8 {
        let baseline = CGFloat(screen - (place.origin - 2 * px)) - bounds.minY
        ctx.textPosition = CGPoint(x: (CGFloat(screen) - bounds.width) / 2 - bounds.minX, y: baseline)
        CTLineDraw(line, ctx)
    }
    guard let image = ctx.makeImage() else { throw Fail("cannot build the preview") }
    return image
}

// MARK: output

/// Each row as hex, most significant bit = leftmost module, padded on the
/// right to a whole number of hex digits (the watch's storage format).
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

/// A hash of the cards (FNV-1a over their sorted JSON), so that the watch can
/// tell whether the built-in list changed since it last imported it.
func stamp(of cards: [[String: Any]]) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: cards, options: [.sortedKeys])
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in data {
        h ^= UInt64(byte)
        h = h &* 0x0000_0100_0000_01b3
    }
    return String(h, radix: 16)
}

/// Can a bar code of this content be shown? The watch refuses a code whose
/// module width would be 0 px; this is the same estimate, made without the
/// encoder: symbols, 11 modules each, plus start, check and stop (13).
func barPixels(_ content: String, screen: Int) -> Int {
    let n = content.count
    let digits = content.allSatisfy { $0.isASCII && $0.isNumber }
    let symbols = digits ? (n % 2 == 0 ? n / 2 : 1 + (n - 1) / 2 + (n > 1 ? 1 : 0)) : n
    let modules = 11 * (symbols + 2) + 13
    let r = Double(screen) / 2
    let chord = 2 * (r * r - 36 * 36).squareRoot()
    return Int(((chord - 8) / Double(modules + 6)).rounded(.down))
}

func fileSlug(_ name: String) -> String {
    let kept = name.lowercased().map { ch -> Character in
        (ch.isLetter || ch.isNumber) ? ch : "-"
    }
    let slug = String(kept).split(separator: "-").joined(separator: "-")
    return slug.isEmpty ? "card" : slug
}

func levelName(_ level: CIQRCodeDescriptor.ErrorCorrectionLevel) -> String {
    switch level {
    case .levelL: return "L"
    case .levelM: return "M"
    case .levelQ: return "Q"
    case .levelH: return "H"
    @unknown default: return "?"
    }
}

/// Do two pictures hold the same code? Answers whether an app's code changes
/// over time (take one picture now and one later) without showing the code.
func compare(_ first: String, _ second: String) throws {
    let a = try readQR(try loadImage(first), from: first)
    let b = try readQR(try loadImage(second), from: second)
    if a.descriptor.errorCorrectedPayload == b.descriptor.errorCorrectedPayload {
        print("same code: the two pictures hold identical data")
    } else {
        print("different codes: the data in the two pictures is not the same")
        exit(2)
    }
}

func run() throws {
    let arguments = CommandLine.arguments
    if arguments.count == 4, arguments[1] == "same" {
        try compare(arguments[2], arguments[3])
        return
    }
    guard arguments.count >= 4 else {
        throw Fail("usage: cardtool <cards.json> <out cards resource .json> <preview folder> [screen px]\n"
            + "       cardtool same <picture 1> <picture 2>")
    }
    let listPath = arguments[1]
    let previews = arguments[3]
    let screen = arguments.count > 4 ? (Int(arguments[4]) ?? 280) : 280
    let listFolder = URL(fileURLWithPath: listPath).deletingLastPathComponent()
    let list = try JSONDecoder().decode(CardsIn.self, from: Data(contentsOf: URL(fileURLWithPath: listPath)))
    // An empty list is allowed: the release build ships no built-in cards.

    var resource: [[String: Any]] = []
    var names = Set<String>()
    for card in list.cards {
        let name = card.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw Fail("a card has no name") }
        guard names.insert(name).inserted else { throw Fail("two cards are named \(name)") }
        if let typed = card.number {
            // A bar code: the watch encodes it. Only the content is checked here.
            // Spaces in a number are how it is printed on a card, not part of
            // the code, and they would make the bars much thinner.
            let number = String(typed.filter { !$0.isWhitespace })
            guard !number.isEmpty, number.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value <= 126 }) else {
                throw Fail("\(name): a bar code holds ASCII 32 to 126 only, and not nothing")
            }
            let px = barPixels(number, screen: screen)
            guard px >= 1 else {
                throw Fail("\(name): the bar code is too long to show on a \(screen) px screen")
            }
            print("\(name): bar code (Code 128), \(number.count) characters, "
                + "\(px) px per module on a \(screen) px screen; the watch draws it")
            resource.append(["name": name, "kind": "bar", "t": number])
            continue
        }
        var matrix: [[Bool]]
        var source: Reading?
        if let imagePath = card.image {
            let path = imagePath.hasPrefix("/") ? imagePath : listFolder.appendingPathComponent(imagePath).path
            let reading = try readQR(try loadImage(path), from: "the picture for \(name)")
            matrix = try grid(copying: reading.descriptor)
            source = reading
        } else if let text = card.text {
            matrix = try grid(encoding: text)
        } else {
            throw Fail("\(name): give \"image\", \"text\" or \"number\"")
        }

        // Check 1: the grid, drawn large, reads back as the same code.
        let back = try readQR(try picture(of: matrix, scale: 8, quiet: 4), from: "the redrawn code for \(name)")
        let sameCode: Bool
        var exactCopy = "n/a"
        if let source = source {
            sameCode = back.descriptor.errorCorrectedPayload == source.descriptor.errorCorrectedPayload
            let same = sameCode
                && back.descriptor.symbolVersion == source.descriptor.symbolVersion
                && back.descriptor.maskPattern == source.descriptor.maskPattern
                && back.descriptor.errorCorrectionLevel == source.descriptor.errorCorrectionLevel
            exactCopy = same ? "yes" : "NO"
        } else {
            sameCode = back.text == card.text
        }
        guard sameCode else { throw Fail("\(name): the redrawn code does not read back as the original") }

        // Check 2: the picture of the watch screen, at the watch's own size, reads too.
        let shown = try preview(of: matrix, name: name, screen: screen)
        try FileManager.default.createDirectory(atPath: previews, withIntermediateDirectories: true)
        try savePNG(shown, "\(previews)/preview-\(fileSlug(name)).png")
        var readsAtSize = "NO"
        if let small = try? readQR(shown, from: "the preview"),
           small.descriptor.errorCorrectedPayload == back.descriptor.errorCorrectedPayload {
            readsAtSize = "yes"
        }

        let place = layout(screen: screen, modules: matrix.count)
        let length = (source?.text ?? card.text)?.count
        print("\(name): QR version \(back.descriptor.symbolVersion) (\(matrix.count) x \(matrix.count) modules), "
            + "error correction \(levelName(back.descriptor.errorCorrectionLevel)), "
            + (length.map { "\($0) characters, " } ?? "")
            + "\(place.pixelsPerModule) px per module on a \(screen) px screen")
        print("  exact copy of the picture's code: \(exactCopy); reads back: yes; reads at watch size: \(readsAtSize)")

        resource.append(["name": name, "kind": "qr", "n": matrix.count, "g": hexRows(of: matrix)])
    }

    let document: [String: Any] = ["stamp": try stamp(of: resource), "cards": resource]
    let json = try JSONSerialization.data(withJSONObject: document, options: [])
    try json.write(to: URL(fileURLWithPath: arguments[2]))
    print("\(resource.count) card\(resource.count == 1 ? "" : "s") written")
}

do {
    try run()
} catch {
    FileHandle.standardError.write("cardtool: \(error)\n".data(using: .utf8)!)
    exit(1)
}
