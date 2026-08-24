import Foundation
import UniformTypeIdentifiers

enum SupportedImageFile {
    private static let fallbackExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif", "tif", "tiff",
        "bmp", "webp", "jp2", "avif"
    ]

    static func isSupported(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }

        if let values = try? url.resourceValues(
            forKeys: [.isRegularFileKey, .contentTypeKey]
        ),
           values.isRegularFile == true,
           values.contentType?.conforms(to: .image) == true {
            return true
        }

        return fallbackExtensions.contains(url.pathExtension.lowercased())
    }
}
