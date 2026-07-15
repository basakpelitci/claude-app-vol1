import Foundation

public enum WorkoutKind: String, Codable, CaseIterable, Sendable {
    case strength
    case cardio
    case walking
    case yoga
    case recovery
    case other
}

/// One day of NEAT + exercise. A single mutable row per day, updated as data
/// arrives (manual entry now; HealthKit/wearables later).
public struct ActivitySummary: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var date: Date
    public var steps: Int
    public var walkingMinutes: Int
    public var standingMinutes: Int
    public var exerciseMinutes: Int
    public var sedentaryMinutes: Int
    public var workoutCompleted: Bool
    public var workoutKind: WorkoutKind?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        date: Date,
        steps: Int = 0,
        walkingMinutes: Int = 0,
        standingMinutes: Int = 0,
        exerciseMinutes: Int = 0,
        sedentaryMinutes: Int = 0,
        workoutCompleted: Bool = false,
        workoutKind: WorkoutKind? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.steps = steps
        self.walkingMinutes = walkingMinutes
        self.standingMinutes = standingMinutes
        self.exerciseMinutes = exerciseMinutes
        self.sedentaryMinutes = sedentaryMinutes
        self.workoutCompleted = workoutCompleted
        self.workoutKind = workoutKind
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct SleepEntry: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var date: Date
    public var hoursSlept: Double
    /// Subjective or device-derived quality in 0…1, if known.
    public var quality: Double?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        date: Date,
        hoursSlept: Double,
        quality: Double? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.hoursSlept = hoursSlept
        self.quality = quality
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
