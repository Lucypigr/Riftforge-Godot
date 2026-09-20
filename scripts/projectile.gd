extends Node3D

var game
var direction := Vector3.FORWARD
var speed: float = 22.0
var damage: int = 14
var enemy_owned: bool = false
var pierce_remaining: int = 0
var max_distance: float = 26.0
var _travelled: float = 0.0
var _hit_ids: Array[int] = []

func initialize(owner_game, heading: Vector3, hit_damage: int, hostile: bool, pierces: int = 0) -> void:
	game = owner_game
	direction = heading.normalized()
	damage = hit_damage
	enemy_owned = hostile
	pierce_remaining = pierces
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.21 if hostile else 0.29
	sphere.height = sphere.radius * 2.0
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#e58af4") if hostile else Color("#ffab55")
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 2.2
	mesh.material_override = mat
	add_child(mesh)

func _physics_process(delta: float) -> void:
	if game == null or game.zone != "field":
		queue_free()
		return
	var step: Vector3 = direction * speed * delta
	position += step
	_travelled += step.length()
	if _travelled >= max_distance:
		queue_free()
		return
	if enemy_owned:
		if global_position.distance_to(game.player.global_position) < 0.85:
			game.player.receive_damage(damage)
			game.spawn_burst(global_position, Color("#cc89f5"), 0.8)
			queue_free()
		return
	for body in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(body) or body.hp <= 0.0:
			continue
		if body.get_instance_id() in _hit_ids:
			continue
		if global_position.distance_to(body.global_position) < (1.05 if body.boss else 0.78):
			_hit_ids.append(body.get_instance_id())
			body.take_hit(damage, global_position)
			game.spawn_burst(global_position, Color("#ffcb7b"), 0.72)
			if pierce_remaining <= 0:
				queue_free()
				return
			pierce_remaining -= 1
