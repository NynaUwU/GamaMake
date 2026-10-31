class_name InventoryUI
extends Control
## Hotbar (9 slots, sempre visível) e mochila (Tab): em cima o personagem com
## os 4 slots de roupa/armadura e o crafting de mão; embaixo a mochila 9x4 e a
## hotbar. Arraste um item até outro slot para trocar/juntar (ou até a roupa
## para vestir). Shift + clique transfere rápido (hotbar <-> mochila; roupa
## veste/tira).
## Os slots mostram o ícone do item (ItemIcons); o nome e os detalhes aparecem
## numa janelinha que segue o mouse ao passar por cima.

const SLOT_SIZE := Vector2(46, 46) ## hotbar da tela (9 slots)
const BAG_SLOT := Vector2(40, 40) ## slots dentro da mochila
const EQUIP_ICONS := {"head": "Cab", "body": "Corpo", "legs": "Pern", "feet": "Pés"}
const COLOR_SLOT := LegacyGUI.SLOT
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
var _spinner: ItemSpinner
var _hovered := -1
var _preview: CharacterPreview
var _equip_slots: Array[Button] = []
var _picked_equip := ""
var _showing_controls := false


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
	# Shift mostra os controles do item (solta: volta para a descrição).
	if Input.is_key_pressed(KEY_SHIFT) != _showing_controls:
		_hover(_hovered)
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
	style.bg_color = LegacyGUI.BG
	style.set_border_width_all(1)
	style.border_color = LegacyGUI.BG_BORDER
	style.set_content_margin_all(8)
	_backpack.add_theme_stylebox_override("panel", style)
	_backpack.set_anchors_preset(Control.PRESET_CENTER)
	_backpack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_backpack.grow_vertical = Control.GROW_DIRECTION_BOTH
	_backpack.visible = false
	add_child(_backpack)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_backpack.add_child(column)
	# Em cima: o personagem com as roupas/armaduras e o crafting de mão.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	column.add_child(top)
	_preview = CharacterPreview.new()
	top.add_child(_preview)
	var equip := VBoxContainer.new()
	equip.add_theme_constant_override("separation", 3)
	top.add_child(equip)
	for slot_name in Inventory.EQUIP_SLOTS:
		var button := _make_equip_slot(slot_name)
		equip.add_child(button)
		_equip_slots.append(button)
	var craft := RecipeGrid.new()
	craft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(craft)
	craft.setup(player, "mao", 4, 118.0)
	# Mochila 9x4 e a hotbar (1-9) embaixo.
	var grid := GridContainer.new()
	grid.columns = Inventory.HOTBAR_SIZE
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	column.add_child(grid)
	for i in range(Inventory.HOTBAR_SIZE, Inventory.HOTBAR_SIZE + Inventory.BACKPACK_SIZE):
		var slot := _make_slot(i, BAG_SLOT)
		grid.add_child(slot)
		_backpack_slots.append(slot)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	column.add_child(row)
	for i in Inventory.HOTBAR_SIZE:
		var slot := _make_slot(i, BAG_SLOT)
		row.add_child(slot)
		_backpack_slots.append(slot)


## Slot de roupa/armadura (cabeça, corpo, pernas, pés).
func _make_equip_slot(slot_name: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = BAG_SLOT
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.set_meta("equip", slot_name)
	button.set_drag_forwarding(_drag_equip.bind(button, slot_name), _can_drop_equip.bind(slot_name), _drop_on_equip.bind(slot_name))
	button.pressed.connect(func():
		if Input.is_key_pressed(KEY_SHIFT):
			_quick_unequip(slot_name))
	button.mouse_entered.connect(func():
		if not inventory.equipment[slot_name].is_empty():
			_show_tooltip(inventory.equipment[slot_name].id, 1))
	button.mouse_exited.connect(func(): _hover(-1))
	return button


func _make_slot(index: int, size := SLOT_SIZE) -> Button:
	var button := Button.new()
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_constant_override("icon_max_width", int(size.x) - 8)
	button.pressed.connect(func():
		if Input.is_key_pressed(KEY_SHIFT) and _backpack.visible:
			_quick_move(index))
	button.set_meta("index", index)
	# Arrastar e soltar: segura num slot, arrasta até outro e solta para trocar/juntar.
	button.set_drag_forwarding(_drag_from.bind(button, index), _can_drop.bind(index), _drop_on.bind(index))
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
	style.bg_color = LegacyGUI.BG
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
	# Título: modelo 3D do item girando à esquerda do nome.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_row)
	_spinner = ItemSpinner.new(56)
	title_row.add_child(_spinner)
	_tooltip_title = Label.new()
	_tooltip_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	_tooltip_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_tooltip_title)
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
	_show_tooltip(inventory.slots[index].id, inventory.slots[index].amount)


func _show_tooltip(id: StringName, amount: int) -> void:
	var item := ItemDB.def(id)
	_tooltip_title.text = item.name
	_spinner.show_item(id)
	var lines: Array[String] = []
	if item.has("damage_type"):
		lines.append("Tipo de dano: %s" % item.damage_type)
		lines.append("Dano: %d" % item.damage)
		lines.append("Empurrão: %d" % item.knockback)
	else:
		lines.append({"tool": "Ferramenta", "material": "Material"}.get(item.kind, ""))
	if amount > 1:
		lines.append("Quantidade: %d" % amount)
	if item.has("armor"):
		lines.append("Proteção: %d%%" % int(item.armor * 100.0))
	lines.append("")
	lines.append(ItemDB.description(id))
	var controls: Array = item.get("controls", [])
	_showing_controls = Input.is_key_pressed(KEY_SHIFT)
	if not controls.is_empty():
		if _showing_controls:
			lines = ["Controles:"]
			for line in controls:
				lines.append("• " + line)
		else:
			pass
	_tooltip_body.text = "\n".join(lines)
	_tooltip.reset_size()
	_tooltip.visible = true
	_process(0.0)


# --- Transferir rápido (Shift + clique) e roupas -----------------------------------

## Hotbar -> mochila, mochila -> hotbar; roupa/armadura vai direto para o corpo.
func _quick_move(index: int) -> void:
	var item: Dictionary = inventory.slots[index]
	if item.is_empty():
		return
	var slot_name: String = ItemDB.def(item.id).get("slot", "")
	if slot_name != "" and inventory.equip_from(index, slot_name):
		Sfx.play("pickup", -8.0)
		return
	var targets := range(Inventory.HOTBAR_SIZE, inventory.slots.size()) if index < Inventory.HOTBAR_SIZE else range(Inventory.HOTBAR_SIZE)
	# Primeiro junta numa pilha igual, depois o primeiro slot vazio.
	for t in targets:
		var other: Dictionary = inventory.slots[t]
		if not other.is_empty() and other.id == item.id and other.amount < ItemDB.max_stack(item.id):
			inventory.swap(index, t)
			if inventory.slots[index].is_empty():
				return
	for t in targets:
		if inventory.slots[t].is_empty():
			inventory.swap(index, t)
			return


func _quick_unequip(slot_name: String) -> void:
	for t in inventory.slots.size():
		if inventory.slots[t].is_empty():
			inventory.unequip_to(slot_name, t)
			return


func _drag_equip(_at: Vector2, button: Button, slot_name: String) -> Variant:
	if inventory.equipment[slot_name].is_empty():
		return null
	_picked_equip = slot_name
	var preview := TextureRect.new()
	preview.texture = button.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(36, 36)
	preview.position = -preview.size * 0.5
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var holder := Control.new()
	holder.add_child(preview)
	button.set_drag_preview(holder)
	return {"equip_slot": slot_name}


func _can_drop_equip(_at: Vector2, data: Variant, slot_name: String) -> bool:
	if not data is Dictionary or not data.has("inventory_slot"):
		return false
	var item: Dictionary = inventory.slots[data.inventory_slot]
	return not item.is_empty() and ItemDB.def(item.id).get("slot", "") == slot_name


func _drop_on_equip(_at: Vector2, data: Variant, slot_name: String) -> void:
	inventory.equip_from(data.inventory_slot, slot_name)
	_picked = -1
	_refresh()


func _drag_from(_at: Vector2, button: Button, index: int) -> Variant:
	if not _backpack.visible or inventory.slots[index].is_empty():
		return null
	_picked = index
	_refresh()
	# O ícone segue o mouse enquanto arrasta.
	var preview := TextureRect.new()
	preview.texture = button.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(44, 44)
	preview.size = Vector2(44, 44)
	preview.position = -preview.size * 0.5
	preview.modulate = Color(1, 1, 1, 0.8)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var holder := Control.new()
	holder.add_child(preview)
	button.set_drag_preview(holder)
	_tooltip.visible = false
	return {"inventory_slot": index}


func _can_drop(_at: Vector2, data: Variant, _index: int) -> bool:
	return data is Dictionary and (data.has("inventory_slot") or data.has("equip_slot"))


func _drop_on(_at: Vector2, data: Variant, index: int) -> void:
	if data.has("equip_slot"):
		inventory.unequip_to(data.equip_slot, index)
		_picked_equip = ""
		_refresh()
		return
	inventory.swap(data.inventory_slot, index)
	_picked = -1
	_refresh()
	_hover(index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and (_picked >= 0 or _picked_equip != ""):
		_picked = -1 # soltou fora de um slot: nada muda
		_picked_equip = ""
		_refresh()


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
	if _preview:
		_preview.show_equipment(inventory.equipment)
	var icons_node := get_node_or_null("/root/ItemIcons")
	for button in _equip_slots:
		var slot_name: String = button.get_meta("equip")
		var worn: Dictionary = inventory.equipment[slot_name]
		button.icon = icons_node.get_icon(worn.id) if icons_node and not worn.is_empty() else null
		button.text = "" if not worn.is_empty() else EQUIP_ICONS[slot_name]
		button.add_theme_font_size_override("font_size", 9)
		var equip_style := StyleBoxFlat.new()
		equip_style.bg_color = COLOR_SLOT.darkened(0.2)
		equip_style.set_border_width_all(2)
		equip_style.border_color = COLOR_PICKED if slot_name == _picked_equip else Color(0.4, 0.36, 0.28)
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, equip_style)
