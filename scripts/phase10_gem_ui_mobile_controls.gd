extends "res://scripts/phase6_mobile_controls.gd"
## Phase 10 integrated panel sizing. Touch events inside the open UI are left to
## Control nodes; combat/world touch IDs are cancelled by the inherited logic.

func _layout() -> void:
	super._layout()
	if not enabled or not is_instance_valid(game) or not is_instance_valid(game.hud):
		return
	if not game.hud.has_method("_refresh_inventory"):
		return
	var panel: Control = game.hud._inventory_panel
	var design_size: Vector2 = game.hud.POE_PANEL_SIZE
	panel.pivot_offset = design_size * 0.5
	var fit := minf(1.0, minf((surface.size.x - 24.0) / design_size.x, (surface.size.y - 18.0) / design_size.y))
	panel.scale = Vector2.ONE * maxf(0.2, fit)
	surface.queue_redraw()
