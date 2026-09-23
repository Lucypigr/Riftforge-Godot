extends Node3D
## Original, standalone ARPG prototype. No Grim Dawn or POE code/assets/data included.
const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const PROJECTILE_SCRIPT = preload("res://scripts/projectile.gd")
const LOOT_SCRIPT = preload("res://scripts/loot.gd")
const HUD_SCRIPT = preload("res://scripts/hud.gd")
const ITEMS = preload("res://scripts/items.gd")
const GEMS = preload("res://scripts/gem_rules.gd")
const COMBAT = preload("res://scripts/combat_math.gd")
const SAVE_PATH = "user://riftforge_phase8_save.json"

var player
var hud
var camera: Camera3D
var _zone_art: Node3D
var zone: String = "camp"
var ui_open := false
var aim_direction := Vector3.FORWARD
var inventory: Array = []
var equipment: Dictionary = {}
var socket_gems: Array = ["ember_bolt", "scatter", "pierce"]
var kills: int = 0
var level: int = 1
var runs: int = 0
var wave_kills: int = 0
var target_kills: int = 15
var boss_spawned := false
var boss_defeated := false
var _spawn_timer: float = 0.0
var _bolt_cd: float = 0.0
var _nova_cd: float = 0.0
var _portal_position := Vector3.ZERO
var _camera_shake: float = 0.0

func _ready() -> void:
	randomize()
	_setup_input()
	_load_progress()
	_setup_world()
	player = PLAYER_SCRIPT.new()
	player.initialize(self)
	add_child(player)
	player.refresh_equipment()
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 49.0
	add_child(camera)
	camera.position = Vector3(0, 22, 25)
	hud = HUD_SCRIPT.new()
	hud.initialize(self)
	add_child(hud)
	_enter_zone("camp")
	hud.announce("新遠征開始：靠近傳送門按 E")

func _setup_input() -> void:
	var bindings := {
		"move_left": KEY_A, "move_right": KEY_D,
		"move_forward": KEY_W, "move_backward": KEY_S,
		"dash": KEY_SPACE, "interact": KEY_E,
		"inventory": KEY_I, "gems": KEY_G, "close_ui": KEY_ESCAPE
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)
	for mouse_action in ["attack", "nova"]:
		if not InputMap.has_action(mouse_action):
			InputMap.add_action(mouse_action)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT if mouse_action == "attack" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(mouse_action, mouse)

func _setup_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0b1522")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8799bf")
	env.ambient_light_energy = 0.8
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.95, -0.52, -0.28)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(58, 58)
	floor_mesh.mesh = floor_plane
	floor_mesh.position.y = -0.06
	floor_mesh.material_override = _mat(Color("#263642"))
	add_child(floor_mesh)
	for i in range(-24, 25, 4):
		_box(self, Vector3(float(i), -0.045, 0), Vector3(0.025, 0.01, 56), Color("#334655"))
		_box(self, Vector3(0, -0.045, float(i)), Vector3(56, 0.01, 0.025), Color("#334655"))
	for edge in [-28.0, 28.0]:
		_box(self, Vector3(edge, 1.0, 0), Vector3(1.1, 2.1, 57), Color("#152536"))
		_box(self, Vector3(0, 1.0, edge), Vector3(57, 2.1, 1.1), Color("#152536"))
	_zone_art = Node3D.new()
	_zone_art.name = "ZoneArt"
	add_child(_zone_art)

func _mat(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.74
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4
	return mat

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _orb(parent: Node3D, at: Vector3, radius: float, color: Color, glow: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = at
	node.material_override = _mat(color, glow)
	parent.add_child(node)
	return node

func _enter_zone(destination: String) -> void:
	zone = destination
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	for loot in get_tree().get_nodes_in_group("loot"):
		loot.queue_free()
	for child in get_children():
		if child is Node3D and (child.is_in_group("projectiles") or child.is_in_group("combat_fx")):
			child.queue_free()
	for art in _zone_art.get_children():
		art.queue_free()
	if zone == "camp":
		_portal_position = Vector3(0, 0, -9)
		player.position = Vector3(0, 0.9, 2.0)
		player.hp = player.max_hp
		player.mana = player.max_mana
		player.invulnerable = 1.0
		_build_camp()
	else:
		runs += 1
		wave_kills = 0
		boss_spawned = false
		boss_defeated = false
		_spawn_timer = 1.0
		_portal_position = Vector3(0, 0, 11)
		player.position = Vector3(0, 0.9, 9)
		player.invulnerable = 1.0
		_build_field()
		for i in range(7):
			_spawn_enemy()
	camera.global_position = player.global_position + Vector3(0, 22, 25)
	camera.look_at(player.global_position + Vector3(0, 0.5, 0), Vector3.UP)
	save_progress()

func _portal(at: Vector3, tint: Color) -> void:
	var portal := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.95
	ring.outer_radius = 1.2
	portal.mesh = ring
	portal.material_override = _mat(tint, true)
	portal.position = at + Vector3(0, 0.12, 0)
	_zone_art.add_child(portal)
	_orb(_zone_art, at + Vector3(0, 0.3, 0), 0.66, Color(tint.r, tint.g, tint.b, 0.65), true)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position = at + Vector3(0, 1.5, 0)
	_zone_art.add_child(light)

func _build_camp() -> void:
	_portal(_portal_position, Color("#52d6fd"))
	_box(_zone_art, Vector3(-8, 0.1, -1), Vector3(8, 0.25, 6), Color("#6a6151"))
	_box(_zone_art, Vector3(8, 0.1, -1), Vector3(8, 0.25, 6), Color("#6a6151"))
	_box(_zone_art, Vector3(-8, 1.3, -4), Vector3(7, 2.3, 0.5), Color("#7c6856"))
	_box(_zone_art, Vector3(8, 1.3, -4), Vector3(7, 2.3, 0.5), Color("#7c6856"))
	for i in range(7):
		var x := -17.0 + i * 5.5
		_box(_zone_art, Vector3(x, 0.55, 15), Vector3(1, 1.1, 1), Color("#615e59"))
		_orb(_zone_art, Vector3(x, 1.42, 15), 0.28, Color("#ffc777"), true)
	_label_3d(_zone_art, "營地   /   按 E 穿過傳送門", Vector3(0, 1.6, -9), Color("#c9f3ff"))

func _build_field() -> void:
	_portal(_portal_position, Color("#6f93e9"))
	for i in range(24):
		var a := float(i) * TAU / 24.0
		var r := randf_range(19.0, 25.0)
		var x := cos(a) * r
		var z := sin(a) * r
		_box(_zone_art, Vector3(x, 0.45, z), Vector3(randf_range(0.5, 1.6), randf_range(0.7, 2.2), randf_range(0.5, 1.8)), Color("#52606c"))
	for i in range(15):
		var x := randf_range(-23.0, 23.0)
		var z := randf_range(-23.0, 23.0)
		if Vector2(x, z).length() < 5.0:
			continue
		_orb(_zone_art, Vector3(x, 0.2, z), 0.35, Color("#45665f"))
	_label_3d(_zone_art, "回營地 [E]", _portal_position + Vector3(0, 1.6, 0), Color("#c1d7ff"))

func _label_3d(parent: Node3D, message: String, at: Vector3, tint: Color) -> void:
	var text := Label3D.new()
	text.text = message
	text.font_size = 46
	text.pixel_size = 0.007
	text.outline_size = 12
	text.modulate = tint
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.position = at
	parent.add_child(text)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_bolt_cd = maxf(0.0, _bolt_cd - delta)
	_nova_cd = maxf(0.0, _nova_cd - delta)
	_camera_shake = maxf(0.0, _camera_shake - delta * 4.0)
	var desired: Vector3 = player.global_position + Vector3(0, 22, 25)
	if _camera_shake > 0.0:
		desired += Vector3(randf_range(-_camera_shake, _camera_shake), 0, randf_range(-_camera_shake, _camera_shake))
	camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 5.5))
	camera.look_at(player.global_position + Vector3(0, 0.5, 0), Vector3.UP)
	_update_aim()
	if Input.is_action_just_pressed("inventory"):
		hud.toggle_inventory()
	if Input.is_action_just_pressed("gems"):
		hud.toggle_gems()
	if Input.is_action_just_pressed("close_ui"):
		hud.close_panels()
	if ui_open:
		return
	if Input.is_action_just_pressed("interact"):
		_interact()
	if zone == "field":
		if Input.is_action_pressed("attack") and _bolt_cd <= 0.0:
			cast_bolt()
		if Input.is_action_just_pressed("nova") and _nova_cd <= 0.0:
			cast_nova()
		_process_spawns(delta)

func _update_aim() -> void:
	var ray_origin: Vector3 = camera.project_ray_origin(get_viewport().get_mouse_position())
	var ray_dir: Vector3 = camera.project_ray_normal(get_viewport().get_mouse_position())
	if absf(ray_dir.y) < 0.001:
		return
	var t: float = (player.global_position.y - ray_origin.y) / ray_dir.y
	if t <= 0.0:
		return
	var target: Vector3 = ray_origin + ray_dir * t
	var to_target: Vector3 = target - player.global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.03:
		aim_direction = to_target.normalized()

func cast_bolt() -> void:
	if player.mana < 3.0:
		return
	player.mana -= 3.0
	_bolt_cd = 0.205
	var modifiers: Dictionary = GEMS.modifiers(socket_gems)
	var shots: int = int(modifiers["projectile_count"])
	var multiplier: float = float(modifiers["damage_multiplier"])
	var weapon_damage: float = float(equipment["weapon"].get("damage", 0))
	for shot in range(shots):
		var angle: float = deg_to_rad(float(shot - (shots - 1) / 2.0) * 12.0)
		var heading: Vector3 = aim_direction.rotated(Vector3.UP, angle)
		var hit_damage: int = COMBAT.damage(16.0, weapon_damage, 0.0, multiplier, 0.13, 1.6, 0.0, randf())
		var bolt = PROJECTILE_SCRIPT.new()
		bolt.initialize(self, heading, hit_damage, false, int(modifiers["pierce_count"]))
		bolt.position = player.global_position + heading * 0.83 + Vector3(0, 0.1, 0)
		bolt.add_to_group("projectiles")
		add_child(bolt)
	spawn_burst(player.global_position + aim_direction * 0.8, Color("#f7a756"), 0.43)

func cast_nova() -> void:
	if player.mana < 25.0:
		hud.announce("魔力不足：需要 25 魔力")
		return
	player.mana -= 25.0
	_nova_cd = 3.6
	_camera_shake = 0.4
	spawn_burst(player.global_position, Color("#7de3ff"), 4.6)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.global_position.distance_to(player.global_position) <= 4.6:
			var weapon_bonus: float = float(equipment["weapon"].get("damage", 0)) * 0.7
			var hit_damage: int = COMBAT.damage(34.0, weapon_bonus, 0.0, 1.0, 0.1, 1.5, 0.08 if enemy.boss else 0.0, randf())
			enemy.take_hit(hit_damage, player.global_position)
	hud.announce("震盪環！")

func fire_enemy_projectile(origin: Vector3, heading: Vector3, raw_damage: float) -> void:
	var bolt = PROJECTILE_SCRIPT.new()
	bolt.initialize(self, heading, int(raw_damage), true)
	bolt.speed = 12.0
	bolt.max_distance = 19.0
	bolt.position = origin
	bolt.add_to_group("projectiles")
	add_child(bolt)

func _process_spawns(delta: float) -> void:
	if boss_defeated:
		return
	if wave_kills >= target_kills:
		if not boss_spawned:
			boss_spawned = true
			_spawn_enemy("brute", true)
			hud.announce("裂隙首領現身！")
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and get_tree().get_nodes_in_group("enemies").size() < 10:
		_spawn_timer = 1.5
		_spawn_enemy()

func _spawn_enemy(enemy_kind: String = "", is_boss: bool = false) -> void:
	if zone != "field":
		return
	var enemy = ENEMY_SCRIPT.new()
	if enemy_kind == "":
		var r: float = randf()
		enemy_kind = "hunter" if r < 0.54 else ("spitter" if r < 0.79 else "brute")
	enemy.initialize(self, enemy_kind, is_boss)
	var angle: float = randf() * TAU
	var distance: float = randf_range(11.0, 17.0)
	var spawn: Vector3 = player.global_position + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
	enemy.position = Vector3(clampf(spawn.x, -23.5, 23.5), 1.15 if is_boss else (0.95 if enemy_kind == "brute" else 0.7), clampf(spawn.z, -23.5, 23.5))
	add_child(enemy)

func enemy_died(at: Vector3, boss: bool) -> void:
	kills += 1
	if boss:
		boss_defeated = true
		hud.announce("首領已擊敗！拾取戰利品，回傳送門按 E。")
	else:
		wave_kills += 1
	if kills % 9 == 0:
		level += 1
		player.refresh_equipment()
		player.hp = player.max_hp
		player.mana = player.max_mana
		hud.announce("升級！現在等級 %d" % level)
	spawn_burst(at, Color("#f2b568"), 1.3 if boss else 0.68)
	_camera_shake = 0.65 if boss else 0.15
	if boss or randf() < 0.40:
		var quantity := 3 if boss else 1
		for i in range(quantity):
			var item: Dictionary = ITEMS.make_item(level, boss)
			var drop = LOOT_SCRIPT.new()
			drop.initialize(item)
			drop.position = Vector3(at.x + randf_range(-1.1, 1.1), 0.35, at.z + randf_range(-1.1, 1.1))
			add_child(drop)
	save_progress()

func interaction_hint() -> String:
	if player == null:
		return ""
	for drop in get_tree().get_nodes_in_group("loot"):
		if is_instance_valid(drop) and not drop.is_queued_for_deletion() and drop.global_position.distance_to(player.global_position) < 2.3:
			return "[E] 拾取：" + str(drop.item["name"])
	if player.global_position.distance_to(_portal_position) < 3.0:
		return "[E] " + ("開始遠征" if zone == "camp" else "返回營地")
	return "靠近傳送門或戰利品，按 E 互動。"

func _interact() -> void:
	var nearest = null
	var best: float = 2.3
	for drop in get_tree().get_nodes_in_group("loot"):
		if not is_instance_valid(drop) or drop.is_queued_for_deletion():
			continue
		var distance: float = drop.global_position.distance_to(player.global_position)
		if distance < best:
			best = distance
			nearest = drop
	if nearest != null:
		inventory.append(nearest.item.duplicate(true))
		hud.announce("取得：" + str(nearest.item["name"]))
		nearest.queue_free()
		save_progress()
		return
	if player.global_position.distance_to(_portal_position) < 3.0:
		_enter_zone("field" if zone == "camp" else "camp")
		hud.announce("進入荒野：擊敗 %d 隻敵人並挑戰首領！" % target_kills if zone == "field" else "返回營地：檢視戰利品並調整寶石。")

func equip_item(index: int) -> void:
	if index < 0 or index >= inventory.size():
		return
	var item: Dictionary = inventory.pop_at(index)
	var slot: String = str(item.get("slot", ""))
	if not equipment.has(slot):
		inventory.append(item)
		return
	inventory.append(equipment[slot].duplicate(true))
	equipment[slot] = item
	player.refresh_equipment()
	hud.announce("已裝備：" + str(item["name"]))
	save_progress()

func player_died() -> void:
	hud.close_panels()
	_enter_zone("camp")
	hud.announce("你倒下了。已在營地重生，裝備和背包保留。")

func spawn_burst(at: Vector3, tint: Color, radius: float) -> void:
	var fx := MeshInstance3D.new()
	fx.mesh = SphereMesh.new()
	fx.material_override = _mat(tint, true)
	fx.position = at
	fx.scale = Vector3.ONE * 0.12
	fx.add_to_group("combat_fx")
	add_child(fx)
	var tween := create_tween()
	tween.tween_property(fx, "scale", Vector3.ONE * maxf(0.22, radius), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(fx, "scale", Vector3.ZERO, 0.22)
	tween.tween_callback(fx.queue_free)

func telegraph(at: Vector3, radius: float, duration: float) -> void:
	var warning := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04
	warning.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.99, 0.22, 0.32, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warning.material_override = mat
	warning.position = Vector3(at.x, 0.07, at.z)
	warning.scale = Vector3(0.4, 1.0, 0.4)
	warning.add_to_group("combat_fx")
	add_child(warning)
	var tween := create_tween()
	tween.tween_property(warning, "scale", Vector3.ONE, duration)
	tween.tween_callback(warning.queue_free)

func show_damage(at: Vector3, amount: int, tint: Color) -> void:
	var text := Label3D.new()
	text.text = str(amount)
	text.font_size = 65 if amount > 40 else 51
	text.pixel_size = 0.0055
	text.outline_size = 11
	text.modulate = tint
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.position = at + Vector3(randf_range(-0.25, 0.25), 1.0, 0)
	text.add_to_group("combat_fx")
	add_child(text)
	var tween := create_tween()
	tween.tween_property(text, "position", text.position + Vector3(0, 1.3, 0), 0.55)
	tween.tween_callback(text.queue_free)

func _load_progress() -> void:
	equipment = {"weapon": {"slot": "weapon"}, "armor": {"slot": "armor"}}
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	if data.get("inventory") is Array:
		inventory = data["inventory"]
	if data.get("equipment") is Dictionary:
		for slot in ["weapon", "armor"]:
			if data["equipment"].get(slot) is Dictionary:
				equipment[slot] = data["equipment"][slot]
	if data.get("socket_gems") is Array and data["socket_gems"].size() == 3:
		socket_gems = data["socket_gems"]
	kills = maxi(0, int(data.get("kills", 0)))
	level = maxi(1, int(data.get("level", 1)))
	runs = maxi(0, int(data.get("runs", 0)))

func save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not create save file: " + SAVE_PATH)
		return
	var data := {
		"version": 1, "inventory": inventory,
		"equipment": equipment, "socket_gems": socket_gems,
		"kills": kills, "level": level, "runs": runs
	}
	file.store_string(JSON.stringify(data, "  "))
