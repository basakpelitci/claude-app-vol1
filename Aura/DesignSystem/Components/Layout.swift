import SwiftUI

/// Two-column staggered grid for the Dream Wardrobe (Pinterest-style).
/// Items are distributed to the currently shorter column by estimated
/// height, so the layout balances without measuring passes.
public struct MasonryGrid<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    private let estimatedHeight: (Item) -> CGFloat
    private let content: (Item) -> Content

    public init(
        items: [Item],
        estimatedHeight: @escaping (Item) -> CGFloat = { _ in 220 },
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.estimatedHeight = estimatedHeight
        self.content = content
    }

    private var columns: ([Item], [Item]) {
        var left: [Item] = [], right: [Item] = []
        var leftH: CGFloat = 0, rightH: CGFloat = 0
        for item in items {
            if leftH <= rightH {
                left.append(item)
                leftH += estimatedHeight(item)
            } else {
                right.append(item)
                rightH += estimatedHeight(item)
            }
        }
        return (left, right)
    }

    public var body: some View {
        let (left, right) = columns
        HStack(alignment: .top, spacing: AuraSpacing.s3) {
            LazyVStack(spacing: AuraSpacing.s3) {
                ForEach(left) { content($0) }
            }
            LazyVStack(spacing: AuraSpacing.s3) {
                ForEach(right) { content($0) }
            }
        }
    }
}

/// Full-screen milestone celebration. Confetti respects Reduce Motion.
public struct CelebrationOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let title: String
    private let message: String
    private let onContinue: () -> Void

    @State private var appeared = false

    public init(title: String, message: String, onContinue: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.onContinue = onContinue
    }

    public var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: AuraSpacing.s5) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(AuraColor.celebrate)
                    .scaleEffect(appeared ? 1 : 0.4)
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AuraColor.textPrimary)
                Text(message)
                    .font(AuraFont.body)
                    .foregroundStyle(AuraColor.textSecondary)
                    .multilineTextAlignment(.center)
                AuraButton("Continue", action: onContinue)
                    .padding(.top, AuraSpacing.s4)
            }
            .padding(AuraSpacing.s6)
            .background(AuraColor.surface, in: .rect(cornerRadius: AuraRadius.sheet, style: .continuous))
            .padding(AuraSpacing.s6)
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeIn(duration: 0.2) : AuraMotion.celebrate) {
                appeared = true
            }
        }
        .accessibilityAddTraits(.isModal)
    }
}

/// 30-day mini trend for card footers. Pure Path — no chart dependency —
/// so it stays cheap inside scrolling cards.
public struct TrendSparkline: View {
    private let values: [Double]
    private let tint: Color

    public init(values: [Double], tint: Color) {
        self.values = values
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { geo in
            if values.count >= 2,
               let minV = values.min(), let maxV = values.max() {
                let span = max(maxV - minV, 0.0001)
                let stepX = geo.size.width / CGFloat(values.count - 1)
                let points = values.enumerated().map { i, v in
                    CGPoint(
                        x: CGFloat(i) * stepX,
                        y: geo.size.height * (1 - CGFloat((v - minV) / span))
                    )
                }
                Path { p in
                    p.move(to: points[0])
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: 32)
        .accessibilityHidden(true)
    }
}
