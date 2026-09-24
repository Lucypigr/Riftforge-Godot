extends "res://scripts/phase6_mobile_controls.gd"
## Phase 10 mobile casting: two assignable mobile-facing hotbar slots use hold -> aim -> drag -> release.

var nova_origin := Vector2.ZERO
var nova_dragging := false

func _layout() -> void:
	super._layout()
	if not enabled or not is_instance_valid(game) or not is_instance_valid(game.hud):
		return
	var design_size: Vector2 = game.hud.GEM_PANEL_SIZE
	var panel: PanelContainer = game.hud._gems_panel
	panel.pivot_offset = design_size * 0.5
	var fit: float = minf(1.0, minf((surface.size.x - 28.0) / design_size.x, (surface.size.y - 24.0) / design_size.y))
	panel.scale = Vector2.ONE * maxf(0.2, fit)

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
			_update_skill_aim(event.position - attack_origin, 0)
			get_viewport().set_input_as_handled()
		elif event.index == nova_id:
			_update_skill_aim(event.position - nova_origin, 1)
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
	elif _in_button(pos, "nova", 47.0) and nova_id < 0:
		nova_id = id
		nova_origin = pos
		nova_dragging = false
	elif _in_button(pos, "dash", 47.0):
		game.mobile_dash_requested = true
	elif _in_button(pos, "interact", 43.0) and _has_interaction():
		game._interact()
	else:
		return
	get_viewport().set_input_as_handled()
	surface.queue_redraw()

func _update_skill_aim(drag: Vector2, slot: int) -> void:
	if drag.length() <= 22.0:
		return
	var direction: Vector3 = Vector3(drag.x, 0, drag.y).normalized()
	game.aim_direction = direction
	if slot == 0:
		dragging_aim = true
	else:
		nova_dragging = true
	surface.queue_redraw()

func _end_touch(id: int) -> void:
	if id == joy_id:
		joy_id = -1
		joy_value = Vector2.ZERO
		game.mobile_move = Vector2.ZERO
	elif id == attack_id:
		attack_id = -1
		if not game.ui_open:
			game.cast_mobile_slot(0, game.aim_direction)
		dragging_aim = false
	elif id == nova_id:
		nova_id = -1
		if not game.ui_open:
			game.cast_mobile_slot(1, game.aim_direction)
		nova_dragging = false
	else:
		return
	get_viewport().set_input_as_handled()
	surface.queue_redraw()

func _cancel_combat() -> void:
	super._cancel_combat()
	nova_dragging = false

func _process(_delta: float) -> void:
	if not enabled or not is_instance_valid(game.player):
		return
	if game.ui_open and (joy_id >= 0 or attack_id >= 0 or nova_id >= 0):
		_cancel_combat()
	surface.queue_redraw()

func _draw_hud() -> void:
	if not enabled or not is_instance_valid(game.player):
		return
	var s: Vector2 = surface.size
	if s.x < s.y:
		surface.draw_rect(Rect2(Vector2.ZERO, s), Color(0.025, 0.047, 0.08, 0.88))
		_text("請將手機橫向旋轉", s * 0.5, 28)
		return
	var base: Vector2 = joy_origin if joy_id >= 0 else _center("joy")
	_circle(base, 76.0, Color("#8eb4c9"), joy_id >= 0)
	surface.draw_circle(base + joy_value * JOY_RADIUS, 31.0, Color(0.45, 0.8, 0.91, 0.80))
	_text("移動", base + Vector2(0, -91), 16, Color("#c9e2eb"))
	_draw_skill_button(0, "attack", 57.0, Color("#e9a45b"), attack_id >= 0)
	_draw_skill_button(1, "nova", 43.0, Color("#6ccef2"), nova_id >= 0)
	_circle(_center("dash"), 43.0, Color("#74e5ba"))
	_text("閃避", _center("dash"), 17)
	if game.player.dash_cooldown > 0.0:
		_text("%.1f" % game.player.dash_cooldown, _center("dash") + Vector2(0, 27), 14, Color("#fbd7a5"))
	var interaction_label: String = game.interaction_action_label()
	if not interaction_label.is_empty():
		_circle(_center("interact"), 38.0, Color("#eac27c"))
		_text(interaction_label, _center("interact"), 16)
	for key in ["inventory", "gems"]:
		var c: Vector2 = _center(key)
		surface.draw_rect(Rect2(c - Vector2(43, 22), Vector2(86, 44)), Color(0.04, 0.10, 0.15, 0.90), true)
		surface.draw_rect(Rect2(c - Vector2(43, 22), Vector2(86, 44)), Color("#7292a4"), false, 2.0)
		_text("背包" if key == "inventory" else "寶石", c, 17)
	if attack_id >= 0 and game.skill_requires_aim(0):
		_draw_aim_preview(0, _center("attack"))
	if nova_id >= 0 and game.skill_requires_aim(1):
		_draw_aim_preview(1, _center("nova"))

func _draw_skill_button(slot: int, action: String, radius: float, tint: Color, active: bool) -> void:
	_circle(_center(action), radius, tint, active)
	var gem_id: String = game.skill_gem(slot)
	var label: String = game.skill_name(gem_id)
	_text(label if not label.is_empty() else "空", _center(action), 15)
	var cooldown: float = game.skill_cooldown(gem_id)
	if cooldown > 0.0:
		_text("%.1f" % cooldown, _center(action) + Vector2(0, 27), 13, Color("#fbd7a5"))

func _draw_aim_preview(slot: int, center: Vector2) -> void:
	var delta: Vector2 = Vector2(game.aim_direction.x, game.aim_direction.z) * 78.0
	var end: Vector2 = center + delta
	var kind: String = game.skill_preview_kind(slot)
	if kind == "melee_cone":
		var normal: Vector2 = delta.normalized()
		var left: Vector2 = normal.rotated(-0.45) * 72.0
		var right: Vector2 = normal.rotated(0.45) * 72.0
		surface.draw_line(center, center + left, Color("#ffcf7d"), 4.0, true)
		surface.draw_line(center, center + right, Color("#ffcf7d"), 4.0, true)
	elif kind == "ground_area":
		surface.draw_line(center, end, Color("#ff9b70"), 4.0, true)
		surface.draw_circle(end, 18.0, Color(1.0, 0.35, 0.15, 0.22))
		surface.draw_arc(end, 18.0, 0.0, TAU, 32, Color("#ff9b70"), 3.0, true)
	else:
		surface.draw_line(center, end, Color("#ffcf7d"), 5.0, true)
		surface.draw_circle(end, 9.0, Color("#ffcf7d"))
