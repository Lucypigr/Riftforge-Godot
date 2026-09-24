extends RefCounted
## Original Riftforge active/support gem data plus equipment socket/link helpers.
## Supports never occupy the hotbar; only installed active gems can be assigned there.
const GEM_DATA = {
	"ember_bolt": {
		"kind": "active", "color": "red", "level": 1,
		"display_name": "燼焰彈",
		"tags": ["fire", "projectile", "spell"],
		"summary": "發射火焰投射物。",
		"icon": "res://assets/ui/skills/ember_bolt.svg"
	},
	"shock_nova": {
		"kind": "active", "color": "blue", "level": 1,
		"display_name": "震盪環",
		"tags": ["lightning", "area", "spell"],
		"summary": "以自身為中心釋放閃電範圍傷害。",
		"icon": "res://assets/ui/skills/shock_nova.svg"
	},
	"scatter": {
		"kind": "support", "color": "green", "level": 1,
		"display_name": "分裂輔助",
		"tags": ["support", "projectile"],
		"requires": ["projectile"],
		"summary": "額外發射投射物，但降低單發傷害。",
		"mana_multiplier": 1.0
	},
	"pierce": {
		"kind": "support", "color": "blue", "level": 1,
		"display_name": "穿透輔助",
		"tags": ["support", "projectile"],
		"requires": ["projectile"],
		"summary": "投射物可額外穿透 1 個敵人。",
		"mana_multiplier": 1.0
	}
}
const LINKS = [[0, 1], [1, 2]]

static func definition(gem_id: String) -> Dictionary:
	return (GEM_DATA.get(gem_id, {}) as Dictionary).duplicate(true)

static func is_gem(gem_id: String) -> bool:
	return GEM_DATA.has(gem_id)

static func is_active(gem_id: String) -> bool:
	return GEM_DATA.has(gem_id) and str(GEM_DATA[gem_id].get("kind", "")) == "active"

static func is_support(gem_id: String) -> bool:
	return GEM_DATA.has(gem_id) and str(GEM_DATA[gem_id].get("kind", "")) == "support"

static func display_name(gem_id: String) -> String:
	if not GEM_DATA.has(gem_id):
		return ""
	return str(GEM_DATA[gem_id].get("display_name", gem_id))

static func icon_path(gem_id: String) -> String:
	if not GEM_DATA.has(gem_id):
		return "res://assets/ui/skills/empty.svg"
	return str(GEM_DATA[gem_id].get("icon", "res://assets/ui/skills/empty.svg"))

static func gem_color(gem_id: String) -> String:
	return str(GEM_DATA.get(gem_id, {}).get("color", ""))

static func tags(gem_id: String) -> Array:
	return (GEM_DATA.get(gem_id, {}).get("tags", []) as Array).duplicate()

static func required_tags(gem_id: String) -> Array:
	return (GEM_DATA.get(gem_id, {}).get("requires", []) as Array).duplicate()

static func color_compatible(gem_id: String, socket_color: String) -> bool:
	if not is_gem(gem_id):
		return false
	var color := gem_color(gem_id)
	return socket_color == "white" or socket_color == color

static func support_compatible(active_id: String, support_id: String) -> bool:
	if not is_active(active_id) or not is_support(support_id):
		return false
	var active_tags: Array = tags(active_id)
	for required in required_tags(support_id):
		if not (required in active_tags):
			return false
	return true

static func connected_component(socket_index: int, installed_gems: Array, socket_links: Array) -> Array:
	if socket_index < 0 or socket_index >= installed_gems.size():
		return []
	var visited: Array = [socket_index]
	var changed := true
	while changed:
		changed = false
		for raw_link in socket_links:
			if not (raw_link is Array) or raw_link.size() != 2:
				continue
			var a := int(raw_link[0])
			var b := int(raw_link[1])
			if a < 0 or b < 0 or a >= installed_gems.size() or b >= installed_gems.size():
				continue
			if a in visited and not (b in visited):
				visited.append(b)
				changed = true
			elif b in visited and not (a in visited):
				visited.append(a)
				changed = true
	return visited

static func linked_supports(item: Dictionary, active_socket: int) -> Array:
	var installed: Array = item.get("installed_gems", [])
	if active_socket < 0 or active_socket >= installed.size():
		return []
	var active_id := str(installed[active_socket])
	if not is_active(active_id):
		return []
	var component := connected_component(active_socket, installed, item.get("socket_links", []))
	var result: Array = []
	var seen: Dictionary = {}
	for socket_index in component:
		var support_id := str(installed[int(socket_index)])
		if not is_support(support_id) or seen.has(support_id):
			continue
		if support_compatible(active_id, support_id):
			seen[support_id] = true
			result.append(support_id)
	return result

static func active_supports(equipment: Dictionary, active_id: String) -> Array:
	for equipment_slot in ["weapon", "armor"]:
		var item = equipment.get(equipment_slot, {})
		if not (item is Dictionary):
			continue
		var installed: Array = item.get("installed_gems", [])
		for i in range(installed.size()):
			if str(installed[i]) == active_id:
				return linked_supports(item, i)
	return []

static func modifiers_for_equipment(equipment: Dictionary, active_id: String) -> Dictionary:
	var result := {"projectile_count": 1, "damage_multiplier": 1.0, "pierce_count": 0, "supports": []}
	var support_ids: Array = active_supports(equipment, active_id)
	result["supports"] = support_ids.duplicate()
	for support_id in support_ids:
		match str(support_id):
			"scatter":
				result["projectile_count"] = 3
				result["damage_multiplier"] = float(result["damage_multiplier"]) * 0.78
			"pierce":
				result["pierce_count"] = int(result["pierce_count"]) + 1
	return result

static func modifiers(socket_gems: Array) -> Dictionary:
	# Legacy Phase 2/7 compatibility path for saves that have not migrated to
	# equipment-owned sockets yet.
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
	var seen: Dictionary = {}
	for slot in range(1, socket_gems.size()):
		if not (slot in visited):
			continue
		var gem_id: String = str(socket_gems[slot])
		if not GEM_DATA.has(gem_id) or seen.has(gem_id):
			continue
		var gem: Dictionary = GEM_DATA[gem_id]
		if gem["kind"] != "support":
			continue
		var compatible := true
		for tag in gem.get("requires", []):
			if not (tag in active_tags):
				compatible = false
		if not compatible:
			continue
		seen[gem_id] = true
		match gem_id:
			"scatter":
				result["projectile_count"] = 3
				result["damage_multiplier"] = float(result["damage_multiplier"]) * 0.78
			"pierce":
				result["pierce_count"] = int(result["pierce_count"]) + 1
	return result

static func gem_detail(gem_id: String) -> String:
	var gem := definition(gem_id)
	if gem.is_empty():
		return "未知寶石"
	var color_name := {"red": "紅色", "green": "綠色", "blue": "藍色"}.get(str(gem.get("color", "")), "無色")
	var kind_name := "主動" if is_active(gem_id) else "輔助"
	var lines := [
		"%s" % display_name(gem_id),
		"%s｜%s｜等級 %d" % [color_name, kind_name, int(gem.get("level", 1))],
		"Tags: %s" % ", ".join(PackedStringArray(gem.get("tags", []))),
		str(gem.get("summary", ""))
	]
	if is_support(gem_id):
		lines.append("支援：%s" % ", ".join(PackedStringArray(gem.get("requires", []))))
		lines.append("Mana Multiplier: %.1f" % float(gem.get("mana_multiplier", 1.0)))
	return "\n".join(lines)
