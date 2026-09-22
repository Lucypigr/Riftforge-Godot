extends Control
## Functional proximity radar: markers are based on live scene positions, not a static image.
var game
var world_radius: float = 25.0
var _redraw_wait: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(152, 152)

func _process(delta: float) -> void:
	_redraw_wait -= delta
	if _redraw_wait <= 0.0:
		_redraw_wait = 0.15
		queue_redraw()

func _marker_position(world_position: Vector3) -> Vector2:
	var relative: Vector3 = world_position - game.player.global_position
	var half: Vector2 = size * 0.5
	var scaled: Vector2 = Vector2(relative.x, relative.z) * (minf(size.x, size.y) * 0.43 / world_radius)
	return half + scaled.limit_length(minf(size.x, size.y) * 0.43)

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color("#101722e6"), true)
	draw_rect(bounds, Color("#92734b"), false, 3.0)
	var center: Vector2 = size * 0.5
	for offset in [-0.5, 0.0, 0.5]:
		var x: float = center.x + offset * size.x * 0.7
		var y: float = center.y + offset * size.y * 0.7
		draw_line(Vector2(x, 4.0), Vector2(x, size.y - 4.0), Color("#293643"), 1.0)
		draw_line(Vector2(4.0, y), Vector2(size.x - 4.0, y), Color("#293643"), 1.0)
	if game == null or not is_instance_valid(game.player):
		return
	var portal: Vector3 = game._portal_position
	draw_circle(_marker_position(portal), 4.0, Color("#64d2ff"))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.hp > 0.0:
			draw_circle(_marker_position(enemy.global_position), 4.0 if enemy.boss else 2.5, Color("#fc6777"))
	draw_circle(center, 4.5, Color("#f7e8bd"))
	draw_line(center, center + Vector2(game.aim_direction.x, game.aim_direction.z).normalized() * 11.0, Color("#fff0c4"), 2.0)
	var font: Font = load("res://fonts/NotoSansTC.ttf") as Font if ResourceLoader.exists("res://fonts/NotoSansTC.ttf") else ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(6.0, 16.0), "荒野" if game.zone == "field" else "營地", HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, 12, Color("#dbc298"))
