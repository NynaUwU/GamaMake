class_name CraftingUI
extends CanvasLayer
## Fabricação por estação ([E] na estação). Lista as receitas com foto, custo
## (tem/precisa) e o botão Fabricar. ESC, E ou Fechar saem.
##   mesa      mesa de trabalho (a única bancada de fabricação): ferramentas,
##             armas, tábuas do tronco, e as receitas de metal (barras, vidro)
##   fornalha  funde minério/sucata em barras, pedra em vidro, tronco em
##             carvão. Cada fundição gasta combustível (carvão, tronco ou 2 tábuas).

const RECIPES := [
	# Bancada
	{"id": &"tabua", "amount": 8, "station": "bancada", "cost": {&"tronco": 1}},
	{"id": &"machado", "station": "bancada", "cost": {&"tabua": 2, &"pedra": 2, &"fita": 1}},
	{"id": &"picareta", "station": "bancada", "cost": {&"tabua": 2, &"pedra": 3, &"fita": 1}},
	{"id": &"pa", "station": "bancada", "cost": {&"tabua": 2, &"sucata": 2}},
	{"id": &"martelo", "station": "bancada", "cost": {&"tabua": 1, &"sucata": 2}},
	{"id": &"talhadeira", "station": "bancada", "cost": {&"sucata": 2}},
	{"id": &"bandagem", "station": "bancada", "cost": {&"pano": 2}},
	{"id": &"bumerangue", "station": "bancada", "cost": {&"tabua": 2, &"fita": 1}},
	{"id": &"chinelo", "station": "bancada", "cost": {&"pano": 1, &"fita": 1}},
	{"id": &"taco", "station": "bancada", "cost": {&"tabua": 2, &"sucata": 1}},
	{"id": &"lanca", "station": "bancada", "cost": {&"tabua": 2, &"sucata": 1, &"fita": 1}},
	{"id": &"vara", "station": "bancada", "cost": {&"tabua": 2, &"pano": 1, &"sucata": 1}},
	# Mesa de trabalho
	{"id": &"espada", "station": "mesa", "cost": {&"barra_ferro": 3, &"pano": 1}},
	{"id": &"pistola", "station": "mesa", "cost": {&"barra_ferro": 2, &"barra_cobre": 1, &"tabua": 1}},
	{"id": &"lanterna", "station": "mesa", "cost": {&"barra_cobre": 1, &"vidro": 1, &"fita": 1}},
	{"id": &"carregador", "station": "mesa", "cost": {&"barra_cobre": 2, &"sucata": 1}},
	{"id": &"gancho", "station": "mesa", "cost": {&"barra_ferro": 2, &"pano": 2}},
	{"id": &"colher", "station": "mesa", "cost": {&"barra_ferro": 4}},
	{"id": &"cajado", "station": "mesa", "cost": {&"barra_cobre": 3, &"vidro": 2, &"tronco": 1}},
	# Fornalha
	{"id": &"barra_ferro", "station": "fornalha", "fuel": true, "cost": {&"minerio_ferro": 2}},
	{"id": &"barra_cobre", "station": "fornalha", "fuel": true, "cost": {&"minerio_cobre": 2}},
	{"id": &"barra_ferro", "station": "fornalha", "fuel": true, "cost": {&"sucata": 3}, "note": "da sucata"},
	{"id": &"vidro", "station": "fornalha", "fuel": true, "cost": {&"pedra": 3}},
	{"id": &"carvao", "amount": 2, "station": "fornalha", "cost": {&"tronco": 1}},
]
const TITLES := {"bancada": "Mesa de trabalho", "mesa": "Mesa de trabalho", "fornalha": "Fornalha"}
## Combustível da fornalha, na ordem de preferência: [item, quanto gasta].
const FUELS := [[&"carvao", 1], [&"tronco", 1], [&"tabua", 2]]

var player: Player
var station := "bancada"
var _list: VBoxContainer


static func open_for(p: Node, station_ := "bancada") -> void:
	if not p is Player or p.is_puppet() or p.ui_blocked:
		return
	var ui := CraftingUI.new()
	ui.player = p
	ui.station = station_
	p.get_parent().add_child(ui) # junto da cena principal (o pai do jogador)


func _ready() -> void:
	layer = 9
	player.ui_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := LegacyGUI.box(center, TITLES.get(station, "Bancada"), 400.0)
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
	for recipe: Dictionary in recipes():
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
		var title := ItemDB.display_name(recipe.id)
		if recipe.get("amount", 1) > 1:
			title += " x%d" % recipe.amount
		if recipe.has("note"):
			title += " (%s)" % recipe.note
		var cost_line := Builder.cost_text(recipe.cost, player.inventory)
		if recipe.get("fuel", false):
			cost_line += " + combustível%s" % ("" if _fuel() != [] else " (falta!)")
		text.text = "%s\n%s" % [title, cost_line]
		row.add_child(text)
		var ok := _can_craft(recipe)
		var button := LegacyGUI.button(row, "Fabricar", craft.bind(recipe))
		button.disabled = not ok
		if not ok:
			text.modulate = Color(1, 1, 1, 0.55)


## Receitas desta estação (a mesa de trabalho faz tudo da bancada também).
func recipes() -> Array:
	var allowed := ["bancada", "mesa"] if station in ["mesa", "bancada"] else [station]
	return RECIPES.filter(func(r): return r.station in allowed)


## Primeiro combustível disponível [item, quantidade] ou [].
func _fuel() -> Array:
	for fuel in FUELS:
		if player.inventory.count(fuel[0]) >= fuel[1]:
			return fuel
	return []


func _can_craft(recipe: Dictionary) -> bool:
	if not Builder.can_afford(player.inventory, recipe.cost):
		return false
	if recipe.get("fuel", false):
		var fuel := _fuel()
		if fuel.is_empty():
			return false
		# O combustível não pode ser o próprio ingrediente que vai faltar.
		var need: Dictionary = recipe.cost.duplicate()
		need[fuel[0]] = need.get(fuel[0], 0) + fuel[1]
		return Builder.can_afford(player.inventory, need)
	return true


func craft(recipe: Dictionary) -> void:
	if not _can_craft(recipe):
		return
	if recipe.get("fuel", false):
		var fuel := _fuel()
		Builder.pay(player.inventory, {fuel[0]: fuel[1]})
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
