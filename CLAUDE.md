# Aura — repo conventions

## Prototype parity rule (required)

Every completed SwiftUI screen must ship with an equivalent interactive HTML
prototype under `prototype/` (Tailwind CSS + vanilla JS, no framework), in
the same change. The prototype exists so UX can be tested in a browser
before compiling the native app, and it must visually match the SwiftUI
implementation as closely as possible.

Keeping them in sync:

- Screens: SwiftUI views in `Aura/Features/**` ⇄ render functions in
  `prototype/js/app.js`. The mapping table lives in `prototype/README.md`.
- Engine math: `Aura/Domain/Engines/*.swift` ⇄ `prototype/js/engines.js`
  (1:1 port — if you change a formula in one, change the other).
- Design tokens: `Aura/DesignSystem/Tokens/AuraTheme.swift` ⇄ CSS variables
  in `prototype/src/input.css` + `prototype/tailwind.config.js`.
- After editing prototype CSS/config, rebuild the committed stylesheet:
  `cd prototype && npm install && npm run build` (output `css/tailwind.css`
  is committed so the prototype runs with no build step, fully offline).

## Verifying the prototype

Serve statically and drive it in a browser (Playwright + Chromium are
available in remote sessions):

```bash
cd prototype && python3 -m http.server 8080
```

Test at minimum: onboarding completes, meal/water/BIA logging updates
Momentum instantly, wardrobe fit-status change fires the celebration
overlay, and dark mode (`prefers-color-scheme`) renders the dark palette.

## Product rules that apply to all copy (Swift and HTML alike)

- Never shame, never guilt: banned vocabulary — cheat, fail, bad, guilty,
  sin, punish, behind, ruined.
- No pure red in the UI; overshoot is neutral text plus kind copy.
- Targets are always computed by the Goal Engine — never hardcoded.
- Protein targets derive from lean body mass, never total body weight.

## Swift project

`project.yml` (XcodeGen) generates `Aura.xcodeproj` — don't commit the
generated project. Engine unit tests live in `Aura/Tests/DomainTests`.
