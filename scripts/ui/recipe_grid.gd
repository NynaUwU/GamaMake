class_name RecipeGrid
extends VBoxContainer
## Grade de receitas: ícone em slot com o nome embaixo (como o menu de
## construção). Passando o mouse, a linha de baixo mostra o que precisa
## (tem/precisa). Clique = fabrica 1, Shift + clique = o máximo (até 100).
## Slot apagado = falta material. Usada na mesa, na fornalha e na mochila.

const SLOT := Vector2(48, 48)

var player: Player
var station := "mesa"
var _grid: GridContainer
var _info: Label


func setup(p: Player, station_: String, columns := 6, height := 240.0) -> void:
	player = p
	station = station_
	add_theme_constant_override("separation", 4)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = columns
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(_grid)
	_info = Label.new()
	_info.custom_minimum_size = Vector2(0, 30)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 11)
	add_child(_info)
	player.inventory.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		child.queue_free()
	for recipe: Dictionary in CraftingUI.recipes_for(station):
		_grid.add_child(_slot(recipe))


func _slot(recipe: Dictionary) -> Control:
	var button := Button.new()
	button.custom_minimum_size = SLOT
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_constant_override("icon_max_width", 34)
	var icons := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("ItemIcons")
	if icons and icons.has_method("get_icon"):
		button.icon = icons.get_icon(recipe.id)
	var ok := CraftingUI.can_craft(player.inventory, recipe)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = LegacyGUI.SLOT.lightened(0.12 if state == "hover" else 0.0)
		style.set_border_width_all(2)
		style.border_color = Color(0.95, 0.85, 0.4) if state == "hover" else Color(0.42, 0.42, 0.44)
		button.add_theme_stylebox_override(state, style)
	if not ok:
		button.modulate = Color(1, 1, 1, 0.4)
	slot_labels(button, ItemDB.short_name(recipe.id), recipe.get("amount", 1))
	button.pressed.connect(func():
		CraftingUI.craft(player, recipe, CraftingUI.max_times(recipe) if Input.is_key_pressed(KEY_SHIFT) else 1))
	button.mouse_entered.connect(func(): _info.text = _describe(recipe))
	return button


## Nome curto dentro do slot (embaixo) e quantidade no canto de cima à esquerda.
static func slot_labels(button: Button, short: String, amount := 1) -> void:
	var name := Label.new()
	name.text = short
	name.add_theme_font_size_override("font_size", 8)
	name.add_theme_color_override("font_outline_color", Color.BLACK)
	name.add_theme_constant_override("outline_size", 3)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name.offset_top = -12.0
	name.offset_bottom = -1.0
	name.clip_text = true
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(name)
	if amount > 1:
		var count := Label.new()
		count.text = str(amount)
		count.add_theme_font_size_override("font_size", 9)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 3)
		count.position = Vector2(3, 0)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count)


func _describe(recipe: Dictionary) -> String:
	var text := "%s%s%s\n%s" % [ItemDB.display_name(recipe.id), " x%d" % recipe.amount if recipe.get("amount", 1) > 1 else "",
		" (%s)" % recipe.note if recipe.has("note") else "", Builder.cost_text(recipe.cost, player.inventory)]
	if recipe.get("fuel", false):
		var fuel := CraftingUI.fuel_for(player.inventory)
		text += " + combustível (%s)" % (ItemDB.display_name(fuel[0]) if not fuel.is_empty() else "falta")
	return text
