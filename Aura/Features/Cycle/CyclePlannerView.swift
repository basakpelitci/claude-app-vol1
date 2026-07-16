import SwiftUI

@Observable
@MainActor
public final class CycleViewModel {
    public private(set) var state: CycleState?
    public private(set) var recommendation: PhaseRecommendation?
    public private(set) var records: [CycleRecord] = []

    private let deps: AppDependencies

    public init(deps: AppDependencies) {
        self.deps = deps
    }

    public func load() async {
        do {
            records = try await deps.store.records()
            state = deps.cycleEngine.state(on: .now, records: records)
            if let phase = state?.phase {
                recommendation = deps.cycleEngine.recommendation(for: phase)
            }
        } catch {
            print("Cycle load failed: \(error)")
        }
    }

    public func logPeriodStart(_ date: Date) async {
        do {
            try await deps.store.save(CycleRecord(periodStartDate: date))
            // A new phase changes targets immediately.
            await deps.coordinator.recalculate()
            await load()
        } catch {
            print("Cycle save failed: \(error)")
        }
    }
}

/// Phase-aware planning: where the app tells the user their targets already
/// adapted — physiology, not weakness.
public struct CyclePlannerView: View {
    @State private var viewModel: CycleViewModel
    @State private var loggingPeriod = false
    @State private var periodDate: Date = .now

    public init(deps: AppDependencies) {
        _viewModel = State(initialValue: CycleViewModel(deps: deps))
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s4) {
                if let state = viewModel.state {
                    phaseHeader(state)
                    phaseArc(state)
                    if let rec = viewModel.recommendation {
                        recommendationsCard(rec)
                    }
                } else {
                    EmptyStateView(
                        systemImage: "moonphase.waxing.crescent",
                        title: "Cycle planner",
                        message: "Log the first day of your period and Aura adapts your targets to each phase automatically."
                    )
                }
                AuraButton("Log period start") { loggingPeriod = true }
            }
            .padding(.horizontal, AuraSpacing.screen)
            .padding(.bottom, AuraSpacing.s6)
        }
        .background(AuraColor.background)
        .navigationTitle("Cycle")
        .task { await viewModel.load() }
        .sheet(isPresented: $loggingPeriod) {
            NavigationStack {
                Form {
                    DatePicker("First day", selection: $periodDate, in: ...Date.now, displayedComponents: .date)
                }
                .navigationTitle("Log period")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { loggingPeriod = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            loggingPeriod = false
                            Task { await viewModel.logPeriodStart(periodDate) }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func phaseHeader(_ state: CycleState) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                CardTitle("Current phase", systemImage: "moonphase.waxing.crescent", tint: AuraColor.cycle)
                Text("\(state.phase.displayName) · Day \(state.dayInCycle)")
                    .font(AuraFont.cardTitle)
                    .foregroundStyle(AuraColor.textPrimary)
                Text("Your targets are already adapted for this phase.")
                    .font(AuraFont.caption)
                    .foregroundStyle(AuraColor.textSecondary)
            }
        }
    }

    /// Proportional phase bar with a marker for today.
    private func phaseArc(_ state: CycleState) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                CardTitle("Your cycle", systemImage: "calendar", tint: AuraColor.cycle)
                GeometryReader { geo in
                    let length = Double(state.averageCycleLength)
                    let ovulation = Double(state.averageCycleLength - 14)
                    let segments: [(CyclePhase, Double, Double)] = [
                        (.menstrual, 0, 5),
                        (.follicular, 5, ovulation - 1),
                        (.ovulation, ovulation - 1, ovulation + 1),
                        (.luteal, ovulation + 1, length),
                    ]
                    ZStack(alignment: .leading) {
                        HStack(spacing: 2) {
                            ForEach(segments, id: \.0) { segment in
                                Capsule()
                                    .fill(AuraColor.cycle.opacity(segment.0 == state.phase ? 0.9 : 0.25))
                                    .frame(width: max(geo.size.width * (segment.2 - segment.1) / length - 2, 4))
                            }
                        }
                        Circle()
                            .fill(AuraColor.textPrimary)
                            .frame(width: 10, height: 10)
                            .offset(x: geo.size.width * Double(state.dayInCycle - 1) / length - 5)
                    }
                }
                .frame(height: 14)
                HStack {
                    Text("Day 1")
                    Spacer()
                    Text("Day \(state.averageCycleLength)")
                }
                .font(.caption2)
                .foregroundStyle(AuraColor.textSecondary)
            }
        }
    }

    private func recommendationsCard(_ rec: PhaseRecommendation) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                CardTitle("This phase, your body prefers", systemImage: "heart.text.square", tint: AuraColor.cycle)
                recommendationRow("dumbbell.fill", "Workout", rec.workout)
                recommendationRow("bed.double.fill", "Recovery", rec.recovery)
                recommendationRow("figure.run", "Cardio", rec.cardioGuidance)
                recommendationRow("figure.strengthtraining.traditional", "Strength", rec.strengthGuidance)
                recommendationRow("moon.zzz.fill", "Sleep", rec.sleepFocus)
                if rec.proteinAdjustmentG > 0 {
                    recommendationRow("fork.knife", "Protein", "+\(Int(rec.proteinAdjustmentG)) g added to your target")
                }
                if rec.hydrationAdjustmentMl > 0 {
                    recommendationRow("drop.fill", "Hydration", "+\(Int(rec.hydrationAdjustmentMl)) ml added to your target")
                }
            }
        }
    }

    private func recommendationRow(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: AuraSpacing.s3) {
            Image(systemName: icon)
                .foregroundStyle(AuraColor.cycle)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AuraFont.body.weight(.medium))
                    .foregroundStyle(AuraColor.textPrimary)
                Text(text)
                    .font(AuraFont.caption)
                    .foregroundStyle(AuraColor.textSecondary)
            }
        }
    }
}
