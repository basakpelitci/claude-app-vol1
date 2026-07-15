import Foundation

/// Biological sex, used only for metabolic formulas and cycle-feature gating.
public enum BiologicalSex: String, Codable, CaseIterable, Sendable {
    case female
    case male
    case unspecified
}

/// Self-reported baseline activity level. The raw multiplier is the classic
/// TDEE activity factor applied to BMR.
public enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    public var tdeeMultiplier: Double {
        switch self {
        case .sedentary:  return 1.2
        case .light:      return 1.375
        case .moderate:   return 1.55
        case .active:     return 1.725
        case .veryActive: return 1.9
        }
    }

    /// Grams of protein per kg of *lean body mass*. Higher activity → more
    /// protein to preserve muscle in a deficit.
    public var proteinPerKgLBM: Double {
        switch self {
        case .sedentary:  return 1.6
        case .light:      return 1.8
        case .moderate:   return 2.0
        case .active:     return 2.2
        case .veryActive: return 2.4
        }
    }
}

public struct UserProfile: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var birthDate: Date
    public var heightCm: Double
    public var biologicalSex: BiologicalSex
    public var activityLevel: ActivityLevel
    public var cycleTrackingEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        birthDate: Date,
        heightCm: Double,
        biologicalSex: BiologicalSex,
        activityLevel: ActivityLevel,
        cycleTrackingEnabled: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.biologicalSex = biologicalSex
        self.activityLevel = activityLevel
        self.cycleTrackingEnabled = cycleTrackingEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func age(on date: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.year], from: birthDate, to: date).year ?? 0
    }
}
