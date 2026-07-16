import Foundation

/// Scores a day's eating: per-macro attainment, macro quality, and an overall
/// meal score with a friendly grade. Pure; targets come from the Goal Engine.
public struct NutritionEngine: Sendable {

    public struct DayScore: Equatable, Sendable {
        public var proteinAttainment: Double
        public var calorieAdherence: Double
        public var fiberAttainment: Double
        public var macroQuality: Double
        /// 0…1 blend of the above.
        public var overall: Double
        /// A+, A, B+, B, C+, C — never below C (no failing grades by design).
        public var grade: String
    }

    public init() {}

    public func score(entries: [MealEntry], targets: DailyTargets) -> DayScore {
        let calories = entries.reduce(0) { $0 + $1.calories }
        let protein = entries.reduce(0) { $0 + $1.proteinG }
        let fat = entries.reduce(0) { $0 + $1.fatG }
        let fiber = entries.reduce(0) { $0 + $1.fiberG }

        let proteinScore = HealthMath.attainment(protein, target: targets.proteinG)
        let calorieScore = HealthMath.adherenceWithOvershoot(calories, target: targets.calories)
        let fiberScore = HealthMath.attainment(fiber, target: targets.fiberG)
        let quality = macroQuality(calories: calories, proteinG: protein, fatG: fat, fiberG: fiber, targets: targets)

        let overall = proteinScore * 0.35 + calorieScore * 0.35 + fiberScore * 0.10 + quality * 0.20
        return DayScore(
            proteinAttainment: proteinScore,
            calorieAdherence: calorieScore,
            fiberAttainment: fiberScore,
            macroQuality: quality,
            overall: overall,
            grade: grade(for: overall)
        )
    }

    /// Macro quality rewards a protein-forward, fiber-adequate distribution —
    /// how well calories were "spent", independent of how many.
    public func macroQuality(calories: Double, proteinG: Double, fatG: Double, fiberG: Double, targets: DailyTargets) -> Double {
        guard calories > 0 else { return 0 }
        let proteinShare = proteinG * 4 / calories
        let targetProteinShare = targets.proteinG * 4 / max(targets.calories, 1)
        let proteinComponent = HealthMath.clamp(proteinShare / max(targetProteinShare, 0.01), 0, 1)

        let fatShare = fatG * 9 / calories
        // Fat share is healthiest in a 20–40% band; taper outside it.
        let fatComponent: Double
        switch fatShare {
        case 0.20...0.40: fatComponent = 1
        case ..<0.20:     fatComponent = HealthMath.clamp(fatShare / 0.20, 0, 1)
        default:          fatComponent = HealthMath.clamp(1 - (fatShare - 0.40) * 2.5, 0, 1)
        }

        let fiberComponent = HealthMath.attainment(fiberG, target: targets.fiberG)
        return proteinComponent * 0.5 + fatComponent * 0.25 + fiberComponent * 0.25
    }

    private func grade(for overall: Double) -> String {
        switch overall {
        case 0.93...: return "A+"
        case 0.85...: return "A"
        case 0.75...: return "B+"
        case 0.65...: return "B"
        case 0.50...: return "C+"
        default:      return "C"
        }
    }
}
