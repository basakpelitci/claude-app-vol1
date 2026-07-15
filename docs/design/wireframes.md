# UI Wireframes (low-fi, annotated)

ASCII wireframes define layout intent; spacing/typography come from design
tokens. All screens scroll; cards reflow vertically at large Dynamic Type.

---

## Today (Dashboard)

```
┌─────────────────────────────────────┐
│  Tuesday, Jul 15          [🌙 phase]│  ← greeting + CyclePhaseChip
│  Good morning, Elif                 │
│                                     │
│  ┌───────────────┬───────────────┐  │
│  │   MOMENTUM    │  HEALTH SCORE │  │  ← two glass hero cards
│  │    ◐ 91       │     ♥ 87      │  │    ScoreRing + count-up
│  │  "strong day" │  "muscle ↑"   │  │    tap → detail breakdown
│  └───────────────┴───────────────┘  │
│                                     │
│  ┌─────────────────────────────────┐│
│  │ Calories remaining      612 kcal││  ← energy color, bar
│  │ ████████████░░░░░  1,238/1,850  ││
│  └─────────────────────────────────┘│
│  ┌────────┬────────┬────────┬─────┐ │
│  │Protein │ Carbs  │  Fat   │Fiber│ │  ← MacroRing row
│  │ ◔ 94%  │ ◑ 61%  │ ◔ 55%  │ 71% │ │
│  └────────┴────────┴────────┴─────┘ │
│  ┌───────────────┬────────────────┐ │
│  │ Water  1.6/2.3L│ NEAT  7,412 st│ │  ← quick +250ml button
│  │ ▓▓▓▓▓░░ [+250] │ ▂▄▆▅▇  sit 4h │ │
│  └───────────────┴────────────────┘ │
│  ┌─────────────────────────────────┐│
│  │ Today's workout   Lower body 💪 ││  ← cycle-aware recommendation
│  │ Luteal phase → moderate + core  ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ Body   -0.4kg fat · muscle held ││  ← BIASummaryCard, sparkline
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ [photo] The linen dress         ││  ← DreamOutfitCard
│  │ Target 38 · "getting closer" ◔  ││
│  └─────────────────────────────────┘│
│  │ "You showed up 12 days in a row"│  ← DailyMotivationCard
│ ─────────────────────────────────── │
│  ● Today  ○ Nutrition ○ Body ○ 👗 ○ Me
└─────────────────────────────────────┘
```

## Momentum Detail (push)

```
│  ◐ 91  Momentum                     │
│  Consistency, not perfection.       │
│  Protein      ████████████▉  94%    │
│  Calories     █████████████▊ 98%    │
│  Water        ██████████▎    82%    │
│  Workout      ██████████████ 100%   │
│  NEAT         ███████████▍   88%    │
│  Sleep        █████████▏     76%    │
│  Meal timing  ███████████    85%    │
│  Cycle sync   ██████████████ 100%   │
│  each row: weight chip + one-line detail
```

## Nutrition

```
│  ‹ Mon   TODAY   Wed ›              │  ← day pager
│  ┌─────────────────────────────────┐│
│  │ 612 remaining · meal score B+   ││
│  │ P◔94 C◑61 F◔55 Fi 71            ││
│  └─────────────────────────────────┘│
│  Breakfast                    412   │
│   • Yogurt bowl   P22 C31 F9   [♥]  │
│  Lunch                        640   │
│   • Chicken salad …                 │
│  Dinner                    + Add    │
│  Snacks                    + Add    │
│  Water  ▓▓▓▓▓░░ 1.6/2.3L  [+250ml]  │
│                         (＋) FAB    │
```

## Body (BIA)

```
│  Latest panel · Jul 14              │
│  ┌────────┬────────┬────────┐       │
│  │ 68.2kg │ 27.4%  │ 47.1kg │       │  ← weight / BF% / LBM
│  │ ↘0.4   │ ↘0.3   │ →      │       │    StatDelta under each
│  ├────────┼────────┼────────┤       │
│  │ muscle │ water  │visceral│  …    │  ← full panel grid
│  └────────┴────────┴────────┘       │
│  Trends            [7d 30d 90d all] │
│  Body fat %   ╲╲__╲_    27.4        │  ← TrendChart per metric
│  Muscle       ____/─    26.1        │
│  ┌─────────────────────────────────┐│
│  │ 🎯 Prediction                   ││
│  │ Goal ~ Nov 3 · 61.8kg · 21% BF  ││
│  │ confidence ● ● ● ○              ││
│  └─────────────────────────────────┘│
│  [ + Add measurement ]              │
```

## Wardrobe (masonry)

```
│  Dream Wardrobe        [+ item]     │
│  (All)(Summer)(Work)(✨Wishlist)(+) │  ← collections bar
│  ┌───────┐ ┌───────────┐            │
│  │ photo │ │   photo   │            │  ← MasonryGrid, 2 cols
│  │ dress │ │   jeans   │            │
│  │ 38 ◔  │ │  fits! ✓  │            │  ← target size + fit badge
│  └───────┘ └───────────┘            │
│  ┌───────────┐ ┌───────┐            │
│  │   jacket  │ │ shoes │            │
```

## Cycle Planner

```
│  Cycle · Day 22 — Luteal 🌙         │
│  ┌── phase arc calendar ──────────┐ │
│  │  M ▓▓ F ▓▓▓▓▓ O ▓ L ▓▓▓▓●▓▓    │ │
│  └────────────────────────────────┘ │
│  This phase, your body prefers:     │
│   💪 Workout   moderate strength    │
│   🛌 Recovery  prioritize rest days │
│   🥩 Protein   +10g target applied  │
│   💧 Hydration +250ml applied       │
│   😴 Sleep     aim 8h               │
│   🏃 Cardio    zone-2 over HIIT     │
│  "Targets already adapted for you." │
```

## Me (Motivation hub)

```
│  Me                                 │
│  ┌─────────────────────────────────┐│
│  │ 🌱 Why I started     [photo]    ││
│  │ "To feel strong at 35."         ││
│  └─────────────────────────────────┘│
│  ✉️ Letter to myself   opens Aug 29 │
│  🏆 Milestones                 12 › │
│  📈 Transformation timeline       › │
│  🧬 Identity: "I am someone who     │
│      trains 3× a week"              │
│  ─────────                          │
│  🌙 Cycle planner ›   ⚙️ Settings › │
```

## Celebration overlay (modal, full-screen)

```
│         ✦  ✧   ✦                    │
│      ┌───────────┐                  │
│      │  🏆 30    │  glass, confetti │
│      │   DAYS    │                  │
│      └───────────┘                  │
│  "A month of showing up.            │
│   You are becoming that person."    │
│  [ See my timeline ]  [ Continue ]  │
```
