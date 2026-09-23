extends "res://scripts/phase6_game.gd"
## Phase 7: six freely assignable PC skill slots driven only by installed active gems.
## Mobile keeps the existing dedicated touch controls.
const Phase7HUD = preload("res://scripts/phase7_hud.gd")
const Phase7Projectile = preload("res://scripts/phase2_projectile.gd")
const GemRules = preload("res://scripts/gem_rules.gd")

const SKILL_ACTIONS := ["skill_slot_0", "skill_slot_1", "skill_slot_2", "skill_slot_3", "skill_slot_4", "skill_slot_5"]
const SKILL_BINDINGS := ["滑鼠左鍵", "滑鼠右鍵", "Q", "E", "R", "T"]

# Prototype currently has one original 3-link group plus a second installed active gem.
# Hotbar entries reference these installed actives; support gems never enter skill_slots.
var installed_active_gems: Array = ["ember_bolt", "shock_nova"]
var skill_slots: Array = ["ember_bolt", "shock_nova", "", "", "", ""]

func _ready() -> void:
	super._ready()
	var previous_hud = hud
	remove_child(previous_hud)
	previous_hud.queue_free()
	hud = Phase7HUD.new()
	hud.initialize(self)
	add_child(hud)
	hud.announce("技能列已改為自由寶石配置；F 互動，I 背包，G 寶石配置")

func _setup_input() -> void:
	super._setup_input()
	# E is now a skill key. Move world interaction/pickup to F.
	InputMap.action_erase_events("interact")
	var interact_event := InputEventKey.new()
	interact_event.physical_keycode = KEY_F
	InputMap.action_add_event("interact", interact_event)

	# Prevent the inherited hard-wired left/right attack actions from firing.
	InputMap.action_erase_events("attack")
	InputMap.action_erase_events("nova")

	for action in SKILL_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)

	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(SKILL_ACTIONS[0], left)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event(SKILL_ACTIONS[1], right)
	for i in range(4):
		var key := InputEventKey.new()
		key.physical_keycode = [KEY_Q, KEY_E, KEY_R, KEY_T][i]
		InputMap.action_add_event(SKILL_ACTIONS[i + 2], key)

func _process(delta: float) -> void:
	super._process(delta)
	if mobile_active or ui_open or zone != "field" or not is_instance_valid(player):
		return
	for slot in range(SKILL_ACTIONS.size()):
		if Input.is_action_pressed(SKILL_ACTIONS[slot]):
			cast_skill_slot(slot)

func installed_skill_gems() -> Array:
	var result: Array = []
	for gem_id in installed_active_gems:
		var id := str(gem_id)
		if GemRules.is_active(id) and not (id in result):
			result.append(id)
	return result

func skill_binding_name(slot: int) -> String:
	return SKILL_BINDINGS[slot] if slot >= 0 and slot < SKILL_BINDINGS.size() else ""

func skill_gem(slot: int) -> String:
	if slot < 0 or slot >= skill_slots.size():
		return ""
	return str(skill_slots[slot])

func skill_name(gem_id: String) -> String:
	return GemRules.display_name(gem_id)

func skill_icon(gem_id: String) -> String:
	return GemRules.icon_path(gem_id)

func assign_skill_slot(slot: int, gem_id: String) -> bool:
	if slot < 0 or slot >= 6:
		return false
	if gem_id != "" and not (gem_id in installed_skill_gems()):
		return false
	# One installed gem instance may occupy only one hotbar slot.
	if gem_id != "":
		for i in range(skill_slots.size()):
			if i != slot and str(skill_slots[i]) == gem_id:
				skill_slots[i] = ""
	skill_slots[slot] = gem_id
	save_progress()
	return true

func skill_cooldown(gem_id: String) -> float:
	if _skill_runtime == null:
		return 0.0
	match gem_id:
		"ember_bolt":
			return _skill_runtime.remaining(_bolt_skill.skill_id)
		"shock_nova":
			return _skill_runtime.remaining(_nova_skill.skill_id)
		_:
			return 0.0

func skill_mana_cost(gem_id: String) -> float:
	match gem_id:
		"ember_bolt":
			return _bolt_skill.mana_cost if _bolt_skill != null else 3.0
		"shock_nova":
			return _nova_skill.mana_cost if _nova_skill != null else 25.0
		_:
			return 0.0

func skill_slot_disabled(slot: int) -> bool:
	var gem_id := skill_gem(slot)
	if gem_id == "":
		return true
	if not (gem_id in installed_skill_gems()):
		return true
	return ui_open or skill_cooldown(gem_id) > 0.0 or player.mana < skill_mana_cost(gem_id)

func cast_skill_slot(slot: int) -> bool:
	if slot < 0 or slot >= 6 or ui_open or mobile_active:
		return false
	var gem_id := skill_gem(slot)
	if gem_id == "" or not (gem_id in installed_skill_gems()):
		return false
	if skill_cooldown(gem_id) > 0.0:
		return false
	match gem_id:
		"ember_bolt":
			return _cast_ember_bolt_skill()
		"shock_nova":
			var before: float = float(_skill_runtime.remaining(_nova_skill.skill_id))
			cast_nova()
			return _skill_runtime.remaining(_nova_skill.skill_id) > before
		_:
			hud.announce("%s 尚未接上施放邏輯" % skill_name(gem_id))
			return false

func _cast_ember_bolt_skill() -> bool:
	if _skill_runtime == null or not is_instance_valid(player):
		return false
	if socket_gems.is_empty() or str(socket_gems[0]) != "ember_bolt":
		_skill_blocked("missing_gem", "燼焰彈", 3)
		return false
	_skill_runtime.mana = player.mana
	var result: Dictionary = _skill_runtime.cast(_bolt_skill, player.global_position, aim_direction, [])
	if not bool(result.get("ok", false)):
		_skill_blocked(str(result.get("reason", "")), "燼焰彈", 3)
		return false
	player.mana = _skill_runtime.mana
	var gem_mods: Dictionary = GemRules.modifiers(socket_gems)
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
		var projectile = Phase7Projectile.new()
		projectile.initialize(self, direction, 0, false, int(gem_mods.get("pierce_count", 0)))
		projectile.configure(_skill_runtime, _bolt_skill, on_hit_mods)
		projectile.max_distance = float(spawn["max_distance"])
		projectile.position = player.global_position + direction * 0.83 + Vector3(0, 0.1, 0)
		projectile.add_to_group("projectiles")
		add_child(projectile)
	spawn_burst(player.global_position + aim_direction * 0.8, Color("#f7a756"), 0.43)
	_sync_cooldowns()
	return true

func _load_progress() -> void:
	super._load_progress()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	if data.get("installed_active_gems") is Array:
		installed_active_gems = data["installed_active_gems"].duplicate()
	if data.get("skill_slots") is Array and data["skill_slots"].size() == 6:
		skill_slots = data["skill_slots"].duplicate()
	_sanitize_skill_slots()

func _sanitize_skill_slots() -> void:
	var installed := installed_skill_gems()
	var seen: Array = []
	for i in range(6):
		var gem_id := str(skill_slots[i])
		if gem_id == "" or not (gem_id in installed) or gem_id in seen:
			skill_slots[i] = ""
		else:
			seen.append(gem_id)

func save_progress() -> void:
	super.save_progress()
	var data: Dictionary = {}
	if FileAccess.file_exists(SAVE_PATH):
		var read_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if read_file != null:
			var parsed = JSON.parse_string(read_file.get_as_text())
			if parsed is Dictionary:
				data = parsed
	data["version"] = maxi(2, int(data.get("version", 1)))
	data["installed_active_gems"] = installed_active_gems
	data["skill_slots"] = skill_slots
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))

func interaction_hint() -> String:
	return super.interaction_hint().replace("[E]", "[F]").replace("按 E", "按 F")

func _build_camp() -> void:
	super._build_camp()
	_replace_world_interact_labels()

func _build_field() -> void:
	super._build_field()
	_replace_world_interact_labels()

func _replace_world_interact_labels() -> void:
	for child in _zone_art.get_children():
		if child is Label3D:
			child.text = child.text.replace("[E]", "[F]").replace("按 E", "按 F")

func enemy_died(at: Vector3, boss: bool) -> void:
	super.enemy_died(at, boss)
	if boss and is_instance_valid(hud):
		hud.announce("首領已擊敗！拾取戰利品，回傳送門按 F。")
