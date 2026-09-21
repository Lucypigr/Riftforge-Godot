extends "res://scripts/hud.gd"
## Two distinct functional tabs: a 120-cell bag and a character equipment page.
const Grid = preload("res://scripts/grid_inventory.gd")
const GridView = preload("res://scripts/inventory_grid_view.gd")
const INVENTORY_PANEL_SIZE := Vector2(790, 650)
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
var _active_tab := 0
var _grid_page := 0
var _selected_index := -1
var _inspected_slot := "weapon"

func _build_inventory() -> void:
	_inventory_panel = _panel(-395, -325, 395, 325, true)
	_inventory_panel.visible = false
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	_inventory_panel.add_child(layout)
	layout.add_child(_label("角色管理｜背包與裝備分頁", 23))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	layout.add_child(tabs)
	_bag_tab_button = Button.new()
	_bag_tab_button.text = "背包（120 格）"
	_bag_tab_button.custom_minimum_size = Vector2(190, 48)
	_bag_tab_button.pressed.connect(_open_bag)
	tabs.add_child(_bag_tab_button)
	_equipment_tab_button = Button.new()
	_equipment_tab_button.text = "角色裝備"
	_equipment_tab_button.custom_minimum_size = Vector2(170, 48)
	_equipment_tab_button.pressed.connect(_open_equipment)
	tabs.add_child(_equipment_tab_button)
	var close_button := Button.new()
	close_button.text = "關閉"
	close_button.custom_minimum_size = Vector2(110, 48)
	close_button.pressed.connect(toggle_inventory)
	tabs.add_child(close_button)

	_bag_page = VBoxContainer.new()
	_bag_page.add_theme_constant_override("separation", 6)
	layout.add_child(_bag_page)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	_bag_page.add_child(navigation)
	_prev_button = Button.new()
	_prev_button.text = "◀ 上一頁"
	_prev_button.custom_minimum_size = Vector2(140, 40)
	_prev_button.pressed.connect(_previous_page)
	navigation.add_child(_prev_button)
	_page_label = _label("", 18)
	_page_label.custom_minimum_size = Vector2(180, 36)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation.add_child(_page_label)
	_next_button = Button.new()
	_next_button.text = "下一頁 ▶"
	_next_button.custom_minimum_size = Vector2(140, 40)
	_next_button.pressed.connect(_next_page)
	navigation.add_child(_next_button)
	_grid_view = GridView.new()
	_grid_view.custom_minimum_size = Vector2(624, 260)
	_grid_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bag_page.add_child(_grid_view)
	_grid_view.cell_pressed.connect(_on_grid_cell)
	_bag_page.add_child(_label("點物品選取，再點空格移動；切頁後也能移到另一頁。", 15))
	_item_details = _label("點選物品檢視屬性", 16)
	_item_details.custom_minimum_size = Vector2(0, 52)
	_item_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bag_page.add_child(_item_details)
	_grid_status = _label("", 15)
	_bag_page.add_child(_grid_status)
	_overflow_choices = OptionButton.new()
	_overflow_choices.visible = false
	_overflow_choices.item_selected.connect(_on_overflow_selected)
	_bag_page.add_child(_overflow_choices)
	var bag_actions := HBoxContainer.new()
	bag_actions.add_theme_constant_override("separation", 12)
	_bag_page.add_child(bag_actions)
	var equip_button := Button.new()
	equip_button.text = "裝備所選"
	equip_button.custom_minimum_size = Vector2(170, 46)
	equip_button.pressed.connect(_equip_selected)
	bag_actions.add_child(equip_button)
	var tidy_button := Button.new()
	tidy_button.text = "整理兩頁"
	tidy_button.custom_minimum_size = Vector2(170, 46)
	tidy_button.pressed.connect(_repack)
	bag_actions.add_child(tidy_button)

	_equipment_page = VBoxContainer.new()
	_equipment_page.add_theme_constant_override("separation", 18)
	layout.add_child(_equipment_page)
	_equipment_page.add_child(_label("目前穿戴｜與背包獨立顯示，換裝請至背包選擇物品。", 18))
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
	_equipment_details.custom_minimum_size = Vector2(0, 100)
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
	_page_label.text = "背包 %d / %d" % [_grid_page + 1, Grid.PAGE_COUNT]
	_prev_button.disabled = _grid_page <= 0
	_next_button.disabled = _grid_page >= Grid.PAGE_COUNT - 1
	var extra := Grid.overflow_count(game.inventory)
	var cells := Grid.occupied_cells(game.inventory)
	_grid_status.text = "佔用 %d / %d 格｜%d 件物品" % [cells, Grid.COLS * Grid.ROWS, game.inventory.size()]
	if extra > 0:
		_grid_status.text += "｜舊檔待整理 %d 件" % extra
	_overflow_choices.clear()
	for i in range(game.inventory.size()):
		var item: Dictionary = game.inventory[i]
		if not Grid.placed(item):
			_overflow_choices.add_item("舊檔溢出：%s" % str(item.get("name", "未知物品")), i)
	_overflow_choices.visible = extra > 0
	var weapon: Dictionary = game.equipment["weapon"]
	var armor: Dictionary = game.equipment["armor"]
	_equipment.text = "生命上限 %d｜目前僅有武器與護甲兩個已實作欄位" % int(game.player.max_hp)
	_weapon_button.text = "武器｜%s" % str(weapon.get("name", "未知"))
	_armor_button.text = "護甲｜%s" % str(armor.get("name", "未知"))
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
	_equipment_details.text = "%s｜%s [%s]\n傷害 +%s　生命 +%s　護甲 %s%%" % ["武器" if slot == "weapon" else "護甲", str(item.get("name", "未知")), str(item.get("rarity", "普通")), str(item.get("damage", 0)), str(item.get("hp", 0)), str(int(float(item.get("armor", 0.0)) * 100.0))]

func _update_selection() -> void:
	if _selected_index < 0 or _selected_index >= game.inventory.size():
		_item_details.text = "點物品檢視屬性，或切換到角色裝備頁面。"
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
	announce("兩頁已整理" if extra == 0 else "已整理；仍有 %d 件舊物品無法放入。" % extra)
