import Foundation

/// Projects weight, body fat, and muscle mass forward from recent BIA trends
/// using exponentially weighted regression, and estimates the goal date.
/// Honest about confidence: sparse or noisy data lowers it.
public struct PredictionEngine: Sendable {

    /// How far ahead projections extend when no goal intercept is found.
    public static let horizonWeeks = 16
    /// Slope floor below which we do not extrapolate a goal date (kg/day).
    private static let minMeaningfulSlope = 0.005

    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// - Parameter panels: recent panels, oldest → newest (28-day window recommended).
    public func predict(panels: [BIAPanel], goal: Goal, asOf today: Date = .now) -> Prediction? {
        guard let latest = panels.last else { return nil }
        let daysAndWeights = panels.map { ($0.date.timeIntervalSinceReferenceDate / 86_400, $0.weightKg) }
        let x = daysAndWeights.map(\.0)

        let weightSlope = HealthMath.weightedSlopePerDay(x: x, y: daysAndWeights.map(\.1))
        let bfSeries = panels.compactMap { p in p.bodyFatPercent.map { (p.date.timeIntervalSinceReferenceDate / 86_400, $0) } }
        let bfSlope = bfSeries.count >= 3
            ? HealthMath.weightedSlopePerDay(x: bfSeries.map(\.0), y: bfSeries.map(\.1)) : nil
        let muscleSeries = panels.compactMap { p in (p.muscleMassKg ?? p.resolvedLeanBodyMassKg).map { (p.date.timeIntervalSinceReferenceDate / 86_400, $0) } }
        let muscleSlope = muscleSeries.count >= 3
            ? HealthMath.weightedSlopePerDay(x: muscleSeries.map(\.0), y: muscleSeries.map(\.1)) : nil

        // Fallback slope from the goal's planned rate when trend data is thin.
        let plannedSlope = -goal.weeklyRateKg / 7
        let slope = weightSlope ?? plannedSlope

        // --- Goal date ---
        var goalDate: Date?
        if let targetWeight = goal.targetWeightKg, latest.weightKg > targetWeight,
           slope < -Self.minMeaningfulSlope {
            let days = (targetWeight - latest.weightKg) / slope
            if days > 0, days < 365 * 2 {
                goalDate = calendar.date(byAdding: .day, value: Int(days.rounded()), to: today)
            }
        } else if let targetBF = goal.targetBodyFatPercent, let bf = latest.bodyFatPercent,
                  bf > targetBF, let s = bfSlope, s < -0.001 {
            let days = (targetBF - bf) / s
            if days > 0, days < 365 * 2 {
                goalDate = calendar.date(byAdding: .day, value: Int(days.rounded()), to: today)
            }
        }

        // --- Weekly projected series ---
        let horizonDays: Int
        if let goalDate {
            horizonDays = min(max(calendar.daysBetween(today, goalDate), 7), 365)
        } else {
            horizonDays = Self.horizonWeeks * 7
        }
        var series: [ProjectedPoint] = []
        var week = 0
        while week * 7 <= horizonDays {
            let d = Double(week * 7)
            let date = calendar.date(byAdding: .day, value: week * 7, to: today) ?? today
            var projectedWeight = latest.weightKg + slope * d
            if let target = goal.targetWeightKg { projectedWeight = max(projectedWeight, target) }
            series.append(ProjectedPoint(
                date: date,
                weightKg: projectedWeight,
                bodyFatPercent: latest.bodyFatPercent.flatMap { bf in
                    bfSlope.map { max(bf + $0 * d, goal.targetBodyFatPercent ?? 5) }
                },
                muscleMassKg: (latest.muscleMassKg ?? latest.resolvedLeanBodyMassKg).flatMap { m in
                    muscleSlope.map { m + $0 * d }
                }
            ))
            week += 1
        }

        // --- Confidence: data density and whether a measured trend exists ---
        let confidence: PredictionConfidence
        if panels.count >= 8, weightSlope != nil, bfSlope != nil {
            confidence = .high
        } else if panels.count >= 4, weightSlope != nil {
            confidence = .medium
        } else {
            confidence = .low
        }

        let last = series.last ?? ProjectedPoint(date: today, weightKg: latest.weightKg)
        return Prediction(
            estimatedGoalDate: goalDate,
            projectedWeightKg: last.weightKg,
            projectedBodyFatPercent: last.bodyFatPercent,
            projectedMuscleMassKg: last.muscleMassKg,
            weeklySeries: series,
            confidence: confidence
        )
    }
}
