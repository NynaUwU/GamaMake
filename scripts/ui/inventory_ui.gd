class_name InventoryUI
extends Control
## Hotbar (5 slots, sempre visível) e mochila (Tab). Na mochila, clique num
## slot e depois em outro para trocar os itens de lugar (ou juntar pilhas).

const SLOT_SIZE := Vector2(52, 52)
const COLOR_SLOT := Color(0.06, 0.06, 0.06, 0.75)
const COLOR_SELECTED := Color(0.95, 0.85, 0.4, 1)
const COLOR_PICKED := Color(0.5, 0.8, 1.0, 1)

var player: Node
var inventory: Inventory
var _hotbar: HBoxContainer
var _backpack: PanelContainer
var _hotbar_slots: Array[Button] = []
var _backpack_slots: Array[Button] = [] # mochila + cópia da hotbar dentro do painel
var _picked := -1


func setup(p: Node) -> void:
	player = p
	inventory = p.inventory
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hotbar()
	_build_backpack()
	inventory.changed.connect(_refresh)
	inventory.selection_changed.connect(func(_i): _refresh())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		_set_open(not _backpack.visible)
		get_viewport().set_input_as_handled()
	elif _backpack.visible and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	_backpack.visible = open
	_picked = -1
	player.ui_blocked = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	_refresh()


func _build_hotbar() -> void:
	_hotbar = HBoxContainer.new()
	_hotbar.add_theme_constant_override("separation", 4)
	var width := SLOT_SIZE.x * Inventory.HOTBAR_SIZE + 4 * (Inventory.HOTBAR_SIZE - 1)
	_hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.offset_left = -width / 2.0
	_hotbar.offset_right = width / 2.0
	_hotbar.offset_top = -SLOT_SIZE.y - 12
	_hotbar.offset_bottom = -12
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hotbar)
	for i in Inventory.HOTBAR_SIZE:
		var slot := _make_slot(i)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotbar.add_child(slot)
		_hotbar_slots.append(slot)


func _build_backpack() -> void:
	_backpack = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.03, 0.88)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.4, 0.4)
	style.set_content_margin_all(10)
	_backpack.add_theme_stylebox_override("panel", style)
	_backpack.set_anchors_preset(Control.PRESET_CENTER)
	_backpack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_backpack.grow_vertical = Control.GROW_DIRECTION_BOTH
	_backpack.visible = false
	add_child(_backpack)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_backpack.add_child(column)
	var title := Label.new()
	title.text = "Mochila  (clique em dois slots para trocar)  [Tab] fechar"
	title.add_theme_font_size_override("font_size", 12)
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	for i in range(Inventory.HOTBAR_SIZE, Inventory.HOTBAR_SIZE + Inventory.BACKPACK_SIZE):
		var slot := _make_slot(i)
		grid.add_child(slot)
		_backpack_slots.append(slot)
	var hotbar_title := Label.new()
	hotbar_title.text = "Hotbar (1-5)"
	hotbar_title.add_theme_font_size_override("font_size", 12)
	column.add_child(hotbar_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	column.add_child(row)
	for i in Inventory.HOTBAR_SIZE:
		var slot := _make_slot(i)
		row.add_child(slot)
		_backpack_slots.append(slot)


func _make_slot(index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = SLOT_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 10)
	button.set_meta("index", index)
	button.pressed.connect(_on_slot_pressed.bind(index))
	return button


func _on_slot_pressed(index: int) -> void:
	if _picked < 0:
		if not inventory.slots[index].is_empty():
			_picked = index
	else:
		inventory.swap(_picked, index)
		_picked = -1
	_refresh()


func _refresh() -> void:
	for slot in _hotbar_slots + _backpack_slots:
		var index: int = slot.get_meta("index")
		var item: Dictionary = inventory.slots[index]
		var text := "%d\n" % (index + 1) if index < Inventory.HOTBAR_SIZE else "\n"
		if not item.is_empty():
			text += ItemDB.display_name(item.id)
			if item.amount > 1:
				text += " x%d" % item.amount
		slot.text = text
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_SLOT
		style.set_border_width_all(2)
		style.border_color = Color(0.3, 0.3, 0.3)
		if index == _picked:
			style.border_color = COLOR_PICKED
		elif index == inventory.selected and index < Inventory.HOTBAR_SIZE:
			style.border_color = COLOR_SELECTED
		for state in ["normal", "hover", "pressed"]:
			slot.add_theme_stylebox_override(state, style)
