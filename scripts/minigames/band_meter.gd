class_name BandMeter
extends Control
## Medidor dos minigames: barra escura com a faixa certa em verde, a zona ruim em
## vermelho (opcional) e o ponteiro branco no valor atual (tudo de 0 a 1).

var value := 0.0
var band := Vector2(0.3, 0.6)
var danger := -1.0 ## daqui para cima é vermelho (-1 = sem zona ruim)


func _init() -> void:
	custom_minimum_size = Vector2(120, 10)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float) -> void:
	value = v
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(band.x * w, 0, (band.y - band.x) * w, h), Color(0.3, 0.75, 0.3, 0.75))
	if danger >= 0.0:
		draw_rect(Rect2(danger * w, 0, (1.0 - danger) * w, h), Color(0.85, 0.25, 0.2, 0.6))
	var x := clampf(value, 0.0, 1.0) * w
	draw_rect(Rect2(x - 1.5, -2, 3, h + 4), Color.WHITE)
