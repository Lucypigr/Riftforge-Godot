extends Node
## Web exports cannot rely on the player's installed CJK fonts. The Web build
## downloads an OFL-licensed Traditional Chinese font before export.
## Desktop/editor builds without that optional font retain the OS fallback.
const FONT_PATH := "res://fonts/NotoSansTC.ttf"

var _font: Font

func _ready() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	_font = load(FONT_PATH) as Font
	if _font == null:
		push_warning("Traditional Chinese font resource could not be loaded.")
		return
	get_tree().node_added.connect(_apply_font)
	_apply_existing(get_tree().root)

func _apply_existing(node: Node) -> void:
	_apply_font(node)
	for child in node.get_children():
		_apply_existing(child)

func _apply_font(node: Node) -> void:
	if _font == null:
		return
	if node is Label3D:
		(node as Label3D).font = _font
	elif node is Control:
		(node as Control).add_theme_font_override("font", _font)
