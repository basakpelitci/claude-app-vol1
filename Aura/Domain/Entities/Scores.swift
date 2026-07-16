import Foundation

/// The full set of daily targets produced by the Goal Engine. Nothing in the
/// UI may display a target that did not come from an instance of this type.
public struct DailyTargets: Equatable, Codable, Sendable {
    public var calories: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var fiberG: Double
    public var waterMl: Double
    public var steps: Int
    public var exerciseMinutes: Int
    public var sleepHours: Double
    /// True when composition data was estimated (no BIA) — surfaced in UI.
    public var isLowConfidence: Bool

    public init(
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        fiberG: Double,
        waterMl: Double,
        steps: Int,
        exerciseMinutes: Int,
        sleepHours: Double,
        isLowConfidence: Bool = false
    ) {
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.waterMl = waterMl
        self.steps = steps
        self.exerciseMinutes = exerciseMinutes
        self.sleepHours = sleepHours
        self.isLowConfidence = isLowConfidence
    }
}

public enum MomentumMetric: String, Codable, CaseIterable, Sendable {
    case calories
    case protein
    case water
    case workout
    case neat
    case sleep
    case mealTiming
    case cycleCompliance
    case habits

    public var displayName: String {
        switch self {
        case .calories:        return "Calories"
        case .protein:         return "Protein"
        case .water:           return "Water"
        case .workout:         return "Workout"
        case .neat:            return "Movement"
        case .sleep:           return "Sleep"
        case .mealTiming:      return "Meal timing"
        case .cycleCompliance: return "Cycle sync"
        case .habits:          return "Habits"
        }
    }
}

public struct MomentumComponent: Equatable, Codable, Sendable {
    public var metric: MomentumMetric
    /// Partial-credit score in 0…1 — never pass/fail.
    public var score: Double
    /// Normalized weight of this metric within today's score.
    public var weight: Double
    public var detail: String

    public init(metric: MomentumMetric, score: Double, weight: Double, detail: String) {
        self.metric = metric
        self.score = score
        self.weight = weight
        self.detail = detail
    }
}

/// Today's behavioral consistency, 0–100, from weighted partial scores.
public struct MomentumScore: Equatable, Codable, Sendable {
    public var overall: Int
    public var components: [MomentumComponent]
    public var headline: String

    public init(overall: Int, components: [MomentumComponent], headline: String) {
        self.overall = overall
        self.components = components
        self.headline = headline
    }
}

public enum HealthFactorKind: String, Codable, CaseIterable, Sendable {
    case bodyFatTrend
    case musclePreservation
    case hydration
    case sleep
    case recovery
    case nutritionQuality
    case proteinAdequacy
    case cycleHealth
    case restingDays

    public var displayName: String {
        switch self {
        case .bodyFatTrend:       return "Body fat trend"
        case .musclePreservation: return "Muscle preservation"
        case .hydration:          return "Hydration"
        case .sleep:              return "Sleep"
        case .recovery:           return "Recovery"
        case .nutritionQuality:   return "Nutrition quality"
        case .proteinAdequacy:    return "Protein adequacy"
        case .cycleHealth:        return "Cycle health"
        case .restingDays:        return "Rest days"
        }
    }
}

public enum TrendDirection: String, Codable, Sendable {
    case improving
    case stable
    case declining
}

public struct HealthFactor: Equatable, Codable, Sendable {
    public var kind: HealthFactorKind
    public var score: Double
    public var weight: Double
    public var trend: TrendDirection
    public var explanation: String

    public init(kind: HealthFactorKind, score: Double, weight: Double, trend: TrendDirection, explanation: String) {
        self.kind = kind
        self.score = score
        self.weight = weight
        self.trend = trend
        self.explanation = explanation
    }
}

/// Physiological health, 0–100, with human-readable reasons for every move.
public struct HealthScore: Equatable, Codable, Sendable {
    public var overall: Int
    public var factors: [HealthFactor]
    /// Ordered explanations of why the score is what it is (best first).
    public var reasons: [String]

    public init(overall: Int, factors: [HealthFactor], reasons: [String]) {
        self.overall = overall
        self.factors = factors
        self.reasons = reasons
    }
}

public struct ProjectedPoint: Equatable, Codable, Sendable {
    public var date: Date
    public var weightKg: Double
    public var bodyFatPercent: Double?
    public var muscleMassKg: Double?

    public init(date: Date, weightKg: Double, bodyFatPercent: Double? = nil, muscleMassKg: Double? = nil) {
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.muscleMassKg = muscleMassKg
    }
}

public enum PredictionConfidence: String, Codable, Sendable {
    case low
    case medium
    case high
}

public struct Prediction: Equatable, Codable, Sendable {
    public var estimatedGoalDate: Date?
    public var projectedWeightKg: Double
    public var projectedBodyFatPercent: Double?
    public var projectedMuscleMassKg: Double?
    /// Weekly projected series from today to (about) the goal date.
    public var weeklySeries: [ProjectedPoint]
    public var confidence: PredictionConfidence

    public init(
        estimatedGoalDate: Date?,
        projectedWeightKg: Double,
        projectedBodyFatPercent: Double? = nil,
        projectedMuscleMassKg: Double? = nil,
        weeklySeries: [ProjectedPoint] = [],
        confidence: PredictionConfidence
    ) {
        self.estimatedGoalDate = estimatedGoalDate
        self.projectedWeightKg = projectedWeightKg
        self.projectedBodyFatPercent = projectedBodyFatPercent
        self.projectedMuscleMassKg = projectedMuscleMassKg
        self.weeklySeries = weeklySeries
        self.confidence = confidence
    }
}

/// Everything the scoring engines need about a single day, assembled by the
/// recalculation coordinator from repositories.
public struct DayMetrics: Equatable, Codable, Sendable {
    public var date: Date
    public var caloriesConsumed: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var fiberG: Double
    public var waterMl: Double
    public var mealTimes: [Date]
    public var activity: ActivitySummary?
    public var sleep: SleepEntry?
    public var cycleState: CycleState?
    /// Whether today's activity followed the phase recommendation (nil when
    /// cycle tracking is off — the metric is then excluded, not zeroed).
    public var followedCycleRecommendation: Bool?
    /// Completion ratio of user-defined daily habits, 0…1 (nil = none defined).
    public var habitCompletion: Double?

    public init(
        date: Date,
        caloriesConsumed: Double = 0,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        fiberG: Double = 0,
        waterMl: Double = 0,
        mealTimes: [Date] = [],
        activity: ActivitySummary? = nil,
        sleep: SleepEntry? = nil,
        cycleState: CycleState? = nil,
        followedCycleRecommendation: Bool? = nil,
        habitCompletion: Double? = nil
    ) {
        self.date = date
        self.caloriesConsumed = caloriesConsumed
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.waterMl = waterMl
        self.mealTimes = mealTimes
        self.activity = activity
        self.sleep = sleep
        self.cycleState = cycleState
        self.followedCycleRecommendation = followedCycleRecommendation
        self.habitCompletion = habitCompletion
    }
}

/// Per-day computed cache: what the dashboard renders.
public struct DailySnapshot: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var date: Date
    public var targets: DailyTargets
    public var momentum: MomentumScore
    public var healthScore: HealthScore?
    public var metrics: DayMetrics

    public init(
        id: UUID = UUID(),
        date: Date,
        targets: DailyTargets,
        momentum: MomentumScore,
        healthScore: HealthScore? = nil,
        metrics: DayMetrics
    ) {
        self.id = id
        self.date = date
        self.targets = targets
        self.momentum = momentum
        self.healthScore = healthScore
        self.metrics = metrics
    }
}
