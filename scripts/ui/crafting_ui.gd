class_name CraftingUI
extends CanvasLayer
## Bancada de fabricação ([E] na bancada da área inicial ou numa construída
## com o martelo). Lista as receitas com foto, custo (tem/precisa) e o botão
## Fabricar. ESC, E ou Fechar saem.

const RECIPES := [
	{"id": &"pa", "cost": {&"tabua": 2, &"sucata": 2}},
	{"id": &"martelo", "cost": {&"tabua": 1, &"sucata": 2}},
	{"id": &"talhadeira", "cost": {&"sucata": 2}},
	{"id": &"bandagem", "cost": {&"pano": 2}},
	{"id": &"bumerangue", "cost": {&"tabua": 2, &"fita": 1}},
	{"id": &"chinelo", "cost": {&"pano": 1, &"fita": 1}},
	{"id": &"lanterna", "cost": {&"sucata": 2, &"fita": 1}},
	{"id": &"taco", "cost": {&"tabua": 2, &"sucata": 1}},
	{"id": &"pistola", "cost": {&"sucata": 6, &"tabua": 1, &"fita": 2}},
]

var player: Player
var _list: VBoxContainer


static func open_for(p: Node) -> void:
	if not p is Player or p.is_puppet() or p.ui_blocked:
		return
	var ui := CraftingUI.new()
	ui.player = p
	p.get_tree().current_scene.add_child(ui)


func _ready() -> void:
	layer = 9
	player.ui_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := LegacyGUI.box(center, "Bancada", 380.0)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	LegacyGUI.button(column, "Fechar", close)
	player.inventory.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var icons := get_node_or_null("/root/ItemIcons")
	for recipe: Dictionary in RECIPES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_list.add_child(row)
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(44, 44)
		var style := StyleBoxFlat.new()
		style.bg_color = LegacyGUI.SLOT
		slot.add_theme_stylebox_override("panel", style)
		row.add_child(slot)
		if icons and icons.has_method("get_icon"):
			var icon := TextureRect.new()
			icon.texture = icons.get_icon(recipe.id)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot.add_child(icon)
		var text := Label.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_size_override("font_size", 11)
		text.text = "%s\n%s" % [ItemDB.display_name(recipe.id), Builder.cost_text(recipe.cost, player.inventory)]
		row.add_child(text)
		var ok := Builder.can_afford(player.inventory, recipe.cost)
		var button := LegacyGUI.button(row, "Fabricar", craft.bind(recipe))
		button.disabled = not ok
		if not ok:
			text.modulate = Color(1, 1, 1, 0.55)


func craft(recipe: Dictionary) -> void:
	if not Builder.can_afford(player.inventory, recipe.cost):
		return
	Builder.pay(player.inventory, recipe.cost)
	var left := player.pick_up(recipe.id, ItemDB.display_name(recipe.id), recipe.get("amount", 1))
	if left > 0:
		Net.i.drop_item(recipe.id, left, player.global_transform.translated(Vector3.UP), Vector3.ZERO)
	Sfx.play("knock")


func close() -> void:
	player.ui_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		close()
