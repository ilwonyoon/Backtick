import SwiftUI

struct SettingsSection<Content: View, HeaderAccessory: View>: View {
    let title: String
    let footer: String?
    let titleFont: Font
    private let headerAccessory: HeaderAccessory
    private let content: Content

    init(
        title: String,
        titleFont: Font = SettingsTokens.Typography.sectionTitle,
        footer: String? = nil,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.titleFont = titleFont
        self.headerAccessory = headerAccessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsTokens.Layout.sectionHeaderSpacing) {
            HStack(alignment: .top, spacing: PrimitiveTokens.Space.md) {
                VStack(alignment: .leading, spacing: SettingsTokens.Layout.sectionTitleSpacing) {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(SettingsSemanticTokens.Text.primary)

                    if let footer, footer.isEmpty == false {
                        Text(footer)
                            .font(SettingsTokens.Typography.supporting)
                            .foregroundStyle(SettingsSemanticTokens.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                headerAccessory
            }

            SettingsGroupSurface {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension SettingsSection where HeaderAccessory == EmptyView {
    init(
        title: String,
        titleFont: Font = SettingsTokens.Typography.sectionTitle,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            titleFont: titleFont,
            footer: footer,
            headerAccessory: { EmptyView() },
            content: content
        )
    }
}

struct SettingsRows<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
    }
}

struct SettingsGroupSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.vertical, SettingsTokens.Layout.groupVerticalInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsSemanticTokens.Surface.formGroupFill)
        .clipShape(
            RoundedRectangle(
                cornerRadius: SettingsTokens.Layout.groupCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: SettingsTokens.Layout.groupCornerRadius,
                style: .continuous
            )
            .stroke(SettingsSemanticTokens.Border.formGroup, lineWidth: PrimitiveTokens.Stroke.subtle)
        }
    }
}
