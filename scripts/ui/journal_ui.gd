class_name JournalUI
extends CanvasLayer
## Diário do jogador (tecla J): guia das eras (objetivos de cada era, como as
## quests do SevTech), árvore de receitas descobertas por estação, manuais lidos
## e o que liberam, e as pistas anotadas (rádio, manuais). Só leitura.

const TABS := ["Eras", "Receitas", "Manuais", "Pistas"]
const OK := Color(0.45, 0.85, 0.4)
const DIM := Color(1, 1, 1, 0.45)
const GOLD := Color(0.95, 0.8, 0.35)

static var tab := "Eras"

var player: Player
var _tabs: HBoxContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _title: Label


static func open_for(p: Player) -> void:
	if p == null or p.ui_blocked or Progress.i == null:
		return
	var ui := JournalUI.new()
	ui.player = p
	p.get_parent().add_child(ui)


func _ready() -> void:
	layer = 9
	player.ui_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	LegacyGUI.close_on_outside(self, close)
	var column := LegacyGUI.box(center, "Diário", 800.0)
	_title = column.get_child(0) as Label
	_tabs = HBoxContainer.new()
	column.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(780, 470)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	_scroll.add_child(_body)
	var hint := Label.new()
	hint.text = "J ou Esc fecha"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = DIM
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	Sfx.play("creak", -10.0, 1.6)
	_refresh()


func _refresh() -> void:
	var p := Progress.i
	_title.text = "Diário · Era %d: %s" % [p.era, Progress.ERAS[p.era].name]
	for child in _tabs.get_children():
		child.queue_free()
	for t in TABS:
		var b := LegacyGUI.button(_tabs, t, func():
			tab = t
			_refresh())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = t == tab
		b.set_meta("tab", t)
	_update_tab_titles()
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	match tab:
		"Eras": _eras()
		"Receitas": _recipes()
		"Manuais": _manuals()
		"Pistas": _clues()
	_scroll.scroll_vertical = 0


## Aba de receitas com quantas novas faltam olhar.
func _update_tab_titles() -> void:
	var fresh := Progress.i.new_recipes().size()
	for b in _tabs.get_children():
		if b is Button and b.get_meta("tab", "") == "Receitas":
			b.text = "Receitas (%d novas)" % fresh if fresh > 0 else "Receitas"


# --- Eras ------------------------------------------------------------------------------

func _eras() -> void:
	var p := Progress.i
	for e in Progress.ERAS.size():
		var era: Dictionary = Progress.ERAS[e]
		var state := "concluída" if e < p.era else ("atual" if e == p.era else "")
		var head := _label("Era %d · %s%s" % [e, era.name, "  (%s)" % state if state != "" else ""], 14)
		head.modulate = GOLD if e == p.era else (OK if e < p.era else DIM)
		_body.add_child(head)
		if e > p.era + 1:
			_body.add_child(_small(era.desc, DIM))
			continue
		_body.add_child(_small(era.desc, Color(1, 1, 1, 0.75) if e <= p.era + 1 else DIM))
		for a: String in Progress.achievements_of(e):
			var info: Dictionary = Progress.ACHIEVEMENTS[a]
			_body.add_child(_goal(info, p.done.has(a), e > p.era))
		if e == p.era and e < Progress.ERAS.size() - 1:
			_body.add_child(_small("Para abrir a Era %d: os objetivos marcados com \"chave\"." % (e + 1), GOLD))
		_body.add_child(_gap(6))


## Linha de objetivo: quadradinho (cheio = feito), título e como fazer.
func _goal(info: Dictionary, finished: bool, future: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var box := Panel.new()
	box.custom_minimum_size = Vector2(11, 11)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = OK if finished else Color(0, 0, 0, 0.3)
	style.set_border_width_all(1)
	style.border_color = Color(0.7, 0.7, 0.7)
	box.add_theme_stylebox_override("panel", style)
	row.add_child(box)
	var text := _label("%s%s" % [info.title, "  · chave" if info.get("key", false) else ""], 12)
	text.custom_minimum_size = Vector2(170, 0)
	text.modulate = OK if finished else (DIM if future else Color.WHITE)
	row.add_child(text)
	var how := _small(info.how, DIM if finished or future else Color(1, 1, 1, 0.75))
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(how)
	return row


# --- Receitas ------------------------------------------------------------------------

## Por estação: produto ← ingredientes (ícone e quantidade), com o que mais precisa
## (combustível, eixo...). Só aparecem as estações já construídas e as receitas com
## ingredientes alcançáveis (RecipeBook). Receita nunca olhada tem o selo NOVA, que
## some ao passar o mouse nela.
func _recipes() -> void:
	var list := RecipeBook.visible()
	var by_station := {}
	for r: Dictionary in list:
		if not by_station.has(r.station):
			by_station[r.station] = []
		by_station[r.station].append(r)
	var built := RecipeBook.built_kinds()
	var fresh := 0
	for r in list:
		fresh += 0 if Progress.i.seen_recipes.has(r.key) else 1
	_body.add_child(_small("%d receitas conhecidas%s. Construir uma estação ou máquina mostra o que dá para fazer nela; receita com ingrediente de máquina que você ainda não tem fica escondida." % [
		list.size(), " (%d novas: passe o mouse para marcar como vista)" % fresh if fresh > 0 else ""], Color(1, 1, 1, 0.8)))
	var locked: Array[String] = []
	for section in RecipeBook.SECTIONS:
		var rows: Array = by_station.get(section[0], [])
		if rows.is_empty():
			if not RecipeBook.station_built(section[0], built):
				locked.append(section[1])
			continue
		var head := _label("%s  (%d)" % [section[1], rows.size()], 14)
		head.modulate = GOLD
		_body.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 4)
		_body.add_child(grid)
		for r: Dictionary in rows:
			grid.add_child(_recipe_row(r))
		_body.add_child(_gap(4))
	if not locked.is_empty():
		_body.add_child(_small("Ainda não construídas: " + ", ".join(locked), DIM))


## Uma receita: [NOVA] produto xN ← ingrediente xN ... (nota). Dica com os nomes.
func _recipe_row(r: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(376, 40)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.25)
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var badge := Label.new()
	badge.text = "NOVA"
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", Color(0.1, 0.08, 0.02))
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = GOLD
	badge_box.set_corner_radius_all(2)
	badge_box.content_margin_left = 3
	badge_box.content_margin_right = 3
	badge.add_theme_stylebox_override("normal", badge_box)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.visible = not Progress.i.seen_recipes.has(r.key)
	row.add_child(badge)
	row.add_child(_item_icon(r.out, r.amount, 32))
	var name := Label.new()
	name.text = ItemDB.short_name(r.out)
	name.add_theme_font_size_override("font_size", 12)
	name.custom_minimum_size = Vector2(92, 0)
	name.clip_text = true
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	var arrow := Label.new()
	arrow.text = "<-"
	arrow.modulate = DIM
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	var parts: Array[String] = []
	for item in r.cost:
		row.add_child(_item_icon(item, r.cost[item], 26))
		parts.append("%d %s" % [r.cost[item], ItemDB.display_name(item)])
	if r.note != "":
		var note := Label.new()
		note.text = r.note
		note.add_theme_font_size_override("font_size", 10)
		note.modulate = DIM
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(note)
	panel.tooltip_text = "%s%s\n%s%s" % [ItemDB.display_name(r.out), " x%d" % r.amount if r.amount > 1 else "", " + ".join(parts),
		"\n" + r.note if r.note != "" else ""]
	var key: String = r.key
	panel.mouse_entered.connect(func():
		if badge.visible:
			badge.visible = false
			Progress.i.mark_seen(key)
			_update_tab_titles())
	return panel


## Ícone do item num quadradinho, com a quantidade no canto.
func _item_icon(id: StringName, amount: int, px: float) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(px, px)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = LegacyGUI.SLOT
	style.set_border_width_all(1)
	style.border_color = Color(0.42, 0.42, 0.44)
	slot.add_theme_stylebox_override("panel", style)
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 2
	icon.offset_top = 2
	icon.offset_right = -2
	icon.offset_bottom = -2
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icons := get_tree().root.get_node_or_null("ItemIcons")
	if icons and icons.has_method("get_icon"):
		icon.texture = icons.get_icon(id)
	slot.add_child(icon)
	if amount > 1:
		var count := Label.new()
		count.text = str(amount)
		count.add_theme_font_size_override("font_size", 10)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 3)
		count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		count.offset_left = -14
		count.offset_top = -14
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count)
	return slot


# --- Manuais -------------------------------------------------------------------------

func _manuals() -> void:
	var p := Progress.i
	_body.add_child(_small("Manuais aparecem em casas, ruínas e airdrops. Clique com o manual na mão para ler: o livro fica com você (dá para emprestar).", Color(1, 1, 1, 0.8)))
	_body.add_child(_gap(4))
	for id in Progress.MANUALS:
		var info: Dictionary = Progress.MANUALS[id]
		if p.manuals.has(id):
			var head := _label("%s  (Era %d)" % [info.title, info.era], 13)
			head.modulate = OK
			_body.add_child(head)
			_body.add_child(_small("Liberou: " + info.unlocks, Color(1, 1, 1, 0.8)))
		else:
			var head := _label("???  (Era %d)" % info.era, 13)
			head.modulate = DIM
			_body.add_child(head)
			_body.add_child(_small("Ainda não encontrado.", DIM))
		_body.add_child(_gap(4))
	_body.add_child(_small("Outros manuais (química, rádio, mecânica) chegam com as próximas eras.", DIM))


# --- Pistas --------------------------------------------------------------------------

func _clues() -> void:
	var list: Array = Progress.i.clues
	if list.is_empty():
		_body.add_child(_small("Nenhuma pista ainda. O rádio e os manuais deixam anotações aqui.", DIM))
		return
	for k in range(list.size() - 1, -1, -1):
		var c: Dictionary = list[k]
		var head := _label("Dia %d, %02d:%02d" % [c.day, int(c.hour), int(fmod(c.hour, 1.0) * 60.0)], 11)
		head.modulate = GOLD
		_body.add_child(head)
		_body.add_child(_small(c.text, Color(1, 1, 1, 0.85)))
		_body.add_child(_gap(3))


# --- Peças ---------------------------------------------------------------------------

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label


func _small(text: String, color: Color) -> Label:
	var label := _label(text, 11)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(300, 0)
	label.modulate = color
	return label


func _gap(h: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, h)
	return gap


func close() -> void:
	player.ui_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("journal") or event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		close()
