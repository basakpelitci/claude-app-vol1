import Foundation
import SwiftData

/// Versioned schema and container factory. Additive changes go into a new
/// `SchemaVn` with a migration plan; the store stays local (offline-first).
public enum AuraSchemaV1 {
    public static var models: [any PersistentModel.Type] {
        [
            ProfileRecord.self,
            GoalRecord.self,
            BIAPanelRecord.self,
            MealEntryRecord.self,
            FoodItemRecord.self,
            RecipeRecord.self,
            WaterEntryRecord.self,
            ActivitySummaryRecord.self,
            SleepEntryRecord.self,
            CycleRecordRow.self,
            WardrobeCollectionRecord.self,
            WardrobeItemRecord.self,
            MotivationArtifactRecord.self,
            MilestoneRecord.self,
            InsightRecord.self,
            DailySnapshotRecord.self,
        ]
    }
}

public enum PersistenceContainer {
    /// The on-device store used by the app.
    public static func live() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(AuraSchemaV1.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        )
    }

    /// In-memory store for previews and tests.
    public static func ephemeral() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(AuraSchemaV1.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
