extends CanvasLayer

var game
var _root: Control
var _hp: ProgressBar
var _mana: ProgressBar
var _stats: Label
var _objectives: Label
var _hint: Label
var _notice: Label
var _inventory_panel: PanelContainer
var _inventory_list: ItemList
var _equipment: Label
var _item_details: Label
var _gems_panel: PanelContainer
var _scatter_box: CheckBox
var _pierce_box: CheckBox
var inventory_open := false
var gems_open := false
var _notice_time: float = 0.0

func initialize(owner_game) -> void:
	game = owner_game
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_hud()
	_build_inventory()
	_build_gems()

func _style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.032, 0.057, 0.086, 0.92)
	style.border_color = Color("#355a70")
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)

func _panel(x1: float, y1: float, x2: float, y2: float, centered: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if centered:
		panel.anchor_left = 0.5
		panel.anchor_right = 0.5
		panel.anchor_top = 0.5
		panel.anchor_bottom = 0.5
	panel.offset_left = x1
	panel.offset_top = y1
	panel.offset_right = x2
	panel.offset_bottom = y2
	_style(panel)
	_root.add_child(panel)
	return panel

func _label(text_value: String, size: int = 16) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("#edf5f5"))
	return label

func _build_hud() -> void:
	var left := _panel(16, 16, 382, 177)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	left.add_child(v)
	v.add_child(_label("RIFTFORGE   /   原創 ARPG 戰鬥試驗場", 17))
	_hp = ProgressBar.new()
	_hp.custom_minimum_size = Vector2(335, 20)
	_hp.show_percentage = false
	v.add_child(_hp)
	_mana = ProgressBar.new()
	_mana.custom_minimum_size = Vector2(335, 15)
	_mana.show_percentage = false
	v.add_child(_mana)
	_stats = _label("", 14)
	v.add_child(_stats)
	var right := _panel(-350, 16, -16, 133)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	var rv := VBoxContainer.new()
	right.add_child(rv)
	_objectives = _label("", 16)
	_objectives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(_objectives)
	var footer := _panel(-465, -105, 465, -14, true)
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	var fv := VBoxContainer.new()
	footer.add_child(fv)
	fv.add_child(_label("WASD 移動  |  滑鼠左鍵 燼焰彈  |  右鍵 震盪環  |  Space 閃避", 15))
	fv.add_child(_label("E 互動/拾取  |  I 背包  |  G 寶石配置  |  Esc 關閉面板", 15))
	_hint = _label("", 15)
	_hint.add_theme_color_override("font_color", Color("#f6ce83"))
	fv.add_child(_hint)
	_notice = _label("", 22)
	_notice.anchor_left = 0.5
	_notice.anchor_right = 0.5
	_notice.offset_left = -320
	_notice.offset_right = 320
	_notice.offset_top = 168
	_notice.offset_bottom = 216
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_color", Color("#ffe093"))
	_root.add_child(_notice)

func _build_inventory() -> void:
	_inventory_panel = _panel(-265, -237, 265, 237, true)
	_inventory_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_inventory_panel.add_child(v)
	v.add_child(_label("背包與裝備  /  選取物品後按裝備", 23))
	_equipment = _label("", 15)
	v.add_child(_equipment)
	_inventory_list = ItemList.new()
	_inventory_list.custom_minimum_size = Vector2(490, 265)
	_inventory_list.select_mode = ItemList.SELECT_SINGLE
	v.add_child(_inventory_list)
	_item_details = _label("選取物品以檢視屬性", 15)
	v.add_child(_item_details)
	_inventory_list.item_selected.connect(_on_item_selected)
	var buttons := HBoxContainer.new()
	v.add_child(buttons)
	var equip := Button.new()
	equip.text = "裝備所選物品"
	equip.pressed.connect(_equip_selected)
	buttons.add_child(equip)
	var close := Button.new()
	close.text = "關閉 [I]"
	close.pressed.connect(toggle_inventory)
	buttons.add_child(close)

func _build_gems() -> void:
	_gems_panel = _panel(-290, -176, 290, 176, true)
	_gems_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_gems_panel.add_child(v)
	v.add_child(_label("連線寶石  /  真正影響技能行為", 22))
	v.add_child(_label("[紅] 燼焰彈  ══ [綠] 輔助孔  ══ [藍] 輔助孔", 17))
	v.add_child(_label("主動：燼焰彈（火焰 / 投射物 / 法術）", 15))
	_scatter_box = CheckBox.new()
	_scatter_box.text = "綠孔：分裂輔助 — 3 顆投射物，每顆傷害 ×0.78"
	v.add_child(_scatter_box)
	_pierce_box = CheckBox.new()
	_pierce_box.text = "藍孔：穿透輔助 — 可再命中 1 隻敵人"
	v.add_child(_pierce_box)
	_scatter_box.toggled.connect(_on_scatter_toggled)
	_pierce_box.toggled.connect(_on_pierce_toggled)
	v.add_child(_label("輔助效果僅作用於連線且標籤相容的主動技能。", 14))
	var close := Button.new()
	close.text = "完成 [G]"
	close.pressed.connect(toggle_gems)
	v.add_child(close)

func toggle_inventory() -> void:
	if gems_open:
		_gems_panel.visible = false
		gems_open = false
	inventory_open = not inventory_open
	_inventory_panel.visible = inventory_open
	if inventory_open:
		_refresh_inventory()
	game.ui_open = inventory_open or gems_open

func toggle_gems() -> void:
	if inventory_open:
		_inventory_panel.visible = false
		inventory_open = false
	gems_open = not gems_open
	_gems_panel.visible = gems_open
	if gems_open:
		_scatter_box.set_pressed_no_signal(str(game.socket_gems[1]) == "scatter")
		_pierce_box.set_pressed_no_signal(str(game.socket_gems[2]) == "pierce")
	game.ui_open = inventory_open or gems_open

func close_panels() -> void:
	inventory_open = false
	gems_open = false
	_inventory_panel.visible = false
	_gems_panel.visible = false
	game.ui_open = false

func _on_scatter_toggled(pressed: bool) -> void:
	game.socket_gems[1] = "scatter" if pressed else ""
	game.save_progress()
	announce("分裂輔助：" + ("已安裝" if pressed else "已卸下"))

func _on_pierce_toggled(pressed: bool) -> void:
	game.socket_gems[2] = "pierce" if pressed else ""
	game.save_progress()
	announce("穿透輔助：" + ("已安裝" if pressed else "已卸下"))

func _refresh_inventory() -> void:
	_inventory_list.clear()
	_equipment.text = "武器：%s  |  護甲：%s" % [game.equipment["weapon"]["name"], game.equipment["armor"]["name"]]
	for item in game.inventory:
		_inventory_list.add_item("[%s] %s (%s)" % [item["rarity"], item["name"], item["slot"]])
	_item_details.text = "選擇物品以檢視屬性"

func _on_item_selected(index: int) -> void:
	if index < 0 or index >= game.inventory.size():
		return
	var item: Dictionary = game.inventory[index]
	_item_details.text = "%s｜傷害 +%s｜生命 +%s｜護甲 %s%%" % [item["name"], item["damage"], item["hp"], int(float(item["armor"]) * 100.0)]

func _equip_selected() -> void:
	var indexes: PackedInt32Array = _inventory_list.get_selected_items()
	if indexes.is_empty():
		return
	game.equip_item(int(indexes[0]))
	_refresh_inventory()

func announce(message: String) -> void:
	_notice.text = message
	_notice_time = 2.8

func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	if _notice_time > 0.0:
		_notice_time -= delta
		if _notice_time <= 0.0:
			_notice.text = ""
	_hp.max_value = game.player.max_hp
	_hp.value = maxf(0.0, game.player.hp)
	_mana.max_value = game.player.max_mana
	_mana.value = game.player.mana
	_stats.text = "生命 %d/%d   魔力 %d/%d   等級 %d   擊殺 %d" % [int(game.player.hp), int(game.player.max_hp), int(game.player.mana), int(game.player.max_mana), game.level, game.kills]
	if game.zone == "camp":
		_objectives.text = "營地 · 安全區\n靠近藍色傳送門按 E 開始刷圖。\nI 裝備、G 編輯寶石。"
	else:
		_objectives.text = "荒野 · 第 %d 次遠征\n進度 %d / %d   Boss %s\n地面戰利品：%d" % [game.runs, game.wave_kills, game.target_kills, ("已擊敗" if game.boss_defeated else ("出現" if game.boss_spawned else "未出現")), get_tree().get_nodes_in_group("loot").size()]
	_hint.text = game.interaction_hint()
