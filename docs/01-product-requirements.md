# Aura — Personal Health Operating System
## Product Requirement Document (PRD)

**Version:** 1.0
**Status:** Approved for implementation
**Platform:** iOS 17+ (SwiftUI, SwiftData)

---

## 1. Product Vision

People don't fail fat-loss journeys because they lack nutritional knowledge.
They fail because **after 30–40 days they lose emotional connection with their goal**.

Aura is not a calorie tracker and not a fitness app. It is a **long-term behavior
change platform** — a Personal Health Operating System — designed to keep users
emotionally engaged, consistent, and identity-driven throughout a fat-loss journey.

Every interaction reinforces:

- **Identity** — "I am the kind of person who takes care of my body."
- **Consistency** — small daily wins over perfection.
- **Long-term thinking** — trends over single days.
- **Intrinsic motivation** — the user's own "why", not external pressure.

**Non-negotiable principles:** never shame, never guilt. Celebrate progress.
A missed day is data, not failure.

Reference experiences: Apple Health (rigor), Gentler Streak (kindness),
Yazio (nutrition depth), Finch (emotional engagement), Notion (personal system),
Pinterest (aspiration boards). The app should feel like something Apple would
build if they focused on sustainable fat loss.

---

## 2. Problem Statement

| Problem | Evidence | Aura's answer |
|---|---|---|
| Motivation decays after ~30–40 days | Churn cliff in every diet app | Motivation Engine: identity artifacts, Dream Wardrobe, milestones |
| Pass/fail tracking punishes imperfection | Streak-break abandonment | Momentum Engine: weighted % scores, never binary |
| Generic targets ignore physiology | Plateau frustration | Goal Engine: LBM-based, cycle-aware, auto-adapting targets |
| Scale weight hides real progress | "I gained a pound" quits | BIA trends + Health Score: muscle preservation surfaced explicitly |
| Female physiology is ignored | Luteal-phase "failures" | Cycle Planner: phase-aware targets and recommendations |

---

## 3. Goals & Success Metrics

### Product goals
1. Users maintain engagement past day 40 (the churn cliff).
2. Users experience daily progress even on imperfect days.
3. Targets adapt automatically — the user never edits a calorie number by hand.

### North-star metric
**D60 retention with ≥4 active days/week.**

### Supporting metrics
- Median Momentum score of active users (target ≥ 70).
- % of users with ≥1 Motivation artifact (Why I Started, Dream Outfit, Letter).
- % of weeks where Health Score explanation is viewed.
- Muscle preservation rate among users losing weight (LBM flat or rising).

### Explicit non-goals (v1)
- Social features, leaderboards, public sharing.
- Meal photo AI, barcode scanning (architecture-ready, not implemented).
- Medical advice or diagnosis. Aura is a wellness product.

---

## 4. Core Modules (v1 scope)

### 4.1 Dashboard
At-a-glance daily command center: Momentum Score, Health Score, Calories
Remaining, Protein Progress, Water Progress, Today's Workout, Today's NEAT,
Current Cycle Phase, Latest BIA Summary, Dream Outfit Card, Daily Motivation.

### 4.2 Nutrition (Calorie Tracking)
Log meals with calories, protein, carbs, fat, fiber; water tracking; meal
history; favorites; recipes. Meal score and macro quality computed by the
Nutrition Engine. Future: AI meal recognition, barcode scanner, restaurant meals.

### 4.3 Dream Wardrobe
A motivational wardrobe board. Users pin outfits, dresses, jeans, jackets,
shoes, accessories into collections with target size, notes, wishlist status,
and fit progress. This is the emotional anchor of the fat-loss goal.

### 4.4 Cycle Planner
Tracks menstrual, follicular, ovulation, and luteal phases. Produces phase-aware
recommendations for workout intensity, recovery, protein, hydration, sleep,
cardio, and strength. Feeds the Goal Engine so targets adapt to the phase.

### 4.5 BIA Tracking
Stores full bioimpedance panels: weight, body fat %, lean body mass, muscle
mass, body water, visceral fat, bone mass, protein %, BMI, basal metabolism,
metabolic age, subcutaneous fat. Renders trend charts designed to show
*composition* progress, not just weight.

### 4.6 Hydration & NEAT
Water, steps, walking, standing, exercise minutes, sedentary time. Generates
intelligent, kind reminders ("You usually drink less water on Mondays —
a glass now keeps your Momentum up").

---

## 5. Core Engines (domain layer)

The app is **architecture-driven**: all intelligence lives in pure, testable
domain engines. UI renders engine output; it never computes.

| Engine | Responsibility | Key rule |
|---|---|---|
| **Goal Engine** | Daily calories, protein, fat, carbs, fiber, water, steps, exercise, sleep targets | Recomputes automatically on any BIA, activity, cycle-phase, or goal change. **No hardcoded targets.** |
| **Nutrition Engine** | Macro targets, meal score, macro quality | Protein from **Lean Body Mass × activity multiplier**, never total weight |
| **Momentum Engine** | Today's behavioral consistency (0–100) | Weighted partial credit per metric — never pass/fail |
| **Health Score Engine** | Physiological health (0–100), daily + weekly | Must **explain why** the score moved |
| **Prediction Engine** | Goal date, projected weight / body-fat / muscle, BIA evolution | Trend-based (EWMA regression over recent data) |
| **Motivation Engine** | Why I Started, Future Me, Letter to Myself, milestones, achievements, transformation timeline, identity builder, quotes | Never guilt; celebration language only |
| **AI Insight Engine** | Personalized pattern insights | Grounded in the user's actual data; template-based v1, LLM-ready |

Momentum vs Health Score: **Momentum measures consistency. Health Score
measures physiology.** Both are surfaced everywhere.

---

## 6. Functional Requirements (summary)

- **FR-1** Onboarding captures: profile (age, height, sex), goal (target weight
  / body fat), activity level, initial BIA (or weight-only fallback), cycle
  tracking opt-in, "Why I Started".
- **FR-2** All targets shown anywhere in the UI come from the Goal Engine.
- **FR-3** Momentum recomputes on every logged event, visible within 100 ms.
- **FR-4** Health Score recomputes daily and rolls up weekly with reasons.
- **FR-5** Every module is functional offline; sync is a background concern.
- **FR-6** Cycle data is optional, private-by-default, and deletable.
- **FR-7** All destructive actions are confirmable and reversible where possible.

## 7. Non-Functional Requirements

- **Offline-first:** SwiftData local store is the source of truth; cloud sync
  is an additive repository decorator (architecture-ready).
- **Performance:** cold start < 1.5 s; dashboard render < 200 ms; 60/120 fps
  animations.
- **Accessibility:** Dynamic Type through XXXL, VoiceOver labels on all scores
  and charts, Reduce Motion honored, WCAG AA contrast in both themes.
- **Privacy:** health data never leaves device in v1; future sync is opt-in
  and end-to-end encrypted.
- **Tone:** every string audited against the "never shame" rule.

## 8. Future Integrations (architecture-ready)

Apple Health / HealthKit, smart scales, Apple Watch, Garmin, Whoop, Oura,
Claude API / ChatGPT (insight generation), Vision AI (meal recognition),
barcode + nutrition APIs. Each maps onto an existing repository or engine
protocol — see `05-architecture.md`.

## 9. Release Plan

| Milestone | Contents |
|---|---|
| M1 | Docs, design system, domain models, engines (this delivery) |
| M2 | Full UI, onboarding, local persistence wiring |
| M3 | HealthKit ingestion, notifications, widgets |
| M4 | Cloud sync, AI insight upgrade (LLM), Vision meal logging |
