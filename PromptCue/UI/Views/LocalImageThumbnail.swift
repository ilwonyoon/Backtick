import AppKit
import SwiftUI

struct LocalImageThumbnail: View {
    let url: URL
    let width: CGFloat?
    let height: CGFloat

    init(
        url: URL,
        width: CGFloat? = nil,
        height: CGFloat = PrimitiveTokens.Size.thumbnailHeight
    ) {
        self.url = url
        self.width = width
        self.height = height
    }

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.md, style: .continuous)
                    .fill(SemanticTokens.Surface.accentFill)
                    .overlay {
                        Image(systemName: "photo")
                            .font(PrimitiveTokens.Typography.iconLabel)
                            .foregroundStyle(SemanticTokens.Text.accent)
                    }
            }
        }
        .frame(width: width, height: height)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.md, style: .continuous)
                .stroke(SemanticTokens.Border.subtle)
        }
    }

    private func loadImage() -> NSImage? {
        ScreenshotDirectoryResolver.withAccessIfNeeded(to: url) { scopedURL in
            NSImage(contentsOf: scopedURL)
        }
    }
}
