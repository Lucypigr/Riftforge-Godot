extends SceneTree
const Grid = preload("res://scripts/grid_inventory.gd")
const GemRules = preload("res://scripts/gem_rules.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS " + message)
	else:
		failed += 1
		push_error("FAIL " + message)

func gear(slot: String, label: String, colors: Array, links: Array) -> Dictionary:
	return {
		"name": label, "slot": slot, "rarity": "普通",
		"damage": 4 if slot == "weapon" else 0,
		"hp": 0, "armor": 0.1 if slot == "armor" else 0.0, "level": 1,
		"socket_count": colors.size(), "socket_colors": colors.duplicate(),
		"socket_links": links.duplicate(true), "installed_gems": ["", "", ""]
	}

func find_gem(items: Array, gem_id: String) -> int:
	for i in range(items.size()):
		if str(items[i].get("gem_id", "")) == gem_id:
			return i
	return -1

func bag_point(item: Dictionary) -> Vector2:
	return Vector2(float(item.get("grid_x", 0)) * 42.0 + 21.0, float(item.get("grid_y", 0)) * 42.0 + 21.0)

func tap(control, finger: int, pos: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = pos
	event.pressed = true
	control._gui_input(event)

func all_ui_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	elif node is Button:
		out += (node as Button).text + "\n"
	elif node is RichTextLabel:
		out += (node as RichTextLabel).text + "\n"
	for child in node.get_children():
		out += all_ui_text(child)
	return out

func _run() -> void:
	var save_path := "user://riftforge_phase8_save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var hud = game.hud
	var controls = game.get_node("MobileControls")

	check(game.get_script().resource_path.ends_with("phase10_gem_ui_game.gd"), "playable scene uses Phase 10 gem UI game layer")
	check(hud.get_script().resource_path.ends_with("phase10_gem_ui_hud.gd"), "playable scene uses integrated Phase 10 HUD")
	check(ResourceLoader.exists("res://fonts/NotoSansTC.ttf"), "Traditional Chinese Noto Sans resource exists in tested build")
	check(hud._root.theme != null and hud._root.theme.default_font != null, "integrated HUD owns one explicit shared font theme")
	var shared_font: Font = hud._root.theme.default_font
	var required_glyphs := "背包角色裝備武器護甲寶石支援主動插槽已連線未連線裝上移除無法插入不相容技能資訊等級傷害魔力冷卻攻擊間隔"
	var glyphs_ok := true
	for i in range(required_glyphs.length()):
		if not shared_font.has_char(required_glyphs.unicode_at(i)):
			glyphs_ok = false
			break
	check(glyphs_ok, "shared HUD font contains required Traditional Chinese glyphs")
	var ui_text := all_ui_text(hud._inventory_panel)
	check(ui_text.contains("角色裝備") and ui_text.contains("背包") and ui_text.contains("技能資訊") and ui_text.contains("裝上") and ui_text.contains("移除") and not ui_text.contains("�"), "main equipment/gem labels are valid Traditional Chinese without replacement glyphs")
	var support_detail := GemRules.gem_detail("scatter")
	check(support_detail.contains("支援效果") and support_detail.contains("相容標籤") and support_detail.contains("魔力倍率") and not support_detail.contains("Mana Multiplier"), "support detail is fully readable Traditional Chinese")
	check(hud._equipment_socket_view.get_parent() == hud._bag_page and hud._grid_view.get_parent() == hud._bag_page and hud._equipment_socket_view.get_index() < hud._grid_view.get_index(), "equipment socket strip is physically above the backpack in one surface")
	check(hud._grid_view.custom_minimum_size == Vector2(756, 420) and Grid.COLS == 18 and Grid.ROWS == 10, "Phase 8 18 by 10 backpack geometry is unchanged")

	game.inventory.clear()
	game.equipment = {
		"weapon": gear("weapon", "三孔測試劍", ["red","green","blue"], [[0,1]]),
		"armor": gear("armor", "三孔測試甲", ["blue","red","green"], [[0,1]])
	}
	game.gem_equipment_mode = true
	game._normalize_equipment_socket_state(false)
	game._sync_installed_from_equipment()
	for id in ["ember_bolt","scatter","pierce","shock_nova"]:
		check(Grid.try_add(game.inventory, game._gem_item(id)), "test gem enters real 18x10 bag: " + id)
	hud._refresh_inventory()
	check(int(game.equipment["weapon"]["socket_count"]) == 3 and int(game.equipment["armor"]["socket_count"]) == 3, "weapon and armor expose real socket data")
	check(game.equipment["weapon"]["socket_links"] == [[0,1]], "weapon link graph is preserved and visible to UI model")
	check(hud._socket_link_state(game.equipment["weapon"], 0) == "已連線" and hud._socket_link_state(game.equipment["weapon"], 2) == "未連線", "socket detail reports linked and unlinked states explicitly")

	# Backpack gem -> occupied backpack gem must reject without duplication or loss.
	var ember_index := find_gem(game.inventory, "ember_bolt")
	var overlap_target_index := find_gem(game.inventory, "scatter")
	var ember_x_before := int(game.inventory[ember_index]["grid_x"])
	var ember_y_before := int(game.inventory[ember_index]["grid_y"])
	var bag_count_before_overlap: int = game.inventory.size()
	check(not game.move_inventory_gem(ember_index, int(game.inventory[overlap_target_index]["grid_x"]), int(game.inventory[overlap_target_index]["grid_y"])), "backpack gem cannot be dropped onto occupied backpack gem")
	check(game.inventory.size() == bag_count_before_overlap and int(game.inventory[ember_index]["grid_x"]) == ember_x_before and int(game.inventory[ember_index]["grid_y"]) == ember_y_before, "failed backpack gem move never duplicates or loses the gem")

	# PC native drag: backpack active -> weapon socket.
	var drag = hud._grid_view._get_drag_data(bag_point(game.inventory[ember_index]))
	check(drag is Dictionary and drag.get("kind") == "inventory_gem", "PC grid exposes native drag data for a gem")
	hud._equipment_socket_view._drop_data(hud._equipment_socket_view.socket_center("weapon", 0), drag)
	check(game.socket_gem("weapon", 0) == "ember_bolt" and find_gem(game.inventory, "ember_bolt") < 0, "PC drag inserts active gem into equipment socket")
	check("ember_bolt" in game.installed_skill_gems(), "socketed active gem becomes installed")
	check(game.assign_skill_slot(0, "ember_bolt"), "installed active gem can enter hotbar")

	# Linked support changes real resolved legacy gameplay modifier.
	var scatter_index := find_gem(game.inventory, "scatter")
	var scatter_drag = hud._grid_view._get_drag_data(bag_point(game.inventory[scatter_index]))
	hud._equipment_socket_view._drop_data(hud._equipment_socket_view.socket_center("weapon", 1), scatter_drag)
	var linked_mods := GemRules.modifiers_for_equipment(game.equipment, "ember_bolt")
	check(int(linked_mods["projectile_count"]) == 3 and float(linked_mods["damage_multiplier"]) < 1.0, "linked compatible support changes resolved Ember Bolt modifiers")
	check(not game.assign_skill_slot(2, "scatter"), "support gem can never enter hotbar")

	# Duplicate same-ID support applies once; incompatible linked support applies zero times.
	var duplicate_weapon := gear("weapon", "重複輔助測試", ["red","green","green"], [[0,1],[1,2]])
	duplicate_weapon["installed_gems"] = ["ember_bolt","scatter","scatter"]
	var duplicate_equipment := {"weapon": duplicate_weapon, "armor": {}}
	var duplicate_mods := GemRules.modifiers_for_equipment(duplicate_equipment, "ember_bolt")
	check((duplicate_mods["supports"] as Array).count("scatter") == 1 and int(duplicate_mods["projectile_count"]) == 3, "duplicate same-ID support is deduplicated within one connected group")
	var incompatible_weapon := gear("weapon", "不相容輔助測試", ["blue","green","blue"], [[0,1]])
	incompatible_weapon["installed_gems"] = ["shock_nova","scatter",""]
	var incompatible_equipment := {"weapon": incompatible_weapon, "armor": {}}
	var incompatible_mods := GemRules.modifiers_for_equipment(incompatible_equipment, "shock_nova")
	check((incompatible_mods["supports"] as Array).is_empty(), "linked but incompatible support has no effect")

	# Unlinked support has no effect, then link graph activation makes it effective.
	var pierce_index := find_gem(game.inventory, "pierce")
	var pierce_drag = hud._grid_view._get_drag_data(bag_point(game.inventory[pierce_index]))
	hud._equipment_socket_view._drop_data(hud._equipment_socket_view.socket_center("weapon", 2), pierce_drag)
	check(int(GemRules.modifiers_for_equipment(game.equipment, "ember_bolt")["pierce_count"]) == 0, "unlinked support has no gameplay effect")
	var weapon: Dictionary = game.equipment["weapon"].duplicate(true)
	weapon["socket_links"] = [[0,1],[1,2]]
	game.equipment["weapon"] = weapon
	game._sync_installed_from_equipment()
	check(int(GemRules.modifiers_for_equipment(game.equipment, "ember_bolt")["pierce_count"]) == 1, "adding a real socket link activates the compatible support")

	# Incompatible socket color is refused without deleting the backpack gem.
	var shock_index := find_gem(game.inventory, "shock_nova")
	var shock_count_before: int = game.inventory.size()
	check(not game.insert_inventory_gem(shock_index, "armor", 1), "blue active gem is rejected by red socket")
	check(game.inventory.size() == shock_count_before and find_gem(game.inventory, "shock_nova") >= 0 and game.last_gem_error.contains("不相容"), "failed insert returns gem to original backpack state")

	# PC socket -> socket and socket -> bag.
	var socket_drag = hud._equipment_socket_view._get_drag_data(hud._equipment_socket_view.socket_center("weapon", 2))
	check(socket_drag is Dictionary and socket_drag.get("kind") == "socket_gem", "PC equipment view exposes native socket gem drag data")
	hud._equipment_socket_view._drop_data(hud._equipment_socket_view.socket_center("armor", 0), socket_drag)
	check(game.socket_gem("armor", 0) == "pierce" and game.socket_gem("weapon", 2).is_empty(), "PC drag moves a gem between equipment sockets")
	var back_drag = hud._equipment_socket_view._get_drag_data(hud._equipment_socket_view.socket_center("armor", 0))
	hud._grid_view._drop_data(Vector2(10.0 * 42.0 + 21.0, 0.0 * 42.0 + 21.0), back_drag)
	check(game.socket_gem("armor", 0).is_empty() and find_gem(game.inventory, "pierce") >= 0, "PC drag removes socket gem back into real backpack")

	# Mobile tap-select + target-tap uses the same model rules.
	var mobile_pierce := find_gem(game.inventory, "pierce")
	tap(hud._grid_view, 40, bag_point(game.inventory[mobile_pierce]))
	tap(hud._equipment_socket_view, 41, hud._equipment_socket_view.socket_center("weapon", 2))
	check(game.socket_gem("weapon", 2) == "pierce", "mobile point-to-point interaction inserts backpack gem into socket")
	tap(hud._equipment_socket_view, 42, hud._equipment_socket_view.socket_center("weapon", 2))
	tap(hud._grid_view, 43, Vector2(12.0 * 42.0 + 21.0, 42.0 + 21.0))
	check(game.socket_gem("weapon", 2).is_empty() and find_gem(game.inventory, "pierce") >= 0, "mobile point-to-point interaction removes socket gem to chosen backpack cell")

	# Removing active invalidates its hotbar assignment.
	check(game.skill_gem(0) == "ember_bolt", "active remains assigned while socketed")
	var active_drag = hud._equipment_socket_view._get_drag_data(hud._equipment_socket_view.socket_center("weapon", 0))
	hud._grid_view._drop_data(Vector2(14.0 * 42.0 + 21.0, 42.0 + 21.0), active_drag)
	check(not ("ember_bolt" in game.installed_skill_gems()) and game.skill_gem(0).is_empty(), "removing active gem clears ghost hotbar assignment")

	# Full bag cannot consume a socketed gem.
	game.inventory.clear()
	for i in range(180):
		var filler := {"name":"滿格%d" % i,"slot":"currency","rarity":"普通","damage":0,"hp":0,"armor":0.0,"level":1}
		Grid.try_add(game.inventory, filler)
	var weapon_full: Dictionary = game.equipment["weapon"].duplicate(true)
	weapon_full["installed_gems"] = ["", "scatter", ""]
	game.equipment["weapon"] = weapon_full
	game._sync_installed_from_equipment()
	check(not game.move_socket_gem_to_inventory("weapon", 1), "full backpack refuses socket gem removal")
	check(game.socket_gem("weapon", 1) == "scatter" and game.inventory.size() == 180, "full bag rejection never loses or duplicates gem")

	# UI blocks combat/world touch path and closing restores it.
	controls.enabled = true
	controls.surface.visible = true
	controls.surface.size = Vector2(1280,720)
	game.mobile_active = true
	game.player.position = game._portal_position + Vector3(0,0.9,0)
	hud.toggle_inventory()
	check(game.ui_open and not game.can_world_interact(), "integrated UI blocks world interaction availability")
	var projectile_before := _friendly_count(game)
	var attack := InputEventScreenTouch.new()
	attack.index = 70
	attack.position = controls._center("attack")
	attack.pressed = true
	controls._input(attack)
	controls._process(0.016)
	check(_friendly_count(game) == projectile_before and game.mobile_move.is_zero_approx(), "open integrated UI blocks combat touch")
	hud.close_panels()
	check(not game.ui_open and game.can_world_interact(), "closing integrated UI restores world interaction")

	# Save/load equipment sockets, bag gem positions, links and hotbar reconstruction.
	game.inventory.clear()
	game.equipment = {
		"weapon": gear("weapon", "存檔武器", ["red","green","blue"], [[0,1],[1,2]]),
		"armor": gear("armor", "存檔護甲", ["blue","red","green"], [[0,1]])
	}
	game.equipment["weapon"]["installed_gems"] = ["ember_bolt","scatter","pierce"]
	game.gem_equipment_mode = true
	game._sync_installed_from_equipment()
	game.assign_skill_slot(0, "ember_bolt")
	Grid.try_add(game.inventory, game._gem_item("shock_nova"))
	var saved_x := int(game.inventory[0]["grid_x"])
	var saved_y := int(game.inventory[0]["grid_y"])
	game.save_progress()
	game.queue_free()
	await process_frame

	var loaded = load("res://scenes/main.tscn").instantiate()
	root.add_child(loaded)
	await process_frame
	check(loaded.gem_equipment_mode and loaded.socket_gem("weapon", 0) == "ember_bolt" and loaded.socket_gem("weapon", 1) == "scatter", "equipment installed gems survive reload")
	check(loaded.equipment["weapon"]["socket_links"] == [[0,1],[1,2]], "socket links survive reload with integer indices")
	check(find_gem(loaded.inventory, "shock_nova") >= 0 and int(loaded.inventory[0]["grid_x"]) == saved_x and int(loaded.inventory[0]["grid_y"]) == saved_y, "backpack gem placement survives reload")
	check(loaded.skill_gem(0) == "ember_bolt" and "ember_bolt" in loaded.installed_skill_gems(), "hotbar rebuild points only to still-installed active gem")
	var tooltip: String = str(loaded.skill_tooltip("ember_bolt"))
	check(tooltip.contains("分裂輔助") and tooltip.contains("穿透輔助") and not tooltip.contains("�"), "reloaded skill tooltip rebuilds linked support effects with readable text")
	var reloaded_text := all_ui_text(loaded.hud._inventory_panel)
	check(not reloaded_text.contains("�"), "reloaded integrated UI remains free of replacement glyphs")

	print("PHASE10 GEM UI: %d passed / %d failed" % [passed, failed])
	loaded.queue_free()
	await process_frame
	await process_frame
	quit(0 if failed == 0 else 1)

func _friendly_count(game) -> int:
	var total := 0
	for node in game.get_children():
		if node.is_in_group("projectiles") and not node.enemy_owned and not node.is_queued_for_deletion():
			total += 1
	return total
