import Foundation

// Repository protocols — the only surface the domain and presentation layers
// use to touch persistence. SwiftData implementations live in Data/; future
// HealthKit, smart-scale, CloudKit, and API sources implement or decorate
// these same protocols.

public protocol ProfileRepository: Sendable {
    func currentProfile() async throws -> UserProfile?
    func save(_ profile: UserProfile) async throws
    func activeGoal() async throws -> Goal?
    func save(_ goal: Goal) async throws
}

public protocol BIARepository: Sendable {
    /// Panels ordered oldest → newest.
    func panels(in range: ClosedRange<Date>) async throws -> [BIAPanel]
    func latestPanel() async throws -> BIAPanel?
    func save(_ panel: BIAPanel) async throws
    func delete(id: UUID) async throws
}

public protocol MealRepository: Sendable {
    func entries(on day: Date) async throws -> [MealEntry]
    func entries(in range: ClosedRange<Date>) async throws -> [MealEntry]
    func save(_ entry: MealEntry) async throws
    func delete(id: UUID) async throws
    func favorites() async throws -> [MealEntry]
}

public protocol FoodCatalogRepository: Sendable {
    func search(_ query: String) async throws -> [FoodItem]
    func save(_ item: FoodItem) async throws
    func recipes() async throws -> [Recipe]
    func save(_ recipe: Recipe) async throws
    func deleteRecipe(id: UUID) async throws
}

public protocol WaterRepository: Sendable {
    func entries(on day: Date) async throws -> [WaterEntry]
    func totalMl(on day: Date) async throws -> Double
    func save(_ entry: WaterEntry) async throws
    func delete(id: UUID) async throws
}

public protocol ActivityRepository: Sendable {
    func summary(on day: Date) async throws -> ActivitySummary?
    func summaries(in range: ClosedRange<Date>) async throws -> [ActivitySummary]
    func save(_ summary: ActivitySummary) async throws
}

public protocol SleepRepository: Sendable {
    func entry(on day: Date) async throws -> SleepEntry?
    func entries(in range: ClosedRange<Date>) async throws -> [SleepEntry]
    func save(_ entry: SleepEntry) async throws
}

public protocol CycleRepository: Sendable {
    /// Records ordered oldest → newest.
    func records() async throws -> [CycleRecord]
    func save(_ record: CycleRecord) async throws
    func delete(id: UUID) async throws
}

public protocol WardrobeRepository: Sendable {
    func collections() async throws -> [WardrobeCollection]
    func items(inCollection collectionID: UUID?) async throws -> [WardrobeItem]
    func allItems() async throws -> [WardrobeItem]
    func pinnedItems() async throws -> [WardrobeItem]
    func save(_ collection: WardrobeCollection) async throws
    func save(_ item: WardrobeItem) async throws
    func deleteItem(id: UUID) async throws
    func deleteCollection(id: UUID) async throws
}

public protocol MotivationRepository: Sendable {
    func artifacts(of kind: MotivationArtifactKind?) async throws -> [MotivationArtifact]
    func save(_ artifact: MotivationArtifact) async throws
    func milestones() async throws -> [Milestone]
    func save(_ milestone: Milestone) async throws
    func insights(limit: Int) async throws -> [Insight]
    func save(_ insight: Insight) async throws
}

public protocol SnapshotRepository: Sendable {
    func snapshot(on day: Date) async throws -> DailySnapshot?
    func snapshots(in range: ClosedRange<Date>) async throws -> [DailySnapshot]
    func save(_ snapshot: DailySnapshot) async throws
}
