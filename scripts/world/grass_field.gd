class_name GrassField
extends Node3D
## Grama densa perto do jogador (qualidade Média/Alta; na Baixa só ficam os tufos
## espalhados do TerrainProps). Quadrados de 16 m com moitinhas de lâminas em
## MultiMesh, gerados em thread com as MESMAS alturas e cores da malha do chão
## (grade de 1,6 m, mesmos triângulos): a grama assenta certinho e só nasce onde o
## chão é de grama (nada em rua, cidade, areia, pedra, neve, água ou encosta).
## Balança no vento e encolhe até sumir na borda (shaders/grass_blades.gdshader).
## Pisos construídos, objetos colocados e blocos cavados/postos tiram a grama de baixo deles.

const TILE := 16.0
const STEP := TerrainWorld.STEP ## grade das alturas geradas do terreno (1,6 m)
const MAX_TASKS := 3

var terrain: TerrainWorld
var _tiles := {} ## Vector2i -> MultiMeshInstance3D
var _raw := {} ## Vector2i -> {"t": Array[Transform3D], "c": PackedColorArray}
var _tasks := {} ## Vector2i -> id do WorkerThreadPool
var _results := {}
var _mutex := Mutex.new()
var _mesh: ArrayMesh
var _material: ShaderMaterial
var _radius := 0.0
var _density := 0.0
var _timer := 0.0
var _blocked := {} ## Vector2i (célula de 1 m) -> true
var _blocked_sig := -1
var _generation := 0 ## muda com a qualidade: resultados velhos são jogados fora
var _level_rects: Array[Rect2] = [] ## chão e prédios fixos da área inicial (main.tscn/Level)


func _ready() -> void:
	add_to_group("look_quality")
	_mesh = _clump_mesh()
	if terrain:
		terrain.blocks_changed.connect(_on_blocks_changed)
	# Área inicial: o asfalto/calçada da cena fica por cima do terreno (sem grama ali).
	var level := get_parent().get_node_or_null("Level")
	if level:
		for node in level.get_children():
			if node is CSGShape3D:
				var box: AABB = node.global_transform * (node as CSGShape3D).get_aabb()
				_level_rects.append(Rect2(box.position.x - 0.3, box.position.z - 0.3, box.size.x + 0.6, box.size.z + 0.6))
	apply_quality()


func _exit_tree() -> void:
	for coord in _tasks:
		WorkerThreadPool.wait_for_task_completion(_tasks[coord])
	_tasks.clear()


func apply_quality() -> void:
	var p := Look.preset()
	_radius = p.grass_radius
	_density = p.grass_density
	if _material == null:
		_material = Look.foliage(null, _radius)
	_material.set_shader_parameter("fade_far", _radius)
	_generation += 1
	for coord in _tiles:
		_tiles[coord].queue_free()
	_tiles.clear()
	_raw.clear()


var last_ms := 0.0


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_process_inner(delta)
	last_ms = (Time.get_ticks_usec() - t0) / 1000.0


func _process_inner(delta: float) -> void:
	if terrain == null or _radius <= 0.0:
		return
	_collect()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var center := camera.global_position
	_refresh_blocked(center)
	var reach := _radius + TILE * 0.75
	var here := Vector2i(floori(center.x / TILE), floori(center.z / TILE))
	var span := int(ceil(reach / TILE))
	var wanted := []
	for j in range(-span, span + 1):
		for i in range(-span, span + 1):
			var coord := here + Vector2i(i, j)
			var mid := (Vector2(coord) + Vector2(0.5, 0.5)) * TILE
			var d := mid.distance_to(Vector2(center.x, center.z))
			if d <= reach:
				wanted.append([d, coord])
	wanted.sort_custom(func(a, b): return a[0] < b[0])
	var keep := {}
	for w in wanted:
		keep[w[1]] = true
	for coord in _tiles.keys():
		if not keep.has(coord):
			_tiles[coord].queue_free()
			_tiles.erase(coord)
			_raw.erase(coord)
	for w in wanted:
		var coord: Vector2i = w[1]
		if _tiles.has(coord) or _tasks.has(coord):
			continue
		if _tasks.size() >= MAX_TASKS:
			break
		_tasks[coord] = WorkerThreadPool.add_task(_generate.bind(coord, _density, _generation), VoxelWorld.STREAM_PRIORITY)


## Recolhe o que as threads terminaram (até 2 quadrados por quadro).
func _collect() -> void:
	var made := 0
	for coord in _tasks.keys():
		if made >= 2:
			break
		if not WorkerThreadPool.is_task_completed(_tasks[coord]):
			continue
		WorkerThreadPool.wait_for_task_completion(_tasks[coord])
		_tasks.erase(coord)
		_mutex.lock()
		var data: Dictionary = _results.get(coord, {})
		_results.erase(coord)
		_mutex.unlock()
		if data.is_empty() or data.gen != _generation:
			continue
		_raw[coord] = data
		_build(coord)
		made += 1


func _build(coord: Vector2i) -> void:
	var data: Dictionary = _raw[coord]
	var origin := Vector3(coord.x * TILE, 0, coord.y * TILE)
	var keep := []
	for k in data.t.size():
		var t: Transform3D = data.t[k]
		var world := origin + t.origin
		if _blocked.has(Vector2i(floori(world.x), floori(world.z))):
			continue
		if not terrain.blocks.is_empty() and _on_edited(world):
			continue
		if VoxelWorld.i and VoxelWorld.i.foliage_hidden(world.x, world.z):
			continue # cavado/posto em voxel
		var on_level := false
		for rect in _level_rects:
			if rect.has_point(Vector2(world.x, world.z)):
				on_level = true
				break
		if on_level:
			continue
		keep.append(k)
	if _tiles.has(coord):
		_tiles[coord].queue_free()
		_tiles.erase(coord)
	if keep.is_empty():
		_tiles[coord] = Node3D.new() # quadrado sem grama (marca como feito)
		add_child(_tiles[coord])
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mesh
	mm.instance_count = keep.size()
	for n in keep.size():
		mm.set_instance_transform(n, data.t[keep[n]])
		mm.set_instance_color(n, data.c[keep[n]])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.position = origin
	add_child(mmi)
	_tiles[coord] = mmi


## Bloco cavado/posto nessa coluna ou nas vizinhas (a rampa delas): sem grama.
func _on_edited(world: Vector3) -> bool:
	var col := TerrainWorld.column_at(world.x, world.z)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if terrain.blocks.has(col + Vector2i(dx, dz)):
				return true
	return false


## Cavaram/puseram bloco: refaz a grama do quadrado (e do vizinho, na borda).
func _on_blocks_changed(col: Vector2i) -> void:
	if not TerrainWorld.is_column(col):
		for coord in _raw.keys():
			_build(coord)
		return
	var p := (Vector2(col) + Vector2(0.5, 0.5)) * TerrainWorld.GRID
	var seen := {}
	for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var q: Vector2 = p + d * TerrainWorld.GRID * 1.5
		var coord := Vector2i(floori(q.x / TILE), floori(q.y / TILE))
		if not seen.has(coord) and _raw.has(coord):
			seen[coord] = true
			_build(coord)


## Pisos e objetos colocados: sem grama atravessando. Recalcula quando muda a
## quantidade e refaz só os quadrados perto do jogador.
func _refresh_blocked(center: Vector3) -> void:
	var world := get_parent()
	var bm := world.get_node_or_null("Building") as BuildingManager
	var placed := world.get_node_or_null("Placed") as PlacedManager
	var sig := (bm.pieces.size() if bm else 0) + (placed.objects.size() if placed else 0) * 7919
	if sig == _blocked_sig:
		return
	_blocked_sig = sig
	_blocked.clear()
	if bm:
		for piece in bm.pieces.values():
			if not is_instance_valid(piece) or piece.kind != BuildPiece.Kind.FLOOR:
				continue
			var o := Vector3(piece.cell) * BuildPiece.SEG
			for z in range(floori(o.z) - 1, ceili(o.z + BuildPiece.SIZE) + 1):
				for x in range(floori(o.x) - 1, ceili(o.x + BuildPiece.SIZE) + 1):
					_blocked[Vector2i(x, z)] = true
	if placed:
		for obj in placed.objects.values():
			if not is_instance_valid(obj):
				continue
			var p: Vector3 = obj.global_position
			for z in range(floori(p.z) - 1, floori(p.z) + 2):
				for x in range(floori(p.x) - 1, floori(p.x) + 2):
					_blocked[Vector2i(x, z)] = true
	for coord in _raw.keys():
		var mid := (Vector2(coord) + Vector2(0.5, 0.5)) * TILE
		if mid.distance_to(Vector2(center.x, center.z)) < TILE * 2.0:
			_build(coord)


## Thread: alturas/cores da grade de 1,6 m do chão e as moitinhas sorteadas.
func _generate(coord: Vector2i, density: float, gen: int) -> void:
	var per := roundi(TILE / STEP) # 10 quadrados de 1,6 m por quadrado de grama
	var n := per + 1
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	var cs := PackedColorArray()
	cs.resize(n * n)
	var ok := PackedByteArray()
	ok.resize(n * n)
	for j in n:
		for i in n:
			# Mesmo ponto da grade do terreno (índice global: alturas idênticas às do chão).
			var x := (coord.x * per + i) * STEP
			var z := (coord.y * per + j) * STEP
			var biome := terrain.biome_at(x, z)
			var h := terrain._height_from(x, z, biome)
			var c := terrain._color_for(x, z, h, biome)
			var idx := j * n + i
			hs[idx] = h
			cs[idx] = c
			var good := _grassy(c) and h > TerrainWorld.SEA_LEVEL + 0.8
			if good:
				var lake := Lakes.at(terrain.lakes, x, z)
				if not lake.is_empty() and h < lake.level + 0.5:
					good = false
			if good:
				var river := terrain.river_at(x, z)
				if not river.is_empty() and h < river.level + 0.5:
					good = false
			if good and terrain.cave_mouth_at(x, z, 1.6):
				good = false # boca de caverna: a grama ficaria flutuando
			ok[idx] = 1 if good else 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([terrain.seed, coord.x, coord.y, 77])
	var transforms := []
	var colors := PackedColorArray()
	for k in int(TILE * TILE * density):
		var lx := rng.randf() * TILE
		var lz := rng.randf() * TILE
		var ci := mini(int(lx / STEP), n - 2)
		var cj := mini(int(lz / STEP), n - 2)
		var i0 := cj * n + ci
		var i1 := i0 + 1
		var i2 := i0 + n
		var i3 := i2 + 1
		var r1 := rng.randf()
		var r2 := rng.randf()
		var r3 := rng.randf()
		if ok[i0] + ok[i1] + ok[i2] + ok[i3] < 4:
			continue
		# Encosta íngreme vira rocha na malha do chão: sem grama ali.
		if absf(hs[i0] - hs[i3]) / (STEP * 1.41) > 0.85:
			continue
		var fx := (lx - ci * STEP) / STEP
		var fz := (lz - cj * STEP) / STEP
		var h: float
		if fx + fz <= 1.0:
			h = hs[i0] + (hs[i1] - hs[i0]) * fx + (hs[i2] - hs[i0]) * fz
		else:
			h = hs[i3] + (hs[i2] - hs[i3]) * (1.0 - fx) + (hs[i1] - hs[i3]) * (1.0 - fz)
		var c: Color = cs[i0].lerp(cs[i1], fx).lerp(cs[i2].lerp(cs[i3], fx), fz)
		var s := lerpf(0.75, 1.25, r1)
		var basis := Basis(Vector3.UP, r2 * TAU).scaled(Vector3(s, s * lerpf(0.7, 1.35, r3), s))
		transforms.append(Transform3D(basis, Vector3(lx, h - 0.03, lz)))
		# Lâmina um pouco mais clara e variada que o chão.
		var blade := c.lightened(0.1) * lerpf(0.86, 1.12, r3)
		blade.a = 1.0
		colors.append(blade)
	_mutex.lock()
	_results[coord] = {"t": transforms, "c": colors, "gen": gen}
	_mutex.unlock()


static func _grassy(c: Color) -> bool:
	return c.g > c.r * 0.92 and c.g > c.b * 1.25 and c.g > 0.18


## Moitinha: 7 lâminas triangulares em volta do centro, umas tortas.
static func _clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for b in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 0.17)
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var face := rng.randf() * TAU
		var side := Vector3(cos(face), 0, sin(face)) * rng.randf_range(0.03, 0.045)
		var height := rng.randf_range(0.26, 0.48)
		var lean := Vector3(rng.randf_range(-0.09, 0.09), 0, rng.randf_range(-0.09, 0.09))
		var tip := base + Vector3.UP * height + lean
		for v in [base - side, tip, base + side]:
			st.set_normal(Vector3.UP) # iluminada como o chão (dos dois lados)
			st.set_color(Color.WHITE)
			st.add_vertex(v)
	return st.commit()
