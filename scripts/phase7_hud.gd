extends "res://scripts/phase6_hud.gd"
## Phase 7 PC HUD: bottom center is icons only. Binding labels live in the gem config panel.
var _skill_buttons: Array[Button] = []
var _skill_pickers: Array[OptionButton] = []
var _rendered_gems: Array = ["__init__", "__init__", "__init__", "__init__", "__init__", "__init__"]

func _build_hud() -> void:
	super._build_hud()
	# Keep Phase 6 controls alive but hidden for regression compatibility.
	for child in _skill_panel.get_children():
		child.visible = false
	_skill_panel.offset_left = -230.0
	_skill_panel.offset_right = 230.0
	_skill_panel.offset_top = -82.0
	var bar := HBoxContainer.new()
	bar.name = "GemSkillHotbar"
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 9)
	_skill_panel.add_child(bar)
	for slot in range(6):
		var button := Button.new()
		button.name = "SkillSlot%d" % slot
		button.text = ""
		button.custom_minimum_size = Vector2(62, 58)
		button.expand_icon = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_skill_button_pressed.bind(slot))
		bar.add_child(button)
		_skill_buttons.append(button)

func _build_gems() -> void:
	_gems_panel = _panel(-330, -265, 330, 265, true)
	_gems_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_gems_panel.add_child(v)
	v.add_child(_label("技能寶石與快捷列", 22))
	v.add_child(_label("底部技能列只顯示圖示；此處決定每個 PC 施放鍵要使用哪顆已裝備主動寶石。", 14))
	v.add_child(_label("目前裝備主動寶石：燼焰彈、震盪環", 15))

	var assignment := GridContainer.new()
	assignment.columns = 2
	assignment.add_theme_constant_override("h_separation", 12)
	assignment.add_theme_constant_override("v_separation", 5)
	v.add_child(assignment)
	for slot in range(6):
		var binding := _label("", 15)
		binding.custom_minimum_size = Vector2(100, 32)
		assignment.add_child(binding)
		var picker := OptionButton.new()
		picker.custom_minimum_size = Vector2(235, 32)
		picker.item_selected.connect(_on_skill_picker_selected.bind(slot, picker))
		assignment.add_child(picker)
		_skill_pickers.append(picker)

	v.add_child(_label("燼焰彈連線輔助", 15))
	_scatter_box = CheckBox.new()
	_scatter_box.text = "分裂輔助 — 3 顆投射物，每顆傷害 ×0.78"
	v.add_child(_scatter_box)
	_pierce_box = CheckBox.new()
	_pierce_box.text = "穿透輔助 — 可再命中 1 隻敵人"
	v.add_child(_pierce_box)
	_scatter_box.toggled.connect(_on_scatter_toggled)
	_pierce_box.toggled.connect(_on_pierce_toggled)
	v.add_child(_label("輔助寶石只修改相容的連線主動技能，不會出現在快捷列。", 13))
	var close := Button.new()
	close.text = "完成 [G]"
	close.pressed.connect(toggle_gems)
	v.add_child(close)
	_refresh_skill_pickers()

func toggle_gems() -> void:
	super.toggle_gems()
	if gems_open:
		_refresh_skill_pickers()

func _refresh_skill_pickers() -> void:
	if game == null:
		return
	var installed: Array = game.installed_skill_gems()
	for slot in range(_skill_pickers.size()):
		var picker := _skill_pickers[slot]
		var label = picker.get_parent().get_child(slot * 2)
		if label is Label:
			label.text = game.skill_binding_name(slot)
		picker.clear()
		picker.add_item("空白")
		picker.set_item_metadata(0, "")
		var selected := 0
		for gem_id in installed:
			var index := picker.item_count
			picker.add_item(game.skill_name(str(gem_id)))
			picker.set_item_metadata(index, str(gem_id))
			if str(gem_id) == game.skill_gem(slot):
				selected = index
		picker.select(selected)

func _on_skill_picker_selected(option: int, slot: int, picker: OptionButton) -> void:
	if game == null or option < 0 or option >= picker.item_count:
		return
	var gem_id := str(picker.get_item_metadata(option))
	if game.assign_skill_slot(slot, gem_id):
		_rendered_gems[slot] = "__refresh__"
		_refresh_skill_pickers()

func _on_skill_button_pressed(slot: int) -> void:
	if game != null and not game.ui_open:
		game.cast_skill_slot(slot)

func _process(delta: float) -> void:
	super._process(delta)
	if game == null:
		return
	for slot in range(_skill_buttons.size()):
		var button := _skill_buttons[slot]
		var gem_id: String = game.skill_gem(slot)
		if str(_rendered_gems[slot]) != gem_id:
			_rendered_gems[slot] = gem_id
			button.icon = load(game.skill_icon(gem_id))
			button.tooltip_text = game.skill_name(gem_id) if gem_id != "" else "空技能槽"
		button.text = ""
		button.disabled = game.skill_slot_disabled(slot)
		button.modulate = Color(1, 1, 1, 0.48) if button.disabled and gem_id != "" else Color.WHITE
