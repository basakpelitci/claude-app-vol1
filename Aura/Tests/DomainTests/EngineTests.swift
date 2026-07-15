import XCTest
@testable import Aura

final class HealthMathTests: XCTestCase {

    func testKatchMcArdleBMR() {
        // LBM 47 kg → 370 + 21.6 × 47 = 1385.2
        XCTAssertEqual(HealthMath.katchMcArdleBMR(leanBodyMassKg: 47), 1385.2, accuracy: 0.01)
    }

    func testAdherenceGivesPartialCreditOnOvershoot() {
        // 10% over target should still earn a meaningful score, not zero.
        let score = HealthMath.adherenceWithOvershoot(2200, target: 2000)
        XCTAssertGreaterThan(score, 0.7)
        XCTAssertLessThan(score, 1.0)
    }

    func testAdherenceDoesNotRewardSevereUndereating() {
        XCTAssertLessThan(HealthMath.adherenceWithOvershoot(600, target: 2000), 0.5)
        XCTAssertEqual(HealthMath.adherenceWithOvershoot(1500, target: 2000), 1.0)
    }

    func testWeightedSlopeDetectsDecline() throws {
        let x: [Double] = [0, 7, 14, 21, 28]
        let y: [Double] = [70, 69.5, 69.1, 68.4, 68.0] // ~ -0.07 kg/day... actually -0.071/7
        let slope = try XCTUnwrap(HealthMath.weightedSlopePerDay(x: x, y: y))
        XCTAssertLessThan(slope, 0)
        XCTAssertEqual(slope, -0.072, accuracy: 0.02)
    }

    func testSlopeRequiresThreePoints() {
        XCTAssertNil(HealthMath.weightedSlopePerDay(x: [0, 1], y: [1, 2]))
    }
}

final class GoalEngineTests: XCTestCase {

    private func profile(activity: ActivityLevel = .moderate, cycle: Bool = false) -> UserProfile {
        UserProfile(
            name: "Test", birthDate: Calendar.current.date(byAdding: .year, value: -34, to: .now)!,
            heightCm: 168, biologicalSex: .female, activityLevel: activity,
            cycleTrackingEnabled: cycle
        )
    }

    private let goal = Goal(kind: .fatLoss, targetWeightKg: 62, weeklyRateKg: 0.5, startWeightKg: 70)

    func testProteinIsBasedOnLeanBodyMassNotWeight() {
        let bia = BIAPanel(date: .now, weightKg: 70, bodyFatPercent: 30) // LBM = 49
        let targets = GoalEngine().targets(for: .init(profile: profile(), goal: goal, latestBIA: bia))
        // moderate → 2.0 g/kg LBM → 98 g. Weight-based would be 140 g.
        XCTAssertEqual(targets.proteinG, 98, accuracy: 1)
        XCTAssertFalse(targets.isLowConfidence)
    }

    func testFallbackWithoutBIAIsLowConfidence() {
        let targets = GoalEngine().targets(for: .init(profile: profile(), goal: goal, latestBIA: nil))
        XCTAssertTrue(targets.isLowConfidence)
        XCTAssertGreaterThan(targets.proteinG, 0)
    }

    func testDeficitIsClampedToSustainableBounds() {
        // Even at max rate, calories never fall below 75% of TDEE / 80% of BMR.
        let aggressive = Goal(kind: .fatLoss, targetWeightKg: 50, weeklyRateKg: 0.75, startWeightKg: 60)
        let bia = BIAPanel(date: .now, weightKg: 60, bodyFatPercent: 25)
        let targets = GoalEngine().targets(for: .init(profile: profile(activity: .sedentary), goal: aggressive, latestBIA: bia))
        let lbm = 60 * 0.75
        let bmr = HealthMath.katchMcArdleBMR(leanBodyMassKg: lbm)
        XCTAssertGreaterThanOrEqual(targets.calories, bmr * 0.8 - 1)
    }

    func testLutealPhaseRaisesCaloriesAndProtein() {
        let bia = BIAPanel(date: .now, weightKg: 70, bodyFatPercent: 30)
        let engine = GoalEngine()
        let base = engine.targets(for: .init(profile: profile(cycle: true), goal: goal, latestBIA: bia, cyclePhase: .follicular))
        let luteal = engine.targets(for: .init(profile: profile(cycle: true), goal: goal, latestBIA: bia, cyclePhase: .luteal))
        XCTAssertGreaterThan(luteal.calories, base.calories)
        XCTAssertEqual(luteal.proteinG - base.proteinG, 10, accuracy: 1)
        XCTAssertGreaterThan(luteal.waterMl, base.waterMl)
    }

    func testTargetsIgnoreCycleWhenTrackingDisabled() {
        let bia = BIAPanel(date: .now, weightKg: 70, bodyFatPercent: 30)
        let engine = GoalEngine()
        let off = engine.targets(for: .init(profile: profile(cycle: false), goal: goal, latestBIA: bia, cyclePhase: .luteal))
        let none = engine.targets(for: .init(profile: profile(cycle: false), goal: goal, latestBIA: bia, cyclePhase: nil))
        XCTAssertEqual(off.calories, none.calories)
    }
}

final class MomentumEngineTests: XCTestCase {

    private var targets: DailyTargets {
        DailyTargets(calories: 1800, proteinG: 100, carbsG: 180, fatG: 60, fiberG: 25,
                     waterMl: 2300, steps: 9000, exerciseMinutes: 30, sleepHours: 7.5)
    }

    func testPartialCreditNeverPassFail() {
        let metrics = DayMetrics(
            date: .now, caloriesConsumed: 1750, proteinG: 94, waterMl: 1900,
            mealTimes: [], activity: nil, sleep: nil
        )
        let score = MomentumEngine().score(metrics: metrics, targets: targets)
        // Water at 82% contributes 0.82 of its weight — not zero.
        let water = score.components.first { $0.metric == .water }
        XCTAssertEqual(water?.score ?? 0, 1900.0 / 2300.0, accuracy: 0.01)
        XCTAssertGreaterThan(score.overall, 80)
    }

    func testAbsentMetricsAreExcludedAndWeightsRenormalized() {
        let metrics = DayMetrics(date: .now, caloriesConsumed: 1800, proteinG: 100, waterMl: 2300)
        let score = MomentumEngine().score(metrics: metrics, targets: targets)
        // Perfect on all present metrics → 100 even without sleep/activity data.
        XCTAssertEqual(score.overall, 100)
        XCTAssertFalse(score.components.contains { $0.metric == .sleep })
        XCTAssertFalse(score.components.contains { $0.metric == .habits })
        let totalWeight = score.components.reduce(0) { $0 + $1.weight }
        XCTAssertEqual(totalWeight, 1.0, accuracy: 0.001)
    }

    func testEmptyDayHasKindHeadline() {
        let score = MomentumEngine().score(metrics: DayMetrics(date: .now), targets: targets)
        // No shame vocabulary in any headline.
        for banned in ["fail", "bad", "guilt", "cheat", "behind", "ruined"] {
            XCTAssertFalse(score.headline.lowercased().contains(banned))
        }
    }
}

final class NutritionEngineTests: XCTestCase {

    func testGradeNeverFallsBelowC() {
        let targets = DailyTargets(calories: 1800, proteinG: 100, carbsG: 180, fatG: 60, fiberG: 25,
                                   waterMl: 2300, steps: 9000, exerciseMinutes: 30, sleepHours: 7.5)
        let score = NutritionEngine().score(entries: [], targets: targets)
        XCTAssertEqual(score.grade, "C")
    }

    func testProteinForwardDayScoresWell() {
        let targets = DailyTargets(calories: 1800, proteinG: 100, carbsG: 180, fatG: 60, fiberG: 25,
                                   waterMl: 2300, steps: 9000, exerciseMinutes: 30, sleepHours: 7.5)
        let entries = [
            MealEntry(date: .now, mealType: .breakfast, foodName: "A", calories: 600, proteinG: 35, carbsG: 60, fatG: 18, fiberG: 9),
            MealEntry(date: .now, mealType: .lunch, foodName: "B", calories: 600, proteinG: 35, carbsG: 60, fatG: 18, fiberG: 9),
            MealEntry(date: .now, mealType: .dinner, foodName: "C", calories: 600, proteinG: 30, carbsG: 60, fatG: 20, fiberG: 8),
        ]
        let score = NutritionEngine().score(entries: entries, targets: targets)
        XCTAssertGreaterThan(score.overall, 0.85)
        XCTAssertTrue(["A", "A+"].contains(score.grade))
    }
}

final class CycleEngineTests: XCTestCase {

    func testPhasesForDefaultCycle() {
        let engine = CycleEngine()
        XCTAssertEqual(engine.phase(forDay: 2, cycleLength: 28), .menstrual)
        XCTAssertEqual(engine.phase(forDay: 9, cycleLength: 28), .follicular)
        XCTAssertEqual(engine.phase(forDay: 14, cycleLength: 28), .ovulation)
        XCTAssertEqual(engine.phase(forDay: 22, cycleLength: 28), .luteal)
    }

    func testStateLearnsCycleLengthFromRecords() throws {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // Two 30-day cycles.
        let records = [
            CycleRecord(periodStartDate: cal.date(byAdding: .day, value: -70, to: today)!),
            CycleRecord(periodStartDate: cal.date(byAdding: .day, value: -40, to: today)!),
            CycleRecord(periodStartDate: cal.date(byAdding: .day, value: -10, to: today)!),
        ]
        let state = try XCTUnwrap(CycleEngine().state(on: today, records: records))
        XCTAssertEqual(state.averageCycleLength, 30)
        XCTAssertEqual(state.dayInCycle, 11)
        XCTAssertEqual(state.phase, .follicular)
    }

    func testNoRecordsMeansNoState() {
        XCTAssertNil(CycleEngine().state(on: .now, records: []))
    }
}

final class PredictionEngineTests: XCTestCase {

    private func panels(weights: [Double], daysApart: Int = 4) -> [BIAPanel] {
        let cal = Calendar.current
        return weights.enumerated().map { i, w in
            BIAPanel(
                date: cal.date(byAdding: .day, value: -(weights.count - 1 - i) * daysApart, to: .now)!,
                weightKg: w, bodyFatPercent: 30 - Double(i) * 0.3
            )
        }
    }

    func testDecliningTrendYieldsGoalDate() throws {
        let goal = Goal(kind: .fatLoss, targetWeightKg: 65, weeklyRateKg: 0.5, startWeightKg: 70)
        let prediction = try XCTUnwrap(
            PredictionEngine().predict(panels: panels(weights: [70, 69.6, 69.1, 68.8, 68.3, 68.0]), goal: goal)
        )
        XCTAssertNotNil(prediction.estimatedGoalDate)
        XCTAssertGreaterThan(prediction.estimatedGoalDate!, .now)
        XCTAssertFalse(prediction.weeklySeries.isEmpty)
        // Projection never overshoots below the target.
        XCTAssertGreaterThanOrEqual(prediction.projectedWeightKg, 65 - 0.001)
    }

    func testSparseDataLowersConfidence() throws {
        let goal = Goal(kind: .fatLoss, targetWeightKg: 65, weeklyRateKg: 0.5, startWeightKg: 70)
        let sparse = try XCTUnwrap(PredictionEngine().predict(panels: panels(weights: [70, 69.5]), goal: goal))
        XCTAssertEqual(sparse.confidence, .low)
        let dense = try XCTUnwrap(
            PredictionEngine().predict(panels: panels(weights: [70, 69.7, 69.5, 69.2, 69.0, 68.7, 68.5, 68.2], daysApart: 3), goal: goal)
        )
        XCTAssertEqual(dense.confidence, .high)
    }

    func testNoPanelsMeansNoPrediction() {
        let goal = Goal(kind: .fatLoss, targetWeightKg: 65, weeklyRateKg: 0.5, startWeightKg: 70)
        XCTAssertNil(PredictionEngine().predict(panels: [], goal: goal))
    }
}

final class HealthScoreEngineTests: XCTestCase {

    private var targets: DailyTargets {
        DailyTargets(calories: 1800, proteinG: 100, carbsG: 180, fatG: 60, fiberG: 25,
                     waterMl: 2300, steps: 9000, exerciseMinutes: 30, sleepHours: 7.5)
    }

    func testScoreAlwaysExplainsWhy() {
        let cal = Calendar.current
        let panels = (0..<5).map { i in
            BIAPanel(date: cal.date(byAdding: .day, value: -12 + i * 3, to: .now)!,
                     weightKg: 70 - Double(i) * 0.3,
                     bodyFatPercent: 30 - Double(i) * 0.25,
                     muscleMassKg: 26.0 + Double(i) * 0.02)
        }
        let days = (0..<7).map { i in
            (metrics: DayMetrics(date: cal.date(byAdding: .day, value: -6 + i, to: .now)!,
                                 caloriesConsumed: 1750, proteinG: 95, fatG: 55, fiberG: 22,
                                 waterMl: 2200, sleep: SleepEntry(date: .now, hoursSlept: 7.2)),
             targets: targets)
        }
        let score = HealthScoreEngine().score(.init(panels: panels, days: days))
        XCTAssertGreaterThan(score.overall, 70)
        XCTAssertFalse(score.reasons.isEmpty)
        XCTAssertTrue(score.factors.contains { $0.kind == .musclePreservation })
        XCTAssertTrue(score.factors.contains { $0.kind == .bodyFatTrend })
    }

    func testNoDataProducesGentleZeroState() {
        let score = HealthScoreEngine().score(.init(panels: [], days: []))
        XCTAssertEqual(score.overall, 0)
        XCTAssertFalse(score.reasons.isEmpty)
    }
}

final class MotivationEngineTests: XCTestCase {

    func testMilestonesFireOnceAndCelebrateBehavior() {
        let cal = Calendar.current
        let goal = Goal(kind: .fatLoss, targetWeightKg: 62,
                        startDate: cal.date(byAdding: .day, value: -10, to: .now)!,
                        startWeightKg: 70)
        let targets = DailyTargets(calories: 1800, proteinG: 100, carbsG: 180, fatG: 60, fiberG: 25,
                                   waterMl: 2300, steps: 9000, exerciseMinutes: 30, sleepHours: 7.5)
        let snapshots = (0..<8).map { i in
            DailySnapshot(
                date: cal.date(byAdding: .day, value: -7 + i, to: .now)!,
                targets: targets,
                momentum: MomentumScore(overall: 85, components: [], headline: ""),
                metrics: DayMetrics(date: .now)
            )
        }
        let input = MotivationEngine.Input(
            goal: goal, panels: [], snapshots: snapshots,
            wardrobeItems: [], existingMilestones: []
        )
        let engine = MotivationEngine()
        let first = engine.newMilestones(input)
        XCTAssertTrue(first.contains { $0.kind == .firstWeekComplete })
        XCTAssertTrue(first.contains { $0.kind == .momentum80Week })

        // Same input with milestones recorded → nothing fires twice.
        let second = engine.newMilestones(.init(
            goal: goal, panels: [], snapshots: snapshots,
            wardrobeItems: [], existingMilestones: first
        ))
        XCTAssertFalse(second.contains { $0.kind == .firstWeekComplete })
    }

    func testNoShameVocabularyAnywhere() {
        let banned = ["cheat", "fail", "guilt", "punish", "behind", "ruined", "sin ", "bad "]
        for quote in MotivationEngine.consistencyQuotes {
            for word in banned {
                XCTAssertFalse(quote.lowercased().contains(word), "Banned word '\(word)' in: \(quote)")
            }
        }
    }
}

final class InsightEngineTests: XCTestCase {

    func testProteinImprovementInsight() {
        let cal = Calendar.current
        let targets = DailyTargets(calories: 1800, proteinG: 100, carbsG: 180, fatG: 60, fiberG: 25,
                                   waterMl: 2300, steps: 9000, exerciseMinutes: 30, sleepHours: 7.5)
        // Last week 80 g/day, this week 95 g/day → ~19% improvement.
        let snapshots = (0..<14).map { i in
            DailySnapshot(
                date: cal.date(byAdding: .day, value: -13 + i, to: .now)!,
                targets: targets,
                momentum: MomentumScore(overall: 70, components: [], headline: ""),
                metrics: DayMetrics(date: .now, proteinG: i < 7 ? 80 : 95, waterMl: 2000)
            )
        }
        let insights = InsightEngine().insights(from: snapshots, cycleRecords: [], asOf: .now)
        XCTAssertTrue(insights.contains { $0.category == .nutrition && $0.sentiment == .celebration })
    }

    func testTooLittleDataMeansNoInsights() {
        XCTAssertTrue(InsightEngine().insights(from: [], cycleRecords: [], asOf: .now).isEmpty)
    }
}
