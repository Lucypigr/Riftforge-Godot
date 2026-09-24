extends SceneTree
## Real gameplay scene: failed skills explain why and cannot spend mana or spawn attacks.
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.mobile_active = true
	game.player.mana = 2.0
	game._skill_runtime.advance(10.0)
	game._sync_cooldowns()
	var initial_count: int = _friendly_count(game)
	game.cast_bolt()
	_check("low mana does not spawn bolt", _friendly_count(game) == initial_count)
	_check("low mana does not consume mana", is_equal_approx(game.player.mana, 2.0))
	_check("low mana does not trigger cooldown", game._bolt_cd <= 0.0)
	_check("low mana explains blocked attack", "魔力不足" in game.hud._notice.text)
	var notification_time: float = game.hud._notice_time
	game.cast_bolt()
	_check("held attack does not reset notification every frame", is_equal_approx(game.hud._notice_time, notification_time))
	game.player.mana = 80.0
	game.cast_bolt()
	_check("restoring mana makes attack work", _friendly_count(game) == initial_count + 3)
	_check("successful attack charges mana and cooldown", is_equal_approx(game.player.mana, 77.0) and game._bolt_cd > 0.0)
	game._skill_runtime.advance(10.0)
	game._sync_cooldowns()
	game.socket_gems[0] = ""
	game._skill_notice_wait = 0.0
	var before_missing: int = _friendly_count(game)
	game.cast_bolt()
	_check("missing active gem blocks real attack", _friendly_count(game) == before_missing)
	_check("missing active gem is explained", "未安裝" in game.hud._notice.text)
	game.socket_gems[0] = "ember_bolt"
	game.player.mana = 0.0
	game._skill_notice_wait = 0.0
	game.cast_nova()
	_check("area cast with no mana does not trigger cooldown", game._nova_cd <= 0.0)
	_check("area cast with no mana explains cause", "魔力不足" in game.hud._notice.text)
	print("PHASE2 CAST FEEDBACK: %d passed / %d failed" % [passed, failed])
	game.queue_free()
	quit(0 if failed == 0 else 1)

func _friendly_count(game) -> int:
	var count: int = 0
	for node in game.get_children():
		if node.is_in_group("projectiles") and not node.enemy_owned and not node.is_queued_for_deletion():
			count += 1
	return count

func _check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
