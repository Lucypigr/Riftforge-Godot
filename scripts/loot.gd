extends Node3D

var item: Dictionary = {}
var _time: float = 0.0
var _visual: MeshInstance3D

func initialize(item_data: Dictionary) -> void:
	item = item_data.duplicate(true)
	add_to_group("loot")
	_visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.47, 0.47, 0.47)
	_visual.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#e6b45c") if item["rarity"] == "稀有" else Color("#78b9f4")
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.65
	_visual.material_override = mat
	add_child(_visual)
	var label := Label3D.new()
	label.text = str(item["name"])
	label.position.y = 0.85
	label.font_size = 35
	label.pixel_size = 0.005
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _process(delta: float) -> void:
	_time += delta
	if _visual:
		_visual.position.y = sin(_time * 3.1) * 0.16
		_visual.rotation.y += delta * 1.5
