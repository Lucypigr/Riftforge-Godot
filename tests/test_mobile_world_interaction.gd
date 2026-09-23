extends SceneTree
## Scene-level mobile world interaction regression for Phase 8.
## Uses the real main scene, real mobile controls, real loot node and real grid inventory.
const Grid = preload("res://scripts/grid_inventory.gd")
const Loot = preload("res://scripts/loot.gd")

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

func sample(slot: String = "gem", label: String = "測試戰利品") -> Dictionary:
	return {
		"name": label, "slot": slot, "rarity": "普通",
		"damage": 0, "hp": 0, "armor": 0.0, "level": 1
	}

func _run() -> void:
	if FileAccess.file_exists("user://riftforge_phase8_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://riftforge_phase8_save.json"))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var controls = game.get_node("MobileControls")
	controls.enabled = true
	controls.surface.visible = true
	controls.surface.size = Vector2(1280, 720)
	game.mobile_active = true

	check(_has_key("interact", KEY_F) and not _has_key("interact", KEY_E), "PC world interaction is F, never E")
	check(_has_key("skill_slot_3", KEY_E), "E remains the fourth PC skill binding")

	game.player.position = Vector3(0, 0.9, 2.0)
	check(not game.can_world_interact() and not controls._has_interaction(), "no interaction when far from a world target")

	game.player.position = game._portal_position + Vector3(0, 0.9, 0)
	check(game.can_world_interact() and controls._has_interaction(), "camp portal is detected semantically on mobile")
	check(game.interaction_action_label() == "傳送" and game.interaction_hint().begins_with("[F]"), "mobile label is semantic while desktop hint remains F")
	_tap_action(controls, 10, "interact")
	check(game.zone == "field", "mobile portal activation enters field")

	game.player.position = game._portal_position + Vector3(0, 0.9, 0)
	check(game.can_world_interact() and game.interaction_action_label() == "傳送", "field return portal is detected")
	_tap_action(controls, 11, "interact")
	check(game.zone == "camp", "mobile portal activation returns to camp")

	var drop = Loot.new()
	drop.initialize(sample("weapon", "手機拾取短劍"))
	drop.position = game.player.position + Vector3(0.2, -0.5, 0)
	game.add_child(drop)
	check(game.can_world_interact() and game.get_interaction_target().get("kind", "") == "loot", "nearby ground loot is detected as a gameplay target")
	check(game.interaction_action_label() == "拾取" and game.interaction_hint().begins_with("[F] 拾取"), "mobile shows pickup without parsing the F hint")
	var before_pickup: int = game.inventory.size()
	_tap_action(controls, 12, "interact")
	check(game.inventory.size() == before_pickup + 1 and drop.is_queued_for_deletion(), "mobile interaction picks real ground loot")
	check(Grid.placed(game.inventory.back()) and Grid.COLS == 18 and Grid.ROWS == 10, "mobile pickup enters the Phase 8 18 by 10 grid")

	game.inventory.clear()
	for i in range(180):
		check(Grid.try_add(game.inventory, sample("gem", "滿包格%d" % i)), "fill grid cell %d" % i)
	check(game.inventory.size() == 180 and Grid.occupied_cells(game.inventory) == 180, "Phase 8 bag reaches exactly 180 occupied cells")
	var full_drop = Loot.new()
	full_drop.initialize(sample("gem", "滿包保留物"))
	full_drop.position = game.player.position + Vector3(0.25, -0.5, 0)
	game.add_child(full_drop)
	_tap_action(controls, 13, "interact")
	check(game.inventory.size() == 180 and not full_drop.is_queued_for_deletion(), "full bag leaves ground loot intact without duplication")
	check(game.hud._notice.text.contains("背包空間不足"), "full bag reports insufficient space")

	# Free one cell so an accidental UI interaction would be observable.
	game.inventory.pop_back()
	var count_with_space: int = game.inventory.size()
	var joy_center: Vector2 = controls._center("joy")
	_touch(controls, 20, joy_center, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 20
	drag.position = joy_center + Vector2(60, 0)
	controls._input(drag)
	check(game.mobile_move.x > 0.9, "joystick touch owns movement before UI opens")
	_touch(controls, 21, controls._center("attack"), true)
	check(controls.joy_id == 20 and controls.attack_id == 21, "movement and attack keep independent touch IDs")
	var friendly_after_attack := _friendly_count(game)
	_tap_action(controls, 22, "inventory")
	check(game.ui_open and controls.joy_id == -1 and controls.attack_id == -1 and game.mobile_move.is_zero_approx(), "opening inventory cancels active combat touches")
	_tap_action(controls, 23, "interact")
	_touch(controls, 24, controls._center("attack"), true)
	_touch(controls, 25, controls._center("joy"), true)
	controls._process(0.016)
	check(game.inventory.size() == count_with_space and not full_drop.is_queued_for_deletion(), "inventory UI blocks mobile world interaction")
	check(_friendly_count(game) == friendly_after_attack and game.mobile_move.is_zero_approx(), "inventory UI blocks combat and movement touches")

	game.hud.close_panels()
	game.hud.toggle_gems()
	check(game.ui_open and not game.can_world_interact(), "gem and skill-assignment UI disables world interaction availability")
	_tap_action(controls, 26, "interact")
	check(game.inventory.size() == count_with_space and not full_drop.is_queued_for_deletion(), "gem UI blocks mobile pickup")
	game.hud.close_panels()
	check(not game.ui_open and game.can_world_interact(), "closing UI restores world interaction")
	_tap_action(controls, 27, "interact")
	check(game.inventory.size() == count_with_space + 1 and full_drop.is_queued_for_deletion(), "mobile pickup resumes after UI closes")

	# PC F path: action binding drives the same semantic interaction.
	game.mobile_active = false
	game._enter_zone("camp")
	game.player.position = game._portal_position + Vector3(0, 0.9, 0)
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	check(game.zone == "field", "PC F action near portal performs the real zone transition")

	# E stays a skill input in Phase 7/8 and must never activate nearby world targets.
	game.assign_skill_slot(3, "shock_nova")
	game._skill_runtime.advance(10.0)
	game._sync_cooldowns()
	game.player.mana = game.player.max_mana
	game.player.position = game._portal_position + Vector3(0, 0.9, 0)
	var zone_before_e: String = game.zone
	Input.action_press("skill_slot_3")
	await process_frame
	Input.action_release("skill_slot_3")
	await process_frame
	check(game.zone == zone_before_e and game.skill_cooldown("shock_nova") > 0.0, "E executes only its assigned skill and does not activate the portal")

	var pc_drop = Loot.new()
	pc_drop.initialize(sample("gem", "PC F 拾取"))
	pc_drop.position = game.player.position + Vector3(0.2, -0.5, 0)
	game.add_child(pc_drop)
	var pc_before: int = game.inventory.size()
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	check(game.inventory.size() == pc_before + 1 and pc_drop.is_queued_for_deletion(), "PC F action picks up nearby loot through the shared target path")

	var e_drop = Loot.new()
	e_drop.initialize(sample("gem", "E 不拾取"))
	e_drop.position = game.player.position + Vector3(0.2, -0.5, 0)
	game.add_child(e_drop)
	game._skill_runtime.advance(10.0)
	game._sync_cooldowns()
	Input.action_press("skill_slot_3")
	await process_frame
	Input.action_release("skill_slot_3")
	await process_frame
	check(not e_drop.is_queued_for_deletion(), "E near loot does not trigger world pickup")

	print("MOBILE WORLD INTERACTION: %d passed / %d failed" % [passed, failed])
	game.queue_free()
	quit(0 if failed == 0 else 1)

func _tap_action(controls, finger_id: int, action: String) -> void:
	_touch(controls, finger_id, controls._center(action), true)
	_touch(controls, finger_id, controls._center(action), false)

func _touch(controls, finger_id: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger_id
	event.position = position
	event.pressed = pressed
	controls._input(event)

func _has_key(action: String, code: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == code:
			return true
	return false

func _friendly_count(game) -> int:
	var total := 0
	for node in game.get_children():
		if node.is_in_group("projectiles") and not node.enemy_owned and not node.is_queued_for_deletion():
			total += 1
	return total
