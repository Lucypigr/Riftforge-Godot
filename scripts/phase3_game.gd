extends "res://scripts/phase2_game.gd"
## Phase 5 adds weapon gameplay on this isolated branch; Phase 3 inventory remains intact.
const Grid = preload("res://scripts/grid_inventory.gd")
const GridHUD = preload("res://scripts/grid_hud.gd")
const WeaponRules = preload("res://research/phase5/weapon_rules.gd")
const SlashDefinition = preload("res://research/phase2/skill_definition.gd")
var _slash_skill

func _ready() -> void:
	super._ready()
	_slash_skill = SlashDefinition.new()
	_slash_skill.skill_id = &"basic_slash"
	_slash_skill.display_name = "武器斬擊"
	_slash_skill.delivery = "area"
	_slash_skill.damage_type = &"physical"
	_slash_skill.base_damage = 6.0
	_slash_skill.mana_cost = 0.0
	_slash_skill.cooldown = 0.67
	_slash_skill.cast_range = 3.1
	_slash_skill.radius = 3.1
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
		hud.announce("Phase 5：換武器會改變近遠戰、攻速與射程")
	_sync_cooldowns()
	save_progress()

func _sync_cooldowns() -> void:
	super._sync_cooldowns()
	if _slash_skill != null and WeaponRules.mode(equipment["weapon"]) == "melee":
		_bolt_cd = _skill_runtime.remaining(_slash_skill.skill_id)

func cast_bolt() -> void:
	if _skill_runtime == null or not is_instance_valid(player) or ui_open:
		return
	var weapon: Dictionary = equipment["weapon"]
	if WeaponRules.mode(weapon) == "melee":
		_cast_weapon_slash(weapon)
		return
	# The existing Ember Bolt/gem/projectile path remains shared by desktop and mobile.
	# Cooldown and maximum travel distance now actually depend on the equipped weapon.
	_bolt_skill.cooldown = WeaponRules.interval(weapon)
	_bolt_skill.cast_range = WeaponRules.reach(weapon)
	super.cast_bolt()

func _cast_weapon_slash(weapon: Dictionary) -> void:
	var direction: Vector3 = Vector3(aim_direction.x, 0.0, aim_direction.z)
	if direction.length_squared() < 0.0001:
		_skill_blocked("invalid_aim", "武器斬擊", 0)
		return
	direction = direction.normalized()
	var radius: float = WeaponRules.reach(weapon)
	_slash_skill.radius = radius
	_slash_skill.cast_range = radius
	_slash_skill.cooldown = WeaponRules.interval(weapon)
	var targets: Array = []
	var enemies_by_id: Dictionary = {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.hp <= 0.0:
			continue
		if not WeaponRules.within_arc(player.global_position, direction, enemy.global_position, radius):
			continue
		var enemy_id: int = enemy.get_instance_id()
		enemies_by_id[enemy_id] = enemy
		targets.append({"id": enemy_id, "hp": enemy.hp, "position": enemy.global_position,
			"resistance": 0.08 if enemy.boss else 0.0,
			"defensive_ability": enemy.defensive_ability,
			"armor_rating": enemy.armor_rating,
			"armor_absorption": enemy.armor_absorption,
			"resistances": enemy.damage_resistances})
	_skill_runtime.mana = player.mana
	var modifiers: Dictionary = {"flat_damage": float(weapon.get("damage", 0.0)),
		"offensive_ability": _offensive_ability(), "can_miss": false}
	var result: Dictionary = _skill_runtime.cast(_slash_skill, player.global_position, direction, targets, modifiers)
	if not bool(result.get("ok", false)):
		_skill_blocked(str(result.get("reason", "")), "武器斬擊", 0)
		return
	player.mana = _skill_runtime.mana
	_sync_cooldowns()
	spawn_burst(player.global_position + direction * 1.1, Color("#f1d4a4"), 0.75)
	for hit in result["hits"]:
		var enemy = enemies_by_id.get(int(hit["target_id"]))
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.hp > 0.0:
			enemy.take_hit(int(hit["damage"]), player.global_position)

func _interact() -> void:
	# Share one semantic target lookup with hints/mobile controls; only loot insertion differs here.
	if ui_open:
		return
	var target: Dictionary = get_interaction_target()
	if str(target.get("kind", "")) != "loot":
		_activate_interaction_target(target)
		return
	var nearest = target.get("node")
	if not is_instance_valid(nearest) or nearest.is_queued_for_deletion():
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
	# Empty slots do not create a fake placeholder item. Real swaps remain atomic.
	if not str(old_item.get("name", "")).is_empty():
		if not Grid.try_add(next_inventory, old_item):
			hud.announce("交換裝備失敗：背包無法容納原裝備。")
			return
	selected.erase("grid_x")
	selected.erase("grid_y")
	inventory = next_inventory
	equipment[slot] = selected
	player.refresh_equipment()
	_sync_cooldowns()
	var announcement: String = "已裝備：" + str(selected.get("name", "物品"))
	if slot == "weapon":
		announcement += "｜%s｜攻擊間隔 %.2f 秒" % ["近戰" if WeaponRules.mode(selected) == "melee" else "遠程", WeaponRules.interval(selected)]
	hud.announce(announcement)
	save_progress()
