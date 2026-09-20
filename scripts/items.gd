extends RefCounted
## Self-authored item bases, prefixes, suffixes, and weighted loot: no imported IP.
const BASES = [
	{"name": "燼鐵長劍", "slot": "weapon", "damage": 8, "armor": 0.0},
	{"name": "遊隼法杖", "slot": "weapon", "damage": 11, "armor": 0.0},
	{"name": "旅者護甲", "slot": "armor", "damage": 0, "armor": 0.09},
	{"name": "石紋胸甲", "slot": "armor", "damage": 0, "armor": 0.13}
]
const PREFIXES = [
	{"name": "銳利的", "damage": 4, "hp": 0},
	{"name": "生機的", "damage": 0, "hp": 20},
	{"name": "猛烈的", "damage": 7, "hp": 0}
]
const SUFFIXES = [
	{"name": "·餘燼", "damage": 3, "hp": 0},
	{"name": "·守護", "damage": 0, "hp": 18},
	{"name": "·疾影", "damage": 2, "hp": 8}
]

static func make_item(level: int, boss: bool = false) -> Dictionary:
	var base: Dictionary = BASES[randi_range(0, BASES.size() - 1)]
	var prefix: Dictionary = PREFIXES.pick_random()
	var suffix: Dictionary = SUFFIXES.pick_random()
	var rarity := "稀有" if boss or randf() < 0.2 else "魔法"
	var has_suffix: bool = rarity == "稀有"
	var damage: int = int(base["damage"]) + int(prefix["damage"]) + (int(suffix["damage"]) if has_suffix else 0) + int(level / 2.0)
	var hp: int = int(prefix["hp"]) + (int(suffix["hp"]) if has_suffix else 0)
	return {
		"name": str(prefix["name"]) + str(base["name"]) + (str(suffix["name"]) if has_suffix else ""),
		"slot": base["slot"], "rarity": rarity, "damage": damage,
		"hp": hp, "armor": base["armor"], "level": level
	}

static func starting_weapon() -> Dictionary:
	return {"name": "新手短劍", "slot": "weapon", "rarity": "普通", "damage": 6, "hp": 0, "armor": 0.0, "level": 1}

static func starting_armor() -> Dictionary:
	return {"name": "舊布衣", "slot": "armor", "rarity": "普通", "damage": 0, "hp": 0, "armor": 0.02, "level": 1}
