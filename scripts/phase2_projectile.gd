extends "res://scripts/projectile.gd"
## Projectile visuals/motion use original game, but damage is resolved AT collision.
var combat_runtime
var skill_definition
var on_hit_modifiers: Dictionary = {}

func configure(runtime, skill, modifiers: Dictionary) -> void:
	combat_runtime = runtime
	skill_definition = skill
	on_hit_modifiers = modifiers.duplicate(true)

func _physics_process(delta: float) -> void:
	if enemy_owned:
		super._physics_process(delta)
		return
	if not is_instance_valid(game) or (game.zone != "field" and game.zone != "camp"):
		queue_free()
		return
	if combat_runtime == null or skill_definition == null:
		queue_free()
		return
	# Swept segment avoids missing enemies between frames at Web/mobile frame rates.
	var start: Vector3 = global_position
	var motion: Vector3 = direction * speed * delta
	global_position += motion
	_travelled += motion.length()
	var segment: Vector3 = global_position - start
	var segment_length_squared: float = segment.length_squared()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.hp <= 0.0:
			continue
		var enemy_id: int = enemy.get_instance_id()
		if enemy_id in _hit_ids:
			continue
		var fraction: float = 0.0
		if segment_length_squared > 0.000001:
			fraction = clampf((enemy.global_position - start).dot(segment) / segment_length_squared, 0.0, 1.0)
		var closest: Vector3 = start + segment * fraction
		var hit_radius: float = 1.05 if enemy.boss else 0.78
		if closest.distance_squared_to(enemy.global_position) > hit_radius * hit_radius:
			continue
		var target: Dictionary = {"hp": enemy.hp, "position": enemy.global_position,
			"resistance": 0.08 if enemy.boss else 0.0,
			"defensive_ability": enemy.defensive_ability,
			"armor_rating": enemy.armor_rating,
			"armor_absorption": enemy.armor_absorption,
			"resistances": enemy.damage_resistances}
		var hit: Dictionary = combat_runtime.resolve_projectile_hit(skill_definition, target, on_hit_modifiers, randf())
		if not bool(hit.get("ok", false)):
			continue
		_hit_ids.append(enemy_id)
		if bool(hit.get("hit", true)) and int(hit.get("damage", 0)) > 0:
			enemy.take_hit(int(hit["damage"]), start)
			game.spawn_burst(closest, Color("#ffe29b") if bool(hit.get("critical", false)) else Color("#ffcb7b"), 0.95 if bool(hit.get("critical", false)) else 0.72)
		else:
			# A miss consumes the impact but never knocks back an enemy or applies a zero-damage hit.
			game.spawn_burst(closest, Color("#94aaba"), 0.40)
		if pierce_remaining <= 0:
			queue_free()
			return
		pierce_remaining -= 1
	if _travelled >= max_distance:
		queue_free()
