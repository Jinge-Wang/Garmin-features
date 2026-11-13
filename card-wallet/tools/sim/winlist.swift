// winlist <pid>: lists the on-screen windows of one process (window number, layer, size).
import CoreGraphics
import Foundation
let pid = Int32(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == pid {
    let b = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    print("num=\(w[kCGWindowNumber as String] ?? 0) layer=\(w[kCGWindowLayer as String] ?? 0) w=\(b["Width"] ?? 0) h=\(b["Height"] ?? 0)")
}
