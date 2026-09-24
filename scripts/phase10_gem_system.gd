extends RefCounted
## Phase 10 original, data-driven gem catalogue + socket graph + compatibility + modifier pipeline.
## Runtime gameplay consumes only the resolved dictionaries returned here.

const DEFINITIONS := {
	"ember_bolt": {
		"id":"ember_bolt","display_name":"燼焰彈","role":"active","color":"red",
		"tags":["spell","projectile","fire","hit"],"behavior":"projectile",
		"base_damage":16.0,"damage_type":"fire","mana_cost":3.0,"interval":0.205,
		"cast_range":26.0,"projectile_speed":22.0,"projectile_count":1,"pierce":0,"chain":0,
		"aoe_radius":0.0,"duration":0.0,"level":1,"max_level":20,
		"support_restrictions":{},"modifier_data":{},"icon":"res://assets/ui/skills/ember_bolt.svg"
	},
	"shock_nova": {
		"id":"shock_nova","display_name":"震盪環","role":"active","color":"blue",
		"tags":["spell","area","lightning","nova","hit"],"behavior":"nova",
		"base_damage":34.0,"damage_type":"lightning","mana_cost":25.0,"interval":3.6,
		"cast_range":4.6,"projectile_speed":0.0,"projectile_count":0,"pierce":0,"chain":0,
		"aoe_radius":4.6,"duration":0.0,"level":1,"max_level":20,
		"support_restrictions":{},"modifier_data":{},"icon":"res://assets/ui/skills/shock_nova.svg"
	},
	"frost_shard": {
		"id":"frost_shard","display_name":"霜晶矢","role":"active","color":"blue",
		"tags":["spell","projectile","cold","hit"],"behavior":"projectile",
		"base_damage":20.0,"damage_type":"cold","mana_cost":7.0,"interval":0.48,
		"cast_range":24.0,"projectile_speed":18.0,"projectile_count":1,"pierce":0,"chain":0,
		"aoe_radius":0.0,"duration":0.0,"level":1,"max_level":20,
		"support_restrictions":{},"modifier_data":{"slow_multiplier":0.72,"slow_duration":1.4},
		"icon":"res://assets/ui/skills/empty.svg"
	},
	"arc_spark": {
		"id":"arc_spark","display_name":"裂鏈電火","role":"active","color":"blue",
		"tags":["spell","projectile","lightning","chain","hit"],"behavior":"projectile",
		"base_damage":19.0,"damage_type":"lightning","mana_cost":9.0,"interval":0.58,
		"cast_range":22.0,"projectile_speed":21.0,"projectile_count":1,"pierce":0,"chain":2,
		"aoe_radius":0.0,"duration":0.0,"level":1,"max_level":20,
		"support_restrictions":{},"modifier_data":{"chain_range":7.5,"chain_damage_multiplier":0.84},
		"icon":"res://assets/ui/skills/empty.svg"
	},
	"rift_cleave": {
		"id":"rift_cleave","display_name":"裂隙橫斬","role":"active","color":"red",
		"tags":["attack","melee","area","physical","hit"],"behavior":"melee_cone",
		"base_damage":7.0,"damage_type":"physical","mana_cost":2.0,"interval":0.72,
		"cast_range":3.2,"projectile_speed":0.0,"projectile_count":0,"pierce":0,"chain":0,
		"aoe_radius":3.2,"duration":0.0,"level":1,"max_level":20,
		"support_restrictions":{},"modifier_data":{"weapon_damage_multiplier":1.0},
		"icon":"res://assets/ui/skills/empty.svg"
	},
	"cinder_field": {
		"id":"cinder_field","display_name":"燼火領域","role":"active","color":"red",
		"tags":["spell","area","fire","duration"],"behavior":"ground_area",
		"base_damage":8.0,"damage_type":"fire","mana_cost":14.0,"interval":2.8,
		"cast_range":7.0,"projectile_speed":0.0,"projectile_count":0,"pierce":0,"chain":0,
		"aoe_radius":3.1,"duration":4.0,"level":1,"max_level":20,
		"support_restrictions":{},"modifier_data":{"tick_interval":0.5},
		"icon":"res://assets/ui/skills/empty.svg"
	},
	"scatter": {
		"id":"scatter","display_name":"分裂輔助","role":"support","color":"green",
		"tags":["support"],"behavior":"support","level":1,"max_level":20,
		"support_restrictions":{"required_tags":["projectile"],"excluded_tags":[],"behaviors":["projectile"]},
		"modifier_data":{"projectile_count_add":2,"more_damage":0.78,"mana_multiplier":1.15}
	},
	"pierce": {
		"id":"pierce","display_name":"穿透輔助","role":"support","color":"green",
		"tags":["support"],"behavior":"support","level":1,"max_level":20,
		"support_restrictions":{"required_tags":["projectile"],"excluded_tags":[],"behaviors":["projectile"]},
		"modifier_data":{"pierce_add":1,"mana_multiplier":1.10}
	},
	"faster_projectiles": {
		"id":"faster_projectiles","display_name":"迅捷投射輔助","role":"support","color":"green",
		"tags":["support"],"behavior":"support","level":1,"max_level":20,
		"support_restrictions":{"required_tags":["projectile"],"excluded_tags":[],"behaviors":["projectile"]},
		"modifier_data":{"projectile_speed_multiplier":1.30,"mana_multiplier":1.10}
	},
	"added_fire": {
		"id":"added_fire","display_name":"附加火焰輔助","role":"support","color":"red",
		"tags":["support"],"behavior":"support","level":1,"max_level":20,
		"support_restrictions":{"required_tags":["hit"],"excluded_tags":["duration"],"behaviors":[]},
		"modifier_data":{"added_damage_type":"fire","added_damage_ratio":0.30,"mana_multiplier":1.20}
	},
	"increased_area": {
		"id":"increased_area","display_name":"增幅範圍輔助","role":"support","color":"blue",
		"tags":["support"],"behavior":"support","level":1,"max_level":20,
		"support_restrictions":{"required_tags":["area"],"excluded_tags":[],"behaviors":["nova","melee_cone","ground_area"]},
		"modifier_data":{"aoe_multiplier":1.30,"mana_multiplier":1.12}
	},
	"faster_attacks": {
		"id":"faster_attacks","display_name":"迅捷攻擊輔助","role":"support","color":"green",
		"tags":["support"],"behavior":"support","level":1,"max_level":20,
		"support_restrictions":{"required_tags":["attack"],"excluded_tags":["spell"],"behaviors":["melee_cone"]},
		"modifier_data":{"interval_multiplier":0.80,"mana_multiplier":1.10}
	},
	"chain_support": {
		"id":"chain_support","display_name":"連鎖輔助","role":"support","color":"blue",
		"tags":["support"],"behavior":"support","level":1,"max_level":20,
		"support_restrictions":{"required_tags":["projectile"],"excluded_tags":["melee","duration","nova"],"behaviors":["projectile"]},
		"modifier_data":{"chain_add":2,"chain_damage_multiplier":0.88,"mana_multiplier":1.30}
	},
	"added_cold": {
		"id":"added_cold","display_name":"寒霜附加輔助","role":"support","color":"blue",
		"tags":["support"],"behavior":"support","level":1,"max_level":20,
		"support_restrictions":{"required_tags":["hit"],"excluded_tags":["duration"],"behaviors":[]},
		"modifier_data":{"added_damage_type":"cold","added_damage_ratio":0.24,"slow_multiplier":0.78,"slow_duration":1.2,"mana_multiplier":1.20}
	}
}

static func definition(gem_id: String) -> Dictionary:
	return DEFINITIONS.get(gem_id, {}).duplicate(true)

static func is_active(gem_id: String) -> bool:
	return str(DEFINITIONS.get(gem_id, {}).get("role", "")) == "active"

static func is_support(gem_id: String) -> bool:
	return str(DEFINITIONS.get(gem_id, {}).get("role", "")) == "support"

static func display_name(gem_id: String) -> String:
	return str(DEFINITIONS.get(gem_id, {}).get("display_name", gem_id))

static func icon_path(gem_id: String) -> String:
	return str(DEFINITIONS.get(gem_id, {}).get("icon", "res://assets/ui/skills/empty.svg"))

static func make_instance(gem_id: String, socket_index: int, level: int = 1) -> Dictionary:
	var data := definition(gem_id)
	if data.is_empty():
		return {}
	return {
		"gem_id": gem_id,
		"level": clampi(level, 1, int(data.get("max_level", 20))),
		"socket_index": socket_index,
		"color": str(data.get("color", "")),
		"role": str(data.get("role", ""))
	}

static func default_instances() -> Array:
	# Two real connected groups. Each intentionally contains multiple active gems.
	var ids := [
		"ember_bolt","frost_shard","arc_spark","scatter","pierce","faster_projectiles","chain_support",
		"shock_nova","rift_cleave","cinder_field","increased_area","faster_attacks","added_fire","added_cold"
	]
	var result: Array = []
	for i in range(ids.size()):
		result.append(make_instance(ids[i], i))
	return result

static func default_links() -> Array:
	# Group A = sockets 0..6. Group B = sockets 7..13.
	var links: Array = []
	for i in range(0, 6):
		links.append([i, i + 1])
	for i in range(7, 13):
		links.append([i, i + 1])
	return links

static func connected_component(socket_index: int, instances: Array, links: Array) -> Array:
	if socket_index < 0:
		return []
	var valid: Dictionary = {}
	for instance in instances:
		if instance is Dictionary:
			valid[int(instance.get("socket_index", -1))] = true
	if not valid.has(socket_index):
		return []
	var visited: Array = [socket_index]
	var changed := true
	while changed:
		changed = false
		for edge in links:
			if not (edge is Array) or edge.size() != 2:
				continue
			var a := int(edge[0])
			var b := int(edge[1])
			if not valid.has(a) or not valid.has(b):
				continue
			if a in visited and not (b in visited):
				visited.append(b)
				changed = true
			elif b in visited and not (a in visited):
				visited.append(a)
				changed = true
	return visited

static func active_instance_index(gem_id: String, instances: Array) -> int:
	for i in range(instances.size()):
		var instance = instances[i]
		if instance is Dictionary and str(instance.get("gem_id", "")) == gem_id and is_active(gem_id):
			return i
	return -1

static func installed_active_ids(instances: Array) -> Array:
	var result: Array = []
	for instance in instances:
		if not (instance is Dictionary):
			continue
		var gem_id := str(instance.get("gem_id", ""))
		if is_active(gem_id) and not (gem_id in result):
			result.append(gem_id)
	return result

static func compatible(active_definition: Dictionary, support_definition: Dictionary) -> bool:
	if str(active_definition.get("role", "")) != "active" or str(support_definition.get("role", "")) != "support":
		return false
	var restrictions: Dictionary = support_definition.get("support_restrictions", {})
	var active_tags: Array = active_definition.get("tags", [])
	for tag in restrictions.get("required_tags", []):
		if not (tag in active_tags):
			return false
	for tag in restrictions.get("excluded_tags", []):
		if tag in active_tags:
			return false
	var behaviors: Array = restrictions.get("behaviors", [])
	if not behaviors.is_empty() and not (str(active_definition.get("behavior", "")) in behaviors):
		return false
	return true

static func connected_support_ids(active_gem_id: String, instances: Array, links: Array) -> Array:
	var active_instance := active_instance_index(active_gem_id, instances)
	if active_instance < 0:
		return []
	var socket_index := int(instances[active_instance].get("socket_index", -1))
	var component := connected_component(socket_index, instances, links)
	var active_def := definition(active_gem_id)
	var supports: Array = []
	var seen: Dictionary = {}
	for instance in instances:
		if not (instance is Dictionary):
			continue
		var support_id := str(instance.get("gem_id", ""))
		var support_socket := int(instance.get("socket_index", -1))
		if not (support_socket in component) or not is_support(support_id) or seen.has(support_id):
			continue
		var support_def := definition(support_id)
		if compatible(active_def, support_def):
			seen[support_id] = true
			supports.append(support_id)
	return supports

static func resolve(active_gem_id: String, instances: Array, links: Array) -> Dictionary:
	var base := definition(active_gem_id)
	if base.is_empty() or str(base.get("role", "")) != "active":
		return {}
	var resolved := {
		"id": active_gem_id,
		"display_name": str(base.get("display_name", active_gem_id)),
		"role": "active",
		"color": str(base.get("color", "")),
		"tags": (base.get("tags", []) as Array).duplicate(),
		"behavior": str(base.get("behavior", "")),
		"damage_type": str(base.get("damage_type", "physical")),
		"damage_components": {str(base.get("damage_type", "physical")): float(base.get("base_damage", 0.0))},
		"mana_cost": float(base.get("mana_cost", 0.0)),
		"interval": float(base.get("interval", 0.0)),
		"cast_range": float(base.get("cast_range", 0.0)),
		"projectile_speed": float(base.get("projectile_speed", 0.0)),
		"projectile_count": int(base.get("projectile_count", 0)),
		"pierce": int(base.get("pierce", 0)),
		"chain": int(base.get("chain", 0)),
		"aoe_radius": float(base.get("aoe_radius", 0.0)),
		"duration": float(base.get("duration", 0.0)),
		"status_effects": [],
		"supports": [],
		"more_damage": 1.0,
		"chain_damage_multiplier": float(base.get("modifier_data", {}).get("chain_damage_multiplier", 1.0)),
		"chain_range": float(base.get("modifier_data", {}).get("chain_range", 7.0)),
		"tick_interval": float(base.get("modifier_data", {}).get("tick_interval", 0.5)),
		"weapon_damage_multiplier": float(base.get("modifier_data", {}).get("weapon_damage_multiplier", 0.0))
	}
	if float(base.get("modifier_data", {}).get("slow_duration", 0.0)) > 0.0:
		resolved["status_effects"].append({
			"type":"slow",
			"multiplier":float(base["modifier_data"].get("slow_multiplier", 1.0)),
			"duration":float(base["modifier_data"].get("slow_duration", 0.0))
		})
	for support_id in connected_support_ids(active_gem_id, instances, links):
		var support := definition(support_id)
		var mod: Dictionary = support.get("modifier_data", {})
		resolved["supports"].append(support_id)
		resolved["mana_cost"] = float(resolved["mana_cost"]) * float(mod.get("mana_multiplier", 1.0))
		resolved["projectile_count"] = int(resolved["projectile_count"]) + int(mod.get("projectile_count_add", 0))
		resolved["projectile_speed"] = float(resolved["projectile_speed"]) * float(mod.get("projectile_speed_multiplier", 1.0))
		resolved["pierce"] = int(resolved["pierce"]) + int(mod.get("pierce_add", 0))
		resolved["chain"] = int(resolved["chain"]) + int(mod.get("chain_add", 0))
		resolved["aoe_radius"] = float(resolved["aoe_radius"]) * float(mod.get("aoe_multiplier", 1.0))
		resolved["interval"] = float(resolved["interval"]) * float(mod.get("interval_multiplier", 1.0))
		resolved["more_damage"] = float(resolved["more_damage"]) * float(mod.get("more_damage", 1.0))
		resolved["chain_damage_multiplier"] = float(resolved["chain_damage_multiplier"]) * float(mod.get("chain_damage_multiplier", 1.0))
		var added_type := str(mod.get("added_damage_type", ""))
		if not added_type.is_empty():
			var source_amount := 0.0
			for amount in (resolved["damage_components"] as Dictionary).values():
				source_amount += float(amount)
			var components: Dictionary = resolved["damage_components"]
			components[added_type] = float(components.get(added_type, 0.0)) + source_amount * float(mod.get("added_damage_ratio", 0.0))
		if float(mod.get("slow_duration", 0.0)) > 0.0:
			resolved["status_effects"].append({
				"type":"slow",
				"multiplier":float(mod.get("slow_multiplier", 1.0)),
				"duration":float(mod.get("slow_duration", 0.0))
			})
	resolved["mana_cost"] = ceil(float(resolved["mana_cost"]))
	return resolved

static func tooltip(resolved: Dictionary) -> String:
	if resolved.is_empty():
		return ""
	var components: Array[String] = []
	for damage_type in (resolved.get("damage_components", {}) as Dictionary):
		components.append("%s %.0f" % [str(damage_type).capitalize(), float(resolved["damage_components"][damage_type]) * float(resolved.get("more_damage", 1.0))])
	var lines := [
		"%s Lv.1" % str(resolved.get("display_name", "")),
		"Damage: %s" % ", ".join(components),
		"Mana: %d" % int(resolved.get("mana_cost", 0)),
		"Interval: %.2f s" % float(resolved.get("interval", 0.0))
	]
	if int(resolved.get("projectile_count", 0)) > 0:
		lines.append("Projectiles: %d" % int(resolved["projectile_count"]))
		lines.append("Projectile Speed: %.1f" % float(resolved["projectile_speed"]))
		lines.append("Range: %.1f" % float(resolved["cast_range"]))
		lines.append("Pierce: %d  Chain: %d" % [int(resolved["pierce"]), int(resolved["chain"])])
	if float(resolved.get("aoe_radius", 0.0)) > 0.0:
		lines.append("AoE Radius: %.2f" % float(resolved["aoe_radius"]))
	if float(resolved.get("duration", 0.0)) > 0.0:
		lines.append("Duration: %.1f s" % float(resolved["duration"]))
	var supports: Array = resolved.get("supports", [])
	if not supports.is_empty():
		var names: Array[String] = []
		for support_id in supports:
			names.append(display_name(str(support_id)))
		lines.append("Supports: " + ", ".join(names))
	return "\n".join(lines)
