extends Control
## Lightweight, touch-friendly original item grid: selection is based on occupied cells.
signal cell_pressed(x: int, y: int)
const Grid = preload("res://scripts/grid_inventory.gd")
const CELL := 37.0
const FONT_PATH := "res://fonts/NotoSansTC.ttf"
var items: Array = []
var selected_index := -1
var _font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(Grid.COLS * CELL, Grid.ROWS * CELL)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load(FONT_PATH) as Font if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font

func show_items(source: Array, selected: int) -> void:
	items = source
	selected_index = selected
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var x := int(floor(event.position.x / CELL))
		var y := int(floor(event.position.y / CELL))
		if x >= 0 and x < Grid.COLS and y >= 0 and y < Grid.ROWS:
			cell_pressed.emit(x, y)
			accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		var x := int(floor(event.position.x / CELL))
		var y := int(floor(event.position.y / CELL))
		if x >= 0 and x < Grid.COLS and y >= 0 and y < Grid.ROWS:
			cell_pressed.emit(x, y)
			accept_event()

func _draw() -> void:
	var size := Vector2(Grid.COLS * CELL, Grid.ROWS * CELL)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#09121c"), true)
	for y in range(Grid.ROWS):
		for x in range(Grid.COLS):
			var cell := Rect2(Vector2(x, y) * CELL, Vector2.ONE * CELL)
			draw_rect(cell, Color("#253442"), false, 1.0)
	for i in range(items.size()):
		var item: Dictionary = items[i]
		if not Grid.placed(item):
			continue
		var footprint := Grid.footprint(item)
		var origin := Vector2(float(item["grid_x"]), float(item["grid_y"])) * CELL
		var rect := Rect2(origin + Vector2.ONE * 2.0, Vector2(footprint) * CELL - Vector2.ONE * 4.0)
		var rarity := str(item.get("rarity", "普通"))
		var fill := Color("#574329") if rarity == "稀有" else (Color("#263d63") if rarity == "魔法" else Color("#35424c"))
		draw_rect(rect, fill, true)
		draw_rect(rect, Color("#ffe49b") if i == selected_index else Color("#a3bdcd"), false, 3.0 if i == selected_index else 1.5)
		if _font != null:
			var name := str(item.get("name", "物品"))
			if name.length() > 6:
				name = name.substr(0, 6) + "…"
			var text_at := rect.position + Vector2(2, minf(rect.size.y - 4.0, rect.size.y * 0.50))
			draw_string(_font, text_at, name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 4.0, 12, Color("#f8f2e6"))
