class_name ForgeMinigame
extends Minigame
## Forja com temperatura por cor (Era 1). A barra esquenta no carvão (segure o
## botão direito para soprar o fole) e muda de cor pelo shader de temperatura
## (forge_heat_2d: frio -> vermelho -> cereja -> laranja -> amarelo -> branco).
## Espaço leva a peça para a bigorna, onde ela esfria; clique martela.
##   na faixa certa do metal  golpe bom (quanto mais no meio da faixa, melhor)
##   fora da faixa            racha (3 rachaduras = peça perdida)
##   branco no fogo           queima (tira acabamento)
## Qualidade = média dos golpes - rachaduras - queima. Com o Manual do ferreiro
## lido, aparece a tabela de cores com a faixa marcada.
##
## Contexto: {"item": peça, "metal": barra, "hits": golpes, "chart": tabela}

const METALS := {
	&"barra_ferro": {"band": Vector2(0.58, 0.82), "cool": 0.07, "cold": Color(0.26, 0.25, 0.25), "hint": "do laranja ao amarelo"},
	&"barra_aco": {"band": Vector2(0.62, 0.86), "cool": 0.065, "cold": Color(0.44, 0.45, 0.47), "hint": "do laranja-claro ao amarelo"},
	&"barra_cobre": {"band": Vector2(0.36, 0.62), "cool": 0.09, "cold": Color(0.66, 0.38, 0.22), "hint": "do vermelho-cereja ao laranja"},
}
const SHAPES := {&"espada": "blade", &"capacete": "plate", &"peitoral": "plate"}
const HEAT_RATE := 0.1 ## por segundo no carvão
const BELLOWS_RATE := 0.24 ## a mais com o fole
const HIT_COOL := 0.035 ## cada martelada esfria um pouco
const HIT_DELAY := 0.32
const MAX_CRACKS := 3
const BURN_AT := 0.94
const FIRE_AT := Vector2(132, 124)
const ANVIL_AT := Vector2(452, 141)
const VIEW := Vector2(600, 250)

var metal := {}
var temp := 0.12
var in_fire := true
var bellows := false
var manual_input := true ## false nos testes (o fole vem de bellows)
var hits := 0
var need := 8
var cracks := 0
var score := 0.0
var burn := 0.0
var _cooldown := 0.0
var _swing := 0.0
var _sparks: Array = [] # {"p", "v", "life", "c"}
var _msg := ""
var _msg_time := 0.0
var _result := -2.0 # -2 = jogando; senão a qualidade esperando o fim da mensagem
var _end_time := 0.0
var _quit_armed := false
var _piece: HeatPiece
var _view: Control
var _fx: FxLayer
var _hits_bar: ProgressBar
var _finish_bar: ProgressBar
var _crack_boxes: Array[Panel] = []
var _mat: ShaderMaterial


func _ready() -> void:
	metal = METALS.get(StringName(context.get("metal", "barra_ferro")), METALS[&"barra_ferro"])
	need = int(context.get("hits", 8))
	var item := StringName(context.get("item", "machado"))
	var column := frame("Forja: %s" % ItemDB.display_name(item), VIEW.x + 20.0)
	_view = Control.new()
	_view.custom_minimum_size = VIEW
	_view.clip_contents = true
	_view.draw.connect(_draw_view)
	column.add_child(_view)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/forge_heat_2d.gdshader")
	var cold: Color = metal.cold
	_mat.set_shader_parameter("cold_color", Vector3(cold.r, cold.g, cold.b))
	_mat.set_shader_parameter("flicker", 1.0)
	_piece = HeatPiece.new()
	_piece.shape = SHAPES.get(item, "head")
	_piece.material = _mat
	_piece.position = FIRE_AT
	_view.add_child(_piece)
	_fx = FxLayer.new()
	_fx.game = self
	_fx.size = VIEW
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(_fx)
	_build_info(column)
	Sfx.play("bellows", -6.0, 1.0)


func _build_info(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	_hits_bar = _bar(row, "Golpes", Color(0.95, 0.75, 0.3))
	var cracks_box := HBoxContainer.new()
	cracks_box.add_theme_constant_override("separation", 3)
	var label := Label.new()
	label.text = "Rachaduras"
	label.add_theme_font_size_override("font_size", 11)
	cracks_box.add_child(label)
	for k in MAX_CRACKS:
		var box := Panel.new()
		box.custom_minimum_size = Vector2(11, 11)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cracks_box.add_child(box)
		_crack_boxes.append(box)
	row.add_child(cracks_box)
	_finish_bar = _bar(row, "Acabamento", Color(0.45, 0.85, 0.4))
	var band: Vector2 = metal.band
	if context.get("chart", false):
		# Tabela de cores do manual: a mesma rampa do shader com a faixa marcada.
		var chart := Control.new()
		chart.custom_minimum_size = Vector2(VIEW.x, 30)
		column.add_child(chart)
		var strip := ColorRect.new()
		var strip_mat := ShaderMaterial.new()
		strip_mat.shader = _mat.shader
		strip_mat.set_shader_parameter("chart", 1.0)
		strip_mat.set_shader_parameter("cold_color", _mat.get_shader_parameter("cold_color"))
		strip.material = strip_mat
		strip.position = Vector2(60, 18)
		strip.size = Vector2(VIEW.x - 120, 10)
		chart.add_child(strip)
		var mark := ColorRect.new() # faixa certa do metal, logo acima da tabela
		mark.color = Color(1, 1, 1, 0.9)
		mark.position = Vector2(60 + band.x * strip.size.x, 14)
		mark.size = Vector2((band.y - band.x) * strip.size.x, 3)
		chart.add_child(mark)
		for part in [["frio", 0.0, HORIZONTAL_ALIGNMENT_RIGHT], ["bata aqui", (band.x + band.y) * 0.5, HORIZONTAL_ALIGNMENT_CENTER], ["branco", 1.0, HORIZONTAL_ALIGNMENT_LEFT]]:
			var text := Label.new()
			text.text = part[0]
			text.add_theme_font_size_override("font_size", 9)
			text.horizontal_alignment = part[2]
			text.size = Vector2(50, 12)
			var x: float = 60 + part[1] * strip.size.x
			text.position = Vector2(x - 54, 16) if part[1] == 0.0 else (Vector2(x + 4, 16) if part[1] == 1.0 else Vector2(x - 25, 0))
			chart.add_child(text)
	else:
		var hint := Label.new()
		hint.text = "Bata com o metal %s. Frio demais racha; branco queima. (O Manual do ferreiro tem a tabela de cores.)" % metal.hint
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		hint.custom_minimum_size = Vector2(VIEW.x, 0)
		hint.add_theme_font_size_override("font_size", 10)
		hint.modulate = Color(1, 1, 1, 0.75)
		column.add_child(hint)
	var keys := Label.new()
	keys.text = "Clique: martelar · Espaço: fogo / bigorna · Botão direito (segurar): fole · Esc: desistir"
	keys.add_theme_font_size_override("font_size", 10)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.modulate = Color(1, 1, 1, 0.6)
	column.add_child(keys)


func _bar(parent: Control, text: String, color: Color) -> ProgressBar:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	parent.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(110, 8)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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


# --- Regras --------------------------------------------------------------------------

## Avança o tempo: esquenta no carvão (mais com o fole), esfria na bigorna.
func step(delta: float) -> void:
	if in_fire:
		temp = minf(temp + (HEAT_RATE + (BELLOWS_RATE if bellows else 0.0)) * delta, 1.0)
		if temp >= BURN_AT:
			burn += delta
			if fmod(burn, 1.0) < delta:
				_say("Branco: está queimando! Espaço tira do fogo")
	else:
		temp = maxf(temp - float(metal.cool) * delta, 0.0)
	_cooldown -= delta


## Clique na bigorna. Devolve "ok", "cold", "hot" ou "" (não deu para bater).
func strike() -> String:
	if in_fire or _cooldown > 0.0 or _result > -2.0:
		if in_fire and _result <= -2.0:
			_say("A peça está no fogo: Espaço leva para a bigorna")
		return ""
	_cooldown = HIT_DELAY
	_swing = 1.0
	_quit_armed = false
	var band: Vector2 = metal.band
	var result := "ok"
	if temp < band.x or temp > band.y:
		cracks += 1
		result = "cold" if temp < band.x else "hot"
		_burst(10, Color(0.2, 0.12, 0.08), 0.6)
		Sfx.play("crack", -2.0, 1.0)
		if cracks >= MAX_CRACKS:
			_end(0.0, "Rachou de vez! A peça se perdeu (sobra sucata).")
		else:
			_say("Frio demais: rachou!" if result == "cold" else "Quente demais: rachou!")
	else:
		var mid := (band.x + band.y) * 0.5
		var half := (band.y - band.x) * 0.5
		score += 1.0 - absf(temp - mid) / half * 0.45
		hits += 1
		_burst(14, Color(1.0, 0.75, 0.3), 1.0)
		Sfx.play("anvil", -2.0, randf_range(0.95, 1.05))
		if hits >= need:
			_end(quality(), "Pronto! Qualidade %d%%" % int(quality() * 100.0))
	temp = maxf(temp - HIT_COOL, 0.0)
	return result


## Espaço: do fogo para a bigorna e de volta.
func toggle() -> void:
	if _result > -2.0:
		return
	in_fire = not in_fire
	var tween := create_tween()
	tween.tween_property(_piece, "position", FIRE_AT if in_fire else ANVIL_AT, 0.18)
	Sfx.play("knock", -10.0, 1.6)


## Qualidade até agora (0 = rachou de vez).
func quality() -> float:
	if cracks >= MAX_CRACKS:
		return 0.0
	if hits == 0:
		return 0.0
	return clampf(score / hits - cracks * 0.12 - minf(burn * 0.12, 0.4), 0.05, 1.0)


func _end(q: float, text: String) -> void:
	_result = q
	_end_time = 1.6
	_say(text, 2.0)


func _say(text: String, time := 1.4) -> void:
	_msg = text
	_msg_time = time


func _burst(count: int, color: Color, speed: float) -> void:
	for k in count:
		var a := randf_range(-PI * 0.95, -PI * 0.05)
		_sparks.append({"p": _piece.position + Vector2(randf_range(-20, 20), -4), "v": Vector2(cos(a), sin(a)) * randf_range(60, 180) * speed,
			"life": randf_range(0.3, 0.7), "c": color})


# --- Loop ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _result > -2.0:
		_end_time -= delta
		if _end_time <= 0.0:
			finish(_result)
	if manual_input:
		bellows = in_fire and (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_SHIFT))
	if _result <= -2.0:
		step(delta)
	_swing = maxf(_swing - delta * 4.0, 0.0)
	_msg_time -= delta
	if in_fire and bellows and randf() < delta * 14.0:
		_sparks.append({"p": FIRE_AT + Vector2(randf_range(-50, 50), 0), "v": Vector2(randf_range(-10, 10), randf_range(-90, -40)), "life": 0.6, "c": Color(1.0, 0.6, 0.2)})
	for s in _sparks:
		s.p += s.v * delta
		s.v.y += 260.0 * delta
		s.life -= delta
	_sparks = _sparks.filter(func(s): return s.life > 0.0)
	_mat.set_shader_parameter("temperature", temp)
	_mat.set_shader_parameter("cracks", float(cracks))
	_piece.progress = clampf(float(hits) / need, 0.0, 1.0)
	_piece.queue_redraw()
	_hits_bar.value = float(hits) / need
	_finish_bar.value = quality()
	for k in _crack_boxes.size():
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.85, 0.25, 0.2) if k < cracks else Color(0, 0, 0, 0.35)
		style.set_border_width_all(1)
		style.border_color = Color(0.7, 0.7, 0.7)
		_crack_boxes[k].add_theme_stylebox_override("panel", style)
	_view.queue_redraw()
	_fx.queue_redraw()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		strike()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if hits == 0 and cracks == 0:
				finish(CANCELLED) # nem começou: nada é gasto
			elif _quit_armed:
				finish(0.0)
			else:
				_quit_armed = true
				_say("Esc de novo: larga a peça (perde o metal)", 2.0)


# --- Desenho -------------------------------------------------------------------------

## Oficina: parede de tijolo, forja com coifa e carvão aceso à esquerda, fole, bigorna
## no toco à direita.
func _draw_view() -> void:
	var v := _view
	v.draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.09, 0.07, 0.06))
	for row in 9:
		for col in 12:
			var shade := 0.11 + 0.03 * float((row * 7 + col * 3) % 4) / 3.0
			v.draw_rect(Rect2(col * 52 + (26 if row % 2 else 0) - 26, row * 24, 50, 22), Color(shade * 1.3, shade * 0.85, shade * 0.7))
	v.draw_rect(Rect2(0, 222, VIEW.x, 28), Color(0.13, 0.1, 0.08))
	# Brilho do fogo na parede.
	var flick := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.013) + (0.35 if bellows else 0.0)
	for k in 6:
		v.draw_circle(FIRE_AT + Vector2(0, -6), 150.0 - k * 22.0, Color(1.0, 0.45, 0.1, 0.035 * flick))
	# Coifa e chaminé.
	v.draw_colored_polygon(PackedVector2Array([Vector2(40, 70), Vector2(224, 70), Vector2(170, 18), Vector2(94, 18)]), Color(0.16, 0.15, 0.15))
	v.draw_rect(Rect2(108, 0, 48, 20), Color(0.13, 0.12, 0.12))
	v.draw_rect(Rect2(40, 66, 184, 6), Color(0.22, 0.2, 0.19))
	# Corpo da forja (tijolo) e o leito de carvão.
	v.draw_rect(Rect2(32, 132, 200, 92), Color(0.36, 0.17, 0.11))
	for row in 4:
		for col in 5:
			v.draw_rect(Rect2(34 + col * 40 + (20 if row % 2 else 0) - (20 if row % 2 and col == 4 else 0), 134 + row * 22, 38, 20), Color(0.42, 0.2, 0.13).darkened(0.08 * ((row + col) % 3)))
	v.draw_rect(Rect2(44, 118, 176, 18), Color(0.05, 0.04, 0.04))
	var t := Time.get_ticks_msec() * 0.001
	for k in 26:
		var x := 50.0 + k * 6.5
		var glow := 0.55 + 0.45 * sin(t * (3.0 + k % 5) + k) * (1.0 if bellows else 0.6)
		var c := Color(1.0, 0.35 + 0.35 * glow, 0.08, 1.0).lerp(Color(0.25, 0.05, 0.02), 0.6 - glow * 0.6)
		v.draw_rect(Rect2(x, 121 + (k * 7) % 9, 7, 6), c)
	# Fole de couro na lateral (aperta quando sopra).
	var squeeze := 0.5 + 0.5 * sin(t * 9.0) if bellows else 1.0
	var top := 150.0 - 22.0 * squeeze
	v.draw_colored_polygon(PackedVector2Array([Vector2(-4, 168), Vector2(30, 160), Vector2(30, 176), Vector2(-4, top + 40)]), Color(0.32, 0.2, 0.12))
	v.draw_line(Vector2(-4, top + 38), Vector2(30, 160), Color(0.2, 0.12, 0.07), 3.0)
	# Toco e bigorna.
	v.draw_rect(Rect2(410, 196, 84, 30), Color(0.33, 0.21, 0.12))
	v.draw_rect(Rect2(410, 196, 84, 4), Color(0.42, 0.28, 0.16))
	var anvil := PackedVector2Array([Vector2(370, 150), Vector2(520, 150), Vector2(530, 156), Vector2(504, 166), Vector2(478, 172),
		Vector2(478, 186), Vector2(500, 196), Vector2(404, 196), Vector2(426, 186), Vector2(426, 172), Vector2(408, 166), Vector2(392, 160)])
	v.draw_colored_polygon(anvil, Color(0.19, 0.19, 0.21))
	v.draw_rect(Rect2(392, 150, 128, 3), Color(0.42, 0.42, 0.45))
	v.draw_colored_polygon(PackedVector2Array([Vector2(370, 150), Vector2(396, 150), Vector2(396, 158)]), Color(0.27, 0.27, 0.29)) # bico
	# Tenaz encostada.
	v.draw_line(Vector2(560, 224), Vector2(540, 120), Color(0.15, 0.15, 0.16), 3.0)
	v.draw_line(Vector2(568, 224), Vector2(544, 120), Color(0.15, 0.15, 0.16), 3.0)


## Peça (com o shader de temperatura): começa barra e vai tomando forma a cada golpe.
class HeatPiece extends Control:
	var shape := "head"
	var progress := 0.0

	func _draw() -> void:
		var p := progress
		var pts: PackedVector2Array
		match shape:
			"blade": # espada: comprida, fina, ganha ponta
				var w := lerpf(72.0, 124.0, p)
				var h := lerpf(14.0, 9.0, p)
				var tip := 20.0 * p
				pts = PackedVector2Array([Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5 - tip, -h * 0.5), Vector2(w * 0.5, 0), Vector2(w * 0.5 - tip, h * 0.5), Vector2(-w * 0.5, h * 0.5)])
			"plate": # chapa de armadura: larga e fina
				var w2 := lerpf(72.0, 96.0, p)
				var h2 := lerpf(14.0, 26.0, p)
				pts = PackedVector2Array([Vector2(-w2 * 0.5, -h2 * 0.5), Vector2(w2 * 0.5, -h2 * 0.5), Vector2(w2 * 0.5, h2 * 0.5), Vector2(-w2 * 0.5, h2 * 0.5)])
			_: # cabeça de ferramenta: abre num gume
				var w3 := lerpf(72.0, 62.0, p)
				var h3 := 14.0
				var edge := lerpf(14.0, 34.0, p)
				pts = PackedVector2Array([Vector2(-w3 * 0.5, -h3 * 0.5), Vector2(w3 * 0.5, -edge * 0.5), Vector2(w3 * 0.5, edge * 0.5), Vector2(-w3 * 0.5, h3 * 0.5)])
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in pts:
			lo = lo.min(q)
			hi = hi.max(q)
		var uvs := PackedVector2Array()
		for q in pts:
			uvs.append((q - lo) / (hi - lo))
		draw_colored_polygon(pts, Color.WHITE, uvs)


## Martelo e faíscas por cima da peça.
class FxLayer extends Control:
	var game: ForgeMinigame

	func _draw() -> void:
		for s in game._sparks:
			draw_rect(Rect2(s.p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(s.c, clampf(s.life * 2.0, 0.0, 1.0)))
		if not game.in_fire:
			# Martelo: cabo saindo da direita; desce na peça a cada golpe.
			var pivot := Vector2(600, 118)
			var down := atan2(ANVIL_AT.y - 10.0 - pivot.y, ANVIL_AT.x - pivot.x)
			var a := lerpf(down + 0.85, down, game._swing)
			var dir := Vector2(cos(a), sin(a))
			var head := pivot + dir * 140.0
			draw_line(pivot, head, Color(0.4, 0.27, 0.15), 5.0)
			var side := Vector2(-dir.y, dir.x)
			var c := head - dir * 4.0
			draw_colored_polygon(PackedVector2Array([c - side * 15 - dir * 9, c + side * 15 - dir * 9, c + side * 15 + dir * 9, c - side * 15 + dir * 9]), Color(0.3, 0.3, 0.32))
		if game._msg_time > 0.0 and game._msg != "":
			var font := get_theme_default_font()
			var width := font.get_string_size(game._msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var at := Vector2((size.x - width) * 0.5, 34)
			draw_rect(Rect2(at - Vector2(8, 16), Vector2(width + 16, 22)), Color(0, 0, 0, 0.6 * clampf(game._msg_time * 2.0, 0.0, 1.0)))
			draw_string(font, at, game._msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.6, clampf(game._msg_time * 2.0, 0.0, 1.0)))
