import Foundation
import Observation

@Observable
@MainActor
public final class TodayViewModel {

    public private(set) var profileName: String = ""
    public private(set) var snapshot: DailySnapshot?
    public private(set) var pinnedOutfit: WardrobeItem?
    public private(set) var dailyMotivation: String = ""
    public private(set) var latestInsight: Insight?
    public private(set) var biaSummary: (latest: BIAPanel, weightSeries: [Double])?
    public private(set) var workoutRecommendation: PhaseRecommendation?
    public private(set) var needsOnboarding = false

    private let deps: AppDependencies

    public init(deps: AppDependencies) {
        self.deps = deps
    }

    public var coordinator: RecalculationCoordinator { deps.coordinator }

    public func load() async {
        let store = deps.store
        do {
            guard let profile = try await store.currentProfile(),
                  let goal = try await store.activeGoal() else {
                needsOnboarding = true
                return
            }
            needsOnboarding = false
            profileName = profile.name

            await deps.coordinator.recalculate()
            snapshot = deps.coordinator.todaySnapshot

            // Dream outfit card: rotate through pinned items by day.
            let pinned = try await store.pinnedItems()
            if !pinned.isEmpty {
                let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
                pinnedOutfit = pinned[day % pinned.count]
            } else {
                pinnedOutfit = nil
            }

            // BIA summary with a 30-day weight sparkline.
            let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
            let panels = try await store.panels(in: monthAgo ... .now)
            if let latest = panels.last {
                biaSummary = (latest, panels.map(\.weightKg))
            }

            // Cycle-aware workout recommendation.
            if let phase = snapshot?.metrics.cycleState?.phase {
                workoutRecommendation = deps.cycleEngine.recommendation(for: phase)
            }

            // Motivation + insight of the day.
            let why = try await store.artifacts(of: .whyIStarted).first?.text
            let windowStart = Calendar.current.date(byAdding: .day, value: -90, to: .now)!
            let snapshots = try await store.snapshots(in: windowStart ... .now)
            dailyMotivation = deps.motivationEngine.dailyMotivation(
                .init(goal: goal, panels: panels, snapshots: snapshots,
                      wardrobeItems: [], existingMilestones: []),
                whyIStarted: why
            )
            latestInsight = try await store.insights(limit: 1).first
        } catch {
            print("Today load failed: \(error)")
        }
    }

    public func quickAddWater(ml: Double = 250) async {
        do {
            try await deps.store.save(WaterEntry(date: .now, amountMl: ml))
            await deps.coordinator.recalculate()
            snapshot = deps.coordinator.todaySnapshot
        } catch {
            print("Water quick add failed: \(error)")
        }
    }
}
