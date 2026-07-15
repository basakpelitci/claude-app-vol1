import Foundation

/// The emotional core: detects newly earned milestones, builds identity
/// statements from real behavior, selects daily motivation, and unlocks
/// scheduled letters. All copy celebrates — guilt is a banned pattern.
public struct MotivationEngine: Sendable {

    public struct Input: Sendable {
        public var goal: Goal
        public var panels: [BIAPanel]                 // oldest → newest
        public var snapshots: [DailySnapshot]         // oldest → newest
        public var wardrobeItems: [WardrobeItem]
        public var existingMilestones: [Milestone]
        public var today: Date

        public init(
            goal: Goal,
            panels: [BIAPanel],
            snapshots: [DailySnapshot],
            wardrobeItems: [WardrobeItem],
            existingMilestones: [Milestone],
            today: Date = .now
        ) {
            self.goal = goal
            self.panels = panels
            self.snapshots = snapshots
            self.wardrobeItems = wardrobeItems
            self.existingMilestones = existingMilestones
            self.today = today
        }
    }

    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: - Milestones

    /// Milestones earned but not yet recorded. Each kind fires once.
    public func newMilestones(_ input: Input) -> [Milestone] {
        let earned = Set(input.existingMilestones.map(\.kind))
        var found: [Milestone] = []

        func award(_ kind: MilestoneKind, _ title: String, _ detail: String) {
            guard !earned.contains(kind) else { return }
            found.append(Milestone(kind: kind, title: title, detail: detail, achievedAt: input.today))
        }

        let activeDays = input.snapshots.count
        let journeyDays = calendar.daysBetween(input.goal.startDate, input.today)

        if activeDays >= 7 {
            award(.firstWeekComplete, "First week complete", "Seven days of showing up. The habit is forming.")
        }
        if journeyDays >= 30, activeDays >= 20 {
            award(.thirtyDaysActive, "30 days in", "A month of consistency. You are becoming that person.")
        }

        // Momentum ≥ 80 average over the last 7 snapshots.
        let recent = input.snapshots.suffix(7)
        if recent.count == 7 {
            let avg = recent.map { Double($0.momentum.overall) }.reduce(0, +) / 7
            if avg >= 80 {
                award(.momentum80Week, "A week of high momentum", "Averaging \(Int(avg)) momentum for seven straight days.")
            }
        }

        // Composition milestones.
        if let first = input.panels.first, let latest = input.panels.last, input.panels.count >= 3 {
            if let bf0 = first.bodyFatPercent, let bf1 = latest.bodyFatPercent, bf0 - bf1 >= 1 {
                award(.bodyFatDown1Percent, "Body fat down a full point",
                      String(format: "From %.1f%% to %.1f%% — real composition change.", bf0, bf1))
            }
            if let m0 = first.resolvedLeanBodyMassKg, let m1 = latest.resolvedLeanBodyMassKg,
               m1 >= m0 - 0.2, calendar.daysBetween(first.date, latest.date) >= 30 {
                award(.musclePreserved30Days, "Muscle preserved",
                      "Thirty days of fat loss without losing muscle. Textbook.")
            }
            if let target = input.goal.targetWeightKg {
                let halfway = input.goal.startWeightKg - (input.goal.startWeightKg - target) / 2
                if latest.weightKg <= halfway, input.goal.startWeightKg > target {
                    award(.halfwayToGoal, "Halfway there", "You've covered half the distance to your goal.")
                }
                if latest.weightKg <= target {
                    award(.goalReached, "Goal reached", "You did the thing. Take a moment — then we celebrate properly.")
                }
            }
        }

        // Wardrobe milestones.
        if input.wardrobeItems.contains(where: { $0.fitStatus == .fits }) {
            award(.wardrobeItemFits, "It fits!", "A dream wardrobe item fits. This is what the journey was for.")
        } else if input.wardrobeItems.contains(where: { $0.fitStatus == .almostFits || $0.fitStatus == .closer }) {
            award(.wardrobeItemCloser, "Getting closer", "A dream item is closer to fitting than when you started.")
        }

        return found
    }

    // MARK: - Identity

    /// Identity statements derived from actual behavior ("I am someone
    /// who…"), the strongest known driver of long-term adherence.
    public func identityStatements(_ input: Input) -> [String] {
        var statements: [String] = []
        let recent = input.snapshots.suffix(28)

        let workoutDays = recent.filter { $0.metrics.activity?.workoutCompleted == true }.count
        if workoutDays >= 8 {
            statements.append("I am someone who trains \(max(workoutDays / 4, 2))× a week.")
        }
        let proteinDays = recent.filter { $0.metrics.proteinG >= $0.targets.proteinG * 0.9 }.count
        if proteinDays >= 14 {
            statements.append("I am someone who fuels my body with protein.")
        }
        let waterDays = recent.filter { $0.metrics.waterMl >= $0.targets.waterMl * 0.9 }.count
        if waterDays >= 14 {
            statements.append("I am someone who stays hydrated.")
        }
        if recent.count >= 21 {
            statements.append("I am someone who shows up, even on hard days.")
        }
        return statements
    }

    // MARK: - Daily motivation

    /// Deterministic per-day pick so the card is stable all day.
    public func dailyMotivation(_ input: Input, whyIStarted: String?) -> String {
        var pool = Self.consistencyQuotes
        if let why = whyIStarted, !why.isEmpty,
           calendar.daysBetween(input.goal.startDate, input.today) % 7 == 0 {
            // Weekly, resurface their own words — stronger than any quote.
            return "Remember why you started: “\(why)”"
        }
        if let recent = input.snapshots.last, recent.momentum.overall >= 85 {
            pool += ["Yesterday's momentum was \(recent.momentum.overall). Carry it forward."]
        }
        let day = calendar.ordinality(of: .day, in: .era, for: input.today) ?? 0
        return pool[day % pool.count]
    }

    /// Letters due for delivery today.
    public func lettersToDeliver(_ artifacts: [MotivationArtifact], today: Date = .now) -> [MotivationArtifact] {
        artifacts.filter {
            $0.kind == .letterToMyself && $0.deliveredAt == nil
                && ($0.deliverAt.map { $0 <= today } ?? false)
        }
    }

    static let consistencyQuotes: [String] = [
        "Consistency beats intensity. Every single time.",
        "You don't have to be perfect. You have to be present.",
        "Small daily wins compound into a different life.",
        "The scale measures mass. It cannot measure momentum.",
        "You are one good decision away from a good day.",
        "Six months from now, you'll be glad you kept going today.",
        "Progress hides in weeks, not days. Zoom out.",
        "The person you're becoming is built on days like this.",
        "Rest is part of the plan, not a break from it.",
        "Strong is a practice, not a destination.",
    ]
}
