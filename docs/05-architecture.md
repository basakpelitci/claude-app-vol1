# Architecture

Clean Architecture + MVVM + SOLID + Repository Pattern, organized into
feature-first modules over a shared domain core. The domain layer is a pure
Swift target with **zero UI and zero persistence imports** — every engine is
deterministic and unit-testable.

## 1. Layer diagram

```
┌────────────────────────────────────────────────────────────┐
│ Presentation (SwiftUI)                                     │
│   Views · ViewModels (@Observable) · DesignSystem          │
│   — renders engine output; never computes health logic —   │
├────────────────────────────────────────────────────────────┤
│ Domain (pure Swift, no imports beyond Foundation)          │
│   Entities · Engines · Repository *protocols* · UseCases   │
├────────────────────────────────────────────────────────────┤
│ Data                                                       │
│   SwiftData models (@Model) · Repository implementations   │
│   Mappers (Entity ⇄ @Model) · Future: HealthKit, CloudKit, │
│   device SDKs, nutrition APIs — each a repository decorator│
└────────────────────────────────────────────────────────────┘
        Dependency rule: source dependencies point inward.
        Presentation → Domain ← Data. Domain imports nothing.
```

## 2. Folder structure

```
Aura/
├── App/
│   ├── AuraApp.swift               # entry point, ModelContainer
│   ├── AppDependencies.swift       # composition root (DI)
│   └── RootTabView.swift           # 5-tab navigation shell
├── Domain/
│   ├── Entities/                   # value types: BIAPanel, MealEntry, …
│   ├── Engines/                    # Goal, Nutrition, Momentum, HealthScore,
│   │                               # Prediction, Motivation, Insight
│   ├── Repositories/               # protocols only
│   └── Support/                    # shared math (EWMA, clamps, dates)
├── Data/
│   ├── Persistence/                # SwiftData @Model classes + container
│   ├── Repositories/               # SwiftData-backed implementations
│   └── Mappers/                    # @Model ⇄ Entity
├── Features/
│   ├── Today/        (TodayView, TodayViewModel, cards)
│   ├── Nutrition/    (NutritionView, ViewModel, food flows)
│   ├── Body/         (BodyView, trend charts, prediction views)
│   ├── Wardrobe/     (WardrobeView, item detail, collections)
│   ├── Cycle/        (CyclePlannerView, phase recommendations)
│   ├── Motivation/   (WhyIStarted, FutureMe, Letter, Milestones, Timeline)
│   └── Onboarding/   (flow)
├── DesignSystem/
│   ├── Tokens/                     # colors, typography, spacing, motion
│   ├── Components/                 # ScoreRing, GlassCard, ProgressBar, …
│   └── Modifiers/
└── Tests/
    ├── DomainTests/                # engine unit tests (pure, fast)
    └── DataTests/
```

## 3. State management

- **ViewModels** are `@Observable` (Observation framework), one per screen,
  owning screen state and calling use cases/engines. No business math in views.
- **Source of truth:** SwiftData store. ViewModels read via repositories,
  never hold long-lived copies of persisted data.
- **Recompute pipeline:** any write (meal, water, BIA, workout, cycle event)
  flows through `RecalculationCoordinator`, which reruns Goal → Nutrition →
  Momentum (→ HealthScore if day boundary / BIA change) and publishes a fresh
  `DailySnapshot` that all score UI observes. This guarantees FR-2/FR-3
  ("targets never hardcoded", "Momentum visible instantly").
- **Unidirectional flow:** View → intent → ViewModel → UseCase/Repository →
  store → snapshot recompute → View.

## 4. Data flow (example: user logs a meal)

```
NutritionView "Add"
  → NutritionViewModel.log(food, portion)
    → LogMealUseCase → MealRepository.save(entry)          [SwiftData write]
    → RecalculationCoordinator.dayChanged(today)
        GoalEngine.targets(profile, latestBIA, phase, goal)
        NutritionEngine.dayScore(entries, targets)
        MomentumEngine.score(dayMetrics, targets)
        → DailySnapshot published
  ← TodayViewModel & NutritionViewModel observe snapshot → UI animates
```

## 5. Dependency injection

`AppDependencies` is the single composition root: it builds the
`ModelContainer`, concrete repositories, engines (stateless structs), and the
`RecalculationCoordinator`, and injects ViewModels via initializer injection.
No service locators, no singletons; previews and tests build their own
graph with in-memory containers and fixture repositories.

## 6. Offline-first & sync-readiness

- SwiftData local store is authoritative; the app is fully functional with
  no network.
- Every entity carries `id: UUID`, `createdAt`, `updatedAt` for future
  last-write-wins sync. A future `SyncingRepository<R>` decorator wraps any
  local repository — no domain or UI change required.

## 7. Integration-readiness map

| Future integration | Slot it fills |
|---|---|
| HealthKit / Apple Watch / Garmin / Whoop / Oura | alternative `ActivityRepository` / `SleepRepository` sources merged by priority |
| Smart scale | `BIARepository` ingestion source |
| Barcode / nutrition APIs | `FoodCatalogRepository` remote source |
| Vision AI meal recognition | producer of `MealEntry` drafts into the same LogMeal flow |
| Claude API / ChatGPT | `InsightGenerating` protocol — v1 ships a deterministic template implementation; an LLM implementation is a drop-in |

## 8. Testing strategy

- **Engines:** pure functions → exhaustive unit tests (phase adjustments,
  LBM protein math, momentum weighting, prediction regression, clamps).
- **Repositories:** in-memory `ModelContainer` round-trip tests.
- **ViewModels:** fixture repositories, assert published snapshots.
- **Tone tests:** snapshot list of all user-facing motivational strings
  reviewed against the never-shame rule.
