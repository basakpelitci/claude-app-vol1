# Aura Design System

Calm, minimal, premium. Apple HIG-native with large typography, generous
whitespace, soft glassmorphism, and gentle motion. Both appearances are
first-class; Dark Mode is not an inversion but its own tuned palette.

## 1. Design tokens

Implemented in `DesignSystem/Tokens/` (`AuraColor`, `AuraTypography`,
`AuraSpacing`, `AuraRadius`, `AuraMotion`). Views use only tokens — never
raw values.

### 1.1 Color

Semantic tokens; each resolves per appearance (light / dark).

| Token | Role | Light | Dark |
|---|---|---|---|
| `background` | app canvas | `#F7F6F3` warm off-white | `#0D0D10` near-black |
| `surface` | cards | `#FFFFFF` | `#17171C` |
| `surfaceGlass` | glass cards | white @ 72% + blur | `#1C1C22` @ 68% + blur |
| `textPrimary` | headings | `#1A1A1E` | `#F4F4F6` |
| `textSecondary` | supporting | `#6E6E76` | `#9B9BA4` |
| `accent` | brand, momentum ring | `#5E8B7E` sage | `#7FB0A1` |
| `accentSoft` | fills, chips | accent @ 14% | accent @ 20% |
| `health` | health score | `#4A7FA5` calm blue | `#6FA5CC` |
| `protein` | protein metric | `#8A6FB8` soft violet | `#A98FD6` |
| `water` | hydration | `#4E9FBF` | `#6FC0DE` |
| `energy` | calories | `#C99A5B` warm amber | `#DDB27A` |
| `cycle` | cycle features | `#B87A8F` muted rose | `#D699AE` |
| `celebrate` | milestones | `#D9A441` gold | `#E8BC63` |

**Rules:** no pure red anywhere (never-shame); overshoot is shown in
`textSecondary` + copy, not alarm color. WCAG AA verified for text tokens.

### 1.2 Typography (SF Pro / SF Rounded, Dynamic Type)

| Token | Style | Usage |
|---|---|---|
| `heroNumber` | SF Rounded, 56, bold | Momentum / Health hero scores |
| `largeTitle` | .largeTitle bold | screen titles |
| `title` | .title2 semibold | card titles |
| `metricValue` | SF Rounded 28 semibold | card numbers |
| `body` | .body | copy |
| `caption` | .footnote, textSecondary | deltas, meta |

All styles use `relativeTo:` so Dynamic Type scales the whole system.

### 1.3 Spacing & radius (4-pt grid)

`space1=4, space2=8, space3=12, space4=16, space5=24, space6=32, space7=48`
Screen margin 20. Card padding `space5`. Radii: card 24 (continuous), chip 12,
sheet 32, ring stroke 10–14.

### 1.4 Motion

| Token | Curve | Usage |
|---|---|---|
| `gentle` | spring(response 0.5, damping 0.85) | card appearance, value changes |
| `score` | spring(response 0.9, damping 0.8) | ring fills, count-up numbers |
| `celebrate` | spring(response 0.55, damping 0.6) | milestone overlay |

Reduce Motion → crossfades only. Numbers animate with count-up
(`contentTransition(.numericText())`).

### 1.5 Elevation / glass

Glass cards: `.ultraThinMaterial` + 1-pt inner border (white @ 8%) +
shadow(y: 8, blur: 24, black @ light 6% / dark 40%). Used for hero score
cards and overlays; standard cards are flat `surface` — glass is an accent,
not wallpaper.

## 2. Reusable components (`DesignSystem/Components/`)

| Component | Description |
|---|---|
| `ScoreRing` | animated circular gauge (Momentum/Health hero + mini variants) |
| `GlassCard` / `SurfaceCard` | card containers with token styling |
| `MetricProgressBar` | rounded linear progress with label + value + delta |
| `MacroRing` | small per-macro ring with icon |
| `TrendSparkline` | 30-day mini chart for card footers |
| `TrendChart` | full Swift Charts trend view with period picker |
| `PhaseChip` | cycle phase pill with phase color + day |
| `StatDelta` | value + arrow + kind wording ("↘ 0.4 kg this week") |
| `AuraButton` | primary / secondary / quiet styles |
| `EmptyStateView` | kind illustrated empty states |
| `CelebrationOverlay` | full-screen milestone moment (confetti, identity copy) |
| `QuickAddWater` | one-tap +250 ml control |
| `MasonryGrid` | two-column staggered grid for Wardrobe |

## 3. Voice & tone

- Address the user as "you"; the app never says "I".
- Celebrate first, inform second, suggest last.
- Banned vocabulary: *cheat, fail, bad, guilty, sin, punish, behind, ruined*.
- Overshoot phrasing pattern: "Calories ran high today — protein and water
  were excellent. Tomorrow starts fresh."
- Cycle copy is physiological and normalizing, never euphemistic or alarming.

## 4. Accessibility

- Dynamic Type to XXXL without truncation (cards reflow vertically).
- Every ring/chart has an `accessibilityLabel` + `accessibilityValue`
  sentence ("Momentum 91 percent, protein excellent, water 82 percent").
- Hit targets ≥ 44 pt; VoiceOver order: score → detail → action.
- Color is never the only signal — every state has text.
