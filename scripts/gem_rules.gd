extends RefCounted
## Small, data-driven, ORIGINAL active/support gem graph, not a GD/POE data dump.
## Supports never occupy the hotbar; only installed active gems can be assigned there.
const GEM_DATA = {
	"ember_bolt": {
		"kind": "active",
		"display_name": "燼焰彈",
		"tags": ["fire", "projectile", "spell"],
		"icon": "res://assets/ui/skills/ember_bolt.svg"
	},
	"shock_nova": {
		"kind": "active",
		"display_name": "震盪環",
		"tags": ["lightning", "area", "spell"],
		"icon": "res://assets/ui/skills/shock_nova.svg"
	},
	"scatter": {"kind": "support", "display_name": "分裂輔助", "requires": ["projectile"]},
	"pierce": {"kind": "support", "display_name": "穿透輔助", "requires": ["projectile"]}
}
const LINKS = [[0, 1], [1, 2]]

static func is_active(gem_id: String) -> bool:
	return GEM_DATA.has(gem_id) and str(GEM_DATA[gem_id].get("kind", "")) == "active"

static func display_name(gem_id: String) -> String:
	if not GEM_DATA.has(gem_id):
		return ""
	return str(GEM_DATA[gem_id].get("display_name", gem_id))

static func icon_path(gem_id: String) -> String:
	if not GEM_DATA.has(gem_id):
		return "res://assets/ui/skills/empty.svg"
	return str(GEM_DATA[gem_id].get("icon", "res://assets/ui/skills/empty.svg"))

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
