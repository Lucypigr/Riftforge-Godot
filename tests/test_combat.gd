extends SceneTree
## Run with: godot --headless --path . --script res://tests/test_combat.gd
const COMBAT = preload("res://scripts/combat_math.gd")
const GEMS = preload("res://scripts/gem_rules.gd")

func _initialize() -> void:
	var failed := 0
	failed += _assert_equal("base damage", COMBAT.damage(100, 0, 0, 1, 0, 1.5, 0, 0.5), 100)
	failed += _assert_equal("50% resistance", COMBAT.damage(100, 0, 0, 1, 0, 1.5, 0.5, 0.5), 50)
	failed += _assert_equal("crit hit", COMBAT.damage(100, 0, 0, 1, 1, 1.5, 0, 0.5), 150)
	failed += _assert_equal("armor cap", COMBAT.incoming(100, 0.9), 30)
	var base: Dictionary = GEMS.modifiers(["ember_bolt", "", ""])
	failed += _assert_equal("no support count", int(base["projectile_count"]), 1)
	var supports: Dictionary = GEMS.modifiers(["ember_bolt", "scatter", "pierce"])
	failed += _assert_equal("linked multishot", int(supports["projectile_count"]), 3)
	failed += _assert_equal("linked piercing", int(supports["pierce_count"]), 1)
	failed += _assert_equal("no inactive skill", int(GEMS.modifiers(["", "scatter", "pierce"])["projectile_count"]), 1)
	print("TEST RESULT: %d passed / %d failed" % [8 - failed, failed])
	quit(0 if failed == 0 else 1)

func _assert_equal(label: String, actual, expected) -> int:
	if actual != expected:
		push_error("FAIL %s: got %s expected %s" % [label, actual, expected])
		return 1
	print("PASS ", label)
	return 0
