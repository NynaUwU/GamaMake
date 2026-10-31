class_name StatusArcs
extends Control
## Vida, stamina e fome como um quarto de círculo no canto de baixo à esquerda:
##   por fora  stamina (amarelo)
##   no meio   vida (vermelho; pisca quando baixa)
##   por dentro fome (laranja)
## Cada arco esvazia da ponta de cima para a de baixo (a parte cheia fica
## encostada na borda de baixo da tela).

const RADII := [74.0, 61.0, 48.0] ## stamina, vida, fome
const WIDTHS := [6.0, 9.0, 6.0]
const COLORS := [Color(0.95, 0.82, 0.25), Color(0.85, 0.16, 0.12), Color(0.9, 0.52, 0.15)]
const MARGIN := 8.0

var values := [1.0, 1.0, 1.0] ## 0..1 (stamina, vida, fome)
var _shown := [1.0, 1.0, 1.0]
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = RADII[0] + MARGIN + WIDTHS[0]
	offset_top = -(RADII[0] + MARGIN + WIDTHS[0])
	offset_bottom = 0.0


func set_value(index: int, current: float, maximum: float) -> void:
	values[index] = clampf(current / maxf(maximum, 0.001), 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	for i in 3:
		_shown[i] = lerpf(_shown[i], values[i], 1.0 - exp(-10.0 * delta))
	queue_redraw()


func _draw() -> void:
	var corner := Vector2(MARGIN, size.y - MARGIN)
	# Ângulos em tela: -PI/2 = para cima (borda esquerda), 0 = para a direita (borda de baixo).
	for i in 3:
		var r: float = RADII[i]
		var w: float = WIDTHS[i]
		draw_arc(corner, r, -PI / 2, 0.0, 40, Color(0, 0, 0, 0.55), w + 3.0, true)
		draw_arc(corner, r, -PI / 2, 0.0, 40, COLORS[i].darkened(0.7), w, true)
		var fill: float = _shown[i]
		if fill > 0.005:
			var color: Color = COLORS[i]
			if i == 1 and fill < 0.3:
				color = color.lightened(0.35 * (0.5 + 0.5 * sin(_time * 8.0))) # vida baixa: pisca
			draw_arc(corner, r, -fill * PI / 2, 0.0, maxi(4, int(40 * fill)), color, w, true)
	# Letrinha na ponta de cima de cada arco (S, V, F).
	var font := get_theme_default_font()
	var labels := ["S", "V", "F"]
	for i in 3:
		var at := corner + Vector2(0, -RADII[i]) + Vector2(WIDTHS[i] * 0.5 + 2.0, 3.0)
		draw_string(font, at, labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLORS[i].lightened(0.3))
