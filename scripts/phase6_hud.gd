extends "res://scripts/grid_hud.gd"
## Phase 6: visual HUD only; combat, inventory, gems and save data stay in their original systems.
const VitalOrb = preload("res://scripts/phase6_vital_orb.gd")
const Radar = preload("res://scripts/phase6_minimap.gd")
const WeaponRules = preload("res://research/phase5/weapon_rules.gd")

var _health_orb
var _mana_orb
var _radar
var _objective_panel: PanelContainer
var _skill_panel: PanelContainer
var _attack_button: Button
var _nova_button: Button
var _dash_status: Label
var _mobile_layout: bool = false

func _build_hud() -> void:
	# Child order retains the existing mobile adapter contract: children 1 and 2
	# are the desktop objective and shortcut panels, NEVER either vitality orb.
	_health_orb = VitalOrb.new()
	_health_orb.name = "HealthOrb"
	_health_orb.configure("生命", Color("#da2945"))
	_root.add_child(_health_orb)
	_hp = ProgressBar.new()
	_hp.visible = false
	_health_orb.add_child(_hp)
	_stats = _label("", 12)
	_stats.visible = false
	_health_orb.add_child(_stats)

	_objective_panel = _panel(18, 18, 338, 139)
	var objective_content := VBoxContainer.new()
	objective_content.add_theme_constant_override("separation", 5)
	_objective_panel.add_child(objective_content)
	var title := _label("RIFTFORGE  ·  遠征", 17)
	title.add_theme_color_override("font_color", Color("#dfbd81"))
	objective_content.add_child(title)
	_objectives = _label("", 13)
	_objectives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_content.add_child(_objectives)
	_hint = _label("", 12)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color("#f5cc84"))
	objective_content.add_child(_hint)

	_skill_panel = _panel(-295, -90, 295, -10, true)
	_skill_panel.anchor_top = 1.0
	_skill_panel.anchor_bottom = 1.0
	var shortcuts := HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 8)
	_skill_panel.add_child(shortcuts)
	_attack_button = _shortcut("左鍵  普攻", 122)
	_attack_button.pressed.connect(_on_attack_pressed)
	shortcuts.add_child(_attack_button)
	_nova_button = _shortcut("右鍵  震盪環", 123)
	_nova_button.pressed.connect(_on_nova_pressed)
	shortcuts.add_child(_nova_button)
	_dash_status = _label("Space\n閃避", 13)
	_dash_status.custom_minimum_size = Vector2(86, 45)
	_dash_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dash_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shortcuts.add_child(_dash_status)
	var bag := _shortcut("I  背包", 87)
	bag.pressed.connect(toggle_inventory)
	shortcuts.add_child(bag)
	var gems := _shortcut("G  寶石", 87)
	gems.pressed.connect(toggle_gems)
	shortcuts.add_child(gems)

	_mana_orb = VitalOrb.new()
	_mana_orb.name = "ManaOrb"
	_mana_orb.configure("魔力", Color("#2466d8"))
	_root.add_child(_mana_orb)
	_mana = ProgressBar.new()
	_mana.visible = false
	_mana_orb.add_child(_mana)

	_radar = Radar.new()
	_radar.name = "LiveMinimap"
	_radar.game = game
	_radar.anchor_left = 1.0
	_radar.anchor_right = 1.0
	_radar.anchor_top = 0.0
	_radar.anchor_bottom = 0.0
	_radar.offset_left = -174.0
	_radar.offset_right = -18.0
	_radar.offset_top = 18.0
	_radar.offset_bottom = 174.0
	_root.add_child(_radar)

	_notice = _label("", 21)
	_notice.anchor_left = 0.5
	_notice.anchor_right = 0.5
	_notice.offset_left = -290.0
	_notice.offset_right = 290.0
	_notice.offset_top = 177.0
	_notice.offset_bottom = 228.0
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_theme_color_override("font_color", Color("#ffdf9f"))
	_root.add_child(_notice)
	set_mobile_layout(false)

func _shortcut(title: String, min_width: float) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(min_width, 45)
	button.add_theme_font_size_override("font_size", 14)
	return button

func _position_orb(orb: Control, horizontal_anchor: float, vertical_anchor: float, x: float, y: float, diameter: float) -> void:
	orb.anchor_left = horizontal_anchor
	orb.anchor_right = horizontal_anchor
	orb.anchor_top = vertical_anchor
	orb.anchor_bottom = vertical_anchor
	orb.offset_left = x
	orb.offset_right = x + diameter
	orb.offset_top = y
	orb.offset_bottom = y + diameter

func set_mobile_layout(active: bool) -> void:
	_mobile_layout = active
	if _health_orb == null or _mana_orb == null:
		return
	if active:
		# Move status orbs ABOVE the touch zones. Bottom corners are reserved for
		# the left joystick and right-hand attack/dash/nova controls.
		_position_orb(_health_orb, 0.0, 0.0, 12.0, 10.0, 88.0)
		_position_orb(_mana_orb, 1.0, 0.0, -290.0, 10.0, 88.0)
	else:
		_position_orb(_health_orb, 0.0, 1.0, 12.0, -156.0, 144.0)
		_position_orb(_mana_orb, 1.0, 1.0, -156.0, -156.0, 144.0)
	_objective_panel.visible = not active
	_skill_panel.visible = not active
	_radar.visible = not active  # Touch menu buttons occupy the upper right.

func _on_attack_pressed() -> void:
	if game != null and not game.ui_open:
		game.cast_bolt()

func _on_nova_pressed() -> void:
	if game != null and not game.ui_open:
		game.cast_nova()

func _process(delta: float) -> void:
	super._process(delta)
	if game == null or not is_instance_valid(game.player):
		return
	_health_orb.set_values(game.player.hp, game.player.max_hp)
	_mana_orb.set_values(game.player.mana, game.player.max_mana)
	var melee: bool = WeaponRules.mode(game.equipment["weapon"]) == "melee"
	_attack_button.text = ("左鍵  斬擊" if melee else "左鍵  燼焰彈") if game._bolt_cd <= 0.0 else "普攻  %.1f" % game._bolt_cd
	_attack_button.disabled = game.ui_open or game._bolt_cd > 0.0 or (not melee and game.player.mana < 3.0)
	_nova_button.text = "右鍵  震盪環" if game._nova_cd <= 0.0 else "震盪環  %.1f" % game._nova_cd
	_nova_button.disabled = game.ui_open or game._nova_cd > 0.0 or game.player.mana < 25.0
	_dash_status.text = "Space\n閃避" if game.player.dash_cooldown <= 0.0 else "閃避\n%.1f 秒" % game.player.dash_cooldown
