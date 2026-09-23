extends Control
## Phase 8: dense 18x10 item grid. Items are visual silhouettes, never giant text cards.
signal cell_pressed(x: int, y: int)
const Grid = preload("res://scripts/grid_inventory.gd")
const CELL := 42.0
var items: Array = []
var selected_index := -1
var page := 0

func _ready() -> void:
	custom_minimum_size = Vector2(Grid.COLS * CELL, Grid.PAGE_ROWS * CELL)
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_items(source: Array, selected: int, target_page: int = 0) -> void:
	items = source
	selected_index = selected
	page = 0
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var point := Vector2(-1, -1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	else:
		return
	var x := int(floor(point.x / CELL))
	var local_y := int(floor(point.y / CELL))
	if x >= 0 and x < Grid.COLS and local_y >= 0 and local_y < Grid.PAGE_ROWS:
		cell_pressed.emit(x, local_y)
		accept_event()

func _draw() -> void:
	var size := Vector2(Grid.COLS * CELL, Grid.PAGE_ROWS * CELL)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0b0e13"), true)
	for y in range(Grid.PAGE_ROWS):
		for x in range(Grid.COLS):
			var cell := Rect2(Vector2(x, y) * CELL, Vector2.ONE * CELL)
			var checker := Color("#15191f") if (x + y) % 2 == 0 else Color("#12161c")
			draw_rect(cell.grow(-1.0), checker, true)
			draw_rect(cell, Color("#4a4338"), false, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#9a7b4e"), false, 2.0)

	for i in range(items.size()):
		var item: Dictionary = items[i]
		if not Grid.placed(item):
			continue
		var footprint := Grid.footprint(item)
		var origin := Vector2(float(item["grid_x"]), float(item["grid_y"])) * CELL
		var rect := Rect2(origin + Vector2.ONE * 2.0, Vector2(footprint) * CELL - Vector2.ONE * 4.0)
		var rarity := str(item.get("rarity", "普通"))
		var fill := Color("#5b3e20") if rarity == "稀有" else (Color("#173557") if rarity == "魔法" else Color("#272b31"))
		draw_rect(rect, fill, true)
		draw_rect(rect, Color("#f0ca7a") if i == selected_index else _rarity_border(rarity), false, 3.0 if i == selected_index else 1.5)
		_draw_item_glyph(rect, str(item.get("slot", "")), rarity)

func _rarity_border(rarity: String) -> Color:
	match rarity:
		"稀有": return Color("#d7a04b")
		"魔法": return Color("#628fc6")
		_: return Color("#8a8173")

func _draw_item_glyph(rect: Rect2, slot: String, rarity: String) -> void:
	var tint := Color("#e2d8c8")
	if rarity == "稀有":
		tint = Color("#ffd17a")
	elif rarity == "魔法":
		tint = Color("#a9ccff")
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.25
	match slot:
		"weapon":
			var a := rect.position + Vector2(rect.size.x * 0.28, rect.size.y * 0.76)
			var b := rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.20)
			draw_line(a, b, tint, maxf(3.0, rect.size.x * 0.06), true)
			draw_line(a - Vector2(7, 7), a + Vector2(7, 7), tint.darkened(0.15), 3.0, true)
		"armor":
			var w := rect.size.x * 0.28
			var h := rect.size.y * 0.28
			var points := PackedVector2Array([
				center + Vector2(-w, -h * 0.65), center + Vector2(-w * 0.45, -h),
				center + Vector2(0, -h * 0.65), center + Vector2(w * 0.45, -h),
				center + Vector2(w, -h * 0.65), center + Vector2(w * 0.72, h),
				center + Vector2(-w * 0.72, h)
			])
			draw_colored_polygon(points, tint)
		"helmet":
			draw_arc(center, radius, PI, TAU, 18, tint, 4.0, true)
			draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), tint, 4.0)
		"gloves":
			draw_circle(center, radius, tint)
			draw_rect(Rect2(center + Vector2(-radius * 0.7, -radius * 1.5), Vector2(radius * 1.4, radius)), tint, true)
		"boots":
			draw_rect(Rect2(center + Vector2(-radius * 0.6, -radius), Vector2(radius, radius * 1.7)), tint, true)
			draw_rect(Rect2(center + Vector2(-radius * 0.6, radius * 0.35), Vector2(radius * 1.6, radius * 0.55)), tint, true)
		"ring":
			draw_arc(center, radius, 0, TAU, 24, tint, 4.0, true)
		"amulet":
			draw_arc(center + Vector2(0, -radius * 0.25), radius, 0.15 * PI, 0.85 * PI, 20, tint, 3.0, true)
			draw_circle(center + Vector2(0, radius * 0.65), radius * 0.35, tint)
		"gem":
			var points := PackedVector2Array([
				center + Vector2(0, -radius), center + Vector2(radius, 0),
				center + Vector2(0, radius), center + Vector2(-radius, 0)
			])
			draw_colored_polygon(points, tint)
		_:
			draw_circle(center, radius * 0.72, tint)
