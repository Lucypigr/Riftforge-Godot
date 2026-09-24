extends SceneTree
const Gems = preload("res://scripts/phase10_gem_system.gd")
const Enemy = preload("res://scripts/enemy.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS " + message)
	else:
		failed += 1
		push_error("FAIL " + message)

func _instances(ids: Array) -> Array:
	var result: Array = []
	for i in range(ids.size()):
		result.append(Gems.make_instance(str(ids[i]), i))
	return result

func _links(count: int) -> Array:
	var result: Array = []
	for i in range(maxi(0, count - 1)):
		result.append([i, i + 1])
	return result

func _set_state(game, ids: Array, links: Array = []) -> void:
	game.set_phase10_socket_state(_instances(ids), links)
	game._skill_runtime.advance(100.0)
	game._sync_cooldowns()
	game.player.mana = game.player.max_mana

func _clear_combat_nodes(game) -> void:
	for group in ["enemies", "projectiles", "combat_fx"]:
		for node in get_nodes_in_group(group):
			if is_instance_valid(node):
				node.queue_free()

func _enemy(game, offset: Vector3):
	var e = Enemy.new()
	e.initialize(game, "hunter", false)
	game.add_child(e)
	e.position = game.player.position + offset
	return e

func _find_script_child(game, suffix: String):
	for child in game.get_children():
		var script = child.get_script()
		if script != null and script.resource_path.ends_with(suffix) and not child.is_queued_for_deletion():
			return child
	return null

func _run() -> void:
	if FileAccess.file_exists("user://riftforge_phase8_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://riftforge_phase8_save.json"))

	# Definition catalogue.
	for id in ["ember_bolt","shock_nova","frost_shard","arc_spark","rift_cleave","cinder_field"]:
		check(Gems.is_active(id), "%s is an active GemDefinition" % id)
	for id in ["scatter","pierce","faster_projectiles","added_fire","increased_area","faster_attacks","chain_support","added_cold"]:
		check(Gems.is_support(id), "%s is a support GemDefinition" % id)
	check(Gems.definition("frost_shard").get("damage_type") == "cold", "Frost Shard has cold damage data")
	check("duration" in Gems.definition("cinder_field").get("tags", []), "Cinder Field carries duration tag")
	check("attack" in Gems.definition("rift_cleave").get("tags", []), "Rift Cleave carries attack tag")

	# Compatibility matrix.
	var cleave: Dictionary = Gems.definition("rift_cleave")
	var ember: Dictionary = Gems.definition("ember_bolt")
	var nova: Dictionary = Gems.definition("shock_nova")
	var field: Dictionary = Gems.definition("cinder_field")
	var frost: Dictionary = Gems.definition("frost_shard")
	check(Gems.compatible(cleave, Gems.definition("faster_attacks")), "Faster Attacks supports melee attack")
	check(not Gems.compatible(ember, Gems.definition("faster_attacks")), "Faster Attacks rejects spell projectile")
	check(not Gems.compatible(nova, Gems.definition("faster_attacks")), "Faster Attacks rejects nova spell")
	check(Gems.compatible(ember, Gems.definition("chain_support")), "Chain supports Ember Bolt projectile")
	check(Gems.compatible(frost, Gems.definition("chain_support")), "Chain supports Frost Shard projectile")
	check(not Gems.compatible(cleave, Gems.definition("chain_support")), "Chain rejects melee")
	check(not Gems.compatible(field, Gems.definition("chain_support")), "Chain rejects ground duration skill")
	check(Gems.compatible(nova, Gems.definition("increased_area")), "Increased Area supports Nova")
	check(Gems.compatible(cleave, Gems.definition("increased_area")), "Increased Area supports Cleave")
	check(Gems.compatible(field, Gems.definition("increased_area")), "Increased Area supports Ground Area")
	check(not Gems.compatible(ember, Gems.definition("increased_area")), "Increased Area rejects basic projectile")
	check(not Gems.compatible(field, Gems.definition("pierce")), "Ground DoT plus Pierce is rejected")
	check(not Gems.compatible(nova, Gems.definition("faster_projectiles")), "Nova plus Faster Projectiles is rejected")

	# Socket graph and pipeline.
	var multi: Array = _instances(["ember_bolt","frost_shard","faster_projectiles"])
	var multi_links: Array = _links(3)
	check(Gems.connected_component(0, multi, multi_links).size() == 3, "SocketGraph finds complete connected component")
	check("faster_projectiles" in Gems.connected_support_ids("ember_bolt", multi, multi_links), "support reaches first active in shared group")
	check("faster_projectiles" in Gems.connected_support_ids("frost_shard", multi, multi_links), "same support reaches second compatible active in group")
	var unlinked: Dictionary = Gems.resolve("frost_shard", _instances(["frost_shard","faster_projectiles"]), [])
	check(is_equal_approx(float(unlinked["projectile_speed"]), 18.0), "unlinked support has no effect")
	var fast_frost: Dictionary = Gems.resolve("frost_shard", _instances(["frost_shard","faster_projectiles"]), [[0,1]])
	check(float(fast_frost["projectile_speed"]) > 18.0, "Faster Projectiles increases actual travel speed")
	check(is_equal_approx(float(fast_frost["cast_range"]), 24.0), "Faster Projectiles does not increase fixed world range")
	check(int(fast_frost["mana_cost"]) == 8, "support mana multiplier changes resolved mana cost")
	var duplicate_chain: Dictionary = Gems.resolve("ember_bolt", _instances(["ember_bolt","chain_support","chain_support"]), [[0,1],[1,2]])
	check(int(duplicate_chain["chain"]) == 2, "duplicate same support applies only once")
	check((duplicate_chain["supports"] as Array).count("chain_support") == 1, "duplicate support is deduplicated in ResolvedSkill")
	var pierce: Dictionary = Gems.resolve("ember_bolt", _instances(["ember_bolt","pierce"]), [[0,1]])
	check(int(pierce["pierce"]) == 1, "Pierce support adds a real pierce")
	var area_cleave: Dictionary = Gems.resolve("rift_cleave", _instances(["rift_cleave","faster_attacks","increased_area"]), [[0,1],[1,2]])
	check(float(area_cleave["interval"]) < float(cleave["interval"]), "Faster Attacks lowers attack interval")
	check(float(area_cleave["aoe_radius"]) > float(cleave["aoe_radius"]), "Increased Area expands cleave radius")
	var area_field: Dictionary = Gems.resolve("cinder_field", _instances(["cinder_field","increased_area"]), [[0,1]])
	check(float(area_field["aoe_radius"]) > float(field["aoe_radius"]) and float(area_field["duration"]) == float(field["duration"]), "Increased Area expands ground field without deleting duration")
	var added_fire: Dictionary = Gems.resolve("ember_bolt", _instances(["ember_bolt","added_fire"]), [[0,1]])
	check(float((added_fire["damage_components"] as Dictionary).get("fire", 0.0)) > float(ember["base_damage"]), "Added Fire contributes through resolved typed damage")
	var added_cold: Dictionary = Gems.resolve("ember_bolt", _instances(["ember_bolt","added_cold"]), [[0,1]])
	check((added_cold["damage_components"] as Dictionary).has("cold"), "Added Cold contributes a cold damage component")
	check(not (added_cold["status_effects"] as Array).is_empty(), "Added Cold creates a resolved chill/slow status")

	# Real playable scene.
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.get_script().resource_path.ends_with("phase10_game.gd"), "playable scene uses Phase 10 gameplay layer")
	check(game.installed_skill_gems().size() == 6, "six active gems are installed from GemInstance data")
	check(not game.assign_skill_slot(0, "chain_support"), "support gem cannot enter hotbar")
	check(game.skill_tooltip("frost_shard").contains("Mana:"), "tooltip reads final ResolvedSkill values")

	# Gem removal invalidates hotbar.
	_set_state(game, ["frost_shard"], [])
	check(game.assign_skill_slot(0, "frost_shard"), "installed active can be assigned")
	check(game.remove_gem("frost_shard"), "installed active can be removed")
	check(game.skill_gem(0).is_empty(), "removing active clears ghost hotbar assignment")

	# Frost projectile -> actual Combat V2 damage + slow.
	_clear_combat_nodes(game)
	_set_state(game, ["frost_shard"], [])
	game.skill_slots = ["frost_shard","","","","",""]
	var frost_enemy = _enemy(game, Vector3(2.0, 0, 0))
	var frost_hp: float = frost_enemy.hp
	check(game.cast_active_gem("frost_shard", Vector3.RIGHT), "Frost Shard cast succeeds")
	var frost_projectile = _find_script_child(game, "phase10_projectile.gd")
	check(frost_projectile != null, "Frost Shard creates resolved projectile runtime")
	if frost_projectile != null:
		frost_projectile._resolve_hit(frost_enemy, frost_enemy.global_position)
	check(frost_enemy.hp < frost_hp, "Frost projectile deals real resolved damage")
	check(frost_enemy.current_move_speed() < frost_enemy.move_speed, "Frost hit applies movement slow gameplay")

	# Chain projectile hit bookkeeping.
	_clear_combat_nodes(game)
	_set_state(game, ["arc_spark","chain_support"], [[0,1]])
	var chain_resolved: Dictionary = game.resolved_skill("arc_spark")
	check(int(chain_resolved["chain"]) == 4, "Arc Spark base chain plus support resolves to four chains")
	var first = _enemy(game, Vector3(2.0, 0, 0))
	var second = _enemy(game, Vector3(5.0, 0, 0))
	check(game.cast_active_gem("arc_spark", Vector3.RIGHT), "Arc Spark cast succeeds")
	var chain_projectile = _find_script_child(game, "phase10_projectile.gd")
	if chain_projectile != null:
		var first_hp: float = first.hp
		chain_projectile._resolve_hit(first, first.global_position)
		check(first.hp < first_hp, "first chain target takes damage")
		check(first.get_instance_id() in chain_projectile._hit_ids, "first chain target is recorded")
		var desired: Vector3 = (second.global_position - chain_projectile.global_position).normalized()
		check(chain_projectile.direction.dot(desired) > 0.85, "chain retargets only after first legal hit")
		var second_hp: float = second.hp
		chain_projectile._resolve_hit(second, second.global_position)
		check(second.hp < second_hp, "second chain target takes decayed follow-up damage")
		check(chain_projectile._hit_ids.count(first.get_instance_id()) == 1, "chain bookkeeping never repeats the same target")
	else:
		check(false, "Arc Spark projectile exists")
		check(false, "Arc Spark first target bookkeeping available")
		check(false, "Arc Spark retarget available")
		check(false, "Arc Spark second hit available")
		check(false, "Arc Spark duplicate prevention available")

	# Pierce survives first hit.
	_clear_combat_nodes(game)
	_set_state(game, ["ember_bolt","pierce"], [[0,1]])
	var p1 = _enemy(game, Vector3(2.0,0,0))
	var p2 = _enemy(game, Vector3(4.0,0,0))
	check(game.cast_active_gem("ember_bolt", Vector3.RIGHT), "Ember plus Pierce cast succeeds")
	var pierce_projectile = _find_script_child(game, "phase10_projectile.gd")
	if pierce_projectile != null:
		pierce_projectile._resolve_hit(p1, p1.global_position)
		check(not pierce_projectile.is_queued_for_deletion() and pierce_projectile.pierce_remaining == 0, "Pierce keeps projectile alive through first target")
		pierce_projectile._resolve_hit(p2, p2.global_position)
		check(pierce_projectile.is_queued_for_deletion(), "Pierce projectile ends after allowed extra target")
	else:
		check(false, "Pierce projectile exists")
		check(false, "Pierce lifecycle available")

	# Directional melee + Faster Attacks + Increased Area.
	_clear_combat_nodes(game)
	_set_state(game, ["rift_cleave","faster_attacks","increased_area"], [[0,1],[1,2]])
	var front = _enemy(game, Vector3(3.7, 0, 0))
	var back = _enemy(game, Vector3(-2.0, 0, 0))
	var front_hp: float = front.hp
	var back_hp: float = back.hp
	check(game.cast_active_gem("rift_cleave", Vector3.RIGHT), "Rift Cleave cast succeeds")
	check(front.hp < front_hp, "increased cleave radius reaches real front target beyond base radius")
	check(is_equal_approx(back.hp, back_hp), "directional cleave does not hit enemy behind player")
	check(game.skill_cooldown("rift_cleave") > 0.0 and game.skill_cooldown("rift_cleave") <= float(area_cleave["interval"]), "real melee cooldown uses resolved faster attack interval")

	# Persistent ground DoT.
	_clear_combat_nodes(game)
	_set_state(game, ["cinder_field","increased_area"], [[0,1]])
	var ground_target = _enemy(game, Vector3(7.0, 0, 0))
	var ground_hp: float = ground_target.hp
	check(game.cast_active_gem("cinder_field", Vector3.RIGHT), "Cinder Field cast succeeds")
	var ground = _find_script_child(game, "phase10_ground_area.gd")
	check(ground != null and ground.remaining > 0.0, "ground area exists for a real duration")
	if ground != null:
		ground._physics_process(0.5)
		check(ground_target.hp < ground_hp, "ground area applies periodic Fire DoT")
		check(ground.remaining > 0.0 and not ground.is_queued_for_deletion(), "ground DoT is not incorrectly cleared after first tick")
	else:
		check(false, "ground area DoT tick available")
		check(false, "ground area persists")

	# Failed cast invariants.
	_clear_combat_nodes(game)
	_set_state(game, ["frost_shard","faster_projectiles"], [[0,1]])
	game.player.mana = 0.0
	var mana_before: float = game.player.mana
	var cooldown_before: float = game.skill_cooldown("frost_shard")
	check(not game.cast_active_gem("frost_shard", Vector3.RIGHT), "insufficient mana rejects resolved cast")
	check(is_equal_approx(game.player.mana, mana_before), "failed cast spends no mana")
	check(is_equal_approx(game.skill_cooldown("frost_shard"), cooldown_before), "failed cast starts no cooldown")

	# Mobile hold -> aim -> release, with no cast on press.
	game.player.mana = game.player.max_mana
	game._skill_runtime.advance(100.0)
	game.skill_slots = ["frost_shard","shock_nova","","","",""]
	game.mobile_active = true
	var controls = game.get_node("MobileControls")
	controls.enabled = true
	controls.surface.visible = true
	controls.surface.size = Vector2(1280,720)
	var touch := InputEventScreenTouch.new()
	touch.index = 70
	touch.position = controls._center("attack")
	touch.pressed = true
	var before_mobile: int = _projectile_count(game)
	controls._input(touch)
	check(_projectile_count(game) == before_mobile and controls.attack_id == 70, "mobile press enters aim state without casting")
	var drag := InputEventScreenDrag.new()
	drag.index = 70
	drag.position = controls._center("attack") + Vector2(80, 0)
	controls._input(drag)
	check(controls.dragging_aim and game.aim_direction.x > 0.9, "mobile drag updates projectile direction preview")
	touch.pressed = false
	controls._input(touch)
	check(_projectile_count(game) > before_mobile and controls.attack_id == -1, "mobile release performs the cast")
	check(game.skill_preview_kind(0) == "projectile", "mobile preview derives from resolved behavior")
	game.skill_slots[0] = "rift_cleave"
	check(game.skill_preview_kind(0) == "melee_cone", "mobile preview supports melee arc")
	game.skill_slots[0] = "cinder_field"
	check(game.skill_preview_kind(0) == "ground_area", "mobile preview supports ground target area")

	# Save/load rebuilds from definitions + socket state, not a serialized RuntimeSkill.
	game.mobile_active = false
	var saved_instances: Array = _instances(["frost_shard","chain_support"])
	saved_instances[0]["level"] = 3
	game.set_phase10_socket_state(saved_instances, [[0,1]])
	game.skill_slots = ["frost_shard","","","","",""]
	game.save_progress()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(saved is Dictionary and saved.get("gem_instances") is Array and not saved.has("resolved_skill"), "save stores GemInstance/socket state, not RuntimeSkill")
	game.queue_free()
	await process_frame
	var loaded = load("res://scenes/main.tscn").instantiate()
	root.add_child(loaded)
	await process_frame
	check(int(loaded.gem_instances[0].get("level", 0)) == 3, "GemInstance level survives save/load")
	check(loaded.socket_links == [[0,1]], "socket links survive save/load")
	check(loaded.skill_gem(0) == "frost_shard", "hotbar assignment survives save/load")
	check(int(loaded.resolved_skill("frost_shard").get("chain", 0)) == 2, "ResolvedSkill is rebuilt from loaded definition plus links")
	loaded.queue_free()

	print("PHASE10 GEM EXPANSION: %d passed / %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _projectile_count(game) -> int:
	var total := 0
	for child in game.get_children():
		if child.is_in_group("projectiles") and not child.is_queued_for_deletion():
			total += 1
	return total
