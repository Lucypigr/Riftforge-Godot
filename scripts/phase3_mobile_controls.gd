extends "res://scripts/mobile_controls.gd"
## Preserve tested multitouch input. Only adapt the enlarged Phase 3 inventory layout.

func _layout() -> void:
	super._layout()
	if not enabled or not is_instance_valid(game) or not is_instance_valid(game.hud):
		return
	var panel: PanelContainer = game.hud._inventory_panel
	var design_size: Vector2 = game.hud.INVENTORY_PANEL_SIZE
	var visible_size: Vector2 = surface.size
	if visible_size.x <= 0.0 or visible_size.y <= 0.0:
		return
	panel.pivot_offset = design_size * 0.5
	var fit: float = minf(1.0, minf((visible_size.x - 28.0) / design_size.x, (visible_size.y - 24.0) / design_size.y))
	panel.scale = Vector2.ONE * maxf(0.2, fit)
