class_name JournalUI
extends CanvasLayer
## Diário do jogador (tecla J): guia das eras (objetivos de cada era, como as
## quests do SevTech), árvore de receitas descobertas por estação, manuais lidos
## e o que liberam, e as pistas anotadas (rádio, manuais). Só leitura.

const TABS := ["Eras", "Receitas", "Manuais", "Pistas"]
const OK := Color(0.45, 0.85, 0.4)
const DIM := Color(1, 1, 1, 0.45)
const GOLD := Color(0.95, 0.8, 0.35)
## Estações na ordem da árvore (a mão primeiro; as do fim são as mais avançadas).
const STATIONS := ["mao", "mesa", "fornalha", "fornalha_pedra", "forja", "forno", "alto_forno", "torno", "prensa", "trefiladora", "destilaria"]

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
	var column := LegacyGUI.box(center, "Diário", 560.0)
	_title = column.get_child(0) as Label
	_tabs = HBoxContainer.new()
	column.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(540, 340)
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
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	match tab:
		"Eras": _eras()
		"Receitas": _recipes()
		"Manuais": _manuals()
		"Pistas": _clues()
	_scroll.scroll_vertical = 0


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

func _recipes() -> void:
	var p := Progress.i
	var total := 0
	var known := 0
	for station in STATIONS:
		var list: Array = CraftingUI.recipes_for(station)
		if list.is_empty():
			continue
		var seen := list.filter(func(r): return p.recipes.has(r.id))
		total += list.size()
		known += seen.size()
		var name: String = CraftingUI.TITLES.get(station, station)
		var head := _label("%s  (%d de %d)" % [name, seen.size(), list.size()], 13)
		head.modulate = GOLD if not seen.is_empty() else DIM
		_body.add_child(head)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		_body.add_child(flow)
		for r: Dictionary in list:
			flow.add_child(_recipe_icon(r, p.recipes.has(r.id)))
		_body.add_child(_gap(4))
	var summary := _small("Receitas descobertas: %d de %d. Fabricar, pegar o item ou ler o manual descobre a receita." % [known, total], Color(1, 1, 1, 0.8))
	_body.add_child(summary)
	_body.move_child(summary, 0)


func _recipe_icon(r: Dictionary, seen: bool) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(34, 34)
	var style := StyleBoxFlat.new()
	style.bg_color = LegacyGUI.SLOT
	style.set_border_width_all(1)
	style.border_color = Color(0.42, 0.42, 0.44)
	slot.add_theme_stylebox_override("panel", style)
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 3
	icon.offset_top = 3
	icon.offset_right = -3
	icon.offset_bottom = -3
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icons := get_tree().root.get_node_or_null("ItemIcons")
	if icons and icons.has_method("get_icon"):
		icon.texture = icons.get_icon(r.id)
	slot.add_child(icon)
	var locked := not Progress.knows(r.get("manual", ""))
	if not seen:
		icon.modulate = Color(0, 0, 0, 0.85) # silhueta: ainda não descobriu
		slot.tooltip_text = "???" + ("\nPrecisa: %s" % Progress.MANUALS[StringName(r.manual)].title if locked else "")
	else:
		icon.modulate = Color(1, 1, 1, 0.45) if locked else Color.WHITE
		slot.tooltip_text = "%s%s\n%s%s" % [ItemDB.display_name(r.id), " x%d" % r.amount if r.get("amount", 1) > 1 else "",
			Builder.cost_text(r.cost, player.inventory), "\nPrecisa: %s" % Progress.MANUALS[StringName(r.manual)].title if locked else ""]
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
	_body.add_child(_small("Outros manuais (soldagem, química, rádio, mecânica) chegam com as próximas eras.", DIM))


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
