extends "res://scripts/phase7_hud.gd"
## Phase 10 gem panel: active/support inventory, hotbar assignment and ResolvedSkill tooltips.
const GemSystem10 = preload("res://scripts/phase10_gem_system.gd")
const GEM_PANEL_SIZE := Vector2(780, 600)

var _gem_summary: RichTextLabel

func _build_gems() -> void:
	_gems_panel = _panel(-390, -300, 390, 300, true)
	_gems_panel.visible = false
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 7)
	_gems_panel.add_child(root_box)
	root_box.add_child(_label("Phase 10｜技能寶石與連線支援", 22))
	root_box.add_child(_label("Active 才能放入快捷列；Support 僅影響同一 Connected Group 且標籤相容的 Active。", 13))

	var assignment := GridContainer.new()
	assignment.columns = 2
	assignment.add_theme_constant_override("h_separation", 10)
	assignment.add_theme_constant_override("v_separation", 4)
	root_box.add_child(assignment)
	for slot in range(6):
		var binding := _label("", 14)
		binding.custom_minimum_size = Vector2(100, 30)
		assignment.add_child(binding)
		var picker := OptionButton.new()
		picker.custom_minimum_size = Vector2(250, 30)
		picker.item_selected.connect(_on_skill_picker_selected.bind(slot, picker))
		assignment.add_child(picker)
		_skill_pickers.append(picker)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(730, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(scroll)
	_gem_summary = RichTextLabel.new()
	_gem_summary.fit_content = true
	_gem_summary.custom_minimum_size = Vector2(700, 290)
	_gem_summary.scroll_active = false
	_gem_summary.add_theme_font_size_override("normal_font_size", 13)
	scroll.add_child(_gem_summary)

	var close := Button.new()
	close.text = "完成 [G]"
	close.pressed.connect(toggle_gems)
	root_box.add_child(close)
	_refresh_phase10_gems()

func toggle_gems() -> void:
	if inventory_open:
		_inventory_panel.visible = false
		inventory_open = false
	gems_open = not gems_open
	_gems_panel.visible = gems_open
	game.ui_open = inventory_open or gems_open
	if gems_open:
		_refresh_phase10_gems()

func _refresh_phase10_gems() -> void:
	if game == null:
		return
	_refresh_skill_pickers()
	if _gem_summary == null:
		return
	var active_lines: Array[String] = []
	var support_lines: Array[String] = []
	for instance in game.gem_instances:
		if not (instance is Dictionary):
			continue
		var gem_id: String = str(instance.get("gem_id", ""))
		var definition: Dictionary = GemSystem10.definition(gem_id)
		var tags: Array = definition.get("tags", [])
		var line: String = "%s Lv.%d｜%s｜%s｜%s" % [
			GemSystem10.display_name(gem_id),
			int(instance.get("level", 1)),
			str(definition.get("color", "")),
			str(definition.get("role", "")),
			", ".join(PackedStringArray(tags))
		]
		if GemSystem10.is_active(gem_id):
			active_lines.append(line + "\n" + GemSystem10.tooltip(game.resolved_skill(gem_id)).replace("\n", "｜"))
		else:
			var mod: Dictionary = definition.get("modifier_data", {})
			support_lines.append(line + "｜" + str(mod))
	_gem_summary.text = "ACTIVE GEMS\n" + "\n".join(active_lines) + "\n\nSUPPORT GEMS\n" + "\n".join(support_lines)

func _refresh_skill_pickers() -> void:
	if game == null:
		return
	var installed: Array = game.installed_skill_gems()
	for slot in range(_skill_pickers.size()):
		var picker: OptionButton = _skill_pickers[slot]
		var label = picker.get_parent().get_child(slot * 2)
		if label is Label:
			label.text = game.skill_binding_name(slot)
		picker.clear()
		picker.add_item("空白")
		picker.set_item_metadata(0, "")
		var selected: int = 0
		for gem_id in installed:
			var index: int = picker.item_count
			picker.add_item(game.skill_name(str(gem_id)))
			picker.set_item_metadata(index, str(gem_id))
			if str(gem_id) == game.skill_gem(slot):
				selected = index
		picker.select(selected)
		var current: String = game.skill_gem(slot)
		picker.tooltip_text = game.skill_tooltip(current) if not current.is_empty() else "空技能槽"

func _on_skill_picker_selected(option: int, slot: int, picker: OptionButton) -> void:
	if game == null or option < 0 or option >= picker.item_count:
		return
	var gem_id: String = str(picker.get_item_metadata(option))
	if game.assign_skill_slot(slot, gem_id):
		_rendered_gems[slot] = "__refresh__"
		_refresh_phase10_gems()

func _process(delta: float) -> void:
	super._process(delta)
	if game == null:
		return
	for slot in range(_skill_buttons.size()):
		var gem_id: String = game.skill_gem(slot)
		_skill_buttons[slot].tooltip_text = game.skill_tooltip(gem_id) if not gem_id.is_empty() else "空技能槽"
