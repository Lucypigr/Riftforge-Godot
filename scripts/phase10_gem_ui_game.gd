extends "res://scripts/phase7_game.gd"
## Phase 10 UI build: equipment owns sockets/gems. The old global socket_gems
## array remains only as a compatibility bridge for untouched legacy saves/tests.
const Grid10 = preload("res://scripts/grid_inventory.gd")
const GemRules10 = preload("res://scripts/gem_rules.gd")
const Phase10HUD = preload("res://scripts/phase10_gem_ui_hud.gd")
const Phase10Projectile = preload("res://scripts/phase2_projectile.gd")

var gem_equipment_mode := false
var last_gem_error := ""
var _phase10_ui_ready := false

func _load_progress() -> void:
	super._load_progress()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		gem_equipment_mode = bool(data.get("gem_equipment_mode", false))
	_normalize_equipment_socket_state(false)

func _ready() -> void:
	super._ready()
	_normalize_equipment_socket_state(true)
	_sync_installed_from_equipment()
	var previous_hud = hud
	remove_child(previous_hud)
	previous_hud.queue_free()
	hud = Phase10HUD.new()
	hud.initialize(self)
	add_child(hud)
	_phase10_ui_ready = true
	hud.announce("裝備、插槽與背包已整合；F 世界互動，I / G 開啟裝備寶石介面")
	save_progress()

func save_progress() -> void:
	super.save_progress()
	var data: Dictionary = {}
	if FileAccess.file_exists(SAVE_PATH):
		var read_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if read_file != null:
			var parsed = JSON.parse_string(read_file.get_as_text())
			if parsed is Dictionary:
				data = parsed
	data["version"] = maxi(10, int(data.get("version", 1)))
	data["gem_equipment_mode"] = gem_equipment_mode
	data["equipment"] = equipment
	data["inventory"] = inventory
	data["installed_active_gems"] = installed_active_gems
	data["skill_slots"] = skill_slots
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))

func equip_item(index: int) -> void:
	super.equip_item(index)
	# If a real weapon/armor is now equipped, attach the socket schema and migrate
	# the old prototype gem group atomically into that gear on first use.
	_normalize_equipment_socket_state(true)
	_sync_installed_from_equipment()
	save_progress()
	if is_instance_valid(hud) and hud.has_method("_refresh_inventory"):
		hud._refresh_inventory()

func _normalize_equipment_socket_state(allow_migration: bool) -> void:
	var has_real_equipment := false
	var had_socket_payload := false
	for slot in ["weapon", "armor"]:
		if not equipment.has(slot) or not (equipment[slot] is Dictionary):
			equipment[slot] = {"slot": slot}
		var item: Dictionary = equipment[slot].duplicate(true)
		if str(item.get("name", "")).is_empty():
			equipment[slot] = item
			continue
		has_real_equipment = true
		had_socket_payload = had_socket_payload or item.has("installed_gems") or item.has("socket_colors")
		equipment[slot] = _ensure_socket_schema(item, slot)
	if has_real_equipment and (gem_equipment_mode or had_socket_payload):
		gem_equipment_mode = true
	if allow_migration and has_real_equipment and not gem_equipment_mode:
		gem_equipment_mode = true
		_migrate_legacy_gems_to_equipment()

func _ensure_socket_schema(item: Dictionary, slot: String) -> Dictionary:
	var result := item.duplicate(true)
	var default_colors: Array = ["red", "green", "blue", "blue"] if slot == "weapon" else ["blue", "red", "green", "blue"]
	var default_links: Array = [[0, 1], [1, 2]] if slot == "weapon" else [[0, 1], [2, 3]]
	var count := clampi(int(result.get("socket_count", default_colors.size())), 1, 6)
	var raw_colors: Array = result.get("socket_colors", default_colors)
	var colors: Array = []
	for i in range(count):
		colors.append(str(raw_colors[i]) if i < raw_colors.size() else str(default_colors[i % default_colors.size()]))
	var raw_gems: Array = result.get("installed_gems", [])
	var installed: Array = []
	for i in range(count):
		installed.append(str(raw_gems[i]) if i < raw_gems.size() else "")
	var links: Array = []
	var raw_links: Array = result.get("socket_links", default_links)
	for raw_link in raw_links:
		if not (raw_link is Array) or raw_link.size() != 2:
			continue
		var a := int(raw_link[0])
		var b := int(raw_link[1])
		if a >= 0 and b >= 0 and a < count and b < count and a != b:
			links.append([a, b])
	result["socket_count"] = count
	result["socket_colors"] = colors
	result["socket_links"] = links
	result["installed_gems"] = installed
	return result

func _migrate_legacy_gems_to_equipment() -> void:
	var candidates: Array = []
	for gem_id in socket_gems:
		var id := str(gem_id)
		if GemRules10.is_gem(id) and not (id in candidates):
			candidates.append(id)
	for gem_id in installed_active_gems:
		var id := str(gem_id)
		if GemRules10.is_gem(id) and not (id in candidates):
			candidates.append(id)
	for gem_id in candidates:
		_place_migrated_gem(str(gem_id))

func _place_migrated_gem(gem_id: String) -> bool:
	for slot in ["weapon", "armor"]:
		var item: Dictionary = equipment.get(slot, {})
		if str(item.get("name", "")).is_empty():
			continue
		var colors: Array = item.get("socket_colors", [])
		var installed: Array = item.get("installed_gems", [])
		for i in range(installed.size()):
			if str(installed[i]).is_empty() and i < colors.size() and GemRules10.color_compatible(gem_id, str(colors[i])):
				installed[i] = gem_id
				item["installed_gems"] = installed
				equipment[slot] = item
				return true
	return false

func _socket_schema_active() -> bool:
	return gem_equipment_mode

func installed_skill_gems() -> Array:
	if not _socket_schema_active():
		return super.installed_skill_gems()
	var result: Array = []
	for slot in ["weapon", "armor"]:
		var item: Dictionary = equipment.get(slot, {})
		for gem_id in item.get("installed_gems", []):
			var id := str(gem_id)
			if GemRules10.is_active(id) and not (id in result):
				result.append(id)
	return result

func _sync_installed_from_equipment() -> void:
	if not _socket_schema_active():
		return
	installed_active_gems = installed_skill_gems()
	_sanitize_skill_slots()
	_sync_legacy_socket_cache()

func _sync_legacy_socket_cache() -> void:
	if not _socket_schema_active():
		return
	for slot in ["weapon", "armor"]:
		var item: Dictionary = equipment.get(slot, {})
		var installed: Array = item.get("installed_gems", [])
		if "ember_bolt" in installed:
			socket_gems = installed.duplicate()
			return
	socket_gems = ["", "", ""]

func equipment_socket_item(slot: String) -> Dictionary:
	if not equipment.has(slot) or not (equipment[slot] is Dictionary):
		return {}
	return equipment[slot]

func socket_gem(slot: String, socket_index: int) -> String:
	var item := equipment_socket_item(slot)
	var installed: Array = item.get("installed_gems", [])
	if socket_index < 0 or socket_index >= installed.size():
		return ""
	return str(installed[socket_index])

func _gem_item(gem_id: String) -> Dictionary:
	return {
		"name": GemRules10.display_name(gem_id),
		"slot": "gem",
		"item_type": "gem",
		"gem_id": gem_id,
		"rarity": "寶石",
		"damage": 0,
		"hp": 0,
		"armor": 0.0,
		"level": int(GemRules10.definition(gem_id).get("level", 1)),
		"grid_w": 1,
		"grid_h": 1
	}

func insert_inventory_gem(inventory_index: int, equipment_slot: String, socket_index: int) -> bool:
	last_gem_error = ""
	if inventory_index < 0 or inventory_index >= inventory.size():
		return _gem_fail("寶石不存在")
	var bag_item: Dictionary = inventory[inventory_index]
	var gem_id := str(bag_item.get("gem_id", ""))
	if str(bag_item.get("slot", "")) != "gem" or not GemRules10.is_gem(gem_id):
		return _gem_fail("無法插入：選取物品不是可用寶石")
	var target: Dictionary = equipment_socket_item(equipment_slot).duplicate(true)
	if str(target.get("name", "")).is_empty():
		return _gem_fail("無法插入：裝備欄位是空的")
	target = _ensure_socket_schema(target, equipment_slot)
	var installed: Array = target.get("installed_gems", [])
	var colors: Array = target.get("socket_colors", [])
	if socket_index < 0 or socket_index >= installed.size():
		return _gem_fail("無法插入：插槽不存在")
	if not str(installed[socket_index]).is_empty():
		return _gem_fail("無法插入：目標插槽已有寶石")
	if socket_index >= colors.size() or not GemRules10.color_compatible(gem_id, str(colors[socket_index])):
		return _gem_fail("不相容：寶石顏色與插槽不符")
	installed[socket_index] = gem_id
	target["installed_gems"] = installed
	equipment[equipment_slot] = target
	inventory.remove_at(inventory_index)
	gem_equipment_mode = true
	_sync_installed_from_equipment()
	save_progress()
	return true

func move_socket_gem(source_slot: String, source_socket: int, target_slot: String, target_socket: int) -> bool:
	last_gem_error = ""
	var source: Dictionary = equipment_socket_item(source_slot).duplicate(true)
	var target: Dictionary = equipment_socket_item(target_slot).duplicate(true)
	if str(source.get("name", "")).is_empty() or str(target.get("name", "")).is_empty():
		return _gem_fail("無法移動：來源或目標裝備不存在")
	source = _ensure_socket_schema(source, source_slot)
	target = _ensure_socket_schema(target, target_slot)
	var source_gems: Array = source.get("installed_gems", [])
	var target_gems: Array = target.get("installed_gems", [])
	var source_colors: Array = source.get("socket_colors", [])
	var target_colors: Array = target.get("socket_colors", [])
	if source_socket < 0 or source_socket >= source_gems.size() or target_socket < 0 or target_socket >= target_gems.size():
		return _gem_fail("無法移動：插槽不存在")
	var moving := str(source_gems[source_socket])
	if moving.is_empty():
		return _gem_fail("來源插槽沒有寶石")
	var displaced := str(target_gems[target_socket])
	if not GemRules10.color_compatible(moving, str(target_colors[target_socket])):
		return _gem_fail("不相容：寶石顏色與目標插槽不符")
	if not displaced.is_empty() and not GemRules10.color_compatible(displaced, str(source_colors[source_socket])):
		return _gem_fail("無法交換：目標寶石不符合來源插槽顏色")
	if source_slot == target_slot:
		var same_item := source
		var same_gems: Array = same_item.get("installed_gems", [])
		same_gems[source_socket] = displaced
		same_gems[target_socket] = moving
		same_item["installed_gems"] = same_gems
		equipment[source_slot] = same_item
	else:
		source_gems[source_socket] = displaced
		target_gems[target_socket] = moving
		source["installed_gems"] = source_gems
		target["installed_gems"] = target_gems
		equipment[source_slot] = source
		equipment[target_slot] = target
	gem_equipment_mode = true
	_sync_installed_from_equipment()
	save_progress()
	return true

func move_socket_gem_to_inventory(source_slot: String, source_socket: int, target_x: int = -1, target_y: int = -1) -> bool:
	last_gem_error = ""
	var source: Dictionary = equipment_socket_item(source_slot).duplicate(true)
	if str(source.get("name", "")).is_empty():
		return _gem_fail("裝備不存在")
	source = _ensure_socket_schema(source, source_slot)
	var installed: Array = source.get("installed_gems", [])
	if source_socket < 0 or source_socket >= installed.size():
		return _gem_fail("插槽不存在")
	var gem_id := str(installed[source_socket])
	if gem_id.is_empty():
		return _gem_fail("插槽內沒有寶石")
	var bag_item := _gem_item(gem_id)
	if target_x >= 0 and target_y >= 0:
		if not Grid10.can_place(inventory, bag_item, target_x, target_y):
			return _gem_fail("背包已滿或目標格被占用，寶石仍保留在裝備上")
		bag_item["grid_x"] = target_x
		bag_item["grid_y"] = target_y
		inventory.append(bag_item)
	else:
		if not Grid10.try_add(inventory, bag_item):
			return _gem_fail("背包已滿，寶石仍保留在裝備上")
	installed[source_socket] = ""
	source["installed_gems"] = installed
	equipment[source_slot] = source
	gem_equipment_mode = true
	_sync_installed_from_equipment()
	save_progress()
	return true

func move_inventory_gem(inventory_index: int, x: int, y: int) -> bool:
	last_gem_error = ""
	if inventory_index < 0 or inventory_index >= inventory.size():
		return _gem_fail("寶石不存在")
	if str(inventory[inventory_index].get("slot", "")) != "gem":
		return _gem_fail("只能用寶石拖曳模式移動寶石")
	if not Grid10.move(inventory, inventory_index, x, y):
		return _gem_fail("背包目標格無法放置")
	save_progress()
	return true

func linked_supports_for(active_id: String) -> Array:
	if _socket_schema_active():
		return GemRules10.active_supports(equipment, active_id)
	return (GemRules10.modifiers(socket_gems).get("supports", []) as Array).duplicate()

func gem_tooltip(gem_id: String) -> String:
	if not GemRules10.is_gem(gem_id):
		return "寶石資訊不可用"
	var lines := [GemRules10.gem_detail(gem_id)]
	if GemRules10.is_active(gem_id):
		var supports: Array = GemRules10.active_supports(equipment, gem_id) if _socket_schema_active() else []
		if gem_id == "ember_bolt":
			var mods: Dictionary = GemRules10.modifiers_for_equipment(equipment, gem_id) if _socket_schema_active() else GemRules10.modifiers(socket_gems)
			lines.append("傷害：%.1f" % (16.0 * float(mods.get("damage_multiplier", 1.0))))
			lines.append("魔力：3")
			lines.append("攻擊間隔：%.3f 秒" % (_bolt_skill.cooldown if _bolt_skill != null else 0.205))
			lines.append("投射物：%d｜穿透：%d" % [int(mods.get("projectile_count", 1)), int(mods.get("pierce_count", 0))])
		elif gem_id == "shock_nova":
			lines.append("傷害：34｜魔力：25｜冷卻：3.6 秒")
		lines.append("目前支援：" + ("無" if supports.is_empty() else ", ".join(PackedStringArray(supports.map(func(id): return GemRules10.display_name(str(id)))))))
	return "\n".join(lines)

func skill_tooltip(gem_id: String) -> String:
	return gem_tooltip(gem_id) if not gem_id.is_empty() else "空技能槽"

func _gem_fail(message: String) -> bool:
	last_gem_error = message
	if _phase10_ui_ready and is_instance_valid(hud):
		hud.announce(message)
	return false

func _cast_ember_bolt_skill() -> bool:
	if _skill_runtime == null or not is_instance_valid(player):
		return false
	if _socket_schema_active():
		if not ("ember_bolt" in installed_skill_gems()):
			_skill_blocked("missing_gem", "燼焰彈", 3)
			return false
	elif socket_gems.is_empty() or str(socket_gems[0]) != "ember_bolt":
		_skill_blocked("missing_gem", "燼焰彈", 3)
		return false
	_skill_runtime.mana = player.mana
	var result: Dictionary = _skill_runtime.cast(_bolt_skill, player.global_position, aim_direction, [])
	if not bool(result.get("ok", false)):
		_skill_blocked(str(result.get("reason", "")), "燼焰彈", 3)
		return false
	player.mana = _skill_runtime.mana
	var gem_mods: Dictionary = GemRules10.modifiers_for_equipment(equipment, "ember_bolt") if _socket_schema_active() else GemRules10.modifiers(socket_gems)
	var count: int = maxi(1, int(gem_mods.get("projectile_count", 1)))
	var on_hit_mods: Dictionary = {
		"flat_damage": float(equipment["weapon"].get("damage", 0.0)),
		"more_multiplier": float(gem_mods.get("damage_multiplier", 1.0)),
		"offensive_ability": _offensive_ability()
	}
	var spawn: Dictionary = result["shots"][0]
	for shot in range(count):
		var angle: float = deg_to_rad((float(shot) - (float(count) - 1.0) * 0.5) * 12.0)
		var direction: Vector3 = (spawn["direction"] as Vector3).rotated(Vector3.UP, angle)
		var projectile = Phase10Projectile.new()
		projectile.initialize(self, direction, 0, false, int(gem_mods.get("pierce_count", 0)))
		projectile.configure(_skill_runtime, _bolt_skill, on_hit_mods)
		projectile.max_distance = float(spawn["max_distance"])
		projectile.position = player.global_position + direction * 0.83 + Vector3(0, 0.1, 0)
		projectile.add_to_group("projectiles")
		add_child(projectile)
	spawn_burst(player.global_position + aim_direction * 0.8, Color("#f7a756"), 0.43)
	_sync_cooldowns()
	return true
