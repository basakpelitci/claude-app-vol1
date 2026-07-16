import Foundation
import SwiftData

/// SwiftData-backed implementation of every repository protocol, isolated on
/// its own model actor so persistence work stays off the main thread. The
/// future cloud sync layer decorates this store; HealthKit/device sources
/// merge into the same protocols.
@ModelActor
public actor LocalStore {

    private func dayRange(for day: Date) -> (Date, Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }
}

// MARK: - ProfileRepository

extension LocalStore: ProfileRepository {
    public func currentProfile() async throws -> UserProfile? {
        try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first?.toEntity()
    }

    public func save(_ profile: UserProfile) async throws {
        if let existing = try fetchByID(ProfileRecord.self, profile.id) {
            existing.apply(profile)
        } else {
            modelContext.insert(ProfileRecord(profile))
        }
        try modelContext.save()
    }

    public func activeGoal() async throws -> Goal? {
        var d = FetchDescriptor<GoalRecord>(predicate: #Predicate { $0.isActive })
        d.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return try modelContext.fetch(d).first?.toEntity()
    }

    public func save(_ goal: Goal) async throws {
        if let existing = try fetchByID(GoalRecord.self, goal.id) {
            existing.apply(goal)
        } else {
            // A newly saved goal becomes the active one.
            for record in try modelContext.fetch(FetchDescriptor<GoalRecord>()) {
                record.isActive = false
            }
            modelContext.insert(GoalRecord(goal, isActive: true))
        }
        try modelContext.save()
    }
}

// MARK: - BIARepository

extension LocalStore: BIARepository {
    public func panels(in range: ClosedRange<Date>) async throws -> [BIAPanel] {
        let (lo, hi) = (range.lowerBound, range.upperBound)
        var d = FetchDescriptor<BIAPanelRecord>(predicate: #Predicate { $0.date >= lo && $0.date <= hi })
        d.sortBy = [SortDescriptor(\.date)]
        return try modelContext.fetch(d).map { $0.toEntity() }
    }

    public func latestPanel() async throws -> BIAPanel? {
        var d = FetchDescriptor<BIAPanelRecord>()
        d.sortBy = [SortDescriptor(\.date, order: .reverse)]
        d.fetchLimit = 1
        return try modelContext.fetch(d).first?.toEntity()
    }

    public func save(_ panel: BIAPanel) async throws {
        if let existing = try fetchByID(BIAPanelRecord.self, panel.id) {
            modelContext.delete(existing)
        }
        modelContext.insert(BIAPanelRecord(panel))
        try modelContext.save()
    }

    public func delete(id: UUID) async throws {
        if let record = try fetchByID(BIAPanelRecord.self, id) {
            modelContext.delete(record)
            try modelContext.save()
        }
    }
}

// MARK: - MealRepository

extension LocalStore: MealRepository {
    public func entries(on day: Date) async throws -> [MealEntry] {
        let (start, end) = dayRange(for: day)
        var d = FetchDescriptor<MealEntryRecord>(predicate: #Predicate { $0.date >= start && $0.date < end })
        d.sortBy = [SortDescriptor(\.date)]
        return try modelContext.fetch(d).map { $0.toEntity() }
    }

    public func entries(in range: ClosedRange<Date>) async throws -> [MealEntry] {
        let (lo, hi) = (range.lowerBound, range.upperBound)
        var d = FetchDescriptor<MealEntryRecord>(predicate: #Predicate { $0.date >= lo && $0.date <= hi })
        d.sortBy = [SortDescriptor(\.date)]
        return try modelContext.fetch(d).map { $0.toEntity() }
    }

    public func save(_ entry: MealEntry) async throws {
        if let existing = try fetchByID(MealEntryRecord.self, entry.id) {
            existing.apply(entry)
        } else {
            modelContext.insert(MealEntryRecord(entry))
        }
        try modelContext.save()
    }

    public func delete(id: UUID) async throws {
        if let record = try fetchByID(MealEntryRecord.self, id) {
            modelContext.delete(record)
            try modelContext.save()
        }
    }

    public func favorites() async throws -> [MealEntry] {
        var d = FetchDescriptor<MealEntryRecord>(predicate: #Predicate { $0.isFavorite })
        d.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        return try modelContext.fetch(d).map { $0.toEntity() }
    }
}

// MARK: - FoodCatalogRepository

extension LocalStore: FoodCatalogRepository {
    public func search(_ query: String) async throws -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        var d: FetchDescriptor<FoodItemRecord>
        if trimmed.isEmpty {
            d = FetchDescriptor<FoodItemRecord>()
        } else {
            d = FetchDescriptor<FoodItemRecord>(
                predicate: #Predicate { $0.name.localizedStandardContains(trimmed) }
            )
        }
        d.sortBy = [SortDescriptor(\.name)]
        d.fetchLimit = 50
        return try modelContext.fetch(d).map { $0.toEntity() }
    }

    public func save(_ item: FoodItem) async throws {
        if let existing = try fetchByID(FoodItemRecord.self, item.id) {
            modelContext.delete(existing)
        }
        modelContext.insert(FoodItemRecord(item))
        try modelContext.save()
    }

    public func recipes() async throws -> [Recipe] {
        var d = FetchDescriptor<RecipeRecord>()
        d.sortBy = [SortDescriptor(\.name)]
        return try modelContext.fetch(d).compactMap { try? $0.toEntity() }
    }

    public func save(_ recipe: Recipe) async throws {
        if let existing = try fetchByID(RecipeRecord.self, recipe.id) {
            modelContext.delete(existing)
        }
        modelContext.insert(try RecipeRecord(recipe))
        try modelContext.save()
    }

    public func deleteRecipe(id: UUID) async throws {
        if let record = try fetchByID(RecipeRecord.self, id) {
            modelContext.delete(record)
            try modelContext.save()
        }
    }
}

// MARK: - WaterRepository

extension LocalStore: WaterRepository {
    public func entries(on day: Date) async throws -> [WaterEntry] {
        let (start, end) = dayRange(for: day)
        var d = FetchDescriptor<WaterEntryRecord>(predicate: #Predicate { $0.date >= start && $0.date < end })
        d.sortBy = [SortDescriptor(\.date)]
        return try modelContext.fetch(d).map { $0.toEntity() }
    }

    public func totalMl(on day: Date) async throws -> Double {
        try await entries(on: day).reduce(0) { $0 + $1.amountMl }
    }

    public func save(_ entry: WaterEntry) async throws {
        modelContext.insert(WaterEntryRecord(entry))
        try modelContext.save()
    }

    public func delete(id: UUID) async throws {
        if let record = try fetchByID(WaterEntryRecord.self, id) {
            modelContext.delete(record)
            try modelContext.save()
        }
    }
}

// MARK: - ActivityRepository

extension LocalStore: ActivityRepository {
    public func summary(on day: Date) async throws -> ActivitySummary? {
        let (start, end) = dayRange(for: day)
        let d = FetchDescriptor<ActivitySummaryRecord>(predicate: #Predicate { $0.date >= start && $0.date < end })
        return try modelContext.fetch(d).first?.toEntity()
    }

    public func summaries(in range: ClosedRange<Date>) async throws -> [ActivitySummary] {
        let (lo, hi) = (range.lowerBound, range.upperBound)
        var d = FetchDescriptor<ActivitySummaryRecord>(predicate: #Predicate { $0.date >= lo && $0.date <= hi })
        d.sortBy = [SortDescriptor(\.date)]
        return try modelContext.fetch(d).map { $0.toEntity() }
    }

    public func save(_ summary: ActivitySummary) async throws {
        // One row per day: update in place if a row for that day exists.
        let (start, end) = dayRange(for: summary.date)
        let d = FetchDescriptor<ActivitySummaryRecord>(predicate: #Predicate { $0.date >= start && $0.date < end })
        if let existing = try modelContext.fetch(d).first {
            existing.apply(summary)
        } else {
            modelContext.insert(ActivitySummaryRecord(summary))
        }
        try modelContext.save()
    }
}

// MARK: - SleepRepository

extension LocalStore: SleepRepository {
    public func entry(on day: Date) async throws -> SleepEntry? {
        let (start, end) = dayRange(for: day)
        let d = FetchDescriptor<SleepEntryRecord>(predicate: #Predicate { $0.date >= start && $0.date < end })
        return try modelContext.fetch(d).first?.toEntity()
    }

    public func entries(in range: ClosedRange<Date>) async throws -> [SleepEntry] {
        let (lo, hi) = (range.lowerBound, range.upperBound)
        var d = FetchDescriptor<SleepEntryRecord>(predicate: #Predicate { $0.date >= lo && $0.date <= hi })
        d.sortBy = [SortDescriptor(\.date)]
        return try modelContext.fetch(d).map { $0.toEntity() }
    }

    public func save(_ entry: SleepEntry) async throws {
        let (start, end) = dayRange(for: entry.date)
        let d = FetchDescriptor<SleepEntryRecord>(predicate: #Predicate { $0.date >= start && $0.date < end })
        if let existing = try modelContext.fetch(d).first {
            existing.hoursSlept = entry.hoursSlept
            existing.quality = entry.quality
            existing.updatedAt = .now
        } else {
            modelContext.insert(SleepEntryRecord(entry))
        }
        try modelContext.save()
    }
}

// MARK: - CycleRepository

extension LocalStore: CycleRepository {
    public func records() async throws -> [CycleRecord] {
        var d = FetchDescriptor<CycleRecordRow>()
        d.sortBy = [SortDescriptor(\.periodStartDate)]
        return try modelContext.fetch(d).map { $0.toEntity() }
    }

    public func save(_ record: CycleRecord) async throws {
        if let existing = try fetchByID(CycleRecordRow.self, record.id) {
            existing.periodStartDate = record.periodStartDate
            existing.periodEndDate = record.periodEndDate
            existing.updatedAt = .now
        } else {
            modelContext.insert(CycleRecordRow(record))
        }
        try modelContext.save()
    }

    public func delete(id: UUID) async throws {
        if let record = try fetchByID(CycleRecordRow.self, id) {
            modelContext.delete(record)
            try modelContext.save()
        }
    }
}

// MARK: - WardrobeRepository

extension LocalStore: WardrobeRepository {
    public func collections() async throws -> [WardrobeCollection] {
        var d = FetchDescriptor<WardrobeCollectionRecord>()
        d.sortBy = [SortDescriptor(\.sortOrder)]
        return try modelContext.fetch(d).map { $0.toEntity() }
    }

    public func items(inCollection collectionID: UUID?) async throws -> [WardrobeItem] {
        let all = try await allItems()
        guard let collectionID else { return all }
        return all.filter { $0.collectionID == collectionID }
    }

    public func allItems() async throws -> [WardrobeItem] {
        var d = FetchDescriptor<WardrobeItemRecord>()
        d.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return try modelContext.fetch(d).map { $0.toEntity() }
    }

    public func pinnedItems() async throws -> [WardrobeItem] {
        let d = FetchDescriptor<WardrobeItemRecord>(predicate: #Predicate { $0.pinnedToDashboard })
        return try modelContext.fetch(d).map { $0.toEntity() }
    }

    public func save(_ collection: WardrobeCollection) async throws {
        if let existing = try fetchByID(WardrobeCollectionRecord.self, collection.id) {
            existing.name = collection.name
            existing.emoji = collection.emoji
            existing.sortOrder = collection.sortOrder
            existing.updatedAt = .now
        } else {
            modelContext.insert(WardrobeCollectionRecord(collection))
        }
        try modelContext.save()
    }

    public func save(_ item: WardrobeItem) async throws {
        if let existing = try fetchByID(WardrobeItemRecord.self, item.id) {
            existing.apply(item)
        } else {
            modelContext.insert(WardrobeItemRecord(item))
        }
        try modelContext.save()
    }

    public func deleteItem(id: UUID) async throws {
        if let record = try fetchByID(WardrobeItemRecord.self, id) {
            modelContext.delete(record)
            try modelContext.save()
        }
    }

    public func deleteCollection(id: UUID) async throws {
        // Items in a deleted collection survive as uncollected.
        for item in try modelContext.fetch(FetchDescriptor<WardrobeItemRecord>()) where item.collectionID == id {
            item.collectionID = nil
        }
        if let record = try fetchByID(WardrobeCollectionRecord.self, id) {
            modelContext.delete(record)
        }
        try modelContext.save()
    }
}

// MARK: - MotivationRepository

extension LocalStore: MotivationRepository {
    public func artifacts(of kind: MotivationArtifactKind?) async throws -> [MotivationArtifact] {
        var d = FetchDescriptor<MotivationArtifactRecord>()
        d.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        let all = try modelContext.fetch(d).map { $0.toEntity() }
        guard let kind else { return all }
        return all.filter { $0.kind == kind }
    }

    public func save(_ artifact: MotivationArtifact) async throws {
        if let existing = try fetchByID(MotivationArtifactRecord.self, artifact.id) {
            existing.apply(artifact)
        } else {
            modelContext.insert(MotivationArtifactRecord(artifact))
        }
        try modelContext.save()
    }

    public func milestones() async throws -> [Milestone] {
        var d = FetchDescriptor<MilestoneRecord>()
        d.sortBy = [SortDescriptor(\.achievedAt, order: .reverse)]
        return try modelContext.fetch(d).map { $0.toEntity() }
    }

    public func save(_ milestone: Milestone) async throws {
        modelContext.insert(MilestoneRecord(milestone))
        try modelContext.save()
    }

    public func insights(limit: Int) async throws -> [Insight] {
        var d = FetchDescriptor<InsightRecord>()
        d.sortBy = [SortDescriptor(\.date, order: .reverse)]
        d.fetchLimit = limit
        return try modelContext.fetch(d).map { $0.toEntity() }
    }

    public func save(_ insight: Insight) async throws {
        modelContext.insert(InsightRecord(insight))
        try modelContext.save()
    }
}

// MARK: - SnapshotRepository

extension LocalStore: SnapshotRepository {
    public func snapshot(on day: Date) async throws -> DailySnapshot? {
        let (start, end) = dayRange(for: day)
        let d = FetchDescriptor<DailySnapshotRecord>(predicate: #Predicate { $0.date >= start && $0.date < end })
        return try modelContext.fetch(d).first.flatMap { try? $0.toEntity() }
    }

    public func snapshots(in range: ClosedRange<Date>) async throws -> [DailySnapshot] {
        let (lo, hi) = (range.lowerBound, range.upperBound)
        var d = FetchDescriptor<DailySnapshotRecord>(predicate: #Predicate { $0.date >= lo && $0.date <= hi })
        d.sortBy = [SortDescriptor(\.date)]
        return try modelContext.fetch(d).compactMap { try? $0.toEntity() }
    }

    public func save(_ snapshot: DailySnapshot) async throws {
        // One snapshot per day, replaced wholesale (derived, re-computable).
        let (start, end) = dayRange(for: snapshot.date)
        let d = FetchDescriptor<DailySnapshotRecord>(predicate: #Predicate { $0.date >= start && $0.date < end })
        for existing in try modelContext.fetch(d) {
            modelContext.delete(existing)
        }
        modelContext.insert(try DailySnapshotRecord(snapshot))
        try modelContext.save()
    }
}

// MARK: - Shared helpers

private extension LocalStore {
    /// In-memory ID lookup: #Predicate cannot be built over a generic model
    /// type, and per-user data volumes here are small enough that a table
    /// scan is cheaper than sixteen concrete fetch helpers.
    func fetchByID<T: PersistentModel & Identifiable>(_ type: T.Type, _ id: UUID) throws -> T? where T.ID == UUID {
        try modelContext.fetch(FetchDescriptor<T>()).first { $0.id == id }
    }
}
