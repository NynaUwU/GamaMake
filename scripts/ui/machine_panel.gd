class_name MachinePanel
extends PanelContainer
## Mirando uma máquina/estação: painel pequeno ao lado da mira no lugar da frase
## comprida embaixo dela. Monta a partir do texto da própria máquina
## (get_interact_text), separando:
##   título   nome da máquina
##   linhas   estado; com barra quando tem "N%" ou "a de b" / "a/b"; com o ícone
##            quando começa com "N Item" (3 Trigo, 1 Farinha...)
##   teclas   [E] ..., [segure E] ..., clique: ...
##   dica     o que vem entre parênteses
## Assim toda máquina nova já aparece no painel sem código a mais.

## Estes ficam com o texto de sempre (curto) ou têm painel próprio (PlantPanel).
const EXCLUDE := ["pot_small", "pot_wide", "bed", "ground", "tree", "flag", "stairs", "fence", "gate",
	"spikes", "beartrap", "barbed", "mine", "drawboard", "chest", "airdrop", "blast_stack"]
const WARN := Color(1.0, 0.45, 0.35)

var player: Player
var _box: VBoxContainer
var _text := ""
var _timer := 0.0
static var _by_name := {} # nome de item -> id (para o ícone)


func setup(p: Player) -> void:
	player = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = 40.0
	offset_top = -40.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.11, 0.8)
	style.set_border_width_all(1)
	style.border_color = Color(0.45, 0.45, 0.47)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 3)
	add_child(_box)
	visible = false


## A máquina mirada agora (null = nada que use o painel).
func target() -> PlacedObject:
	var raw: Variant = player.get("_interact_target")
	var obj: PlacedObject = raw as PlacedObject if is_instance_valid(raw) else null
	if obj == null or obj.kind in EXCLUDE or obj.is_farm() or obj.kind in Cooking.KINDS:
		return null
	return obj


func _process(delta: float) -> void:
	var obj := target()
	if obj == null:
		visible = false
		_text = ""
		return
	_timer -= delta
	if visible and _timer > 0.0:
		return
	_timer = 0.2
	var text := obj.get_interact_text()
	visible = true
	if text == _text:
		return
	_text = text
	_rebuild(parse(text))


# --- Texto -> painel --------------------------------------------------------------------

## {title, rows: [[texto, fração (-1 = sem barra), id do ícone], ...], keys: [[tecla, ação]], hint, warn}
static func parse(text: String) -> Dictionary:
	var out := {"title": "", "rows": [], "keys": [], "hint": "", "warn": text.contains("!")}
	var parts: Array[String] = []
	for chunk in text.split("  ", false):
		for seg in chunk.split(" · ", false):
			var t := seg.strip_edges()
			if t.begins_with("·"):
				t = t.substr(1).strip_edges()
			if t != "":
				parts.append(t)
	for k in parts.size():
		var seg := parts[k]
		# Dica entre parênteses no fim: vai para a linha pequena de baixo.
		var paren := seg.find("(")
		if paren >= 0 and seg.ends_with(")"):
			out.hint = seg.substr(paren + 1, seg.length() - paren - 2)
			seg = seg.substr(0, paren).strip_edges()
			if seg == "":
				continue
		if seg.begins_with("["):
			var close := seg.find("]")
			var inside := seg.substr(1, close - 1)
			var label := seg.substr(close + 1).strip_edges()
			var key := inside
			if label == "":
				# "[segure E com a ferramenta na mão]" / "[segure E: enche garrafas]"
				var at := inside.find(" E")
				key = inside.substr(0, at + 2) if at >= 0 else inside
				label = inside.substr(key.length()).trim_prefix(":").strip_edges()
			if k == 0 and out.title == "":
				# "[E] Caldeira · ..." : o nome vem junto com a tecla.
				var colon := label.find(":")
				out.title = label.substr(0, colon) if colon >= 0 else label
				if colon >= 0:
					out.rows.append(_row(label.substr(colon + 1).strip_edges()))
				out.keys.append([key, "abrir" if label.length() < 40 else "usar"])
			else:
				out.keys.append([key, label])
			continue
		if seg.begins_with("clique"):
			var colon := seg.find(":")
			out.keys.append(["clique", seg.substr(colon + 1).strip_edges() if colon >= 0 else seg.substr(6).strip_edges()])
			continue
		if k == 0 and out.title == "":
			var colon := seg.find(":")
			if colon >= 0:
				out.title = seg.substr(0, colon)
				var rest := seg.substr(colon + 1).strip_edges()
				if rest != "":
					out.rows.append(_row(rest))
			else:
				# "Fornalha de pedra 54%" / "Eixo girando": número/estado no fim vira linha.
				var re := RegEx.create_from_string("^(.*?)\\s+(\\d+%|girando|parado)$")
				var m := re.search(seg)
				if m:
					out.title = m.get_string(1)
					out.rows.append(_row(m.get_string(2)))
				else:
					out.title = seg
			continue
		out.rows.append(_row(seg))
	return out


## Uma linha: texto, fração da barra (se tiver número) e ícone (se começar com "N Item").
static func _row(text: String) -> Array:
	var frac := -1.0
	var re_pct := RegEx.create_from_string("(\\d+)%")
	var re_of := RegEx.create_from_string("(\\d+(?:[.,]\\d+)?)\\s*(?:de|/)\\s*(\\d+)")
	var m := re_of.search(text)
	if m and float(m.get_string(2)) > 0.0:
		frac = clampf(float(m.get_string(1).replace(",", ".")) / float(m.get_string(2)), 0.0, 1.0)
	else:
		m = re_pct.search(text)
		if m:
			frac = clampf(float(m.get_string(1)) / 100.0, 0.0, 1.0)
	var icon: StringName = &""
	var re_item := RegEx.create_from_string("^(\\d+)\\s+(.+)$")
	m = re_item.search(text)
	if m:
		icon = item_by_name(m.get_string(2))
	return [text, frac, icon]


static func item_by_name(name: String) -> StringName:
	if _by_name.is_empty():
		for id in ItemDB.ITEMS:
			_by_name[ItemDB.display_name(id).to_lower()] = id
	return _by_name.get(name.to_lower(), &"")


func _rebuild(info: Dictionary) -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = info.title
	title.add_theme_font_size_override("font_size", 11)
	title.modulate = WARN if info.warn else Color(1, 0.9, 0.7)
	_box.add_child(title)
	var icons := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("ItemIcons")
	for row: Array in info.rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		_box.add_child(line)
		if row[2] != &"" and icons and icons.has_method("get_icon"):
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(18, 18)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.texture = icons.get_icon(row[2])
			line.add_child(icon)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 1)
		line.add_child(column)
		var label := Label.new()
		label.text = row[0]
		label.add_theme_font_size_override("font_size", 10)
		column.add_child(label)
		if row[1] >= 0.0:
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(110, 5)
			bar.show_percentage = false
			bar.value = row[1] * 100.0
			var fill := StyleBoxFlat.new()
			fill.bg_color = Color(0.35, 0.65, 0.95) if row[0].contains("água") else (Color(1.0, 0.6, 0.25) if row[1] > 0.85 and row[0].contains("pressão") else Color(0.45, 0.8, 0.35))
			var bg := StyleBoxFlat.new()
			bg.bg_color = Color(0, 0, 0, 0.6)
			bar.add_theme_stylebox_override("fill", fill)
			bar.add_theme_stylebox_override("background", bg)
			column.add_child(bar)
	if info.hint != "":
		var hint := Label.new()
		hint.text = info.hint
		hint.add_theme_font_size_override("font_size", 9)
		hint.modulate = Color(0.75, 0.75, 0.75)
		_box.add_child(hint)
	if not info.keys.is_empty():
		var keys := HFlowContainer.new()
		keys.add_theme_constant_override("h_separation", 6)
		keys.custom_minimum_size.x = 120
		_box.add_child(keys)
		for pair: Array in info.keys:
			var chip := HBoxContainer.new()
			chip.add_theme_constant_override("separation", 3)
			var key := Label.new()
			key.text = pair[0]
			key.add_theme_font_size_override("font_size", 9)
			var key_style := StyleBoxFlat.new()
			key_style.bg_color = Color(0.85, 0.82, 0.7)
			key_style.set_content_margin_all(1)
			key_style.content_margin_left = 3
			key_style.content_margin_right = 3
			key.add_theme_stylebox_override("normal", key_style)
			key.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
			chip.add_child(key)
			var action := Label.new()
			action.text = pair[1]
			action.add_theme_font_size_override("font_size", 9)
			chip.add_child(action)
			keys.add_child(chip)
	size = Vector2.ZERO
	reset_size()
