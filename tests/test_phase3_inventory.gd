extends SceneTree
const Grid = preload("res://scripts/grid_inventory.gd")
const Loot = preload("res://scripts/loot.gd")
var passed := 0
var failed := 0

func expect(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS " + description)
	else:
		failed += 1
		push_error("FAIL " + description)

func sample(slot: String = "weapon", label: String = "測試物品") -> Dictionary:
	return {"name": label, "slot": slot, "rarity": "普通", "damage": 4, "hp": 0, "armor": 0.0, "level": 1}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Phase 8 uses its own save namespace so a first launch is actually empty.
	if FileAccess.file_exists("user://riftforge_phase8_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://riftforge_phase8_save.json"))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	expect(_script_chain_contains(game.get_script(), "phase3_game.gd") and game.hud._grid_view != null, "real playable scene retains grid inventory")
	expect(_script_chain_contains(game.hud.get_script(), "grid_hud.gd") and game.hud._bag_page != null and game.hud._equipment_page != null, "inventory and equipment tabs remain live")
	expect(Grid.COLS == 18 and Grid.ROWS == 10 and Grid.PAGE_COUNT == 1, "Phase 8 backpack is one dense 18 by 10 grid")
	expect(Grid.COLS * Grid.ROWS == 180, "physical storage expands from 120 to 180 cells")
	expect(game.inventory.is_empty(), "fresh Phase 8 character starts with an empty backpack")
	expect(str(game.equipment["weapon"].get("name", "")).is_empty() and str(game.equipment["armor"].get("name", "")).is_empty(), "fresh character starts with no weapon or armor")

	var items: Array = []
	expect(Grid.footprint(sample()) == Vector2i(2, 3), "weapon still occupies multiple cells")
	expect(Grid.try_add(items, sample("weapon", "A")), "first weapon fits")
	expect(Grid.try_add(items, sample("armor", "B")), "second large item fits")
	expect(Grid.item_at(items, 0, 2) == 0 and Grid.item_at(items, 2, 1) == 1, "occupied cells identify real items")
	expect(not Grid.move(items, 0, 2, 0), "item overlap is rejected")
	expect(not Grid.move(items, 0, 17, 8), "out of bounds placement is rejected")
	expect(Grid.move(items, 0, 16, 7), "large equipment can move to the far edge of the expanded bag")

	var full: Array = []
	for i in range(180):
		Grid.try_add(full, sample("gem", "格子"))
	expect(full.size() == 180 and Grid.occupied_cells(full) == 180 and Grid.overflow_count(full) == 0, "exact 18 by 10 physical capacity is 180")
	expect(not Grid.try_add(full, sample()) and full.size() == 180, "true full bag refuses further loot without mutation")

	game.inventory = full
	var drop = Loot.new()
	drop.initialize(sample("weapon", "地面武器"))
	drop.position = game.player.position + Vector3(0.2, -0.5, 0)
	game.add_child(drop)
	game._interact()
	expect(game.inventory.size() == 180 and not drop.is_queued_for_deletion(), "180-cell full bag leaves ground loot intact")
	game.inventory.clear()
	game._interact()
	expect(game.inventory.size() == 1 and drop.is_queued_for_deletion() and Grid.placed(game.inventory[0]), "real pickup inserts into compact grid")

	game.inventory.clear()
	var armor := sample("armor", "生命胸甲")
	armor["hp"] = 33
	armor["armor"] = 0.24
	Grid.try_add(game.inventory, armor)
	var hp_before: float = game.player.max_hp
	game.equip_item(0)
	expect(game.equipment["armor"]["name"] == "生命胸甲" and game.inventory.is_empty(), "equipping into an empty slot does not create a fake starter item")
	expect(is_equal_approx(game.player.max_hp, hp_before + 33.0), "first equipped armor updates actual health")

	game.hud.toggle_inventory()
	expect(game.hud.inventory_open and game.hud._bag_page.visible and not game.hud._equipment_page.visible, "open bag defaults to backpack tab")
	expect(game.hud._grid_view.custom_minimum_size == Vector2(756, 420), "compact grid uses 42px cells across 18 by 10")
	expect(game.hud._grid_view.CELL == 42.0, "item cells are substantially smaller than the old 60px cards")
	expect(not game.hud._item_details.visible and game.hud._item_details.text.is_empty(), "unselected bag hides item details")
	game.hud._open_equipment()
	expect(game.hud._weapon_button.text.contains("空") and game.hud._armor_button.text.contains("生命胸甲"), "equipment tab clearly shows empty and equipped slots")
	game.hud._open_bag()

	var weapon := sample("weapon", "短劍")
	Grid.try_add(game.inventory, weapon)
	game.hud._refresh_inventory()
	game.hud._on_grid_cell(int(game.inventory[0]["grid_x"]), int(game.inventory[0]["grid_y"]))
	expect(game.hud._item_details.visible and game.hud._item_details.text.contains("短劍"), "item name and stats appear only after selecting an item")
	var tap := InputEventScreenTouch.new()
	tap.index = 4
	tap.position = Vector2(5.0 * 42.0 + 3.0, 4.0 * 42.0 + 3.0)
	tap.pressed = true
	game.hud._grid_view._gui_input(tap)
	expect(int(game.inventory[0]["grid_x"]) == 5 and int(game.inventory[0]["grid_y"]) == 4, "compact touch hitboxes map to correct grid cells")

	game.save_progress()
	expect(FileAccess.file_exists(game.SAVE_PATH), "Phase 8 persists to its isolated save file")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	expect(saved is Dictionary and saved["inventory"].size() == 1, "compact inventory state persists")
	game.queue_free()
	print("PHASE3 INVENTORY: %d passed / %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _script_chain_contains(script: Script, filename: String) -> bool:
	var current: Script = script
	while current != null:
		if current.resource_path.ends_with(filename):
			return true
		current = current.get_base_script()
	return false
