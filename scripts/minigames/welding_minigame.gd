class_name WeldingMinigame
extends Minigame
## Solda (bancada de solda, Era 3): segure o clique com a ponta do eletrodo em cima da
## junta (a linha escura entre as duas chapas) e vá seguindo até o fim, numa velocidade
## constante. Cada pedacinho do cordão tem nota pela velocidade e pela mira:
##   na faixa verde       cordão cheio e regular
##   rápido demais        cordão fino: solda fraca
##   devagar demais       cordão grosso e queimado
##   parado com o arco    fura a chapa
##   longe da junta       só respinga (não solda)
## Com o arco aceso a tela escurece (máscara de solda) e só o arco e o metal quente
## aparecem. Armaduras têm 2 ou 3 cordões. Qualidade = média dos pedaços - furos.
##
## Modo "brazing" (bancada de maçarico): chama em vez de arco, chapas de cobre, cordão
## de estanho, sem máscara e um pouco mais devagar (o cobre precisa esquentar).
##
## Contexto: {"item": peça, "seams": cordões, "mode": "arc"/"brazing"}

const VIEW := Vector2(600, 260)
const BAND := Vector2(55.0, 105.0) ## velocidade boa (px/s)
const BRAZE_BAND := Vector2(40.0, 85.0) ## maçarico: mais devagar
const SPEED_MAX := 180.0 ## fim do medidor
const SNAP := 14.0 ## distância máxima da ponta à junta para soldar
const JUMP := 26.0 ## pular mais que isso para a frente não vale
const SEG := 6.0 ## px de cordão por pedaço
const BURN_TIME := 0.9 ## parado com o arco aceso: fura
const WINDOW := 0.3 ## s para medir a velocidade
## Rampa de cor do metal quente (a mesma do shader forge_heat), em sRGB.
const HEAT := [[0.0, Color(0.6, 0.61, 0.63)], [0.24, Color(0.3, 0.035, 0.02)], [0.38, Color(0.72, 0.07, 0.03)],
	[0.52, Color(0.95, 0.27, 0.05)], [0.66, Color(1.0, 0.52, 0.1)], [0.8, Color(1.0, 0.83, 0.3)], [0.95, Color(1.0, 0.97, 0.88)]]

var seams := 2
var brazing := false
var band := BAND
var seam := 0
var path := PackedVector2Array()
var lengths := PackedFloat32Array() ## comprimento acumulado em cada ponto
var front := 0.0 ## até onde a ponta já passou (px ao longo da junta)
var laid := 0.0 ## até onde o cordão foi depositado
var speed := 0.0
var burns := 0
var scores: Array[float] = []
var beads: Array = [] # {"p", "r", "t"}
var holes: Array = [] # Vector2
var sparks: Array = [] # {"p", "v", "life"}
var tip := Vector2.ZERO
var arc_on := false
var manual_input := true ## false nos testes (drive() faz o papel do mouse)
var _still := 0.0
var _hist: Array = [] # [tempo, front]
var _time := 0.0
var _off := 0.0
var _result := -2.0
var _end_time := 0.0
var _quit_armed := false
var _msg := ""
var _msg_time := 0.0
var _gradient: Gradient
var _view: Control
var _meter: BandMeter
var _progress: ProgressBar
var _info: Label


func _ready() -> void:
	seams = int(context.get("seams", 2))
	brazing = context.get("mode", "arc") == "brazing"
	band = BRAZE_BAND if brazing else BAND
	_gradient = Gradient.new()
	_gradient.offsets = PackedFloat32Array(HEAT.map(func(h): return h[0]))
	_gradient.colors = PackedColorArray(HEAT.map(func(h): return h[1]))
	if brazing:
		_gradient.set_color(0, Color(0.78, 0.78, 0.75)) # estanho frio: prateado
	var title := "Solda de cobre: %s" if brazing else "Solda: %s"
	var column := frame(title % ItemDB.display_name(StringName(context.get("item", "couraca"))), VIEW.x + 20.0)
	_view = Control.new()
	_view.custom_minimum_size = VIEW
	_view.clip_contents = true
	_view.draw.connect(_draw_view)
	column.add_child(_view)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	row.add_child(_small("Velocidade"))
	_meter = BandMeter.new()
	_meter.band = band / SPEED_MAX
	row.add_child(_meter)
	row.add_child(_small("Cordão"))
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(90, 8)
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress.show_percentage = false
	_progress.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.6, 0.75, 0.95)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	_progress.add_theme_stylebox_override("fill", fill)
	_progress.add_theme_stylebox_override("background", bg)
	row.add_child(_progress)
	_info = _small("")
	row.add_child(_info)
	var keys := Label.new()
	keys.text = ("Segure o clique: a chama esquenta a junta e o estanho escorre. Siga devagar e sempre igual (faixa verde) · Esc: desistir" if brazing
		else "Segure o clique em cima da junta e siga até o fim, devagar e sempre igual (faixa verde) · Esc: desistir")
	keys.add_theme_font_size_override("font_size", 10)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.modulate = Color(1, 1, 1, 0.6)
	column.add_child(keys)
	_load_seam(0)


func _small(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	return label


# --- Juntas ----------------------------------------------------------------------------

## Junta k: 0 ondulada na horizontal, 1 na diagonal, 2 em arco (da esquerda para a direita).
static func seam_points(k: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match k % 3:
		0:
			for i in 47:
				var x := 70.0 + i * 10.0
				pts.append(Vector2(x, 130.0 + 18.0 * sin((x - 70.0) * 0.018)))
		1:
			for i in 43:
				var x := 90.0 + i * 10.0
				pts.append(Vector2(x, 60.0 + (x - 90.0) / 420.0 * 140.0 + 10.0 * sin((x - 90.0) * 0.015)))
		_:
			for i in 41:
				var a := deg_to_rad(-155.0 + i * 130.0 / 40.0)
				pts.append(Vector2(300.0, 330.0) + Vector2(cos(a), sin(a)) * 230.0)
	return pts


func _load_seam(k: int) -> void:
	seam = k
	path = seam_points(k)
	lengths = PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		lengths.append(lengths[i - 1] + path[i].distance_to(path[i - 1]))
	front = 0.0
	laid = 0.0
	beads.clear()
	holes.clear()
	_hist.clear()
	_still = 0.0


func length() -> float:
	return lengths[lengths.size() - 1]


## Ponto da junta a "along" px do começo.
func point_at(along: float) -> Vector2:
	along = clampf(along, 0.0, length())
	for i in range(1, path.size()):
		if lengths[i] >= along:
			var t := (along - lengths[i - 1]) / maxf(lengths[i] - lengths[i - 1], 0.001)
			return path[i - 1].lerp(path[i], t)
	return path[path.size() - 1]


## Ponto mais perto da junta: {"along", "dist"}.
func project(p: Vector2) -> Dictionary:
	var best := {"along": 0.0, "dist": INF}
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best.dist:
			best = {"along": lengths[i - 1] + ab.length() * t, "dist": d}
	return best


# --- Regras ----------------------------------------------------------------------------

## Um passo da solda com a ponta em "at" (arco aceso se "on").
func drive(at: Vector2, on: bool, delta: float) -> void:
	_time += delta
	tip = at
	arc_on = on and _result <= -2.0 and Rect2(Vector2.ZERO, VIEW).has_point(at)
	if not arc_on:
		_still = 0.0
		speed = move_toward(speed, 0.0, delta * 300.0)
		return
	var hit := project(at)
	if hit.dist > SNAP:
		_off += delta
		if randf() < delta * 30.0:
			sparks.append({"p": at, "v": Vector2(randf_range(-90, 90), randf_range(-120, -20)), "life": 0.35})
		if _off > 0.4:
			_say("Fora da junta: só respinga")
			_off = 0.0
		return
	_off = 0.0
	if hit.along > front + JUMP:
		_say("Pulou um pedaço: volte para o fim do cordão")
		return
	var before := front
	front = maxf(front, hit.along)
	_hist.append([_time, front])
	while _hist.size() > 1 and _time - _hist[0][0] > WINDOW:
		_hist.pop_front()
	var span: float = _time - _hist[0][0]
	speed = (front - _hist[0][1]) / span if span > 0.05 else speed
	for k in (1 if brazing else 3):
		sparks.append({"p": at, "v": Vector2(randf_range(-110, 110), randf_range(-160, -30)), "life": randf_range(0.2, 0.5)})
	if front - before < 0.2:
		_still += delta
		if _still > BURN_TIME:
			_still = 0.0
			burns += 1
			holes.append(point_at(front))
			_say("Parado demais: furou a chapa!")
			Sfx.play("crack", -8.0, 1.6)
	else:
		_still = 0.0
	while laid + SEG <= front:
		laid += SEG
		_lay(laid, hit.dist)
	if front >= length() - 1.0:
		_seam_done()


## Deposita um pedaço do cordão em "along": nota pela velocidade e pela mira.
func _lay(along: float, dist: float) -> void:
	var q := 1.0
	if speed > band.y:
		q = clampf(1.0 - (speed - band.y) / band.y, 0.15, 1.0) # fino: fraco
	elif speed < band.x:
		q = clampf(1.0 - (band.x - speed) / band.x * 0.7, 0.3, 1.0) # grosso: queimado
	q *= 1.0 - clampf((dist - 3.0) / 11.0, 0.0, 0.4)
	scores.append(q)
	var r := clampf(5.5 * ((band.x + band.y) * 0.5) / maxf(speed, 20.0), 2.2, 9.0)
	beads.append({"p": point_at(along), "r": r, "t": _time})


func _seam_done() -> void:
	Sfx.play("pickup", -6.0, 0.8)
	if seam + 1 >= seams:
		_end(quality(), "Pronto! Qualidade %d%%" % int(quality() * 100.0))
	else:
		_say("Cordão %d de %d pronto" % [seam + 1, seams])
		_load_seam(seam + 1)


## Qualidade até agora: média dos pedaços menos os furos.
func quality() -> float:
	if scores.is_empty():
		return 0.0
	var total := 0.0
	for q in scores:
		total += q
	return clampf(total / scores.size() - burns * 0.12, 0.05, 1.0)


func _end(q: float, text: String) -> void:
	_result = q
	_end_time = 1.6
	arc_on = false
	_say(text, 2.0)


func _say(text: String, time := 1.2) -> void:
	_msg = text
	_msg_time = time


# --- Loop ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _result > -2.0:
		_end_time -= delta
		if _end_time <= 0.0:
			finish(_result)
	if manual_input:
		drive(_view.get_local_mouse_position(), Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), delta)
	for s in sparks:
		s.p += s.v * delta
		s.v.y += 400.0 * delta
		s.life -= delta
	sparks = sparks.filter(func(s): return s.life > 0.0)
	_msg_time -= delta
	_meter.set_value(speed / SPEED_MAX)
	_progress.value = front / length()
	_info.text = "Cordão %d de %d · Furos: %d · Nota: %d%%" % [mini(seam + 1, seams), seams, burns, int(quality() * 100.0)]
	_view.queue_redraw()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled() # o clique é do maçarico (lido no _process)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if scores.is_empty():
			finish(CANCELLED) # nem começou: nada é gasto
		elif _quit_armed:
			finish(0.0)
		else:
			_quit_armed = true
			_say("Esc de novo: larga a peça (perde o material)", 2.0)


# --- Desenho -------------------------------------------------------------------------

func _heat(t: float) -> Color:
	return _gradient.sample(clampf(t, 0.0, 1.0))


## Duas chapas de aço com a junta escura, o cordão (cor pela temperatura), furos,
## máscara de solda escurecendo tudo com o arco aceso, o arco, faíscas e o eletrodo.
func _draw_view() -> void:
	var v := _view
	v.draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.12, 0.12, 0.13))
	var first := path[0]
	var last := path[path.size() - 1]
	var top := PackedVector2Array([Vector2(0, 0), Vector2(VIEW.x, 0), Vector2(VIEW.x, last.y)])
	for i in range(path.size() - 1, -1, -1):
		top.append(path[i] + Vector2(0, -2))
	top.append(Vector2(0, first.y))
	var bottom := PackedVector2Array([Vector2(0, VIEW.y), Vector2(0, first.y)])
	for p in path:
		bottom.append(p + Vector2(0, 2))
	bottom.append(Vector2(VIEW.x, last.y))
	bottom.append(Vector2(VIEW.x, VIEW.y))
	v.draw_colored_polygon(top, Color(0.72, 0.43, 0.26) if brazing else Color(0.42, 0.43, 0.45))
	v.draw_colored_polygon(bottom, Color(0.64, 0.37, 0.22) if brazing else Color(0.36, 0.37, 0.4))
	for k in 9: # riscos de esmeril nas chapas
		var y := 18.0 + k * 27.0
		v.draw_line(Vector2(10, y), Vector2(VIEW.x - 10, y + 6), Color(1, 1, 1, 0.04), 2.0)
	v.draw_polyline(path, Color(0.05, 0.05, 0.06), 4.0) # junta (chanfro)
	v.draw_circle(first, 4.0, Color(0.3, 0.75, 0.35)) # começo
	for hole in holes:
		v.draw_circle(hole, 7.0, Color(0.02, 0.02, 0.02))
		v.draw_arc(hole, 8.0, 0, TAU, 12, Color(0.45, 0.2, 0.08), 2.0)
	for b in beads:
		var cool := clampf((_time - b.t) / 2.5, 0.0, 1.0)
		var c := _heat(lerpf(0.9, 0.0, cool))
		v.draw_circle(b.p, b.r + 1.0, c.darkened(0.45))
		v.draw_circle(b.p, b.r, c)
		v.draw_circle(b.p + Vector2(-b.r * 0.3, -b.r * 0.3), b.r * 0.35, c.lightened(0.25))
	if arc_on and brazing:
		# Chama do maçarico vindo de cima à direita: azul no bico, laranja na ponta, e o
		# cobre em volta escurecendo de calor.
		for k in 4:
			v.draw_circle(tip, 22.0 - k * 4.0, Color(1.0, 0.5, 0.15, 0.06 + k * 0.04))
		var from := tip + Vector2(34, -46)
		v.draw_colored_polygon(PackedVector2Array([from + Vector2(-5, -3), from + Vector2(5, 3), tip]), Color(1.0, 0.65, 0.25, 0.85))
		v.draw_colored_polygon(PackedVector2Array([from + Vector2(-3, -2), from + Vector2(3, 2), from.lerp(tip, 0.55)]), Color(0.45, 0.65, 1.0, 0.95))
	elif arc_on:
		v.draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.02, 0.06, 0.03, 0.62)) # máscara de solda
		for k in 5:
			v.draw_circle(tip, 26.0 - k * 5.0, Color(0.7, 0.85, 1.0, 0.08 + k * 0.05))
		v.draw_circle(tip, 4.0, Color(1, 1, 1))
	for s in sparks:
		v.draw_rect(Rect2(s.p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1.0, 0.75, 0.35, clampf(s.life * 3.0, 0.0, 1.0)))
	if Rect2(Vector2.ZERO, VIEW).has_point(tip):
		if brazing:
			var nozzle := tip + Vector2(34, -46)
			v.draw_line(nozzle, nozzle + Vector2(40, -30), Color(0.72, 0.58, 0.26), 7.0) # maçarico de latão
			v.draw_line(tip + Vector2(-30, -50), tip + Vector2(-4, -6), Color(0.78, 0.78, 0.75), 2.0) # vareta de estanho
		else:
			var used := clampf(front / length(), 0.0, 1.0)
			var stick := tip + Vector2(26, -40) * (1.0 - used * 0.4)
			v.draw_line(tip, stick, Color(0.65, 0.6, 0.48), 3.0) # eletrodo (gasta)
			v.draw_line(stick, stick + Vector2(30, -26), Color(0.75, 0.6, 0.15), 8.0) # porta-eletrodo
	if _msg_time > 0.0 and _msg != "":
		var font := v.get_theme_default_font()
		var width := font.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var at := Vector2((VIEW.x - width) * 0.5, 30)
		var alpha := clampf(_msg_time * 2.0, 0.0, 1.0)
		v.draw_rect(Rect2(at - Vector2(8, 16), Vector2(width + 16, 22)), Color(0, 0, 0, 0.6 * alpha))
		v.draw_string(font, at, _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.6, alpha))
