class_name LegacyGUI
extends RefCounted
## Visual dos menus padrão das versões antigas da Unity (GUI.Box / GUI.Button
## do skin embutido): caixa preta translúcida com o título no topo, botões
## cinza em degradê com borda escura e um brilho em cima, campos de texto
## escuros, texto branco pequeno com sombra.

const BG := Color(0.27, 0.27, 0.28, 0.94) ## fundo cinza de todas as caixas/menus
const BG_BORDER := Color(0.5, 0.5, 0.52)
const SLOT := Color(0.17, 0.17, 0.18, 0.95) ## fundo dos slots (inventário, menu de construção)

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 13
	var white := Color(0.95, 0.95, 0.95)
	var shadow := Color(0, 0, 0, 0.7)
	# Botão: degradê cinza (claro em cima), borda escura e cantos arredondados.
	_theme.set_stylebox("normal", "Button", _button_box(Color(0.47, 0.47, 0.47), Color(0.29, 0.29, 0.29)))
	_theme.set_stylebox("hover", "Button", _button_box(Color(0.56, 0.56, 0.56), Color(0.36, 0.36, 0.36)))
	_theme.set_stylebox("pressed", "Button", _button_box(Color(0.24, 0.24, 0.24), Color(0.36, 0.36, 0.36)))
	_theme.set_stylebox("disabled", "Button", _button_box(Color(0.3, 0.3, 0.3, 0.6), Color(0.22, 0.22, 0.22, 0.6)))
	_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_theme.set_color(state, "Button", white)
	_theme.set_color("font_disabled_color", "Button", Color(0.6, 0.6, 0.6))
	_theme.set_color("font_shadow_color", "Button", shadow)
	_theme.set_constant("shadow_offset_x", "Button", 1)
	_theme.set_constant("shadow_offset_y", "Button", 1)
	# Campo de texto: fundo quase preto, borda cinza (mais clara com o foco).
	_theme.set_stylebox("normal", "LineEdit", _flat(Color(0.08, 0.08, 0.08, 0.9), Color(0.42, 0.42, 0.42), 3))
	_theme.set_stylebox("focus", "LineEdit", _flat(Color(0, 0, 0, 0), Color(0.75, 0.75, 0.75), 3))
	_theme.set_color("font_color", "LineEdit", white)
	_theme.set_color("font_placeholder_color", "LineEdit", Color(0.55, 0.55, 0.55))
	_theme.set_color("caret_color", "LineEdit", white)
	_theme.set_color("font_color", "Label", white)
	_theme.set_color("font_shadow_color", "Label", shadow)
	_theme.set_constant("shadow_offset_x", "Label", 1)
	_theme.set_constant("shadow_offset_y", "Label", 1)
	# Caixa (GUI.Box): preta translúcida, cantos arredondados.
	_theme.set_stylebox("panel", "PanelContainer", _flat(BG, BG_BORDER, 6, 14))
	_theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return _theme


## Caixa com o título no topo (como GUI.Box("Título")). Devolve a coluna de dentro.
static func box(parent: Control, title: String, width := 300.0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme = theme()
	panel.custom_minimum_size = Vector2(width, 0)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	column.add_child(gap)
	return column


static func button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 26)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


static func field(parent: Control, label_text: String, value := "", placeholder := "") -> LineEdit:
	if label_text != "":
		var label := Label.new()
		label.text = label_text
		parent.add_child(label)
	var edit := LineEdit.new()
	edit.text = value
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 24)
	parent.add_child(edit)
	return edit


static func _flat(bg: Color, border: Color, radius: int, margin := 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.content_margin_top = margin * 0.6
	style.content_margin_bottom = margin * 0.6
	return style


## Textura do botão desenhada pixel a pixel: degradê, borda escura, linha de
## brilho em cima e cantos de 3 px. Esticada em 9 partes (StyleBoxTexture).
static func _button_box(top: Color, bottom: Color) -> StyleBoxTexture:
	var w := 16
	var h := 24
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var border := Color(0.06, 0.06, 0.06, 0.95)
	for y in h:
		var fill := top.lerp(bottom, float(y) / (h - 1))
		for x in w:
			var color := fill
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				color = border
			elif y == 1:
				color = fill.lightened(0.25) # brilho do topo
			# Cantos arredondados (3 px): fora do raio fica transparente.
			var cx := mini(x, w - 1 - x)
			var cy := mini(y, h - 1 - y)
			if cx < 3 and cy < 3:
				var d := Vector2(2.5 - cx, 2.5 - cy).length()
				if d > 3.0:
					color = Color(0, 0, 0, 0)
				elif d > 2.0:
					color = border
			image.set_pixel(x, y, color)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	style.texture_margin_left = 4
	style.texture_margin_right = 4
	style.texture_margin_top = 4
	style.texture_margin_bottom = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style
