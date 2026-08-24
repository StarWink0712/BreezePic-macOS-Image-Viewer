# Contributing to BreezePic

感谢你愿意参与 BreezePic。Bug 修复、性能优化、界面改进、测试和文档更新都欢迎提交。

## 开始之前

1. Fork 仓库并从 `main` 创建分支。
2. 使用 Xcode 16 或更高版本打开 `BreezePic.xcodeproj`。
3. 在 Signing & Capabilities 中选择自己的 Team，并使用属于自己的 Bundle Identifier。
4. 保持最低系统版本为 macOS 14.0。

## 提交建议

- 一个 Pull Request 尽量只解决一类问题。
- 功能修改请说明使用场景、实现方式和验证结果。
- 界面修改请附上前后截图。
- 不要提交个人 Team ID、证书、Provisioning Profile、`xcuserdata` 或构建产物。
- 涉及系统照片时必须保持本地优先，不要在未明确讨论的情况下开启 iCloud 网络下载。
- 图片编辑默认不得覆盖原图。

## Build check

提交前请至少确认工程能够在 `My Mac` 目标上完成 Debug 构建。若修改了照片权限、沙盒权限或文件访问逻辑，请同时执行一次真实应用验证。

---

Thank you for contributing to BreezePic. Bug fixes, performance work, UI improvements, tests, and documentation updates are all welcome.

## Before you start

1. Fork the repository and create a branch from `main`.
2. Open `BreezePic.xcodeproj` with Xcode 16 or later.
3. Select your own Team and use a Bundle Identifier that you control.
4. Keep the deployment target at macOS 14.0.

## Pull request guidelines

- Keep each pull request focused on one type of change.
- Explain the use case, implementation, and verification for feature changes.
- Include before-and-after screenshots for UI changes.
- Do not commit personal Team IDs, certificates, provisioning profiles, `xcuserdata`, or build products.
- Keep Photos access local-first; do not enable iCloud downloads without prior discussion.
- Image editing must not overwrite the original by default.

Before opening a pull request, make sure the project completes a Debug build for the `My Mac` destination. Changes to Photos permissions, sandbox entitlements, or file access should also be tested in the real app.
