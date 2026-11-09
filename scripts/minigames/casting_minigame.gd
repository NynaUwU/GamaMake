class_name CastingMinigame
extends Minigame
## Fundição (Era 2), em 3D: o cadinho cheio de metal derretido fica no cavalete em cima
## do molde de areia. A altura do mouse na tela inclina o cadinho (em cima = em pé,
## embaixo = virado); W/S ou a roda ajustam fino. O metal só sai quando passa da borda,
## e a borda fica mais longe quanto mais vazio o cadinho (precisa inclinar mais).
##   vazão na faixa verde   enche bem
##   rápido demais          espirra para fora (perde metal e acabamento)
##   devagar demais         a frente do metal esfria antes de encher: emenda fria
##   passou de cheio        transborda na areia
##   demorou                o metal endurece no cadinho (peça perdida)
## Termina quando o molde está cheio e o cadinho volta a ficar em pé.
##
## Contexto: {"item": peça, "metal": metal principal, "mold": "ingot"/"gear"/"pipe"/"axe"}

const VIEW := Vector2(600, 290)
const POUR_RATE := 0.03 ## volume do molde por segundo, por grau além da borda
const BAND := Vector2(0.12, 0.35) ## vazão boa (molde por segundo)
const SPLASH := 0.45 ## acima disso espirra
const MAX_FLOW := 0.9
const COLD_LIMIT := 1.2 ## segundos despejando devagar (já começado) até uma emenda fria
const METAL := 1.15 ## o cadinho leva um pouco mais que o molde
const CRUCIBLE_LIFE := 45.0 ## segundos até o metal endurecer no cadinho
const MAX_TILT := 120.0
const TILT_SPEED := 90.0 ## graus por segundo (o cadinho é pesado)
## Cavidade no molde: [tamanho x, tamanho z].
const MOLDS := {"ingot": Vector2(0.62, 0.2), "gear": Vector2(0.44, 0.44), "pipe": Vector2(0.72, 0.12), "axe": Vector2(0.5, 0.28)}
const COLORS := {&"barra_bronze": Color(0.66, 0.46, 0.2), &"barra_cobre": Color(0.66, 0.38, 0.22), &"barra_estanho": Color(0.75, 0.75, 0.74)}
const PIVOT := Vector3(-0.42, 1.02, 0)
const LIP := Vector3(0.17, 0.13, 0) ## borda do cadinho (espaço do pivô)
const DEPTH := 0.14 ## fundo da cavidade
const SAND_TOP := 0.4

var tilt := 0.0
var target_tilt := 0.0
var metal := METAL
var fill := 0.0
var flow := 0.0
var spill := 0.0
var overflow := 0.0
var cold := 0.0
var cold_shuts := 0
var heat := 1.0 ## metal do cadinho (endurece em 0,25)
var pour_time := 0.0
var band_time := 0.0
var manual_input := true ## false nos testes (a inclinação vem de target_tilt)
var _settle := 0.0
var _result := -2.0
var _end_time := 0.0
var _quit_armed := false
var _msg_time := 0.0
var _mold_heat := 0.0
var _keys := 0.0
var _pivot: Node3D
var _stream: MeshInstance3D
var _fill_mesh: MeshInstance3D
var _puddle: MeshInstance3D
var _inner: MeshInstance3D
var _splash: CPUParticles3D
var _glow: OmniLight3D
var _fill_mat: ShaderMaterial
var _metal_mat: ShaderMaterial
var _cavity := Vector2(0.62, 0.2)
var _cavity_x := 0.0
var _flow_meter: BandMeter
var _fill_bar: ProgressBar
var _heat_bar: ProgressBar
var _defects: Label
var _msg: Label


func _ready() -> void:
	_cavity = MOLDS.get(String(context.get("mold", "ingot")), MOLDS.ingot)
	_cavity_x = -0.34 + _cavity.x * 0.5 # o jorro cai perto da borda esquerda da cavidade
	var column := frame("Fundição: %s" % ItemDB.display_name(StringName(context.get("item", "barra_bronze"))), VIEW.x + 20.0)
	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = VIEW
	holder.stretch = true
	column.add_child(holder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(VIEW)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	holder.add_child(viewport)
	_build_scene(viewport)
	_msg = Label.new()
	_msg.add_theme_font_size_override("font_size", 14)
	_msg.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_msg.add_theme_color_override("font_outline_color", Color.BLACK)
	_msg.add_theme_constant_override("outline_size", 4)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_msg.offset_top = 10
	holder.add_child(_msg)
	_build_info(column)


## Oficina escura: chão de terra, caixa de areia com a cavidade, cavalete com o
## cadinho no pivô, o jorro de metal e o brilho laranja.
func _build_scene(viewport: SubViewport) -> void:
	var root := Node3D.new()
	viewport.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.055, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.4)
	env.ambient_light_energy = 0.5
	env.glow_enabled = true
	env.glow_intensity = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	root.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	sun.light_energy = 0.6
	root.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 48.0
	root.add_child(camera)
	camera.look_at_from_position(Vector3(0.55, 1.65, 2.05), Vector3(-0.05, 0.55, 0.0))
	var mb := MeshBuilder.new()
	mb.color(Color(0.22, 0.17, 0.13))
	mb.box(Vector3(0, -0.05, 0), Vector3(5, 0.1, 4)) # chão
	mb.color(Color(0.18, 0.12, 0.09))
	mb.box(Vector3(0, 1.2, -1.2), Vector3(5, 2.6, 0.1)) # parede
	# Caixa de areia (moldura de madeira) com a cavidade aberta no meio.
	mb.color(ObjectModels.WOOD)
	mb.box(Vector3(0, SAND_TOP * 0.5 - 0.02, 0), Vector3(1.3, SAND_TOP - 0.04, 0.9))
	var sand := Color(0.62, 0.5, 0.34)
	var cx := _cavity_x
	var hx := _cavity.x * 0.5
	var hz := _cavity.y * 0.5
	mb.color(sand)
	mb.box(Vector3((-0.62 + cx - hx) * 0.5, SAND_TOP - 0.01, 0), Vector3(cx - hx + 0.62, 0.02, 0.86))
	mb.box(Vector3((0.62 + cx + hx) * 0.5, SAND_TOP - 0.01, 0), Vector3(0.62 - cx - hx, 0.02, 0.86))
	mb.box(Vector3(cx, SAND_TOP - 0.01, (-0.43 - hz) * 0.5), Vector3(hx * 2.0, 0.02, 0.43 - hz))
	mb.box(Vector3(cx, SAND_TOP - 0.01, (0.43 + hz) * 0.5), Vector3(hx * 2.0, 0.02, 0.43 - hz))
	mb.color(sand.darkened(0.45))
	mb.box(Vector3(cx, SAND_TOP - DEPTH, 0), Vector3(hx * 2.0, 0.01, hz * 2.0)) # fundo da cavidade
	mb.color(sand.darkened(0.3))
	for side in [-1.0, 1.0]:
		mb.box(Vector3(cx + side * hx, SAND_TOP - DEPTH * 0.5, 0), Vector3(0.006, DEPTH, hz * 2.0))
		mb.box(Vector3(cx, SAND_TOP - DEPTH * 0.5, side * hz), Vector3(hx * 2.0, DEPTH, 0.006))
	mb.color(ObjectModels.WOOD_DARK)
	for z in [-0.45, 0.45]:
		mb.box(Vector3(0, SAND_TOP + 0.02, z), Vector3(1.34, 0.05, 0.04))
	# Cavalete: dois postes com o pino do cadinho.
	mb.color(ObjectModels.IRON)
	for z in [-0.28, 0.28]:
		mb.box(Vector3(PIVOT.x, PIVOT.y * 0.5, z), Vector3(0.05, PIVOT.y, 0.05))
		mb.box(Vector3(PIVOT.x, 0.03, z), Vector3(0.34, 0.06, 0.07))
	mb.tube(PackedVector3Array([PIVOT + Vector3(0, 0, -0.3), PIVOT + Vector3(0, 0, 0.3)]), 0.018, 6)
	var room := MeshInstance3D.new()
	room.mesh = mb.finish(PlacedObject._mat(), false)
	root.add_child(room)
	# Cadinho no pivô (gira em Z; a borda de despejo fica para +X).
	_pivot = Node3D.new()
	_pivot.position = PIVOT
	root.add_child(_pivot)
	var pot := MeshBuilder.new()
	pot.color(SmithingModels.CRUCIBLE)
	pot.lathe(PackedVector2Array([Vector2(0.002, -0.2), Vector2(0.11, -0.2), Vector2(0.16, -0.04), Vector2(0.17, 0.13), Vector2(0.15, 0.13), Vector2(0.14, -0.03), Vector2(0.002, -0.17)]), 12)
	pot.color(SmithingModels.CRUCIBLE.darkened(0.25))
	pot.box(LIP + Vector3(0.015, -0.005, 0), Vector3(0.05, 0.02, 0.08)) # bico
	pot.color(ItemModels.STEEL)
	pot.lathe(PackedVector2Array([Vector2(0.172, 0.0), Vector2(0.175, 0.02)]), 12) # anel do cabo
	pot.tube(PackedVector3Array([Vector3(-0.17, 0.02, 0), Vector3(-0.62, -0.02, 0)]), 0.02, 5) # cabo
	pot.color(ObjectModels.WOOD_DARK)
	pot.tube(PackedVector3Array([Vector3(-0.62, -0.02, 0), Vector3(-0.82, -0.04, 0)]), 0.03, 6)
	var pot_mesh := MeshInstance3D.new()
	pot_mesh.mesh = pot.finish(PlacedObject._mat(), false)
	_pivot.add_child(pot_mesh)
	var cold: Color = COLORS.get(StringName(context.get("metal", "barra_bronze")), COLORS[&"barra_bronze"])
	_metal_mat = _heat_material(cold)
	_inner = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.14
	disc.bottom_radius = 0.14
	disc.height = 0.01
	disc.radial_segments = 12
	_inner.mesh = disc
	_inner.material_override = _metal_mat
	_pivot.add_child(_inner)
	# Jorro, metal no molde, poça na areia, respingos e o brilho.
	_stream = MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 1.0
	rod.bottom_radius = 1.0
	rod.height = 1.0
	rod.radial_segments = 8
	_stream.mesh = rod
	_stream.material_override = _metal_mat
	_stream.visible = false
	root.add_child(_stream)
	_fill_mat = _heat_material(cold)
	_fill_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(_cavity.x - 0.01, 1.0, _cavity.y - 0.01)
	_fill_mesh.mesh = box
	_fill_mesh.material_override = _fill_mat
	_fill_mesh.visible = false
	root.add_child(_fill_mesh)
	_puddle = MeshInstance3D.new()
	var flat := CylinderMesh.new()
	flat.top_radius = 1.0
	flat.bottom_radius = 1.0
	flat.height = 0.008
	_puddle.mesh = flat
	_puddle.material_override = _fill_mat
	_puddle.visible = false
	root.add_child(_puddle)
	_splash = CPUParticles3D.new()
	_splash.amount = 40
	_splash.lifetime = 0.5
	_splash.emitting = false
	_splash.direction = Vector3.UP
	_splash.spread = 75.0
	_splash.gravity = Vector3(0, -7, 0)
	_splash.initial_velocity_min = 0.6
	_splash.initial_velocity_max = 1.6
	var drop := BoxMesh.new()
	drop.size = Vector3.ONE * 0.02
	drop.material = StationModels._glow_mat()
	_splash.mesh = drop
	_splash.color = Color(1.0, 0.6, 0.2)
	root.add_child(_splash)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.55, 0.25)
	_glow.omni_range = 2.6
	_glow.position = Vector3(_cavity_x, 0.7, 0.2)
	root.add_child(_glow)


func _heat_material(cold: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/forge_heat.gdshader")
	mat.set_shader_parameter("cold_color", Vector3(cold.r, cold.g, cold.b))
	return mat


func _build_info(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	row.add_child(_small_label("Vazão"))
	_flow_meter = BandMeter.new()
	_flow_meter.band = BAND / MAX_FLOW
	_flow_meter.danger = SPLASH / MAX_FLOW
	row.add_child(_flow_meter)
	row.add_child(_small_label("Molde"))
	_fill_bar = _bar(row, Color(1.0, 0.6, 0.2))
	row.add_child(_small_label("Cadinho"))
	_heat_bar = _bar(row, Color(0.95, 0.35, 0.15))
	_defects = _small_label("")
	row.add_child(_defects)
	var keys := Label.new()
	keys.text = "Mouse mais para baixo: inclina o cadinho (W/S ou a roda: ajuste fino) · encha sem espirrar e sem parar · Esc: desistir"
	keys.add_theme_font_size_override("font_size", 10)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.modulate = Color(1, 1, 1, 0.6)
	column.add_child(keys)


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	return label


func _bar(parent: Control, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(80, 8)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 1.0
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("fill", fill_box)
	bar.add_theme_stylebox_override("background", bg)
	parent.add_child(bar)
	return bar


# --- Regras --------------------------------------------------------------------------

## Ângulo em que o metal chega na borda (cheio: 40°, vazio: 95°).
func lip_angle() -> float:
	return 95.0 - 55.0 * clampf(metal / METAL, 0.0, 1.0)


## Avança o tempo: inclina na direção do alvo, despeja, espirra, esfria, transborda.
func step(delta: float) -> void:
	tilt = move_toward(tilt, clampf(target_tilt, 0.0, MAX_TILT), TILT_SPEED * delta)
	heat -= delta / CRUCIBLE_LIFE
	flow = 0.0 if metal <= 0.0 else clampf((tilt - lip_angle()) * POUR_RATE, 0.0, MAX_FLOW)
	var pour := minf(flow * delta, metal)
	metal -= pour
	var lost := 0.0
	if flow > SPLASH:
		lost = pour * clampf((flow - SPLASH) / (MAX_FLOW - SPLASH), 0.0, 1.0) * 0.6
		spill += lost
		_say("Rápido demais: espirrando!")
	fill += pour - lost
	if fill > 1.0:
		overflow += fill - 1.0
		fill = 1.0
		_say("Transbordou! Volte o cadinho")
	if flow > 0.0:
		pour_time += delta
		if flow >= BAND.x and flow <= BAND.y:
			band_time += delta
	if fill > 0.02 and fill < 0.98 and flow < BAND.x * 0.5:
		cold += delta
		if cold >= COLD_LIMIT:
			cold = 0.0
			cold_shuts += 1
			_say("Devagar demais: emenda fria!")
			Sfx.play("crack", -6.0, 1.4)
	else:
		cold = maxf(cold - delta, 0.0)
	_mold_heat = minf(_mold_heat + delta * 2.0, 0.85) if flow > 0.0 else maxf(_mold_heat - delta * 0.05, 0.25)
	if _result > -2.0:
		return
	if heat <= 0.25 and fill < 0.98:
		_end(quality() if fill >= 0.85 else 0.0, "O metal endureceu no cadinho!")
	elif fill >= 0.98 and flow <= 0.0:
		_settle += delta
		if _settle >= 0.6:
			_end(quality(), "Pronto! Qualidade %d%%" % int(quality() * 100.0))
	elif metal <= 0.001 and flow <= 0.0 and fill < 0.98:
		_end(quality() if fill >= 0.85 else 0.0, "Faltou metal: a peça ficou incompleta" if fill < 0.85 else "Quase cheio...")
	else:
		_settle = 0.0


## Qualidade até agora (0 = peça perdida: incompleta).
func quality() -> float:
	if fill < 0.85:
		return 0.0
	var steady := band_time / pour_time if pour_time > 0.0 else 0.0
	var q := 1.0 - spill * 2.5 - overflow * 3.0 - cold_shuts * 0.18 - maxf(0.98 - fill, 0.0) * 4.0
	return clampf(q * (0.7 + 0.3 * steady), 0.05, 1.0)


func _end(q: float, text: String) -> void:
	_result = q
	_end_time = 1.8
	target_tilt = 0.0
	_say(text, 2.2)


func _say(text: String, time := 1.2) -> void:
	_msg.text = text
	_msg_time = time


# --- Loop ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _result > -2.0:
		_end_time -= delta
		if _end_time <= 0.0:
			finish(_result)
	if manual_input and _result <= -2.0:
		var mouse_y := get_viewport().get_mouse_position().y / maxf(get_viewport().get_visible_rect().size.y, 1.0)
		var keys := (1.0 if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) else 0.0)
		_keys = clampf(_keys + keys * 30.0 * delta, -40.0, 40.0)
		target_tilt = clampf((mouse_y - 0.15) / 0.7, 0.0, 1.0) * MAX_TILT + _keys
	step(delta)
	_msg_time -= delta
	_msg.modulate.a = clampf(_msg_time * 2.0, 0.0, 1.0)
	_update_scene()
	_flow_meter.set_value(flow / MAX_FLOW)
	_fill_bar.value = fill
	_heat_bar.value = clampf((heat - 0.25) / 0.75, 0.0, 1.0)
	_defects.text = "Emendas frias: %d · Espirrou: %d%%" % [cold_shuts, int((spill + overflow) * 100.0)]


func _update_scene() -> void:
	_pivot.rotation.z = -deg_to_rad(tilt)
	var level := clampf(metal / METAL, 0.0, 1.0)
	_inner.position = Vector3(0, -0.17 + level * 0.27, 0)
	_inner.visible = level > 0.02
	_metal_mat.set_shader_parameter("temperature", lerpf(0.35, 0.82, clampf((heat - 0.25) / 0.75, 0.0, 1.0)))
	var lip := _pivot.global_transform * LIP
	var surface := SAND_TOP - DEPTH + fill * DEPTH
	_stream.visible = flow > 0.0
	if _stream.visible:
		var top := lip
		var bottom := Vector3(lip.x + 0.04, surface, 0.0)
		var radius := 0.008 + 0.03 * sqrt(flow / MAX_FLOW)
		_stream.position = (top + bottom) * 0.5
		_stream.scale = Vector3(radius, maxf(top.y - bottom.y, 0.01), radius)
	_fill_mesh.visible = fill > 0.005
	_fill_mesh.scale = Vector3(1, maxf(fill * DEPTH, 0.004), 1)
	_fill_mesh.position = Vector3(_cavity_x, SAND_TOP - DEPTH + fill * DEPTH * 0.5, 0)
	_fill_mat.set_shader_parameter("temperature", _mold_heat)
	_puddle.visible = overflow > 0.0 or spill > 0.02
	var mess := clampf(overflow + spill, 0.0, 1.0)
	_puddle.scale = Vector3(0.12 + mess * 0.5, 1, 0.08 + mess * 0.35)
	_puddle.position = Vector3(_cavity_x - _cavity.x * 0.5 - 0.06, SAND_TOP + 0.006, 0.12)
	_splash.position = Vector3(lip.x + 0.04, surface + 0.01, 0.0)
	_splash.emitting = flow > SPLASH or (fill >= 1.0 and flow > 0.0)
	_glow.light_energy = 0.4 + 1.6 * (_mold_heat if fill > 0.0 else 0.0) + (1.0 if flow > 0.0 else 0.0)


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_keys = clampf(_keys + 4.0, -40.0, 40.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_keys = clampf(_keys - 4.0, -40.0, 40.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if fill <= 0.0 and pour_time <= 0.0:
			finish(CANCELLED) # nem começou: nada é gasto
		elif _quit_armed:
			finish(0.0)
		else:
			_quit_armed = true
			_say("Esc de novo: larga a peça (perde o metal)", 2.0)
