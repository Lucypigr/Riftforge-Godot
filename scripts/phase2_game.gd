extends "res://scripts/mobile_game.gd"
## Both PC and touch use the same original Riftforge casting and damage pipeline.
const SkillDefinition = preload("res://research/phase2/skill_definition.gd")
const SkillRuntime = preload("res://research/phase2/skill_runtime.gd")
const Phase2Projectile = preload("res://scripts/phase2_projectile.gd")

var _skill_runtime
var _bolt_skill
var _nova_skill
var _skill_notice_wait: float = 0.0

func _ready() -> void:
	super._ready()
	_bolt_skill = SkillDefinition.new()
	_bolt_skill.skill_id = &"ember_bolt"
	_bolt_skill.display_name = "燼焰彈"
	_bolt_skill.delivery = "projectile"
	_bolt_skill.base_damage = 16.0
	_bolt_skill.mana_cost = 3.0
	_bolt_skill.cooldown = 0.205
	_bolt_skill.cast_range = 26.0
	_bolt_skill.crit_chance = 0.13
	_bolt_skill.crit_multiplier = 1.6
	_nova_skill = SkillDefinition.new()
	_nova_skill.skill_id = &"shock_nova"
	_nova_skill.display_name = "震盪環"
	_nova_skill.delivery = "area"
	_nova_skill.base_damage = 34.0
	_nova_skill.mana_cost = 25.0
	_nova_skill.cooldown = 3.6
	_nova_skill.cast_range = 4.6
	_nova_skill.radius = 4.6
	_nova_skill.crit_chance = 0.1
	_nova_skill.crit_multiplier = 1.5
	_skill_runtime = SkillRuntime.new(player.mana)
	_sync_cooldowns()

func _process(delta: float) -> void:
	_skill_notice_wait = maxf(0.0, _skill_notice_wait - delta)
	if _skill_runtime != null:
		_skill_runtime.advance(delta)
		_sync_cooldowns()
	# Parent dispatches desktop attacks to these same overridden functions.
	# Mobile controls call them directly, never a separate damage formula.
	super._process(delta)
	if _skill_runtime != null:
		_sync_cooldowns()

func _sync_cooldowns() -> void:
	_bolt_cd = _skill_runtime.remaining(_bolt_skill.skill_id)
	_nova_cd = _skill_runtime.remaining(_nova_skill.skill_id)

func _skill_blocked(reason: String, skill_name: String, cost: int) -> void:
	# A held attack checks every frame: throttle notifications rather than resetting the HUD timer forever.
	if _skill_notice_wait > 0.0 or not is_instance_valid(hud):
		return
	match reason:
		"insufficient_mana": hud.announce("%s：魔力不足（需要 %d）" % [skill_name, cost])
		"invalid_skill": hud.announce("%s：技能資料無效" % skill_name)
		"invalid_aim": hud.announce("%s：請指定施放方向" % skill_name)
		"missing_gem": hud.announce("燼焰彈未安裝：請檢查主動寶石孔")
		_: return  # Cooldowns are displayed on the HUD; avoid spam.
	_skill_notice_wait = 0.9

func _offensive_ability() -> float:
	# No hidden source-game data: transparent Riftforge progression and future weapon-affix hook.
	return 1000.0 + 8.0 * float(level - 1) + float(equipment["weapon"].get("offensive_ability", 0.0))

func cast_bolt() -> void:
	if _skill_runtime == null or not is_instance_valid(player) or ui_open:
		return
	if socket_gems.is_empty() or str(socket_gems[0]) != "ember_bolt":
		_skill_blocked("missing_gem", "燼焰彈", 3)
		return
	_skill_runtime.mana = player.mana
	var result: Dictionary = _skill_runtime.cast(_bolt_skill, player.global_position, aim_direction, [])
	if not bool(result.get("ok", false)):
		_skill_blocked(str(result.get("reason", "")), "燼焰彈", 3)
		return
	player.mana = _skill_runtime.mana
	_sync_cooldowns()
	var gem_mods: Dictionary = GEMS.modifiers(socket_gems)
	var count: int = maxi(1, int(gem_mods.get("projectile_count", 1)))
	var on_hit_mods: Dictionary = {
		"flat_damage": float(equipment["weapon"].get("damage", 0.0)),
		"more_multiplier": float(gem_mods.get("damage_multiplier", 1.0)),
		"offensive_ability": _offensive_ability()
	}
	var spawn: Dictionary = result["shots"][0]
	for shot in range(count):
		var angle: float = deg_to_rad((float(shot) - (float(count) - 1.0) * 0.5) * 12.0)
		var direction: Vector3 = (spawn["direction"] as Vector3).rotated(Vector3.UP, angle)
		var projectile = Phase2Projectile.new()
		projectile.initialize(self, direction, 0, false, int(gem_mods.get("pierce_count", 0)))
		projectile.configure(_skill_runtime, _bolt_skill, on_hit_mods)
		projectile.max_distance = float(spawn["max_distance"])
		projectile.position = player.global_position + direction * 0.83 + Vector3(0, 0.1, 0)
		projectile.add_to_group("projectiles")
		add_child(projectile)
	spawn_burst(player.global_position + aim_direction * 0.8, Color("#f7a756"), 0.43)

func cast_nova() -> void:
	if _skill_runtime == null or not is_instance_valid(player) or ui_open:
		return
	_skill_runtime.mana = player.mana
	var targets: Array = []
	var enemies_by_id: Dictionary = {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.hp <= 0.0:
			continue
		var enemy_id: int = enemy.get_instance_id()
		enemies_by_id[enemy_id] = enemy
		targets.append({"id": enemy_id, "hp": enemy.hp, "position": enemy.global_position,
			"resistance": 0.08 if enemy.boss else 0.0,
			"defensive_ability": enemy.defensive_ability,
			"armor_rating": enemy.armor_rating,
			"armor_absorption": enemy.armor_absorption,
			"resistances": enemy.damage_resistances})
	var modifiers: Dictionary = {"flat_damage": float(equipment["weapon"].get("damage", 0.0)) * 0.7,
		"offensive_ability": _offensive_ability()}
	var result: Dictionary = _skill_runtime.cast(_nova_skill, player.global_position, Vector3.ZERO, targets, modifiers, randf())
	if not bool(result.get("ok", false)):
		_skill_blocked(str(result.get("reason", "")), "震盪環", 25)
		return
	player.mana = _skill_runtime.mana
	_sync_cooldowns()
	_camera_shake = 0.4
	spawn_burst(player.global_position, Color("#7de3ff"), _nova_skill.radius)
	for hit in result["hits"]:
		var enemy = enemies_by_id.get(int(hit["target_id"]))
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.hp > 0.0:
			enemy.take_hit(int(hit["damage"]), player.global_position)
	hud.announce("震盪環！")
