# Aura — Personal Health Operating System

A premium iOS behavior-change platform for sustainable fat loss. Not a calorie
tracker, not a fitness app: Aura keeps users emotionally connected to their
goal past the day-30–40 motivation cliff through weighted consistency scoring
(Momentum), physiological insight (Health Score), cycle-aware adaptive targets,
and identity-building motivation features (Dream Wardrobe, Why I Started,
Transformation Timeline).

**Platform:** iOS 17+ · SwiftUI · SwiftData · Swift Charts
**Architecture:** Clean Architecture · MVVM · Repository pattern · offline-first

## Documentation

| Doc | Contents |
|---|---|
| [PRD](docs/01-product-requirements.md) | vision, goals, modules, engines, requirements |
| [Personas](docs/02-user-personas.md) | Elif, Deniz, Maya + requirements matrix |
| [User Journey](docs/03-user-journey.md) | onboarding → day-90 identity consolidation |
| [Information Architecture](docs/04-information-architecture.md) | screen inventory, navigation flow |
| [Architecture](docs/05-architecture.md) | layers, folder structure, DI, data flow, state management |
| [Domain Models & Schema](docs/06-domain-models-and-schema.md) | entities, SwiftData schema, formulas |
| [Design System](docs/design/design-system.md) | tokens, components, voice & tone, accessibility |
| [Wireframes](docs/design/wireframes.md) | annotated screen layouts |

## Project layout

```
Aura/
├── App/            entry point, DI composition root, tab shell
├── Domain/         pure Swift: entities, engines, repository protocols
├── Data/           SwiftData models, repository implementations, mappers
├── Features/       Today, Nutrition, Body, Wardrobe, Cycle, Motivation, Onboarding
├── DesignSystem/   tokens, reusable components
└── Tests/          engine unit tests
```

## Core engines

Goal · Nutrition (LBM-based protein) · Momentum (weighted consistency) ·
Health Score (explained physiology) · Prediction · Motivation · AI Insight.
All engines are pure, deterministic, and UI-free — see
[docs/05-architecture.md](docs/05-architecture.md).

## Product principles

Never shame. Never guilt. Celebrate progress. Trends over days.
Identity over outcomes.
