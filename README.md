<div align="center">
  <img src="BreezePic/Brand/BreezePicIconSource-1024.png" width="160" alt="BreezePic icon">
  <h1>BreezePic</h1>
  <p>A lightweight, local-first image viewer and photo editor for macOS.</p>
  <p>轻量、本地优先的 macOS 看图与图片编辑工具。</p>
</div>

> **Project status: Alpha · Source only**
> BreezePic currently does not provide an official DMG or other prebuilt binary. Build it locally with Xcode.

## 中文

BreezePic 是一个使用 SwiftUI、AppKit、Core Image 和 PhotoKit 开发的原生 macOS 看图工具。它可以浏览文件夹中的图片、读取本机系统照片、完成常用编辑，并将当前图片设置为桌面背景。

项目坚持本地优先：不上传图片，不主动下载 iCloud 原图，编辑过程也不会覆盖原文件。

### 功能

- 打开单张图片或扫描整个文件夹
- PNG、JPEG、HEIC 及 macOS 可识别的常见图片格式
- 上一张、下一张、方向键翻页和 Finder 拖放
- 适应窗口、1:1、放大和缩小
- 旋转、水平/垂直翻转和自由裁剪
- 亮度、对比度、饱和度和色温调节
- 最多 30 步撤销与重做
- 另存为 PNG、JPEG 或 HEIC，不覆盖原图
- 浏览最近 500 张本机系统照片
- 设置全部或指定显示器的桌面背景
- 使用安全书签恢复上次选择的图片文件夹
- 可从 Finder 的“打开方式”启动

### 隐私与权限

- BreezePic 不会在启动时请求照片权限。
- 只有主动点击“系统照片”并选择允许后，macOS 才会显示授权窗口。
- 授权结果由 macOS 保存，正常情况下不需要重复确认。
- PhotoKit 的缩略图和原图请求均设置为 `isNetworkAccessAllowed = false`。
- 仅存在于 iCloud 的照片不会被下载，需要先在系统“照片”应用中下载到本机。
- 从系统照片打开图片时，BreezePic 会在自己的 Application Support 目录保存本地副本，系统照片原件保持不变。

### 环境要求

- macOS 14.0 或更高版本
- Xcode 16 或更高版本
- Apple Account（免费 Personal Team 即可用于本机构建）

### 从源码运行

1. 克隆仓库：

   ```bash
   git clone https://github.com/StarWink0712/BreezePic-macOS-Image-Viewer.git
   cd BreezePic-macOS-Image-Viewer
   ```

2. 使用 Xcode 打开 `BreezePic.xcodeproj`。
3. 选择 `BreezePic` Target，进入 **Signing & Capabilities**。
4. 选择自己的 Team，并将 Bundle Identifier 改成属于自己的唯一值，例如 `com.yourname.BreezePic`。
5. 顶部选择 `BreezePic` Scheme 和 `My Mac`，按 `Command-R` 构建运行。

如果不熟悉 Xcode，也可以把仓库交给本地代码智能体，让它按照上面的步骤检查签名、构建并安装；照片授权仍需由你在 macOS 系统窗口中确认。

免费 Apple Account 的本地签名可能需要定期重新构建。若要面向所有 Mac 用户分发且尽量避免 Gatekeeper 提示，需要 Apple Developer Program、Developer ID 签名和 Apple 公证。

### 快捷键

| 操作 | 快捷键 |
| --- | --- |
| 打开图片 | `Command-O` |
| 打开文件夹 | `Command-Shift-O` |
| 上一张 / 下一张 | `←` / `→` |
| 撤销 | `Command-Z` |
| 重做 | `Command-Shift-Z` |
| 另存为 | `Command-Shift-S` |

### 主要模块

| 模块 | 职责 |
| --- | --- |
| `ImageLibrary` | 文件夹扫描、图片切换、安全书签与 Finder 文件访问 |
| `ImageEditorModel` | Core Image 编辑管线、撤销重做和完整分辨率导出 |
| `PhotosLibraryModel` | PhotoKit 授权、本机缩略图与照片导入 |
| `WallpaperManager` | 多显示器桌面背景设置 |
| `ContentView` | 主窗口、工具栏、状态栏和各模块协调 |

### 当前限制

- 文件夹扫描只读取当前目录，不递归子目录。
- 系统照片最多显示最近 500 张，暂不支持相册分类和搜索。
- 不下载 iCloud 原图。
- 裁剪目前只有自由比例。
- JPEG 导出质量固定为 92%。
- 超大图片的预览渲染仍可能短暂占用主线程。
- 当前不是 Developer ID 公证分发版本。

开发计划和已完成版本见 [ROADMAP.md](ROADMAP.md)。欢迎提交 Issue 和 Pull Request，参与前可阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

## English

BreezePic is a native macOS image viewer built with SwiftUI, AppKit, Core Image, and PhotoKit. It browses images in folders, opens locally available Photos library assets, provides common editing tools, and can set the current image as the desktop wallpaper.

The project is local-first: it does not upload images, does not download iCloud originals, and never overwrites the source image during editing.

### Features

- Open a single image or scan a folder
- PNG, JPEG, HEIC, and other formats supported by macOS
- Previous/next navigation, arrow-key browsing, and Finder drag and drop
- Fit to window, 1:1 view, zoom in, and zoom out
- Rotate, horizontal/vertical flip, and freeform crop
- Brightness, contrast, saturation, and temperature controls
- Up to 30 undo and redo steps
- Export as PNG, JPEG, or HEIC without overwriting the original
- Browse the 500 most recent locally available Photos assets
- Set the wallpaper for all displays or a selected display
- Restore the last selected folder with a security-scoped bookmark
- Open images through Finder's **Open With** menu

### Privacy and permissions

- BreezePic does not request Photos access at launch.
- macOS prompts only after you open **System Photos** and explicitly request access.
- macOS persists the authorization decision, so it normally does not ask again.
- Both thumbnail and full-image PhotoKit requests use `isNetworkAccessAllowed = false`.
- iCloud-only originals are not downloaded. Download them in Apple Photos first if needed.
- Opening a Photos asset creates a local copy inside BreezePic's Application Support directory; the Photos library original remains unchanged.

### Requirements

- macOS 14.0 or later
- Xcode 16 or later
- An Apple Account for local code signing; a free Personal Team is sufficient for local builds

### Build from source

1. Clone the repository:

   ```bash
   git clone https://github.com/StarWink0712/BreezePic-macOS-Image-Viewer.git
   cd BreezePic-macOS-Image-Viewer
   ```

2. Open `BreezePic.xcodeproj` in Xcode.
3. Select the `BreezePic` target and open **Signing & Capabilities**.
4. Select your Team and change the Bundle Identifier to a unique value you control, such as `com.yourname.BreezePic`.
5. Select the `BreezePic` scheme and `My Mac`, then press `Command-R`.

If you are unfamiliar with Xcode, a local coding agent can follow these steps to check signing, build, and install the project. You must still approve the macOS Photos permission prompt yourself.

Local signing with a free Apple Account may require periodic rebuilding. Public distribution without common Gatekeeper warnings requires an Apple Developer Program membership, Developer ID signing, and Apple notarization.

### Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Open image | `Command-O` |
| Open folder | `Command-Shift-O` |
| Previous / next | `←` / `→` |
| Undo | `Command-Z` |
| Redo | `Command-Shift-Z` |
| Save As | `Command-Shift-S` |

### Architecture

| Component | Responsibility |
| --- | --- |
| `ImageLibrary` | Folder scanning, navigation, security-scoped bookmarks, and Finder file access |
| `ImageEditorModel` | Core Image pipeline, history, and full-resolution export |
| `PhotosLibraryModel` | PhotoKit authorization, local thumbnails, and asset import |
| `WallpaperManager` | Multi-display desktop wallpaper configuration |
| `ContentView` | Main window, toolbar, status bar, and feature coordination |

### Known limitations

- Folder scanning is not recursive.
- System Photos currently shows up to 500 recent assets without album grouping or search.
- iCloud originals are never downloaded.
- Crop is currently freeform only.
- JPEG export quality is fixed at 92%.
- Very large images may briefly block the main thread while rendering a preview.
- The project is not distributed as a Developer ID-notarized binary.

See [ROADMAP.md](ROADMAP.md) for progress and planned work. Issues and pull requests are welcome; please read [CONTRIBUTING.md](CONTRIBUTING.md) before contributing.

## License

BreezePic is available under the [MIT License](LICENSE).
