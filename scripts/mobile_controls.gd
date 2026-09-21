extends CanvasLayer
## Landscape mobile ARPG controls: separate touch IDs for moving and attacking.
const FONT_PATH := "res://fonts/NotoSansTC.ttf"
const JOY_RADIUS := 64.0
const TOUCH_RADIUS := 86.0

var game
var surface: Control
var font: Font
var joy_id := -1
var attack_id := -1
var nova_id := -1
var joy_origin := Vector2.ZERO
var joy_value := Vector2.ZERO
var attack_origin := Vector2.ZERO
var dragging_aim := false
var enabled := false

func _ready() -> void:
	game = get_parent()
	surface = Control.new()
	surface.name = "TouchHUD"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	# Set full-screen anchors only after adding the Control to its CanvasLayer.
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.draw.connect(_draw_hud)
	surface.resized.connect(_layout)
	font = load(FONT_PATH) as Font if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font
	call_deferred("_initialize")

func _initialize() -> void:
	if not is_instance_valid(game.hud):
		push_warning("Mobile HUD initialization delayed: game HUD unavailable.")
		call_deferred("_initialize")
		return
	enabled = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		# Godot 4.3 has JavaScriptBridge.eval(), but NOT JavaScriptBridge.is_available().
		var browser_touch = JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches || navigator.maxTouchPoints > 0 || /Android|iPhone|iPad|iPod/i.test(navigator.userAgent) || location.search.includes('touch=1')")
		enabled = enabled or bool(browser_touch)
	game.mobile_active = enabled
	surface.visible = enabled
	if not enabled:
		return
	if game.hud._root.get_child_count() >= 3:
		game.hud._root.get_child(1).hide()
		game.hud._root.get_child(2).hide()
	_layout()

func _layout() -> void:
	if not enabled or not is_instance_valid(game.hud):
		return
	var s: Vector2 = surface.size
	for panel in [game.hud._inventory_panel, game.hud._gems_panel]:
		var box_size: Vector2 = Vector2(530, 474) if panel == game.hud._inventory_panel else Vector2(580, 352)
		panel.pivot_offset = box_size * 0.5
		panel.scale = Vector2.ONE * minf(1.0, minf((s.x - 36.0) / box_size.x, (s.y - 28.0) / box_size.y))
	surface.queue_redraw()

func _center(action: String) -> Vector2:
	var s := surface.size
	match action:
		"joy": return Vector2(110, s.y - 112)
		"attack": return Vector2(s.x - 106, s.y - 108)
		"nova": return Vector2(s.x - 205, s.y - 194)
		"dash": return Vector2(s.x - 245, s.y - 86)
		"interact": return Vector2(s.x - 106, s.y - 266)
		"inventory": return Vector2(s.x - 155, 46)
		"gems": return Vector2(s.x - 64, 46)
	return Vector2.ZERO

func _in_button(pos: Vector2, action: String, radius: float) -> bool:
	return pos.distance_squared_to(_center(action)) <= radius * radius

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_touch(event.index, event.position)
		else:
			_end_touch(event.index)
	elif event is InputEventScreenDrag:
		if event.index == joy_id:
			_set_joystick(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == attack_id:
			var drag: Vector2 = event.position - attack_origin
			if drag.length() > 22.0:
				dragging_aim = true
				game.aim_direction = Vector3(drag.x, 0, drag.y).normalized()
			surface.queue_redraw()
			get_viewport().set_input_as_handled()

func _start_touch(id: int, pos: Vector2) -> void:
	if _in_button(pos, "inventory", 49.0):
		_cancel_combat()
		game.hud.toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if _in_button(pos, "gems", 49.0):
		_cancel_combat()
		game.hud.toggle_gems()
		get_viewport().set_input_as_handled()
		return
	if game.ui_open:
		return
	if joy_id < 0 and pos.x < surface.size.x * 0.39 and pos.y > surface.size.y * 0.47:
		joy_id = id
		joy_origin = _center("joy") if pos.distance_to(_center("joy")) < TOUCH_RADIUS else pos
		joy_origin.x = clampf(joy_origin.x, 82.0, surface.size.x * 0.35)
		joy_origin.y = clampf(joy_origin.y, surface.size.y * 0.57, surface.size.y - 80.0)
		_set_joystick(pos)
	elif _in_button(pos, "attack", 61.0) and attack_id < 0:
		attack_id = id
		attack_origin = pos
		dragging_aim = false
		_auto_aim()
		_try_attack()
	elif _in_button(pos, "nova", 47.0) and nova_id < 0:
		nova_id = id
	elif _in_button(pos, "dash", 47.0):
		game.mobile_dash_requested = true
	elif _in_button(pos, "interact", 43.0) and _has_interaction():
		game._interact()
	else:
		return
	get_viewport().set_input_as_handled()
	surface.queue_redraw()

func _end_touch(id: int) -> void:
	if id == joy_id:
		joy_id = -1
		joy_value = Vector2.ZERO
		game.mobile_move = Vector2.ZERO
	elif id == attack_id:
		attack_id = -1
		dragging_aim = false
	elif id == nova_id:
		nova_id = -1
		# The camp is safe but skills can be previewed there. Only enemy spawning is field-only.
		if not game.ui_open and game._nova_cd <= 0.0:
			game.cast_nova()
	else:
		return
	get_viewport().set_input_as_handled()
	surface.queue_redraw()

func _cancel_combat() -> void:
	joy_id = -1
	attack_id = -1
	nova_id = -1
	joy_value = Vector2.ZERO
	game.mobile_move = Vector2.ZERO
	game.mobile_dash_requested = false

func _set_joystick(pos: Vector2) -> void:
	joy_value = (pos - joy_origin) / JOY_RADIUS
	if joy_value.length() < 0.10:
		joy_value = Vector2.ZERO
	else:
		joy_value = joy_value.limit_length(1.0)
	game.mobile_move = joy_value
	surface.queue_redraw()

func _has_interaction() -> bool:
	return game.interaction_hint().begins_with("[E]")

func _auto_aim() -> void:
	var distance := 14.0
	var nearest: Vector3 = Vector3.ZERO
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var d: float = enemy.global_position.distance_to(game.player.global_position)
		if d < distance:
			distance = d
			nearest = enemy.global_position - game.player.global_position
	if distance < 14.0:
		nearest.y = 0.0
		if nearest.length_squared() > 0.02:
			game.aim_direction = nearest.normalized()

func _try_attack() -> void:
	# Do not silently discard mobile skill input just because the player is in camp.
	if not game.ui_open and game._bolt_cd <= 0.0:
		game.cast_bolt()

func _process(_delta: float) -> void:
	if not enabled or not is_instance_valid(game.player):
		return
	if game.ui_open and (joy_id >= 0 or attack_id >= 0 or nova_id >= 0):
		_cancel_combat()
	if attack_id >= 0:
		if not dragging_aim:
			_auto_aim()
		_try_attack()
	surface.queue_redraw()

func _text(message: String, center: Vector2, size: int = 18, tint: Color = Color.WHITE) -> void:
	if font != null:
		surface.draw_string(font, center + Vector2(-60, 6), message, HORIZONTAL_ALIGNMENT_CENTER, 120.0, size, tint)

func _circle(center: Vector2, radius: float, tint: Color, active: bool = false) -> void:
	surface.draw_circle(center, radius, Color(0.035, 0.072, 0.11, 0.72))
	surface.draw_arc(center, radius, 0.0, TAU, 48, tint if active else tint.darkened(0.26), 3.0, true)
	if active:
		surface.draw_circle(center, radius - 7.0, Color(tint.r, tint.g, tint.b, 0.12))

func _draw_hud() -> void:
	if not enabled or not is_instance_valid(game.player):
		return
	var s := surface.size
	if s.x < s.y:
		surface.draw_rect(Rect2(Vector2.ZERO, s), Color(0.025, 0.047, 0.08, 0.88))
		_text("請將手機橫向旋轉", s * 0.5, 28)
		return
	var base: Vector2 = joy_origin if joy_id >= 0 else _center("joy")
	_circle(base, 76.0, Color("#8eb4c9"), joy_id >= 0)
	surface.draw_circle(base + joy_value * JOY_RADIUS, 31.0, Color(0.45, 0.8, 0.91, 0.80))
	_text("移動", base + Vector2(0, -91), 16, Color("#c9e2eb"))
	_circle(_center("attack"), 57.0, Color("#e9a45b"), attack_id >= 0)
	_text("燼焰彈", _center("attack"), 19)
	_circle(_center("nova"), 43.0, Color("#6ccef2"), nova_id >= 0)
	_text("震盪環", _center("nova"), 17)
	if game._nova_cd > 0.0:
		_text("%.1f" % game._nova_cd, _center("nova") + Vector2(0, 27), 14, Color("#fbd7a5"))
	_circle(_center("dash"), 43.0, Color("#74e5ba"))
	_text("閃避", _center("dash"), 17)
	if game.player.dash_cooldown > 0.0:
		_text("%.1f" % game.player.dash_cooldown, _center("dash") + Vector2(0, 27), 14, Color("#fbd7a5"))
	if _has_interaction():
		_circle(_center("interact"), 38.0, Color("#eac27c"))
		_text("拾取" if "拾取" in game.interaction_hint() else "傳送", _center("interact"), 16)
	for key in ["inventory", "gems"]:
		var c := _center(key)
		surface.draw_rect(Rect2(c - Vector2(43, 22), Vector2(86, 44)), Color(0.04, 0.10, 0.15, 0.90), true)
		surface.draw_rect(Rect2(c - Vector2(43, 22), Vector2(86, 44)), Color("#7292a4"), false, 2.0)
		_text("背包" if key == "inventory" else "寶石", c, 17)
	if attack_id >= 0 and dragging_aim:
		var delta: Vector2 = Vector2(game.aim_direction.x, game.aim_direction.z) * 75.0
		surface.draw_line(_center("attack"), _center("attack") + delta, Color("#ffcf7d"), 5.0, true)
		surface.draw_circle(_center("attack") + delta, 9.0, Color("#ffcf7d"))