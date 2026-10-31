class_name BuildMenu
extends CanvasLayer
## Menu do martelo: aparece enquanto o botão direito está SEGURADO. Abas no
## topo (Estrutura, Aberturas, Outros...) e, embaixo, slots com a foto de cada
## peça como no inventário (com rolagem: cabe tudo que for sendo adicionado).
## Solte o botão em cima de um slot para escolher (ou clique nele).

const SLOT_SIZE := Vector2(64, 64)
const COLUMNS := 4

static var icons := {} ## id da entrada -> foto (tirada uma vez do modelo 3D)
static var _rendering := false

var builder: Builder
var _tab := "Estrutura"
var _tabs_row: HBoxContainer
var _grid: GridContainer
var _hovered := {}
var _info: Label


func _ready() -> void:
	layer = 8
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := LegacyGUI.box(center, "Construção", 400.0)
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 3)
	column.add_child(_tabs_row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 196)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)
	_info = Label.new()
	_info.custom_minimum_size = Vector2(0, 50)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_info)
	_render_icons()
	_refresh()


func open() -> void:
	visible = true
	_hovered = {}
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close(apply: bool) -> void:
	# Escolhe o slot que está embaixo do mouse AGORA (não depende de o mouse
	# ter "entrado" no botão: abrir o menu já com o mouse em cima também vale).
	var under := _slot_under_mouse() if apply else {}
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not under.is_empty():
		builder.select(under)


func _slot_under_mouse() -> Dictionary:
	var mouse := _grid.get_global_mouse_position()
	for box in _grid.get_children():
		var button := box.get_child(0) as Button
		if button and not box.is_queued_for_deletion() and button.get_global_rect().has_point(mouse):
			return button.get_meta("entry")
	return {}


func _process(_delta: float) -> void:
	if visible and not Input.is_action_pressed("block"):
		close(true) # soltou o botão direito: escolhe o slot embaixo do mouse


## Fotos das peças (uma vez por jogo; no headless fica só o nome).
func _render_icons() -> void:
	if _rendering or not icons.is_empty():
		return
	var studio := get_node_or_null("/root/ItemIcons")
	if studio == null or not studio.has_method("render_model"):
		return
	_rendering = true
	for tab in Builder.ENTRIES:
		for entry: Dictionary in Builder.ENTRIES[tab]:
			var texture: Texture2D = await studio.render_model(Builder.preview_model(entry))
			if texture:
				icons[entry.id] = texture
	_rendering = false
	if is_inside_tree():
		_refresh()


func _refresh() -> void:
	for child in _tabs_row.get_children():
		child.queue_free()
	for tab in Builder.ENTRIES:
		var button := LegacyGUI.button(_tabs_row, tab, _set_tab.bind(tab))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = tab == _tab # aba atual (aparece "afundada")
	for child in _grid.get_children():
		child.queue_free()
	var entries: Array = Builder.ENTRIES[_tab]
	_info.text = "Em breve..." if entries.is_empty() else "Solte o botão direito em cima de um slot"
	for entry: Dictionary in entries:
		_grid.add_child(_make_slot(entry))


func _make_slot(entry: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var button := Button.new()
	button.custom_minimum_size = SLOT_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_constant_override("icon_max_width", 56)
	button.icon = icons.get(entry.id)
	button.set_meta("entry", entry)
	if button.icon == null:
		button.text = entry.name.left(6) # sem foto (headless): ao menos o nome
	var current: bool = builder.selection.get("id") == entry.id
	var affordable := Builder.can_afford(builder.player.inventory, entry.get("cost", {}))
	if not affordable:
		button.modulate = Color(1.0, 0.6, 0.55) # falta material
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = LegacyGUI.SLOT.lightened(0.12 if state == "hover" else 0.0)
		style.set_border_width_all(2)
		style.border_color = InventoryUI.COLOR_SELECTED if current else Color(0.42, 0.42, 0.44)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func():
		builder.select(entry)
		close(false))
	button.mouse_entered.connect(func():
		_hovered = entry
		_info.text = "%s: %s\nCusto: %s" % [entry.name, entry.get("desc", ""), Builder.cost_text(entry.get("cost", {}), builder.player.inventory)])
	button.mouse_exited.connect(func(): if _hovered == entry: _hovered = {})
	box.add_child(button)
	var label := Label.new()
	label.text = entry.name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.custom_minimum_size = Vector2(SLOT_SIZE.x, 0)
	box.add_child(label)
	return box


func _set_tab(tab: String) -> void:
	_tab = tab
	_hovered = {}
	_refresh()
