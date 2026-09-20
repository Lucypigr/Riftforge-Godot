extends RefCounted
## Small, data-driven, ORIGINAL active/support gem graph, not a GD/POE data dump.
## Each support must be reachable from active socket 0 AND match the active tags.
const GEM_DATA = {
	"ember_bolt": {"kind": "active", "tags": ["fire", "projectile", "spell"]},
	"scatter": {"kind": "support", "requires": ["projectile"]},
	"pierce": {"kind": "support", "requires": ["projectile"]}
}
const LINKS = [[0, 1], [1, 2]]

static func modifiers(socket_gems: Array) -> Dictionary:
	var result := {"projectile_count": 1, "damage_multiplier": 1.0, "pierce_count": 0}
	if socket_gems.size() < 3 or str(socket_gems[0]) != "ember_bolt":
		return result
	var visited := [0]
	var changed := true
	while changed:
		changed = false
		for link in LINKS:
			var a: int = link[0]
			var b: int = link[1]
			if a in visited and not (b in visited):
				visited.append(b)
				changed = true
			elif b in visited and not (a in visited):
				visited.append(a)
				changed = true
	var active_tags: Array = GEM_DATA["ember_bolt"]["tags"]
	for slot in range(1, socket_gems.size()):
		if not (slot in visited):
			continue
		var gem_id: String = str(socket_gems[slot])
		if not GEM_DATA.has(gem_id):
			continue
		var gem: Dictionary = GEM_DATA[gem_id]
		if gem["kind"] != "support":
			continue
		var compatible := true
		for tag in gem["requires"]:
			if not (tag in active_tags):
				compatible = false
		if not compatible:
			continue
		match gem_id:
			"scatter":
				result["projectile_count"] = 3
				result["damage_multiplier"] *= 0.78
			"pierce":
				result["pierce_count"] += 1
	return result
