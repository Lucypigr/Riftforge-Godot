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
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	expect(game.get_script().resource_path.ends_with("phase3_game.gd"), "real playable scene uses Phase 3 inventory")
	expect(game.hud.get_script().resource_path.ends_with("grid_hud.gd"), "real game uses inventory and equipment tabs")
	expect(Grid.COLS == 12 and Grid.ROWS == 10 and Grid.PAGE_COUNT == 2, "physical storage is 120 cells across two pages")
	var items: Array = []
	expect(Grid.footprint(sample()) == Vector2i(2, 3), "weapon occupies multiple cells")
	expect(Grid.try_add(items, sample("weapon", "A")), "first weapon fits")
	expect(Grid.try_add(items, sample("armor", "B")), "second large item fits")
	expect(Grid.item_at(items, 0, 2) == 0 and Grid.item_at(items, 2, 1) == 1, "occupied cells identify real items")
	expect(not Grid.move(items, 0, 2, 0), "item overlap is rejected")
	expect(not Grid.move(items, 0, 11, 4), "out of bounds and page-spanning placement is rejected")
	expect(not Grid.move(items, 0, 5, 4), "an item cannot be split across inventory pages")
	expect(Grid.move(items, 0, 10, 2), "valid move changes real position")
	expect(Grid.move(items, 0, 10, 5) and Grid.item_at(items, 10, 7) == 0, "large equipment moves safely between both pages")
	var legacy: Array = [sample("weapon", "舊武器"), sample("armor", "舊護甲")]
	legacy[0]["grid_x"] = 0
	legacy[0]["grid_y"] = 0
	legacy[1]["grid_x"] = 0
	legacy[1]["grid_y"] = 0
	expect(Grid.normalize(legacy) == 0 and Grid.placed(legacy[0]) and Grid.placed(legacy[1]) and legacy[1]["grid_x"] != 0, "legacy overlapping save repacked without item loss")
	var expanded: Array = []
	for i in range(60):
		Grid.try_add(expanded, sample("gem", "填第一頁"))
	expect(Grid.try_add(expanded, sample("weapon", "第二頁武器")) and int(expanded.back()["grid_y"]) >= Grid.PAGE_ROWS, "pickup flows into second page after first 60 cells fill")
	var full: Array = []
	for i in range(120):
		Grid.try_add(full, sample("gem", "格子"))
	expect(full.size() == 120 and Grid.occupied_cells(full) == 120 and Grid.overflow_count(full) == 0, "exact 12 by 10 physical capacity is 120")
	expect(not Grid.try_add(full, sample()) and full.size() == 120, "true full bag refuses further loot without mutation")
	var existing: Array = full.duplicate(true)
	existing.append(sample("weapon", "舊檔額外武器"))
	expect(Grid.normalize(existing) == 1 and existing.size() == 121 and not Grid.placed(existing[120]), "oversized old save keeps overflow safely")
	game.inventory = full
	var drop = Loot.new()
	drop.initialize(sample("weapon", "地面武器"))
	drop.position = game.player.position + Vector3(0.2, -0.5, 0)
	game.add_child(drop)
	game._interact()
	expect(game.inventory.size() == 120 and not drop.is_queued_for_deletion(), "120-cell full bag leaves ground loot intact")
	game.inventory.clear()
	game._interact()
	expect(game.inventory.size() == 1 and drop.is_queued_for_deletion() and Grid.placed(game.inventory[0]), "real pickup inserts into grid")
	game.inventory.clear()
	var armor := sample("armor", "生命胸甲")
	armor["hp"] = 33
	armor["armor"] = 0.24
	Grid.try_add(game.inventory, armor)
	var hp_before: float = game.player.max_hp
	game.equip_item(0)
	expect(game.equipment["armor"]["name"] == "生命胸甲" and game.inventory.size() == 1, "equipment swaps original old item into bag")
	expect(game.player.max_hp == hp_before + 33.0, "equipped armor modifies actual playable health")
	game.hud.toggle_inventory()
	expect(game.hud.inventory_open and game.hud._bag_page.visible and not game.hud._equipment_page.visible, "open bag defaults to backpack tab")
	expect(game.hud._grid_view.items.size() == 1 and game.hud._grid_view.page == 0, "first page shows real item state")
	game.hud._on_grid_cell(0, 0)
	game.hud._on_grid_cell(10, 2)
	expect(int(game.inventory[0]["grid_x"]) == 10 and int(game.inventory[0]["grid_y"]) == 2, "first-page UI taps move real items")
	game.hud._set_grid_page(1)
	expect(game.hud._grid_view.page == 1 and game.hud._page_label.text == "背包 2 / 2", "second page opens with correct navigation")
	game.hud._on_grid_cell(8, 5)
	expect(int(game.inventory[0]["grid_x"]) == 8 and int(game.inventory[0]["grid_y"]) == 5, "selected item can move from first page to second")
	var tap := InputEventScreenTouch.new()
	tap.index = 4
	tap.position = Vector2(3.0 * 52.0 + 3.0, 3.0)
	tap.pressed = true
	game.hud._grid_view._gui_input(tap)
	expect(int(game.inventory[0]["grid_x"]) == 3 and int(game.inventory[0]["grid_y"]) == 5, "touch on second page maps to global storage row five")
	game.hud._open_equipment()
	expect(not game.hud._bag_page.visible and game.hud._equipment_page.visible and game.hud._equipment_tab_button.disabled, "equipment is a separate tab, not merged into backpack")
	game.hud._inspect_armor()
	expect(game.hud._equipment_details.text.contains("生命胸甲"), "equipment tab displays actual equipped item attributes")
	game.hud._open_bag()
	expect(game.hud._bag_page.visible and not game.hud._equipment_page.visible and game.hud._grid_view.page == 1, "returning to bag preserves inventory page")
	expect(FileAccess.file_exists(game.SAVE_PATH), "game persists a save file")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	expect(saved is Dictionary and saved["inventory"].size() == 1 and int(saved["inventory"][0]["grid_y"]) == 5, "second-page coordinates persist to actual save")
	game.hud.close_panels()
	game.inventory.clear()
	var tiny := sample("weapon", "一格測試武器")
	tiny["grid_w"] = 1
	tiny["grid_h"] = 1
	Grid.try_add(game.inventory, tiny)
	for i in range(119):
		Grid.try_add(game.inventory, sample("gem", "阻擋"))
	var old_weapon := str(game.equipment["weapon"]["name"])
	game.equip_item(0)
	expect(game.inventory.size() == 120 and str(game.equipment["weapon"]["name"]) == old_weapon, "failed swap stays atomic at expanded capacity")
	game.queue_free()
	print("PHASE3 INVENTORY: %d passed / %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
