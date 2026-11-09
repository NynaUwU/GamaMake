class_name ChemistryMinigame
extends Minigame
## Bancada química (Era 4): três válvulas e três relógios. A receita pede uma faixa
## (verde) em cada relógio; a reação só anda com o balão quente e o líquido correndo,
## e a qualidade é o quanto os três ponteiros ficaram dentro das faixas enquanto ela
## andava.
##   Gás     chama do queimador: esquenta o balão (devagar: o vidro demora a responder)
##   Alívio  purga do vapor: baixa a pressão (o que sai é perdido no ar)
##   Saída   dosagem para a serpentina: a vazão (e ela também alivia um pouco a pressão)
## A pressão sobe com a temperatura; a vazão sobe com a pressão. Mexer numa válvula
## mexe nos três ponteiros, por isso é preciso acertar o conjunto.
## De tempos em tempos acontece algo (bolha de vapor, corrente de ar, entupiu a saída).
## Vermelho por tempo demais é acidente: pressão estoura a vedação (perde a mistura);
## "risk" = "boom" (pólvora quente) explode; "leak" (ácido) vaza gás tóxico na bancada.
##
## Contexto: {"item", "amount", "chem": {"t", "p", "f", "risk", "hot"}, "obj_id"}

const VIEW := Vector2(680, 320)
const DURATION := 16.0 ## segundos de reação com tudo na faixa (fora dela, mais devagar)
const NAMES := ["Temperatura", "Pressão", "Vazão"]
const VALVE_NAMES := ["Gás", "Alívio", "Saída"]
const KEYS := [[KEY_Q, KEY_A], [KEY_W, KEY_S], [KEY_E, KEY_D]] ## abre / fecha
const TURN_RATE := 0.55 ## volta inteira por segundo segurando a tecla
const DIAL_X := [345.0, 465.0, 585.0]
const DIAL_Y := 110.0
const DIAL_R := 50.0
const VALVE_Y := 240.0
const VALVE_R := 34.0
const PRESSURE_RED := 0.9
const STRESS_RATE := 0.55 ## por segundo no vermelho (1 = acidente)
## Cor do líquido no balão (o produto da receita).
const LIQUID := {&"salitre": Color(0.85, 0.85, 0.78), &"polvora": Color(0.2, 0.2, 0.2), &"combustivel": Color(0.75, 0.68, 0.18),
	&"plastico": Color(0.86, 0.8, 0.55), &"acido": Color(0.7, 0.85, 0.3), &"carvao_ativado": Color(0.25, 0.25, 0.27)}

var valves := [0.0, 0.0, 0.0] ## gás, alívio, saída (0 fechada .. 1 aberta)
var values := [0.05, 0.0, 0.0] ## temperatura, pressão, vazão (0..1, até 1,2 no vermelho)
var bands: Array[Vector2] = [Vector2(0.4, 0.6), Vector2(0.3, 0.5), Vector2(0.3, 0.5)]
var reds := [0.95, PRESSURE_RED, 9.0] ## onde começa o vermelho (vazão não tem)
var risk := ""
var progress := 0.0
var stress := 0.0
var running := false
var calm := false ## testes: sem imprevistos
var manual_input := true ## false nos testes (as válvulas mudam por código)
var _score_sum := 0.0
var _score_time := 0.0
var _clog := 0.0 # segundos com a saída entupida
var _event_in := 4.0
var _time := 0.0
var _result := -2.0
var _end_time := 0.0
var _quit_armed := false
var _msg := ""
var _msg_time := 0.0
var _drag := -1
var _hover := -1
var _bubble_in := 0.0
var _drops: Array = [] # {"y", "v"}
var _puffs: Array = [] # {"p", "r", "life"}
var _view: Control
var _progress: ProgressBar
var _info: Label


func _ready() -> void:
	var chem: Dictionary = context.get("chem", {})
	for k in 3:
		var band: Array = chem.get(["t", "p", "f"][k], [0.4, 0.6])
		bands[k] = Vector2(band[0], band[1])
	risk = chem.get("risk", "")
	reds[0] = float(chem.get("hot", 0.95))
	var column := frame("Reação: %s" % ItemDB.display_name(StringName(context.get("item", "salitre"))), VIEW.x + 20.0)
	_view = Control.new()
	_view.custom_minimum_size = VIEW
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.draw.connect(_draw_view)
	column.add_child(_view)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	row.add_child(_small("Reação"))
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(160, 8)
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress.show_percentage = false
	_progress.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.45, 0.8, 0.35)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	_progress.add_theme_stylebox_override("fill", fill)
	_progress.add_theme_stylebox_override("background", bg)
	row.add_child(_progress)
	_info = _small("")
	row.add_child(_info)
	var keys := Label.new()
	keys.text = "Arraste a válvula para cima/baixo (ou roda do mouse em cima dela; Q/A gás, W/S alívio, E/D saída). Deixe os três ponteiros no verde · Esc: desistir"
	keys.add_theme_font_size_override("font_size", 10)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD
	keys.custom_minimum_size = Vector2(VIEW.x, 0)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.modulate = Color(1, 1, 1, 0.6)
	column.add_child(keys)
	if risk == "boom":
		_say("Pólvora: misture FRIO! Quente demais explode", 3.0)
	elif risk == "leak":
		_say("Ácido: a pressão alta vaza gás (use o alívio)", 3.0)


func _small(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	return label


# --- Regras ------------------------------------------------------------------------------

## Um passo da química (as válvulas já estão onde o jogador deixou).
func step(delta: float) -> void:
	_time += delta
	if _result > -2.0:
		return
	var gas: float = valves[0]
	var relief: float = valves[1]
	var out: float = valves[2] * (0.4 if _clog > 0.0 else 1.0)
	_clog = maxf(_clog - delta, 0.0)
	# Temperatura segue a chama com atraso; o ácido esquenta sozinho quando a reação pega.
	var t_target := 0.04 + 0.96 * gas
	if risk == "leak" and values[0] > bands[0].x:
		t_target += 0.08
	values[0] += (t_target - values[0]) * (1.0 - exp(-delta / 2.2))
	# Pressão: vapor do calor, menos o que a purga e a saída deixam escapar.
	var p_target := clampf(values[0] * 1.15 - 0.1 - 0.7 * relief - 0.15 * out, 0.0, 1.2)
	values[1] += (p_target - values[1]) * (1.0 - exp(-delta / 1.4))
	# Vazão: a dosagem, empurrada pela pressão.
	var f_target := clampf(out * (0.55 + 0.6 * values[1]), 0.0, 1.2)
	values[2] += (f_target - values[2]) * (1.0 - exp(-delta / 0.8))
	_events(delta)
	# Vermelho: estressa o equipamento; demais = acidente.
	var red := false
	for k in 3:
		if values[k] >= reds[k]:
			red = true
	stress = clampf(stress + (STRESS_RATE if red else -0.3) * delta, 0.0, 1.0)
	if stress >= 1.0:
		_accident()
		return
	# A reação anda com o balão quente o bastante e o líquido correndo.
	running = values[0] >= bands[0].x * 0.8 and values[2] >= bands[2].x * 0.5
	if running:
		var score := 0.0
		var inside := 0
		for k in 3:
			score += closeness(k)
			if values[k] >= bands[k].x and values[k] <= bands[k].y:
				inside += 1
		score /= 3.0
		_score_sum += score * delta
		_score_time += delta
		progress = minf(progress + delta / DURATION * (0.35 + 0.65 * inside / 3.0), 1.0)
		if progress >= 1.0:
			var q := quality()
			Sfx.play("pickup", -6.0, 0.8)
			_end(q, "Pronto! Qualidade %d%%" % int(q * 100.0))


## 1 dentro da faixa; cai até 0 a 0,2 de distância dela.
func closeness(k: int) -> float:
	var v: float = values[k]
	var band: Vector2 = bands[k]
	if v >= band.x and v <= band.y:
		return 1.0
	var d := band.x - v if v < band.x else v - band.y
	return clampf(1.0 - d / 0.2, 0.0, 1.0)


## Qualidade: média do quanto os ponteiros ficaram na faixa enquanto a reação andava.
func quality() -> float:
	if _score_time <= 0.0:
		return 0.0
	return clampf(_score_sum / _score_time, 0.05, 1.0)


func _events(delta: float) -> void:
	if calm:
		return
	_event_in -= delta
	if _event_in > 0.0:
		return
	_event_in = randf_range(3.5, 6.5)
	match randi() % 3:
		0:
			values[1] = minf(values[1] + 0.12, 1.2)
			_say("Bolha de vapor! A pressão pulou")
			Sfx.play("bubble", -2.0, 0.8)
		1:
			values[0] = maxf(values[0] - 0.08, 0.0)
			_say("Corrente de ar: o balão esfriou")
			Sfx.play("hiss", -14.0, 0.6)
		_:
			_clog = 2.0
			_say("Entupiu a saída! Abra mais um pouco")
			Sfx.play("knock", -8.0, 0.7)


## Passou tempo demais no vermelho.
func _accident() -> void:
	var kind := "spill"
	var text := "A vedação estourou: perdeu a mistura"
	if risk == "boom" and values[0] >= reds[0]:
		kind = "boom"
		text = "A PÓLVORA EXPLODIU!"
	elif risk == "leak":
		kind = "leak"
		text = "Vazou gás! Saia de perto (ou use a máscara)"
	Sfx.play("hiss" if kind != "boom" else "explosion", 2.0, 0.8)
	var manager := player.get_parent().get_node_or_null("Placed") as PlacedManager if player else null
	if manager and context.has("obj_id"):
		manager.request("chem_accident", [int(context.obj_id), kind])
	_end(0.0, text)


func _end(q: float, text: String) -> void:
	_result = q
	_end_time = 1.8
	_say(text, 2.2)


func _say(text: String, time := 1.4) -> void:
	_msg = text
	_msg_time = time


# --- Loop e controles ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if _result > -2.0:
		_end_time -= delta
		if _end_time <= 0.0:
			finish(_result)
	if manual_input and _result <= -2.0:
		for k in 3:
			if Input.is_key_pressed(KEYS[k][0]):
				turn(k, TURN_RATE * delta)
			elif Input.is_key_pressed(KEYS[k][1]):
				turn(k, -TURN_RATE * delta)
		_hover = _valve_at(_view.get_local_mouse_position())
	step(delta)
	_animate(delta)
	_msg_time -= delta
	_progress.value = progress
	_info.text = "Nota: %d%%%s" % [int(quality() * 100.0), "  ·  ALARME!" if stress > 0.05 else ("" if running else "  ·  esquente e abra a saída")]
	_info.modulate = Color(1.0, 0.45, 0.35) if stress > 0.05 else Color.WHITE
	_view.queue_redraw()


func turn(k: int, amount: float) -> void:
	valves[k] = clampf(valves[k] + amount, 0.0, 1.0)


func _valve_at(p: Vector2) -> int:
	for k in 3:
		if p.distance_to(Vector2(DIAL_X[k], VALVE_Y)) <= VALVE_R + 8.0:
			return k
	return -1


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		if _result > -2.0:
			return
		var at := _view.get_local_mouse_position()
		var k := _valve_at(at)
		if event.button_index == MOUSE_BUTTON_LEFT:
			_drag = k if event.pressed else -1
		elif event.pressed and k >= 0 and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			turn(k, 0.04 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.04)
			Sfx.play("click", -14.0, 1.4)
	elif event is InputEventMouseMotion and _drag >= 0:
		turn(_drag, -event.relative.y * 0.004)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if progress <= 0.0:
			finish(CANCELLED) # nem começou: nada é gasto
		elif _quit_armed:
			finish(0.0)
		else:
			_quit_armed = true
			_say("Esc de novo: larga a reação (perde os reagentes)", 2.0)


# --- Desenho ---------------------------------------------------------------------------------

func _animate(delta: float) -> void:
	_bubble_in -= delta * (0.5 + values[0] * 6.0)
	if _bubble_in <= 0.0 and values[0] > 0.3:
		_bubble_in = 1.0
		if values[0] > 0.6 and randf() < 0.3:
			Sfx.play("bubble", -16.0, randf_range(0.8, 1.2))
	if randf() < delta * values[2] * 6.0:
		_drops.append({"y": 0.0, "v": 0.0})
	for d in _drops:
		d.v += 400.0 * delta
		d.y += d.v * delta
	_drops = _drops.filter(func(d): return d.y < 46.0)
	if randf() < delta * valves[1] * values[1] * 10.0:
		_puffs.append({"p": Vector2(150, 40), "r": 6.0, "life": 1.0})
	for p in _puffs:
		p.p += Vector2(randf_range(-10, 10), -30.0) * delta
		p.r += 14.0 * delta
		p.life -= delta * 0.9
	_puffs = _puffs.filter(func(p): return p.life > 0.0)


func _draw_view() -> void:
	var v := _view
	v.draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.11, 0.12, 0.11))
	for k in 8: # azulejos da parede
		v.draw_line(Vector2(0, 40 * k), Vector2(VIEW.x, 40 * k), Color(1, 1, 1, 0.03), 1.0)
	v.draw_rect(Rect2(0, 292, VIEW.x, 28), Color(0.2, 0.15, 0.1)) # mesa
	_draw_apparatus(v)
	for k in 3:
		_draw_dial(v, k)
		_draw_valve(v, k)
	if stress > 0.05 and fmod(_time, 0.4) < 0.2:
		v.draw_circle(Vector2(655, 22), 9.0, Color(1.0, 0.2, 0.15))
		v.draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.8, 0.1, 0.05, 0.08 * stress), false, 6.0)
	if _msg_time > 0.0 and _msg != "":
		var font := v.get_theme_default_font()
		var width := font.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var at := Vector2((VIEW.x - width) * 0.5, 22)
		var alpha := clampf(_msg_time * 2.0, 0.0, 1.0)
		v.draw_rect(Rect2(at - Vector2(8, 16), Vector2(width + 16, 22)), Color(0, 0, 0, 0.65 * alpha))
		v.draw_string(font, at, _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.6, alpha))


## Queimador, balão com o líquido fervendo, tubo, serpentina na tina e o frasco que enche.
func _draw_apparatus(v: Control) -> void:
	var liquid: Color = LIQUID.get(StringName(context.get("item", "")), Color(0.45, 0.75, 0.3))
	var base := Vector2(95, 292)
	# Tripé e queimador.
	v.draw_line(base + Vector2(-40, 0), base + Vector2(-30, -72), Color(0.25, 0.24, 0.24), 3.0)
	v.draw_line(base + Vector2(40, 0), base + Vector2(30, -72), Color(0.25, 0.24, 0.24), 3.0)
	v.draw_rect(Rect2(base + Vector2(-8, -30), Vector2(16, 30)), Color(0.62, 0.5, 0.26))
	var flame: float = valves[0]
	if flame > 0.02:
		var h := 10.0 + 34.0 * flame
		v.draw_colored_polygon(PackedVector2Array([base + Vector2(-9, -30), base + Vector2(9, -30), base + Vector2(0, -30 - h)]), Color(0.4, 0.6, 1.0, 0.9))
		v.draw_colored_polygon(PackedVector2Array([base + Vector2(-5, -30), base + Vector2(5, -30), base + Vector2(0, -30 - h * 0.6)]), Color(0.8, 0.9, 1.0, 0.9))
	# Balão: vidro, líquido pela metade, bolhas conforme o calor; vermelho quando estressa.
	var flask := Vector2(95, 175)
	var hot := clampf((values[0] - 0.5) * 2.0, 0.0, 1.0)
	v.draw_circle(flask, 48.0, Color(0.55, 0.68, 0.66, 0.35))
	var level := PackedVector2Array()
	for k in 17:
		var a := lerpf(0.15, PI - 0.15, k / 16.0)
		level.append(flask + Vector2(cos(a), sin(a)) * 46.0)
	v.draw_colored_polygon(level, liquid.lerp(Color(1.0, 0.5, 0.2), hot * 0.25))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in int(values[0] * 14.0):
		var x := rng.randf_range(-34, 34)
		var y := fmod(_time * (40.0 + rng.randf() * 40.0) + rng.randf() * 40.0, 36.0)
		v.draw_circle(flask + Vector2(x + sin(_time * 5.0 + k) * 2.0, 38 - y), 2.0 + rng.randf() * 2.0, liquid.lightened(0.4))
	v.draw_arc(flask, 48.0, 0.0, TAU, 32, Color(0.75, 0.85, 0.85, 0.8), 2.0)
	if stress > 0.05:
		v.draw_arc(flask, 52.0, 0.0, TAU, 32, Color(1.0, 0.25, 0.15, stress), 3.0)
	# Gargalo, purga (vapor saindo do alívio) e o tubo até a serpentina.
	v.draw_rect(Rect2(flask + Vector2(-9, -100), Vector2(18, 56)), Color(0.55, 0.68, 0.66, 0.35))
	v.draw_line(flask + Vector2(-9, -100), flask + Vector2(-9, -46), Color(0.75, 0.85, 0.85, 0.8), 2.0)
	v.draw_line(flask + Vector2(9, -100), flask + Vector2(9, -46), Color(0.75, 0.85, 0.85, 0.8), 2.0)
	v.draw_line(flask + Vector2(0, -100), Vector2(150, 50), Color(0.72, 0.42, 0.25), 4.0) # cano do alívio
	for p in _puffs:
		v.draw_circle(p.p, p.r, Color(0.9, 0.9, 0.9, 0.35 * p.life))
	v.draw_polyline(PackedVector2Array([flask + Vector2(9, -90), Vector2(190, 92), Vector2(205, 140)]), Color(0.75, 0.85, 0.85, 0.9), 3.0)
	# Tina d'água com a serpentina.
	v.draw_rect(Rect2(178, 135, 56, 110), Color(0.3, 0.45, 0.58, 0.6))
	for k in 7:
		var y := 145.0 + k * 14.0
		v.draw_line(Vector2(186, y), Vector2(226, y + 7), Color(0.72, 0.42, 0.25), 3.0)
		v.draw_line(Vector2(226, y + 7), Vector2(186, y + 14), Color(0.62, 0.36, 0.22), 3.0)
	v.draw_rect(Rect2(178, 135, 56, 110), Color(0.4, 0.3, 0.2), false, 3.0)
	v.draw_line(Vector2(206, 245), Vector2(206, 252), Color(0.72, 0.42, 0.25), 3.0)
	# Frasco que recolhe (enche com o progresso) e as gotas da vazão.
	var bottle := Rect2(186, 252, 40, 40)
	v.draw_rect(bottle, Color(0.55, 0.68, 0.66, 0.3))
	var fill_h := 38.0 * progress
	v.draw_rect(Rect2(bottle.position.x + 1, bottle.end.y - fill_h, 38, fill_h), liquid)
	v.draw_rect(bottle, Color(0.75, 0.85, 0.85, 0.8), false, 2.0)
	for d in _drops:
		v.draw_circle(Vector2(206, 252 + d.y * 0.7), 2.0, liquid.lightened(0.2))


## Relógio: arco de 270°, faixa verde da receita, vermelho no fim, ponteiro e o valor.
func _draw_dial(v: Control, k: int) -> void:
	var c := Vector2(DIAL_X[k], DIAL_Y)
	var font := v.get_theme_default_font()
	v.draw_circle(c, DIAL_R + 6.0, Color(0.62, 0.5, 0.26))
	v.draw_circle(c, DIAL_R, Color(0.9, 0.88, 0.8))
	var ang := func(x: float) -> float: return lerpf(PI * 0.75, PI * 2.25, clampf(x / 1.2, 0.0, 1.0))
	v.draw_arc(c, DIAL_R - 9.0, ang.call(bands[k].x), ang.call(bands[k].y), 16, Color(0.25, 0.65, 0.3), 9.0)
	if reds[k] < 1.2:
		v.draw_arc(c, DIAL_R - 9.0, ang.call(reds[k]), ang.call(1.2), 12, Color(0.8, 0.2, 0.15), 9.0)
	for t in 13:
		var a: float = ang.call(t * 0.1)
		var long := t % 2 == 0
		v.draw_line(c + Vector2.from_angle(a) * (DIAL_R - (12.0 if long else 7.0)), c + Vector2.from_angle(a) * (DIAL_R - 2.0), Color(0.15, 0.15, 0.15), 2.0 if long else 1.0)
	var needle: float = ang.call(values[k])
	var shake := sin(_time * 40.0) * 0.03 * stress
	v.draw_line(c, c + Vector2.from_angle(needle + shake) * (DIAL_R - 6.0), Color(0.12, 0.1, 0.1), 3.0)
	v.draw_circle(c, 5.0, Color(0.3, 0.25, 0.15))
	var inside: bool = values[k] >= bands[k].x and values[k] <= bands[k].y
	var label: String = NAMES[k]
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	v.draw_string(font, c + Vector2(-lw * 0.5, -DIAL_R - 12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.85))
	var value_text := "%d%%" % int(values[k] * 100.0)
	var vw := font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	v.draw_string(font, c + Vector2(-vw * 0.5, DIAL_R * 0.62), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.2, 0.55, 0.25) if inside else Color(0.55, 0.2, 0.15))


## Volante da válvula: gira com a abertura; aceso quando o mouse está em cima.
func _draw_valve(v: Control, k: int) -> void:
	var c := Vector2(DIAL_X[k], VALVE_Y)
	var font := v.get_theme_default_font()
	v.draw_line(c + Vector2(0, -VALVE_R - 12.0), c + Vector2(0, -VALVE_R + 4.0), Color(0.72, 0.42, 0.25), 6.0) # cano
	var red := Color(0.7, 0.14, 0.11) if k != _hover and k != _drag else Color(0.9, 0.25, 0.2)
	v.draw_arc(c, VALVE_R, 0.0, TAU, 24, red, 6.0)
	var turn_angle: float = valves[k] * TAU * 1.5
	for s in 3:
		var a := turn_angle + TAU * s / 3.0
		v.draw_line(c, c + Vector2.from_angle(a) * VALVE_R, red, 4.0)
	v.draw_circle(c, 7.0, Color(0.62, 0.5, 0.26))
	var label := "%s %d%%" % [VALVE_NAMES[k], int(valves[k] * 100.0)]
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	v.draw_string(font, c + Vector2(-lw * 0.5, VALVE_R + 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.9, 0.85))
	var keys := "%s/%s" % [OS.get_keycode_string(KEYS[k][0]), OS.get_keycode_string(KEYS[k][1])]
	var kw := font.get_string_size(keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	v.draw_string(font, c + Vector2(-kw * 0.5, VALVE_R + 31.0), keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5))
