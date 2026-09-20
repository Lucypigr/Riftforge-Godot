extends "res://scripts/game.gd"
## Mobile adapter: desktop gameplay remains unchanged; touch is not a mouse attack.
var mobile_active: bool = false
var mobile_move: Vector2 = Vector2.ZERO
var mobile_dash_requested: bool = false

func _update_aim() -> void:
	if not mobile_active:
		super._update_aim()

func _process(delta: float) -> void:
	# Keep parent loop semantics while preventing synthesized touch/mouse events
	# from turning joystick movement or menu taps into normal attacks.
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
		if not mobile_active and Input.is_action_pressed("attack") and _bolt_cd <= 0.0:
			cast_bolt()
		if not mobile_active and Input.is_action_just_pressed("nova") and _nova_cd <= 0.0:
			cast_nova()
		_process_spawns(delta)
