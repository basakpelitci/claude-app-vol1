import Foundation
import Observation

/// The recompute pipeline: every write (meal, water, activity, BIA, cycle,
/// goal) funnels through here. It assembles today's DayMetrics, reruns
/// Goal → Nutrition → Momentum (→ Health Score), persists the DailySnapshot,
/// and publishes it so every score in the UI updates immediately.
@Observable
@MainActor
public final class RecalculationCoordinator {

    public private(set) var todaySnapshot: DailySnapshot?
    public private(set) var pendingCelebrations: [Milestone] = []

    private let store: LocalStore
    private let goalEngine: GoalEngine
    private let nutritionEngine: NutritionEngine
    private let momentumEngine: MomentumEngine
    private let healthScoreEngine: HealthScoreEngine
    private let motivationEngine: MotivationEngine
    private let insightEngine: any InsightGenerating
    private let cycleEngine: CycleEngine
    private let calendar: Calendar

    public init(
        store: LocalStore,
        goalEngine: GoalEngine = GoalEngine(),
        nutritionEngine: NutritionEngine = NutritionEngine(),
        momentumEngine: MomentumEngine = MomentumEngine(),
        healthScoreEngine: HealthScoreEngine = HealthScoreEngine(),
        motivationEngine: MotivationEngine = MotivationEngine(),
        insightEngine: any InsightGenerating = InsightEngine(),
        cycleEngine: CycleEngine = CycleEngine(),
        calendar: Calendar = .current
    ) {
        self.store = store
        self.goalEngine = goalEngine
        self.nutritionEngine = nutritionEngine
        self.momentumEngine = momentumEngine
        self.healthScoreEngine = healthScoreEngine
        self.motivationEngine = motivationEngine
        self.insightEngine = insightEngine
        self.cycleEngine = cycleEngine
        self.calendar = calendar
    }

    /// Recomputes and republishes the snapshot for `day` (usually today).
    /// Safe to call after every write; errors are contained — a failed
    /// recompute never corrupts logged data.
    public func recalculate(day: Date = .now) async {
        do {
            guard let profile = try await store.currentProfile(),
                  let goal = try await store.activeGoal() else { return }

            // --- Cycle state ---
            let cycleRecords = profile.cycleTrackingEnabled ? try await store.records() : []
            let cycleState = cycleEngine.state(on: day, records: cycleRecords)

            // --- Targets (Goal Engine, never hardcoded) ---
            let latestBIA = try await store.latestPanel()
            let targets = goalEngine.targets(for: .init(
                profile: profile, goal: goal, latestBIA: latestBIA, cyclePhase: cycleState?.phase
            ))

            // --- Assemble today's metrics ---
            let meals = try await store.entries(on: day)
            let waterMl = try await store.totalMl(on: day)
            let activity = try await store.summary(on: day)
            let sleep = try await store.entry(on: day)

            var followedCycle: Bool?
            if let cycleState, let activity {
                // Luteal/menstrual ask for moderation: completing *any*
                // intentional movement or rest counts as following the plan.
                switch cycleState.phase {
                case .menstrual, .luteal:
                    followedCycle = !activity.workoutCompleted || activity.exerciseMinutes <= 75
                case .follicular, .ovulation:
                    followedCycle = activity.workoutCompleted || activity.steps >= targets.steps / 2
                }
            }

            let metrics = DayMetrics(
                date: day,
                caloriesConsumed: meals.reduce(0) { $0 + $1.calories },
                proteinG: meals.reduce(0) { $0 + $1.proteinG },
                carbsG: meals.reduce(0) { $0 + $1.carbsG },
                fatG: meals.reduce(0) { $0 + $1.fatG },
                fiberG: meals.reduce(0) { $0 + $1.fiberG },
                waterMl: waterMl,
                mealTimes: meals.map(\.date),
                activity: activity,
                sleep: sleep,
                cycleState: cycleState,
                followedCycleRecommendation: followedCycle
            )

            // --- Scores ---
            let momentum = momentumEngine.score(metrics: metrics, targets: targets)

            let windowStart = calendar.date(byAdding: .day, value: -14, to: day) ?? day
            let panels = try await store.panels(in: windowStart...day)
            let priorSnapshots = try await store.snapshots(in: windowStart...day)
            var days = priorSnapshots
                .filter { !calendar.isDate($0.date, inSameDayAs: day) }
                .map { (metrics: $0.metrics, targets: $0.targets) }
            days.append((metrics: metrics, targets: targets))
            let health = healthScoreEngine.score(.init(panels: panels, days: days))

            let snapshot = DailySnapshot(
                date: day, targets: targets, momentum: momentum,
                healthScore: health, metrics: metrics
            )
            try await store.save(snapshot)
            todaySnapshot = snapshot

            await detectMilestonesAndInsights(goal: goal, day: day)
        } catch {
            // Derived state only — log and keep the last good snapshot.
            print("Recalculation failed: \(error)")
        }
    }

    /// Milestones fire once and queue a celebration; insights are refreshed
    /// on day boundaries.
    private func detectMilestonesAndInsights(goal: Goal, day: Date) async {
        do {
            let monthStart = calendar.date(byAdding: .day, value: -90, to: day) ?? day
            let panels = try await store.panels(in: monthStart...day)
            let snapshots = try await store.snapshots(in: monthStart...day)
            let wardrobe = try await store.allItems()
            let existing = try await store.milestones()

            let input = MotivationEngine.Input(
                goal: goal, panels: panels, snapshots: snapshots,
                wardrobeItems: wardrobe, existingMilestones: existing, today: day
            )
            let fresh = motivationEngine.newMilestones(input)
            for milestone in fresh {
                try await store.save(milestone)
            }
            if !fresh.isEmpty {
                pendingCelebrations.append(contentsOf: fresh)
            }

            let cycleRecords = try await store.records()
            let todaysInsights = try await store.insights(limit: 1)
            let alreadyGeneratedToday = todaysInsights.first.map { calendar.isDate($0.date, inSameDayAs: day) } ?? false
            if !alreadyGeneratedToday {
                for insight in insightEngine.insights(from: snapshots, cycleRecords: cycleRecords, asOf: day) {
                    try await store.save(insight)
                }
            }
        } catch {
            print("Milestone/insight detection failed: \(error)")
        }
    }

    public func dismissCelebration() {
        if !pendingCelebrations.isEmpty {
            pendingCelebrations.removeFirst()
        }
    }
}
