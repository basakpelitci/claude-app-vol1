# Information Architecture & Navigation Flow

## 1. Top-level structure

Five-tab root navigation (Apple HIG). Each tab owns a `NavigationStack`.

```
Aura
├── 1. Today (Dashboard)          ← default tab
├── 2. Nutrition
├── 3. Body (BIA & Trends)
├── 4. Wardrobe (Dream Wardrobe)
└── 5. Me (Motivation, Cycle, Settings)
```

The **Momentum ring** and **Health Score** appear on Today and are reachable
from every tab via the shared score header.

## 2. Screen inventory

### Tab 1 — Today
```
TodayView
├── MomentumRingCard          (tap → MomentumDetailView: per-metric breakdown)
├── HealthScoreCard           (tap → HealthScoreDetailView: reasons list)
├── CaloriesRemainingCard     (tap → Nutrition tab, today)
├── MacroProgressRow          (protein / carbs / fat / fiber)
├── WaterCard                 (inline +250ml quick action)
├── WorkoutCard               (today's recommendation, cycle-aware)
├── NEATCard                  (steps, standing, sedentary)
├── CyclePhaseChip            (tap → CyclePlannerView)
├── BIASummaryCard            (latest panel deltas, tap → Body tab)
├── DreamOutfitCard           (rotating pinned item + fit progress)
└── DailyMotivationCard       (quote / insight of the day)
```

### Tab 2 — Nutrition
```
NutritionView (day pager: ← yesterday | today | tomorrow →)
├── DailySummaryHeader        (remaining calories, macro rings, meal score)
├── MealSections              (breakfast / lunch / dinner / snacks)
│   └── MealEntryRow          (tap → FoodDetailView, swipe → delete/favorite)
├── AddFoodFlow               (search → FoodSearchView → PortionSheet)
│   ├── FavoritesTab
│   ├── RecentTab
│   └── RecipesTab            (RecipeDetailView, RecipeBuilderView)
└── WaterTrackerSection
```

### Tab 3 — Body
```
BodyView
├── LatestPanelCard           (full BIA panel grid)
├── TrendChartsSection        (weight, body fat %, LBM, muscle, water,
│   visceral fat, metabolic age … each tap → MetricTrendDetailView)
├── PredictionCard            (goal date, projected weight/BF%/muscle)
│   └── PredictionDetailView  (projection chart + confidence)
└── AddBIAEntryFlow           (manual panel entry form)
```

### Tab 4 — Wardrobe
```
WardrobeView (Pinterest-style masonry grid)
├── CollectionsBar            (horizontal chips + NewCollectionSheet)
├── WardrobeItemCard          (image, target size, fit-progress badge)
│   └── WardrobeItemDetailView (notes, wishlist, size, "worn it" moment)
└── AddItemFlow               (photo/import → category → target size → notes)
```

### Tab 5 — Me
```
MeView
├── MotivationSection
│   ├── WhyIStartedView
│   ├── FutureMeView
│   ├── LetterToMyselfView    (write + scheduled delivery)
│   ├── MilestonesView
│   ├── AchievementsView
│   ├── TransformationTimelineView
│   └── IdentityBuilderView
├── CyclePlannerView
│   ├── PhaseCalendarView
│   └── PhaseRecommendationsView (workout/recovery/protein/hydration/
│                                 sleep/cardio/strength per phase)
├── HydrationAndNEATSettings  (reminder preferences)
├── GoalSettingsView          (goal, activity level → Goal Engine recompute)
└── SettingsView              (profile, appearance, privacy, data export)
```

### Modal flows (outside tabs)
```
OnboardingFlow    Welcome → WhyIStarted → Profile → Goal → Activity →
                  CycleOptIn → FirstWardrobePin → TargetsReveal
CelebrationOverlay  full-screen milestone/achievement moments
```

## 3. Navigation rules

- Tab bar is always visible except during Onboarding and Celebration overlays.
- Deep links: `aura://today`, `aura://log/water`, `aura://log/meal`,
  `aura://body/add`, `aura://wardrobe/item/{id}` (widget & notification ready).
- Every detail screen is pushed (NavigationStack); every creation flow is a
  sheet with explicit Save/Cancel; destructive actions confirm.
- State restoration: last tab + stack path persisted.

## 4. Information hierarchy principles

1. **Scores before numbers** — Momentum/Health Score lead every context;
   raw calories are secondary detail.
2. **Trends before points** — charts default to 30-day windows; single values
   always render with their delta.
3. **One glance = one answer** — each card answers exactly one question
   ("Am I on track on protein?").
4. **Emotion above data on Today** — Dream Outfit and Daily Motivation are
   above the fold on the dashboard alongside scores.
