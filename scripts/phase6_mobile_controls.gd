extends "res://scripts/phase3_mobile_controls.gd"
## Keep the Phase 3/5 multitouch implementation untouched. Only adapt HUD layout.

func _layout() -> void:
	super._layout()
	if enabled and is_instance_valid(game) and is_instance_valid(game.hud):
		game.hud.set_mobile_layout(true)
