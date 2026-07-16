# User Personas

Aura targets people on a **sustainable fat-loss journey** who have failed with
pass/fail trackers before. Three primary personas drive design decisions.

---

## Persona 1 — Elif, "The Restarter" (primary)

- **Age 34 · Product manager · Istanbul · iPhone 15 Pro, Apple Watch**
- **Goal:** lose 12 kg of fat while keeping muscle; fit into a specific dress.
- **History:** four previous attempts with MyFitnessPal-style apps. Each time
  she quit between week 4 and 6 — not from hunger, but because a broken streak
  made the app feel like a judge.
- **Cycle:** regular; notices strong luteal-phase cravings that trackers treat
  as "failures".
- **Needs:**
  - Partial credit on imperfect days (Momentum, not streaks).
  - Proof that muscle is being preserved (BIA trends, Health Score reasons).
  - Cycle-aware targets so luteal weeks don't feel like relapse.
  - An emotional anchor — her Dream Wardrobe dress on the dashboard.
- **Quote:** *"I don't need another app to tell me I ate too much. I need one
  that notices I showed up."*
- **Success:** still engaged on day 60; sees LBM flat while body fat drops.

## Persona 2 — Deniz, "The Data Optimizer"

- **Age 41 · Software engineer · smart BIA scale, Whoop, Garmin**
- **Goal:** cut body fat 24% → 17% without losing lifting performance.
- **History:** loves spreadsheets; distrusts apps that hide their math.
- **Needs:**
  - Transparent formulas (LBM-based protein, visible weights in Momentum).
  - Full BIA panel storage with trend charts for every metric.
  - Predictions with honest confidence, recalculated as data arrives.
  - Future device integrations (architecture matters to them).
- **Quote:** *"Show me the model. If protein targets come from total weight
  instead of lean mass, I'm out."*
- **Success:** trusts the numbers enough to stop maintaining a spreadsheet.

## Persona 3 — Maya, "The Gentle Beginner"

- **Age 27 · Nurse, rotating shifts · iPhone 13**
- **Goal:** lose 8 kg; build the identity of "someone who takes care of herself".
- **History:** never tracked before; intimidated by macro jargon; anxious about
  being judged for shift-work eating times.
- **Needs:**
  - Calm, minimal UI; one glance tells her she's okay.
  - Kind reminders, never red badges or guilt copy.
  - Identity features: Why I Started, Letter to Myself, Future Me.
  - Water and steps as first-class wins (they're achievable on any shift).
- **Quote:** *"I just want to feel like I'm becoming that person, a little
  bit every day."*
- **Success:** logs something — anything — 5+ days a week and reads her
  milestone celebrations.

---

## Anti-persona

**The crash dieter** seeking aggressive deficits, punishment framing, or
"lose 10 kg in 2 weeks" plans. Aura's engines clamp deficits to sustainable
ranges and will not serve this user's expectations — by design.

## Persona-driven requirements matrix

| Requirement | Elif | Deniz | Maya |
|---|---|---|---|
| Momentum partial credit | ●●● | ●● | ●●● |
| BIA trends & transparent math | ●● | ●●● | ● |
| Cycle-aware targets | ●●● | ● | ●● |
| Dream Wardrobe | ●●● | ● | ●● |
| Identity / motivation artifacts | ●● | ● | ●●● |
| Predictions | ●● | ●●● | ● |
| Kind reminders | ●● | ● | ●●● |
