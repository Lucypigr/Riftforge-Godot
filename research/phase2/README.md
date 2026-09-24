# Riftforge Phase 2 — experimental skill integration

This branch contains an **original, independent skill core** plus an adapter integrating it into the playable Godot scene. It includes no copied Grim Dawn DBR/TPL records, copyrighted artwork, or engine source. Its simplified formulas are NOT Grim Dawn or POE formulas.

## Implemented

- `skill_definition.gd`: resource-based skill schema with validation.
- `combat_resolver.gd`: simplified damage, critical hit, resistance and hit feedback data.
- `skill_runtime.gd`: mana, cooldown, projectile spawn commands and AoE target filtering.
- `scripts/phase2_game.gd`: makes desktop and mobile call a shared bolt/nova casting implementation. Synchronizes existing HUD cooldowns and player mana with the shared runtime. Only an active gem in socket 0 enables the bolt.
- `scripts/phase2_projectile.gd`: retains the original projectile visuals and pierce behavior but uses a swept motion segment and resolves damage on actual collision. Enemy projectiles retain the existing path.
- `scenes/main.tscn`: experimental branch ONLY points to the new adapter. No change to the public `main` branch or GitHub Pages.

## Verification

`godot --headless --path . --script res://tests/test_phase2_skill_core.gd`

`godot --headless --path . --script res://tests/test_phase2_integration.gd`

GitHub Actions runs both suites and checks an experimental Web export without publishing it. Current results: 20 core assertions + 21 integration assertions passed. Scene assertions include real-enemy HP changes after a swept projectile hit, area filtering, mana/cooldowns, mobile-button method dispatch, and field transition.

## Release gate and known limitations

- Headless test inputs are synthesized method calls, NOT actual iPhone touches; multi-touch, visual appearance and controls still require hands-on device/browser testing.
- Only two original sample skills are wired. This is not a conversion of the 34k Grim Dawn data records, original game engine, AI or art.
- Existing enemy AI, loot, HUD and combat effects are the original Riftforge prototype, not an ARPG finished to a commercial game's standard.
- No original Grim Dawn/POE assets, data, names or formulas are distributed. Before incorporating third-party content, verify licenses and prepare original replacements.
- Do not merge this draft PR or describe the web game as updated until browser/mobile acceptance has been performed.
