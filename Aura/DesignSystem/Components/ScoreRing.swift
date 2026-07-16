import SwiftUI

/// Animated circular gauge for Momentum / Health Score, in hero and mini
/// sizes. Fully accessible: the ring reads as a sentence, not a shape.
public struct ScoreRing: View {
    public enum Size {
        case hero, mini

        var diameter: CGFloat { self == .hero ? 132 : 56 }
        var stroke: CGFloat { self == .hero ? 13 : 6 }
        var font: Font { self == .hero ? AuraFont.heroNumber : .system(size: 18, weight: .bold, design: .rounded) }
    }

    private let score: Int
    private let label: String
    private let tint: Color
    private let size: Size

    @State private var animatedFraction: Double = 0

    public init(score: Int, label: String, tint: Color, size: Size = .hero) {
        self.score = score
        self.label = label
        self.tint = tint
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: size.stroke)
            Circle()
                .trim(from: 0, to: animatedFraction)
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.65), tint],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * animatedFraction)
                    ),
                    style: StrokeStyle(lineWidth: size.stroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(size.font)
                .foregroundStyle(AuraColor.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(width: size.diameter, height: size.diameter)
        .onAppear { withAnimation(AuraMotion.score) { animatedFraction = Double(score) / 100 } }
        .onChange(of: score) { _, newValue in
            withAnimation(AuraMotion.score) { animatedFraction = Double(newValue) / 100 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(score) out of 100")
    }
}
