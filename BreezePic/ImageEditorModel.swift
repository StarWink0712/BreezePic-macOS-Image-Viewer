import AppKit
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class ImageEditorModel: ObservableObject {
    static let shared = ImageEditorModel()

    @Published private(set) var previewImage: NSImage?
    @Published private(set) var outputPixelSize: CGSize = .zero
    @Published private(set) var isDirty = false
    @Published private(set) var lastExportURL: URL?
    @Published var errorMessage: String?

    @Published var brightness: Double = 0 {
        didSet { adjustmentDidChange() }
    }
    @Published var contrast: Double = 1 {
        didSet { adjustmentDidChange() }
    }
    @Published var saturation: Double = 1 {
        didSet { adjustmentDidChange() }
    }
    @Published var temperature: Double = 0 {
        didSet { adjustmentDidChange() }
    }

    private struct Snapshot {
        let baseImage: CIImage?
        let brightness: Double
        let contrast: Double
        let saturation: Double
        let temperature: Double
        let isDirty: Bool
    }

    private let context = CIContext(options: [
        .cacheIntermediates: true,
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any
    ])
    private var sourceURL: URL?
    private var sourceImage: CIImage?
    private var baseImage: CIImage?
    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []
    private var applyingSnapshot = false
    private var continuousEditActive = false

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var canEdit: Bool { baseImage != nil }
    var canExport: Bool { baseImage != nil }
    var hasUnexportedChanges: Bool { isDirty && lastExportURL == nil }

    func load(_ url: URL) {
        do {
            let image = try loadCIImage(from: url)
            sourceURL = url
            sourceImage = normalized(image)
            baseImage = sourceImage
            undoStack.removeAll()
            redoStack.removeAll()
            continuousEditActive = false
            lastExportURL = nil
            errorMessage = nil
            applyAdjustmentValues(
                brightness: 0,
                contrast: 1,
                saturation: 1,
                temperature: 0
            )
            isDirty = false
            renderPreview()
        } catch {
            clear()
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        sourceURL = nil
        sourceImage = nil
        baseImage = nil
        previewImage = nil
        outputPixelSize = .zero
        undoStack.removeAll()
        redoStack.removeAll()
        continuousEditActive = false
        lastExportURL = nil
        isDirty = false
        applyAdjustmentValues(
            brightness: 0,
            contrast: 1,
            saturation: 1,
            temperature: 0
        )
    }

    func adjustmentEditingChanged(_ editing: Bool) {
        if editing, !continuousEditActive {
            pushUndoSnapshot()
            continuousEditActive = true
        } else if !editing {
            continuousEditActive = false
        }
    }

    func rotateClockwise() {
        transformBase(rotation: -.pi / 2)
    }

    func rotateCounterclockwise() {
        transformBase(rotation: .pi / 2)
    }

    func flipHorizontal() {
        guard let baseImage else { return }
        pushUndoSnapshot()
        self.baseImage = normalized(
            baseImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        )
        finishDiscreteEdit()
    }

    func flipVertical() {
        guard let baseImage else { return }
        pushUndoSnapshot()
        self.baseImage = normalized(
            baseImage.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
        )
        finishDiscreteEdit()
    }

    func applyCrop(normalizedRect: CGRect) {
        guard let baseImage else { return }
        let rect = normalizedRect.standardized.intersection(
            CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        guard rect.width >= 0.02, rect.height >= 0.02 else {
            errorMessage = "裁剪区域太小，请重新选择。"
            return
        }

        let extent = baseImage.extent
        let cropRect = CGRect(
            x: extent.minX + rect.minX * extent.width,
            y: extent.minY + (1 - rect.maxY) * extent.height,
            width: rect.width * extent.width,
            height: rect.height * extent.height
        ).integral.intersection(extent)
        guard cropRect.width >= 1, cropRect.height >= 1 else { return }

        pushUndoSnapshot()
        self.baseImage = normalized(baseImage.cropped(to: cropRect))
        finishDiscreteEdit()
    }

    func resetAdjustments() {
        guard brightness != 0 || contrast != 1 || saturation != 1 || temperature != 0 else {
            return
        }
        pushUndoSnapshot()
        applyAdjustmentValues(
            brightness: 0,
            contrast: 1,
            saturation: 1,
            temperature: 0
        )
        isDirty = true
        lastExportURL = nil
        renderPreview()
    }

    func resetAll() {
        guard let sourceImage, isDirty else { return }
        pushUndoSnapshot()
        baseImage = sourceImage
        applyAdjustmentValues(
            brightness: 0,
            contrast: 1,
            saturation: 1,
            temperature: 0
        )
        isDirty = false
        lastExportURL = nil
        renderPreview()
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot())
        apply(snapshot)
    }

    func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot())
        apply(snapshot)
    }

    func chooseExportDestination() {
        guard canExport else { return }

        let panel = NSSavePanel()
        panel.title = "导出编辑后的图片"
        panel.prompt = "导出"
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.canSelectHiddenExtension = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = defaultExportName

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try export(to: url)
            lastExportURL = url
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func makeWallpaperFile() throws -> URL {
        guard canExport else {
            throw EditorError.noImage
        }

        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root
            .appendingPathComponent("BreezePic", isDirectory: true)
            .appendingPathComponent("Wallpapers", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent("BreezePic-current-wallpaper.png")
        try export(to: url)
        return url
    }

    func clearError() {
        errorMessage = nil
    }

    private func transformBase(rotation: CGFloat) {
        guard let baseImage else { return }
        pushUndoSnapshot()
        self.baseImage = normalized(
            baseImage.transformed(by: CGAffineTransform(rotationAngle: rotation))
        )
        finishDiscreteEdit()
    }

    private func finishDiscreteEdit() {
        continuousEditActive = false
        isDirty = true
        lastExportURL = nil
        renderPreview()
    }

    private func adjustmentDidChange() {
        guard !applyingSnapshot, baseImage != nil else { return }
        isDirty = true
        lastExportURL = nil
        renderPreview()
    }

    private func pushUndoSnapshot() {
        undoStack.append(currentSnapshot())
        if undoStack.count > 30 {
            undoStack.removeFirst(undoStack.count - 30)
        }
        redoStack.removeAll()
    }

    private func currentSnapshot() -> Snapshot {
        Snapshot(
            baseImage: baseImage,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            temperature: temperature,
            isDirty: isDirty
        )
    }

    private func apply(_ snapshot: Snapshot) {
        baseImage = snapshot.baseImage
        applyAdjustmentValues(
            brightness: snapshot.brightness,
            contrast: snapshot.contrast,
            saturation: snapshot.saturation,
            temperature: snapshot.temperature
        )
        isDirty = snapshot.isDirty
        continuousEditActive = false
        lastExportURL = nil
        renderPreview()
    }

    private func applyAdjustmentValues(
        brightness: Double,
        contrast: Double,
        saturation: Double,
        temperature: Double
    ) {
        applyingSnapshot = true
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.temperature = temperature
        applyingSnapshot = false
    }

    private func adjustedImage() -> CIImage? {
        guard var image = baseImage else { return nil }

        image = image.applyingFilter(
            "CIColorControls",
            parameters: [
                kCIInputBrightnessKey: brightness,
                kCIInputContrastKey: contrast,
                kCIInputSaturationKey: saturation
            ]
        )

        if abs(temperature) > 0.001 {
            image = image.applyingFilter(
                "CITemperatureAndTint",
                parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(
                        x: 6500 + temperature * 2500,
                        y: 0
                    )
                ]
            )
        }
        return normalized(image)
    }

    private func renderPreview() {
        guard let image = adjustedImage() else {
            previewImage = nil
            outputPixelSize = .zero
            return
        }

        let fullExtent = image.extent.integral
        outputPixelSize = fullExtent.size

        let maxPreviewDimension: CGFloat = 4096
        let longestEdge = max(fullExtent.width, fullExtent.height)
        let previewCIImage: CIImage
        if longestEdge > maxPreviewDimension {
            let scale = maxPreviewDimension / longestEdge
            previewCIImage = image.transformed(
                by: CGAffineTransform(scaleX: scale, y: scale)
            )
        } else {
            previewCIImage = image
        }

        let extent = previewCIImage.extent.integral
        guard let cgImage = context.createCGImage(previewCIImage, from: extent) else {
            errorMessage = "无法渲染当前编辑效果。"
            return
        }
        previewImage = NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }

    private func export(to url: URL) throws {
        guard let image = adjustedImage() else {
            throw EditorError.noImage
        }
        let extent = image.extent.integral
        guard let cgImage = context.createCGImage(image, from: extent) else {
            throw EditorError.renderFailed
        }

        let type = exportType(for: url)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            type.identifier as CFString,
            1,
            nil
        ) else {
            throw EditorError.cannotCreateDestination
        }

        let properties: CFDictionary = [
            kCGImageDestinationLossyCompressionQuality: 0.92
        ] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw EditorError.exportFailed
        }
    }

    private func exportType(for url: URL) -> UTType {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": .jpeg
        case "heic", "heif": .heic
        default: .png
        }
    }

    private var defaultExportName: String {
        let original = sourceURL?.deletingPathExtension().lastPathComponent
            ?? "BreezePic"
        return "\(original)-edited.png"
    }

    private func loadCIImage(from url: URL) throws -> CIImage {
        if let image = CIImage(
            contentsOf: url,
            options: [.applyOrientationProperty: true]
        ) {
            return image
        }

        if let nsImage = NSImage(contentsOf: url),
           let data = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: data),
           let cgImage = bitmap.cgImage {
            return CIImage(cgImage: cgImage)
        }
        throw EditorError.cannotDecode(url.lastPathComponent)
    }

    private func normalized(_ image: CIImage) -> CIImage {
        let extent = image.extent
        guard extent.isFinite,
              !extent.isInfinite,
              extent.width > 0,
              extent.height > 0 else {
            return image
        }
        return image.transformed(
            by: CGAffineTransform(
                translationX: -extent.minX,
                y: -extent.minY
            )
        )
    }
}

private enum EditorError: LocalizedError {
    case noImage
    case cannotDecode(String)
    case renderFailed
    case cannotCreateDestination
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .noImage:
            "当前没有可以导出的图片。"
        case .cannotDecode(let name):
            "无法为“\(name)”建立编辑图像。"
        case .renderFailed:
            "无法渲染完整尺寸图片。"
        case .cannotCreateDestination:
            "无法创建目标图片文件。"
        case .exportFailed:
            "图片导出失败。"
        }
    }
}

private extension CGRect {
    var isFinite: Bool {
        [minX, minY, width, height].allSatisfy(\.isFinite)
    }
}
