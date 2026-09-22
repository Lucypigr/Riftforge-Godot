extends "res://scripts/phase3_game.gd"
## Preserve all Phase 5 systems; replace its visual HUD only after initialization.
const Phase6HUD = preload("res://scripts/phase6_hud.gd")

func _ready() -> void:
	super._ready()
	var previous_hud = hud
	remove_child(previous_hud)
	previous_hud.queue_free()
	hud = Phase6HUD.new()
	hud.initialize(self)
	add_child(hud)
	hud.announce("Phase 6：生命在左、魔力在右；按 I 開啟背包")
