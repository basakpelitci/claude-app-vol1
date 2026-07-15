import Foundation

/// Generates personalized, data-grounded insights ("Your protein intake
/// improved 12% this week", "You usually drink less water on Mondays").
/// v1 is deterministic template logic behind `InsightGenerating`, so a
/// Claude-API-backed implementation is a drop-in replacement later.
public protocol InsightGenerating: Sendable {
    func insights(from snapshots: [DailySnapshot], cycleRecords: [CycleRecord], asOf today: Date) -> [Insight]
}

public struct InsightEngine: InsightGenerating, Sendable {

    private let calendar: Calendar
    private let cycleEngine: CycleEngine

    public init(calendar: Calendar = .current, cycleEngine: CycleEngine = CycleEngine()) {
        self.calendar = calendar
        self.cycleEngine = cycleEngine
    }

    /// - Parameter snapshots: oldest → newest, ideally 28 days.
    public func insights(from snapshots: [DailySnapshot], cycleRecords: [CycleRecord], asOf today: Date = .now) -> [Insight] {
        var results: [Insight] = []
        guard snapshots.count >= 7 else { return results }

        let thisWeek = Array(snapshots.suffix(7))
        let lastWeek = Array(snapshots.dropLast(7).suffix(7))

        // --- Week-over-week protein change ---
        if lastWeek.count == 7 {
            let prev = lastWeek.map(\.metrics.proteinG).reduce(0, +) / 7
            let curr = thisWeek.map(\.metrics.proteinG).reduce(0, +) / 7
            if prev > 0 {
                let change = (curr - prev) / prev * 100
                if change >= 8 {
                    results.append(Insight(
                        date: today, category: .nutrition, sentiment: .celebration,
                        message: "Your protein intake improved \(Int(change.rounded()))% this week.",
                        sourceMetrics: ["proteinG.7dAvg"]
                    ))
                } else if change <= -15 {
                    results.append(Insight(
                        date: today, category: .nutrition, sentiment: .gentleNudge,
                        message: "Protein dipped \(Int(abs(change).rounded()))% this week — it protects your muscle while you lose fat.",
                        sourceMetrics: ["proteinG.7dAvg"]
                    ))
                }
            }
        }

        // --- Weekday hydration pattern ("you drink less water on Mondays") ---
        if snapshots.count >= 21 {
            var byWeekday: [Int: [Double]] = [:]
            for s in snapshots {
                let ratio = HealthMath.attainment(s.metrics.waterMl, target: s.targets.waterMl)
                byWeekday[calendar.component(.weekday, from: s.date), default: []].append(ratio)
            }
            let averages = byWeekday.compactMapValues { $0.isEmpty ? nil : $0.reduce(0, +) / Double($0.count) }
            if averages.count >= 5,
               let (weakDay, weakAvg) = averages.min(by: { $0.value < $1.value }) {
                let overall = averages.values.reduce(0, +) / Double(averages.count)
                if overall - weakAvg > 0.15, weakAvg < 0.8 {
                    let name = calendar.weekdaySymbols[weakDay - 1]
                    results.append(Insight(
                        date: today, category: .hydration, sentiment: .observation,
                        message: "You consistently drink less water on \(name)s. A bottle on your desk that morning usually fixes this.",
                        sourceMetrics: ["waterMl.byWeekday"]
                    ))
                }
            }
        }

        // --- Pre-menstrual craving pattern ---
        if !cycleRecords.isEmpty {
            var lateLutealCalorieRatios: [Double] = []
            var otherRatios: [Double] = []
            for s in snapshots {
                guard let state = cycleEngine.state(on: s.date, records: cycleRecords) else { continue }
                let ratio = s.targets.calories > 0 ? s.metrics.caloriesConsumed / s.targets.calories : 0
                let daysToNext = state.averageCycleLength - state.dayInCycle
                if state.phase == .luteal, daysToNext <= 3 {
                    lateLutealCalorieRatios.append(ratio)
                } else {
                    otherRatios.append(ratio)
                }
            }
            if lateLutealCalorieRatios.count >= 2, otherRatios.count >= 7 {
                let lateAvg = lateLutealCalorieRatios.reduce(0, +) / Double(lateLutealCalorieRatios.count)
                let baseAvg = otherRatios.reduce(0, +) / Double(otherRatios.count)
                if lateAvg - baseAvg > 0.12 {
                    results.append(Insight(
                        date: today, category: .cycle, sentiment: .observation,
                        message: "You usually crave more food in the days before your period. That's physiology — your targets already adapt for it.",
                        sourceMetrics: ["calories.byCyclePhase"]
                    ))
                }
            }
        }

        // --- Momentum consistency celebration ---
        let highDays = thisWeek.filter { $0.momentum.overall >= 75 }.count
        if highDays >= 5 {
            results.append(Insight(
                date: today, category: .behavior, sentiment: .celebration,
                message: "Five or more strong days this week. This is what sustainable looks like.",
                sourceMetrics: ["momentum.overall.7d"]
            ))
        }

        return results
    }
}
