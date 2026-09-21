extends SceneTree
## Run with: godot --headless --path . --script res://tests/test_mobile_inputs.gd
## This verifies game state and touch-button handlers, not physical iPhone rendering.

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var game = main_scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var controls = game.get_node("MobileControls")
	var failures := 0
	failures += _check("starts in camp", game.zone == "camp")
	failures += _check("player and control nodes exist", is_instance_valid(game.player) and is_instance_valid(controls.surface))

	# A press on the actual attack button must cast even while standing in camp.
	game.player.mana = game.player.max_mana
	game._bolt_cd = 0.0
	var before_attack: float = game.player.mana
	controls._start_touch(101, controls._center("attack"))
	failures += _check("camp attack consumes mana", game.player.mana < before_attack)
	failures += _check("camp attack starts cooldown", game._bolt_cd > 0.0)
	controls._end_touch(101)

	# The area skill intentionally fires on touch release, not press.
	game.player.mana = game.player.max_mana
	game._nova_cd = 0.0
	var before_nova: float = game.player.mana
	controls._start_touch(102, controls._center("nova"))
	failures += _check("nova press is armed", controls.nova_id == 102 and game.player.mana == before_nova)
	controls._end_touch(102)
	failures += _check("camp nova release consumes mana", game.player.mana < before_nova)
	failures += _check("camp nova release starts cooldown", game._nova_cd > 0.0)

	# Opening a menu must not allow mobile attacks through the UI.
	game.ui_open = true
	game._bolt_cd = 0.0
	game.player.mana = game.player.max_mana
	var before_menu: float = game.player.mana
	controls._start_touch(103, controls._center("attack"))
	failures += _check("open menu blocks attack", game.player.mana == before_menu and game._bolt_cd == 0.0)
	game.ui_open = false

	# Normal field combat still works after enabling camp skill practice.
	game._enter_zone("field")
	game._bolt_cd = 0.0
	game.player.mana = game.player.max_mana
	var before_field: float = game.player.mana
	controls._start_touch(104, controls._center("attack"))
	failures += _check("field attack still works", game.player.mana < before_field and game._bolt_cd > 0.0)
	controls._end_touch(104)

	if failures == 0:
		print("MOBILE INPUT TEST PASSED: 9 checks")
	else:
		printerr("MOBILE INPUT TEST FAILED: %d check(s)" % failures)
	quit(0 if failures == 0 else 1)

func _check(label: String, passed: bool) -> int:
	if passed:
		print("PASS: ", label)
		return 0
	printerr("FAIL: ", label)
	return 1
