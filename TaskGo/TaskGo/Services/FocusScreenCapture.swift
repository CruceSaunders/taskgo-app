import AppKit
import CoreGraphics

class FocusScreenCapture {
    static func capture(quality: CGFloat = 0.5) -> Data? {
        guard let cgImage = CGDisplayCreateImage(CGMainDisplayID()) else { return nil }

        if cgImage.width <= 1 || cgImage.height <= 1 { return nil }

        let targetSize = NSSize(width: 1280, height: 720)
        let resized = NSImage(size: targetSize, flipped: false) { rect in
            let sourceImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            sourceImage.draw(in: rect)
            return true
        }

        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }

        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
}
