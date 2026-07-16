import SwiftUI
import UIKit

/// The daily command center: scores first, emotion above the fold,
/// one question answered per card.
public struct TodayView: View {
    @State private var viewModel: TodayViewModel

    public init(deps: AppDependencies) {
        _viewModel = State(initialValue: TodayViewModel(deps: deps))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    header
                    scoreRow
                    if let snapshot = viewModel.snapshot {
                        caloriesCard(snapshot)
                        macroRow(snapshot)
                        waterAndNEATRow(snapshot)
                        workoutCard
                        biaCard
                    }
                    dreamOutfitCard
                    motivationCard
                }
                .padding(.horizontal, AuraSpacing.screen)
                .padding(.bottom, AuraSpacing.s6)
            }
            .background(AuraColor.background)
            .navigationTitle("Today")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: AuraSpacing.s1) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(AuraFont.caption)
                    .foregroundStyle(AuraColor.textSecondary)
                Text(greeting)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AuraColor.textPrimary)
            }
            Spacer()
            if let state = viewModel.snapshot?.metrics.cycleState {
                NavigationLink { CyclePlannerView(deps: dependencies) } label: {
                    PhaseChip(state: state)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, AuraSpacing.s2)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = viewModel.profileName
        let prefix = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        return name.isEmpty ? prefix : "\(prefix), \(name)"
    }

    private var scoreRow: some View {
        HStack(spacing: AuraSpacing.s4) {
            NavigationLink {
                MomentumDetailView(momentum: viewModel.snapshot?.momentum)
            } label: {
                GlassCard {
                    VStack(spacing: AuraSpacing.s3) {
                        CardTitle("Momentum", systemImage: "flame.fill", tint: AuraColor.accent)
                        ScoreRing(score: viewModel.snapshot?.momentum.overall ?? 0,
                                  label: "Momentum", tint: AuraColor.accent, size: .hero)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.plain)

            NavigationLink {
                HealthScoreDetailView(healthScore: viewModel.snapshot?.healthScore)
            } label: {
                GlassCard {
                    VStack(spacing: AuraSpacing.s3) {
                        CardTitle("Health", systemImage: "heart.fill", tint: AuraColor.health)
                        ScoreRing(score: viewModel.snapshot?.healthScore?.overall ?? 0,
                                  label: "Health Score", tint: AuraColor.health, size: .hero)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func caloriesCard(_ snapshot: DailySnapshot) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                CardTitle("Calories remaining", systemImage: "bolt.fill", tint: AuraColor.energy)
                Text("\(max(Int(snapshot.targets.calories - snapshot.metrics.caloriesConsumed), 0)) kcal")
                    .font(AuraFont.metricValue)
                    .foregroundStyle(AuraColor.textPrimary)
                    .contentTransition(.numericText())
                MetricProgressBar(
                    label: "Eaten",
                    value: snapshot.metrics.caloriesConsumed,
                    target: snapshot.targets.calories,
                    unit: "kcal",
                    tint: AuraColor.energy
                )
            }
        }
    }

    private func macroRow(_ snapshot: DailySnapshot) -> some View {
        SurfaceCard {
            HStack {
                MacroRing(title: "Protein", value: snapshot.metrics.proteinG,
                          target: snapshot.targets.proteinG, tint: AuraColor.protein)
                MacroRing(title: "Carbs", value: snapshot.metrics.carbsG,
                          target: snapshot.targets.carbsG, tint: AuraColor.energy)
                MacroRing(title: "Fat", value: snapshot.metrics.fatG,
                          target: snapshot.targets.fatG, tint: AuraColor.celebrate)
                MacroRing(title: "Fiber", value: snapshot.metrics.fiberG,
                          target: snapshot.targets.fiberG, tint: AuraColor.accent)
            }
        }
    }

    private func waterAndNEATRow(_ snapshot: DailySnapshot) -> some View {
        HStack(spacing: AuraSpacing.s4) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    CardTitle("Water", systemImage: "drop.fill", tint: AuraColor.water)
                    Text("\(String(format: "%.1f", snapshot.metrics.waterMl / 1000)) / \(String(format: "%.1f", snapshot.targets.waterMl / 1000)) L")
                        .font(AuraFont.metricValue)
                        .foregroundStyle(AuraColor.textPrimary)
                    Button {
                        Task { await viewModel.quickAddWater() }
                    } label: {
                        Label("+250 ml", systemImage: "plus")
                            .font(AuraFont.chip)
                            .padding(.horizontal, AuraSpacing.s3)
                            .padding(.vertical, 6)
                            .background(AuraColor.water.opacity(0.16), in: .capsule)
                            .foregroundStyle(AuraColor.water)
                    }
                    .buttonStyle(.plain)
                }
            }
            SurfaceCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    CardTitle("Movement", systemImage: "figure.walk", tint: AuraColor.accent)
                    Text("\(snapshot.metrics.activity?.steps ?? 0)")
                        .font(AuraFont.metricValue)
                        .foregroundStyle(AuraColor.textPrimary)
                    Text("of \(snapshot.targets.steps) steps")
                        .font(AuraFont.caption)
                        .foregroundStyle(AuraColor.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var workoutCard: some View {
        if let rec = viewModel.workoutRecommendation {
            SurfaceCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                    CardTitle("Today's workout", systemImage: "dumbbell.fill", tint: AuraColor.accent)
                    Text(rec.workout)
                        .font(AuraFont.body)
                        .foregroundStyle(AuraColor.textPrimary)
                    Text("Adapted to your \(rec.phase.displayName.lowercased()) phase")
                        .font(AuraFont.caption)
                        .foregroundStyle(AuraColor.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var biaCard: some View {
        if let (latest, series) = viewModel.biaSummary {
            SurfaceCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    CardTitle("Body", systemImage: "chart.line.downtrend.xyaxis", tint: AuraColor.health)
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(format: "%.1f kg", latest.weightKg))
                            .font(AuraFont.metricValue)
                            .foregroundStyle(AuraColor.textPrimary)
                        if let bf = latest.bodyFatPercent {
                            Text(String(format: "%.1f%% fat", bf))
                                .font(AuraFont.caption)
                                .foregroundStyle(AuraColor.textSecondary)
                        }
                        Spacer()
                    }
                    TrendSparkline(values: series, tint: AuraColor.health)
                }
            }
        }
    }

    @ViewBuilder
    private var dreamOutfitCard: some View {
        if let outfit = viewModel.pinnedOutfit {
            SurfaceCard {
                HStack(spacing: AuraSpacing.s4) {
                    wardrobeThumbnail(outfit)
                    VStack(alignment: .leading, spacing: AuraSpacing.s1) {
                        CardTitle("Dream outfit", systemImage: "sparkles", tint: AuraColor.celebrate)
                        Text(outfit.title)
                            .font(AuraFont.cardTitle)
                            .foregroundStyle(AuraColor.textPrimary)
                        Text("Target size \(outfit.targetSize) · \(outfit.fitStatus.displayName)")
                            .font(AuraFont.caption)
                            .foregroundStyle(AuraColor.textSecondary)
                    }
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func wardrobeThumbnail(_ item: WardrobeItem) -> some View {
        if let data = item.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: AuraRadius.chip, style: .continuous))
        } else {
            Image(systemName: "tshirt.fill")
                .font(.title2)
                .foregroundStyle(AuraColor.celebrate)
                .frame(width: 64, height: 64)
                .background(AuraColor.celebrate.opacity(0.12), in: .rect(cornerRadius: AuraRadius.chip, style: .continuous))
        }
    }

    private var motivationCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                CardTitle("Daily motivation", systemImage: "quote.opening", tint: AuraColor.accent)
                Text(viewModel.dailyMotivation)
                    .font(AuraFont.body.italic())
                    .foregroundStyle(AuraColor.textPrimary)
                if let insight = viewModel.latestInsight {
                    Divider()
                    Text(insight.message)
                        .font(AuraFont.caption)
                        .foregroundStyle(AuraColor.textSecondary)
                }
            }
        }
    }

    // Needed for the phase-chip navigation link.
    @Environment(\.dependencies) private var envDeps
    private var dependencies: AppDependencies {
        envDeps ?? .preview()
    }
}

/// Per-metric momentum breakdown — partial credit made visible.
struct MomentumDetailView: View {
    let momentum: MomentumScore?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                if let momentum {
                    HStack {
                        Spacer()
                        VStack(spacing: AuraSpacing.s3) {
                            ScoreRing(score: momentum.overall, label: "Momentum", tint: AuraColor.accent, size: .hero)
                            Text(momentum.headline)
                                .font(AuraFont.body)
                                .foregroundStyle(AuraColor.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, AuraSpacing.s4)
                    ForEach(momentum.components, id: \.metric) { component in
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                                HStack {
                                    Text(component.metric.displayName)
                                        .font(AuraFont.body.weight(.medium))
                                        .foregroundStyle(AuraColor.textPrimary)
                                    Spacer()
                                    Text("\(Int(component.score * 100))%")
                                        .font(AuraFont.body.weight(.semibold))
                                        .foregroundStyle(AuraColor.accent)
                                }
                                MetricProgressBar(
                                    label: component.detail, value: component.score * 100,
                                    target: 100, unit: "%", tint: AuraColor.accent
                                )
                            }
                        }
                    }
                } else {
                    EmptyStateView(
                        systemImage: "flame",
                        title: "No momentum yet",
                        message: "Log anything — a meal, a glass of water, a walk — and your momentum begins."
                    )
                }
            }
            .padding(.horizontal, AuraSpacing.screen)
        }
        .background(AuraColor.background)
        .navigationTitle("Momentum")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The Health Score always explains WHY.
struct HealthScoreDetailView: View {
    let healthScore: HealthScore?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                if let healthScore {
                    HStack {
                        Spacer()
                        ScoreRing(score: healthScore.overall, label: "Health Score", tint: AuraColor.health, size: .hero)
                        Spacer()
                    }
                    .padding(.vertical, AuraSpacing.s4)

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                            CardTitle("Why this score", systemImage: "text.magnifyingglass", tint: AuraColor.health)
                            ForEach(healthScore.reasons, id: \.self) { reason in
                                Label(reason, systemImage: "checkmark.circle.fill")
                                    .font(AuraFont.body)
                                    .foregroundStyle(AuraColor.textPrimary)
                            }
                        }
                    }

                    ForEach(healthScore.factors, id: \.kind) { factor in
                        SurfaceCard {
                            HStack {
                                VStack(alignment: .leading, spacing: AuraSpacing.s1) {
                                    Text(factor.kind.displayName)
                                        .font(AuraFont.body.weight(.medium))
                                        .foregroundStyle(AuraColor.textPrimary)
                                    Text(factor.explanation)
                                        .font(AuraFont.caption)
                                        .foregroundStyle(AuraColor.textSecondary)
                                }
                                Spacer()
                                trendIcon(factor.trend)
                            }
                        }
                    }
                } else {
                    EmptyStateView(
                        systemImage: "heart.text.square",
                        title: "Health Score is warming up",
                        message: "A few days of data and your first Health Score appears, with reasons."
                    )
                }
            }
            .padding(.horizontal, AuraSpacing.screen)
        }
        .background(AuraColor.background)
        .navigationTitle("Health Score")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func trendIcon(_ trend: TrendDirection) -> some View {
        Image(systemName: trend == .improving ? "arrow.up.right.circle.fill"
              : trend == .declining ? "arrow.down.right.circle" : "equal.circle")
            .foregroundStyle(trend == .improving ? AuraColor.accent : AuraColor.textSecondary)
    }
}
