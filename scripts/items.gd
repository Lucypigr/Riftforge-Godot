extends RefCounted
## Original Riftforge item generation. No third-party game records or assets are imported.
## Base, prefix and suffix are separate data modules; weights are relative, not drop chances.
const BASES = [
	{"id": "rift_sabre", "name": "裂紋軍刀", "slot": "weapon", "weapon_class": "sword", "attack_mode": "melee", "damage": 15, "armor": 0.0, "attack_interval": 0.67, "attack_reach": 3.1, "weight": 5, "min_level": 1},
	{"id": "ash_crossbow", "name": "灰燼手弩", "slot": "weapon", "weapon_class": "crossbow", "attack_mode": "ranged", "damage": 19, "armor": 0.0, "attack_interval": 0.46, "attack_reach": 29.0, "weight": 4, "min_level": 1},
	{"id": "starlight_focus", "name": "星火法器", "slot": "weapon", "weapon_class": "focus", "attack_mode": "ranged", "damage": 9, "armor": 0.0, "attack_interval": 0.22, "attack_reach": 23.0, "weight": 4, "min_level": 1},
	{"id": "traveler_coat", "name": "旅者護甲", "slot": "armor", "damage": 0, "armor": 0.09, "weight": 6, "min_level": 1},
	{"id": "stone_plate", "name": "石紋胸甲", "slot": "armor", "damage": 0, "armor": 0.13, "weight": 4, "min_level": 1}
]
const PREFIXES = [
	{"id": "keen", "name": "銳利的", "slots": ["weapon"], "weight": 6, "min_level": 1, "damage": 4, "offensive_ability": 20},
	{"id": "swift", "name": "迅捷的", "slots": ["weapon"], "weight": 4, "min_level": 1, "damage": 1, "attack_speed_percent": 25},
	{"id": "heavy", "name": "沉重的", "slots": ["weapon"], "weight": 4, "min_level": 3, "damage": 9, "attack_speed_percent": -12},
	{"id": "vital", "name": "生機的", "slots": ["weapon", "armor"], "weight": 5, "min_level": 1, "hp": 20},
	{"id": "guarded", "name": "衛護的", "slots": ["armor"], "weight": 5, "min_level": 1, "hp": 12, "armor": 0.02}
]
const SUFFIXES = [
	{"id": "embers", "name": "·餘燼", "slots": ["weapon"], "weight": 5, "min_level": 1, "damage": 3},
	{"id": "precision", "name": "·精準", "slots": ["weapon"], "weight": 4, "min_level": 2, "offensive_ability": 55},
	{"id": "reach", "name": "·遠望", "slots": ["weapon"], "weight": 3, "min_level": 2, "attack_reach_bonus": 3.0},
	{"id": "guardian", "name": "·守護", "slots": ["armor"], "weight": 6, "min_level": 1, "hp": 18},
	{"id": "vigor", "name": "·活力", "slots": ["weapon", "armor"], "weight": 4, "min_level": 1, "hp": 8}
]

static func _roll(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng != null else randf()

static func _weighted(table: Array, slot: String, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var eligible: Array = []
	var total: float = 0.0
	for record in table:
		var entry: Dictionary = record
		if level < int(entry.get("min_level", 1)):
			continue
		if slot != "" and not (entry.get("slots", [entry.get("slot", "")]) as Array).has(slot):
			continue
		var weight: float = maxf(0.0, float(entry.get("weight", 0.0)))
		if weight <= 0.0:
			continue
		eligible.append(entry)
		total += weight
	if eligible.is_empty():
		return {}
	var remaining: float = _roll(rng) * total
	for entry in eligible:
		remaining -= float(entry["weight"])
		if remaining < 0.0:
			return entry
	return eligible.back()

static func make_item(level: int, boss: bool = false, rng: RandomNumberGenerator = null) -> Dictionary:
	var item_level: int = maxi(1, level)
	var base: Dictionary = _weighted(BASES, "", item_level, rng)
	var slot: String = str(base["slot"])
	var rarity_roll: float = _roll(rng)
	var rarity: String = "稀有" if boss or rarity_roll >= 0.75 else ("魔法" if rarity_roll >= 0.18 else "普通")
	var prefix: Dictionary = _weighted(PREFIXES, slot, item_level, rng) if rarity != "普通" else {}
	var suffix: Dictionary = _weighted(SUFFIXES, slot, item_level, rng) if rarity == "稀有" else {}
	var result: Dictionary = base.duplicate(true)
	result["base_id"] = str(base["id"])
	result["prefix_id"] = str(prefix.get("id", ""))
	result["suffix_id"] = str(suffix.get("id", ""))
	result["name"] = str(prefix.get("name", "")) + str(base["name"]) + str(suffix.get("name", ""))
	result["rarity"] = rarity
	result["level"] = item_level
	result["damage"] = int(base.get("damage", 0)) + int(prefix.get("damage", 0)) + int(suffix.get("damage", 0)) + (int(item_level / 2.0) if slot == "weapon" else 0)
	result["hp"] = int(prefix.get("hp", 0)) + int(suffix.get("hp", 0))
	result["armor"] = float(base.get("armor", 0.0)) + float(prefix.get("armor", 0.0)) + float(suffix.get("armor", 0.0))
	result["offensive_ability"] = int(prefix.get("offensive_ability", 0)) + int(suffix.get("offensive_ability", 0))
	result["attack_speed_percent"] = int(prefix.get("attack_speed_percent", 0)) + int(suffix.get("attack_speed_percent", 0))
	result["attack_reach"] = float(base.get("attack_reach", 0.0)) + float(prefix.get("attack_reach_bonus", 0.0)) + float(suffix.get("attack_reach_bonus", 0.0))
	result.erase("weight")
	result.erase("min_level")
	return result

static func starting_weapon() -> Dictionary:
	# Preserve the previous three-projectile starter gameplay and legacy-save semantics.
	return {"name": "新手短弩", "slot": "weapon", "rarity": "普通", "base_id": "starter_crossbow", "weapon_class": "crossbow", "attack_mode": "ranged", "attack_interval": 0.205, "attack_reach": 26.0, "damage": 6, "hp": 0, "armor": 0.0, "offensive_ability": 0, "attack_speed_percent": 0, "level": 1}

static func starting_armor() -> Dictionary:
	return {"name": "舊布衣", "slot": "armor", "rarity": "普通", "damage": 0, "hp": 0, "armor": 0.02, "level": 1}
