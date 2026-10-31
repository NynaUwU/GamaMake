class_name StorageUI
extends CanvasLayer
## Baú construído pelo martelo ([E] nele). Em cima os 20 slots do baú, embaixo
## a sua mochila (hotbar + mochila). Igual ao inventário: segure num item e
## arraste até outro slot (baú <-> mochila, ou dentro de cada um) para mover,
## trocar ou juntar pilhas. Passando o mouse, o modelo 3D gira ao lado do nome.
## O baú é do mundo (o host guarda): todos veem o mesmo conteúdo e vai no save.

const SLOT := Vector2(36, 36)

var player: Player
var key := ""
var _chest_grid: GridContainer
var _bag_grid: GridContainer
var _hotbar_grid: GridContainer
var _spinner: ItemSpinner
var _name: Label
var _picked := {} # {"from": "chest"/"bag", "index": i} enquanto arrasta


static func open_for(p: Node, key_: String) -> void:
	if not p is Player or p.is_puppet() or p.ui_blocked or ContainerManager.i == null:
		return
	var ui := StorageUI.new()
	ui.player = p
	ui.key = key_
	p.get_parent().add_child(ui)


func _ready() -> void:
	layer = 9
	player.ui_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	LegacyGUI.close_on_outside(self, close)
	var column := LegacyGUI.box(center, "Baú", 230.0)
	_chest_grid = GridContainer.new()
	_chest_grid.columns = 7 # centralizado: quem define a largura é a mochila (9 colunas)
	_chest_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_chest_grid.add_theme_constant_override("h_separation", 4)
	_chest_grid.add_theme_constant_override("v_separation", 4)
	column.add_child(_chest_grid)
	var info := HBoxContainer.new()
	info.custom_minimum_size = Vector2(0, 36)
	column.add_child(info)
	_spinner = ItemSpinner.new(36)
	info.add_child(_spinner)
	_name = Label.new()
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	info.add_child(_name)
	var mine := Label.new()
	mine.text = "Mochila"
	mine.add_theme_font_size_override("font_size", 11)
	column.add_child(mine)
	# Mesmo formato do inventário: mochila 9x4 e a hotbar separada embaixo.
	_bag_grid = _player_grid(column)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	column.add_child(gap)
	_hotbar_grid = _player_grid(column)
	ContainerManager.i.changed.connect(func(k: String): if k == key: _refresh())
	player.inventory.changed.connect(_refresh)
	ContainerManager.i.request("open", [key, ""])
	Sfx.play("creak", -6.0, 1.0)
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	for child in _chest_grid.get_children():
		child.queue_free()
	for child in _bag_grid.get_children() + _hotbar_grid.get_children():
		child.queue_free()
	var slots: Array = ContainerManager.i.slots_of(key)
	for k in ContainerManager.STORAGE_SLOTS:
		_chest_grid.add_child(_slot("chest", k, slots[k] if k < slots.size() else {}))
	for k in player.inventory.slots.size():
		var grid := _hotbar_grid if k < Inventory.HOTBAR_SIZE else _bag_grid
		grid.add_child(_slot("bag", k, player.inventory.slots[k]))


func _player_grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = Inventory.HOTBAR_SIZE
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	return grid


func _slot(from: String, index: int, slot: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = SLOT
	button.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = LegacyGUI.SLOT
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.3)
	if _picked.get("from") == from and _picked.get("index") == index:
		style.border_color = InventoryUI.COLOR_PICKED
	elif from == "bag" and index < Inventory.HOTBAR_SIZE:
		style.border_color = Color(0.42, 0.42, 0.44)
	var hover := style.duplicate() as StyleBoxFlat
	hover.border_color = Color(0.95, 0.85, 0.4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	if from == "bag" and index < Inventory.HOTBAR_SIZE:
		var number := Label.new()
		number.text = str(index + 1)
		number.add_theme_font_size_override("font_size", 9)
		number.modulate = Color(1, 1, 1, 0.55)
		number.position = Vector2(3, 0)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(number)
	if not slot.is_empty():
		var icons := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("ItemIcons")
		if icons and icons.has_method("get_icon"):
			button.icon = icons.get_icon(slot.id)
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if slot.amount > 1:
			var count := Label.new()
			count.text = str(slot.amount)
			count.add_theme_font_size_override("font_size", 10)
			count.add_theme_color_override("font_outline_color", Color.BLACK)
			count.add_theme_constant_override("outline_size", 3)
			count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			count.position -= Vector2(16, 15)
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(count)
		button.mouse_entered.connect(func():
			_spinner.show_item(slot.id)
			_name.text = "%s%s" % [ItemDB.display_name(slot.id), "  x%d" % slot.amount if slot.amount > 1 else ""])
	button.set_drag_forwarding(_drag_from.bind(button, from, index, slot), _can_drop, _drop_on.bind(from, index))
	button.pressed.connect(func():
		if Input.is_key_pressed(KEY_SHIFT) and not slot.is_empty():
			_quick(from, index))
	return button


func _drag_from(_at: Vector2, button: Button, from: String, index: int, slot: Dictionary) -> Variant:
	if slot.is_empty():
		return null
	_picked = {"from": from, "index": index}
	var preview := TextureRect.new()
	preview.texture = button.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(36, 36)
	preview.position = -preview.size * 0.5
	preview.modulate = Color(1, 1, 1, 0.8)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var holder := Control.new()
	holder.add_child(preview)
	button.set_drag_preview(holder)
	return {"storage_slot": true, "from": from, "index": index}


func _can_drop(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("storage_slot")


func _drop_on(_at: Vector2, data: Variant, to: String, index: int) -> void:
	_picked = {}
	var from: String = data.from
	var src: int = data.index
	var manager := ContainerManager.i
	if from == "bag" and to == "bag":
		player.inventory.swap(src, index)
	elif from == "chest" and to == "chest":
		manager.request("swap", [key, src, index])
	elif from == "chest" and to == "bag":
		manager.request("take", [key, src, index])
		Sfx.play("pickup", -4.0)
	elif from == "bag" and to == "chest":
		var slot: Dictionary = player.inventory.slots[src]
		if slot.is_empty():
			return
		var moved := player.inventory.take(src, slot.amount)
		manager.request("put_at", [key, index, String(moved.id), moved.amount, moved.get("dur", 1.0)])
		Sfx.play("knock", -8.0, 1.0)
	_refresh()


## Shift + clique: manda o item direto para o outro lado (baú <-> mochila).
func _quick(from: String, index: int) -> void:
	var manager := ContainerManager.i
	if from == "chest":
		manager.request("take", [key, index])
		Sfx.play("pickup", -4.0)
		return
	var item: Dictionary = player.inventory.slots[index]
	var slots: Array = manager.slots_of(key)
	var target := -1
	for k in slots.size(): # pilha igual com espaço, senão o primeiro vazio
		if not slots[k].is_empty() and slots[k].id == item.id and slots[k].amount < ItemDB.max_stack(item.id):
			target = k
			break
	if target < 0:
		target = slots.find({})
	if target < 0:
		Sfx.play("click", -6.0, 0.6) # baú cheio
		return
	var moved := player.inventory.take(index, item.amount)
	manager.request("put_at", [key, target, String(moved.id), moved.amount, moved.get("dur", 1.0)])
	Sfx.play("knock", -8.0, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and not _picked.is_empty():
		_picked = {} # soltou fora de um slot: nada muda
		_refresh()


func close() -> void:
	player.ui_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		close()
