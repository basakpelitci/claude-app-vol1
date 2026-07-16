import Foundation

/// The heart of the app. Momentum measures *today's behavioral consistency*
/// as a weighted blend of partial-credit scores — never pass/fail, never a
/// breakable streak. Metrics with no data source today (no cycle tracking,
/// no habits defined) are excluded and their weight redistributed, so the
/// user is never punished for a feature they don't use.
public struct MomentumEngine: Sendable {

    /// Base weights; normalized over whichever metrics are present today.
    public static let baseWeights: [MomentumMetric: Double] = [
        .calories: 0.20,
        .protein: 0.18,
        .water: 0.12,
        .workout: 0.15,
        .neat: 0.12,
        .sleep: 0.10,
        .mealTiming: 0.05,
        .cycleCompliance: 0.04,
        .habits: 0.04,
    ]

    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func score(metrics: DayMetrics, targets: DailyTargets) -> MomentumScore {
        var components: [MomentumComponent] = []

        func add(_ metric: MomentumMetric, _ score: Double, _ detail: String) {
            components.append(MomentumComponent(
                metric: metric,
                score: HealthMath.clamp(score, 0, 1),
                weight: Self.baseWeights[metric] ?? 0,
                detail: detail
            ))
        }

        // Calories — adherence with gentle overshoot falloff.
        let cal = HealthMath.adherenceWithOvershoot(metrics.caloriesConsumed, target: targets.calories)
        add(.calories, cal, "\(Int(metrics.caloriesConsumed)) of \(Int(targets.calories)) kcal")

        // Protein — pure attainment; more is simply capped, never penalized.
        let prot = HealthMath.attainment(metrics.proteinG, target: targets.proteinG)
        add(.protein, prot, "\(Int(metrics.proteinG)) of \(Int(targets.proteinG)) g")

        // Water.
        let water = HealthMath.attainment(metrics.waterMl, target: targets.waterMl)
        add(.water, water, "\(Int(metrics.waterMl)) of \(Int(targets.waterMl)) ml")

        // Workout — completion is full credit; exercise minutes earn partial
        // credit on non-workout days (movement always counts).
        if let activity = metrics.activity {
            let workoutScore = activity.workoutCompleted
                ? 1.0
                : HealthMath.attainment(Double(activity.exerciseMinutes), target: Double(targets.exerciseMinutes))
            add(.workout, workoutScore, activity.workoutCompleted ? "Workout complete" : "\(activity.exerciseMinutes) active minutes")

            // NEAT — steps with a sedentary-time taper.
            var neat = HealthMath.attainment(Double(activity.steps), target: Double(targets.steps))
            if activity.sedentaryMinutes > 600 { neat *= 0.85 }
            add(.neat, neat, "\(activity.steps) steps")
        }

        // Sleep.
        if let sleep = metrics.sleep {
            let s = HealthMath.attainment(sleep.hoursSlept, target: targets.sleepHours)
            add(.sleep, s, String(format: "%.1f of %.1f h", sleep.hoursSlept, targets.sleepHours))
        }

        // Meal timing — rewards distributing intake across the day (3+ eating
        // occasions spread over 6+ hours) rather than judging *when*.
        if metrics.mealTimes.count >= 2 {
            let sorted = metrics.mealTimes.sorted()
            let spreadHours = sorted.last!.timeIntervalSince(sorted.first!) / 3600
            let occasions = HealthMath.clamp(Double(metrics.mealTimes.count) / 3, 0, 1)
            let spread = HealthMath.clamp(spreadHours / 6, 0, 1)
            add(.mealTiming, occasions * 0.5 + spread * 0.5, "\(metrics.mealTimes.count) meals across the day")
        } else if !metrics.mealTimes.isEmpty {
            add(.mealTiming, 0.4, "One meal logged so far")
        }

        // Cycle compliance — only when tracking is on and a recommendation
        // existed today.
        if let followed = metrics.followedCycleRecommendation {
            add(.cycleCompliance, followed ? 1 : 0.5, followed ? "Synced with your phase" : "Off phase plan — still counts")
        }

        // Habits.
        if let habits = metrics.habitCompletion {
            add(.habits, habits, "\(Int(habits * 100))% of habits")
        }

        // Normalize weights over present components.
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            return MomentumScore(overall: 0, components: [], headline: "Log anything to start your day")
        }
        let normalized = components.map { c in
            MomentumComponent(metric: c.metric, score: c.score, weight: c.weight / totalWeight, detail: c.detail)
        }
        let overall = Int((normalized.reduce(0) { $0 + $1.score * $1.weight } * 100).rounded())

        return MomentumScore(
            overall: overall,
            components: normalized.sorted { $0.score > $1.score },
            headline: headline(for: overall, components: normalized)
        )
    }

    /// Celebrate first, inform second — never shame.
    private func headline(for overall: Int, components: [MomentumComponent]) -> String {
        let best = components.max { $0.score < $1.score }
        switch overall {
        case 90...: return "A strong day — you're building something."
        case 75...: return "Solid consistency today."
        case 50...:
            if let best { return "\(best.metric.displayName) was your win today." }
            return "Progress logged — every entry counts."
        default:
            return "Showing up is the whole game. You're here."
        }
    }
}
