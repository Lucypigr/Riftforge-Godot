extends Node3D
## Phase 10 timed ground area. It persists for duration and asks the game to resolve each DoT tick through Combat V2.

var game
var resolved: Dictionary = {}
var remaining: float = 0.0
var tick_interval: float = 0.5
var tick_wait: float = 0.0

func initialize(owner_game, resolved_skill: Dictionary) -> void:
	game = owner_game
	resolved = resolved_skill.duplicate(true)
	remaining = float(resolved.get("duration", 0.0))
	tick_interval = maxf(0.05, float(resolved.get("tick_interval", 0.5)))
	tick_wait = 0.0
	add_to_group("combat_fx")
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = float(resolved.get("aoe_radius", 3.0))
	cylinder.bottom_radius = cylinder.top_radius
	cylinder.height = 0.08
	mesh.mesh = cylinder
	mesh.position.y = 0.03
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.95, 0.24, 0.08, 0.28)
	mat.emission_enabled = true
	mat.emission = Color("#e94f24")
	mat.emission_energy_multiplier = 1.1
	mesh.material_override = mat
	add_child(mesh)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or remaining <= 0.0 or (game.zone != "field" and game.zone != "camp"):
		queue_free()
		return
	remaining -= delta
	tick_wait -= delta
	if tick_wait <= 0.0:
		tick_wait += tick_interval
		game.phase10_ground_tick(global_position, resolved)
	if remaining <= 0.0:
		queue_free()
