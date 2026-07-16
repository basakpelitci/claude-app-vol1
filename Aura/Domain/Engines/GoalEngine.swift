import Foundation

/// Computes every daily target in the app. Recomputed whenever BIA values,
/// activity level, cycle phase, or the goal change — targets are never
/// hardcoded and never edited by hand.
public struct GoalEngine: Sendable {

    public struct Input: Sendable {
        public var profile: UserProfile
        public var goal: Goal
        public var latestBIA: BIAPanel?
        public var cyclePhase: CyclePhase?

        public init(profile: UserProfile, goal: Goal, latestBIA: BIAPanel? = nil, cyclePhase: CyclePhase? = nil) {
            self.profile = profile
            self.goal = goal
            self.latestBIA = latestBIA
            self.cyclePhase = cyclePhase
        }
    }

    private let cycleEngine: CycleEngine

    public init(cycleEngine: CycleEngine = CycleEngine()) {
        self.cycleEngine = cycleEngine
    }

    public func targets(for input: Input) -> DailyTargets {
        let profile = input.profile
        let goal = input.goal

        // --- Body composition (BIA-first, estimated fallback) ---
        let weightKg = input.latestBIA?.weightKg ?? goal.startWeightKg
        let measuredLBM = input.latestBIA?.resolvedLeanBodyMassKg
        let lbm = measuredLBM ?? HealthMath.estimatedLeanBodyMassKg(
            weightKg: weightKg, heightCm: profile.heightCm, sex: profile.biologicalSex
        )
        let isLowConfidence = measuredLBM == nil

        // --- Energy ---
        let bmr = measuredLBM != nil
            ? HealthMath.katchMcArdleBMR(leanBodyMassKg: lbm)
            : HealthMath.mifflinStJeorBMR(
                weightKg: weightKg, heightCm: profile.heightCm,
                age: profile.age(), sex: profile.biologicalSex
              )
        let tdee = bmr * profile.activityLevel.tdeeMultiplier

        var calories: Double
        switch goal.kind {
        case .maintenance:
            calories = tdee
        case .fatLoss, .recomposition:
            // 7700 kcal per kg of fat; deficit clamped to sustainable bounds:
            // never below 80% of BMR, never more than 25% under TDEE.
            let dailyDeficit = goal.weeklyRateKg * 7700 / 7
            calories = max(tdee - dailyDeficit, max(bmr * 0.8, tdee * 0.75))
        }

        // --- Cycle adaptation (compassion allowance, applied silently) ---
        var proteinAdjustment = 0.0
        var waterAdjustment = 0.0
        var sleepHours = 7.5
        if let phase = input.cyclePhase, profile.cycleTrackingEnabled {
            let rec = cycleEngine.recommendation(for: phase)
            calories *= rec.calorieMultiplier
            proteinAdjustment = rec.proteinAdjustmentG
            waterAdjustment = rec.hydrationAdjustmentMl
            if phase == .luteal || phase == .menstrual { sleepHours = 8 }
        }

        // --- Protein from lean body mass, never total weight ---
        let protein = lbm * profile.activityLevel.proteinPerKgLBM + proteinAdjustment

        // --- Fat floor, carbs fill the remainder ---
        let fat = max(0.8 * weightKg, calories * 0.25 / 9)
        let carbs = max((calories - protein * 4 - fat * 9) / 4, 50)

        // --- Fiber: 14 g per 1000 kcal (dietary guideline) ---
        let fiber = calories / 1000 * 14

        // --- Water: 33 ml/kg + phase adjustment ---
        let water = weightKg * 33 + waterAdjustment

        // --- Movement ---
        let steps: Int
        let exerciseMinutes: Int
        switch profile.activityLevel {
        case .sedentary:  steps = 7_000;  exerciseMinutes = 20
        case .light:      steps = 8_000;  exerciseMinutes = 25
        case .moderate:   steps = 9_000;  exerciseMinutes = 30
        case .active:     steps = 10_000; exerciseMinutes = 40
        case .veryActive: steps = 12_000; exerciseMinutes = 50
        }

        return DailyTargets(
            calories: calories.rounded(),
            proteinG: protein.rounded(),
            carbsG: carbs.rounded(),
            fatG: fat.rounded(),
            fiberG: fiber.rounded(),
            waterMl: (water / 50).rounded() * 50,
            steps: steps,
            exerciseMinutes: exerciseMinutes,
            sleepHours: sleepHours,
            isLowConfidence: isLowConfidence
        )
    }
}
