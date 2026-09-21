extends SceneTree
const Items = preload("res://scripts/items.gd")
const Grid = preload("res://scripts/grid_inventory.gd")
const Rules = preload("res://research/phase5/weapon_rules.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Loot = preload("res://scripts/loot.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS " + label)
	else:
		failed += 1
		push_error("FAIL " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	var seen: Dictionary = {}
	var rarity_seen: Dictionary = {}
	var generation_valid := true
	for i in range(350):
		var loot: Dictionary = Items.make_item(1 + (i % 8), false, rng)
		seen[str(loot["base_id"])] = true
		rarity_seen[str(loot["rarity"])] = true
		if int(loot["level"]) != 1 + (i % 8) or not ["weapon", "armor"].has(str(loot["slot"])):
			generation_valid = false
		if loot["rarity"] == "普通" and (loot["prefix_id"] != "" or loot["suffix_id"] != ""):
			generation_valid = false
		if loot["rarity"] == "魔法" and (loot["prefix_id"] == "" or loot["suffix_id"] != ""):
			generation_valid = false
		if loot["rarity"] == "稀有" and (loot["prefix_id"] == "" or loot["suffix_id"] == ""):
			generation_valid = false
		if loot["slot"] == "weapon" and (not ["melee", "ranged"].has(str(loot["attack_mode"])) or Rules.interval(loot) <= 0.0):
			generation_valid = false
	check(generation_valid, "level/slot/affix limits and valid weapon stats hold across weighted generation")
	check(seen.size() == Items.BASES.size(), "all five original base records can be selected by weighted loot")
	check(rarity_seen.size() == 3, "normal, magic, and rare items all occur")
	var boss_item: Dictionary = Items.make_item(12, true, rng)
	check(boss_item["rarity"] == "稀有" and boss_item["prefix_id"] != "" and boss_item["suffix_id"] != "", "boss drops have two eligible affixes")
	check(Rules.interval({"attack_interval": 0.5, "attack_speed_percent": 25}) < Rules.interval({"attack_interval": 0.5}), "speed affix actually shortens the attack interval")
	check(Rules.within_arc(Vector3.ZERO, Vector3.RIGHT, Vector3(2, 0, 0), 3.1) and not Rules.within_arc(Vector3.ZERO, Vector3.RIGHT, Vector3(-2, 0, 0), 3.1), "melee arc distinguishes front and rear enemies")
	check(not Rules.within_arc(Vector3.ZERO, Vector3.RIGHT, Vector3(4, 0, 0), 3.1), "melee reach excludes distant targets")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.inventory.clear()
	game.equipment = {"weapon": Items.starting_weapon(), "armor": Items.starting_armor()}
	game.level = 1
	game.socket_gems = ["ember_bolt", "scatter", "pierce"]
	game.player.refresh_equipment()
	game.zone = "field"
	game.player.position = Vector3(0, 0.9, 0)
	game.aim_direction = Vector3.RIGHT
	var dropped: Dictionary = Items.make_item(5, true, rng)
	var drop = Loot.new()
	drop.initialize(dropped)
	drop.position = game.player.position + Vector3(0.2, -0.5, 0)
	game.add_child(drop)
	game._interact()
	check(game.inventory.size() == 1 and game.inventory[0]["base_id"] == dropped["base_id"] and Grid.placed(game.inventory[0]) and drop.is_queued_for_deletion(), "actual interact collects generated loot into the 120-cell backpack")
	game.inventory.clear()
	var sword: Dictionary = Items.BASES[0].duplicate(true)
	sword["name"] = "測試迅捷軍刀"
	sword["hp"] = 24
	sword["attack_speed_percent"] = 25
	sword["offensive_ability"] = 50
	sword["rarity"] = "稀有"
	sword["level"] = 1
	check(Grid.try_add(game.inventory, sword), "multi-cell sword fits the real backpack")
	game.equip_item(0)
	check(game.equipment["weapon"]["name"] == "測試迅捷軍刀" and game.inventory.size() == 1 and Grid.placed(game.inventory[0]), "weapon swap returns original equipment to valid backpack cells")
	check(is_equal_approx(game.player.max_hp, 144.0) and is_equal_approx(game._offensive_ability(), 1050.0), "weapon health and accuracy affixes affect the actual player")
	check(Rules.mode(game.equipment["weapon"]) == "melee", "sword selects the melee combat mode")
	var near_enemy = Enemy.new()
	near_enemy.initialize(game, "hunter")
	near_enemy.hp = 400.0
	near_enemy.max_hp = 400.0
	near_enemy.armor_rating = 0.0
	near_enemy.position = game.player.position + Vector3(2.0, -0.2, 0)
	game.add_child(near_enemy)
	var rear_enemy = Enemy.new()
	rear_enemy.initialize(game, "hunter")
	rear_enemy.hp = 400.0
	rear_enemy.max_hp = 400.0
	rear_enemy.position = game.player.position + Vector3(-2.0, -0.2, 0)
	game.add_child(rear_enemy)
	game.player.mana = game.player.max_mana
	var initial_mana: float = game.player.mana
	game.cast_bolt()
	check(near_enemy.hp < 400.0 and is_equal_approx(rear_enemy.hp, 400.0), "live melee slash hurts only enemies within the forward arc")
	check(is_equal_approx(game.player.mana, initial_mana) and game._bolt_cd > 0.0, "basic melee spends no mana and applies real attack cooldown")
	check(_friendly_count(game) == 0, "melee does not secretly spawn spell projectiles")
	game._skill_runtime.advance(5.0)
	game._sync_cooldowns()
	var bow: Dictionary = Items.BASES[1].duplicate(true)
	bow["name"] = "測試迅捷手弩"
	bow["attack_speed_percent"] = 25
	bow["hp"] = 0
	bow["rarity"] = "稀有"
	bow["level"] = 1
	check(Grid.try_add(game.inventory, bow), "ranged weapon can join the same grid inventory")
	game.equip_item(game.inventory.size() - 1)
	check(game.equipment["weapon"]["name"] == "測試迅捷手弩" and is_equal_approx(game.player.max_hp, 120.0), "ranged swap removes previous weapon health without item loss")
	game.player.mana = game.player.max_mana
	var ranged_mana: float = game.player.mana
	var ranged_hp: float = near_enemy.hp
	game.cast_bolt()
	check(_friendly_count(game) == 3 and is_equal_approx(game.player.mana, ranged_mana - 3.0), "real ranged weapon fires three supported projectiles with one mana payment")
	check(is_equal_approx(game._bolt_skill.cooldown, Rules.interval(bow)) and is_equal_approx(game._bolt_skill.cast_range, Rules.reach(bow)), "weapon speed and range configure actual live skill/projectile runtime")
	for child in game.get_children():
		if child.is_in_group("projectiles") and not child.enemy_owned and not child.is_queued_for_deletion():
			check(is_equal_approx(child.max_distance, Rules.reach(bow)), "projectile travel range matches the equipped weapon")
			child._physics_process(0.12)
	check(near_enemy.hp < ranged_hp, "ranged projectile actually damages the enemy after swapping weapons")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(saved is Dictionary and saved["equipment"]["weapon"]["weapon_class"] == "crossbow" and saved["inventory"].size() == 2, "equipped weapon profile and returned inventory items persist to save")
	game.queue_free()
	print("PHASE5 WEAPON LOOT: %d passed / %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _friendly_count(game) -> int:
	var total: int = 0
	for child in game.get_children():
		if child.is_in_group("projectiles") and not child.enemy_owned and not child.is_queued_for_deletion():
			total += 1
	return total
