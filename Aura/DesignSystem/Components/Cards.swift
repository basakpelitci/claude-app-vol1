import SwiftUI

/// Standard flat card — the default container.
public struct SurfaceCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(AuraSpacing.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AuraColor.surface, in: .rect(cornerRadius: AuraRadius.card, style: .continuous))
    }
}

/// Glass card — reserved for hero moments (scores, celebration), not wallpaper.
public struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(AuraSpacing.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: AuraRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.card, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.06), radius: 24, y: 8)
    }
}

public struct CardTitle: View {
    private let text: String
    private let systemImage: String?
    private let tint: Color

    public init(_ text: String, systemImage: String? = nil, tint: Color = AuraColor.textSecondary) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: AuraSpacing.s2) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .font(.footnote.weight(.semibold))
            }
            Text(text)
                .font(AuraFont.caption.weight(.medium))
                .foregroundStyle(AuraColor.textSecondary)
                .textCase(.uppercase)
                .kerning(0.6)
        }
    }
}
