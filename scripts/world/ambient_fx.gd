class_name AmbientFX
extends Node3D
## Partículas do clima em volta da câmera (qualidade Média/Alta):
##   - respingos onde a gota bate de verdade (chão, telhado, máquinas): raios
##     descendo do céu a cada quadro, respingo animado no shader (barato);
##   - ciscos de poeira brilhando no sol (de dia, sem chuva);
##   - areia soprada pelo vento no deserto.
## E em toda qualidade: diz se o jogador está abrigado (telhado em cima) para a
## chuva sumir em volta dele (Weather).

static var i: AmbientFX

const WIND_DIR := Vector3(0.94, 0.0, 0.33) ## mesmo rumo das nuvens

var terrain: TerrainWorld
var sheltered := false

var _splashes: MultiMeshInstance3D
var _splash_mat: ShaderMaterial
var _next := 0
var _motes: CPUParticles3D
var _sand: CPUParticles3D
var _check := 0.0
var _desert := 0.0
var _rays := 0
var _amount := 0.0


func _enter_tree() -> void:
	i = self


func _exit_tree() -> void:
	if i == self:
		i = null


func _ready() -> void:
	add_to_group("look_quality")
	_splash_mat = ShaderMaterial.new()
	_splash_mat.shader = preload("res://shaders/rain_splash.gdshader")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _splash_mesh()
	mm.instance_count = 320
	for k in mm.instance_count:
		mm.set_instance_custom_data(k, Color(-100.0, 0, 0, 0))
	_splashes = MultiMeshInstance3D.new()
	_splashes.multimesh = mm
	_splashes.material_override = _splash_mat
	_splashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_splashes.custom_aabb = AABB(Vector3(-4000, -200, -4000), Vector3(8000, 600, 8000)) # posições mudam sem refazer o AABB
	add_child(_splashes)
	_motes = _make_motes()
	add_child(_motes)
	_sand = _make_sand()
	add_child(_sand)
	apply_quality()


func apply_quality() -> void:
	var p := Look.preset()
	_rays = p.splashes
	_amount = p.particles
	_motes.amount = maxi(1, int(50 * _amount))
	_sand.amount = maxi(1, int(30 * _amount))
	_splashes.visible = _rays > 0


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	var now := Time.get_ticks_msec() / 1000.0
	_splash_mat.set_shader_parameter("now", now)
	var space := get_world_3d().direct_space_state
	_check -= delta
	if _check <= 0.0:
		_check = 0.25
		# Abrigado: algo do mundo (telhado, teto, árvore grossa) logo acima da cabeça.
		var up := PhysicsRayQueryParameters3D.create(eye, eye + Vector3.UP * 14.0, 1)
		sheltered = not space.intersect_ray(up).is_empty()
		if terrain:
			_desert = terrain.biome_at(eye.x, eye.z).desert
	var rain := Weather.i.rain if Weather.i else 0.0
	var wind := Weather.i.wind if Weather.i else 0.3
	var under := WaterManager.i != null and WaterManager.i.underwater
	# Respingos: N raios por quadro (mais com chuva forte), de cima para baixo.
	var rays := int(_rays * rain) if rain > 0.05 and not under else 0
	var mm := _splashes.multimesh
	for k in rays:
		var a := randf() * TAU
		var r := sqrt(randf()) * 11.0
		var top := eye + Vector3(cos(a) * r, 10.0, sin(a) * r)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 30.0, 1))
		if hit.is_empty():
			continue
		var n: Vector3 = hit.normal
		if n.y < 0.3:
			continue
		var s := randf_range(0.7, 1.25)
		mm.set_instance_transform(_next, Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * s), hit.position + n * 0.02))
		mm.set_instance_custom_data(_next, Color(now - randf() * 0.05, 0, 0, 0))
		_next = (_next + 1) % mm.instance_count
	# Ciscos no sol: de dia, sem chuva, fora d'água.
	var sun := DayNight.i.sun_factor if DayNight.i else 1.0
	_motes.global_position = eye
	_motes.emitting = _amount > 0.0 and sun > 0.4 and rain < 0.1 and not under
	_motes.gravity = WIND_DIR * (0.15 + wind * 0.35) + Vector3.DOWN * 0.02
	# Areia soprada: deserto com vento.
	_sand.global_position = Vector3(eye.x, eye.y - 1.4, eye.z) - WIND_DIR * 10.0
	_sand.emitting = _amount > 0.0 and _desert > 0.35 and wind > 0.2 and rain < 0.1 and not under
	_sand.initial_velocity_min = 3.0 + wind * 4.0
	_sand.initial_velocity_max = 5.0 + wind * 6.0


## Anel no chão + 5 gotinhas (quadradinhos cruzados).
static func _splash_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := 10
	for k in ring:
		var a0 := TAU * k / ring
		var a1 := TAU * (k + 1) / ring
		var inner := 0.035
		var outer := 0.06
		var p := [Vector3(cos(a0) * inner, 0, sin(a0) * inner), Vector3(cos(a0) * outer, 0, sin(a0) * outer),
			Vector3(cos(a1) * outer, 0, sin(a1) * outer), Vector3(cos(a1) * inner, 0, sin(a1) * inner)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(0, 0, 0))
			st.set_uv2(Vector2.ZERO)
			st.add_vertex(p[idx])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for d in 5:
		var a := TAU * d / 5.0 + rng.randf() * 0.5
		var dir := Vector2(cos(a), sin(a)) * rng.randf_range(0.6, 1.0)
		var jump := rng.randf_range(0.8, 1.3)
		var h := 0.012
		for q in [[Vector3(-h, -h, 0), Vector3(h, -h, 0), Vector3(h, h, 0), Vector3(-h, h, 0)],
				[Vector3(0, -h, -h), Vector3(0, -h, h), Vector3(0, h, h), Vector3(0, h, -h)]]:
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color(1, jump, 0))
				st.set_uv2(dir)
				st.add_vertex(q[idx])
	return st.commit()


static func _soft_dot(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## Aparece, fica e some (alfa 0 → a → a → 0).
static func _fade(c: Color, a: float, edge: float) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, edge, 1.0 - edge, 1.0])
	g.colors = PackedColorArray([Color(c, 0.0), Color(c, a), Color(c, a), Color(c, 0.0)])
	return g


func _make_motes() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 7.0
	p.preprocess = 4.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(5, 2.0, 5)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.12
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.color_ramp = _fade(Color(0.55, 0.5, 0.38), 1.0, 0.3)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.016, 0.016)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Somado à imagem: no céu claro quase some, contra a sombra vira um cisco brilhando.
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	quad.material = m
	p.mesh = quad
	p.emitting = false
	return p


func _make_sand() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 4.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(12, 0.8, 12)
	p.direction = WIND_DIR + Vector3.UP * 0.05
	p.spread = 12.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.6
	p.color_ramp = _fade(Color(0.86, 0.74, 0.54), 0.08, 0.3)
	var quad := QuadMesh.new()
	quad.size = Vector2(3.2, 0.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_texture = _soft_dot(32)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	quad.material = m
	p.mesh = quad
	p.emitting = false
	return p
