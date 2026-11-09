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
## Fornalha (key "furnace_"): os 3 lugares ficam em volta da seta de progresso.
var source: PlacedObject
var _furnace_slots: Array[Control] = [] # onde cada um dos 3 lugares entra
var _arrow: ProgressBar
var _flame: ProgressBar
var _bellows: ProgressBar
## Tier 3: caldeira (água, calor, pressão), destilaria (água), alto-forno (energia + montagem).
var _water_bar: ProgressBar
var _heat_bar: ProgressBar
var _pressure_bar: ProgressBar
var _power_bar: ProgressBar
var _status: Label


static func open_for(p: Node, key_: String, source_: PlacedObject = null) -> void:
	if not p is Player or p.is_puppet() or p.ui_blocked or ContainerManager.i == null:
		return
	var ui := StorageUI.new()
	ui.player = p
	ui.key = key_
	ui.source = source_
	p.get_parent().add_child(ui)


func _is_furnace() -> bool:
	return key.begins_with("furnace_")


## Material e combustível à esquerda, seta (progresso) no meio, resultado à direita;
## a chama embaixo do material mostra quanto falta do combustível aceso.
func _build_furnace(column: VBoxContainer) -> void:
	for k in Smelting.slot_count(source.kind if source else "furnace"):
		var holder := CenterContainer.new()
		holder.custom_minimum_size = SLOT
		_furnace_slots.append(holder)
	if source and source.kind == "boiler":
		_build_boiler(column)
		return
	if source and Smithing.STATION.has(source.kind):
		_build_forge(column)
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)
	left.add_child(_furnace_slots[Smelting.INPUT])
	if source and source.kind in Smelting.NO_FUEL:
		left.alignment = BoxContainer.ALIGNMENT_CENTER # trefiladora: gira, não queima
	else:
		_flame = _bar(left, Color(1.0, 0.55, 0.15))
		left.add_child(_furnace_slots[Smelting.FUEL])
	var middle := VBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(middle)
	var arrow_label := Label.new()
	arrow_label.text = "→"
	arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(arrow_label)
	_arrow = _bar(middle, Color(0.95, 0.85, 0.4))
	_arrow.custom_minimum_size = Vector2(60, 6)
	if source and source.kind == "stone_furnace":
		_bellows = _bar(middle, Color(0.9, 0.3, 0.15)) # calor do fole
		_bellows.custom_minimum_size = Vector2(60, 4)
	if source and source.kind == "distillery":
		_water_bar = _labeled_bar(middle, "água", Color(0.3, 0.55, 0.95))
	if source and source.kind == "blast_furnace":
		_power_bar = _labeled_bar(middle, "fole", Color(0.9, 0.3, 0.15))
	if source and source.kind == "wire_drawer":
		_power_bar = _labeled_bar(middle, "eixo", Color(0.85, 0.7, 0.3))
	var right := CenterContainer.new()
	row.add_child(right)
	right.add_child(_furnace_slots[Smelting.OUTPUT])
	if source and source.kind in ["blast_furnace", "distillery", "wire_drawer"]:
		_status = Label.new()
		_status.add_theme_font_size_override("font_size", 11)
		_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_status.modulate = Color(1.0, 0.75, 0.45)
		column.add_child(_status)
	_build_recipes(column)


## Estações de minigame (forja, fundição, bancada de solda): lugares do material à
## esquerda, a peça pronta à direita; embaixo as peças. Clicar numa abre o minigame.
const STATION_UI := {
	"forge": {"slots": [["metal", Smelting.INPUT], ["carvão", Smelting.FUEL]], "arrow": "→ bigorna →",
		"title": "Forjar (clique: começa o minigame · 1 carvão por peça)", "hint": "Arraste barras de metal e carvão da mochila para os lugares"},
	"foundry": {"slots": [["metal", Smelting.INPUT], ["liga", Smithing.ALLOY], ["carvão", Smelting.FUEL]], "arrow": "→ cadinho → molde →",
		"title": "Fundir (clique: começa o minigame · 1 carvão por peça)", "hint": "Bronze: 3 barras de cobre no metal e 1 de estanho na liga, mais carvão"},
	"weld_bench": {"slots": [["metal", Smelting.INPUT], ["eletrodos", Smelting.FUEL]], "arrow": "→ solda →",
		"title": "Soldar armaduras e chapas (clique: começa o minigame)", "hint": "Barras (aço para armadura, ferro para chapa) e eletrodos (mesa) nos lugares"},
	"torch_bench": {"slots": [["cobre", Smelting.INPUT], ["solda", Smithing.ALLOY], ["outro", Smithing.EXTRA_SLOT], ["combustível", Smelting.FUEL]],
		"arrow": "→ maçarico →", "title": "Soldar cobre (clique: começa o minigame · 1 solda de combustível)",
		"hint": "Cobre/cano/fio, estanho (solda) e vidro nos lugares; álcool, óleo ou botijão de gás (8 soldas) no combustível"},
}
const METAL_SHORT := {&"barra_aco": "aço", &"barra_cobre": "cobre", &"barra_ferro": "ferro", &"barra_bronze": "bronze", &"barra_estanho": "estanho"}
const METAL_SYMBOL := {&"barra_aco": "aço", &"barra_cobre": "Cu", &"barra_ferro": "Fe", &"barra_bronze": "bz", &"barra_estanho": "Sn",
	&"vidro": "vd", &"fio_cobre": "fio", &"cano": "cano"}


## Custo curto no botão da peça: "2x ferro"; liga: "3 Cu + 1 Sn" (eletrodos ficam de fora).
static func _cost_label(r: Dictionary) -> String:
	var metals: Array = r.cost.keys().filter(func(id): return id != &"eletrodo")
	if metals.size() == 1:
		return "%dx %s" % [r.cost[metals[0]], METAL_SHORT.get(metals[0], ItemDB.short_name(metals[0]))]
	var sep := " + " if metals.size() == 2 else "+"
	return sep.join(metals.map(func(id): return ("%d %s" if metals.size() == 2 else "%d%s") % [r.cost[id], METAL_SYMBOL.get(id, ItemDB.short_name(id))]))
var _forge_box: HFlowContainer
func _build_forge(column: VBoxContainer) -> void:
	var ui: Dictionary = STATION_UI[source.kind]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	row.add_child(left)
	for part in ui.slots:
		var label := Label.new()
		label.text = part[0]
		label.add_theme_font_size_override("font_size", 9)
		label.modulate = Color(1, 1, 1, 0.6)
		left.add_child(label)
		left.add_child(_furnace_slots[part[1]])
	var arrow := Label.new()
	arrow.text = ui.arrow
	arrow.add_theme_font_size_override("font_size", 11)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	var done := Label.new()
	done.text = "peça"
	done.add_theme_font_size_override("font_size", 9)
	done.modulate = Color(1, 1, 1, 0.6)
	right.add_child(done)
	right.add_child(_furnace_slots[Smelting.OUTPUT])
	var title := Label.new()
	title.text = ui.title
	title.add_theme_font_size_override("font_size", 10)
	title.modulate = Color(1, 1, 1, 0.7)
	column.add_child(title)
	_forge_box = HFlowContainer.new()
	_forge_box.add_theme_constant_override("h_separation", 4)
	_forge_box.add_theme_constant_override("v_separation", 4)
	_forge_box.custom_minimum_size = Vector2(300, 0)
	column.add_child(_forge_box)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 10)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size = Vector2(300, 0)
	_status.modulate = Color(1.0, 0.8, 0.5)
	column.add_child(_status)


func _fill_forge() -> void:
	if _forge_box == null:
		return
	for child in _forge_box.get_children():
		_forge_box.remove_child(child)
		child.queue_free()
	var slots: Array = ContainerManager.i.slots_of(key)
	var icons := get_tree().root.get_node_or_null("ItemIcons")
	for entry in Smithing.recipes(Smithing.STATION[source.kind]):
		var r: Dictionary = entry[1]
		if not Progress.knows(r.get("manual", "")):
			continue # peça de manual que ainda não leu
		var metal := Smithing.metal_of(r)
		var why := Smithing.missing(r, slots, source)
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(62, 44)
		var fuel: int = Smithing.FUEL_COST.get(r.station, 0)
		button.tooltip_text = "%s%s%s: %s%s%s" % [ItemDB.display_name(r.id), " x%d" % r.amount if r.get("amount", 1) > 1 else "",
			" (%s)" % r.note if r.has("note") else "", Builder.cost_text(r.cost, null), " + %d carvão" % fuel if fuel > 0 else "",
			"\n" + why if why != "" else ""]
		var icon := TextureRect.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		icon.offset_top = 2
		icon.offset_bottom = 30
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if icons and icons.has_method("get_icon"):
			icon.texture = icons.get_icon(r.id)
		button.add_child(icon)
		var cost := Label.new()
		cost.text = _cost_label(r)
		cost.add_theme_font_size_override("font_size", 8)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		cost.offset_top = -12
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(cost)
		button.modulate = Color.WHITE if why == "" else Color(1, 1, 1, 0.4)
		button.mouse_entered.connect(func(): _status.text = why if why != "" else "Pronto: %s" % ItemDB.display_name(r.id))
		var index: int = entry[0]
		button.pressed.connect(func():
			if why != "":
				_status.text = why
				Sfx.play("click", -6.0, 0.6)
				return
			var forge := source
			close()
			Smithing.start(player, forge, index))
		_forge_box.add_child(button)
	if _status and _status.text == "":
		_status.text = STATION_UI[source.kind].hint


## Receitas desta fornalha: material -> resultado (com ícones). Com o material na
## mochila fica claro; clique manda o que tiver dele para o lugar do material.
var _recipe_box: HFlowContainer
func _build_recipes(column: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Receitas (clique: põe o material)"
	title.add_theme_font_size_override("font_size", 10)
	title.modulate = Color(1, 1, 1, 0.7)
	column.add_child(title)
	_recipe_box = HFlowContainer.new()
	_recipe_box.add_theme_constant_override("h_separation", 6)
	_recipe_box.add_theme_constant_override("v_separation", 4)
	_recipe_box.custom_minimum_size = Vector2(300, 0)
	column.add_child(_recipe_box)
	_fill_recipes()


func _fill_recipes() -> void:
	_fill_forge()
	if _recipe_box == null:
		return
	for child in _recipe_box.get_children():
		_recipe_box.remove_child(child)
		child.queue_free()
	var kind: String = source.kind if source else "furnace"
	var icons := get_tree().root.get_node_or_null("ItemIcons")
	for r: Dictionary in CraftingUI.RECIPES:
		if r.station != Smelting.station(kind) or r.cost.size() != 1:
			continue
		var input: StringName = r.cost.keys()[0]
		var need: int = r.cost[input]
		var have := player.inventory.count(input)
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "%d %s -> %d %s" % [need, ItemDB.display_name(input), r.get("amount", 1), ItemDB.display_name(r.id)]
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 2)
		button.add_child(row)
		for part in [[input, need], ["->", 0], [r.id, r.get("amount", 1)]]:
			if part[0] is String:
				var arrow := Label.new()
				arrow.text = "→"
				arrow.add_theme_font_size_override("font_size", 10)
				row.add_child(arrow)
				continue
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(20, 20)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if icons and icons.has_method("get_icon"):
				icon.texture = icons.get_icon(part[0])
			row.add_child(icon)
			if part[1] > 1:
				var count := Label.new()
				count.text = "x%d" % part[1]
				count.add_theme_font_size_override("font_size", 9)
				row.add_child(count)
		button.custom_minimum_size = Vector2(row.get_combined_minimum_size().x + 10, 26)
		row.position = Vector2(5, 3)
		button.modulate = Color(1, 1, 1, 1.0) if have >= need else Color(1, 1, 1, 0.4)
		button.pressed.connect(func(): _use_recipe(input))
		_recipe_box.add_child(button)


## Manda todo o material da receita que estiver na mochila para o lugar do material.
func _use_recipe(input: StringName) -> void:
	var index := Cooking.find_any(player.inventory, {input: true})
	if index < 0:
		Sfx.play("click", -6.0, 0.6)
		return
	_quick("bag", index)


## Caldeira: só o combustível (com a chama) e as três barras: água, calor e pressão.
func _build_boiler(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(left)
	_flame = _bar(left, Color(1.0, 0.55, 0.15))
	left.add_child(_furnace_slots[Smelting.FUEL])
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	row.add_child(bars)
	_water_bar = _labeled_bar(bars, "água", Color(0.3, 0.55, 0.95))
	_heat_bar = _labeled_bar(bars, "calor", Color(1.0, 0.55, 0.15))
	_pressure_bar = _labeled_bar(bars, "pressão", Color(0.9, 0.25, 0.2))
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)


func _labeled_bar(parent: Control, text: String, color: Color) -> ProgressBar:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = Color(1, 1, 1, 0.7)
	parent.add_child(label)
	var bar := _bar(parent, color)
	bar.custom_minimum_size = Vector2(90, 6)
	return bar


func _bar(parent: Control, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(SLOT.x, 5)
	bar.show_percentage = false
	bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	parent.add_child(bar)
	return bar


func _process(_delta: float) -> void:
	if not _is_furnace() or not is_instance_valid(source):
		return
	var burn_max: float = maxf(source.extra.get("burn_max", 1.0), 0.01)
	if _flame:
		_flame.value = clampf(source.extra.get("burn", 0.0) / burn_max, 0.0, 1.0)
	if _arrow:
		_arrow.value = clampf(source.extra.get("prog", 0.0) / Smelting.SMELT_TIME.get(source.kind, 8.0), 0.0, 1.0)
	if _bellows:
		_bellows.value = Machines.heat(source)
	var kind := source.kind
	if _water_bar:
		var cap := Fluids.BOILER_WATER if kind == "boiler" else Fluids.STILL_WATER
		_water_bar.value = clampf(source.extra.get("water", 0.0) / cap, 0.0, 1.0)
	if _heat_bar:
		_heat_bar.value = source.extra.get("heat", 0.0)
	if _pressure_bar:
		_pressure_bar.value = source.extra.get("pressure", 0.0) / Fluids.PRESSURE_MAX
	if _power_bar:
		_power_bar.value = source.extra.get("speed", 0.0)
	if _status and not Smithing.STATION.has(kind): # estação de minigame: escreve o que falta para a peça
		_status.text = _status_text(kind)


func _status_text(kind: String) -> String:
	match kind:
		"boiler":
			if source.extra.get("dry", 0.0) > 0.0:
				_status.modulate = Color(1.0, 0.3, 0.2)
				return "SECA E QUENTE! Ponha água ou apague o fogo"
			_status.modulate = Color(1, 1, 1, 0.7)
			if source.extra.get("water", 0.0) < 1.0:
				return "Sem água: ligue um cano ou despeje garrafas"
			return "Fervendo: vapor para o motor" if source.extra.get("heat", 0.0) > 0.5 else "Esquentando..."
		"blast_furnace":
			var rings := Fluids.blast_rings(source)
			if rings < Fluids.BLAST_RINGS:
				return "Incompleto: empilhe %d anel%s de tijolo em cima" % [Fluids.BLAST_RINGS - rings, "" if Fluids.BLAST_RINGS - rings == 1 else "s"]
			return "Fole parado: ligue um eixo com força" if source.extra.get("speed", 0.0) < 0.3 else "Pronto: ferro + carvão = aço"
		"distillery":
			return "Sem água: ligue um cano ou despeje garrafas" if source.extra.get("water", 0.0) < 1.0 else ""
		"wire_drawer":
			return "Parada: ligue um eixo com força ou um motor elétrico na porta de latão" if source.extra.get("speed", 0.0) < 0.3 else "Girando: cobre vira fio"
	return ""


func _ready() -> void:
	layer = 9
	player.ui_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	LegacyGUI.close_on_outside(self, close)
	var title := "Baú"
	if _is_furnace():
		title = Machines.NAMES.get(source.kind, "Fornalha") if source else "Fornalha"
	var column := LegacyGUI.box(center, title, 230.0)
	if _is_furnace():
		_build_furnace(column)
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
	_fill_recipes() # mochila mudou: receitas com/sem material
	var slots: Array = ContainerManager.i.slots_of(key)
	if _is_furnace():
		for k in _furnace_slots.size():
			for child in _furnace_slots[k].get_children():
				child.queue_free()
			_furnace_slots[k].add_child(_slot("chest", k, slots[k] if k < slots.size() else {}))
	else:
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
	button.set_drag_forwarding(_drag_from.bind(button, from, index, slot), _can_drop.bind(from, index), _drop_on.bind(from, index))
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


func _can_drop(_at: Vector2, data: Variant, to := "", index := -1) -> bool:
	if not (data is Dictionary and data.has("storage_slot")):
		return false
	if _is_furnace() and to == "chest" and data.from == "bag":
		var slot: Dictionary = player.inventory.slots[data.index]
		return not slot.is_empty() and Smelting.accepts(index, slot.id, source.kind if source else "")
	return true


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
		manager.request("put_at", [key, index, String(moved.id), moved.amount, moved.get("dur", 1.0), ItemDB.extras(moved)])
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
	if _is_furnace():
		target = _furnace_target(item.id, slots)
		if target < 0:
			Sfx.play("click", -6.0, 0.6)
			return
		var moved_f := player.inventory.take(index, item.amount)
		manager.request("put_at", [key, target, String(moved_f.id), moved_f.amount, moved_f.get("dur", 1.0), ItemDB.extras(moved_f)])
		Sfx.play("knock", -8.0, 1.0)
		return
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
	manager.request("put_at", [key, target, String(moved.id), moved.amount, moved.get("dur", 1.0), ItemDB.extras(moved)])
	Sfx.play("knock", -8.0, 1.0)


## Shift + clique na fornalha: combustível vai para o lugar dele; o que funde, para o material.
func _furnace_target(id: StringName, slots: Array) -> int:
	var kind: String = source.kind if source else "furnace"
	var fits := func(k: int) -> bool:
		return slots.size() > k and (slots[k].is_empty() or (slots[k].id == id and slots[k].amount < ItemDB.max_stack(id)))
	if Smithing.STATION.has(kind):
		# Estação de minigame: o mesmo item que já está num lugar, senão o primeiro que aceita.
		var order: Array = {"foundry": [Smelting.INPUT, Smithing.ALLOY, Smelting.FUEL],
			"torch_bench": [Smelting.INPUT, Smithing.ALLOY, Smithing.EXTRA_SLOT, Smelting.FUEL]}.get(kind, [Smelting.INPUT, Smelting.FUEL])
		for k in order:
			if slots.size() > k and not slots[k].is_empty() and slots[k].id == id and fits.call(k):
				return k
		for k in order:
			if Smelting.accepts(k, id, kind) and fits.call(k):
				return k
		return -1
	if kind != "boiler" and not Smelting.recipe(kind, id).is_empty() and fits.call(Smelting.INPUT):
		return Smelting.INPUT
	if Smelting.accepts(Smelting.FUEL, id, kind) and fits.call(Smelting.FUEL):
		return Smelting.FUEL
	return -1


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
