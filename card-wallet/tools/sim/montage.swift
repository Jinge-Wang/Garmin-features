// montage <out.png> <columns> <cropX> <cropY> <cropW> <cropH> <in.png>...
// Crops the same region out of each picture and tiles them, numbered.
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers
let a = CommandLine.arguments
let cols = Int(a[2])!, cx = Int(a[3])!, cy = Int(a[4])!, cw = Int(a[5])!, ch = Int(a[6])!
let files = Array(a[7...])
let rows = (files.count + cols - 1) / cols
let pad = 6, label = 18
let W = cols * (cw + pad) + pad, H = rows * (ch + label + pad) + pad
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setFillColor(CGColor(gray: 0.85, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
for (i, f) in files.enumerated() {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: f) as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
    let scale = img.width / 430   // captures may be at 2x
    guard let crop = img.cropping(to: CGRect(x: cx * scale, y: cy * scale, width: cw * scale, height: ch * scale)) else { continue }
    let col = i % cols, row = i / cols
    let x = pad + col * (cw + pad)
    let top = pad + row * (ch + label + pad)
    ctx.draw(crop, in: CGRect(x: x, y: H - top - label - ch, width: cw, height: ch))
    let name = URL(fileURLWithPath: f).deletingPathExtension().lastPathComponent
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 13, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: name, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
    ctx.textPosition = CGPoint(x: x + 4, y: H - top - label + 4)
    CTLineDraw(line, ctx)
}
let out = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(out, ctx.makeImage()!, nil)
CGImageDestinationFinalize(out)
