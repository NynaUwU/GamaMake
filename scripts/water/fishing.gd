class_name Fishing
extends Node3D
## Vara de pesca (filho do Player enquanto ele existir).
##   1. Clique: a boia voa até onde você mira na água (até 22 m).
##   2. Espera (4-12 s; à noite e em lago grande, mais rápido). A boia treme.
##   3. A boia AFUNDA ("!"): clique em até 1,2 s para fisgar.
##   4. Minijogo: um peixe pula numa barra; segure o clique para empurrar a
##      faixa verde para a direita (solte e ela volta). Com o peixe dentro da
##      faixa, a barra de captura enche; fora, esvazia. Cheia = pegou.
##      Atum é bravo (pula muito), camarão é fácil.
## Botão direito recolhe a linha a qualquer momento.

enum State { IDLE, CAST, WAIT, BITE, FIGHT }

const RANGE := 22.0
## O que a vara pega: [id, chance, dificuldade 0..1]. Atum só nos lagos grandes.
const CATCH_LAKE := [[&"baixo", 45, 0.4], [&"atum", 18, 0.85], [&"lagosta", 12, 0.6], [&"caranguejo", 13, 0.3], [&"camarao", 12, 0.15]]
const CATCH_POND := [[&"baixo", 60, 0.35], [&"caranguejo", 22, 0.3], [&"camarao", 18, 0.15]]

var player: Player
var state := State.IDLE
var _bobber: Node3D
var _line: MeshInstance3D
var _line_mesh := ImmediateMesh.new()
var _target := Vector3.ZERO
var _from := Vector3.ZERO
var _timer := 0.0
var _lake := {}
var _fish: Array = [] # [id, chance, dificuldade]
var _ui: CanvasLayer
var _bar: Control
var _zone := 0.3 # posição da faixa verde (0..1, esquerda)
var _zone_speed := 0.0
var _fish_pos := 0.5
var _fish_target := 0.5
var _progress := 0.3


func _ready() -> void:
	top_level = true
	_bobber = Node3D.new()
	_bobber.top_level = true
	add_child(_bobber)
	var mb := MeshBuilder.new()
	mb.color(Color(0.85, 0.12, 0.08))
	mb.lathe(PackedVector2Array([Vector2(0.002, -0.06), Vector2(0.045, -0.02), Vector2(0.045, 0.0)]), 8)
	mb.color(Color(0.95, 0.95, 0.9))
	mb.lathe(PackedVector2Array([Vector2(0.045, 0.0), Vector2(0.03, 0.04), Vector2(0.002, 0.05)]), 8)
	mb.color(Color(0.1, 0.1, 0.1))
	mb.box(Vector3(0, 0.09, 0), Vector3(0.008, 0.08, 0.008))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	_bobber.add_child(mesh)
	_bobber.visible = false
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.top_level = true
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.9, 0.9, 0.85)
	_line.material_override = material
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)


## Ponta da vara (no mundo), para a linha sair dali.
func _tip() -> Vector3:
	var rod: Node3D = player.get("rod")
	if rod and rod.visible:
		# A ponta do modelo (que fica levemente inclinado dentro do nó da vara).
		var model: Node3D = rod.get_child(0) if rod.get_child_count() > 0 else rod
		return model.global_transform * Vector3(0, 0, -1.45)
	return player.camera.global_position - player.camera.global_basis.z * 1.0


func click() -> void:
	match state:
		State.IDLE:
			_cast()
		State.BITE:
			_start_fight()
		State.WAIT, State.CAST:
			pass


func cancel() -> void:
	if state != State.IDLE:
		Sfx.play("whirr", -10.0, 1.0)
	_reset()


func _cast() -> void:
	var cam := player.camera
	var water := WaterManager.i.ray_water(cam.global_position, -cam.global_basis.z, RANGE) if WaterManager.i else Vector3.INF
	if water == Vector3.INF:
		Sfx.play("click", -6.0, 0.6)
		return
	# Algo no caminho (margem, árvore)? A boia bate e cai antes.
	var query := PhysicsRayQueryParameters3D.create(cam.global_position, water + Vector3.UP * 0.4, 1, [player.get_rid()])
	if player.get_world_3d().direct_space_state.intersect_ray(query):
		Sfx.play("click", -6.0, 0.6)
		return
	_lake = WaterManager.i.lake_at(water)
	_fish = CATCH_LAKE if _lake.kind == "lake" else CATCH_POND
	_target = water
	_from = _tip()
	_timer = 0.0
	state = State.CAST
	_bobber.visible = true
	Sfx.play_at("swing", player.global_position + Vector3.UP * 1.5, -4.0, 0.7)


func _process(delta: float) -> void:
	if player == null:
		return
	# Trocou de arma ou foi para longe: recolhe.
	if state != State.IDLE and (player.get("_weapon_type") != Player.WeaponType.ROD or player.global_position.distance_to(_target) > RANGE + 6.0):
		_reset()
		return
	match state:
		State.CAST:
			_timer += delta / 0.7
			var t := minf(_timer, 1.0)
			var p := _from.lerp(_target, t) + Vector3.UP * sin(t * PI) * 2.5
			_bobber.global_position = p
			if t >= 1.0:
				state = State.WAIT
				_timer = randf_range(4.0, 12.0) * (0.7 if DayNight.i and DayNight.i.is_night() else 1.0)
				Sfx.play_at("slap", _target, -6.0, 0.6)
		State.WAIT:
			_timer -= delta
			_bobber.global_position = _target + Vector3.UP * sin(Time.get_ticks_msec() * 0.004) * 0.015
			if _timer <= 0.0:
				state = State.BITE
				_timer = 1.2
				Sfx.play_at("slap", _target, 2.0, 0.7) # tchibum da boia afundando
				Sfx.play("ping", 0.0, 0.9)
		State.BITE:
			_timer -= delta
			_bobber.global_position = _target + Vector3.DOWN * 0.12 + Vector3.UP * sin(Time.get_ticks_msec() * 0.03) * 0.04
			if _timer <= 0.0:
				Sfx.play("click", -6.0, 0.5)
				_reset()
		State.FIGHT:
			_bobber.global_position = _target + Vector3(sin(Time.get_ticks_msec() * 0.01) * 0.2, -0.05, cos(Time.get_ticks_msec() * 0.013) * 0.2)
			_update_fight(delta)
	_draw_line()


func _draw_line() -> void:
	_line_mesh.clear_surfaces()
	if state == State.IDLE:
		return
	var a := _tip()
	var b := _bobber.global_position + Vector3.UP * 0.12
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for k in 13: # linha caindo um pouco no meio
		var t := k / 12.0
		var sag := sin(t * PI) * (0.6 if state != State.FIGHT else 0.1)
		_line_mesh.surface_add_vertex(a.lerp(b, t) + Vector3.DOWN * sag)
	_line_mesh.surface_end()


# --- Minijogo ----------------------------------------------------------------------

func _pick_fish() -> Array:
	var total := 0
	for f in _fish:
		total += f[1]
	var roll := randi() % total
	for f in _fish:
		roll -= f[1]
		if roll < 0:
			return f
	return _fish[0]


var _hooked: Array = []


func _start_fight() -> void:
	if _fish.is_empty():
		_reset()
		return
	_hooked = _pick_fish()
	state = State.FIGHT
	_zone = 0.35
	_zone_speed = 0.0
	_fish_pos = 0.5
	_fish_target = randf()
	_progress = 0.3
	_build_ui()
	Sfx.play_at("whirr", player.global_position, -6.0, 0.8)


func _update_fight(delta: float) -> void:
	var difficulty: float = _hooked[2]
	# Peixe: pula para pontos aleatórios, mais rápido e mais vezes quanto mais bravo.
	if absf(_fish_pos - _fish_target) < 0.03 or randf() < delta * (0.25 + difficulty * 0.8):
		_fish_target = randf()
	_fish_pos = move_toward(_fish_pos, _fish_target, delta * (0.1 + difficulty * 0.35)) # bem mais calmo
	# Faixa: segurar empurra para a direita, soltar cai para a esquerda (com inércia).
	var holding := Input.is_action_pressed("attack")
	_zone_speed += (2.6 if holding else -2.2) * delta
	_zone_speed = clampf(_zone_speed, -1.2, 1.2)
	var width := 0.28 - difficulty * 0.1
	_zone = clampf(_zone + _zone_speed * delta, 0.0, 1.0 - width)
	if _zone <= 0.0 or _zone >= 1.0 - width:
		_zone_speed *= -0.3 # quica na borda
	var inside := _fish_pos >= _zone and _fish_pos <= _zone + width
	_progress += (0.28 if inside else -0.2 - difficulty * 0.1) * delta
	_bar.queue_redraw()
	if _progress >= 1.0:
		var id: StringName = _hooked[0]
		var amount := randi_range(2, 4) if id == &"camarao" else 1
		var left := player.pick_up(id, ItemDB.display_name(id), amount)
		if left > 0:
			Net.i.drop_item(id, left, player.global_transform.translated(Vector3.UP), Vector3.ZERO)
		Sfx.play_at("slap", player.global_position, 0.0, 0.9)
		Sfx.play("pickup")
		_reset()
	elif _progress <= 0.0:
		Sfx.play("click", -6.0, 0.5)
		_reset()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 7
	add_child(_ui)
	_bar = Control.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.offset_left = -170.0
	_bar.offset_right = 170.0
	_bar.offset_top = -150.0
	_bar.offset_bottom = -96.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	_ui.add_child(_bar)


func _draw_bar() -> void:
	var w := _bar.size.x
	var difficulty: float = _hooked[2]
	var width := 0.28 - difficulty * 0.1
	var font := _bar.get_theme_default_font()
	_bar.draw_rect(Rect2(0, 0, w, 54), Color(0.1, 0.1, 0.11, 0.85))
	_bar.draw_rect(Rect2(0, 0, w, 54), Color(0.5, 0.5, 0.52), false, 1.0)
	_bar.draw_string(font, Vector2(6, 13), "Segure o clique: mantenha o peixe na faixa verde", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.7))
	# Água e faixa verde.
	_bar.draw_rect(Rect2(6, 18, w - 12, 18), Color(0.12, 0.28, 0.38))
	_bar.draw_rect(Rect2(6 + _zone * (w - 12), 18, width * (w - 12), 18), Color(0.3, 0.8, 0.3, 0.75))
	# O peixe (silhueta em blocos).
	var fx := 6 + _fish_pos * (w - 12)
	var color := Color(0.95, 0.75, 0.3) if difficulty > 0.7 else Color(0.85, 0.85, 0.9)
	_bar.draw_rect(Rect2(fx - 8, 22, 14, 10), color)
	_bar.draw_rect(Rect2(fx + 6, 24, 5, 6), color.darkened(0.2))
	_bar.draw_rect(Rect2(fx - 6, 24, 2, 2), Color.BLACK)
	# Captura.
	_bar.draw_rect(Rect2(6, 41, w - 12, 8), Color(0, 0, 0, 0.6))
	_bar.draw_rect(Rect2(6, 41, (w - 12) * clampf(_progress, 0.0, 1.0), 8), Color(1.0, 0.85, 0.3))


func _reset() -> void:
	state = State.IDLE
	_bobber.visible = false
	_line_mesh.clear_surfaces()
	if _ui:
		_ui.queue_free()
		_ui = null
