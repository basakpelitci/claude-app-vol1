import Foundation

/// A recorded menstrual period. Cycle length and phases are derived from the
/// sequence of records — the phase itself is never stored.
public struct CycleRecord: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var periodStartDate: Date
    public var periodEndDate: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        periodStartDate: Date,
        periodEndDate: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.periodStartDate = periodStartDate
        self.periodEndDate = periodEndDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum CyclePhase: String, Codable, CaseIterable, Sendable {
    case menstrual
    case follicular
    case ovulation
    case luteal

    public var displayName: String {
        switch self {
        case .menstrual:  return "Menstrual"
        case .follicular: return "Follicular"
        case .ovulation:  return "Ovulation"
        case .luteal:     return "Luteal"
        }
    }
}

/// The user's derived cycle state on a given day.
public struct CycleState: Equatable, Codable, Sendable {
    public var phase: CyclePhase
    public var dayInCycle: Int
    public var averageCycleLength: Int

    public init(phase: CyclePhase, dayInCycle: Int, averageCycleLength: Int) {
        self.phase = phase
        self.dayInCycle = dayInCycle
        self.averageCycleLength = averageCycleLength
    }
}

/// Phase-specific guidance produced by the cycle logic and consumed by the
/// Goal Engine (adjustments) and the UI (recommendations).
public struct PhaseRecommendation: Equatable, Codable, Sendable {
    public var phase: CyclePhase
    public var workout: String
    public var recovery: String
    public var cardioGuidance: String
    public var strengthGuidance: String
    public var sleepFocus: String
    /// Additive grams applied to the protein target.
    public var proteinAdjustmentG: Double
    /// Additive millilitres applied to the water target.
    public var hydrationAdjustmentMl: Double
    /// Multiplier applied to the calorie target (1.0 = no change).
    public var calorieMultiplier: Double

    public init(
        phase: CyclePhase,
        workout: String,
        recovery: String,
        cardioGuidance: String,
        strengthGuidance: String,
        sleepFocus: String,
        proteinAdjustmentG: Double,
        hydrationAdjustmentMl: Double,
        calorieMultiplier: Double
    ) {
        self.phase = phase
        self.workout = workout
        self.recovery = recovery
        self.cardioGuidance = cardioGuidance
        self.strengthGuidance = strengthGuidance
        self.sleepFocus = sleepFocus
        self.proteinAdjustmentG = proteinAdjustmentG
        self.hydrationAdjustmentMl = hydrationAdjustmentMl
        self.calorieMultiplier = calorieMultiplier
    }
}
