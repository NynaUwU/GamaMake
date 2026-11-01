class_name PlantPanel
extends PanelContainer
## Mirando um pote/floreira/canteiro/cova (ou a grelha da fogueira): painel ao
## lado da mira com a foto de cada planta, a barra de crescimento e a %.

var player: Player
var _list: VBoxContainer
var _target: PlacedObject
var _timer := 0.0


func setup(p: Player) -> void:
	player = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = 40.0
	offset_top = -60.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.11, 0.78)
	style.set_border_width_all(1)
	style.border_color = Color(0.45, 0.45, 0.47)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	add_child(_list)
	visible = false


func _process(delta: float) -> void:
	# O alvo pode ter sido destruído neste frame (tronco cortado, item pego): checa antes do "as".
	var raw: Variant = player.get("_interact_target")
	var target: PlacedObject = raw as PlacedObject if is_instance_valid(raw) else null
	if target == null or not (target.is_farm() or target.kind == "campfire"):
		visible = false
		_target = null
		return
	_timer -= delta
	if target == _target and _timer > 0.0:
		return
	_target = target
	_timer = 0.25
	visible = true
	_rebuild(target)


func _rebuild(target: PlacedObject) -> void:
	# Tira as linhas antigas NA HORA (queue_free sozinho deixava o painel somar as velhas e crescer).
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var manager := target.get_parent() as PlacedManager
	var clock := manager.clock if manager else 0.0
	var icons := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("ItemIcons")
	var title := Label.new()
	title.text = {"pot_small": "Pote", "pot_wide": "Floreira", "bed": "Canteiro", "ground": "Cova", "campfire": "Grelha"}.get(target.kind, "")
	title.add_theme_font_size_override("font_size", 11)
	title.modulate = Color(1, 0.9, 0.7)
	_list.add_child(title)
	# Itens iguais viram uma linha só ("Argila x6"), com o progresso do mais atrasado.
	var groups := {}
	var order := []
	for entry in target.crops:
		if entry.is_empty():
			continue
		var id: StringName
		var progress := 0.0
		var note := ""
		if target.kind == "campfire":
			var st := Cooking.stage(entry, clock)
			id = entry.food if st == 0 else Cooking.result_of(entry, clock)
			progress = clampf((clock - entry.t) / entry.get("cook", Cooking.COOK_TIME), 0.0, 1.0)
			note = ["", "  pronto!", "  queimou"][st]
		else:
			id = Farming.CROPS[entry.crop].food
			progress = PlacedObject.progress(entry, clock)
			note = "  pronta!" if progress >= 1.0 else ""
		var key := "%s|%s" % [id, note]
		if not groups.has(key):
			groups[key] = {"id": id, "note": note, "count": 0, "progress": 1.0}
			order.append(key)
		groups[key].count += 1
		groups[key].progress = minf(groups[key].progress, progress)
	for key in order:
		var g: Dictionary = groups[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		_list.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if icons and icons.has_method("get_icon"):
			icon.texture = icons.get_icon(g.id)
		row.add_child(icon)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 1)
		row.add_child(column)
		var label := Label.new()
		label.text = "%s%s  %d%%%s" % [ItemDB.display_name(g.id), " x%d" % g.count if g.count > 1 else "", g.progress * 100.0, g.note]
		label.add_theme_font_size_override("font_size", 10)
		column.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(110, 6)
		bar.show_percentage = false
		bar.value = g.progress * 100.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.4, 0.8, 0.3) if g.progress < 1.0 else Color(1.0, 0.85, 0.3)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.6)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bg)
		column.add_child(bar)
	if order.is_empty():
		var empty := Label.new()
		empty.text = "Vazio"
		empty.add_theme_font_size_override("font_size", 10)
		_list.add_child(empty)
	size = Vector2.ZERO # encolhe para o conteúdo atual
	reset_size()
