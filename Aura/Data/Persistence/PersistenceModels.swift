import Foundation
import SwiftData

// SwiftData @Model classes (SchemaV1). These mirror the domain entities 1:1;
// mapping lives in Data/Mappers. Images use external storage; day-scoped
// records are queried by date predicate rather than a parent DayLog row.

@Model
public final class ProfileRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var birthDate: Date
    public var heightCm: Double
    public var biologicalSexRaw: String
    public var activityLevelRaw: String
    public var cycleTrackingEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, name: String, birthDate: Date, heightCm: Double,
                biologicalSexRaw: String, activityLevelRaw: String,
                cycleTrackingEnabled: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.biologicalSexRaw = biologicalSexRaw
        self.activityLevelRaw = activityLevelRaw
        self.cycleTrackingEnabled = cycleTrackingEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class GoalRecord {
    @Attribute(.unique) public var id: UUID
    public var kindRaw: String
    public var targetWeightKg: Double?
    public var targetBodyFatPercent: Double?
    public var weeklyRateKg: Double
    public var startDate: Date
    public var startWeightKg: Double
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, kindRaw: String, targetWeightKg: Double?, targetBodyFatPercent: Double?,
                weeklyRateKg: Double, startDate: Date, startWeightKg: Double,
                isActive: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.kindRaw = kindRaw
        self.targetWeightKg = targetWeightKg
        self.targetBodyFatPercent = targetBodyFatPercent
        self.weeklyRateKg = weeklyRateKg
        self.startDate = startDate
        self.startWeightKg = startWeightKg
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class BIAPanelRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var weightKg: Double
    public var bodyFatPercent: Double?
    public var leanBodyMassKg: Double?
    public var muscleMassKg: Double?
    public var bodyWaterPercent: Double?
    public var visceralFatRating: Double?
    public var boneMassKg: Double?
    public var proteinPercent: Double?
    public var bmi: Double?
    public var basalMetabolismKcal: Double?
    public var metabolicAge: Int?
    public var subcutaneousFatPercent: Double?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, date: Date, weightKg: Double, bodyFatPercent: Double?,
                leanBodyMassKg: Double?, muscleMassKg: Double?, bodyWaterPercent: Double?,
                visceralFatRating: Double?, boneMassKg: Double?, proteinPercent: Double?,
                bmi: Double?, basalMetabolismKcal: Double?, metabolicAge: Int?,
                subcutaneousFatPercent: Double?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.leanBodyMassKg = leanBodyMassKg
        self.muscleMassKg = muscleMassKg
        self.bodyWaterPercent = bodyWaterPercent
        self.visceralFatRating = visceralFatRating
        self.boneMassKg = boneMassKg
        self.proteinPercent = proteinPercent
        self.bmi = bmi
        self.basalMetabolismKcal = basalMetabolismKcal
        self.metabolicAge = metabolicAge
        self.subcutaneousFatPercent = subcutaneousFatPercent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class MealEntryRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var mealTypeRaw: String
    public var foodName: String
    public var servingDescription: String
    public var calories: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var fiberG: Double
    public var isFavorite: Bool
    public var recipeID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, date: Date, mealTypeRaw: String, foodName: String,
                servingDescription: String, calories: Double, proteinG: Double,
                carbsG: Double, fatG: Double, fiberG: Double, isFavorite: Bool,
                recipeID: UUID?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.date = date
        self.mealTypeRaw = mealTypeRaw
        self.foodName = foodName
        self.servingDescription = servingDescription
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.isFavorite = isFavorite
        self.recipeID = recipeID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class FoodItemRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var brand: String?
    public var kcalPer100: Double
    public var proteinPer100: Double
    public var carbsPer100: Double
    public var fatPer100: Double
    public var fiberPer100: Double
    public var barcode: String?
    public var isFavorite: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, name: String, brand: String?, kcalPer100: Double,
                proteinPer100: Double, carbsPer100: Double, fatPer100: Double,
                fiberPer100: Double, barcode: String?, isFavorite: Bool,
                createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.brand = brand
        self.kcalPer100 = kcalPer100
        self.proteinPer100 = proteinPer100
        self.carbsPer100 = carbsPer100
        self.fatPer100 = fatPer100
        self.fiberPer100 = fiberPer100
        self.barcode = barcode
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class RecipeRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    /// JSON-encoded [RecipeIngredient] — ingredients are value data owned by
    /// the recipe, not shared rows.
    public var ingredientsData: Data
    public var servings: Double
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, name: String, ingredientsData: Data, servings: Double,
                notes: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.ingredientsData = ingredientsData
        self.servings = servings
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class WaterEntryRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var amountMl: Double
    public var createdAt: Date

    public init(id: UUID, date: Date, amountMl: Double, createdAt: Date) {
        self.id = id
        self.date = date
        self.amountMl = amountMl
        self.createdAt = createdAt
    }
}

@Model
public final class ActivitySummaryRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var steps: Int
    public var walkingMinutes: Int
    public var standingMinutes: Int
    public var exerciseMinutes: Int
    public var sedentaryMinutes: Int
    public var workoutCompleted: Bool
    public var workoutKindRaw: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, date: Date, steps: Int, walkingMinutes: Int, standingMinutes: Int,
                exerciseMinutes: Int, sedentaryMinutes: Int, workoutCompleted: Bool,
                workoutKindRaw: String?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.date = date
        self.steps = steps
        self.walkingMinutes = walkingMinutes
        self.standingMinutes = standingMinutes
        self.exerciseMinutes = exerciseMinutes
        self.sedentaryMinutes = sedentaryMinutes
        self.workoutCompleted = workoutCompleted
        self.workoutKindRaw = workoutKindRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class SleepEntryRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var hoursSlept: Double
    public var quality: Double?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, date: Date, hoursSlept: Double, quality: Double?,
                createdAt: Date, updatedAt: Date) {
        self.id = id
        self.date = date
        self.hoursSlept = hoursSlept
        self.quality = quality
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class CycleRecordRow {
    @Attribute(.unique) public var id: UUID
    public var periodStartDate: Date
    public var periodEndDate: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, periodStartDate: Date, periodEndDate: Date?,
                createdAt: Date, updatedAt: Date) {
        self.id = id
        self.periodStartDate = periodStartDate
        self.periodEndDate = periodEndDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class WardrobeCollectionRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var emoji: String?
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, name: String, emoji: String?, sortOrder: Int,
                createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class WardrobeItemRecord {
    @Attribute(.unique) public var id: UUID
    public var collectionID: UUID?
    public var title: String
    public var categoryRaw: String
    @Attribute(.externalStorage) public var imageData: Data?
    public var targetSize: String
    public var currentSize: String?
    public var notes: String
    public var isWishlist: Bool
    public var fitStatusRaw: String
    public var pinnedToDashboard: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, collectionID: UUID?, title: String, categoryRaw: String,
                imageData: Data?, targetSize: String, currentSize: String?, notes: String,
                isWishlist: Bool, fitStatusRaw: String, pinnedToDashboard: Bool,
                createdAt: Date, updatedAt: Date) {
        self.id = id
        self.collectionID = collectionID
        self.title = title
        self.categoryRaw = categoryRaw
        self.imageData = imageData
        self.targetSize = targetSize
        self.currentSize = currentSize
        self.notes = notes
        self.isWishlist = isWishlist
        self.fitStatusRaw = fitStatusRaw
        self.pinnedToDashboard = pinnedToDashboard
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class MotivationArtifactRecord {
    @Attribute(.unique) public var id: UUID
    public var kindRaw: String
    public var text: String
    @Attribute(.externalStorage) public var imageData: Data?
    public var deliverAt: Date?
    public var deliveredAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, kindRaw: String, text: String, imageData: Data?,
                deliverAt: Date?, deliveredAt: Date?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.kindRaw = kindRaw
        self.text = text
        self.imageData = imageData
        self.deliverAt = deliverAt
        self.deliveredAt = deliveredAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class MilestoneRecord {
    @Attribute(.unique) public var id: UUID
    public var kindRaw: String
    public var title: String
    public var detail: String
    public var achievedAt: Date

    public init(id: UUID, kindRaw: String, title: String, detail: String, achievedAt: Date) {
        self.id = id
        self.kindRaw = kindRaw
        self.title = title
        self.detail = detail
        self.achievedAt = achievedAt
    }
}

@Model
public final class InsightRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var categoryRaw: String
    public var sentimentRaw: String
    public var message: String
    public var sourceMetricsData: Data
    public var createdAt: Date

    public init(id: UUID, date: Date, categoryRaw: String, sentimentRaw: String,
                message: String, sourceMetricsData: Data, createdAt: Date) {
        self.id = id
        self.date = date
        self.categoryRaw = categoryRaw
        self.sentimentRaw = sentimentRaw
        self.message = message
        self.sourceMetricsData = sourceMetricsData
        self.createdAt = createdAt
    }
}

/// Per-day computed cache. Score structures are value data computed by
/// engines, stored as JSON — they are derived, re-computable state.
@Model
public final class DailySnapshotRecord {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var payload: Data
    public var updatedAt: Date

    public init(id: UUID, date: Date, payload: Data, updatedAt: Date) {
        self.id = id
        self.date = date
        self.payload = payload
        self.updatedAt = updatedAt
    }
}
