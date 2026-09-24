extends SceneTree
## Simulate Godot screen events through the actual mobile input handler (not just its helpers).
## This verifies multi-touch ownership, but real iOS browser testing is still required.
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var controls = game.get_node("MobileControls")
	controls.enabled = true
	controls.surface.visible = true
	game.mobile_active = true
	game.player.mana = 80.0
	game._skill_runtime.advance(10.0)
	game._sync_cooldowns()
	# This regression owns its hotbar fixture. Earlier Phase 7 tests intentionally
	# move the active gems and persist that state in the shared user:// save.
	# Keep this test focused on independent touch ownership and release-to-cast.
	game.skill_slots = ["ember_bolt", "shock_nova", "", "", "", ""]
	var joy_center: Vector2 = controls._center("joy")
	var attack_center: Vector2 = controls._center("attack")
	var initial: int = _friendly_count(game)
	_touch(controls, 1, joy_center, true)
	_check("joystick captures first finger", controls.joy_id == 1)
	_check("joystick touch does not fire", _friendly_count(game) == initial)
	var drag = InputEventScreenDrag.new()
	drag.index = 1
	drag.position = joy_center + Vector2(60.0, 0.0)
	controls._input(drag)
	_check("joystick drag moves character input", game.mobile_move.x > 0.9)
	_check("joystick drag still does not fire", _friendly_count(game) == initial)
	_touch(controls, 2, attack_center, true)
	_check("second finger belongs to attack independently", controls.joy_id == 1 and controls.attack_id == 2)
	_check("attack hold does not cast before release", _friendly_count(game) == initial)
	_check("aiming does not cancel moving", game.mobile_move.x > 0.9)
	_touch(controls, 2, attack_center, false)
	_check("attack release casts and preserves joystick ownership", _friendly_count(game) > initial and controls.attack_id == -1 and controls.joy_id == 1)
	_touch(controls, 1, joy_center, false)
	_check("joystick release stops movement", controls.joy_id == -1 and game.mobile_move.is_zero_approx())
	print("PHASE2 MULTITOUCH: %d passed / %d failed" % [passed, failed])
	game.queue_free()
	quit(0 if failed == 0 else 1)

func _touch(controls, finger_id: int, position: Vector2, pressed: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.index = finger_id
	event.position = position
	event.pressed = pressed
	controls._input(event)

func _friendly_count(game) -> int:
	var count: int = 0
	for node in game.get_children():
		if node.is_in_group("projectiles") and not node.enemy_owned and not node.is_queued_for_deletion():
			count += 1
	return count

func _check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
