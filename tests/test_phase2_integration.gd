extends SceneTree
## Scene-level regression. Does NOT replace real iPhone touch/browser playtesting.
const ENEMY = preload("res://scripts/enemy.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	_check("main scene uses phase2 bridge", game.get_script().resource_path.ends_with("phase2_game.gd"))
	_check("shared runtime exists", game._skill_runtime != null)
	_check("two valid skills", game._bolt_skill.validate().is_empty() and game._nova_skill.validate().is_empty())
	game.mobile_active = true
	game.aim_direction = Vector3.RIGHT
	var mana_before: float = game.player.mana
	game.cast_bolt()
	var first_volley: Array = _friendly_projectiles(game)
	_check("bolt spawns three linked projectiles", first_volley.size() == 3)
	_check("bolt charges mana once", is_equal_approx(game.player.mana, mana_before - 3.0))
	_check("UI cooldown follows skill runtime", game._bolt_cd > 0.0 and is_equal_approx(game._bolt_cd, game._skill_runtime.remaining(&"ember_bolt")))
	game.cast_bolt()
	_check("cooldown prevents extra projectiles", _friendly_projectiles(game).size() == 3)
	var enemy = ENEMY.new()
	enemy.initialize(game, "hunter")
	enemy.max_hp = 500.0
	enemy.hp = 500.0
	enemy.position = game.player.position + Vector3(3.0, -0.2, 0.0)
	game.add_child(enemy)
	var before_hit: float = enemy.hp
	_check("projectile does not auto damage at spawn", is_equal_approx(enemy.hp, before_hit))
	for projectile in first_volley:
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			projectile._physics_process(0.2)
	_check("swept collision applies real enemy damage", enemy.hp < before_hit)
	_check("target stays alive for follow-up", enemy.hp > 0.0)
	var far_enemy = ENEMY.new()
	far_enemy.initialize(game, "hunter")
	far_enemy.position = game.player.position + Vector3(8.0, -0.2, 0.0)
	game.add_child(far_enemy)
	var near_hp: float = enemy.hp
	var far_hp: float = far_enemy.hp
	var pre_nova_mana: float = game.player.mana
	game.cast_nova()
	_check("nova hits nearby enemy", enemy.hp < near_hp)
	_check("nova excludes distant enemy", is_equal_approx(far_enemy.hp, far_hp))
	_check("nova charges mana once", is_equal_approx(game.player.mana, pre_nova_mana - 25.0))
	_check("nova cooldown shared with mobile HUD", game._nova_cd > 0.0 and is_equal_approx(game._nova_cd, game._skill_runtime.remaining(&"shock_nova")))
	# Mobile buttons call the same methods; no duplicate combat engine.
	var controls = game.get_node("MobileControls")
	controls.enabled = true
	controls.surface.visible = true
	game._skill_runtime.advance(5.0)
	game._sync_cooldowns()
	var touch_mana: float = game.player.mana
	var before_touch: int = _friendly_projectiles(game).size()
	controls._start_touch(41, controls._center("attack"))
	_check("touch attack owns separate ID", controls.attack_id == 41)
	_check("touch attack casts through shared runtime", _friendly_projectiles(game).size() == before_touch + 3)
	_check("touch attack spends mana", game.player.mana < touch_mana)
	controls._end_touch(41)
	_check("touch release clears held state", controls.attack_id == -1)
	var nova_mana: float = game.player.mana
	controls._start_touch(42, controls._center("nova"))
	controls._end_touch(42)
	_check("touch nova uses shared runtime", game.player.mana < nova_mana and game._nova_cd > 0.0)
	game._enter_zone("field")
	_check("field transition still works", game.zone == "field")
	_check("field still spawns enemies", get_nodes_in_group("enemies").size() >= 7)
	print("PHASE2 INTEGRATION RESULT: %d passed / %d failed" % [passed, failed])
	game.queue_free()
	quit(0 if failed == 0 else 1)

func _friendly_projectiles(game) -> Array:
	var result: Array = []
	for node in game.get_children():
		if node.is_in_group("projectiles") and not node.enemy_owned and not node.is_queued_for_deletion():
			result.append(node)
	return result

func _check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
