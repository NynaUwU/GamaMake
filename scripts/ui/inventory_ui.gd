class_name InventoryUI
extends Control
## Hotbar (5 slots, sempre visível) e mochila (Tab). Na mochila, clique num
## slot e depois em outro para trocar os itens de lugar (ou juntar pilhas).
## Os slots mostram o ícone do item (ItemIcons); o nome e os detalhes aparecem
## numa janelinha que segue o mouse ao passar por cima.

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
var _tooltip: PanelContainer
var _tooltip_title: Label
var _tooltip_body: Label
var _hovered := -1


func setup(p: Node) -> void:
	player = p
	inventory = p.inventory
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hotbar()
	_build_backpack()
	_build_tooltip()
	var icons := get_node_or_null("/root/ItemIcons")
	if icons:
		icons.icons_ready.connect(_refresh)
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


func _process(_delta: float) -> void:
	if not _tooltip.visible:
		return
	# Segue o mouse, sem sair da tela.
	var screen := get_viewport_rect().size
	var pos := get_global_mouse_position() + Vector2(14, 14)
	var size := _tooltip.get_combined_minimum_size()
	pos.x = minf(pos.x, screen.x - size.x - 4)
	pos.y = minf(pos.y, screen.y - size.y - 4)
	_tooltip.global_position = pos


func _set_open(open: bool) -> void:
	_backpack.visible = open
	_picked = -1
	_hover(-1)
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
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_constant_override("icon_max_width", 44)
	button.set_meta("index", index)
	button.pressed.connect(_on_slot_pressed.bind(index))
	button.mouse_entered.connect(_hover.bind(index))
	button.mouse_exited.connect(func(): if _hovered == index: _hover(-1))
	# Número do slot (hotbar) no canto de cima e quantidade no canto de baixo.
	var number := Label.new()
	number.name = "Number"
	number.text = str(index + 1) if index < Inventory.HOTBAR_SIZE else ""
	number.add_theme_font_size_override("font_size", 10)
	number.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	number.position = Vector2(4, 1)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(number)
	var amount := Label.new()
	amount.name = "Amount"
	amount.add_theme_font_size_override("font_size", 11)
	amount.add_theme_color_override("font_outline_color", Color.BLACK)
	amount.add_theme_constant_override("outline_size", 3)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	amount.offset_left = -30
	amount.offset_top = -17
	amount.offset_right = -4
	amount.offset_bottom = -1
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(amount)
	return button


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.05, 0.94)
	style.set_border_width_all(1)
	style.border_color = Color(0.95, 0.85, 0.4, 0.8)
	style.set_content_margin_all(8)
	_tooltip.add_theme_stylebox_override("panel", style)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.top_level = true
	_tooltip.visible = false
	add_child(_tooltip)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	_tooltip.add_child(column)
	_tooltip_title = Label.new()
	_tooltip_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	column.add_child(_tooltip_title)
	_tooltip_body = Label.new()
	_tooltip_body.add_theme_font_size_override("font_size", 12)
	_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_body.custom_minimum_size = Vector2(220, 0)
	column.add_child(_tooltip_body)


## Mostra (ou esconde, com -1) a janela de detalhes do item do slot.
func _hover(index: int) -> void:
	_hovered = index
	if index < 0 or inventory.slots[index].is_empty() or not _backpack.visible:
		_tooltip.visible = false
		return
	var id: StringName = inventory.slots[index].id
	var item := ItemDB.def(id)
	_tooltip_title.text = item.name
	var lines: Array[String] = []
	if item.has("damage_type"):
		lines.append("Tipo de dano: %s" % item.damage_type)
		lines.append("Dano: %d" % item.damage)
		lines.append("Empurrão: %d" % item.knockback)
	else:
		lines.append({"tool": "Ferramenta", "material": "Material"}.get(item.kind, ""))
	if inventory.slots[index].amount > 1:
		lines.append("Quantidade: %d" % inventory.slots[index].amount)
	lines.append("")
	lines.append(ItemDB.description(id))
	_tooltip_body.text = "\n".join(lines)
	_tooltip.reset_size()
	_tooltip.visible = true
	_process(0.0)


func _on_slot_pressed(index: int) -> void:
	if _picked < 0:
		if not inventory.slots[index].is_empty():
			_picked = index
	else:
		inventory.swap(_picked, index)
		_picked = -1
	_refresh()
	_hover(index)


func _refresh() -> void:
	for slot in _hotbar_slots + _backpack_slots:
		var index: int = slot.get_meta("index")
		var item: Dictionary = inventory.slots[index]
		slot.text = ""
		var icons := get_node_or_null("/root/ItemIcons")
		slot.icon = icons.get_icon(item.id) if icons and not item.is_empty() else null
		var amount: Label = slot.get_node("Amount")
		amount.text = str(item.amount) if not item.is_empty() and item.amount > 1 else ""
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
