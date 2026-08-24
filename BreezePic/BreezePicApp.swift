import SwiftUI

@main
struct BreezePicApp: App {
    @NSApplicationDelegateAdaptor(BreezePicAppDelegate.self) private var appDelegate
    @StateObject private var library = ImageLibrary.shared
    @StateObject private var editor = ImageEditorModel.shared
    @StateObject private var photos = PhotosLibraryModel.shared
    @StateObject private var wallpaper = WallpaperManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(editor)
                .environmentObject(photos)
                .environmentObject(wallpaper)
                .frame(minWidth: 900, minHeight: 580)
        }
        .windowStyle(.titleBar)
        .commands {
            ViewerCommands(library: library, editor: editor)
        }
    }
}

private struct ViewerCommands: Commands {
    @ObservedObject var library: ImageLibrary
    @ObservedObject var editor: ImageEditorModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("打开图片…") {
                library.chooseImage()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("打开文件夹…") {
                library.chooseFolder()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .saveItem) {
            Button("另存为…") {
                editor.chooseExportDestination()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(!editor.canExport)
        }

        CommandGroup(replacing: .undoRedo) {
            Button("撤销") {
                editor.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!editor.canUndo)

            Button("重做") {
                editor.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!editor.canRedo)
        }

        CommandMenu("浏览") {
            Button("上一张") {
                library.showPrevious()
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(!library.canShowPrevious)

            Button("下一张") {
                library.showNext()
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(!library.canShowNext)

            Divider()

            Button("在 Finder 中显示") {
                library.revealCurrentImage()
            }
            .disabled(library.currentURL == nil)
        }

        CommandMenu("图像") {
            Button("向左旋转") {
                editor.rotateCounterclockwise()
            }
            .disabled(!editor.canEdit)

            Button("向右旋转") {
                editor.rotateClockwise()
            }
            .disabled(!editor.canEdit)

            Divider()

            Button("水平翻转") {
                editor.flipHorizontal()
            }
            .disabled(!editor.canEdit)

            Button("垂直翻转") {
                editor.flipVertical()
            }
            .disabled(!editor.canEdit)

            Divider()

            Button("恢复原图") {
                editor.resetAll()
            }
            .disabled(!editor.isDirty)
        }
    }
}
