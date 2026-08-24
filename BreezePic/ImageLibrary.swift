import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ImageLibrary: ObservableObject {
    static let shared = ImageLibrary()

    @Published private(set) var imageURLs: [URL] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var currentURL: URL?
    @Published private(set) var currentImage: NSImage?
    @Published private(set) var metadata: ImageMetadata?
    @Published private(set) var folderURL: URL?
    @Published private(set) var sourceDescription: String?
    @Published var errorMessage: String?

    private let fileManager: FileManager
    private let lastFolderStore: LastFolderStore
    private var restoredLastFolder = false
    private var scopedDirectory: URL?
    private var didStartDirectoryScope = false
    private var scopedFile: URL?
    private var didStartFileScope = false

    init(
        fileManager: FileManager = .default,
        lastFolderStore: LastFolderStore = LastFolderStore()
    ) {
        self.fileManager = fileManager
        self.lastFolderStore = lastFolderStore
    }

    deinit {
        if didStartDirectoryScope {
            scopedDirectory?.stopAccessingSecurityScopedResource()
        }
        if didStartFileScope {
            scopedFile?.stopAccessingSecurityScopedResource()
        }
    }

    var canShowPrevious: Bool {
        !imageURLs.isEmpty && currentIndex > 0
    }

    var canShowNext: Bool {
        !imageURLs.isEmpty && currentIndex + 1 < imageURLs.count
    }

    var positionText: String {
        guard !imageURLs.isEmpty else { return "未打开图片" }
        return "\(currentIndex + 1) / \(imageURLs.count)"
    }

    func restoreLastFolderIfNeeded() {
        guard !restoredLastFolder, currentURL == nil else { return }
        restoredLastFolder = true

        do {
            guard let bookmark = try lastFolderStore.resolve() else { return }
            try openFolder(bookmark.url, remember: bookmark.isStale)
        } catch {
            // A moved or deleted folder should not prevent the app from opening.
        }
    }

    func chooseImage() {
        let panel = NSOpenPanel()
        panel.title = "选择图片"
        panel.prompt = "打开"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openSingleImage(url)
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择图片文件夹"
        panel.prompt = "打开文件夹"
        panel.message = "BreezePic 会记住这个文件夹，方便下次继续浏览。"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try openFolder(url, remember: true)
        } catch {
            report(error)
        }
    }

    func openExternalURLs(_ urls: [URL]) {
        guard let first = urls.first else { return }
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: first.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            do {
                try openFolder(first, remember: true)
            } catch {
                report(error)
            }
        } else {
            openSingleImage(first)
        }
    }

    func openDroppedURLs(_ urls: [URL]) -> Bool {
        guard let first = urls.first else { return false }
        openExternalURLs([first])
        return currentURL != nil || folderURL != nil
    }

    func openImportedPhoto(_ url: URL) {
        openSingleImage(url, sourceDescription: "系统照片（本机）")
    }

    func showPrevious() {
        guard canShowPrevious else { return }
        currentIndex -= 1
        loadCurrentImage()
    }

    func showNext() {
        guard canShowNext else { return }
        currentIndex += 1
        loadCurrentImage()
    }

    func revealCurrentImage() {
        guard let currentURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([currentURL])
    }

    func clearError() {
        errorMessage = nil
    }

    private func openFolder(
        _ directory: URL,
        remember: Bool,
        selecting preferredImage: URL? = nil
    ) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(
            atPath: directory.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            throw ViewerError.notDirectory
        }

        beginDirectoryAccess(directory)
        releaseFileAccess()

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .contentTypeKey,
            .isHiddenKey
        ]
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        .filter(SupportedImageFile.isSupported)
        .sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent)
                == .orderedAscending
        }

        folderURL = directory.standardizedFileURL
        sourceDescription = nil
        imageURLs = urls
        if let preferredImage,
           let index = urls.firstIndex(of: preferredImage.standardizedFileURL) {
            currentIndex = index
        } else {
            currentIndex = 0
        }

        if remember {
            try lastFolderStore.save(directory)
        }

        guard !urls.isEmpty else {
            currentURL = nil
            currentImage = nil
            metadata = nil
            throw ViewerError.noImages
        }
        loadCurrentImage()
    }

    private func openSingleImage(
        _ url: URL,
        sourceDescription: String? = nil
    ) {
        guard SupportedImageFile.isSupported(url) else {
            errorMessage = ViewerError.unsupportedImage.localizedDescription
            return
        }

        let standardized = url.standardizedFileURL
        if let folderURL,
           standardized.deletingLastPathComponent() == folderURL,
           let index = imageURLs.firstIndex(of: standardized) {
            currentIndex = index
            loadCurrentImage()
            return
        }

        releaseDirectoryAccess()
        beginFileAccess(standardized)
        folderURL = nil
        self.sourceDescription = sourceDescription
        imageURLs = [standardized]
        currentIndex = 0
        loadCurrentImage()
    }

    private func loadCurrentImage() {
        guard imageURLs.indices.contains(currentIndex) else {
            currentURL = nil
            currentImage = nil
            metadata = nil
            return
        }

        let url = imageURLs[currentIndex]
        guard let image = NSImage(contentsOf: url) else {
            currentURL = nil
            currentImage = nil
            metadata = nil
            errorMessage = ViewerError.cannotDecode(url.lastPathComponent)
                .localizedDescription
            return
        }

        currentURL = url
        currentImage = image
        metadata = ImageMetadata.load(from: url)
        errorMessage = nil
    }

    private func beginDirectoryAccess(_ url: URL) {
        let standardized = url.standardizedFileURL
        guard scopedDirectory != standardized else { return }
        releaseDirectoryAccess()
        scopedDirectory = standardized
        didStartDirectoryScope = standardized.startAccessingSecurityScopedResource()
    }

    private func releaseDirectoryAccess() {
        if didStartDirectoryScope {
            scopedDirectory?.stopAccessingSecurityScopedResource()
        }
        scopedDirectory = nil
        didStartDirectoryScope = false
    }

    private func beginFileAccess(_ url: URL) {
        releaseFileAccess()
        scopedFile = url
        didStartFileScope = url.startAccessingSecurityScopedResource()
    }

    private func releaseFileAccess() {
        if didStartFileScope {
            scopedFile?.stopAccessingSecurityScopedResource()
        }
        scopedFile = nil
        didStartFileScope = false
    }

    private func report(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}

private enum ViewerError: LocalizedError {
    case notDirectory
    case noImages
    case unsupportedImage
    case cannotDecode(String)

    var errorDescription: String? {
        switch self {
        case .notDirectory:
            "所选位置不是文件夹。"
        case .noImages:
            "这个文件夹中没有找到支持的图片。"
        case .unsupportedImage:
            "BreezePic 暂时无法识别这个图片格式。"
        case .cannotDecode(let name):
            "无法读取图片“\(name)”。文件可能已经损坏或格式不受系统支持。"
        }
    }
}
