extends Label
## Compact quest/status line replaces the wide desktop objectives panel.
var game

func _ready() -> void:
	game = get_parent().get_parent()
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -272.0
	offset_right = -14.0
	offset_top = 96.0
	offset_bottom = 127.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 17)
	add_theme_color_override("font_color", Color("#e2f0fa"))
	add_theme_color_override("font_outline_color", Color("#07111d"))
	add_theme_constant_override("outline_size", 4)
	visible = false

func _process(_delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	visible = game.mobile_active
	if not visible:
		return
	if game.zone == "camp":
		text = "營地｜靠近傳送門互動"
	else:
		var boss: String = "已擊敗" if game.boss_defeated else ("出現" if game.boss_spawned else "未出現")
		text = "遠征 %d｜%d/%d｜首領%s" % [game.runs, game.wave_kills, game.target_kills, boss]
