import SwiftUI

/// Rounded linear progress with label, value, and optional detail line.
public struct MetricProgressBar: View {
    private let label: String
    private let value: Double
    private let target: Double
    private let unit: String
    private let tint: Color

    public init(label: String, value: Double, target: Double, unit: String, tint: Color) {
        self.label = label
        self.value = value
        self.target = target
        self.unit = unit
        self.tint = tint
    }

    private var fraction: Double {
        target > 0 ? min(value / target, 1) : 0
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            HStack {
                Text(label)
                    .font(AuraFont.body)
                    .foregroundStyle(AuraColor.textPrimary)
                Spacer()
                Text("\(Int(value)) / \(Int(target)) \(unit)")
                    .font(AuraFont.caption)
                    .foregroundStyle(AuraColor.textSecondary)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(geo.size.width * fraction, fraction > 0 ? 8 : 0))
                        .animation(AuraMotion.gentle, value: fraction)
                }
            }
            .frame(height: AuraRadius.bar)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value)) of \(Int(target)) \(unit)")
    }
}

/// Compact per-macro ring with title, used in the dashboard macro row.
public struct MacroRing: View {
    private let title: String
    private let value: Double
    private let target: Double
    private let tint: Color

    public init(title: String, value: Double, target: Double, tint: Color) {
        self.title = title
        self.value = value
        self.target = target
        self.tint = tint
    }

    public var body: some View {
        VStack(spacing: AuraSpacing.s2) {
            ScoreRing(
                score: target > 0 ? Int(min(value / target, 1) * 100) : 0,
                label: title,
                tint: tint,
                size: .mini
            )
            Text(title)
                .font(AuraFont.caption)
                .foregroundStyle(AuraColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Value with a directional delta, worded kindly ("↘ 0.4 kg this week").
public struct StatDelta: View {
    private let delta: Double
    private let unit: String
    private let period: String
    /// Whether a decreasing value is the desired direction (true for fat).
    private let downIsGood: Bool

    public init(delta: Double, unit: String, period: String = "this week", downIsGood: Bool = true) {
        self.delta = delta
        self.unit = unit
        self.period = period
        self.downIsGood = downIsGood
    }

    private var isGood: Bool { downIsGood ? delta <= 0 : delta >= 0 }

    public var body: some View {
        HStack(spacing: AuraSpacing.s1) {
            Image(systemName: delta == 0 ? "arrow.right" : (delta < 0 ? "arrow.down.right" : "arrow.up.right"))
                .font(.caption2.weight(.bold))
            Text(String(format: "%.1f %@ %@", abs(delta), unit, period))
                .font(AuraFont.caption)
        }
        .foregroundStyle(isGood ? AuraColor.accent : AuraColor.textSecondary)
    }
}

/// Cycle phase pill.
public struct PhaseChip: View {
    private let state: CycleState

    public init(state: CycleState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: AuraSpacing.s1) {
            Image(systemName: "moonphase.waxing.crescent")
                .font(.caption2)
            Text("\(state.phase.displayName) · Day \(state.dayInCycle)")
                .font(AuraFont.chip)
        }
        .padding(.horizontal, AuraSpacing.s3)
        .padding(.vertical, 6)
        .background(AuraColor.cycle.opacity(0.16), in: .capsule)
        .foregroundStyle(AuraColor.cycle)
        .accessibilityLabel("Cycle phase: \(state.phase.displayName), day \(state.dayInCycle)")
    }
}

/// Primary / secondary / quiet button styles.
public struct AuraButton: View {
    public enum Style { case primary, secondary, quiet }

    private let title: String
    private let style: Style
    private let action: () -> Void

    public init(_ title: String, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: style == .quiet ? nil : .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, AuraSpacing.s4)
        }
        .buttonStyle(.plain)
        .background(background, in: .rect(cornerRadius: AuraRadius.chip + 4, style: .continuous))
        .foregroundStyle(foreground)
    }

    private var background: Color {
        switch style {
        case .primary:   return AuraColor.accent
        case .secondary: return AuraColor.accentSoft
        case .quiet:     return .clear
        }
    }

    private var foreground: Color {
        switch style {
        case .primary:              return .white
        case .secondary, .quiet:    return AuraColor.accent
        }
    }
}

/// Kind empty state — an invitation, never an accusation.
public struct EmptyStateView: View {
    private let systemImage: String
    private let title: String
    private let message: String

    public init(systemImage: String, title: String, message: String) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: AuraSpacing.s3) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(AuraColor.accent.opacity(0.6))
            Text(title)
                .font(AuraFont.cardTitle)
                .foregroundStyle(AuraColor.textPrimary)
            Text(message)
                .font(AuraFont.body)
                .foregroundStyle(AuraColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AuraSpacing.s6)
    }
}
