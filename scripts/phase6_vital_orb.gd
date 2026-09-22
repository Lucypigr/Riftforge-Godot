extends Control
## Original vector-drawn vitality display. It never intercepts gameplay input.
var caption: String = "生命"
var fill_color: Color = Color("#d92e45")
var current_value: float = 1.0
var maximum_value: float = 1.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(88, 88)

func configure(title: String, tint: Color) -> void:
	caption = title
	fill_color = tint
	queue_redraw()

func set_values(current: float, maximum: float) -> void:
	var safe_max: float = maxf(0.0, maximum)
	var safe_value: float = clampf(current, 0.0, safe_max)
	if is_equal_approx(current_value, safe_value) and is_equal_approx(maximum_value, safe_max):
		return
	current_value = safe_value
	maximum_value = safe_max
	queue_redraw()

func fill_fraction() -> float:
	return clampf(current_value / maximum_value, 0.0, 1.0) if maximum_value > 0.0 else 0.0

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = maxf(1.0, minf(size.x, size.y) * 0.5 - 5.0)
	var inside: float = maxf(1.0, radius - 9.0)
	# A metallic outer rim and dark glass, drawn entirely with original geometry.
	draw_circle(center, radius + 4.0, Color("#0b0e15"))
	draw_circle(center, radius + 1.0, Color("#725c40"))
	draw_circle(center, radius - 3.0, Color("#1b222d"))
	draw_circle(center, inside, Color("#151b28"))
	var fraction: float = fill_fraction()
	if fraction > 0.0:
		# Trace the lower circular boundary, then close with the horizontal liquid surface.
		# Unlike a rectangular ProgressBar, the liquid always stays inside the circle.
		var surface_y: float = inside * (1.0 - 2.0 * fraction)
		var edge_x: float = sqrt(maxf(0.0, inside * inside - surface_y * surface_y))
		var start_angle: float = atan2(surface_y, -edge_x)
		if surface_y < 0.0:
			start_angle += TAU
		var end_angle: float = atan2(surface_y, edge_x)
		var polygon := PackedVector2Array()
		for i in range(73):
			var angle: float = lerpf(start_angle, end_angle, float(i) / 72.0)
			polygon.append(center + Vector2(cos(angle), sin(angle)) * inside)
		draw_colored_polygon(polygon, fill_color.darkened(0.23))
		draw_line(center + Vector2(-edge_x, surface_y), center + Vector2(edge_x, surface_y), fill_color.lightened(0.42), 1.8, true)
	draw_arc(center, radius - 4.0, 0.0, TAU, 80, Color("#b49a70"), 2.0, true)
	draw_arc(center, radius + 2.0, deg_to_rad(202.0), deg_to_rad(332.0), 26, Color("#eddbb5"), 2.5, true)
	var font: Font = load("res://fonts/NotoSansTC.ttf") as Font if ResourceLoader.exists("res://fonts/NotoSansTC.ttf") else ThemeDB.fallback_font
	if font == null:
		return
	var caption_size: int = maxi(10, int(size.x * 0.12))
	var value_size: int = maxi(10, int(size.x * 0.12))
	draw_string(font, Vector2(0.0, center.y - 3.0), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, caption_size, Color("#fff1d8"))
	draw_string(font, Vector2(0.0, center.y + float(value_size) + 1.0), "%d / %d" % [int(round(current_value)), int(round(maximum_value))], HORIZONTAL_ALIGNMENT_CENTER, size.x, value_size, Color.WHITE)
