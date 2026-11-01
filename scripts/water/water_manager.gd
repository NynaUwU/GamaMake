class_name WaterManager
extends Node3D
## Nó "Water" da cena principal: desenha a água dos lagos perto do jogador,
## cria a vida de cada lago (peixes, crustáceos, plantas) quando chega perto e
## cuida do efeito debaixo d'água (tela ondulando e azulada, neblina curta,
## som abafado, bolhas). Lagos de neve congelam: dá para andar no gelo.
## Também responde "quão fundo estou?" (nadar) e "onde a linha cai?" (pesca).

const DRAW := 260.0
const LIFE := 90.0

static var i: WaterManager

var underwater := false
var under_depth := 0.0 ## 0..1 (superfície..fundo), para o efeito
var _bodies := {} # índice do lago -> Node3D (superfície)
var _lives := {} # índice do lago -> LakeLife
## Estoque de bichos de cada lago (índice -> {id: quantos}). O padrão é sorteado
## pela semente do lago (fixo para o mundo); pescar diminui; a cada REFILL_DAYS
## dias volta ao padrão. Vai no save.
const REFILL_DAYS := 5
var stock := {}
var _refill_day := 1
var _timer := 0.0
var _overlay: ColorRect
var _overlay_layer: CanvasLayer
var _bubbles: CPUParticles3D
var _lowpass := -1
var _water_shader: Shader = preload("res://shaders/water.gdshader")


func _enter_tree() -> void:
	i = self


func _exit_tree() -> void:
	if i == self:
		i = null
	_set_lowpass(false)


func _terrain() -> TerrainWorld:
	return get_parent().get_node_or_null("Terrain") as TerrainWorld


func lakes() -> Array:
	var t := _terrain()
	return t.lakes if t else []


## Quantos de cada bicho o lago tem por padrão (sorteado uma vez pela semente do lago).
static func default_stock(lake: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = lake.seed + 99
	if lake.kind == "pond":
		return {&"baixo": rng.randi_range(2, 6), &"camarao": rng.randi_range(3, 8), &"caranguejo": rng.randi_range(1, 4),
			&"caranguejo_aranha": rng.randi_range(0, 3)}
	return {&"baixo": rng.randi_range(4, 9), &"atum": rng.randi_range(1, 4), &"camarao": rng.randi_range(5, 10),
		&"lagosta": rng.randi_range(1, 4), &"caranguejo": rng.randi_range(3, 6), &"caranguejo_aranha": rng.randi_range(1, 4)}


func stock_of(index: int) -> Dictionary:
	if not stock.has(index):
		stock[index] = default_stock(lakes()[index])
	return stock[index]


func caught(index: int, id: StringName) -> void:
	var s := stock_of(index)
	s[id] = maxi(s.get(id, 0) - 1, 0)


## A cada 5 dias de jogo os lagos voltam à quantidade padrão.
func _check_refill() -> void:
	if DayNight.i == null or DayNight.i.day < _refill_day + REFILL_DAYS:
		return
	_refill_day = DayNight.i.day
	stock.clear()
	for index in _lives:
		_lives[index].top_up(stock_of(index))


func persist_key() -> String:
	return "water"


func save_data() -> Dictionary:
	return {"stock": stock.duplicate(true), "refill": _refill_day}


func load_data(data: Dictionary) -> void:
	stock = data.get("stock", {}).duplicate(true)
	_refill_day = data.get("refill", 1)


func _ready() -> void:
	add_to_group("persist")
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = -1 # por cima do 3D, por baixo do HUD
	add_child(_overlay_layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/underwater.gdshader")
	_overlay.material = material
	_overlay.visible = false
	_overlay_layer.add_child(_overlay)
	# Som abafado debaixo d'água: passa-baixa no Master (desligado fora d'água).
	var lowpass := AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 700.0
	AudioServer.add_bus_effect(0, lowpass)
	_lowpass = AudioServer.get_bus_effect_count(0) - 1
	_set_lowpass(false)


func _set_lowpass(on: bool) -> void:
	if _lowpass >= 0 and _lowpass < AudioServer.get_bus_effect_count(0):
		AudioServer.set_bus_effect_enabled(0, _lowpass, on)


## Quantos metros abaixo da superfície está o ponto (negativo = fora d'água).
func depth_at(pos: Vector3) -> float:
	var lake := Lakes.at(lakes(), pos.x, pos.z)
	if lake.is_empty() or lake.frozen:
		var terrain := _terrain()
		if terrain == null:
			return -INF
		var river: Dictionary = terrain.river_at(pos.x, pos.z)
		if not river.is_empty():
			return river.level - pos.y
		if pos.y < TerrainWorld.SEA_LEVEL + 3.0 and terrain.sea_at(pos.x, pos.z):
			return TerrainWorld.SEA_LEVEL - pos.y
		return -INF
	return lake.level - pos.y


func lake_at(pos: Vector3) -> Dictionary:
	return Lakes.at(lakes(), pos.x, pos.z)


## Pesca: ponto onde o raio (da câmera) encontra a água de algum lago, ou INF.
func ray_water(from: Vector3, dir: Vector3, max_dist: float) -> Vector3:
	var best := Vector3.INF
	var best_t := max_dist
	if dir.y >= -0.01:
		return best
	for lake in lakes():
		if lake.frozen or Vector2(from.x, from.z).distance_to(lake.center) > lake.radius + max_dist:
			continue
		var t: float = (lake.level - from.y) / dir.y
		if t <= 0.0 or t >= best_t:
			continue
		var p := from + dir * t
		if Vector2(p.x, p.z).distance_to(lake.center) < lake.radius * 0.97:
			best = p
			best_t = t
	return best


var _rivers_built := false


## Faixas de água dos rios (UV.x = 1 no meio, 0 na margem: o shader clareia a beira).
func _build_rivers() -> void:
	_rivers_built = true
	var terrain := _terrain()
	if terrain == null:
		return
	for river in terrain.rivers:
		var pts: PackedVector2Array = river.points
		var levels: PackedFloat32Array = river.levels
		var half: float = river.width * 0.5 + 0.6
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var normals := PackedVector3Array()
		for i in pts.size() - 1:
			var dir_a := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var dir_b := (pts[mini(i + 2, pts.size() - 1)] - pts[i]).normalized()
			var side_a := Vector2(-dir_a.y, dir_a.x) * half
			var side_b := Vector2(-dir_b.y, dir_b.x) * half
			var ca := Vector3(pts[i].x, levels[i], pts[i].y)
			var cb := Vector3(pts[i + 1].x, levels[i + 1], pts[i + 1].y)
			var la := ca + Vector3(side_a.x, 0, side_a.y)
			var ra := ca - Vector3(side_a.x, 0, side_a.y)
			var lb := cb + Vector3(side_b.x, 0, side_b.y)
			var rb := cb - Vector3(side_b.x, 0, side_b.y)
			for tri in [[la, 0.0, ca, 1.0, cb, 1.0], [la, 0.0, cb, 1.0, lb, 0.0], [ca, 1.0, ra, 0.0, rb, 0.0], [ca, 1.0, rb, 0.0, cb, 1.0]]:
				for k in 3:
					verts.append(tri[k * 2])
					uvs.append(Vector2(tri[k * 2 + 1], 0))
					normals.append(Vector3.UP)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := ShaderMaterial.new()
		material.shader = _water_shader
		material.set_shader_parameter("frozen", 0.0)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


## Mar em volta da ilha: uma malha só, em células de 64 m, cobrindo de perto
## da costa até bem além do fim do mapa (o horizonte vira mar). Por baixo, um
## fundo escuro para não ver o vazio depois do último chunk de terreno.
func _build_sea() -> void:
	var terrain := _terrain()
	if terrain == null:
		return
	var cell := 64.0
	var reach := terrain.world_size * 0.5 + 2500.0
	var n := int(reach * 2.0 / cell)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var y := TerrainWorld.SEA_LEVEL
	for j in n:
		for i in n:
			var x0 := -reach + i * cell
			var z0 := -reach + j * cell
			var nearest := INF
			for c in [Vector2(x0, z0), Vector2(x0 + cell, z0), Vector2(x0, z0 + cell), Vector2(x0 + cell, z0 + cell)]:
				nearest = minf(nearest, terrain.coast_distance(c.x, c.y))
			if nearest > TerrainWorld.SEA_BAND:
				continue
			var a := Vector3(x0, y, z0)
			var b := Vector3(x0 + cell, y, z0)
			var c := Vector3(x0 + cell, y, z0 + cell)
			var d := Vector3(x0, y, z0 + cell)
			for v in [a, b, c, a, c, d]:
				verts.append(v)
				uvs.append(Vector2(1.0, 0.0))
				normals.append(Vector3.UP)
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = _water_shader
	material.set_shader_parameter("frozen", 0.0)
	material.set_shader_parameter("deep", Color(0.16, 0.36, 0.48, 0.72))
	material.set_shader_parameter("wave_height", 0.08)
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = mesh
	sea.material_override = material
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	# Fundo além do mapa (o terreno cobre ele dentro da ilha).
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2.ONE * reach * 2.0
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.2, 0.24, 0.22)
	floor_mat.roughness = 1.0
	var bed := MeshInstance3D.new()
	bed.name = "SeaBed"
	bed.mesh = floor_mesh
	bed.material_override = floor_mat
	bed.position.y = TerrainWorld.SEA_LEVEL - 22.5
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bed)


## Ninguém nada para fora do mapa: empurra de volta antes da borda.
func _keep_inside(body: Node3D) -> void:
	var terrain := _terrain()
	if terrain == null:
		return
	var limit := terrain.world_size * 0.5 - 40.0
	var p := body.global_position
	if absf(p.x) > limit or absf(p.z) > limit:
		body.global_position = Vector3(clampf(p.x, -limit, limit), p.y, clampf(p.z, -limit, limit))


func _process(delta: float) -> void:
	if not _rivers_built:
		_build_rivers()
		_build_sea()
	var world := get_parent()
	var player: Node3D = world.get("player")
	if player == null:
		return
	_keep_inside(player)
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_stream(player.global_position)
		_check_refill()
	_update_underwater(delta)


func _stream(at: Vector3) -> void:
	var list := lakes()
	for index in list.size():
		var lake: Dictionary = list[index]
		var d: float = Vector2(at.x, at.z).distance_to(lake.center) - lake.radius
		if d < DRAW and not _bodies.has(index):
			_bodies[index] = _make_surface(lake)
		elif d > DRAW + 80.0 and _bodies.has(index):
			_bodies[index].queue_free()
			_bodies.erase(index)
		if d < LIFE and not _lives.has(index) and not lake.frozen:
			var life := LakeLife.new()
			life.name = "Life_%d" % index
			add_child(life)
			life.setup(lake, _terrain(), index, stock_of(index))
			_lives[index] = life
		elif d > LIFE + 40.0 and _lives.has(index):
			_lives[index].queue_free()
			_lives.erase(index)


## Disco de água no nível do lago (UV.x = 1 no centro, 0 na borda).
func _make_surface(lake: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(lake.center.x, lake.level, lake.center.y)
	add_child(root)
	var segments := 48
	var radius: float = lake.radius * 1.08
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	for k in segments:
		var a0 := TAU * k / segments
		var a1 := TAU * (k + 1) / segments
		for v in [[Vector3.ZERO, 1.0], [Vector3(cos(a1), 0, sin(a1)) * radius, 0.0], [Vector3(cos(a0), 0, sin(a0)) * radius, 0.0]]:
			verts.append(v[0])
			uvs.append(Vector2(v[1], 0))
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = _water_shader
	material.set_shader_parameter("frozen", 1.0 if lake.frozen else 0.0)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	if lake.frozen:
		# Gelo: chão de verdade por cima da água.
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = 0.3
		shape.shape = cylinder
		shape.position.y = -0.15
		body.add_child(shape)
		root.add_child(body)
	return root


func _update_underwater(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var depth := depth_at(cam.global_position)
	var now := depth > 0.05
	if now != underwater:
		underwater = now
		_overlay.visible = now
		_set_lowpass(now)
		if now:
			Sfx.play("thud", -12.0, 0.6) # tchibum abafado
		if _bubbles == null:
			_bubbles = _make_bubbles()
		_bubbles.emitting = now
	if _bubbles and _bubbles.get_parent() != cam:
		_bubbles.reparent(cam, false)
	if now:
		var lake := lake_at(cam.global_position)
		under_depth = clampf(depth / maxf(lake.get("depth", 2.5), 1.0), 0.0, 1.0) # rio/mar não têm "depth" de lago
		(_overlay.material as ShaderMaterial).set_shader_parameter("depth", under_depth)


func _make_bubbles() -> CPUParticles3D:
	var bubbles := CPUParticles3D.new()
	bubbles.amount = 40
	bubbles.lifetime = 2.5
	bubbles.position = Vector3(0, -0.3, -1.2)
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(1.5, 0.6, 1.0)
	bubbles.direction = Vector3.UP
	bubbles.spread = 15.0
	bubbles.gravity = Vector3(0, 0.8, 0)
	bubbles.initial_velocity_min = 0.2
	bubbles.initial_velocity_max = 0.6
	bubbles.local_coords = false
	var mesh := SphereMesh.new()
	mesh.radius = 0.02
	mesh.height = 0.04
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.8, 0.95, 1.0, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	bubbles.mesh = mesh
	bubbles.emitting = false
	add_child(bubbles)
	return bubbles
