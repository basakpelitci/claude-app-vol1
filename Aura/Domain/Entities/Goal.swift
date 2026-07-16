import Foundation

public enum GoalKind: String, Codable, CaseIterable, Sendable {
    case fatLoss
    case maintenance
    case recomposition
}

/// The user's active goal. `weeklyRateKg` is clamped at creation and again in
/// the Goal Engine so a crash-diet rate can never reach target math.
public struct Goal: Identifiable, Equatable, Codable, Sendable {
    public static let minWeeklyRateKg = 0.25
    public static let maxWeeklyRateKg = 0.75

    public var id: UUID
    public var kind: GoalKind
    public var targetWeightKg: Double?
    public var targetBodyFatPercent: Double?
    public var weeklyRateKg: Double
    public var startDate: Date
    public var startWeightKg: Double
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        kind: GoalKind,
        targetWeightKg: Double? = nil,
        targetBodyFatPercent: Double? = nil,
        weeklyRateKg: Double = 0.5,
        startDate: Date = .now,
        startWeightKg: Double,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.targetWeightKg = targetWeightKg
        self.targetBodyFatPercent = targetBodyFatPercent
        self.weeklyRateKg = min(max(weeklyRateKg, Self.minWeeklyRateKg), Self.maxWeeklyRateKg)
        self.startDate = startDate
        self.startWeightKg = startWeightKg
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
