import SwiftUI

struct EditInspector: View {
    @ObservedObject var editor: ImageEditorModel
    let beginCrop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("编辑")
                    .font(.title3.weight(.semibold))
                Spacer()
                if editor.hasUnexportedChanges {
                    Text("未保存")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            transformSection
            Divider()
            adjustmentSection
            Spacer(minLength: 12)
            actionSection
        }
        .padding(16)
        .frame(width: 268)
        .background(.regularMaterial)
    }

    private var transformSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("变换")
                .font(.headline)

            HStack(spacing: 8) {
                inspectorButton("左转", systemImage: "rotate.left") {
                    editor.rotateCounterclockwise()
                }
                inspectorButton("右转", systemImage: "rotate.right") {
                    editor.rotateClockwise()
                }
                inspectorButton("裁剪", systemImage: "crop") {
                    beginCrop()
                }
            }

            HStack(spacing: 8) {
                inspectorButton("水平", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                    editor.flipHorizontal()
                }
                inspectorButton("垂直", systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down") {
                    editor.flipVertical()
                }
            }
        }
        .disabled(!editor.canEdit)
    }

    private var adjustmentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("调色")
                    .font(.headline)
                Spacer()
                Button("重置") {
                    editor.resetAdjustments()
                }
                .buttonStyle(.link)
                .disabled(!editor.canEdit)
            }

            adjustmentRow(
                title: "亮度",
                value: $editor.brightness,
                range: -1...1,
                displayValue: String(format: "%+.2f", editor.brightness)
            )
            adjustmentRow(
                title: "对比度",
                value: $editor.contrast,
                range: 0.25...2,
                displayValue: String(format: "%.2f", editor.contrast)
            )
            adjustmentRow(
                title: "饱和度",
                value: $editor.saturation,
                range: 0...2,
                displayValue: String(format: "%.2f", editor.saturation)
            )
            adjustmentRow(
                title: "色温",
                value: $editor.temperature,
                range: -1...1,
                displayValue: String(format: "%+.2f", editor.temperature)
            )
        }
        .disabled(!editor.canEdit)
    }

    private var actionSection: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    editor.undo()
                } label: {
                    Label("撤销", systemImage: "arrow.uturn.backward")
                }
                .disabled(!editor.canUndo)

                Button {
                    editor.redo()
                } label: {
                    Label("重做", systemImage: "arrow.uturn.forward")
                }
                .disabled(!editor.canRedo)
            }
            .frame(maxWidth: .infinity)

            Button("恢复原图") {
                editor.resetAll()
            }
            .frame(maxWidth: .infinity)
            .disabled(!editor.isDirty)

            Button {
                editor.chooseExportDestination()
            } label: {
                Label("另存为…", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!editor.canExport)
        }
    }

    private func adjustmentRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        displayValue: String
    ) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(displayValue)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: value,
                in: range,
                onEditingChanged: editor.adjustmentEditingChanged
            )
        }
    }

    private func inspectorButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.bordered)
    }
}
