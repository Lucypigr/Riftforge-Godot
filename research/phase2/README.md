# Riftforge Phase 2 — original skill core (experimental)

This is an independent **data-level** prototype, motivated by the structural inventory in `riftforge_data_audit_phase1.zip`. It contains NO copied Grim Dawn DBR/TPL entries, original formulas, artwork or names. All test values are synthetic. It is **not** a game-engine conversion and does not yet change the playable game.

Files:
- `skill_definition.gd`: editable skill schema and validation.
- `combat_resolver.gd`: deterministic damage computation; returns a hit-feedback event.
- `skill_runtime.gd`: mana, cooldown, ranged projectile spawn instructions, AoE target filtering. Does NOT auto-hit projectiles.
- `tests/test_phase2_skill_core.gd`: synthetic functional tests.

## Run test

```sh
godot --headless --path . --script res://tests/test_phase2_skill_core.gd
```

## Integration gate

Existing `scripts/game.gd`, mobile controls, scenes and web export are **unmodified**. A subsequent integration must: (1) store SkillDefinition data for original skills; (2) have both PC and mobile call the SAME cast command; (3) spawn and move a real projectile using a `shots` instruction and resolve hits only at actual collision; (4) apply `hits` damage to enemy Nodes; (5) render `feedback` events with animations/audio/numbers; (6) run device tests. These steps are not accomplished merely by providing the core.

### Explicit limitations

Damage and resistances here are deliberately simplified ORIGINAL formulas, not a claim to reproduce Grim Dawn or POE. No proof of complete skill-database semantics, asset rights, actual animation timing, performance, or mobile playability is provided. The model uses per-target single resistance and external line-of-sight/collision validation.
