import AppKit
import Foundation

@MainActor
final class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()

    enum Scaling: String, CaseIterable, Identifiable {
        case fill
        case fit
        case stretch

        var id: String { rawValue }

        var title: String {
            switch self {
            case .fill: "填充屏幕"
            case .fit: "适合屏幕"
            case .stretch: "拉伸"
            }
        }
    }

    struct Display: Identifiable {
        let id: String
        let name: String
        let screen: NSScreen
    }

    @Published var errorMessage: String?
    @Published private(set) var lastAppliedMessage: String?

    var displays: [Display] {
        NSScreen.screens.enumerated().map { index, screen in
            let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber
            return Display(
                id: number?.stringValue ?? "screen-\(index)",
                name: screen.localizedName,
                screen: screen
            )
        }
    }

    func apply(
        editor: ImageEditorModel,
        displayID: String,
        scaling: Scaling
    ) -> Bool {
        do {
            let url = try editor.makeWallpaperFile()
            let targets: [Display]
            if displayID == "all" {
                targets = displays
            } else {
                targets = displays.filter { $0.id == displayID }
            }
            guard !targets.isEmpty else {
                throw WallpaperError.displayNotFound
            }

            let options = desktopOptions(for: scaling)
            for target in targets {
                try NSWorkspace.shared.setDesktopImageURL(
                    url,
                    for: target.screen,
                    options: options
                )
            }

            lastAppliedMessage = displayID == "all"
                ? "已设置全部显示器的桌面背景"
                : "已设置所选显示器的桌面背景"
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            lastAppliedMessage = nil
            return false
        }
    }

    func clearMessages() {
        errorMessage = nil
        lastAppliedMessage = nil
    }

    private func desktopOptions(
        for scaling: Scaling
    ) -> [NSWorkspace.DesktopImageOptionKey: Any] {
        let imageScaling: NSImageScaling
        let allowClipping: Bool
        switch scaling {
        case .fill:
            imageScaling = .scaleProportionallyUpOrDown
            allowClipping = true
        case .fit:
            imageScaling = .scaleProportionallyUpOrDown
            allowClipping = false
        case .stretch:
            imageScaling = .scaleAxesIndependently
            allowClipping = true
        }

        return [
            .imageScaling: imageScaling.rawValue,
            .allowClipping: allowClipping,
            .fillColor: NSColor.black
        ]
    }
}

private enum WallpaperError: LocalizedError {
    case displayNotFound

    var errorDescription: String? {
        "没有找到要设置的显示器。"
    }
}
