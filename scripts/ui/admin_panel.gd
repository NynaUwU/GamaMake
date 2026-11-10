class_name AdminPanel
extends RefCounted
## Menu de admin dentro do ESC (só quem hospeda: solo ou host). À esquerda as trapaças que
## ficam ligadas (vida infinita, stamina, sem necessidades, munição, criativo, invisível,
## velocidade); à direita as ações na hora (desbloquear tudo, encher, zumbis, horda, matar
## todos, dia/noite, chuva, voltar ao início) e "Dar itens" (todos os itens com ícone e busca).

var player: Player
var main: Node
var box: Control ## a caixa do menu (o PauseMenu mostra/esconde)
var items_box: Control ## seletor de itens
var _toggles := {} # nome -> Button
var _status: Label
var _grid: GridContainer
var _search: LineEdit


func _init(parent: Control, p: Player, back: Callable) -> void:
	player = p
	main = p.get_parent()
	var column := LegacyGUI.box(parent, "Admin (trapaças)", 560.0)
	box = column.get_parent()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(_header("Ligadas até desligar"))
	for t in Cheats.TOGGLES:
		var b := LegacyGUI.button(left, "", _toggle.bind(t[0]))
		b.tooltip_text = t[2]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_toggles[t[0]] = b
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(_header("Na hora"))
	LegacyGUI.button(right, "Desbloquear tudo", func():
		Cheats.unlock_all()
		_say("Manuais lidos, todas as receitas e estações no diário, conquistas feitas"))
	LegacyGUI.button(right, "Encher vida, fome, sede e calor", func():
		Cheats.fill(player)
		_say("Tudo cheio; doença e gás curados"))
	LegacyGUI.button(right, "Dar itens...", func():
		box.visible = false
		items_box.visible = true
		_fill_items())
	var pair := _pair(right)
	LegacyGUI.button(pair, "Zumbi na frente", func():
		main.spawn_zombie_in_front()
		_say("Zumbi a 6 m na sua frente"))
	LegacyGUI.button(pair, "Horda (100)", func():
		main.spawn_horde(100)
		_say("100 zumbis em volta (nascem ao continuar)"))
	LegacyGUI.button(right, "Matar todos os zumbis", func():
		_say("%d zumbis derrubados" % Cheats.kill_zombies(main)))
	pair = _pair(right)
	LegacyGUI.button(pair, "Dia (8 h)", func():
		Cheats.set_hour(8.0)
		_say("Amanheceu"))
	LegacyGUI.button(pair, "Noite (22 h)", func():
		Cheats.set_hour(22.0)
		_say("Anoiteceu"))
	pair = _pair(right)
	LegacyGUI.button(pair, "Chuva", func():
		Cheats.set_rain(true)
		_say("Chovendo"))
	LegacyGUI.button(pair, "Tempo bom", func():
		Cheats.set_rain(false)
		_say("Céu limpo"))
	LegacyGUI.button(right, "Voltar ao início", func():
		if player.spawn_point != Vector3.INF:
			player.global_position = player.spawn_point
			player.velocity = Vector3.ZERO
			_say("De volta ao ponto de início"))
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.modulate = Color(0.95, 0.85, 0.45)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.text = "Só para você e só nesta sessão (recomeçar desliga tudo)."
	column.add_child(_status)
	LegacyGUI.button(column, "Voltar", back)
	_build_items(parent)
	box.visible = false
	refresh()


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(1, 1, 1, 0.6)
	return label


func _pair(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	row.child_entered_tree.connect(func(child: Node):
		if child is Control:
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL)
	return row


func _say(text: String) -> void:
	_status.text = text
	Sfx.play("click", -4.0, 1.2)


func _toggle(name: String) -> void:
	Cheats.set_flag(name, not Cheats.get_flag(name))
	refresh()
	Sfx.play("click", -4.0, 1.4 if Cheats.get_flag(name) else 0.9)


## Texto dos botões de trapaça: LIGADA em verde, desligada em cinza.
func refresh() -> void:
	for t in Cheats.TOGGLES:
		var b: Button = _toggles[t[0]]
		var on := Cheats.get_flag(t[0])
		b.text = "%s %s" % ["[x]" if on else "[  ]", t[1]]
		b.modulate = Color(0.65, 1.0, 0.6) if on else Color(1, 1, 1, 0.85)


# --- Dar itens ------------------------------------------------------------------------

func _build_items(parent: Control) -> void:
	var column := LegacyGUI.box(parent, "Dar itens (clique: uma pilha · Shift: 1)", 560.0)
	items_box = column.get_parent()
	_search = LineEdit.new()
	_search.placeholder_text = "Buscar item..."
	_search.text_changed.connect(func(_t): _fill_items())
	column.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 10
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_grid)
	LegacyGUI.button(column, "Voltar", func():
		items_box.visible = false
		box.visible = true)
	items_box.visible = false


func _fill_items() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var query := _search.text.strip_edges().to_lower()
	var icons := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("ItemIcons")
	var ids := ItemDB.ITEMS.keys()
	ids.sort_custom(func(a, b): return ItemDB.display_name(a).naturalnocasecmp_to(ItemDB.display_name(b)) < 0)
	for id: StringName in ids:
		var name := ItemDB.display_name(id)
		if query != "" and not name.to_lower().contains(query) and not String(id).contains(query):
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(48, 48)
		button.focus_mode = Control.FOCUS_NONE
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.add_theme_constant_override("icon_max_width", 34)
		button.tooltip_text = name
		if icons and icons.has_method("get_icon"):
			button.icon = icons.get_icon(id)
		RecipeGrid.slot_labels(button, ItemDB.short_name(id))
		button.pressed.connect(func():
			Cheats.give(player, id, 1 if Input.is_key_pressed(KEY_SHIFT) else -1))
		_grid.add_child(button)
