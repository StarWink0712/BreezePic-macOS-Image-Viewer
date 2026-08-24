import Photos
import SwiftUI

struct PhotosLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: ImageLibrary
    @ObservedObject var photos: PhotosLibraryModel

    private let columns = [
        GridItem(.adaptive(minimum: 128, maximum: 180), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 720, minHeight: 540)
        .onAppear {
            photos.refreshAuthorizationStatus()
        }
        .alert(
            "系统照片",
            isPresented: Binding(
                get: { photos.errorMessage != nil },
                set: { if !$0 { photos.clearError() } }
            )
        ) {
            Button("好") {
                photos.clearError()
            }
        } message: {
            Text(photos.errorMessage ?? "未知错误")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("系统照片")
                    .font(.title2.weight(.semibold))
                Text("只读取本机已有图片，不会从 iCloud 下载原图。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if photos.hasAccess {
                Button {
                    photos.loadAssets()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
            Button("关闭") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(18)
    }

    @ViewBuilder
    private var content: some View {
        switch photos.accessState {
        case .notDetermined:
            permissionView(
                icon: "photo.badge.plus",
                title: "允许 BreezePic 读取系统照片",
                description: "macOS 只会询问一次，并会为 BreezePic 保存你的选择。以后打开照片库时不会重复请求。"
            ) {
                Task {
                    await photos.requestAccessIfNeeded()
                }
            }
        case .denied:
            permissionView(
                icon: "photo.badge.exclamationmark",
                title: "照片访问已关闭",
                description: "BreezePic 不会再次弹出授权窗口。如需使用，请在“系统设置 → 隐私与安全性 → 照片”中开启。",
                buttonTitle: "打开系统设置"
            ) {
                photos.openPrivacySettings()
            }
        case .restricted:
            ContentUnavailableView {
                Label("照片访问受到限制", systemImage: "lock.trianglebadge.exclamationmark")
            } description: {
                Text("当前 Mac 的系统策略不允许 BreezePic 访问照片图库。")
            }
        case .authorized:
            photoGrid
        }
    }

    private var photoGrid: some View {
        Group {
            if photos.isLoading {
                ProgressView("正在读取本机照片…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if photos.assets.isEmpty {
                ContentUnavailableView {
                    Label("没有可显示的照片", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("照片图库为空，或其中的图片尚未下载到这台 Mac。")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(photos.assets, id: \.localIdentifier) { asset in
                            PhotoAssetCell(asset: asset, photos: photos) {
                                photos.openAsset(asset, in: library)
                                waitForImportAndDismiss()
                            }
                        }
                    }
                    .padding(16)
                }
                .overlay(alignment: .bottom) {
                    if photos.isImporting {
                        ProgressView("正在打开本机原图…")
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(.ultraThickMaterial, in: Capsule())
                            .padding(18)
                    }
                }
            }
        }
    }

    private func permissionView(
        icon: String,
        title: String,
        description: String,
        buttonTitle: String = "允许访问照片",
        action: @escaping () -> Void
    ) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(description)
                .frame(maxWidth: 460)
        } actions: {
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func waitForImportAndDismiss() {
        Task {
            while photos.isImporting {
                try? await Task.sleep(for: .milliseconds(100))
            }
            if photos.errorMessage == nil, library.currentURL != nil {
                dismiss()
            }
        }
    }
}

private struct PhotoAssetCell: View {
    let asset: PHAsset
    @ObservedObject var photos: PhotosLibraryModel
    let action: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isOnlyInCloud = false
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary)

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: isOnlyInCloud ? "icloud.slash" : "photo")
                            .font(.title)
                        if isOnlyInCloud {
                            Text("仅在 iCloud")
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(height: 128)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .bottomTrailing) {
                Text("\(asset.pixelWidth) × \(asset.pixelHeight)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.58), in: Capsule())
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .help(isOnlyInCloud ? "这张照片需要先在系统照片中下载" : "点击打开")
        .onAppear {
            guard requestID == nil else { return }
            requestID = photos.requestThumbnail(
                for: asset,
                targetSize: CGSize(width: 360, height: 360)
            ) { image, cloudOnly in
                thumbnail = image
                isOnlyInCloud = cloudOnly
            }
        }
        .onDisappear {
            if let requestID {
                photos.cancelThumbnailRequest(requestID)
            }
            requestID = nil
        }
    }
}
