import Foundation

// Record ⇄ Entity mapping. Records are persistence detail; entities are the
// only currency above the Data layer.

extension ProfileRecord {
    func toEntity() -> UserProfile {
        UserProfile(
            id: id, name: name, birthDate: birthDate, heightCm: heightCm,
            biologicalSex: BiologicalSex(rawValue: biologicalSexRaw) ?? .unspecified,
            activityLevel: ActivityLevel(rawValue: activityLevelRaw) ?? .moderate,
            cycleTrackingEnabled: cycleTrackingEnabled,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }

    func apply(_ e: UserProfile) {
        name = e.name
        birthDate = e.birthDate
        heightCm = e.heightCm
        biologicalSexRaw = e.biologicalSex.rawValue
        activityLevelRaw = e.activityLevel.rawValue
        cycleTrackingEnabled = e.cycleTrackingEnabled
        updatedAt = .now
    }

    convenience init(_ e: UserProfile) {
        self.init(
            id: e.id, name: e.name, birthDate: e.birthDate, heightCm: e.heightCm,
            biologicalSexRaw: e.biologicalSex.rawValue,
            activityLevelRaw: e.activityLevel.rawValue,
            cycleTrackingEnabled: e.cycleTrackingEnabled,
            createdAt: e.createdAt, updatedAt: e.updatedAt
        )
    }
}

extension GoalRecord {
    func toEntity() -> Goal {
        Goal(
            id: id, kind: GoalKind(rawValue: kindRaw) ?? .fatLoss,
            targetWeightKg: targetWeightKg, targetBodyFatPercent: targetBodyFatPercent,
            weeklyRateKg: weeklyRateKg, startDate: startDate, startWeightKg: startWeightKg,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }

    func apply(_ e: Goal) {
        kindRaw = e.kind.rawValue
        targetWeightKg = e.targetWeightKg
        targetBodyFatPercent = e.targetBodyFatPercent
        weeklyRateKg = e.weeklyRateKg
        startDate = e.startDate
        startWeightKg = e.startWeightKg
        updatedAt = .now
    }

    convenience init(_ e: Goal, isActive: Bool = true) {
        self.init(
            id: e.id, kindRaw: e.kind.rawValue, targetWeightKg: e.targetWeightKg,
            targetBodyFatPercent: e.targetBodyFatPercent, weeklyRateKg: e.weeklyRateKg,
            startDate: e.startDate, startWeightKg: e.startWeightKg,
            isActive: isActive, createdAt: e.createdAt, updatedAt: e.updatedAt
        )
    }
}

extension BIAPanelRecord {
    func toEntity() -> BIAPanel {
        BIAPanel(
            id: id, date: date, weightKg: weightKg, bodyFatPercent: bodyFatPercent,
            leanBodyMassKg: leanBodyMassKg, muscleMassKg: muscleMassKg,
            bodyWaterPercent: bodyWaterPercent, visceralFatRating: visceralFatRating,
            boneMassKg: boneMassKg, proteinPercent: proteinPercent, bmi: bmi,
            basalMetabolismKcal: basalMetabolismKcal, metabolicAge: metabolicAge,
            subcutaneousFatPercent: subcutaneousFatPercent,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }

    convenience init(_ e: BIAPanel) {
        self.init(
            id: e.id, date: e.date, weightKg: e.weightKg, bodyFatPercent: e.bodyFatPercent,
            leanBodyMassKg: e.leanBodyMassKg, muscleMassKg: e.muscleMassKg,
            bodyWaterPercent: e.bodyWaterPercent, visceralFatRating: e.visceralFatRating,
            boneMassKg: e.boneMassKg, proteinPercent: e.proteinPercent, bmi: e.bmi,
            basalMetabolismKcal: e.basalMetabolismKcal, metabolicAge: e.metabolicAge,
            subcutaneousFatPercent: e.subcutaneousFatPercent,
            createdAt: e.createdAt, updatedAt: e.updatedAt
        )
    }
}

extension MealEntryRecord {
    func toEntity() -> MealEntry {
        MealEntry(
            id: id, date: date, mealType: MealType(rawValue: mealTypeRaw) ?? .snack,
            foodName: foodName, servingDescription: servingDescription,
            calories: calories, proteinG: proteinG, carbsG: carbsG, fatG: fatG,
            fiberG: fiberG, isFavorite: isFavorite, recipeID: recipeID,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }

    func apply(_ e: MealEntry) {
        date = e.date
        mealTypeRaw = e.mealType.rawValue
        foodName = e.foodName
        servingDescription = e.servingDescription
        calories = e.calories
        proteinG = e.proteinG
        carbsG = e.carbsG
        fatG = e.fatG
        fiberG = e.fiberG
        isFavorite = e.isFavorite
        recipeID = e.recipeID
        updatedAt = .now
    }

    convenience init(_ e: MealEntry) {
        self.init(
            id: e.id, date: e.date, mealTypeRaw: e.mealType.rawValue, foodName: e.foodName,
            servingDescription: e.servingDescription, calories: e.calories,
            proteinG: e.proteinG, carbsG: e.carbsG, fatG: e.fatG, fiberG: e.fiberG,
            isFavorite: e.isFavorite, recipeID: e.recipeID,
            createdAt: e.createdAt, updatedAt: e.updatedAt
        )
    }
}

extension FoodItemRecord {
    func toEntity() -> FoodItem {
        FoodItem(
            id: id, name: name, brand: brand,
            per100g: MacroProfile(kcal: kcalPer100, proteinG: proteinPer100,
                                  carbsG: carbsPer100, fatG: fatPer100, fiberG: fiberPer100),
            barcode: barcode, isFavorite: isFavorite,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }

    convenience init(_ e: FoodItem) {
        self.init(
            id: e.id, name: e.name, brand: e.brand, kcalPer100: e.per100g.kcal,
            proteinPer100: e.per100g.proteinG, carbsPer100: e.per100g.carbsG,
            fatPer100: e.per100g.fatG, fiberPer100: e.per100g.fiberG,
            barcode: e.barcode, isFavorite: e.isFavorite,
            createdAt: e.createdAt, updatedAt: e.updatedAt
        )
    }
}

extension RecipeRecord {
    func toEntity() throws -> Recipe {
        Recipe(
            id: id, name: name,
            ingredients: try JSONDecoder().decode([RecipeIngredient].self, from: ingredientsData),
            servings: servings, notes: notes, createdAt: createdAt, updatedAt: updatedAt
        )
    }

    convenience init(_ e: Recipe) throws {
        self.init(
            id: e.id, name: e.name,
            ingredientsData: try JSONEncoder().encode(e.ingredients),
            servings: e.servings, notes: e.notes,
            createdAt: e.createdAt, updatedAt: e.updatedAt
        )
    }
}

extension WaterEntryRecord {
    func toEntity() -> WaterEntry {
        WaterEntry(id: id, date: date, amountMl: amountMl, createdAt: createdAt)
    }

    convenience init(_ e: WaterEntry) {
        self.init(id: e.id, date: e.date, amountMl: e.amountMl, createdAt: e.createdAt)
    }
}

extension ActivitySummaryRecord {
    func toEntity() -> ActivitySummary {
        ActivitySummary(
            id: id, date: date, steps: steps, walkingMinutes: walkingMinutes,
            standingMinutes: standingMinutes, exerciseMinutes: exerciseMinutes,
            sedentaryMinutes: sedentaryMinutes, workoutCompleted: workoutCompleted,
            workoutKind: workoutKindRaw.flatMap(WorkoutKind.init(rawValue:)),
            createdAt: createdAt, updatedAt: updatedAt
        )
    }

    func apply(_ e: ActivitySummary) {
        steps = e.steps
        walkingMinutes = e.walkingMinutes
        standingMinutes = e.standingMinutes
        exerciseMinutes = e.exerciseMinutes
        sedentaryMinutes = e.sedentaryMinutes
        workoutCompleted = e.workoutCompleted
        workoutKindRaw = e.workoutKind?.rawValue
        updatedAt = .now
    }

    convenience init(_ e: ActivitySummary) {
        self.init(
            id: e.id, date: e.date, steps: e.steps, walkingMinutes: e.walkingMinutes,
            standingMinutes: e.standingMinutes, exerciseMinutes: e.exerciseMinutes,
            sedentaryMinutes: e.sedentaryMinutes, workoutCompleted: e.workoutCompleted,
            workoutKindRaw: e.workoutKind?.rawValue,
            createdAt: e.createdAt, updatedAt: e.updatedAt
        )
    }
}

extension SleepEntryRecord {
    func toEntity() -> SleepEntry {
        SleepEntry(id: id, date: date, hoursSlept: hoursSlept, quality: quality,
                   createdAt: createdAt, updatedAt: updatedAt)
    }

    convenience init(_ e: SleepEntry) {
        self.init(id: e.id, date: e.date, hoursSlept: e.hoursSlept, quality: e.quality,
                  createdAt: e.createdAt, updatedAt: e.updatedAt)
    }
}

extension CycleRecordRow {
    func toEntity() -> CycleRecord {
        CycleRecord(id: id, periodStartDate: periodStartDate, periodEndDate: periodEndDate,
                    createdAt: createdAt, updatedAt: updatedAt)
    }

    convenience init(_ e: CycleRecord) {
        self.init(id: e.id, periodStartDate: e.periodStartDate, periodEndDate: e.periodEndDate,
                  createdAt: e.createdAt, updatedAt: e.updatedAt)
    }
}

extension WardrobeCollectionRecord {
    func toEntity() -> WardrobeCollection {
        WardrobeCollection(id: id, name: name, emoji: emoji, sortOrder: sortOrder,
                           createdAt: createdAt, updatedAt: updatedAt)
    }

    convenience init(_ e: WardrobeCollection) {
        self.init(id: e.id, name: e.name, emoji: e.emoji, sortOrder: e.sortOrder,
                  createdAt: e.createdAt, updatedAt: e.updatedAt)
    }
}

extension WardrobeItemRecord {
    func toEntity() -> WardrobeItem {
        WardrobeItem(
            id: id, collectionID: collectionID, title: title,
            category: WardrobeCategory(rawValue: categoryRaw) ?? .other,
            imageData: imageData, targetSize: targetSize, currentSize: currentSize,
            notes: notes, isWishlist: isWishlist,
            fitStatus: FitStatus(rawValue: fitStatusRaw) ?? .dream,
            pinnedToDashboard: pinnedToDashboard,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }

    func apply(_ e: WardrobeItem) {
        collectionID = e.collectionID
        title = e.title
        categoryRaw = e.category.rawValue
        imageData = e.imageData
        targetSize = e.targetSize
        currentSize = e.currentSize
        notes = e.notes
        isWishlist = e.isWishlist
        fitStatusRaw = e.fitStatus.rawValue
        pinnedToDashboard = e.pinnedToDashboard
        updatedAt = .now
    }

    convenience init(_ e: WardrobeItem) {
        self.init(
            id: e.id, collectionID: e.collectionID, title: e.title,
            categoryRaw: e.category.rawValue, imageData: e.imageData,
            targetSize: e.targetSize, currentSize: e.currentSize, notes: e.notes,
            isWishlist: e.isWishlist, fitStatusRaw: e.fitStatus.rawValue,
            pinnedToDashboard: e.pinnedToDashboard,
            createdAt: e.createdAt, updatedAt: e.updatedAt
        )
    }
}

extension MotivationArtifactRecord {
    func toEntity() -> MotivationArtifact {
        MotivationArtifact(
            id: id, kind: MotivationArtifactKind(rawValue: kindRaw) ?? .whyIStarted,
            text: text, imageData: imageData, deliverAt: deliverAt, deliveredAt: deliveredAt,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }

    func apply(_ e: MotivationArtifact) {
        kindRaw = e.kind.rawValue
        text = e.text
        imageData = e.imageData
        deliverAt = e.deliverAt
        deliveredAt = e.deliveredAt
        updatedAt = .now
    }

    convenience init(_ e: MotivationArtifact) {
        self.init(
            id: e.id, kindRaw: e.kind.rawValue, text: e.text, imageData: e.imageData,
            deliverAt: e.deliverAt, deliveredAt: e.deliveredAt,
            createdAt: e.createdAt, updatedAt: e.updatedAt
        )
    }
}

extension MilestoneRecord {
    func toEntity() -> Milestone {
        Milestone(id: id, kind: MilestoneKind(rawValue: kindRaw) ?? .firstWeekComplete,
                  title: title, detail: detail, achievedAt: achievedAt)
    }

    convenience init(_ e: Milestone) {
        self.init(id: e.id, kindRaw: e.kind.rawValue, title: e.title,
                  detail: e.detail, achievedAt: e.achievedAt)
    }
}

extension InsightRecord {
    func toEntity() -> Insight {
        Insight(
            id: id, date: date,
            category: InsightCategory(rawValue: categoryRaw) ?? .behavior,
            sentiment: InsightSentiment(rawValue: sentimentRaw) ?? .observation,
            message: message,
            sourceMetrics: (try? JSONDecoder().decode([String].self, from: sourceMetricsData)) ?? []
        )
    }

    convenience init(_ e: Insight) {
        self.init(
            id: e.id, date: e.date, categoryRaw: e.category.rawValue,
            sentimentRaw: e.sentiment.rawValue, message: e.message,
            sourceMetricsData: (try? JSONEncoder().encode(e.sourceMetrics)) ?? Data(),
            createdAt: .now
        )
    }
}

extension DailySnapshotRecord {
    func toEntity() throws -> DailySnapshot {
        try JSONDecoder().decode(DailySnapshot.self, from: payload)
    }

    convenience init(_ e: DailySnapshot) throws {
        self.init(id: e.id, date: e.date, payload: try JSONEncoder().encode(e), updatedAt: .now)
    }
}
