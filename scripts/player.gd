extends CharacterBody3D
const COMBAT = preload("res://scripts/combat_math.gd")

var game
var hp: float = 120.0
var max_hp: float = 120.0
var mana: float = 80.0
var max_mana: float = 80.0
var speed: float = 9.0
var dash_cooldown: float = 0.0
var invulnerable: float = 0.0
var aim := Vector3.FORWARD
var _body_mesh: MeshInstance3D
var _body_material: StandardMaterial3D
var _dash_time: float = 0.0
var _dash_direction := Vector3.ZERO
var _hit_flash: float = 0.0

func initialize(owner_game) -> void:
	game = owner_game
	collision_layer = 1
	collision_mask = 2
	var shape := CapsuleShape3D.new()
	shape.radius = 0.46
	shape.height = 1.6
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	_body_mesh = MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.43
	body.height = 1.45
	_body_mesh.mesh = body
	_body_material = _material(Color("#4bc6d5"))
	_body_mesh.material_override = _body_material
	add_child(_body_mesh)
	var face := MeshInstance3D.new()
	var marker := BoxMesh.new()
	marker.size = Vector3(0.28, 0.19, 0.64)
	face.mesh = marker
	face.position = Vector3(0, 0.20, -0.49)
	face.material_override = _material(Color("#ffe0a1"))
	add_child(face)

func _material(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.17
	mat.roughness = 0.45
	return mat

func _physics_process(delta: float) -> void:
	if game == null:
		return
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	mana = minf(max_mana, mana + 8.5 * delta)
	_body_material.albedo_color = Color("#ffffff") if _hit_flash > 0.0 else Color("#4bc6d5")
	var axis: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if game.mobile_active:
		axis = game.mobile_move
	var move_dir := Vector3(axis.x, 0, axis.y)
	if move_dir.length_squared() > 1.0:
		move_dir = move_dir.normalized()
	if game.ui_open:
		move_dir = Vector3.ZERO
	if game.aim_direction.length_squared() > 0.01:
		aim = game.aim_direction
		rotation.y = atan2(-aim.x, -aim.z)
	var dash_requested: bool = Input.is_action_just_pressed("dash") or (game.mobile_active and game.mobile_dash_requested)
	if game.mobile_active:
		game.mobile_dash_requested = false
	var dash_dir: Vector3 = move_dir if move_dir.length_squared() > 0.01 else game.aim_direction.normalized()
	if dash_requested and not game.ui_open and dash_cooldown <= 0.0 and dash_dir.length_squared() > 0.01:
		dash_cooldown = 2.2
		_dash_time = 0.19
		_dash_direction = dash_dir
		invulnerable = 0.29
		game.spawn_burst(global_position, Color("#52e8e8"), 1.1)
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_direction * 25.0
	else:
		velocity = move_dir * speed
	move_and_slide()
	position.x = clampf(position.x, -26.5, 26.5)
	position.z = clampf(position.z, -26.5, 26.5)
	position.y = 0.9

func receive_damage(raw_damage: float) -> void:
	if invulnerable > 0.0 or hp <= 0.0:
		return
	var armor: float = float(game.equipment["armor"].get("armor", 0.0))
	var actual: int = COMBAT.incoming(raw_damage, armor)
	hp -= actual
	_hit_flash = 0.19
	invulnerable = 0.32
	game.spawn_burst(global_position, Color("#ff637e"), 0.85)
	game.show_damage(global_position, actual, Color("#ff7c88"))
	if hp <= 0.0:
		game.player_died()

func refresh_equipment() -> void:
	var old_max: float = max_hp
	# A weapon's vitality affix is an equipped bonus too, including after loading an older save.
	max_hp = 120.0 + 6.0 * float(game.level - 1) + float(game.equipment["armor"].get("hp", 0.0)) + float(game.equipment["weapon"].get("hp", 0.0))
	hp = clampf(hp + max_hp - old_max, 1.0, max_hp)
