extends "res://scripts/hud.gd"
## Grid is a gameplay state, not decorative slots; equip/move uses grid validation.
const Grid = preload("res://scripts/grid_inventory.gd")
const GridView = preload("res://scripts/inventory_grid_view.gd")
var _grid_view: Control
var _grid_status: Label
var _overflow_choices: OptionButton
var _selected_index := -1

func _build_inventory() -> void:
	_inventory_panel = _panel(-265, -237, 265, 237, true)
	_inventory_panel.visible = false
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	_inventory_panel.add_child(layout)
	layout.add_child(_label("背包｜12 × 5 格", 22))
	_equipment = _label("", 15)
	layout.add_child(_equipment)
	_grid_view = GridView.new()
	_grid_view.custom_minimum_size = Vector2(444, 185)
	layout.add_child(_grid_view)
	_grid_view.cell_pressed.connect(_on_grid_cell)
	layout.add_child(_label("點物品選取，再點空格移動；格子不足無法拾取。", 13))
	_item_details = _label("點選物品檢視屬性", 14)
	_item_details.custom_minimum_size = Vector2(0, 43)
	_item_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_item_details)
	_grid_status = _label("", 13)
	layout.add_child(_grid_status)
	_overflow_choices = OptionButton.new()
	_overflow_choices.visible = false
	_overflow_choices.item_selected.connect(_on_overflow_selected)
	layout.add_child(_overflow_choices)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	layout.add_child(actions)
	var equip_button := Button.new()
	equip_button.text = "裝備所選"
	equip_button.pressed.connect(_equip_selected)
	actions.add_child(equip_button)
	var tidy_button := Button.new()
	tidy_button.text = "整理格子"
	tidy_button.pressed.connect(_repack)
	actions.add_child(tidy_button)
	var close_button := Button.new()
	close_button.text = "關閉"
	close_button.pressed.connect(toggle_inventory)
	actions.add_child(close_button)

func _refresh_inventory() -> void:
	if game == null:
		return
	if _selected_index >= game.inventory.size():
		_selected_index = -1
	_equipment.text = "武器：%s｜護甲：%s" % [game.equipment["weapon"]["name"], game.equipment["armor"]["name"]]
	_grid_view.show_items(game.inventory, _selected_index)
	var extra := Grid.overflow_count(game.inventory)
	_grid_status.text = "物品 %d 件｜未能放入格子的舊物品 %d 件" % [game.inventory.size(), extra] if extra > 0 else "物品 %d 件｜選取後可移動或裝備" % game.inventory.size()
	_overflow_choices.clear()
	for i in range(game.inventory.size()):
		var item: Dictionary = game.inventory[i]
		if not Grid.placed(item):
			_overflow_choices.add_item("舊檔溢出：%s" % str(item.get("name", "未知物品")), i)
	_overflow_choices.visible = extra > 0
	_update_selection()

func _update_selection() -> void:
	if _selected_index < 0 or _selected_index >= game.inventory.size():
		_item_details.text = "點選物品檢視屬性；點空格可移動已選物品。"
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
			game.save_progress()
		else:
			announce("放置失敗：超出邊界或與其他物品重疊。")
	_refresh_inventory()

func _on_overflow_selected(option: int) -> void:
	_selected_index = _overflow_choices.get_item_id(option)
	_refresh_inventory()

func _equip_selected() -> void:
	if _selected_index < 0:
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
	_selected_index = -1
	game.save_progress()
	_refresh_inventory()
	announce("格子已整理" if extra == 0 else "已整理；仍有 %d 件舊物品無法放入。" % extra)
