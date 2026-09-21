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
	expect(game.get_script().resource_path.ends_with("phase3_game.gd"), "playable scene uses Phase 3 inventory bridge")
	expect(game.hud.get_script().resource_path.ends_with("grid_hud.gd"), "actual game uses grid HUD")
	var items: Array = []
	expect(Grid.footprint(sample()) == Vector2i(2, 3), "weapon occupies multiple cells")
	expect(Grid.try_add(items, sample("weapon", "A")), "first weapon fits")
	expect(Grid.try_add(items, sample("armor", "B")), "second large item fits separately")
	expect(Grid.item_at(items, 0, 2) == 0 and Grid.item_at(items, 2, 1) == 1, "occupied cells identify complete items")
	expect(not Grid.move(items, 0, 2, 0), "overlap rejected without destroying item")
	expect(not Grid.move(items, 0, 11, 4), "out-of-bounds rejected")
	expect(Grid.move(items, 0, 10, 2), "valid move changes real inventory position")
	expect(Grid.item_at(items, 10, 4) == 0 and Grid.item_at(items, 0, 2) == -1, "new occupancy matches moved footprint")
	var legacy: Array = [sample("weapon", "舊武器"), sample("armor", "舊護甲")]
	legacy[0]["grid_x"] = 0
	legacy[0]["grid_y"] = 0
	legacy[1]["grid_x"] = 0
	legacy[1]["grid_y"] = 0
	expect(Grid.normalize(legacy) == 0 and Grid.placed(legacy[0]) and Grid.placed(legacy[1]) and legacy[1]["grid_x"] != 0, "overlapping legacy save safely repacked")
	var full: Array = []
	for i in range(60):
		Grid.try_add(full, sample("gem", "格子"))
	expect(full.size() == 60 and Grid.overflow_count(full) == 0, "exact 12 by 5 capacity")
	expect(not Grid.try_add(full, sample()) and full.size() == 60, "full bag rejects extra loot without mutation")
	var existing: Array = full.duplicate(true)
	existing.append(sample("weapon", "舊檔額外武器"))
	expect(Grid.normalize(existing) == 1 and existing.size() == 61 and not Grid.placed(existing[60]), "old save overflow retained instead of deleted")
	game.inventory = full
	var drop = Loot.new()
	drop.initialize(sample("weapon", "地面武器"))
	drop.position = game.player.position + Vector3(0.2, -0.5, 0)
	game.add_child(drop)
	game._interact()
	expect(game.inventory.size() == 60 and not drop.is_queued_for_deletion(), "full-bag pickup leaves ground loot intact")
	game.inventory.clear()
	game._interact()
	expect(game.inventory.size() == 1 and drop.is_queued_for_deletion() and Grid.placed(game.inventory[0]), "successful pickup occupies cells and removes ground loot")
	game.inventory.clear()
	var armor := sample("armor", "生命胸甲")
	armor["hp"] = 33
	armor["armor"] = 0.24
	Grid.try_add(game.inventory, armor)
	var hp_before: float = game.player.max_hp
	game.equip_item(0)
	expect(game.equipment["armor"]["name"] == "生命胸甲" and game.inventory.size() == 1, "equipping swaps real old item into bag")
	expect(game.player.max_hp == hp_before + 33.0, "equipped armor changes actual playable health")
	game.hud.toggle_inventory()
	expect(game.hud.inventory_open and game.hud._grid_view.items.size() == 1, "opened inventory renders real item state")
	game.hud._on_grid_cell(0, 0)
	game.hud._on_grid_cell(10, 2)
	expect(int(game.inventory[0]["grid_x"]) == 10 and int(game.inventory[0]["grid_y"]) == 2, "UI taps really move item")
	expect(FileAccess.file_exists(game.SAVE_PATH), "game writes a save")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	expect(saved is Dictionary and saved["inventory"].size() == 1 and int(saved["inventory"][0]["grid_x"]) == 10, "grid positions persist in save JSON")
	game.hud.close_panels()
	game.inventory.clear()
	var tiny := sample("weapon", "一格測試武器")
	tiny["grid_w"] = 1
	tiny["grid_h"] = 1
	Grid.try_add(game.inventory, tiny)
	for i in range(59):
		Grid.try_add(game.inventory, sample("gem", "阻擋"))
	var old_weapon := str(game.equipment["weapon"]["name"])
	game.equip_item(0)
	expect(game.inventory.size() == 60 and str(game.equipment["weapon"]["name"]) == old_weapon, "failed equipment swap is atomic and loses nothing")
	game.queue_free()
	print("PHASE3 INVENTORY: %d passed / %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
