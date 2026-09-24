extends SceneTree
## Synthetic regression: godot --headless --path . --script res://tests/test_phase2_skill_core.gd
const SkillDefinition = preload("res://research/phase2/skill_definition.gd")
const SkillRuntime = preload("res://research/phase2/skill_runtime.gd")

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	var bolt = SkillDefinition.new()
	bolt.skill_id = &"example_bolt"
	bolt.display_name = "Example Bolt"
	bolt.delivery = "projectile"
	bolt.base_damage = 100.0
	bolt.mana_cost = 12.0
	bolt.cooldown = 0.5
	bolt.crit_chance = 0.0
	var nova = SkillDefinition.new()
	nova.skill_id = &"example_nova"
	nova.display_name = "Example Nova"
	nova.delivery = "area"
	nova.radius = 4.0
	nova.base_damage = 40.0
	nova.mana_cost = 20.0
	nova.cooldown = 2.0

	_check("skill definition valid", bolt.validate().is_empty())
	_check("area requires radius", _invalid_area_has_error())
	var runtime = SkillRuntime.new(100.0)
	var rejected: Dictionary = runtime.cast(bolt, Vector3.ZERO, Vector3.ZERO, [])
	_check("invalid aim rejected", rejected.get("reason", "") == "invalid_aim")
	_check("invalid aim spends no mana", is_equal_approx(runtime.mana, 100.0))
	var first: Dictionary = runtime.cast(bolt, Vector3.ZERO, Vector3.RIGHT, [])
	_check("projectile cast accepted", first.get("ok", false))
	_check("projectile spawn emitted", first["shots"].size() == 1)
	_check("no instant projectile hit", first["hits"].is_empty())
	_check("mana consumed once", is_equal_approx(runtime.mana, 88.0))
	_check("cooldown started", is_equal_approx(runtime.remaining(bolt.skill_id), 0.5))
	var blocked: Dictionary = runtime.cast(bolt, Vector3.ZERO, Vector3.RIGHT, [])
	_check("repeat cast rejected on cooldown", blocked.get("reason", "") == "cooldown")
	_check("cooldown rejection spends no mana", is_equal_approx(runtime.mana, 88.0))
	runtime.advance(0.5)
	_check("cooldown expires", is_equal_approx(runtime.remaining(bolt.skill_id), 0.0))
	var target: Dictionary = {"id": "dummy", "hp": 100.0, "position": Vector3(2, 0, 0), "resistance": 0.5}
	var impact: Dictionary = runtime.resolve_projectile_hit(bolt, target)
	_check("50 percent resistance", impact.get("damage", -1) == 50)
	_check("collision includes hit feedback", impact.get("feedback", {}).get("type", "") == "hit")
	bolt.crit_chance = 1.0
	var crit: Dictionary = runtime.resolve_projectile_hit(bolt, target, {}, 0.1)
	_check("critical damage and resistance", crit.get("damage", -1) == 75 and crit.get("critical", false))
	var dead: Dictionary = runtime.resolve_projectile_hit(bolt, {"id": "dead", "hp": 0.0})
	_check("dead target ignored", not dead.get("ok", true))
	var aoe: Array = [
		{"id": "inside", "hp": 100.0, "position": Vector3(3, 0, 0)},
		{"id": "outside", "hp": 100.0, "position": Vector3(5, 0, 0)},
		{"id": "dead", "hp": 0.0, "position": Vector3.ZERO},
	]
	var nova_cast: Dictionary = runtime.cast(nova, Vector3.ZERO, Vector3.ZERO, aoe)
	_check("area skill does not need aim", nova_cast.get("ok", false))
	_check("area affects live targets in radius only", nova_cast["hits"].size() == 1 and nova_cast["hits"][0]["target_id"] == "inside")
	_check("area produces per-target feedback", nova_cast["feedback"].size() == 1)
	var low_mana = SkillRuntime.new(4.0)
	_check("low mana blocks cast", low_mana.can_cast(bolt).get("reason", "") == "insufficient_mana")
	print("PHASE2 TEST RESULT: %d passed / %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _invalid_area_has_error() -> bool:
	var area = SkillDefinition.new()
	area.skill_id = &"bad_area"
	area.delivery = "area"
	return not area.validate().is_empty()

func _check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
