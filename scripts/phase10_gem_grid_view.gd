extends "res://scripts/inventory_grid_view.gd"
## Phase 10 grid keeps the Phase 8 18x10 geometry but exposes real gem drag/drop.
signal gem_drop_to_bag(data: Dictionary, x: int, y: int)
const GemRules = preload("res://scripts/gem_rules.gd")

func _cell_from_point(point: Vector2) -> Vector2i:
	return Vector2i(int(floor(point.x / CELL)), int(floor(point.y / CELL)))

func _get_drag_data(at_position: Vector2):
	var cell := _cell_from_point(at_position)
	if cell.x < 0 or cell.x >= Grid.COLS or cell.y < 0 or cell.y >= Grid.PAGE_ROWS:
		return null
	var index := Grid.item_at(items, cell.x, cell.y)
	if index < 0 or index >= items.size():
		return null
	var item: Dictionary = items[index]
	var gem_id := str(item.get("gem_id", ""))
	if str(item.get("slot", "")) != "gem" or not GemRules.is_gem(gem_id):
		return null
	var data := {"kind": "inventory_gem", "inventory_index": index, "gem_id": gem_id}
	if get_viewport().gui_is_dragging():
		var preview := Label.new()
		preview.text = GemRules.display_name(gem_id)
		preview.add_theme_font_size_override("font_size", 15)
		var font_path := "res://fonts/NotoSansTC.ttf"
		if ResourceLoader.exists(font_path):
			preview.add_theme_font_override("font", load(font_path) as Font)
		set_drag_preview(preview)
	return data

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not (data is Dictionary):
		return false
	if not (str(data.get("kind", "")) in ["socket_gem", "inventory_gem"]):
		return false
	var cell := _cell_from_point(at_position)
	return cell.x >= 0 and cell.x < Grid.COLS and cell.y >= 0 and cell.y < Grid.PAGE_ROWS

func _drop_data(at_position: Vector2, data) -> void:
	if not _can_drop_data(at_position, data):
		return
	var cell := _cell_from_point(at_position)
	gem_drop_to_bag.emit(data, cell.x, cell.y)

func _draw() -> void:
	super._draw()
	for i in range(items.size()):
		var item: Dictionary = items[i]
		if not Grid.placed(item) or str(item.get("slot", "")) != "gem":
			continue
		var gem_id := str(item.get("gem_id", ""))
		if not GemRules.is_gem(gem_id):
			continue
		var center := (Vector2(float(item["grid_x"]), float(item["grid_y"])) + Vector2(0.5, 0.5)) * CELL
		var tint := _gem_color(GemRules.gem_color(gem_id))
		draw_circle(center, 13.0, Color("#090b0e"))
		var points := PackedVector2Array([
			center + Vector2(0, -11), center + Vector2(11, 0),
			center + Vector2(0, 11), center + Vector2(-11, 0)
		])
		draw_colored_polygon(points, tint)
		draw_arc(center, 12.0, 0, TAU, 24, Color("#eee6d8"), 1.5, true)

func _gem_color(color_name: String) -> Color:
	match color_name:
		"red": return Color("#dc5b58")
		"green": return Color("#4dc17a")
		"blue": return Color("#5b91e8")
		_: return Color("#d8d8d0")
