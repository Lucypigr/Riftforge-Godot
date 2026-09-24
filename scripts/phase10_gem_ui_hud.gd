extends "res://scripts/phase7_hud.gd"
## Integrated ARPG equipment/socket/backpack UI. Equipment is above the 18x10 bag.
const Grid10 = preload("res://scripts/grid_inventory.gd")
const GemRules10 = preload("res://scripts/gem_rules.gd")
const GemGridView = preload("res://scripts/phase10_gem_grid_view.gd")
const EquipmentSocketView = preload("res://scripts/phase10_equipment_socket_view.gd")
const FONT_PATH := "res://fonts/NotoSansTC.ttf"
const POE_PANEL_SIZE := Vector2(1110, 690)

var _equipment_socket_view
var _gem_detail: RichTextLabel
var _carry_source: Dictionary = {}
var _mode_label: Label
var _font: Font

func initialize(owner_game) -> void:
	super.initialize(owner_game)
	_apply_shared_font_theme()

func _apply_shared_font_theme() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as Font
	if _font == null:
		_font = ThemeDB.fallback_font
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 15
	_root.theme = theme
	if _gem_detail != null:
		_gem_detail.add_theme_font_override("normal_font", _font)
		_gem_detail.add_theme_font_override("bold_font", _font)

func _build_inventory() -> void:
	_inventory_panel = _panel(-555, -345, 555, 345, true)
	_inventory_panel.visible = false
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#0e1117")
	frame.border_color = Color("#9b7c4e")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(5)
	frame.content_margin_left = 12
	frame.content_margin_right = 12
	frame.content_margin_top = 10
	frame.content_margin_bottom = 10
	_inventory_panel.add_theme_stylebox_override("panel", frame)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	_inventory_panel.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	outer.add_child(header)
	var title := _label("角色裝備・插槽・寶石・背包", 22)
	title.add_theme_color_override("font_color", Color("#dfbd81"))
	header.add_child(title)
	var stretch := Control.new()
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(stretch)
	_mode_label = _label("裝備 / 背包", 14)
	_mode_label.add_theme_color_override("font_color", Color("#b9c6cb"))
	header.add_child(_mode_label)
	_equip_button = Button.new()
	_equip_button.text = "裝備所選"
	_equip_button.custom_minimum_size = Vector2(112, 38)
	_equip_button.pressed.connect(_equip_selected)
	header.add_child(_equip_button)
	_tidy_button = Button.new()
	_tidy_button.text = "整理"
	_tidy_button.custom_minimum_size = Vector2(72, 38)
	_tidy_button.pressed.connect(_repack)
	header.add_child(_tidy_button)
	var close := Button.new()
	close.text = "關閉"
	close.custom_minimum_size = Vector2(72, 38)
	close.pressed.connect(close_panels)
	header.add_child(close)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	_bag_page = VBoxContainer.new()
	_bag_page.name = "IntegratedEquipmentAndBag"
	_bag_page.custom_minimum_size = Vector2(772, 610)
	_bag_page.add_theme_constant_override("separation", 5)
	body.add_child(_bag_page)

	_bag_page.add_child(_label("角色裝備", 16))
	_equipment_socket_view = EquipmentSocketView.new()
	_equipment_socket_view.name = "EquipmentSocketView"
	_equipment_socket_view.socket_pressed.connect(_on_socket_pressed)
	_equipment_socket_view.gem_drop_requested.connect(_on_equipment_drop)
	_bag_page.add_child(_equipment_socket_view)

	var bag_row := HBoxContainer.new()
	_bag_page.add_child(bag_row)
	_page_label = _label("18 × 10 背包", 16)
	bag_row.add_child(_page_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_row.add_child(spacer)
	_grid_status = _label("", 14)
	_grid_status.add_theme_color_override("font_color", Color("#c7b38d"))
	bag_row.add_child(_grid_status)

	_grid_view = GemGridView.new()
	_grid_view.custom_minimum_size = Vector2(756, 420)
	_grid_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid_view.cell_pressed.connect(_on_grid_cell)
	_grid_view.gem_drop_to_bag.connect(_on_gem_drop_to_bag)
	_bag_page.add_child(_grid_view)

	_item_details = _label("", 14)
	_item_details.custom_minimum_size = Vector2(0, 34)
	_item_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_details.add_theme_color_override("font_color", Color("#e7d4ac"))
	_item_details.visible = false
	_bag_page.add_child(_item_details)

	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(300, 610)
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color("#121820")
	detail_style.border_color = Color("#514838")
	detail_style.set_border_width_all(1)
	detail_style.content_margin_left = 10
	detail_style.content_margin_right = 10
	detail_style.content_margin_top = 8
	detail_style.content_margin_bottom = 8
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	body.add_child(detail_panel)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 7)
	detail_panel.add_child(detail_box)
	detail_box.add_child(_label("技能資訊 / 寶石資訊", 18))
	_gem_detail = RichTextLabel.new()
	_gem_detail.name = "GemDetail"
	_gem_detail.bbcode_enabled = false
	_gem_detail.fit_content = false
	_gem_detail.scroll_active = true
	_gem_detail.custom_minimum_size = Vector2(278, 500)
	_gem_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_gem_detail)
	var return_button := Button.new()
	return_button.text = "將選中插槽寶石取回背包"
	return_button.pressed.connect(_return_selected_socket_gem)
	detail_box.add_child(return_button)
	detail_box.add_child(_label("手機：點寶石 → 點插槽；點插槽寶石 → 點背包空格。\nPC：直接拖曳寶石。", 12))

	# Compatibility fields remain alive for existing Phase 8 regressions but are
	# not separate user-facing pages anymore.
	_equipment_page = VBoxContainer.new()
	_equipment_page.visible = false
	_equipment_page.custom_minimum_size = Vector2.ZERO
	_inventory_panel.add_child(_equipment_page)
	_bag_tab_button = Button.new()
	_equipment_tab_button = Button.new()
	_prev_button = Button.new()
	_next_button = Button.new()
	_overflow_choices = OptionButton.new()
	_weapon_button = Button.new()
	_armor_button = Button.new()
	_equipment_details = _label("", 14)
	for node in [_bag_tab_button, _equipment_tab_button, _prev_button, _next_button, _overflow_choices, _weapon_button, _armor_button, _equipment_details]:
		node.visible = false
		_equipment_page.add_child(node)

	_refresh_inventory()

func _build_gems() -> void:
	# G opens the exact same integrated equipment/socket/backpack surface.
	_gems_panel = _inventory_panel

func toggle_inventory() -> void:
	var should_open := not _inventory_panel.visible
	close_panels()
	if should_open:
		inventory_open = true
		_inventory_panel.visible = true
		_mode_label.text = "裝備 / 背包"
		game.ui_open = true
		_refresh_inventory()

func toggle_gems() -> void:
	var should_open := not _inventory_panel.visible
	close_panels()
	if should_open:
		gems_open = true
		_inventory_panel.visible = true
		_mode_label.text = "寶石 / 插槽"
		game.ui_open = true
		_refresh_inventory()

func close_panels() -> void:
	inventory_open = false
	gems_open = false
	if _inventory_panel != null:
		_inventory_panel.visible = false
	game.ui_open = false
	_carry_source.clear()

func _open_bag() -> void:
	_active_tab = 0
	_bag_page.visible = true
	_equipment_page.visible = false
	_refresh_inventory()

func _open_equipment() -> void:
	_active_tab = 1
	_bag_page.visible = true
	_equipment_page.visible = true
	_refresh_inventory()

func _show_tab(_target: int) -> void:
	# Compatibility: visually remain on the integrated surface.
	_open_bag()

func _refresh_inventory() -> void:
	if game == null or _grid_view == null:
		return
	if _selected_index >= game.inventory.size():
		_selected_index = -1
	_grid_view.show_items(game.inventory, _selected_index, 0)
	var cells := Grid10.occupied_cells(game.inventory)
	_grid_status.text = "%d / %d 格｜%d 件" % [cells, Grid10.COLS * Grid10.ROWS, game.inventory.size()]
	var weapon: Dictionary = game.equipment.get("weapon", {})
	var armor: Dictionary = game.equipment.get("armor", {})
	_weapon_button.text = "武器｜%s" % str(weapon.get("name", "空"))
	_armor_button.text = "護甲｜%s" % str(armor.get("name", "空"))
	_equipment_socket_view.show_equipment(game.equipment, str(_carry_source.get("equipment_slot", "")), int(_carry_source.get("socket_index", -1)))
	_update_selection()
	if _carry_source.is_empty() and _selected_index < 0:
		_gem_detail.text = "選擇裝備插槽或背包中的寶石以查看：\n名稱、顏色、主動/輔助、Tags、等級、支援效果與最終技能資訊。"

func _update_selection() -> void:
	var has_selection := _selected_index >= 0 and _selected_index < game.inventory.size()
	_item_details.visible = has_selection
	_equip_button.disabled = not has_selection or str(game.inventory[_selected_index].get("slot", "")) == "gem" if has_selection else true
	if not has_selection:
		_item_details.text = ""
		return
	var item: Dictionary = game.inventory[_selected_index]
	if str(item.get("slot", "")) == "gem":
		var gem_id := str(item.get("gem_id", ""))
		_item_details.text = "%s｜背包寶石｜拖到上方裝備插槽" % GemRules10.display_name(gem_id)
		_gem_detail.text = game.gem_tooltip(gem_id)
	else:
		var shape := Grid10.footprint(item)
		_item_details.text = "%s [%s]｜%d×%d 格｜傷害 +%s　生命 +%s　護甲 %s%%" % [
			str(item.get("name", "物品")), str(item.get("rarity", "普通")), shape.x, shape.y,
			str(item.get("damage", 0)), str(item.get("hp", 0)), str(int(float(item.get("armor", 0.0)) * 100.0))
		]
		_gem_detail.text = "裝備資訊\n%s\n類型：%s\n傷害 +%s\n生命 +%s\n護甲 %s%%" % [
			str(item.get("name", "物品")), str(item.get("slot", "")), str(item.get("damage", 0)),
			str(item.get("hp", 0)), str(int(float(item.get("armor", 0.0)) * 100.0))
		]

func _on_grid_cell(x: int, y: int) -> void:
	var hit := Grid10.item_at(game.inventory, x, y)
	if str(_carry_source.get("kind", "")) == "socket_gem" and hit < 0:
		if game.move_socket_gem_to_inventory(str(_carry_source["equipment_slot"]), int(_carry_source["socket_index"]), x, y):
			_carry_source.clear()
			_selected_index = -1
		_refresh_inventory()
		return
		announce(game.last_gem_error)
		return
	if hit >= 0:
		_selected_index = hit
		var item: Dictionary = game.inventory[hit]
		if str(item.get("slot", "")) == "gem" and GemRules10.is_gem(str(item.get("gem_id", ""))):
			_carry_source = {"kind": "inventory_gem", "inventory_index": hit, "gem_id": str(item["gem_id"])}
		else:
			_carry_source.clear()
		_refresh_inventory()
		return
	if str(_carry_source.get("kind", "")) == "inventory_gem":
		var index := int(_carry_source.get("inventory_index", -1))
		if game.move_inventory_gem(index, x, y):
			_selected_index = index
		else:
			announce(game.last_gem_error)
	_refresh_inventory()

func _on_socket_pressed(slot: String, socket_index: int) -> void:
	var carry_kind := str(_carry_source.get("kind", ""))
	if carry_kind == "inventory_gem":
		if game.insert_inventory_gem(int(_carry_source.get("inventory_index", -1)), slot, socket_index):
			_carry_source.clear()
			_selected_index = -1
		else:
			announce(game.last_gem_error)
		_refresh_inventory()
		return
	if carry_kind == "socket_gem":
		if game.move_socket_gem(str(_carry_source.get("equipment_slot", "")), int(_carry_source.get("socket_index", -1)), slot, socket_index):
			_carry_source.clear()
		else:
			announce(game.last_gem_error)
		_refresh_inventory()
		return
	var gem_id := game.socket_gem(slot, socket_index)
	if not gem_id.is_empty():
		_carry_source = {"kind": "socket_gem", "equipment_slot": slot, "socket_index": socket_index, "gem_id": gem_id}
		_selected_index = -1
		_gem_detail.text = game.gem_tooltip(gem_id)
	else:
		_carry_source.clear()
		_selected_index = -1
		var item: Dictionary = game.equipment_socket_item(slot)
		var colors: Array = item.get("socket_colors", [])
		var links: Array = item.get("socket_links", [])
		var color := str(colors[socket_index]) if socket_index < colors.size() else "未知"
		_gem_detail.text = "插槽資訊\n裝備：%s\n插槽：%d\n顏色：%s\n連線：%s\n未連線的輔助寶石不會生效。" % [slot, socket_index + 1, color, str(links)]
	_refresh_inventory()

func _on_equipment_drop(data: Dictionary, slot: String, socket_index: int) -> void:
	var ok := false
	match str(data.get("kind", "")):
		"inventory_gem":
			ok = game.insert_inventory_gem(int(data.get("inventory_index", -1)), slot, socket_index)
		"socket_gem":
			ok = game.move_socket_gem(str(data.get("equipment_slot", "")), int(data.get("socket_index", -1)), slot, socket_index)
	if not ok:
		announce(game.last_gem_error)
	_carry_source.clear()
	_selected_index = -1
	_refresh_inventory()

func _on_gem_drop_to_bag(data: Dictionary, x: int, y: int) -> void:
	var ok := false
	match str(data.get("kind", "")):
		"socket_gem":
			ok = game.move_socket_gem_to_inventory(str(data.get("equipment_slot", "")), int(data.get("socket_index", -1)), x, y)
		"inventory_gem":
			ok = game.move_inventory_gem(int(data.get("inventory_index", -1)), x, y)
	if not ok:
		announce(game.last_gem_error)
	_carry_source.clear()
	_selected_index = -1
	_refresh_inventory()

func _return_selected_socket_gem() -> void:
	if str(_carry_source.get("kind", "")) != "socket_gem":
		announce("請先選擇裝備插槽中的寶石")
		return
	if game.move_socket_gem_to_inventory(str(_carry_source.get("equipment_slot", "")), int(_carry_source.get("socket_index", -1))):
		_carry_source.clear()
	else:
		announce(game.last_gem_error)
	_refresh_inventory()

func _equip_selected() -> void:
	if _selected_index < 0 or _selected_index >= game.inventory.size():
		announce("請先選擇一件裝備")
		return
	if str(game.inventory[_selected_index].get("slot", "")) == "gem":
		announce("寶石請直接拖曳或點選到裝備插槽")
		return
	game.equip_item(_selected_index)
	_selected_index = -1
	_carry_source.clear()
	_refresh_inventory()

func _repack() -> void:
	for i in range(game.inventory.size()):
		var item: Dictionary = game.inventory[i]
		item["grid_x"] = -1
		item["grid_y"] = -1
		game.inventory[i] = item
	var extra := Grid10.normalize(game.inventory)
	_selected_index = -1
	_carry_source.clear()
	game.save_progress()
	_refresh_inventory()
	announce("背包已整理" if extra == 0 else "已整理；仍有 %d 件物品無法放入" % extra)

func _inspect_equipped(slot: String) -> void:
	_inspected_slot = slot
	var item: Dictionary = game.equipment.get(slot, {})
	_equipment_details.text = "%s｜%s" % ["武器" if slot == "weapon" else "護甲", str(item.get("name", "空"))]

func _process(delta: float) -> void:
	super._process(delta)
	if game == null:
		return
	for slot in range(_skill_buttons.size()):
		var gem_id := game.skill_gem(slot)
		_skill_buttons[slot].tooltip_text = game.skill_tooltip(gem_id)
