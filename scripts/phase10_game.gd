extends "res://scripts/phase7_game.gd"
## Phase 10: all new active/support behavior is resolved from one gem pipeline.
const GemSystem = preload("res://scripts/phase10_gem_system.gd")
const SkillDefinition10 = preload("res://research/phase2/skill_definition.gd")
const CombatResolver10 = preload("res://research/phase4/combat_resolver_v2.gd")
const WeaponRules10 = preload("res://research/phase5/weapon_rules.gd")
const ResolvedProjectile = preload("res://scripts/phase10_projectile.gd")
const GroundArea = preload("res://scripts/phase10_ground_area.gd")
const Phase10HUD = preload("res://scripts/phase10_hud.gd")

var gem_instances: Array = GemSystem.default_instances()
var socket_links: Array = GemSystem.default_links()
var _phase10_ready := false
var _had_phase10_save := false

func _ready() -> void:
	# Load Phase 10 socket data before parent startup can rewrite the shared save file.
	_had_phase10_save = _phase10_state_exists()
	if _had_phase10_save:
		_load_phase10_state()
	super._ready()
	if not _had_phase10_save:
		skill_slots = ["ember_bolt","shock_nova","frost_shard","arc_spark","rift_cleave","cinder_field"]
	_sanitize_skill_slots()
	_phase10_ready = true
	var previous_hud = hud
	remove_child(previous_hud)
	previous_hud.queue_free()
	hud = Phase10HUD.new()
	hud.initialize(self)
	add_child(hud)
	hud.announce("Phase 10：資料驅動寶石已啟用；F 世界互動，G 檢視寶石與最終技能")
	save_progress()

func installed_skill_gems() -> Array:
	return GemSystem.installed_active_ids(gem_instances)

func skill_name(gem_id: String) -> String:
	return GemSystem.display_name(gem_id)

func skill_icon(gem_id: String) -> String:
	return GemSystem.icon_path(gem_id)

func resolved_skill(gem_id: String) -> Dictionary:
	return GemSystem.resolve(gem_id, gem_instances, socket_links)

func skill_tooltip(gem_id: String) -> String:
	return GemSystem.tooltip(resolved_skill(gem_id))

func skill_cooldown(gem_id: String) -> float:
	if _skill_runtime == null:
		return 0.0
	return _skill_runtime.remaining(StringName(gem_id))

func skill_mana_cost(gem_id: String) -> float:
	return float(resolved_skill(gem_id).get("mana_cost", 0.0))

func skill_slot_disabled(slot: int) -> bool:
	var gem_id := skill_gem(slot)
	if gem_id.is_empty() or not (gem_id in installed_skill_gems()):
		return true
	return ui_open or skill_cooldown(gem_id) > 0.0 or player.mana < skill_mana_cost(gem_id)

func cast_skill_slot(slot: int) -> bool:
	if mobile_active or slot < 0 or slot >= skill_slots.size():
		return false
	return cast_active_gem(skill_gem(slot), aim_direction)

func cast_mobile_slot(slot: int, aim: Vector3) -> bool:
	if not mobile_active or slot < 0 or slot >= skill_slots.size():
		return false
	return cast_active_gem(skill_gem(slot), aim)

func skill_requires_aim(slot: int) -> bool:
	var resolved := resolved_skill(skill_gem(slot))
	return not resolved.is_empty() and str(resolved.get("behavior", "")) != "nova"

func skill_preview_kind(slot: int) -> String:
	return str(resolved_skill(skill_gem(slot)).get("behavior", ""))

func cast_active_gem(gem_id: String, aim: Vector3) -> bool:
	if ui_open or gem_id.is_empty() or not (gem_id in installed_skill_gems()) or _skill_runtime == null:
		return false
	var resolved := resolved_skill(gem_id)
	if resolved.is_empty():
		return false
	var behavior := str(resolved.get("behavior", ""))
	var horizontal := Vector3(aim.x, 0.0, aim.z)
	if behavior != "nova" and horizontal.length_squared() < 0.0001:
		_skill_blocked("invalid_aim", skill_name(gem_id), int(resolved.get("mana_cost", 0)))
		return false
	match behavior:
		"projectile":
			return _phase10_cast_projectile(resolved, horizontal.normalized())
		"nova":
			return _phase10_cast_nova(resolved)
		"melee_cone":
			return _phase10_cast_melee(resolved, horizontal.normalized())
		"ground_area":
			return _phase10_cast_ground_area(resolved, horizontal.normalized())
	return false

func _phase10_skill_definition(resolved: Dictionary):
	var skill = SkillDefinition10.new()
	skill.skill_id = StringName(str(resolved.get("id", "")))
	skill.display_name = str(resolved.get("display_name", ""))
	skill.delivery = "projectile" if str(resolved.get("behavior", "")) == "projectile" else "area"
	skill.damage_type = StringName(str(resolved.get("damage_type", "physical")))
	var components: Dictionary = resolved.get("damage_components", {})
	skill.base_damage = float(components.get(str(resolved.get("damage_type", "physical")), 0.0))
	skill.mana_cost = float(resolved.get("mana_cost", 0.0))
	skill.cooldown = float(resolved.get("interval", 0.0))
	skill.cast_range = maxf(0.1, float(resolved.get("cast_range", 0.1)))
	skill.radius = maxf(0.1, float(resolved.get("aoe_radius", 0.1))) if skill.delivery == "area" else 0.0
	return skill

func phase10_hit_modifiers(resolved: Dictionary, chain_index: int = 0) -> Dictionary:
	var components: Dictionary = resolved.get("damage_components", {})
	var primary := str(resolved.get("damage_type", "physical"))
	var added: Dictionary = {}
	for damage_type in components:
		if str(damage_type) != primary:
			added[str(damage_type)] = float(components[damage_type])
	var chain_factor := pow(float(resolved.get("chain_damage_multiplier", 1.0)), chain_index)
	return {
		"offensive_ability": _offensive_ability(),
		"added_damage_by_type": added,
		"more_multiplier": float(resolved.get("more_damage", 1.0)) * chain_factor
	}

func _phase10_cast_projectile(resolved: Dictionary, heading: Vector3) -> bool:
	var skill = _phase10_skill_definition(resolved)
	_skill_runtime.mana = player.mana
	var result: Dictionary = _skill_runtime.cast(skill, player.global_position, heading, [])
	if not bool(result.get("ok", false)):
		_skill_blocked(str(result.get("reason", "")), skill.display_name, int(skill.mana_cost))
		return false
	player.mana = _skill_runtime.mana
	var count := maxi(1, int(resolved.get("projectile_count", 1)))
	for shot in range(count):
		var angle := deg_to_rad((float(shot) - (float(count) - 1.0) * 0.5) * 12.0)
		var direction := heading.rotated(Vector3.UP, angle)
		var projectile = ResolvedProjectile.new()
		projectile.initialize(self, _skill_runtime, skill, resolved, direction)
		projectile.position = player.global_position + direction * 0.83 + Vector3(0, 0.1, 0)
		add_child(projectile)
	spawn_burst(player.global_position + heading * 0.8, Color("#a9e9ff") if str(resolved.get("damage_type", "")) == "cold" else Color("#ffbb73"), 0.48)
	_sync_cooldowns()
	return true

func _phase10_targets(radius: float, direction: Vector3 = Vector3.ZERO, cone: bool = false) -> Dictionary:
	var targets: Array = []
	var nodes: Dictionary = {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.hp <= 0.0:
			continue
		if cone and not WeaponRules10.within_arc(player.global_position, direction, enemy.global_position, radius):
			continue
		if not cone and enemy.global_position.distance_to(player.global_position) > radius:
			continue
		var enemy_id := enemy.get_instance_id()
		nodes[enemy_id] = enemy
		targets.append({
			"id":enemy_id,"hp":enemy.hp,"position":enemy.global_position,
			"resistance":0.08 if enemy.boss else 0.0,
			"defensive_ability":enemy.defensive_ability,
			"armor_rating":enemy.armor_rating,
			"armor_absorption":enemy.armor_absorption,
			"resistances":enemy.damage_resistances
		})
	return {"targets":targets,"nodes":nodes}

func _phase10_cast_nova(resolved: Dictionary) -> bool:
	var skill = _phase10_skill_definition(resolved)
	var selection := _phase10_targets(float(resolved.get("aoe_radius", 0.0)))
	_skill_runtime.mana = player.mana
	var modifiers := phase10_hit_modifiers(resolved)
	modifiers["can_miss"] = false
	var result: Dictionary = _skill_runtime.cast(skill, player.global_position, Vector3.ZERO, selection["targets"], modifiers)
	if not bool(result.get("ok", false)):
		_skill_blocked(str(result.get("reason", "")), skill.display_name, int(skill.mana_cost))
		return false
	player.mana = _skill_runtime.mana
	for hit in result.get("hits", []):
		var enemy = selection["nodes"].get(int(hit.get("target_id", 0)))
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.take_hit(int(hit.get("damage", 0)), player.global_position)
			phase10_apply_statuses(enemy, resolved)
	spawn_burst(player.global_position, Color("#83dcff"), float(resolved.get("aoe_radius", 1.0)))
	_sync_cooldowns()
	return true

func _phase10_cast_melee(resolved: Dictionary, heading: Vector3) -> bool:
	var radius := float(resolved.get("aoe_radius", 3.0))
	var skill = _phase10_skill_definition(resolved)
	var selection := _phase10_targets(radius, heading, true)
	_skill_runtime.mana = player.mana
	var modifiers := phase10_hit_modifiers(resolved)
	modifiers["can_miss"] = false
	modifiers["flat_damage"] = float(equipment["weapon"].get("damage", 0.0)) * float(resolved.get("weapon_damage_multiplier", 1.0))
	var result: Dictionary = _skill_runtime.cast(skill, player.global_position, heading, selection["targets"], modifiers)
	if not bool(result.get("ok", false)):
		_skill_blocked(str(result.get("reason", "")), skill.display_name, int(skill.mana_cost))
		return false
	player.mana = _skill_runtime.mana
	for hit in result.get("hits", []):
		var enemy = selection["nodes"].get(int(hit.get("target_id", 0)))
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.take_hit(int(hit.get("damage", 0)), player.global_position)
			phase10_apply_statuses(enemy, resolved)
	spawn_burst(player.global_position + heading * minf(1.1, radius * 0.4), Color("#f1d4a4"), radius * 0.55)
	_sync_cooldowns()
	return true

func _phase10_cast_ground_area(resolved: Dictionary, heading: Vector3) -> bool:
	var skill = _phase10_skill_definition(resolved)
	_skill_runtime.mana = player.mana
	var result: Dictionary = _skill_runtime.cast(skill, player.global_position, heading, [])
	if not bool(result.get("ok", false)):
		_skill_blocked(str(result.get("reason", "")), skill.display_name, int(skill.mana_cost))
		return false
	player.mana = _skill_runtime.mana
	var area = GroundArea.new()
	area.initialize(self, resolved)
	area.position = player.global_position + heading * float(resolved.get("cast_range", 6.0))
	add_child(area)
	_sync_cooldowns()
	return true

func phase10_apply_statuses(enemy, resolved: Dictionary) -> void:
	if not is_instance_valid(enemy):
		return
	for status in resolved.get("status_effects", []):
		if status is Dictionary and str(status.get("type", "")) == "slow" and enemy.has_method("apply_slow"):
			enemy.apply_slow(float(status.get("multiplier", 1.0)), float(status.get("duration", 0.0)))

func phase10_ground_tick(origin: Vector3, resolved: Dictionary) -> void:
	var skill = _phase10_skill_definition(resolved)
	skill.mana_cost = 0.0
	skill.cooldown = 0.0
	var radius := float(resolved.get("aoe_radius", 0.0))
	var modifiers := phase10_hit_modifiers(resolved)
	modifiers["can_miss"] = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.hp <= 0.0:
			continue
		if enemy.global_position.distance_to(origin) > radius:
			continue
		var target := {
			"hp":enemy.hp,"position":enemy.global_position,
			"resistance":0.08 if enemy.boss else 0.0,
			"defensive_ability":enemy.defensive_ability,
			"armor_rating":enemy.armor_rating,
			"armor_absorption":enemy.armor_absorption,
			"resistances":enemy.damage_resistances
		}
		var hit: Dictionary = CombatResolver10.resolve(skill, target, modifiers, 0.0, randf())
		if bool(hit.get("ok", false)) and bool(hit.get("hit", true)) and int(hit.get("damage", 0)) > 0:
			enemy.take_hit(int(hit["damage"]), origin)

func remove_gem(gem_id: String) -> bool:
	for i in range(gem_instances.size()):
		if str(gem_instances[i].get("gem_id", "")) == gem_id:
			gem_instances.remove_at(i)
			_sanitize_skill_slots()
			save_progress()
			return true
	return false

func set_phase10_socket_state(instances: Array, links: Array) -> void:
	gem_instances = instances.duplicate(true)
	socket_links = links.duplicate(true)
	_sanitize_skill_slots()
	if _phase10_ready:
		save_progress()

func _phase10_state_exists() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	return data is Dictionary and data.get("gem_instances") is Array

func _load_phase10_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	if data.get("gem_instances") is Array:
		gem_instances = data["gem_instances"].duplicate(true)
	if data.get("socket_links") is Array:
		socket_links = data["socket_links"].duplicate(true)
	if data.get("skill_slots") is Array and data["skill_slots"].size() == 6:
		skill_slots = data["skill_slots"].duplicate()

func save_progress() -> void:
	super.save_progress()
	if not _phase10_ready:
		return
	var data: Dictionary = {}
	if FileAccess.file_exists(SAVE_PATH):
		var read_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if read_file != null:
			var parsed = JSON.parse_string(read_file.get_as_text())
			if parsed is Dictionary:
				data = parsed
	data["version"] = maxi(10, int(data.get("version", 1)))
	data["gem_instances"] = gem_instances
	data["socket_links"] = socket_links
	data["skill_slots"] = skill_slots
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))
