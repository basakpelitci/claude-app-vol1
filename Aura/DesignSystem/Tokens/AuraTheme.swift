import SwiftUI

// Design tokens — the only place raw values live. Views reference tokens,
// never literals. See docs/design/design-system.md for the rationale.

// MARK: - Color

public enum AuraColor {
    // Adaptive tokens (light / dark tuned separately — dark is not inversion).
    public static let background = adaptive(light: 0xF7F6F3, dark: 0x0D0D10)
    public static let surface = adaptive(light: 0xFFFFFF, dark: 0x17171C)
    public static let textPrimary = adaptive(light: 0x1A1A1E, dark: 0xF4F4F6)
    public static let textSecondary = adaptive(light: 0x6E6E76, dark: 0x9B9BA4)

    /// Brand sage — momentum, primary actions.
    public static let accent = adaptive(light: 0x5E8B7E, dark: 0x7FB0A1)
    public static let health = adaptive(light: 0x4A7FA5, dark: 0x6FA5CC)
    public static let protein = adaptive(light: 0x8A6FB8, dark: 0xA98FD6)
    public static let water = adaptive(light: 0x4E9FBF, dark: 0x6FC0DE)
    public static let energy = adaptive(light: 0xC99A5B, dark: 0xDDB27A)
    public static let cycle = adaptive(light: 0xB87A8F, dark: 0xD699AE)
    public static let celebrate = adaptive(light: 0xD9A441, dark: 0xE8BC63)

    public static var accentSoft: Color { accent.opacity(0.16) }

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
        #else
        return Color(hex: light)
        #endif
    }
}

public extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Typography

public enum AuraFont {
    /// Hero score numbers (Momentum / Health Score).
    public static let heroNumber = Font.system(size: 56, weight: .bold, design: .rounded)
    public static let metricValue = Font.system(size: 28, weight: .semibold, design: .rounded)
    public static let cardTitle = Font.title3.weight(.semibold)
    public static let body = Font.body
    public static let caption = Font.footnote
    public static let chip = Font.caption.weight(.medium)
}

// MARK: - Spacing & radius (4-pt grid)

public enum AuraSpacing {
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 8
    public static let s3: CGFloat = 12
    public static let s4: CGFloat = 16
    public static let s5: CGFloat = 24
    public static let s6: CGFloat = 32
    public static let s7: CGFloat = 48
    /// Horizontal screen margin.
    public static let screen: CGFloat = 20
}

public enum AuraRadius {
    public static let card: CGFloat = 24
    public static let chip: CGFloat = 12
    public static let sheet: CGFloat = 32
    public static let bar: CGFloat = 8
}

// MARK: - Motion

public enum AuraMotion {
    /// Card appearance and small value changes.
    public static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.85)
    /// Ring fills and count-up numbers.
    public static let score = Animation.spring(response: 0.9, dampingFraction: 0.8)
    /// Milestone celebrations.
    public static let celebrate = Animation.spring(response: 0.55, dampingFraction: 0.6)
}
