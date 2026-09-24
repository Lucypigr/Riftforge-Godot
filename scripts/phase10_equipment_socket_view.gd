extends Control
## Draws weapon/armor sockets and links in one compact POE-inspired equipment strip.
signal socket_pressed(equipment_slot: String, socket_index: int)
signal gem_drop_requested(data: Dictionary, equipment_slot: String, socket_index: int)

const GemRules = preload("res://scripts/gem_rules.gd")
const FONT_PATH := "res://fonts/NotoSansTC.ttf"

var equipment: Dictionary = {}
var selected_slot := ""
var selected_socket := -1
var font: Font
var _socket_centers: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(756, 154)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = load(FONT_PATH) as Font if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font

func show_equipment(source: Dictionary, focus_slot: String = "", focus_socket: int = -1) -> void:
	equipment = source
	selected_slot = focus_slot
	selected_socket = focus_socket
	queue_redraw()

func socket_center(slot: String, socket_index: int) -> Vector2:
	var key := "%s:%d" % [slot, socket_index]
	return _socket_centers.get(key, Vector2.ZERO)

func _slot_rect(slot: String) -> Rect2:
	return Rect2(Vector2(9, 8), Vector2(360, 138)) if slot == "weapon" else Rect2(Vector2(387, 8), Vector2(360, 138))

func _socket_hit(point: Vector2) -> Dictionary:
	for slot in ["weapon", "armor"]:
		var item: Dictionary = equipment.get(slot, {})
		var count := int(item.get("socket_count", 0))
		for i in range(count):
			var center := socket_center(slot, i)
			if center != Vector2.ZERO and point.distance_squared_to(center) <= 22.0 * 22.0:
				return {"slot": slot, "socket": i}
	return {}

func _gui_input(event: InputEvent) -> void:
	var point := Vector2(-1000, -1000)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	else:
		return
	var hit := _socket_hit(point)
	if not hit.is_empty():
		socket_pressed.emit(str(hit["slot"]), int(hit["socket"]))
		accept_event()

func _get_drag_data(at_position: Vector2):
	var hit := _socket_hit(at_position)
	if hit.is_empty():
		return null
	var slot := str(hit["slot"])
	var socket_index := int(hit["socket"])
	var item: Dictionary = equipment.get(slot, {})
	var installed: Array = item.get("installed_gems", [])
	if socket_index < 0 or socket_index >= installed.size():
		return null
	var gem_id := str(installed[socket_index])
	if gem_id.is_empty():
		return null
	var data := {
		"kind": "socket_gem",
		"equipment_slot": slot,
		"socket_index": socket_index,
		"gem_id": gem_id
	}
	var preview := Label.new()
	preview.text = GemRules.display_name(gem_id)
	preview.add_theme_font_size_override("font_size", 15)
	if font != null:
		preview.add_theme_font_override("font", font)
	set_drag_preview(preview)
	return data

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not (data is Dictionary):
		return false
	if not (str(data.get("kind", "")) in ["inventory_gem", "socket_gem"]):
		return false
	return not _socket_hit(at_position).is_empty()

func _drop_data(at_position: Vector2, data) -> void:
	if not (data is Dictionary):
		return
	var hit := _socket_hit(at_position)
	if hit.is_empty():
		return
	gem_drop_requested.emit(data, str(hit["slot"]), int(hit["socket"]))

func _draw() -> void:
	_socket_centers.clear()
	for slot in ["weapon", "armor"]:
		var rect := _slot_rect(slot)
		var item: Dictionary = equipment.get(slot, {})
		var title := "武器" if slot == "weapon" else "護甲"
		draw_rect(rect, Color("#11151b"), true)
		draw_rect(rect, Color("#8e744e"), false, 2.0)
		draw_string(font, rect.position + Vector2(15, 25), title, HORIZONTAL_ALIGNMENT_LEFT, 90, 17, Color("#e5c895"))
		var name := str(item.get("name", ""))
		draw_string(font, rect.position + Vector2(15, 49), name if not name.is_empty() else "空裝備欄", HORIZONTAL_ALIGNMENT_LEFT, 320, 15, Color("#edf2f2"))
		var count := int(item.get("socket_count", 0))
		if count <= 0:
			draw_string(font, rect.position + Vector2(15, 82), "裝上物品後顯示插槽", HORIZONTAL_ALIGNMENT_LEFT, 300, 13, Color("#8d98a0"))
			continue
		var colors: Array = item.get("socket_colors", [])
		var installed: Array = item.get("installed_gems", [])
		var centers: Array = []
		var start_x := rect.position.x + 58.0
		var y := rect.position.y + 104.0
		var spacing := 66.0
		for i in range(count):
			var center := Vector2(start_x + float(i) * spacing, y)
			centers.append(center)
			_socket_centers["%s:%d" % [slot, i]] = center
		for raw_link in item.get("socket_links", []):
			if raw_link is Array and raw_link.size() == 2:
				var a := int(raw_link[0])
				var b := int(raw_link[1])
				if a >= 0 and b >= 0 and a < centers.size() and b < centers.size():
					draw_line(centers[a], centers[b], Color("#c7a363"), 7.0, true)
					draw_line(centers[a], centers[b], Color("#302a22"), 3.0, true)
		for i in range(count):
			var center: Vector2 = centers[i]
			var socket_color := str(colors[i]) if i < colors.size() else "white"
			var tint := _socket_color(socket_color)
			draw_circle(center, 20.0, Color("#080a0d"))
			draw_circle(center, 16.5, tint.darkened(0.40))
			draw_arc(center, 20.0, 0, TAU, 32, tint, 3.0, true)
			var gem_id := str(installed[i]) if i < installed.size() else ""
			if not gem_id.is_empty():
				var gem_tint := _socket_color(GemRules.gem_color(gem_id))
				var points := PackedVector2Array([
					center + Vector2(0, -12), center + Vector2(12, 0),
					center + Vector2(0, 12), center + Vector2(-12, 0)
				])
				draw_colored_polygon(points, gem_tint)
				draw_arc(center, 12.0, 0, TAU, 24, Color.WHITE, 1.5, true)
			if selected_slot == slot and selected_socket == i:
				draw_arc(center, 24.0, 0, TAU, 32, Color("#ffe0a0"), 3.0, true)

func _socket_color(color_name: String) -> Color:
	match color_name:
		"red": return Color("#d95757")
		"green": return Color("#48ba78")
		"blue": return Color("#548ee8")
		_: return Color("#d8d8d0")
