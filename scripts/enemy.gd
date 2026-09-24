extends CharacterBody3D

var game
var kind: String = "hunter"
var boss: bool = false
var hp: float = 42.0
var max_hp: float = 42.0
var move_speed: float = 4.0
var attack_range: float = 1.8
var attack_cooldown: float = 1.2
## Original Riftforge combat V2 defence stats, not imported game data.
var defensive_ability: float = 1000.0
var armor_rating: float = 0.0
var armor_absorption: float = 0.7
var damage_resistances: Dictionary = {}
var _attack_timer: float = 1.0
var _windup: float = 0.0
var _flash: float = 0.0
var _knock := Vector3.ZERO
var _visual: MeshInstance3D
var _visual_material: StandardMaterial3D
var _bar_fill: MeshInstance3D
var _color := Color("#d45c6b")
var _attack_done := false
var _slow_time: float = 0.0
var _slow_multiplier: float = 1.0

func initialize(owner_game, enemy_kind: String, is_boss: bool = false) -> void:
	game = owner_game
	kind = enemy_kind
	boss = is_boss
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1 | 2
	match kind:
		"hunter":
			hp = 43.0
			move_speed = 5.5
			attack_range = 1.65
			defensive_ability = 950.0
			armor_rating = 5.0
			damage_resistances = {}
			_color = Color("#df6772")
		"spitter":
			hp = 32.0
			move_speed = 3.4
			attack_range = 9.5
			defensive_ability = 990.0
			armor_rating = 3.0
			damage_resistances = {"fire": 0.12}
			_color = Color("#9b7ae1")
		"brute":
			hp = 92.0
			move_speed = 2.7
			attack_range = 2.7
			defensive_ability = 1100.0
			armor_rating = 24.0
			damage_resistances = {"physical": 0.04}
			_color = Color("#e4a95f")
	if boss:
		hp = 490.0
		move_speed = 3.35
		attack_range = 3.1
		defensive_ability = 1210.0
		armor_rating = 60.0
		damage_resistances = {"fire": 0.08, "lightning": 0.08, "physical": 0.08}
		_color = Color("#f04c9d")
	max_hp = hp
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.9 if boss else (0.72 if kind == "brute" else 0.42)
	capsule.height = 2.4 if boss else (1.8 if kind == "brute" else 1.3)
	collision.shape = capsule
	add_child(collision)
	_visual = MeshInstance3D.new()
	var shape := CapsuleMesh.new()
	shape.radius = capsule.radius * 0.88
	shape.height = capsule.height * 0.95
	_visual.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color
	_visual_material = mat
	mat.metallic = 0.1
	mat.roughness = 0.65
	_visual.material_override = mat
	add_child(_visual)
	var back := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1.3 if boss else 0.95, 0.08, 0.1)
	back.mesh = bar_mesh
	back.position.y = 1.65 if boss else 1.12
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#1b1d29")
	back.material_override = dark
	add_child(back)
	_bar_fill = MeshInstance3D.new()
	_bar_fill.mesh = bar_mesh
	_bar_fill.position = back.position + Vector3(0, 0.035, 0.01)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("#74d68f") if not boss else Color("#f3b055")
	_bar_fill.material_override = green
	add_child(_bar_fill)

func _physics_process(delta: float) -> void:
	if game == null or game.zone != "field" or hp <= 0.0:
		return
	_attack_timer -= delta
	_flash = maxf(0.0, _flash - delta)
	_slow_time = maxf(0.0, _slow_time - delta)
	if _slow_time <= 0.0:
		_slow_multiplier = 1.0
	_visual_material.albedo_color = Color.WHITE if _flash > 0.0 else _color
	var to_player: Vector3 = game.player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	var dir: Vector3 = to_player.normalized() if dist > 0.01 else Vector3.FORWARD
	rotation.y = atan2(-dir.x, -dir.z)
	if _windup > 0.0:
		_windup -= delta
		velocity = _knock
		if _windup <= 0.0 and not _attack_done:
			_attack_done = true
			_perform_attack(dist)
	else:
		var move_dir: Vector3 = Vector3.ZERO
		if kind == "spitter" and not boss:
			if dist < 5.0:
				move_dir = -dir
			elif dist > 8.0:
				move_dir = dir
		elif dist > attack_range * 0.82:
			move_dir = dir
		velocity = move_dir * move_speed * _slow_multiplier + _knock
		if dist <= attack_range and _attack_timer <= 0.0:
			_start_attack()
	_knock = _knock.move_toward(Vector3.ZERO, 17.0 * delta)
	move_and_slide()
	position.y = 1.15 if boss else (0.95 if kind == "brute" else 0.7)

func _start_attack() -> void:
	_attack_done = false
	_attack_timer = 2.1 if boss else (2.2 if kind == "spitter" else 1.45)
	_windup = 0.72 if boss else (0.48 if kind == "brute" else 0.31)
	var radius: float = 3.2 if boss else (2.6 if kind == "brute" else 1.3)
	game.telegraph(global_position, radius, _windup)

func _perform_attack(_previous_distance: float) -> void:
	if not is_instance_valid(game.player) or game.zone != "field":
		return
	if kind == "spitter" and not boss:
		var aim: Vector3 = (game.player.global_position - global_position).normalized()
		aim.y = 0.0
		game.fire_enemy_projectile(global_position + Vector3(0, 0.25, 0), aim, 14.0)
		return
	var dist: float = global_position.distance_to(game.player.global_position)
	var radius: float = 3.2 if boss else (2.6 if kind == "brute" else 1.55)
	if dist <= radius:
		game.player.receive_damage(30.0 if boss else (19.0 if kind == "brute" else 10.0))
	game.spawn_burst(global_position, Color("#f3a1a5"), radius)

func take_hit(amount: int, source_position: Vector3) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_flash = 0.13
	var knock_dir: Vector3 = global_position - source_position
	knock_dir.y = 0.0
	_knock += knock_dir.normalized() * (1.3 if boss else 3.8)
	_bar_fill.scale.x = maxf(0.001, hp / max_hp)
	game.show_damage(global_position, amount, Color("#ffe29b"))
	if hp <= 0.0:
		game.enemy_died(global_position, boss)
		queue_free()

func apply_slow(multiplier: float, duration: float) -> void:
	if hp <= 0.0 or duration <= 0.0:
		return
	_slow_multiplier = minf(_slow_multiplier, clampf(multiplier, 0.2, 1.0))
	_slow_time = maxf(_slow_time, duration)

func current_move_speed() -> float:
	return move_speed * _slow_multiplier
