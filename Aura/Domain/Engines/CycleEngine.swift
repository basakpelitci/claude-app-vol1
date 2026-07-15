import Foundation

/// Derives the current cycle state from period records and produces
/// phase-aware recommendations. Pure and deterministic; consumed by the
/// Goal Engine (target adjustments) and the Cycle Planner UI.
public struct CycleEngine: Sendable {
    public static let defaultCycleLength = 28

    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Current cycle state, or nil when there are no records (feature off or
    /// no data yet). Average cycle length is learned from record spacing.
    public func state(on date: Date, records: [CycleRecord]) -> CycleState? {
        let starts = records.map(\.periodStartDate).sorted()
        guard let lastStart = starts.last(where: { $0 <= date }) else { return nil }

        var length = Self.defaultCycleLength
        if starts.count >= 2 {
            let gaps = zip(starts.dropFirst(), starts).map { calendar.daysBetween($1, $0) }
            let plausible = gaps.filter { (20...45).contains($0) }
            if !plausible.isEmpty {
                length = plausible.reduce(0, +) / plausible.count
            }
        }

        // Day 1 = first day of the period; wrap when past the expected length
        // (late period) rather than inventing a phase beyond luteal.
        let rawDay = calendar.daysBetween(lastStart, date) + 1
        let day = min(rawDay, length)
        return CycleState(phase: phase(forDay: day, cycleLength: length), dayInCycle: day, averageCycleLength: length)
    }

    /// Phase boundaries scale with the learned cycle length: menstrual ≈ first
    /// 5 days, ovulation ≈ 3 days around length−14, luteal after that.
    public func phase(forDay day: Int, cycleLength: Int) -> CyclePhase {
        let ovulationDay = cycleLength - 14
        switch day {
        case ..<6:                                  return .menstrual
        case 6..<(ovulationDay - 1):                return .follicular
        case (ovulationDay - 1)...(ovulationDay + 1): return .ovulation
        default:                                    return .luteal
        }
    }

    /// Recommendations reflect the physiology of each phase; the calorie and
    /// protein adjustments are consumed by the Goal Engine so targets adapt
    /// silently — cravings in the luteal phase are physiology, not weakness.
    public func recommendation(for phase: CyclePhase) -> PhaseRecommendation {
        switch phase {
        case .menstrual:
            return PhaseRecommendation(
                phase: phase,
                workout: "Gentle movement — walking, mobility, light yoga",
                recovery: "Prioritize rest; extra recovery days are productive this week",
                cardioGuidance: "Easy zone-1/2 only, and only if it feels good",
                strengthGuidance: "Light technique work, no maxing",
                sleepFocus: "Aim for 8+ hours; iron-rich meals support energy",
                proteinAdjustmentG: 0,
                hydrationAdjustmentMl: 250,
                calorieMultiplier: 1.0
            )
        case .follicular:
            return PhaseRecommendation(
                phase: phase,
                workout: "Your power window — push strength and new personal bests",
                recovery: "Normal recovery; energy and pain tolerance are highest",
                cardioGuidance: "HIIT and intervals land best in this phase",
                strengthGuidance: "Progressive overload — add weight or reps",
                sleepFocus: "Standard 7.5–8 hours",
                proteinAdjustmentG: 0,
                hydrationAdjustmentMl: 0,
                calorieMultiplier: 1.0
            )
        case .ovulation:
            return PhaseRecommendation(
                phase: phase,
                workout: "Peak strength — great day for a big session",
                recovery: "Warm up thoroughly; ligament laxity is slightly higher",
                cardioGuidance: "Intensity is fine; keep form sharp",
                strengthGuidance: "Strong lifts, extra attention to joints",
                sleepFocus: "Standard 7.5–8 hours",
                proteinAdjustmentG: 0,
                hydrationAdjustmentMl: 0,
                calorieMultiplier: 1.0
            )
        case .luteal:
            return PhaseRecommendation(
                phase: phase,
                workout: "Moderate strength and steady cardio over intensity",
                recovery: "Schedule extra rest; RPE runs higher this week",
                cardioGuidance: "Zone-2 over HIIT — same fat-loss benefit, less strain",
                strengthGuidance: "Maintain loads; don't chase records",
                sleepFocus: "Aim 8+ hours; sleep quality dips are normal now",
                proteinAdjustmentG: 10,
                hydrationAdjustmentMl: 250,
                calorieMultiplier: 1.06
            )
        }
    }
}
