import Foundation
import ImageIO

struct ImageMetadata: Equatable {
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSize: Int64
    let modifiedAt: Date?

    static func load(from url: URL) -> ImageMetadata {
        let resourceValues = try? url.resourceValues(
            forKeys: [.fileSizeKey, .contentModificationDateKey]
        )

        var width = 0
        var height = 0
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(
               source,
               0,
               [kCGImageSourceShouldCache: false] as CFDictionary
           ) as? [CFString: Any] {
            width = number(properties[kCGImagePropertyPixelWidth])
            height = number(properties[kCGImagePropertyPixelHeight])

            let orientation = number(properties[kCGImagePropertyOrientation])
            if [5, 6, 7, 8].contains(orientation) {
                swap(&width, &height)
            }
        }

        return ImageMetadata(
            pixelWidth: width,
            pixelHeight: height,
            fileSize: Int64(resourceValues?.fileSize ?? 0),
            modifiedAt: resourceValues?.contentModificationDate
        )
    }

    private static func number(_ value: Any?) -> Int {
        (value as? NSNumber)?.intValue ?? 0
    }
}
