# Aura — Interactive HTML Prototype

A browser-testable mirror of the SwiftUI app: Tailwind CSS + vanilla
JavaScript, no build step. Use it to validate UX flows before compiling the
native application.

## Run

```bash
# from the repo root — any static server works
cd prototype && python3 -m http.server 8080
# open http://localhost:8080
```

Opening `index.html` directly from disk also works in most browsers
(Tailwind loads from its CDN, so you need network access either way).

State persists in `localStorage`. On first launch you get the onboarding
flow; tap **"or explore with demo data"** on the welcome screen (or
Me → Prototype data) to load a rich fixture — "Elif", day 32 of her journey,
with 30 days of meals/water/activity/sleep, 8 BIA panels, cycle records, and
a wardrobe — so every screen has meaningful data to test against.

## Fidelity to SwiftUI

- **Design tokens** are copied from `Aura/DesignSystem/Tokens/AuraTheme.swift`
  into CSS variables (`index.html`): identical light/dark hex palettes,
  4-pt spacing, 24 px card radius, glass cards, spring-like easing curves,
  Reduce Motion support via `prefers-reduced-motion`.
- **Engines** are ported 1:1 in `js/engines.js` from `Aura/Domain/Engines/`
  (Goal, Momentum, Nutrition, Cycle, Health Score, Prediction, Motivation) —
  the scores you see in the browser are the scores the native app computes.
- **Dark mode** follows the OS (`prefers-color-scheme`), same as SwiftUI.
- The phone frame is a 390×844 canvas on desktop and full-screen on mobile.

## Screen map (SwiftUI ⇄ prototype)

| SwiftUI | Prototype | Interactions to test |
|---|---|---|
| `OnboardingView` | onboarding flow (7 steps) | why-first capture, pace slider, activity picker, cycle opt-in, live targets reveal |
| `RootTabView` | tab bar + view stack | tab switching, push/pop, celebration overlay |
| `TodayView` | Today tab | animated score rings, +250 ml quick add, phase chip → cycle, dream-outfit card |
| `MomentumDetailView` | Today → Momentum | per-metric partial-credit breakdown |
| `HealthScoreDetailView` | Today → Health | reasons list, factor trends |
| `NutritionView` + `AddFoodSheet` | Nutrition tab | day pager, catalog search, favorites, manual entry, delete/favorite, water buttons, meal score grade |
| `BodyView` + `AddBIAEntrySheet` | Body tab | full panel grid, weight/body-fat/muscle trend charts, prediction card, measurement entry |
| `WardrobeView` / item detail / form | Wardrobe tab | masonry grid, collection & wishlist filters, photo upload, fit-status segmented control, pin toggle |
| `CyclePlannerView` | Me → Cycle (or phase chip) | phase arc, per-phase recommendations, period logging |
| `MeView` + subviews | Me tab | Why/Future-me editors, sealed letters with delivery dates, milestones, transformation timeline, identity card |
| `CelebrationOverlay` | milestone overlay | fires on milestone conditions (e.g. set a wardrobe item to "It fits!") |

## Prototype-only conveniences

- **Me → Prototype data**: load demo fixture / reset all data.
- SF Symbols are approximated with emoji; system font stack approximates SF Pro.
- No HealthKit/steps sources — activity data comes from the demo fixture.

## Keeping it in sync

Rule for this repo: **every completed SwiftUI screen ships with its
equivalent prototype screen in the same change.** If you touch engine math
in Swift, mirror it in `js/engines.js` (both files carry a comment pointing
at their counterpart).
