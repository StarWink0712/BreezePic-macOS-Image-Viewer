import SwiftUI

struct WallpaperSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var editor: ImageEditorModel
    @ObservedObject var wallpaper: WallpaperManager

    @State private var displayID = "all"
    @State private var scaling: WallpaperManager.Scaling = .fill

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "desktopcomputer")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("设置桌面背景")
                        .font(.title2.weight(.semibold))
                    Text("使用当前完整分辨率的编辑结果，不会覆盖原图。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Form {
                Picker("显示器", selection: $displayID) {
                    Text("全部显示器").tag("all")
                    ForEach(wallpaper.displays) { display in
                        Text(display.name).tag(display.id)
                    }
                }

                Picker("显示方式", selection: $scaling) {
                    ForEach(WallpaperManager.Scaling.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
            }
            .formStyle(.grouped)

            if let message = wallpaper.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("设置背景") {
                    if wallpaper.apply(
                        editor: editor,
                        displayID: displayID,
                        scaling: scaling
                    ) {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!editor.canExport)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear {
            wallpaper.clearMessages()
        }
    }
}
