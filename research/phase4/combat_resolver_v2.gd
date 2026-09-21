extends RefCounted
## Original Riftforge combat rules inspired by ARPG design, NOT a port of Grim Dawn code.
## One attack: validate -> accuracy -> convert -> type bonuses -> crit -> defence -> round.
const SkillDefinition = preload("res://research/phase2/skill_definition.gd")
const MIN_PTH := 55.0
const MAX_PTH := 135.0

static func pth(offensive_ability: float, defensive_ability: float) -> float:
	var oa: float = maxf(1.0, offensive_ability)
	var da: float = maxf(1.0, defensive_ability)
	# An intentionally original, smooth rating curve; equal ratings produce 90 PTH.
	return clampf(90.0 + 80.0 * (oa - da) / (oa + da), MIN_PTH, MAX_PTH)

static func critical_multiplier(hit_rating: float) -> float:
	if hit_rating >= 135.0:
		return 1.5
	if hit_rating >= 130.0:
		return 1.4
	if hit_rating >= 120.0:
		return 1.3
	if hit_rating >= 105.0:
		return 1.2
	if hit_rating > 90.0:
		return 1.1
	return 1.0

static func mitigate_physical(raw_damage: float, armor_rating: float, absorption: float = 0.7) -> float:
	var raw: float = maxf(0.0, raw_damage)
	return maxf(0.0, raw - minf(raw, maxf(0.0, armor_rating)) * clampf(absorption, 0.0, 1.0))

static func resolve(skill: SkillDefinition, target: Dictionary, modifiers: Dictionary = {}, hit_roll: float = 0.0, crit_roll: float = 0.99) -> Dictionary:
	if skill == null or not skill.validate().is_empty():
		return {"ok": false, "reason": "invalid_skill", "damage": 0}
	if float(target.get("hp", 0.0)) <= 0.0:
		return {"ok": false, "reason": "invalid_target", "damage": 0}
	var rating: float = pth(float(modifiers.get("offensive_ability", 1000.0)), float(target.get("defensive_ability", 1000.0)))
	var can_miss: bool = bool(modifiers.get("can_miss", skill.delivery == "projectile"))
	var hit_chance: float = minf(1.0, rating / 100.0) if can_miss else 1.0
	if clampf(hit_roll, 0.0, 1.0) >= hit_chance:
		return {"ok": true, "hit": false, "damage": 0, "critical": false, "pth": rating,
			"feedback": {"type": "miss", "amount": 0, "position": target.get("position", Vector3.ZERO)}}
	var crit_chance: float = clampf((rating - 90.0) / 100.0, 0.0, 0.45)
	var critical: bool = clampf(crit_roll, 0.0, 1.0) < crit_chance
	var crit_factor: float = critical_multiplier(rating) if critical else 1.0
	var damage_by_type: Dictionary = {str(skill.damage_type): maxf(0.0, skill.base_damage)}
	var physical: float = maxf(0.0, float(modifiers.get("flat_damage", 0.0)))
	# Convert the weapon-supplied physical component once, before type bonuses.
	var conversion: float = clampf(float(modifiers.get("physical_to_fire", 0.0)), 0.0, 1.0)
	damage_by_type["physical"] = float(damage_by_type.get("physical", 0.0)) + physical * (1.0 - conversion)
	damage_by_type["fire"] = float(damage_by_type.get("fire", 0.0)) + physical * conversion
	var bonuses: Dictionary = modifiers.get("type_increased_percent", {})
	var general_bonus: float = maxf(0.0, 1.0 + float(modifiers.get("increased_percent", 0.0)) / 100.0)
	var more: float = maxf(0.0, float(modifiers.get("more_multiplier", 1.0)))
	var resistances: Dictionary = target.get("resistances", {})
	var damage_sum: float = 0.0
	var after_defence: Dictionary = {}
	for damage_type in damage_by_type:
		var amount: float = float(damage_by_type[damage_type])
		amount *= general_bonus * maxf(0.0, 1.0 + float(bonuses.get(damage_type, 0.0)) / 100.0) * more * crit_factor
		if damage_type == "physical":
			amount = mitigate_physical(amount, float(target.get("armor_rating", 0.0)), float(target.get("armor_absorption", 0.7)))
		var resistance: float = clampf(float(resistances.get(damage_type, target.get("resistance", 0.0))), -0.5, 0.8)
		amount *= 1.0 - resistance
		after_defence[damage_type] = amount
		damage_sum += amount
	var damage: int = maxi(0, int(round(damage_sum)))
	return {"ok": true, "hit": true, "damage": damage, "critical": critical,
		"pth": rating, "damage_by_type": after_defence, "damage_type": skill.damage_type,
		"feedback": {"type": "hit", "amount": damage, "critical": critical,
			"position": target.get("position", Vector3.ZERO)}}
