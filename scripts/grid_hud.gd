extends "res://scripts/hud.gd"
## Phase 8 compact ARPG layout: 180-cell dense grid and separate equipped-gear tab.
const Grid = preload("res://scripts/grid_inventory.gd")
const GridView = preload("res://scripts/inventory_grid_view.gd")
const INVENTORY_PANEL_SIZE := Vector2(860, 650)
var _grid_view: Control
var _grid_status: Label
var _overflow_choices: OptionButton
var _bag_page: VBoxContainer
var _equipment_page: VBoxContainer
var _bag_tab_button: Button
var _equipment_tab_button: Button
var _prev_button: Button
var _next_button: Button
var _page_label: Label
var _weapon_button: Button
var _armor_button: Button
var _equipment_details: Label
var _equip_button: Button
var _tidy_button: Button
var _active_tab := 0
var _grid_page := 0
var _selected_index := -1
var _inspected_slot := "weapon"

func _build_inventory() -> void:
	_inventory_panel = _panel(-430, -325, 430, 325, true)
	_inventory_panel.visible = false
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#11141b")
	frame.border_color = Color("#90724b")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(5)
	frame.content_margin_left = 12
	frame.content_margin_right = 12
	frame.content_margin_top = 9
	frame.content_margin_bottom = 9
	_inventory_panel.add_theme_stylebox_override("panel", frame)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	_inventory_panel.add_child(layout)
	var title := _label("戰利品｜背包與角色", 21)
	title.add_theme_color_override("font_color", Color("#d9b982"))
	layout.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	layout.add_child(tabs)
	_bag_tab_button = Button.new()
	_bag_tab_button.text = "背包"
	_bag_tab_button.custom_minimum_size = Vector2(125, 43)
	_bag_tab_button.pressed.connect(_open_bag)
	tabs.add_child(_bag_tab_button)
	_equipment_tab_button = Button.new()
	_equipment_tab_button.text = "角色裝備"
	_equipment_tab_button.custom_minimum_size = Vector2(140, 43)
	_equipment_tab_button.pressed.connect(_open_equipment)
	tabs.add_child(_equipment_tab_button)
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(filler)
	_equip_button = Button.new()
	_equip_button.text = "裝備所選"
	_equip_button.custom_minimum_size = Vector2(124, 43)
	_equip_button.pressed.connect(_equip_selected)
	tabs.add_child(_equip_button)
	_tidy_button = Button.new()
	_tidy_button.text = "整理"
	_tidy_button.custom_minimum_size = Vector2(90, 43)
	_tidy_button.pressed.connect(_repack)
	tabs.add_child(_tidy_button)
	var close_button := Button.new()
	close_button.text = "✕ 關閉"
	close_button.custom_minimum_size = Vector2(105, 43)
	close_button.pressed.connect(toggle_inventory)
	tabs.add_child(close_button)

	_bag_page = VBoxContainer.new()
	_bag_page.add_theme_constant_override("separation", 5)
	layout.add_child(_bag_page)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	_bag_page.add_child(navigation)
	_prev_button = Button.new()
	_prev_button.text = "◀"
	_prev_button.custom_minimum_size = Vector2(1, 1)
	_prev_button.visible = false
	_prev_button.pressed.connect(_previous_page)
	navigation.add_child(_prev_button)
	_page_label = _label("緊湊背包", 17)
	_page_label.custom_minimum_size = Vector2(150, 34)
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	navigation.add_child(_page_label)
	_next_button = Button.new()
	_next_button.text = "▶"
	_next_button.custom_minimum_size = Vector2(1, 1)
	_next_button.visible = false
	_next_button.pressed.connect(_next_page)
	navigation.add_child(_next_button)
	var nav_filler := Control.new()
	nav_filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(nav_filler)
	_grid_status = _label("", 15)
	_grid_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_grid_status.add_theme_color_override("font_color", Color("#c7b38d"))
	navigation.add_child(_grid_status)

	_grid_view = GridView.new()
	_grid_view.custom_minimum_size = Vector2(756, 420)
	_grid_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bag_page.add_child(_grid_view)
	_grid_view.cell_pressed.connect(_on_grid_cell)
	# Contextual details appear only on selection, rather than occupying a permanent footer.
	_item_details = _label("", 15)
	_item_details.custom_minimum_size = Vector2(0, 43)
	_item_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_details.add_theme_color_override("font_color", Color("#e7d4ac"))
	_item_details.visible = false
	_bag_page.add_child(_item_details)
	_overflow_choices = OptionButton.new()
	_overflow_choices.visible = false
	_overflow_choices.item_selected.connect(_on_overflow_selected)
	_bag_page.add_child(_overflow_choices)

	_equipment_page = VBoxContainer.new()
	_equipment_page.add_theme_constant_override("separation", 14)
	layout.add_child(_equipment_page)
	_equipment_page.add_child(_label("已裝備物品", 21))
	_equipment = _label("", 17)
	_equipment_page.add_child(_equipment)
	_weapon_button = Button.new()
	_weapon_button.custom_minimum_size = Vector2(580, 66)
	_weapon_button.pressed.connect(_inspect_weapon)
	_equipment_page.add_child(_weapon_button)
	_armor_button = Button.new()
	_armor_button.custom_minimum_size = Vector2(580, 66)
	_armor_button.pressed.connect(_inspect_armor)
	_equipment_page.add_child(_armor_button)
	_equipment_details = _label("", 18)
	_equipment_details.custom_minimum_size = Vector2(0, 90)
	_equipment_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equipment_page.add_child(_equipment_details)
	_bag_page.visible = true
	_equipment_page.visible = false
	_refresh_inventory()

func toggle_inventory() -> void:
	super.toggle_inventory()
	if inventory_open:
		_show_tab(0)

func _open_bag() -> void:
	_show_tab(0)

func _open_equipment() -> void:
	_show_tab(1)

func _show_tab(target: int) -> void:
	_active_tab = clampi(target, 0, 1)
	_bag_page.visible = _active_tab == 0
	_equipment_page.visible = _active_tab == 1
	_bag_tab_button.disabled = _active_tab == 0
	_equipment_tab_button.disabled = _active_tab == 1
	_equip_button.visible = _active_tab == 0
	_tidy_button.visible = _active_tab == 0
	_refresh_inventory()

func _previous_page() -> void:
	_set_grid_page(_grid_page - 1)

func _next_page() -> void:
	_set_grid_page(_grid_page + 1)

func _set_grid_page(next_page: int) -> void:
	_grid_page = clampi(next_page, 0, Grid.PAGE_COUNT - 1)
	_refresh_inventory()

func _refresh_inventory() -> void:
	if game == null or _grid_view == null:
		return
	if _selected_index >= game.inventory.size():
		_selected_index = -1
	_grid_view.show_items(game.inventory, _selected_index, _grid_page)
	_page_label.text = "18 × 10 緊湊背包"
	_prev_button.disabled = true
	_next_button.disabled = true
	var extra := Grid.overflow_count(game.inventory)
	var cells := Grid.occupied_cells(game.inventory)
	_grid_status.text = "%d / %d 格｜%d 件" % [cells, Grid.COLS * Grid.ROWS, game.inventory.size()]
	if extra > 0:
		_grid_status.text += "｜待整理 %d" % extra
	_overflow_choices.clear()
	for i in range(game.inventory.size()):
		var item: Dictionary = game.inventory[i]
		if not Grid.placed(item):
			_overflow_choices.add_item("舊檔溢出：%s" % str(item.get("name", "未知物品")), i)
	_overflow_choices.visible = extra > 0
	var weapon: Dictionary = game.equipment["weapon"]
	var armor: Dictionary = game.equipment["armor"]
	_equipment.text = "生命上限 %d｜新角色不預裝任何裝備" % int(game.player.max_hp)
	_weapon_button.text = "武器｜%s" % str(weapon.get("name", "空"))
	_armor_button.text = "護甲｜%s" % str(armor.get("name", "空"))
	_inspect_equipped(_inspected_slot)
	_update_selection()

func _inspect_weapon() -> void:
	_inspect_equipped("weapon")

func _inspect_armor() -> void:
	_inspect_equipped("armor")

func _inspect_equipped(slot: String) -> void:
	_inspected_slot = slot
	if game == null:
		return
	var item: Dictionary = game.equipment[slot]
	if str(item.get("name", "")).is_empty():
		_equipment_details.text = "%s｜空欄位\n從背包選擇掉落裝備後按「裝備所選」。" % ("武器" if slot == "weapon" else "護甲")
		return
	_equipment_details.text = "%s｜%s [%s]\n傷害 +%s　生命 +%s　護甲 %s%%" % ["武器" if slot == "weapon" else "護甲", str(item.get("name", "未知")), str(item.get("rarity", "普通")), str(item.get("damage", 0)), str(item.get("hp", 0)), str(int(float(item.get("armor", 0.0)) * 100.0))]

func _update_selection() -> void:
	var has_selection: bool = _selected_index >= 0 and _selected_index < game.inventory.size()
	_item_details.visible = has_selection and _active_tab == 0
	_equip_button.disabled = not has_selection
	if not has_selection:
		_item_details.text = ""
		return
	var item: Dictionary = game.inventory[_selected_index]
	var shape := Grid.footprint(item)
	_item_details.text = "%s [%s]｜%d×%d 格\n傷害 +%s　生命 +%s　護甲 %s%%" % [str(item.get("name", "物品")), str(item.get("rarity", "普通")), shape.x, shape.y, str(item.get("damage", 0)), str(item.get("hp", 0)), str(int(float(item.get("armor", 0.0)) * 100.0))]

func _on_grid_cell(x: int, y: int) -> void:
	var hit := Grid.item_at(game.inventory, x, y)
	if hit >= 0:
		_selected_index = hit
	elif _selected_index >= 0:
		if Grid.move(game.inventory, _selected_index, x, y):
			_grid_page = int(y / Grid.PAGE_ROWS)
			game.save_progress()
		else:
			announce("放置失敗：超出本頁範圍或與其他物品重疊。")
	_refresh_inventory()

func _on_overflow_selected(option: int) -> void:
	_selected_index = _overflow_choices.get_item_id(option)
	_refresh_inventory()

func _equip_selected() -> void:
	if _selected_index < 0 or _selected_index >= game.inventory.size():
		announce("請先選擇一件裝備。")
		return
	game.equip_item(_selected_index)
	_selected_index = -1
	_refresh_inventory()

func _repack() -> void:
	for i in range(game.inventory.size()):
		var item: Dictionary = game.inventory[i]
		item["grid_x"] = -1
		item["grid_y"] = -1
		game.inventory[i] = item
	var extra := Grid.normalize(game.inventory)
	_grid_page = 0
	_selected_index = -1
	game.save_progress()
	_refresh_inventory()
	announce("背包已整理" if extra == 0 else "已整理；仍有 %d 件舊物品無法放入。" % extra)
