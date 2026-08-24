import SwiftUI

struct CropSelectionOverlay: View {
    @Binding var selection: CGRect
    @State private var dragStart: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            let selectedRect = CGRect(
                x: selection.minX * proxy.size.width,
                y: selection.minY * proxy.size.height,
                width: selection.width * proxy.size.width,
                height: selection.height * proxy.size.height
            )

            ZStack(alignment: .topLeading) {
                shadePath(size: proxy.size, hole: selectedRect)
                    .fill(
                        Color.black.opacity(0.52),
                        style: FillStyle(eoFill: true)
                    )

                Rectangle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: selectedRect.width, height: selectedRect.height)
                    .offset(x: selectedRect.minX, y: selectedRect.minY)
                    .shadow(color: .black.opacity(0.8), radius: 2)

                ForEach(Array(cornerPoints(of: selectedRect).enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(.white)
                        .stroke(.black.opacity(0.5), lineWidth: 1)
                        .frame(width: 10, height: 10)
                        .position(point)
                }

                Text("拖动以重新选择裁剪区域")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.65), in: Capsule())
                    .padding(12)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = clamped(value.location, to: proxy.size)
                        let start = dragStart ?? point
                        if dragStart == nil {
                            dragStart = point
                        }
                        let pixelRect = CGRect(
                            x: min(start.x, point.x),
                            y: min(start.y, point.y),
                            width: abs(point.x - start.x),
                            height: abs(point.y - start.y)
                        )
                        selection = CGRect(
                            x: pixelRect.minX / max(proxy.size.width, 1),
                            y: pixelRect.minY / max(proxy.size.height, 1),
                            width: pixelRect.width / max(proxy.size.width, 1),
                            height: pixelRect.height / max(proxy.size.height, 1)
                        )
                    }
                    .onEnded { _ in
                        dragStart = nil
                    }
            )
        }
    }

    private func shadePath(size: CGSize, hole: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(origin: .zero, size: size))
        path.addRect(hole)
        return path
    }

    private func cornerPoints(of rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]
    }

    private func clamped(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), size.width),
            y: min(max(point.y, 0), size.height)
        )
    }
}
