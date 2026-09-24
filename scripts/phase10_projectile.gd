extends Node3D
## Phase 10 resolved projectile: fixed world range, pierce, chain bookkeeping and real status effects.

var game
var runtime
var skill_definition
var resolved: Dictionary = {}
var enemy_owned: bool = false
var direction := Vector3.FORWARD
var speed: float = 20.0
var max_distance: float = 20.0
var pierce_remaining: int = 0
var chain_remaining: int = 0
var _travelled: float = 0.0
var _hit_ids: Array[int] = []
var _chain_index: int = 0

func initialize(owner_game, owner_runtime, skill, resolved_skill: Dictionary, heading: Vector3) -> void:
	game = owner_game
	runtime = owner_runtime
	skill_definition = skill
	resolved = resolved_skill.duplicate(true)
	direction = heading.normalized()
	speed = float(resolved.get("projectile_speed", 20.0))
	max_distance = float(resolved.get("cast_range", 20.0))
	pierce_remaining = int(resolved.get("pierce", 0))
	chain_remaining = int(resolved.get("chain", 0))
	add_to_group("projectiles")
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match str(resolved.get("damage_type", "")):
		"cold": mat.albedo_color = Color("#8fe9ff")
		"lightning": mat.albedo_color = Color("#b99cff")
		_: mat.albedo_color = Color("#ffab55")
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 2.1
	mesh.material_override = mat
	add_child(mesh)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player) or (game.zone != "field" and game.zone != "camp"):
		queue_free()
		return
	var start := global_position
	var motion := direction * speed * delta
	global_position += motion
	_travelled += motion.length()
	var segment := global_position - start
	var segment_len_sq := segment.length_squared()
	var collided = null
	var impact := global_position
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.hp <= 0.0:
			continue
		var enemy_id: int = enemy.get_instance_id()
		if enemy_id in _hit_ids:
			continue
		var fraction := 0.0
		if segment_len_sq > 0.000001:
			fraction = clampf((enemy.global_position - start).dot(segment) / segment_len_sq, 0.0, 1.0)
		var closest := start + segment * fraction
		var radius := 1.05 if enemy.boss else 0.78
		if closest.distance_squared_to(enemy.global_position) <= radius * radius:
			collided = enemy
			impact = closest
			break
	if collided != null:
		_resolve_hit(collided, impact)
		if is_queued_for_deletion():
			return
	if _travelled >= max_distance:
		queue_free()

func _resolve_hit(enemy, impact: Vector3) -> void:
	var enemy_id: int = enemy.get_instance_id()
	_hit_ids.append(enemy_id)
	var target: Dictionary = {
		"hp": enemy.hp,
		"position": enemy.global_position,
		"resistance": 0.08 if enemy.boss else 0.0,
		"defensive_ability": enemy.defensive_ability,
		"armor_rating": enemy.armor_rating,
		"armor_absorption": enemy.armor_absorption,
		"resistances": enemy.damage_resistances
	}
	var modifiers := game.phase10_hit_modifiers(resolved, _chain_index)
	var hit: Dictionary = runtime.resolve_projectile_hit(skill_definition, target, modifiers, randf())
	if bool(hit.get("ok", false)) and bool(hit.get("hit", true)):
		var damage := int(hit.get("damage", 0))
		if damage > 0:
			enemy.take_hit(damage, global_position)
		game.phase10_apply_statuses(enemy, resolved)
			game.spawn_burst(impact, Color("#d7f3ff") if str(resolved.get("damage_type", "")) == "cold" else Color("#ffe29b"), 0.72)
	else:
		game.spawn_burst(impact, Color("#94aaba"), 0.40)
	var next_target = _next_chain_target(enemy.global_position)
	if chain_remaining > 0 and next_target != null:
		chain_remaining -= 1
		_chain_index += 1
		var next_dir: Vector3 = next_target.global_position - global_position
		next_dir.y = 0.0
		if next_dir.length_squared() > 0.001:
			direction = next_dir.normalized()
			return
	if pierce_remaining > 0:
		pierce_remaining -= 1
		return
	queue_free()

func _next_chain_target(origin: Vector3):
	if chain_remaining <= 0:
		return null
	var best = null
	var best_distance := float(resolved.get("chain_range", 7.0))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.hp <= 0.0:
			continue
		if enemy.get_instance_id() in _hit_ids:
			continue
		var distance := enemy.global_position.distance_to(origin)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best
