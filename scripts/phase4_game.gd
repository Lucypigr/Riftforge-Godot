extends "res://scripts/phase3_game.gd"
## Phase 4 experiment: enable original typed-damage combat for both PC and touch.
## This branch/scene is separate from Phase 3 and production.

func _ready() -> void:
	super._ready()
	_skill_runtime.use_combat_v2 = true
	_nova_skill.damage_type = &"lightning"
	if is_instance_valid(hud):
		hud.announce("戰鬥 V2：武器物理傷害、屬性抗性與攻防命中已啟用")
