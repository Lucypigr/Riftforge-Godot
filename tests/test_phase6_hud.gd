extends SceneTree
## Real-scene HUD checks. This is headless coverage, not a physical phone screenshot test.
const VitalOrb = preload("res://scripts/phase6_vital_orb.gd")
var passed: int = 0
var failed: int = 0

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
	var orb = VitalOrb.new()
	root.add_child(orb)
	orb.set_values(25.0, 100.0)
	check(is_equal_approx(orb.fill_fraction(), 0.25), "orb liquid reflects quarter health")
	orb.set_values(500.0, 100.0)
	check(is_equal_approx(orb.fill_fraction(), 1.0), "orb cannot overfill")
	orb.set_values(-15.0, 100.0)
	check(is_zero_approx(orb.fill_fraction()), "orb cannot fill below zero")
	orb.queue_free()

	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	check(hud._health_orb.name == "HealthOrb" and hud._mana_orb.name == "ManaOrb", "playable scene installs both dedicated vitality orbs")
	check(hud._health_orb.fill_color.r > hud._health_orb.fill_color.b and hud._mana_orb.fill_color.b > hud._mana_orb.fill_color.r, "health orb is red and mana orb is blue")
	check(hud._health_orb.anchor_left == 0.0 and hud._health_orb.anchor_top == 1.0, "desktop health anchored bottom left")
	check(hud._mana_orb.anchor_right == 1.0 and hud._mana_orb.anchor_top == 1.0, "desktop mana anchored bottom right")
	check(hud._radar.game == game and hud._radar.visible, "upper-right minimap uses live game context")
	game.player.hp = game.player.max_hp * 0.25
	game.player.mana = game.player.max_mana * 0.5
	hud._process(0.016)
	check(is_equal_approx(hud._health_orb.fill_fraction(), 0.25), "real player damage updates health liquid")
	check(is_equal_approx(hud._mana_orb.fill_fraction(), 0.5), "real player mana updates blue liquid")
	check(hud._skill_panel.visible and hud._attack_button != null and hud._nova_button != null, "desktop skill bar exposes actual abilities")
	game.player.mana = game.player.max_mana
	game._skill_runtime.advance(10.0)
	game._sync_cooldowns()
	var shots_before: int = _friendly_count(game)
	hud._on_attack_pressed()
	check(_friendly_count(game) == shots_before + 3, "HUD basic attack connects to actual supported projectiles")
	hud._process(0.016)
	check(hud._attack_button.disabled, "basic attack cooldown disables shortcut")
	game._skill_runtime.advance(10.0)
	game._sync_cooldowns()
	hud.toggle_inventory()
	hud._process(0.016)
	check(game.ui_open and hud._attack_button.disabled, "inventory keeps combat shortcuts blocked")
	hud.close_panels()
	check(not game.ui_open, "inventory close restores combat state")
	hud.set_mobile_layout(true)
	check(hud._health_orb.anchor_top == 0.0 and hud._mana_orb.anchor_top == 0.0, "mobile vitality moves above the joystick and attack zone")
	check(hud._health_orb.anchor_left == 0.0 and hud._mana_orb.anchor_right == 1.0, "mobile keeps left/right health and mana separation")
	check(not hud._skill_panel.visible and not hud._radar.visible and not hud._objective_panel.visible, "mobile removes overlapping desktop-only overlays")
	check(hud._health_orb.mouse_filter == Control.MOUSE_FILTER_IGNORE and hud._mana_orb.mouse_filter == Control.MOUSE_FILTER_IGNORE, "both orbs let touch controls receive inputs")
	var controls = game.get_node("MobileControls")
	controls.enabled = true
	controls.surface.visible = true
	game.mobile_active = true
	controls._layout()
	check(hud._mobile_layout and hud._inventory_panel.scale.x <= 1.0, "mobile input controller applies adaptive HUD without breaking inventory scale")
	game.queue_free()
	print("PHASE6 ARPG HUD: %d passed / %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _friendly_count(game) -> int:
	var total: int = 0
	for child in game.get_children():
		if child.is_in_group("projectiles") and not child.enemy_owned and not child.is_queued_for_deletion():
			total += 1
	return total
