// code128_check: checks the Code 128 pattern table and encoder rules that ship
// in source/Code128.mc.
//
// The table is read out of the Monkey C file itself, so the table tested is the
// table on the watch. The encoder here follows the same three rules as the
// watch's (written separately, in Swift). Each random input is drawn as bars,
// read back with macOS Vision, and compared with the input.
//
//   code128_check <source/Code128.mc> [inputs] [seed]
//
// Prints counts and three sample vectors for the unit tests. The inputs are
// random dummy strings, not card content.

import CoreGraphics
import Foundation
import Vision

struct Fail: Error, CustomStringConvertible {
    let description: String
    init(_ text: String) { description = text }
}

// MARK: the table

func readTable(_ path: String) throws -> [String] {
    let source = try String(contentsOfFile: path, encoding: .utf8)
    guard let start = source.range(of: "const PATTERNS = \"") else { throw Fail("PATTERNS not found in \(path)") }
    let rest = source[start.upperBound...]
    guard let end = rest.firstIndex(of: "\"") else { throw Fail("PATTERNS is not closed") }
    return rest[..<end].split(separator: " ").map(String.init)
}

/// Structural checks on the table. Returns the number of problems.
func checkTable(_ table: [String]) -> Int {
    var problems = 0
    func bad(_ text: String) { print("  TABLE PROBLEM: \(text)"); problems += 1 }
    if table.count != 107 { bad("expected 107 entries (0..105 and stop), found \(table.count)") }
    for (value, pattern) in table.enumerated() {
        let digits = pattern.compactMap { $0.wholeNumberValue }
        if digits.count != pattern.count { bad("entry \(value) has a non-digit") }
        let sum = digits.reduce(0, +)
        if value < 106 {
            if digits.count != 6 { bad("entry \(value) has \(digits.count) widths, not 6") }
            if sum != 11 { bad("entry \(value) (\(pattern)) sums to \(sum), not 11") }
        } else {
            if digits.count != 7 { bad("stop has \(digits.count) widths, not 7") }
            if sum != 13 { bad("stop (\(pattern)) sums to \(sum), not 13") }
        }
        if digits.contains(where: { $0 < 1 || $0 > 4 }) { bad("entry \(value) has a width outside 1..4") }
    }
    if Set(table).count != table.count { bad("two entries are the same") }
    return problems
}

// MARK: the encoder (same three rules as the watch)

struct Encoded {
    let symbols: [Int]      // start, data..., check (without the stop)
    let dataValues: [Int]   // data symbols only (no start, no set switch, no check)
    let widths: String
}

func encode(_ text: String, table: [String]) -> Encoded? {
    let codes = text.unicodeScalars.map { Int($0.value) }
    guard !codes.isEmpty, codes.allSatisfy({ $0 >= 32 && $0 <= 126 }) else { return nil }
    let allDigits = codes.allSatisfy { $0 >= 48 && $0 <= 57 }
    var symbols: [Int] = []
    var data: [Int] = []
    if allDigits {
        var from = 0
        if codes.count % 2 == 0 {
            symbols.append(105)
        } else {
            symbols.append(104)
            symbols.append(codes[0] - 32); data.append(codes[0] - 32)
            from = 1
            if codes.count > 1 { symbols.append(99) }
        }
        var i = from
        while i + 1 < codes.count {
            let v = (codes[i] - 48) * 10 + (codes[i + 1] - 48)
            symbols.append(v); data.append(v)
            i += 2
        }
    } else {
        symbols.append(104)
        for c in codes { symbols.append(c - 32); data.append(c - 32) }
    }
    var sum = symbols[0]
    for i in 1..<max(symbols.count, 1) { sum += i * symbols[i] }
    let check = sum % 103
    symbols.append(check)
    let widths = symbols.map { table[$0] }.joined() + table[106]
    return Encoded(symbols: symbols, dataValues: data + [], widths: widths)
}

// MARK: drawing and reading

func picture(widths: String, scale: Int, quiet: Int, height: Int) -> CGImage? {
    let w = widths.compactMap { $0.wholeNumberValue }
    let modules = w.reduce(0, +)
    let width = (modules + 2 * quiet) * scale
    var buffer = [UInt8](repeating: 255, count: width * height)
    var x = quiet * scale
    for (index, run) in w.enumerated() {
        let dark = index % 2 == 0
        if dark {
            for row in 0..<height {
                for dx in 0..<(run * scale) { buffer[row * width + x + dx] = 0 }
            }
        }
        x += run * scale
    }
    guard let provider = CGDataProvider(data: Data(buffer) as CFData) else { return nil }
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                   space: CGColorSpaceCreateDeviceGray(),
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
}

func read(_ image: CGImage) -> [String] {
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.code128]
    try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    return (request.results ?? []).compactMap { $0.payloadStringValue }
}

// MARK: random inputs (fixed seed)

struct Random: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

func digitsString(_ length: Int, _ rng: inout Random) -> String {
    String((0..<length).map { _ in Character(String(Int.random(in: 0...9, using: &rng))) })
}

func run() throws {
    let args = CommandLine.arguments
    guard args.count >= 2 else { throw Fail("usage: code128_check <source/Code128.mc> [inputs] [seed]") }
    let total = args.count > 2 ? (Int(args[2]) ?? 3000) : 3000
    var rng = Random(state: UInt64(args.count > 3 ? (Int(args[3]) ?? 1) : 1))

    let table = try readTable(args[1])
    print("table: \(table.count) entries read from \(args[1])")
    let tableProblems = checkTable(table)
    print("structure: every pattern 11 modules, stop 13, all distinct: \(tableProblems == 0 ? "yes" : "NO (\(tableProblems) problems)")")

    // Rule 1: even digits (set C). Rule 2: odd digits (B then C). Rule 3: other text (set B).
    var inputs: [(String, String)] = []
    let third = total / 3
    for _ in 0..<third { inputs.append(("C", digitsString(2 * Int.random(in: 1...20, using: &rng), &rng))) }
    for _ in 0..<third { inputs.append(("B+C", digitsString(2 * Int.random(in: 0...19, using: &rng) + 1, &rng))) }
    let printable = (32...126).map { Character(UnicodeScalar($0)!) }
    while inputs.count < total {
        let length = Int.random(in: 1...22, using: &rng)
        var chars = (0..<length).map { _ in printable.randomElement(using: &rng)! }
        // Drawn as a picture the code is read back as text; leading or trailing
        // blanks are not reliably kept by every reader, so the first and last
        // character of the random text are not blanks (blanks inside are tested).
        let nonBlank = printable.filter { $0 != " " }
        chars[0] = nonBlank.randomElement(using: &rng)!
        chars[chars.count - 1] = nonBlank.randomElement(using: &rng)!
        let text = String(chars)
        if text.allSatisfy({ $0.isASCII && $0.isNumber }) { continue }   // would be rule 1 or 2
        inputs.append(("B", text))
    }

    var failures: [(String, String, String)] = []
    var usedData = Set<Int>()
    var usedCheck = Set<Int>()
    var perRule: [String: (Int, Int)] = [:]
    for (rule, text) in inputs {
        guard let encoded = encode(text, table: table) else { failures.append((rule, "<not encodable>", "")); continue }
        usedData.formUnion(encoded.dataValues)
        usedCheck.insert(encoded.symbols.last!)
        guard let image = picture(widths: encoded.widths, scale: 4, quiet: 10, height: 120) else {
            failures.append((rule, text, "no picture")); continue
        }
        let got = read(image)
        var entry = perRule[rule] ?? (0, 0)
        entry.0 += 1
        if got != [text] {
            entry.1 += 1
            failures.append((rule, text, got.joined(separator: "|")))
        }
        perRule[rule] = entry
    }

    print("random inputs: \(inputs.count)")
    for rule in ["C", "B+C", "B"] {
        let e = perRule[rule] ?? (0, 0)
        print("  rule \(rule): \(e.0) inputs, \(e.1) failures")
    }
    print("failures in total: \(failures.count)")
    for f in failures.prefix(10) { print("  FAIL rule \(f.0): input [\(f.1)] read [\(f.2)]") }

    let covered = usedData.union(usedCheck).filter { $0 <= 102 }
    let missing = (0...102).filter { !covered.contains($0) }
    print("values 0..102 exercised as data or check symbols: \(covered.count) of 103; missing: \(missing)")
    print("  as data: \(usedData.filter { $0 <= 102 }.count), as check: \(usedCheck.count)")
    print("  not covered as data (check only): \((0...102).filter { !usedData.contains($0) })")

    print("sample vectors (input -> widths):")
    for sample in ["123456", "12345", "Hi-5"] {
        if let e = encode(sample, table: table) { print("  \(sample) -> \(e.widths)") }
    }
    if tableProblems > 0 || !failures.isEmpty || !missing.isEmpty { exit(1) }
}

do {
    try run()
} catch {
    FileHandle.standardError.write("code128_check: \(error)\n".data(using: .utf8)!)
    exit(1)
}
