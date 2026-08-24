import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: ImageLibrary
    @EnvironmentObject private var editor: ImageEditorModel
    @EnvironmentObject private var photos: PhotosLibraryModel
    @EnvironmentObject private var wallpaper: WallpaperManager
    @State private var fitToWindow = true
    @State private var zoom: CGFloat = 1
    @State private var isDropTargeted = false
    @State private var showInspector = true
    @State private var cropMode = false
    @State private var showPhotosLibrary = false
    @State private var showWallpaperSheet = false
    @State private var cropSelection = CGRect(
        x: 0.1,
        y: 0.1,
        width: 0.8,
        height: 0.8
    )

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                viewer

                if showInspector {
                    Divider()
                    EditInspector(editor: editor, beginCrop: beginCrop)
                }
            }
            statusBar
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    library.chooseImage()
                } label: {
                    Label("打开图片", systemImage: "photo")
                }

                Button {
                    library.chooseFolder()
                } label: {
                    Label("打开文件夹", systemImage: "folder")
                }

                Button {
                    showPhotosLibrary = true
                } label: {
                    Label("系统照片", systemImage: "photo.stack")
                }
            }

            ToolbarItemGroup(placement: .principal) {
                Button {
                    library.showPrevious()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .help("上一张（←）")
                .disabled(!library.canShowPrevious || cropMode)

                Text(library.positionText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 72)

                Button {
                    library.showNext()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .help("下一张（→）")
                .disabled(!library.canShowNext || cropMode)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    fitToWindow = true
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                }
                .accessibilityLabel("适应窗口")
                .help("适应窗口")
                .disabled(editor.previewImage == nil || cropMode)

                Button {
                    fitToWindow = false
                    zoom = 1
                } label: {
                    Text("1:1")
                        .font(.system(.body, design: .rounded, weight: .medium))
                }
                .help("实际大小")
                .disabled(editor.previewImage == nil || cropMode)

                Button {
                    fitToWindow = false
                    zoom = max(zoom / 1.25, 0.1)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("缩小")
                .disabled(editor.previewImage == nil || cropMode)

                Button {
                    fitToWindow = false
                    zoom = min(zoom * 1.25, 8)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("放大")
                .disabled(editor.previewImage == nil || cropMode)

                Button {
                    showInspector.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .accessibilityLabel(showInspector ? "隐藏编辑面板" : "显示编辑面板")
                .help(showInspector ? "隐藏编辑面板" : "显示编辑面板")

                Button {
                    showWallpaperSheet = true
                } label: {
                    Image(systemName: "desktopcomputer")
                }
                .accessibilityLabel("设置桌面背景")
                .help("设置桌面背景")
                .disabled(!editor.canExport || cropMode)
            }
        }
        .navigationTitle(windowTitle)
        .task {
            library.restoreLastFolderIfNeeded()
            if let url = library.currentURL, editor.previewImage == nil {
                editor.load(url)
            }
        }
        .onChange(of: library.currentURL) {
            fitToWindow = true
            zoom = 1
            cropMode = false
            if let url = library.currentURL {
                editor.load(url)
            } else {
                editor.clear()
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !cropMode else { return false }
            return library.openDroppedURLs(urls)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.tint, style: StrokeStyle(lineWidth: 4, dash: [10]))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .alert(
            "BreezePic",
            isPresented: Binding(
                get: { presentedError != nil },
                set: { if !$0 { clearErrors() } }
            )
        ) {
            Button("好") {
                clearErrors()
            }
        } message: {
            Text(presentedError ?? "未知错误")
        }
        .sheet(isPresented: $showPhotosLibrary) {
            PhotosLibraryView(photos: photos)
                .environmentObject(library)
        }
        .sheet(isPresented: $showWallpaperSheet) {
            WallpaperSheet(editor: editor, wallpaper: wallpaper)
        }
    }

    @ViewBuilder
    private var viewer: some View {
        if let image = editor.previewImage {
            ZStack(alignment: .bottom) {
                ImageCanvas(
                    image: image,
                    pixelSize: editor.outputPixelSize,
                    fitToWindow: fitToWindow,
                    zoom: zoom,
                    cropMode: cropMode,
                    cropSelection: $cropSelection
                )

                if cropMode {
                    cropControls
                        .padding(.bottom, 18)
                }
            }
            .contextMenu {
                Button {
                    showWallpaperSheet = true
                } label: {
                    Label("设置为桌面背景…", systemImage: "desktopcomputer")
                }
                .disabled(cropMode)
            }
        } else {
            ContentUnavailableView {
                Label("打开一张图片", systemImage: "photo.on.rectangle.angled")
            } description: {
                Text("选择图片或文件夹，也可以把图片拖到这里。")
            } actions: {
                HStack {
                    Button("打开图片…") {
                        library.chooseImage()
                    }
                    Button("打开文件夹…") {
                        library.chooseFolder()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var cropControls: some View {
        HStack(spacing: 10) {
            Button("取消") {
                cropMode = false
            }
            .keyboardShortcut(.cancelAction)

            Button("应用裁剪") {
                editor.applyCrop(normalizedRect: cropSelection)
                if editor.errorMessage == nil {
                    cropMode = false
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(10)
        .background(.ultraThickMaterial, in: Capsule())
        .shadow(radius: 10)
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            if let sourceDescription = library.sourceDescription {
                Label(sourceDescription, systemImage: "photo.stack")
                    .lineLimit(1)
            } else if let folder = library.folderURL {
                Label(folder.lastPathComponent, systemImage: "folder")
                    .lineLimit(1)
                    .help(folder.path)
            } else if let url = library.currentURL {
                Label(url.deletingLastPathComponent().lastPathComponent, systemImage: "doc")
                    .lineLimit(1)
                    .help("通过 Finder 打开单张图片；选择文件夹后可以连续翻页。")
            }

            if let exportURL = editor.lastExportURL {
                Label("已导出 \(exportURL.lastPathComponent)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .lineLimit(1)
            } else if editor.hasUnexportedChanges {
                Label("已编辑，尚未导出", systemImage: "circle.fill")
                    .foregroundStyle(.orange)
            }

            if let message = wallpaper.lastAppliedMessage {
                Label(message, systemImage: "desktopcomputer")
                    .foregroundStyle(.green)
                    .lineLimit(1)
            }

            Spacer()

            let size = editor.outputPixelSize
            if size.width > 0, size.height > 0 {
                Text("\(Int(size.width)) × \(Int(size.height))")
            }
            if let metadata = library.metadata, metadata.fileSize > 0 {
                Text(ByteCountFormatter.string(
                    fromByteCount: metadata.fileSize,
                    countStyle: .file
                ))
            }

            if library.currentURL != nil {
                Text(cropMode ? "裁剪模式" : (fitToWindow ? "适应窗口" : "\(Int(zoom * 100))%"))
                    .monospacedDigit()
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var windowTitle: String {
        let name = library.currentURL?.lastPathComponent ?? "BreezePic"
        return editor.hasUnexportedChanges ? "\(name) — 已编辑" : name
    }

    private var presentedError: String? {
        editor.errorMessage
            ?? library.errorMessage
    }

    private func clearErrors() {
        editor.clearError()
        library.clearError()
        photos.clearError()
        wallpaper.clearMessages()
    }

    private func beginCrop() {
        guard editor.canEdit else { return }
        cropSelection = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        fitToWindow = true
        cropMode = true
    }
}
