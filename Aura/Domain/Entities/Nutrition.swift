import Foundation

public enum MealType: String, Codable, CaseIterable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack
}

/// One logged food, meal, or recipe serving.
public struct MealEntry: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var date: Date
    public var mealType: MealType
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

    public init(
        id: UUID = UUID(),
        date: Date,
        mealType: MealType,
        foodName: String,
        servingDescription: String = "",
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        fiberG: Double = 0,
        isFavorite: Bool = false,
        recipeID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.mealType = mealType
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

/// Macro values per 100 g, the canonical catalog unit.
public struct MacroProfile: Equatable, Codable, Sendable {
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var fiberG: Double

    public init(kcal: Double, proteinG: Double, carbsG: Double, fatG: Double, fiberG: Double = 0) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
    }

    public func scaled(grams: Double) -> MacroProfile {
        let f = grams / 100
        return MacroProfile(
            kcal: kcal * f, proteinG: proteinG * f, carbsG: carbsG * f,
            fatG: fatG * f, fiberG: fiberG * f
        )
    }
}

/// Catalog food. `barcode` reserves the slot for the future scanner.
public struct FoodItem: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var brand: String?
    public var per100g: MacroProfile
    public var barcode: String?
    public var isFavorite: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        per100g: MacroProfile,
        barcode: String? = nil,
        isFavorite: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.per100g = per100g
        self.barcode = barcode
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct RecipeIngredient: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var foodItemID: UUID
    public var name: String
    public var grams: Double
    public var per100g: MacroProfile

    public init(id: UUID = UUID(), foodItemID: UUID, name: String, grams: Double, per100g: MacroProfile) {
        self.id = id
        self.foodItemID = foodItemID
        self.name = name
        self.grams = grams
        self.per100g = per100g
    }
}

public struct Recipe: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var ingredients: [RecipeIngredient]
    public var servings: Double
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        ingredients: [RecipeIngredient] = [],
        servings: Double = 1,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.ingredients = ingredients
        self.servings = max(servings, 1)
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Macros for one serving of the finished recipe.
    public var perServing: MacroProfile {
        let total = ingredients.reduce(MacroProfile(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0)) { acc, ing in
            let m = ing.per100g.scaled(grams: ing.grams)
            return MacroProfile(
                kcal: acc.kcal + m.kcal,
                proteinG: acc.proteinG + m.proteinG,
                carbsG: acc.carbsG + m.carbsG,
                fatG: acc.fatG + m.fatG,
                fiberG: acc.fiberG + m.fiberG
            )
        }
        return MacroProfile(
            kcal: total.kcal / servings,
            proteinG: total.proteinG / servings,
            carbsG: total.carbsG / servings,
            fatG: total.fatG / servings,
            fiberG: total.fiberG / servings
        )
    }
}

public struct WaterEntry: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var date: Date
    public var amountMl: Double
    public var createdAt: Date

    public init(id: UUID = UUID(), date: Date, amountMl: Double, createdAt: Date = .now) {
        self.id = id
        self.date = date
        self.amountMl = amountMl
        self.createdAt = createdAt
    }
}
