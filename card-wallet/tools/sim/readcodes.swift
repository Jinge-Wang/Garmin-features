// readcodes <picture>...: prints every code Vision finds in each picture (used on dummy codes only).
import Foundation
import ImageIO
import Vision
for path in CommandLine.arguments.dropFirst() {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { print("\(path): cannot open"); continue }
    let req = VNDetectBarcodesRequest()
    try? VNImageRequestHandler(cgImage: img, options: [:]).perform([req])
    let found = (req.results ?? []).map { "\($0.symbology.rawValue.replacingOccurrences(of: "VNBarcodeSymbology", with: "")) = \($0.payloadStringValue ?? "?")" }
    print("\(URL(fileURLWithPath: path).lastPathComponent): \(found.isEmpty ? "nothing read" : found.joined(separator: "; "))")
}
