extends "res://scripts/phase2_game.gd"
## Phase 3 inventory with optional Phase 4 combat, isolated on feature/phase4-combat-v2.
const Grid = preload("res://scripts/grid_inventory.gd")
const GridHUD = preload("res://scripts/grid_hud.gd")

func _ready() -> void:
	super._ready()
	# Phase 4 branch only: PC and mobile share one resolver and unchanged casting controls.
	_skill_runtime.use_combat_v2 = true
	_nova_skill.damage_type = &"lightning"
	var extra := Grid.normalize(inventory)
	var previous_hud = hud
	remove_child(previous_hud)
	previous_hud.queue_free()
	hud = GridHUD.new()
	hud.initialize(self)
	add_child(hud)
	if extra > 0:
		hud.announce("舊存檔有 %d 件物品超出格子，已保留，可於背包清單查看。" % extra)
	else:
		hud.announce("戰鬥 V2 已啟用：武器與技能依傷害類型計算")
	save_progress()

func _interact() -> void:
	# Override only loot insertion; retain original portals and zone progression.
	var nearest = null
	var best := 2.3
	for drop in get_tree().get_nodes_in_group("loot"):
		if not is_instance_valid(drop) or drop.is_queued_for_deletion():
			continue
		var distance: float = drop.global_position.distance_to(player.global_position)
		if distance < best:
			best = distance
			nearest = drop
	if nearest == null:
		super._interact()
		return
	if not Grid.try_add(inventory, nearest.item):
		hud.announce("背包空間不足：先整理或裝備物品。戰利品仍留在地上。")
		return
	hud.announce("取得：" + str(nearest.item.get("name", "物品")))
	nearest.queue_free()
	save_progress()

func equip_item(index: int) -> void:
	if index < 0 or index >= inventory.size():
		return
	var selected: Dictionary = inventory[index].duplicate(true)
	var slot := str(selected.get("slot", ""))
	if not equipment.has(slot):
		hud.announce("此物品無法裝入目前裝備欄位。")
		return
	var old_item: Dictionary = equipment[slot].duplicate(true)
	var next_inventory: Array = inventory.duplicate(true)
	next_inventory.remove_at(index)
	# All changes commit together. A failed swap must not delete either item.
	if not Grid.try_add(next_inventory, old_item):
		hud.announce("交換裝備失敗：背包無法容納原裝備。")
		return
	selected.erase("grid_x")
	selected.erase("grid_y")
	inventory = next_inventory
	equipment[slot] = selected
	player.refresh_equipment()
	hud.announce("已裝備：" + str(selected.get("name", "物品")))
	save_progress()
