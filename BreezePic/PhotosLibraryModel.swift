import AppKit
import Foundation
import Photos
import UniformTypeIdentifiers

@MainActor
final class PhotosLibraryModel: ObservableObject {
    static let shared = PhotosLibraryModel()

    enum AccessState: Equatable {
        case notDetermined
        case authorized
        case denied
        case restricted
    }

    @Published private(set) var accessState: AccessState = .notDetermined
    @Published private(set) var assets: [PHAsset] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isImporting = false
    @Published var errorMessage: String?

    private let imageManager = PHCachingImageManager()
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        refreshAuthorizationStatus()
    }

    var hasAccess: Bool {
        accessState == .authorized
    }

    func refreshAuthorizationStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        accessState = map(status)
        if accessState == .authorized {
            loadAssets()
        } else {
            assets = []
        }
    }

    func requestAccessIfNeeded() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else {
            refreshAuthorizationStatus()
            return
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        accessState = map(status)
        if accessState == .authorized {
            loadAssets()
        }
    }

    func loadAssets() {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            assets = []
            return
        }

        isLoading = true
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        options.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )
        options.fetchLimit = 500

        let result = PHAsset.fetchAssets(with: options)
        assets = (0..<result.count).map { result.object(at: $0) }
        isLoading = false
        errorMessage = nil
    }

    @discardableResult
    func requestThumbnail(
        for asset: PHAsset,
        targetSize: CGSize,
        completion: @escaping (NSImage?, Bool) -> Void
    ) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false

        return imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
            Task { @MainActor in
                completion(image, isInCloud && image == nil)
            }
        }
    }

    func cancelThumbnailRequest(_ requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }

    func openAsset(_ asset: PHAsset, in library: ImageLibrary) {
        guard !isImporting else { return }
        isImporting = true
        errorMessage = nil

        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false

        imageManager.requestImageDataAndOrientation(
            for: asset,
            options: options
        ) { [weak self] data, dataUTI, _, info in
            Task { @MainActor in
                guard let self else { return }
                defer { self.isImporting = false }

                if let error = info?[PHImageErrorKey] as? Error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let data else {
                    let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                    self.errorMessage = isInCloud
                        ? "这张照片目前只存储在 iCloud 中。BreezePic 已关闭网络下载，请先在系统“照片”中将原图下载到本机。"
                        : "无法读取这张照片的本机原图。"
                    return
                }

                do {
                    let url = try self.writeImportedPhoto(
                        data,
                        dataUTI: dataUTI,
                        asset: asset
                    )
                    library.openImportedPhoto(url)
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func openPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func clearError() {
        errorMessage = nil
    }

    private func map(_ status: PHAuthorizationStatus) -> AccessState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .authorized, .limited:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        @unknown default:
            .denied
        }
    }

    private func writeImportedPhoto(
        _ data: Data,
        dataUTI: String?,
        asset: PHAsset
    ) throws -> URL {
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root
            .appendingPathComponent("BreezePic", isDirectory: true)
            .appendingPathComponent("ImportedPhotos", isDirectory: true)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let resource = PHAssetResource.assetResources(for: asset).first
        let originalExtension = resource
            .map { URL(fileURLWithPath: $0.originalFilename).pathExtension }
            .flatMap { $0.isEmpty ? nil : $0 }
        let typeExtension = dataUTI
            .flatMap(UTType.init)
            .flatMap(\.preferredFilenameExtension)
        let fileExtension = originalExtension ?? typeExtension ?? "jpg"
        let identifier = asset.localIdentifier
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" }
        let stableName = String(identifier.prefix(48))
        let url = directory
            .appendingPathComponent(stableName)
            .appendingPathExtension(fileExtension)

        try data.write(to: url, options: .atomic)
        return url
    }
}
