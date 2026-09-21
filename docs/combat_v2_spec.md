# Riftforge Combat V2 — original experimental rules

This is **not** Grim Dawn source code, a database conversion, or a claim of numeric parity with that game's engine. The user's DBR/TPL archive was used to study *concepts* (offense/defense ratings, damage types, conversion, resistances and physical armor). Values and the smooth rating curve below are original Riftforge gameplay choices. No proprietary source, textures, records or item names are embedded.

## Live integration (Phase 4 branch only)

`scenes/main.tscn` still uses `phase3_game.gd` so the real backpack and touch input regressions continue to apply. Its `_ready()` enables `SkillRuntime.use_combat_v2`; the default remains disabled for standalone Phase 2 compatibility. Both mobile and PC call `cast_bolt`/`cast_nova` and the same `SkillRuntime`; the projectile resolves damage only on its swept collision, not when cast.

The current bolt deals **fire base skill damage** plus a **physical weapon component**. Nova is lightning plus 70% of the weapon physical component. Enemy archetypes now provide explicit defensive ratings, physical armor and typed resistance dictionaries. Higher offensive ability can be supplied later by `weapon.offensive_ability`, but existing items do not yet generate this affix. Player incoming attacks still use the older simplified fractional armor function, so this is **not** a full combat overhaul.

## Resolution contract

1. Reject invalid skills/dead targets; compute `PTH = clamp(90 + 80*(OA-DA)/(OA+DA), 55, 135)` for positive OA/DA. This **original** curve is not claimed to be Grim Dawn's formula.
2. Projectiles may miss based on `min(100%, PTH/100)`; area skills do not miss. Critical chance is `clamp((PTH-90)/100, 0, 0.45)` with independent critical roll. Crit tiers across >90/105/120/130/135 use 1.1/1.2/1.3/1.4/1.5. This is a Riftforge approximation, not sourced game engine behavior.
3. Form typed components: base skill's declared type, and weapon's physical flat damage. Convert a clamped 0–100% portion of weapon physical to fire once if a modifier requests `physical_to_fire`.
4. Apply global additive percent, each type's own additive percent, multiplicative modifier and critical multiplier to each component.
5. On the physical component only, apply flat armor mitigation: `max(0, raw - min(raw, armor_rating) * clamp(absorption, 0, 1))`. Then apply each type's resistance clamped from -50% to 80%. Round sum of post-defense components once. Allow real zero damage; misses never call `enemy.take_hit(0)`.
6. No damage, stagger or knockback on missed projectiles. Projectile contact is consumed as usual, including pierce count.

## Pending before a stable merge

- Compare desired balance in real iPhone field fights, including high-defence bosses and elemental/physical weapons.
- Extend type system to damage-over-time, multiple conversions and proc triggers only after tests exist.
- Move player incoming damage to a type-aware defender after defining player armor item semantics and save migration.
- Add data-driven original weapon bases and affixes instead of inventing Grim Dawn record imports.

Tests: `tests/test_phase4_combat_v2.gd` checks deterministic math and real projectile damage, together with inherited inventory, casting and simulated multitouch regressions in `.github/workflows/phase4-combat-test.yml`. GitHub Actions Web export is a build test, not iPhone validation or production deployment.
