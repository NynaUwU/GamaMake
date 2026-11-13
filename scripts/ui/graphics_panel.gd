class_name GraphicsPanel
extends RefCounted
## Menu de gráficos (ESC > Gráficos e menu principal > Gráficos). Em cima a
## predefinição (Clássico = o visual de antes da atualização gráfica, Baixa, Média,
## Alta); embaixo cada opção solta em duas colunas: "Imagem" (o que pesa na placa de
## vídeo) e "Tela" (resolução do 3D, filtro retrô, alcance, FOV, janela). Tudo vale na
## hora e fica salvo em user://graphics.cfg (Look).

const IMAGE_KEYS := ["shadows", "ssao", "glow", "detail", "color_fix", "tonemap", "grass", "particles"]
const SCREEN_KEYS := ["lines", "retro", "vignette", "view", "fov", "grid", "vsync", "fullscreen", "fps"]

var box: Control ## a caixa (quem abriu mostra/esconde)
var _preset: OptionButton
var _controls := {} # chave -> OptionButton/CheckButton
var _hint: Label
var _refreshing := false


func _init(parent: Control, back: Callable) -> void:
	var column := LegacyGUI.box(parent, "Gráficos", 640.0)
	box = column.get_parent()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	column.add_child(top)
	var label := Label.new()
	label.text = "Predefinição"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	_preset = OptionButton.new()
	_preset.focus_mode = Control.FOCUS_NONE
	_preset.custom_minimum_size = Vector2(230, 0)
	for name in Look.PRESET_ORDER:
		_preset.add_item(Look.PRESET_NAMES[name])
	_preset.add_item(Look.PRESET_NAMES.custom)
	_preset.set_item_disabled(Look.PRESET_ORDER.size(), true) # só aparece quando mexem nas opções
	_preset.item_selected.connect(func(index: int):
		if _refreshing or index >= Look.PRESET_ORDER.size():
			return
		Look.set_preset(Look.PRESET_ORDER[index])
		refresh()
		_say(_preset_hint(Look.PRESET_ORDER[index])))
	top.add_child(_preset)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	for side in [["Imagem", IMAGE_KEYS], ["Tela", SCREEN_KEYS]]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var header := Label.new()
		header.text = side[0]
		header.add_theme_font_size_override("font_size", 11)
		header.modulate = Color(1, 1, 1, 0.6)
		col.add_child(header)
		for key: String in side[1]:
			_add_option(col, key)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.modulate = Color(0.95, 0.85, 0.45)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.custom_minimum_size = Vector2(0, 30)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint)
	LegacyGUI.button(column, "Voltar", back)
	box.visible = false
	refresh()


func _option(key: String) -> Array:
	for o in Look.OPTIONS:
		if o[0] == key:
			return o
	return []


func _add_option(parent: Control, key: String) -> void:
	var o := _option(key)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.tooltip_text = o[3]
	parent.add_child(line)
	var label := Label.new()
	label.text = o[1]
	label.add_theme_font_size_override("font_size", 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.tooltip_text = o[3]
	line.add_child(label)
	var values: Array = o[2]
	if values.is_empty():
		var check := CheckButton.new()
		check.focus_mode = Control.FOCUS_NONE
		check.tooltip_text = o[3]
		check.toggled.connect(func(on: bool):
			if _refreshing:
				return
			Look.set_setting(key, on)
			refresh()
			_say(o[3]))
		line.add_child(check)
		_controls[key] = check
	else:
		var pick := OptionButton.new()
		pick.focus_mode = Control.FOCUS_NONE
		pick.custom_minimum_size = Vector2(150, 0)
		pick.tooltip_text = o[3]
		for v in values:
			pick.add_item(v[0])
		pick.item_selected.connect(func(index: int):
			if _refreshing:
				return
			Look.set_setting(key, values[index][1])
			refresh()
			_say(o[3]))
		line.add_child(pick)
		_controls[key] = pick


## Põe os controles no que está salvo (depois de trocar a predefinição, por exemplo).
func refresh() -> void:
	_refreshing = true
	var preset: String = Look.get_setting("preset")
	var index := Look.PRESET_ORDER.find(preset)
	_preset.select(index if index >= 0 else Look.PRESET_ORDER.size())
	for key: String in _controls:
		var control: Control = _controls[key]
		var value: Variant = Look.get_setting(key)
		if control is CheckButton:
			(control as CheckButton).button_pressed = bool(value)
		else:
			var values: Array = _option(key)[2]
			var at := 0
			for k in values.size():
				if values[k][1] == value:
					at = k
			(control as OptionButton).select(at)
	_refreshing = false


func _say(text: String) -> void:
	_hint.text = text
	Sfx.play("click", -6.0, 1.2)


static func _preset_hint(name: String) -> String:
	match name:
		"classic":
			return "Como era antes da atualização gráfica: cores lavadas, sem textura PS2, tom Filmic, sem brilho, sem SSAO e sem grama densa."
		"low":
			return "Leve: sombra curta, sem SSAO, sem brilho e sem grama densa."
		"high":
			return "Sombras longas, SSAO cheio, mais grama e mais partículas."
	return "Equilíbrio entre visual e desempenho."


## Texto do botão que abre este menu.
static func button_text() -> String:
	return "Gráficos: %s..." % Look.preset_name()
