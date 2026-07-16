import Foundation

public enum MotivationArtifactKind: String, Codable, CaseIterable, Sendable {
    case whyIStarted
    case futureMe
    case letterToMyself
    case identityStatement
}

/// The user's own words about their journey — the emotional root of the app.
public struct MotivationArtifact: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var kind: MotivationArtifactKind
    public var text: String
    public var imageData: Data?
    /// For letters: when the letter unlocks. Nil for other kinds.
    public var deliverAt: Date?
    public var deliveredAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        kind: MotivationArtifactKind,
        text: String,
        imageData: Data? = nil,
        deliverAt: Date? = nil,
        deliveredAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.imageData = imageData
        self.deliverAt = deliverAt
        self.deliveredAt = deliveredAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Milestones celebrate journey events (behavior and composition — never
/// framed as weight alone).
public enum MilestoneKind: String, Codable, CaseIterable, Sendable {
    case firstWeekComplete
    case thirtyDaysActive
    case momentum80Week
    case musclePreserved30Days
    case bodyFatDown1Percent
    case wardrobeItemCloser
    case wardrobeItemFits
    case hydrationStreak14
    case firstBIAImprovement
    case halfwayToGoal
    case goalReached
}

public struct Milestone: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var kind: MilestoneKind
    public var title: String
    public var detail: String
    public var achievedAt: Date

    public init(
        id: UUID = UUID(),
        kind: MilestoneKind,
        title: String,
        detail: String,
        achievedAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.achievedAt = achievedAt
    }
}

public enum InsightCategory: String, Codable, CaseIterable, Sendable {
    case nutrition
    case hydration
    case cycle
    case composition
    case behavior
}

public enum InsightSentiment: String, Codable, CaseIterable, Sendable {
    case celebration
    case observation
    case gentleNudge
}

/// A personalized, data-grounded insight. `sourceMetrics` names the inputs
/// that justify the message so it is always explainable.
public struct Insight: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var date: Date
    public var category: InsightCategory
    public var sentiment: InsightSentiment
    public var message: String
    public var sourceMetrics: [String]

    public init(
        id: UUID = UUID(),
        date: Date = .now,
        category: InsightCategory,
        sentiment: InsightSentiment,
        message: String,
        sourceMetrics: [String] = []
    ) {
        self.id = id
        self.date = date
        self.category = category
        self.sentiment = sentiment
        self.message = message
        self.sourceMetrics = sourceMetrics
    }
}
