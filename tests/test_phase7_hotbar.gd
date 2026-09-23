extends SceneTree
## Phase 7 PC hotbar regression. Headless input-map checks are not a physical mouse/keyboard test.
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

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.installed_active_gems = ["ember_bolt", "shock_nova"]
	game.skill_slots = ["ember_bolt", "shock_nova", "", "", "", ""]

	check(game.SKILL_ACTIONS.size() == 6, "six PC skill actions exist")
	check(game.skill_binding_name(0) == "滑鼠左鍵" and game.skill_binding_name(1) == "滑鼠右鍵", "mouse left and right are the first two skill slots")
	check(game.skill_binding_name(2) == "Q" and game.skill_binding_name(3) == "E" and game.skill_binding_name(4) == "R" and game.skill_binding_name(5) == "T", "Q E R T are the remaining skill slots")
	check(_has_mouse("skill_slot_0", MOUSE_BUTTON_LEFT) and _has_mouse("skill_slot_1", MOUSE_BUTTON_RIGHT), "real mouse bindings are mapped to skill slots")
	check(_has_key("skill_slot_2", KEY_Q) and _has_key("skill_slot_3", KEY_E) and _has_key("skill_slot_4", KEY_R) and _has_key("skill_slot_5", KEY_T), "real keyboard bindings are mapped to Q E R T")
	check(_has_key("interact", KEY_F) and not _has_key("interact", KEY_E), "interaction moved to F so E is exclusively a skill key")
	check(InputMap.action_get_events("attack").is_empty() and InputMap.action_get_events("nova").is_empty(), "legacy hard-wired mouse attack bindings are removed")

	var hud = game.hud
	check(hud._skill_buttons.size() == 6 and hud._skill_panel.visible, "desktop HUD exposes six icon skill slots")
	hud._process(0.016)
	var icon_only := true
	for button in hud._skill_buttons:
		icon_only = icon_only and button.text == "" and button.icon != null
	check(icon_only, "visible bottom hotbar uses icons only with no left/right or key text")
	check(game.skill_gem(0) == "ember_bolt" and game.skill_gem(1) == "shock_nova", "default loadout starts with ember and nova then empty slots")
	check(not game.assign_skill_slot(2, "scatter"), "support gems cannot occupy the skill hotbar")

	check(game.assign_skill_slot(2, "ember_bolt"), "installed active gem can move to any slot")
	check(game.skill_gem(2) == "ember_bolt" and game.skill_gem(0) == "", "moving one installed gem clears its previous slot instead of duplicating it")
	game.player.mana = game.player.max_mana
	game._skill_runtime.advance(10.0)
	game._sync_cooldowns()
	var before := _friendly_count(game)
	check(game.cast_skill_slot(2), "reassigned ember gem casts from its new slot")
	check(_friendly_count(game) == before + 3, "reassigned ember gem uses the real supported projectile path")
	check(not game.cast_skill_slot(0), "empty skill slot does not cast")

	game._skill_runtime.advance(10.0)
	game._sync_cooldowns()
	check(game.assign_skill_slot(3, "shock_nova"), "nova gem can be moved to E slot")
	check(game.skill_gem(3) == "shock_nova" and game.skill_gem(1) == "", "nova move also preserves one-gem-one-slot behavior")
	game.player.mana = game.player.max_mana
	check(game.cast_skill_slot(3), "E slot dispatches the assigned nova gem")
	check(game.skill_cooldown("shock_nova") > 0.0, "assigned nova starts its real cooldown")

	game._skill_runtime.advance(10.0)
	game._sync_cooldowns()
	hud.toggle_inventory()
	check(game.ui_open and not game.cast_skill_slot(2), "open inventory blocks hotbar casting")
	hud.close_panels()
	check(not game.ui_open, "closing panels restores combat input")

	hud.set_mobile_layout(true)
	check(not hud._skill_panel.visible, "mobile keeps its existing touch layout instead of showing the PC hotbar")
	game.queue_free()
	print("PHASE7 GEM HOTBAR: %d passed / %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _has_key(action: String, code: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == code:
			return true
	return false

func _has_mouse(action: String, button: MouseButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return true
	return false

func _friendly_count(game) -> int:
	var total := 0
	for child in game.get_children():
		if child.is_in_group("projectiles") and not child.enemy_owned and not child.is_queued_for_deletion():
			total += 1
	return total
