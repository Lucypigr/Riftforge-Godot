extends RefCounted
## Standalone, original damage calculation for Riftforge's phase-2 skill model.
## Does not mutate an enemy or claim to reproduce Grim Dawn/POE formulas.
const SkillDefinition = preload("res://research/phase2/skill_definition.gd")

static func resolve(skill: SkillDefinition, target: Dictionary, modifiers: Dictionary = {}, crit_roll: float = 0.99) -> Dictionary:
	if skill == null or not skill.validate().is_empty():
		return {"ok": false, "reason": "invalid_skill", "damage": 0}
	if not target.has("hp") or float(target["hp"]) <= 0.0:
		return {"ok": false, "reason": "invalid_target", "damage": 0}
	var raw: float = maxf(0.0, skill.base_damage + float(modifiers.get("flat_damage", 0.0)))
	raw *= maxf(0.0, 1.0 + float(modifiers.get("increased_percent", 0.0)) / 100.0)
	raw *= maxf(0.0, float(modifiers.get("more_multiplier", 1.0)))
	var critical: bool = clampf(crit_roll, 0.0, 1.0) < skill.crit_chance
	if critical:
		raw *= skill.crit_multiplier
	var resistance: float = clampf(float(target.get("resistance", 0.0)), -0.5, 0.75)
	var damage: int = maxi(0, int(round(raw * (1.0 - resistance))))
	return {
		"ok": true,
		"damage": damage,
		"critical": critical,
		"damage_type": skill.damage_type,
		"feedback": {
			"type": "hit", "amount": damage, "critical": critical,
			"position": target.get("position", Vector3.ZERO)
		}
	}
