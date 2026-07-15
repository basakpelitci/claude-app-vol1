import Foundation

/// A full bioimpedance analysis panel. Only `date` and `weightKg` are
/// required so weight-only scales are supported; engines degrade gracefully
/// (and flag lower confidence) when composition fields are absent.
public struct BIAPanel: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var date: Date
    public var weightKg: Double
    public var bodyFatPercent: Double?
    public var leanBodyMassKg: Double?
    public var muscleMassKg: Double?
    public var bodyWaterPercent: Double?
    public var visceralFatRating: Double?
    public var boneMassKg: Double?
    public var proteinPercent: Double?
    public var bmi: Double?
    public var basalMetabolismKcal: Double?
    public var metabolicAge: Int?
    public var subcutaneousFatPercent: Double?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        date: Date,
        weightKg: Double,
        bodyFatPercent: Double? = nil,
        leanBodyMassKg: Double? = nil,
        muscleMassKg: Double? = nil,
        bodyWaterPercent: Double? = nil,
        visceralFatRating: Double? = nil,
        boneMassKg: Double? = nil,
        proteinPercent: Double? = nil,
        bmi: Double? = nil,
        basalMetabolismKcal: Double? = nil,
        metabolicAge: Int? = nil,
        subcutaneousFatPercent: Double? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.leanBodyMassKg = leanBodyMassKg
        self.muscleMassKg = muscleMassKg
        self.bodyWaterPercent = bodyWaterPercent
        self.visceralFatRating = visceralFatRating
        self.boneMassKg = boneMassKg
        self.proteinPercent = proteinPercent
        self.bmi = bmi
        self.basalMetabolismKcal = basalMetabolismKcal
        self.metabolicAge = metabolicAge
        self.subcutaneousFatPercent = subcutaneousFatPercent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Lean body mass, measured if available, otherwise derived from body fat.
    public var resolvedLeanBodyMassKg: Double? {
        if let leanBodyMassKg { return leanBodyMassKg }
        if let bodyFatPercent { return weightKg * (1 - bodyFatPercent / 100) }
        return nil
    }
}
