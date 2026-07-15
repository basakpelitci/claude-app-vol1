# Domain Models & Database Schema

Domain entities are pure Swift value types (structs/enums) in `Domain/Entities`.
Persistence uses SwiftData `@Model` classes in `Data/Persistence`, mapped 1:1
by mappers. Every persisted record carries `id: UUID`, `createdAt`, `updatedAt`
(sync-ready).

## 1. Entity map

```
UserProfile 1───1 Goal
UserProfile 1───* BIAPanel
UserProfile 1───* DayLog 1───* MealEntry ─── FoodItem / Recipe
                  DayLog 1───* WaterEntry
                  DayLog 1───1 ActivitySummary (steps/NEAT/exercise)
                  DayLog 1───1 SleepEntry
                  DayLog 1───1 DailySnapshot (computed: momentum, targets…)
UserProfile 1───* CycleRecord (periods) → derived CyclePhase
UserProfile 1───* WardrobeCollection 1───* WardrobeItem
UserProfile 1───* MotivationArtifact (why/futureMe/letter/…)
UserProfile 1───* Milestone / Achievement
UserProfile 1───* Insight
```

## 2. Core entities

### UserProfile
`id, name, birthDate, heightCm, biologicalSex, activityLevel, cycleTrackingEnabled, createdAt, updatedAt`

`ActivityLevel`: `sedentary(1.2) | light(1.375) | moderate(1.55) | active(1.725) | veryActive(1.9)` — TDEE multipliers.

### Goal
`id, kind(fatLoss|maintenance|recomposition), targetWeightKg?, targetBodyFatPercent?, weeklyRateKg (clamped 0.25–0.75), startDate, startWeightKg`

### BIAPanel (full bioimpedance panel)
`id, date, weightKg, bodyFatPercent, leanBodyMassKg, muscleMassKg, bodyWaterPercent, visceralFatRating, boneMassKg, proteinPercent, bmi, basalMetabolismKcal, metabolicAge, subcutaneousFatPercent`
All fields except `date` and `weightKg` optional — supports weight-only scales.

### MealEntry
`id, date, mealType(breakfast|lunch|dinner|snack), foodName, servingDescription, calories, proteinG, carbsG, fatG, fiberG, isFavorite, recipeID?`

### FoodItem (catalog) / Recipe
`FoodItem: id, name, brand?, per100g{kcal,protein,carbs,fat,fiber}, barcode?`
`Recipe: id, name, ingredients: [FoodItem+grams], servings, notes`

### WaterEntry
`id, date, amountMl`

### ActivitySummary (per day — NEAT + exercise)
`id, date, steps, walkingMinutes, standingMinutes, exerciseMinutes, sedentaryMinutes, workoutCompleted, workoutKind?`

### SleepEntry
`id, date, hoursSlept, quality(0–1)?`

### CycleRecord / CyclePhase
`CycleRecord: id, periodStartDate, periodEndDate?`
`CyclePhase` (derived, not stored): `menstrual | follicular | ovulation | luteal`
with `dayInCycle`, computed from recent records + average cycle length.

### WardrobeCollection / WardrobeItem
`WardrobeCollection: id, name, emoji?, sortOrder`
`WardrobeItem: id, collectionID, title, category(outfit|dress|jeans|jacket|shoes|accessory|top|skirt|other), imageData?, targetSize, currentSize?, notes, isWishlist, fitStatus(dream|closer|almostFits|fits), pinnedToDashboard`

### MotivationArtifact
`id, kind(whyIStarted|futureMe|letterToMyself|identityStatement), text, imageData?, createdAt, deliverAt? (letters), deliveredAt?`

### Milestone / Achievement
`Milestone: id, kind, title, achievedAt, detail` (e.g. firstWeekComplete, momentum80Week, muscklePreserved30d, bodyFatMinus1, wardrobeItemFits)
`Achievement`: behavior-based badges (`loggedMeals7Days`, `hydration14Days`, …)

### Insight
`id, date, category(nutrition|hydration|cycle|composition|behavior), message, sentiment(celebration|observation|gentleNudge), sourceMetrics: [String]`

### DailySnapshot (computed cache, persisted per day)
`id, date, targets: DailyTargets, momentum: MomentumScore, healthScore: HealthScore?, caloriesConsumed, proteinG, carbsG, fatG, fiberG, waterMl, steps`

## 3. Engine value types (never persisted as source of truth)

```
DailyTargets   { calories, proteinG, carbsG, fatG, fiberG, waterMl,
                 steps, exerciseMinutes, sleepHours }
MomentumScore  { overall: Int(0–100), components: [MomentumComponent] }
MomentumComponent { metric, score(0–1), weight, detail }
HealthScore    { overall: Int(0–100), factors: [HealthFactor], reasons: [String] }
HealthFactor   { kind, score(0–1), weight, trend(improving|stable|declining), explanation }
Prediction     { goalDate?, projectedWeightKg, projectedBodyFatPercent?,
                 projectedMuscleMassKg?, weeklySeries: [ProjectedPoint], confidence }
PhaseRecommendation { phase, workout, recovery, proteinAdjustment,
                      hydrationAdjustment, sleepFocus, cardioGuidance, strengthGuidance,
                      calorieAdjustment }
```

## 4. SwiftData schema notes

- One `@Model` class per persisted entity above; relationships use SwiftData
  macros with cascade delete from `UserProfile` and `WardrobeCollection`.
- `DayLog` is implicit: day-scoped records are queried by date predicate
  (`#Predicate { $0.date >= startOfDay && $0.date < endOfDay }`) rather than a
  parent row — avoids hot-row contention and keeps writes independent.
- Images (`WardrobeItem.imageData`, artifacts) stored as external-storage
  `Data` attributes (`@Attribute(.externalStorage)`).
- Cycle & health data marked for future per-record encryption; excluded from
  any analytics.
- Migration: schema is versioned (`SchemaV1`); additive changes preferred.

## 5. Key formulas (authoritative)

- **BMR** (Katch-McArdle when LBM known): `370 + 21.6 × LBM(kg)`;
  fallback Mifflin-St Jeor from weight/height/age/sex.
- **TDEE** = BMR × activity multiplier (+ NEAT refinement over time).
- **Calorie target** = TDEE − deficit from `weeklyRateKg` (7700 kcal/kg ÷ 7),
  clamped to ≥ BMR × 0.8 and deficit ≤ 25% of TDEE. Luteal phase: +5%%–8%
  compassion allowance, recomposition-safe.
- **Protein** = **LBM × activity-based multiplier** (1.6–2.4 g/kg LBM);
  never total body weight. Fallback when no BIA: estimated LBM via BMI-based
  body-fat estimate, flagged low-confidence.
- **Water** = 30–35 ml/kg + exercise adjustment (+500 ml/hour) + luteal +250 ml.
- **Momentum** = Σ(componentScore × weight), each component
  `min(actual/target, cap)` with overshoot curves for calories (see engine).
- **Prediction** = exponentially weighted linear regression over last 28 days
  of weight & body-fat series; confidence from data density + residual spread.
