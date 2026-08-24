import AppKit
import SwiftUI

struct ImageCanvas: View {
    let image: NSImage
    let pixelSize: CGSize?
    let fitToWindow: Bool
    let zoom: CGFloat
    let cropMode: Bool
    @Binding var cropSelection: CGRect

    var body: some View {
        GeometryReader { proxy in
            let naturalSize = resolvedNaturalSize
            let availableWidth = max(proxy.size.width - 48, 1)
            let availableHeight = max(proxy.size.height - 48, 1)
            let fitScale = min(
                availableWidth / max(naturalSize.width, 1),
                availableHeight / max(naturalSize.height, 1)
            )
            let scale = fitToWindow ? max(fitScale, 0.01) : zoom
            let displaySize = CGSize(
                width: naturalSize.width * scale,
                height: naturalSize.height * scale
            )

            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    Color.clear
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: displaySize.width,
                            height: displaySize.height
                        )
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
                        .overlay {
                            if cropMode {
                                CropSelectionOverlay(selection: $cropSelection)
                            }
                        }
                }
                .frame(
                    width: max(proxy.size.width, displaySize.width + 48),
                    height: max(proxy.size.height, displaySize.height + 48)
                )
            }
            .scrollIndicators(.automatic)
            .scrollDisabled(cropMode)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.55))
    }

    private var resolvedNaturalSize: CGSize {
        if let pixelSize,
           pixelSize.width > 0,
           pixelSize.height > 0 {
            return pixelSize
        }
        return image.size
    }
}
