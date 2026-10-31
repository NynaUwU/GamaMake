class_name ContainerUI
extends CanvasLayer
## Baú/armário/caixote do mundo ([E] nele): só dá para RETIRAR. Clique num
## item = pega; "Pegar tudo" esvazia. (Para guardar coisas, construa um Baú com
## o martelo: StorageUI.) Com o item embaixo do mouse, o
## modelo 3D dele gira ao lado do nome. ESC, E ou Fechar saem.

const SLOT := Vector2(46, 46)

var player: Player
var key := ""
var table := "casa"
var title := "Baú"
var _chest_grid: GridContainer
var _spinner: ItemSpinner
var _name: Label


static func open_for(p: Node, key_: String, table_: String, title_: String) -> void:
	if not p is Player or p.is_puppet() or p.ui_blocked or ContainerManager.i == null:
		return
	var ui := ContainerUI.new()
	ui.player = p
	ui.key = key_
	ui.table = table_
	ui.title = title_
	p.get_parent().add_child(ui) # junto da cena principal (o pai do jogador)


func _ready() -> void:
	layer = 9
	player.ui_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	LegacyGUI.close_on_outside(self, close)
	var column := LegacyGUI.box(center, title, 300.0)
	_chest_grid = GridContainer.new()
	_chest_grid.columns = 6
	_chest_grid.add_theme_constant_override("h_separation", 4)
	_chest_grid.add_theme_constant_override("v_separation", 4)
	column.add_child(_chest_grid)
	var info := HBoxContainer.new()
	info.custom_minimum_size = Vector2(0, 46)
	column.add_child(info)
	_spinner = ItemSpinner.new(44)
	info.add_child(_spinner)
	_name = Label.new()
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	info.add_child(_name)
	var row := HBoxContainer.new()
	column.add_child(row)
	LegacyGUI.button(row, "Pegar tudo", _take_all).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ContainerManager.i.changed.connect(func(k: String): if k == key: _refresh())
	player.inventory.changed.connect(_refresh)
	ContainerManager.i.request("open", [key, table])
	Sfx.play("creak", -6.0, 1.0)
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	for child in _chest_grid.get_children():
		child.queue_free()
	var slots: Array = ContainerManager.i.slots_of(key)
	for k in ContainerManager.SLOTS:
		var slot: Dictionary = slots[k] if k < slots.size() else {}
		_chest_grid.add_child(_slot(slot, _take.bind(k)))


func _slot(slot: Dictionary, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = SLOT
	button.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = LegacyGUI.SLOT
	style.set_border_width_all(1)
	style.border_color = Color(0.42, 0.42, 0.44)
	var hover := style.duplicate() as StyleBoxFlat
	hover.border_color = Color(0.95, 0.85, 0.4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
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
			count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			count.position -= Vector2(14, 14)
			button.add_child(count)
		button.mouse_entered.connect(func():
			_spinner.show_item(slot.id)
			_name.text = "%s%s" % [ItemDB.display_name(slot.id), "  x%d" % slot.amount if slot.amount > 1 else ""])
		button.pressed.connect(action)
	return button


func _take(index: int) -> void:
	ContainerManager.i.request("take", [key, index])
	Sfx.play("pickup", -4.0)


func _take_all() -> void:
	var slots: Array = ContainerManager.i.slots_of(key)
	for k in slots.size():
		if not slots[k].is_empty():
			ContainerManager.i.request("take", [key, k])


func close() -> void:
	player.ui_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		close()
