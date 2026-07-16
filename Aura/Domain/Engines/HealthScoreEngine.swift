import Foundation

/// Health Score measures *physiology* (Momentum measures consistency).
/// Computed daily over a trailing window and rolled up weekly. Every factor
/// carries an explanation — the score always says WHY it moved.
public struct HealthScoreEngine: Sendable {

    public struct Input: Sendable {
        /// BIA panels in the evaluation window, oldest → newest.
        public var panels: [BIAPanel]
        /// Daily snapshots (metrics + targets) in the window, oldest → newest.
        public var days: [(metrics: DayMetrics, targets: DailyTargets)]

        public init(panels: [BIAPanel], days: [(metrics: DayMetrics, targets: DailyTargets)]) {
            self.panels = panels
            self.days = days
        }
    }

    private static let weights: [HealthFactorKind: Double] = [
        .bodyFatTrend: 0.16,
        .musclePreservation: 0.16,
        .hydration: 0.10,
        .sleep: 0.13,
        .recovery: 0.09,
        .nutritionQuality: 0.13,
        .proteinAdequacy: 0.13,
        .cycleHealth: 0.05,
        .restingDays: 0.05,
    ]

    private let calendar: Calendar
    private let nutritionEngine: NutritionEngine

    public init(calendar: Calendar = .current, nutritionEngine: NutritionEngine = NutritionEngine()) {
        self.calendar = calendar
        self.nutritionEngine = nutritionEngine
    }

    public func score(_ input: Input) -> HealthScore {
        var factors: [HealthFactor] = []

        // --- Body fat trend (down = improving for fat loss) ---
        if let f = bodyFatFactor(panels: input.panels) { factors.append(f) }
        // --- Muscle preservation (flat or up while losing = excellent) ---
        if let f = muscleFactor(panels: input.panels) { factors.append(f) }

        let days = input.days
        if !days.isEmpty {
            factors.append(averageFactor(
                kind: .hydration, days: days,
                value: { HealthMath.attainment($0.metrics.waterMl, target: $0.targets.waterMl) },
                good: "Hydration on target", weak: "Water has been running below target"
            ))
            let sleepDays = days.filter { $0.metrics.sleep != nil }
            if !sleepDays.isEmpty {
                factors.append(averageFactor(
                    kind: .sleep, days: sleepDays,
                    value: { HealthMath.attainment($0.metrics.sleep!.hoursSlept, target: $0.targets.sleepHours) },
                    good: "Sleep is supporting recovery", weak: "Sleep slightly under what your body needs"
                ))
            }
            factors.append(averageFactor(
                kind: .proteinAdequacy, days: days,
                value: { HealthMath.attainment($0.metrics.proteinG, target: $0.targets.proteinG) },
                good: "Protein excellent — muscle is protected", weak: "Protein below target on several days"
            ))
            factors.append(averageFactor(
                kind: .nutritionQuality, days: days,
                value: {
                    nutritionEngine.macroQuality(
                        calories: $0.metrics.caloriesConsumed, proteinG: $0.metrics.proteinG,
                        fatG: $0.metrics.fatG, fiberG: $0.metrics.fiberG, targets: $0.targets
                    )
                },
                good: "Calories are well spent — quality macros", weak: "Macro quality has room to improve"
            ))

            // Recovery + rest days from activity pattern.
            let activityDays = days.compactMap { $0.metrics.activity }
            if activityDays.count >= 5 {
                let workouts = activityDays.filter(\.workoutCompleted).count
                let rest = activityDays.count - workouts
                let restScore: Double = rest >= 1 && workouts >= 2 ? 1 : (rest >= 1 || workouts >= 2 ? 0.7 : 0.4)
                factors.append(HealthFactor(
                    kind: .restingDays, score: restScore, weight: 0, trend: .stable,
                    explanation: restScore == 1
                        ? "A healthy balance of training and rest"
                        : "Balance training with at least one full rest day"
                ))
                let sedentaryAvg = Double(activityDays.map(\.sedentaryMinutes).reduce(0, +)) / Double(activityDays.count)
                let recovery = HealthMath.clamp(1.2 - sedentaryAvg / 900, 0, 1)
                factors.append(HealthFactor(
                    kind: .recovery, score: recovery, weight: 0,
                    trend: recovery > 0.7 ? .stable : .declining,
                    explanation: recovery > 0.7 ? "Active recovery looks good" : "Long sedentary stretches — short walks will help"
                ))
            }

            // Cycle health: data present and targets adapted.
            let cycleDays = days.filter { $0.metrics.cycleState != nil }
            if !cycleDays.isEmpty {
                factors.append(HealthFactor(
                    kind: .cycleHealth, score: 1, weight: 0, trend: .stable,
                    explanation: "Cycle tracked — targets are adapting to your phase"
                ))
            }
        }

        // Normalize weights over the factors we could actually evaluate.
        let withWeights = factors.map { f in
            HealthFactor(kind: f.kind, score: f.score, weight: Self.weights[f.kind] ?? 0.05,
                         trend: f.trend, explanation: f.explanation)
        }
        let total = withWeights.reduce(0) { $0 + $1.weight }
        guard total > 0 else {
            return HealthScore(overall: 0, factors: [], reasons: ["Not enough data yet — log a few days to see your Health Score."])
        }
        let normalized = withWeights.map {
            HealthFactor(kind: $0.kind, score: $0.score, weight: $0.weight / total, trend: $0.trend, explanation: $0.explanation)
        }
        let overall = Int((normalized.reduce(0) { $0 + $1.score * $1.weight } * 100).rounded())

        // Reasons: strongest factors first, then the gentlest area to improve.
        let sorted = normalized.sorted { $0.score > $1.score }
        var reasons = sorted.prefix(3).filter { $0.score >= 0.75 }.map(\.explanation)
        if let weakest = sorted.last, weakest.score < 0.75 {
            reasons.append(weakest.explanation)
        }
        if reasons.isEmpty { reasons = sorted.prefix(2).map(\.explanation) }

        return HealthScore(overall: overall, factors: sorted, reasons: reasons)
    }

    // MARK: - Composition factors

    private func bodyFatFactor(panels: [BIAPanel]) -> HealthFactor? {
        let series = panels.compactMap { p -> (Double, Double)? in
            guard let bf = p.bodyFatPercent else { return nil }
            return (p.date.timeIntervalSinceReferenceDate / 86_400, bf)
        }
        guard series.count >= 3,
              let slope = HealthMath.weightedSlopePerDay(x: series.map(\.0), y: series.map(\.1))
        else { return nil }

        // −0.05 %/day (≈ −0.35 %/week) is excellent; positive slope tapers off.
        let score = HealthMath.clamp(0.6 + (-slope / 0.05) * 0.4, 0, 1)
        let trend: TrendDirection = slope < -0.005 ? .improving : (slope > 0.01 ? .declining : .stable)
        let explanation: String
        switch trend {
        case .improving: explanation = "Body fat is trending down"
        case .stable:    explanation = "Body fat is holding steady"
        case .declining: explanation = "Body fat ticked up — trends matter more than days"
        }
        return HealthFactor(kind: .bodyFatTrend, score: score, weight: 0, trend: trend, explanation: explanation)
    }

    private func muscleFactor(panels: [BIAPanel]) -> HealthFactor? {
        let series = panels.compactMap { p -> (Double, Double)? in
            guard let m = p.muscleMassKg ?? p.resolvedLeanBodyMassKg else { return nil }
            return (p.date.timeIntervalSinceReferenceDate / 86_400, m)
        }
        guard series.count >= 3,
              let slope = HealthMath.weightedSlopePerDay(x: series.map(\.0), y: series.map(\.1))
        else { return nil }

        // Preserving (≥ −5 g/day) is a win in a deficit; gaining is exceptional.
        let score = HealthMath.clamp(0.9 + slope * 20, 0, 1)
        let trend: TrendDirection = slope > 0.002 ? .improving : (slope < -0.01 ? .declining : .stable)
        let explanation: String
        switch trend {
        case .improving: explanation = "Muscle is increasing while you lose fat — the best possible sign"
        case .stable:    explanation = "Muscle preserved during fat loss"
        case .declining: explanation = "Muscle dipping — protein and strength work protect it"
        }
        return HealthFactor(kind: .musclePreservation, score: score, weight: 0, trend: trend, explanation: explanation)
    }

    private func averageFactor(
        kind: HealthFactorKind,
        days: [(metrics: DayMetrics, targets: DailyTargets)],
        value: ((metrics: DayMetrics, targets: DailyTargets)) -> Double,
        good: String,
        weak: String
    ) -> HealthFactor {
        let scores = days.map(value)
        let avg = scores.reduce(0, +) / Double(scores.count)
        // Trend: second half of window vs first half.
        let mid = scores.count / 2
        let first = scores.prefix(mid), second = scores.suffix(scores.count - mid)
        let delta = (second.reduce(0, +) / Double(max(second.count, 1))) - (first.reduce(0, +) / Double(max(first.count, 1)))
        let trend: TrendDirection = delta > 0.05 ? .improving : (delta < -0.05 ? .declining : .stable)
        return HealthFactor(kind: kind, score: avg, weight: 0, trend: trend, explanation: avg >= 0.75 ? good : weak)
    }
}
