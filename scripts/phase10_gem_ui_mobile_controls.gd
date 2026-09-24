extends "res://scripts/phase6_mobile_controls.gd"
## Phase 10 integrated panel sizing. Touch events inside the open UI are left to
## Control nodes; combat/world touch IDs are cancelled by the inherited logic.

func _layout() -> void:
	super._layout()
	if not enabled or not is_instance_valid(game) or not is_instance_valid(game.hud):
		return
	if game.hud.has_method("set_mobile_inventory_viewport"):
		game.hud.set_mobile_inventory_viewport(surface.size)
	surface.queue_redraw()
