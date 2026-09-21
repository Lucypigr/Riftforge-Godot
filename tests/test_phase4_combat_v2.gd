extends SceneTree
## Phase 4 original combat mathematics plus actual playable-scene integration.
const Resolver = preload("res://research/phase4/combat_resolver_v2.gd")
const SkillDefinition = preload("res://research/phase2/skill_definition.gd")
const SkillRuntime = preload("res://research/phase2/skill_runtime.gd")
const Enemy = preload("res://scripts/enemy.gd")
var passed: int = 0
var failed: int = 0

func expect(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS " + description)
	else:
		failed += 1
		push_error("FAIL " + description)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fire := SkillDefinition.new()
	fire.skill_id = &"phase4_fire"
	fire.base_damage = 100.0
	fire.damage_type = &"fire"
	fire.mana_cost = 1.0
	var target: Dictionary = {"hp": 1000.0, "defensive_ability": 1000.0, "position": Vector3.RIGHT,
		"resistances": {"fire": 0.25}, "armor_rating": 0.0}
	expect(is_equal_approx(Resolver.pth(1000.0, 1000.0), 90.0), "equal attack and defense yield 90 rating")
	expect(Resolver.pth(1200.0, 1000.0) > 90.0, "offensive rating boosts accuracy")
	expect(Resolver.pth(1000.0, 1200.0) < 90.0, "defensive rating lowers accuracy")
	expect(Resolver.pth(1000000.0, 1.0) <= 135.0 and Resolver.pth(1.0, 1000000.0) >= 55.0, "ratings have safe bounds")
	expect(is_equal_approx(Resolver.critical_multiplier(90.0), 1.0), "baseline has no critical multiplier")
	expect(is_equal_approx(Resolver.critical_multiplier(106.0), 1.2), "critical tier crosses 105 rating")
	expect(is_equal_approx(Resolver.critical_multiplier(135.0), 1.5), "maximum critical tier is bounded")
	var basic: Dictionary = Resolver.resolve(fire, target, {}, 0.2, 0.9)
	expect(basic.get("ok", false) and basic.get("hit", false) and int(basic["damage"]) == 75, "typed fire resistance affects normal hit")
	var missed: Dictionary = Resolver.resolve(fire, {"hp": 1000.0, "defensive_ability": 2000.0}, {}, 0.99, 0.0)
	expect(missed.get("ok", false) and not missed.get("hit", true) and int(missed["damage"]) == 0, "miss does not cause damage")
	expect(missed.get("feedback", {}).get("type", "") == "miss", "miss feedback is explicit")
	var crit_target: Dictionary = {"hp": 1000.0, "defensive_ability": 1000.0}
	var critical: Dictionary = Resolver.resolve(fire, crit_target, {"offensive_ability": 1500.0}, 0.2, 0.0)
	expect(critical.get("critical", false) and int(critical["damage"]) == 120, "OA influences real critical hit and damage")
	var normal: Dictionary = Resolver.resolve(fire, crit_target, {"offensive_ability": 1500.0}, 0.2, 0.99)
	expect(not normal.get("critical", true) and int(normal["damage"]) == 100, "same rating may yield normal damage with separate critical roll")
	var split_target: Dictionary = {"hp": 1000.0, "defensive_ability": 1000.0,
		"armor_rating": 50.0, "armor_absorption": 0.7}
	var split: Dictionary = Resolver.resolve(fire, split_target, {"flat_damage": 40.0,
		"physical_to_fire": 0.5, "type_increased_percent": {"fire": 50.0}}, 0.1, 0.99)
	expect(int(split["damage"]) == 186, "conversion occurs before fire bonus; physical portion uses armor")
	expect(is_equal_approx(float(split["damage_by_type"]["physical"]), 6.0), "armor applies to physical component only")
	expect(is_equal_approx(float(split["damage_by_type"]["fire"]), 180.0), "fire bonus excludes remaining physical component")
	expect(int(Resolver.resolve(fire, split_target, {"flat_damage": 40.0, "physical_to_fire": 2.0}, 0.1, 0.99)["damage"]) == 140, "conversion rate clamps to 100 percent")
	var physical := SkillDefinition.new()
	physical.skill_id = &"phase4_physical"
	physical.damage_type = &"physical"
	physical.base_damage = 100.0
	expect(is_equal_approx(Resolver.mitigate_physical(100.0, 50.0, 0.7), 65.0), "fixed armor absorption differs from percent armor")
	expect(int(Resolver.resolve(physical, split_target, {}, 0.1, 0.99)["damage"]) == 65, "physical skill actually uses flat armor")
	expect(Resolver.mitigate_physical(10.0, 999.0, 1.0) == 0.0, "armor cannot produce negative damage")
	var area := SkillDefinition.new()
	area.skill_id = &"phase4_area"
	area.delivery = "area"
	area.radius = 4.0
	area.base_damage = 20.0
	var guaranteed: Dictionary = Resolver.resolve(area, {"hp": 100.0, "defensive_ability": 1000000.0}, {}, 0.99, 0.99)
	expect(guaranteed.get("hit", false), "area skill cannot miss even against high defence")
	expect(not Resolver.resolve(fire, {"hp": 0.0}).get("ok", true), "dead targets rejected")
	var runtime = SkillRuntime.new(100.0)
	expect(not runtime.use_combat_v2, "legacy damage remains default for old tests")
	var legacy: Dictionary = runtime.resolve_projectile_hit(fire, target, {}, 0.99)
	expect(int(legacy["damage"]) == 100, "legacy compatibility ignores new typed resistance dictionary")
	runtime.use_combat_v2 = true
	# This assertion tests typed resistance selection, not accuracy. Misses are tested above.
	# Disable accuracy only for this call; live attacks retain their normal hit rolls.
	var converted: Dictionary = runtime.resolve_projectile_hit(fire, target, {"can_miss": false}, 0.99)
	expect(int(converted["damage"]) == 75, "same shared runtime selects V2 typed resistance")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	expect(game._skill_runtime.use_combat_v2, "actual playable scene enables V2")
	expect(str(game._nova_skill.damage_type) == "lightning", "nova uses distinct lightning damage type")
	game.aim_direction = Vector3.RIGHT
	game.player.mana = game.player.max_mana
	var enemy = Enemy.new()
	enemy.initialize(game, "hunter")
	enemy.defensive_ability = 1.0
	enemy.hp = 500.0
	enemy.max_hp = 500.0
	enemy.position = game.player.position + Vector3(3.0, -0.2, 0.0)
	game.add_child(enemy)
	var hp_before: float = enemy.hp
	var mana_before: float = game.player.mana
	game.cast_bolt()
	var volley: Array = []
	for child in game.get_children():
		if child.is_in_group("projectiles") and not child.enemy_owned and not child.is_queued_for_deletion():
			volley.append(child)
	expect(volley.size() == 3, "real gem supports still create 3 projectiles")
	expect(is_equal_approx(game.player.mana, mana_before - 3.0), "one volley charges mana once")
	for bolt in volley:
		if is_instance_valid(bolt) and not bolt.is_queued_for_deletion():
			bolt._physics_process(0.2)
	expect(enemy.hp < hp_before, "real collision routes V2 damage to an enemy node")
	expect(enemy.hp > 0.0, "high-health integration dummy stays alive")
	game.queue_free()
	print("PHASE4 COMBAT V2: %d passed / %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
