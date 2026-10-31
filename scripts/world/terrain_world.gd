class_name TerrainWorld
extends Node3D
## Mapa aberto gerado por semente: planícies, montanhas, inverno e um deserto
## grande e quase plano. O terreno é dividido em pedaços (chunks) que são
## criados perto do player e apagados longe dele, então o mapa pode ser
## grande sem pesar.
##
## Layout (com variação pela semente):
##   norte (-Z)  -> inverno (morros com neve, pinheiros)
##   meio        -> planícies (grama, árvores) com cadeias de montanhas
##   sul (+Z)    -> deserto grande e quase plano (dunas baixas, cactos)
## O centro (0, 0) é achatado para a cidade inicial. As bordas sobem em
## montanhas para fechar o mapa.
##
## Desempenho: alturas, cores e triângulos de cada chunk são calculados em
## threads (WorkerThreadPool); a thread principal só cria os nós prontos.

signal chunk_loaded(coord: Vector2i)

@export var seed := 1337
@export var randomize_seed := false ## true = mapa diferente a cada partida
@export var world_size := 3072.0 ## lado do mapa em metros
@export var chunk_size := 64.0
@export var cell := 2.0 ## distância entre vértices (2 m = visual low-poly)
@export var view_distance := 220.0 ## além da neblina mais longa
@export var chunks_per_frame := 1
@export var town_radius := 45.0 ## área plana da cidade no centro
@export var remote_view_distance := 130.0 ## host online: terreno em volta dos outros jogadores
@export var player_path: NodePath

const COLOR_GRASS := Color(0.32, 0.42, 0.2)
const COLOR_DRY_GRASS := Color(0.5, 0.48, 0.28)
const COLOR_SAND := Color(0.78, 0.66, 0.45)
const COLOR_ROCK := Color(0.42, 0.4, 0.38)
const COLOR_SNOW := Color(0.8, 0.86, 0.98) # puxado para o azul (o sol do fim de tarde é laranja)

var _noise_temp := FastNoiseLite.new()
var _noise_rugged := FastNoiseLite.new()
var _noise_hills := FastNoiseLite.new()
var _noise_ridge := FastNoiseLite.new()
var _noise_dunes := FastNoiseLite.new()
var _noise_bumps := FastNoiseLite.new()
var _noise_detail := FastNoiseLite.new()
var cities: Array = [] ## cidades geradas pela semente (CityGen): centro, raio, tamanho, altura, lotes, ruas
var avenues: Array = [] ## avenidas entre as cidades maiores ({a, b, width, kind})
var race_track: Array = [] ## segmentos de asfalto da pista de corrida (RaceTrack)
var track: Dictionary = {} ## lugar e traçado da pista (RaceTrack.plan)
var lakes: Array = [] ## lagos e lagoas (Lakes.place): centro, raio, nível da água, fundo
var _avenue_grid := {} # Vector2i (células de AVENUE_CELL m) -> trechos de avenida que alcançam a célula
const AVENUE_CELL := 64.0
var _chunks := {} # Vector2i -> Node3D
var _tasks := {} # Vector2i -> id da tarefa em andamento
var _results := {} # Vector2i -> dados prontos (escrito pelas threads)
var _mutex := Mutex.new()
var _material: StandardMaterial3D
var _props: TerrainProps
var _player: Node3D


func _ready() -> void:
	if randomize_seed:
		seed = randi()
	if Net.i.world_seed != 0:
		seed = Net.i.world_seed # multiplayer: todo mundo gera o mesmo mapa
	_setup_noise()
	cities = CityGen.place_cities(self)
	avenues = CityGen.connect_cities(cities)
	_avenue_grid = _index_roads(avenues)
	track = RaceTrack.plan(self)
	if not track.is_empty():
		race_track = track.segments
	lakes = Lakes.place(self)
	_material = _make_material()
	_props = TerrainProps.new()
	_player = get_node_or_null(player_path)
	if _player:
		# Gera o entorno de uma vez antes de começar (o resto vem aos poucos).
		update_around(_player.global_position, -1, 140.0)


func _setup_noise() -> void:
	var setups := [
		[_noise_temp, 1.0 / 700.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2],
		[_noise_rugged, 1.0 / 750.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2],
		[_noise_hills, 1.0 / 170.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 4],
		[_noise_ridge, 1.0 / 420.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3],
		[_noise_dunes, 1.0 / 75.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2],
		[_noise_bumps, 1.0 / 55.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2],
		[_noise_detail, 1.0 / 25.0, FastNoiseLite.TYPE_SIMPLEX, 2],
	]
	for i in setups.size():
		var noise: FastNoiseLite = setups[i][0]
		noise.seed = seed + i * 1013
		noise.frequency = setups[i][1]
		noise.noise_type = setups[i][2]
		noise.fractal_octaves = setups[i][3]


# --- Consultas (usadas por spawner, atmosfera, props) --------------------------

## Peso de cada bioma no ponto (somam 1): desert, plains, winter, mountain.
func biome_at(x: float, z: float) -> Dictionary:
	var half := world_size * 0.5
	var temperature := clampf(0.5 + (z / half) * 0.55 + _noise_temp.get_noise_2d(x, z) * 0.22, 0.0, 1.0)
	var desert := smoothstep(0.62, 0.72, temperature)
	var winter := 1.0 - smoothstep(0.28, 0.38, temperature)
	var temperate := clampf(1.0 - desert - winter, 0.0, 1.0)
	var rugged := _noise_rugged.get_noise_2d(x, z) * 0.5 + 0.5
	# Limiar mais baixo e ruído mais largo = regiões de montanha maiores.
	var hot_cut := 1.0 - smoothstep(0.55, 0.76, temperature) # montanhas somem devagar perto do deserto
	var mountain := smoothstep(0.44, 0.66, rugged) * hot_cut
	# "Profundidade" dentro da cordilheira: o pé é baixo (morros) e os picos só
	# sobem bem no meio dela, então a borda nunca vira um paredão.
	var depth := smoothstep(0.5, 0.92, rugged) * hot_cut * hot_cut
	var dist := Vector2(x, z).length()
	depth *= smoothstep(town_radius * 2.4, town_radius * 9.0, dist) # sem picos perto da cidade
	mountain = maxf(mountain, _border(x, z))
	depth = maxf(depth, _border(x, z))
	mountain *= 1.0 - _town_mask(x, z)
	return {
		"desert": desert * (1.0 - mountain), "plains": temperate * (1.0 - mountain),
		"winter": winter * (1.0 - mountain), "mountain": mountain, "temperature": temperature,
		"depth": depth,
	}


func height_at(x: float, z: float) -> float:
	var biome := biome_at(x, z)
	return _height_from(x, z, biome)


## Quanto o ponto está "na neve": bioma de inverno ou montanha acima da linha de neve.
func snow_at(x: float, z: float) -> float:
	var biome := biome_at(x, z)
	var h := _height_from(x, z, biome)
	var cold: float = biome.winter + biome.mountain * (1.0 - smoothstep(0.35, 0.6, biome.temperature))
	return clampf(maxf(cold, smoothstep(65.0, 85.0, h)), 0.0, 1.0)


## Altura final: relevo + chão achatado das cidades.
func _height_from(x: float, z: float, biome: Dictionary) -> float:
	var h := raw_height(x, z, biome)
	var p := Vector2(x, z)
	# Avenidas: niveladas na largura, seguindo o relevo no comprimento.
	for road in _avenue_grid.get(Vector2i(floori(x / AVENUE_CELL), floori(z / AVENUE_CELL)), []):
		if p.x < road.lo.x or p.y < road.lo.y or p.x > road.hi.x or p.y > road.hi.y:
			continue
		var info := _segment_info(p, road.a, road.b)
		var reach: float = road.width * 0.5 + 18.0
		if info.y < reach:
			var on_line: Vector2 = road.a.lerp(road.b, info.x)
			var line_h := raw_height(on_line.x, on_line.y, biome_at(on_line.x, on_line.y))
			h = lerpf(h, line_h, 1.0 - smoothstep(road.width * 0.5 + 1.0, reach, info.y))
	if not track.is_empty():
		var w := RaceTrack.flatten_weight(track, p)
		if w > 0.0:
			h = lerpf(h, RaceTrack.surface(track, p), w)
	for city in cities:
		var d := _city_distance(city, p)
		var r: float = city.radius
		if d < r * 1.8:
			h = lerpf(h, city.base, 1.0 - smoothstep(r * 1.05, r * 1.8, d))
	if not lakes.is_empty():
		h = Lakes.shape(lakes, x, z, h)
	return h


## Distância "quadrada" (no eixo da grade da cidade) até o centro, com cantos arredondados.
func _city_distance(city: Dictionary, p: Vector2) -> float:
	var local := CityGen.to_local(city, p).abs()
	return maxf(local.x, local.y) * 0.85 + local.length() * 0.15


## Grade de trechos: cada célula guarda os trechos cuja caixa (lo/hi) a toca.
static func _index_roads(roads: Array) -> Dictionary:
	var grid := {}
	for road in roads:
		for gx in range(floori(road.lo.x / AVENUE_CELL), floori(road.hi.x / AVENUE_CELL) + 1):
			for gy in range(floori(road.lo.y / AVENUE_CELL), floori(road.hi.y / AVENUE_CELL) + 1):
				var key := Vector2i(gx, gy)
				if not grid.has(key):
					grid[key] = []
				grid[key].append(road)
	return grid


## (t ao longo do segmento 0..1, distância até ele).
static func _segment_info(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return Vector2(t, p.distance_to(a + ab * t))


## Rua no ponto: {} ou {"kind": "avenue"/"street"/"dirt"/"asphalt", "edge": 0..1 (1 = no meio)}.
func road_at(x: float, z: float) -> Dictionary:
	var p := Vector2(x, z)
	var best := {}
	for city in cities:
		if _city_distance(city, p) > city.radius + 12.0:
			continue
		for street in city.streets:
			var info := _segment_info(p, street.a, street.b)
			var half: float = street.width * 0.5
			if info.y < half:
				best = {"kind": street.kind, "edge": 1.0 - smoothstep(half - 0.8, half, info.y)}
				if street.kind == "avenue":
					return best
	for road in _avenue_grid.get(Vector2i(floori(x / AVENUE_CELL), floori(z / AVENUE_CELL)), []):
		if p.x < road.lo.x or p.y < road.lo.y or p.x > road.hi.x or p.y > road.hi.y:
			continue
		var info := _segment_info(p, road.a, road.b)
		if info.y < road.width * 0.5:
			return {"kind": "avenue", "edge": 1.0 - smoothstep(road.width * 0.5 - 0.8, road.width * 0.5, info.y)}
	if track.is_empty() or RaceTrack.flatten_weight(track, p) < 0.99:
		return best
	var on_track := RaceTrack.road_at(track, p)
	if not on_track.is_empty():
		return on_track
	return best


## Quanto o ponto está dentro de uma cidade (1 = no meio, 0 = fora).
func city_mask(x: float, z: float) -> float:
	var m := 0.0
	for city in cities:
		var d := _city_distance(city, Vector2(x, z))
		m = maxf(m, 1.0 - smoothstep(city.radius * 0.85, city.radius * 1.15, d))
	return m


## Relevo sem as cidades (usado para escolher onde elas ficam).
func raw_height(x: float, z: float, biome: Dictionary) -> float:
	var hills := _noise_hills.get_noise_2d(x, z)
	var bumps := _noise_bumps.get_noise_2d(x, z)
	# Planície ondulada: morros largos + elevações menores.
	var plains_h := 3.0 + hills * 11.0 + bumps * 3.0
	# Dunas: cristas suaves e vales largos (forma "ao quadrado"), até ~16 m.
	var dune := _noise_dunes.get_noise_2d(x, z) * 0.5 + 0.5
	var desert_h := 1.0 + dune * dune * 16.0 + hills * 2.0
	var winter_h := 6.0 + hills * 14.0 + bumps * 2.0
	# Montanhas arredondadas (ruído suave, sem cristas afiadas): boas para andar e
	# para estradas no futuro. smoothstep deixa topo e pé das encostas mais macios.
	var round_peak := smoothstep(0.0, 1.0, _noise_ridge.get_noise_2d(x, z) * 0.5 + 0.5)
	var mountain_h := 10.0 + round_peak * 115.0 * pow(biome.depth, 1.3) + hills * 8.0
	var base: float = plains_h * biome.plains + desert_h * biome.desert + winter_h * biome.winter
	var total_flat: float = biome.plains + biome.desert + biome.winter
	if total_flat > 0.001:
		base /= total_flat
	var h: float = lerpf(base, mountain_h + base * 0.3, biome.mountain)
	h += _noise_detail.get_noise_2d(x, z) * 0.4
	return lerpf(-0.08, h, 1.0 - _town_mask(x, z))


func _town_mask(x: float, z: float) -> float:
	return 1.0 - smoothstep(town_radius, town_radius * 2.4, Vector2(x, z).length())


func _border(x: float, z: float) -> float:
	var edge := maxf(absf(x), absf(z)) / (world_size * 0.5)
	return smoothstep(0.9, 1.0, edge)


# --- Chunks ------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	var others: Array[Vector3] = []
	if Net.i.online() and Net.i.is_host() and Net.i.world:
		others.assign(Net.i.world.player_positions())
		others.remove_at(0)
	if others.is_empty():
		update_around(_player.global_position, chunks_per_frame)
	else:
		_stream_many(_player.global_position, others)


## Host online: terreno em volta dele e (mais perto) em volta dos outros
## jogadores, para os zumbis de lá terem chão e colisão.
func _stream_many(center: Vector3, others: Array[Vector3]) -> void:
	var wanted := _wanted_chunks(center, view_distance)
	var seen := {}
	for coord in wanted:
		seen[coord] = true
	for other in others:
		for coord in _wanted_chunks(other, remote_view_distance):
			if not seen.has(coord):
				seen[coord] = true
				wanted.append(coord)
	_stream(wanted, seen, chunks_per_frame * 2)


## Cria os chunks que faltam perto de "center" (até "budget" por chamada) e
## apaga os longe. budget < 0 = cria todos de uma vez (usado no início).
func update_around(center: Vector3, budget := -1, radius := -1.0) -> void:
	var wanted := _wanted_chunks(center, view_distance if radius < 0.0 else radius)
	var keep_list := wanted if radius < 0.0 else _wanted_chunks(center, view_distance)
	var keep := {}
	for coord in keep_list:
		keep[coord] = true
	_stream(wanted, keep, budget)


func _stream(wanted: Array, keep: Dictionary, budget: int) -> void:
	for coord in _chunks.keys():
		if not is_instance_valid(_chunks[coord]):
			_chunks.erase(coord) # alguém já liberou
		elif not keep.has(coord):
			_chunks[coord].queue_free()
			_chunks.erase(coord)
	if budget < 0:
		# Síncrono (início do jogo): calcula e cria tudo agora.
		for coord in wanted:
			if not _chunks.has(coord):
				_finish(coord, _generate_data(coord))
		return
	# Recolhe o que as threads terminaram (no máximo "budget" por frame).
	var created := 0
	for coord in _tasks.keys():
		if created >= budget:
			break
		if WorkerThreadPool.is_task_completed(_tasks[coord]):
			WorkerThreadPool.wait_for_task_completion(_tasks[coord])
			_tasks.erase(coord)
			_mutex.lock()
			var data: Dictionary = _results.get(coord, {})
			_results.erase(coord)
			_mutex.unlock()
			if keep.has(coord) and not _chunks.has(coord) and not data.is_empty():
				_finish(coord, data)
				created += 1
	# Pede os que faltam (os mais perto primeiro).
	for coord in wanted:
		if not _chunks.has(coord) and not _tasks.has(coord) and _tasks.size() < 10:
			_tasks[coord] = WorkerThreadPool.add_task(_threaded_generate.bind(coord))


func _threaded_generate(coord: Vector2i) -> void:
	var data := _generate_data(coord)
	_mutex.lock()
	_results[coord] = data
	_mutex.unlock()


func _exit_tree() -> void:
	for coord in _tasks:
		WorkerThreadPool.wait_for_task_completion(_tasks[coord])
	_tasks.clear()


func _wanted_chunks(center: Vector3, distance: float) -> Array:
	var result := []
	var radius := int(ceil(distance / chunk_size))
	var here := Vector2i(floori(center.x / chunk_size), floori(center.z / chunk_size))
	var half_chunks := int(world_size * 0.5 / chunk_size)
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var coord := here + Vector2i(dx, dz)
			if absi(coord.x) > half_chunks or absi(coord.y) > half_chunks:
				continue
			var chunk_center := (Vector2(coord) + Vector2(0.5, 0.5)) * chunk_size
			if chunk_center.distance_to(Vector2(center.x, center.z)) <= distance + chunk_size * 0.7:
				result.append(coord)
	# Mais perto primeiro.
	var c := Vector2(center.x, center.z)
	result.sort_custom(func(a, b): return ((Vector2(a) + Vector2(0.5, 0.5)) * chunk_size).distance_squared_to(c) \
			< ((Vector2(b) + Vector2(0.5, 0.5)) * chunk_size).distance_squared_to(c))
	return result


## Usado por testes/ferramentas: gera e cria um chunk na hora.
func _build_chunk(coord: Vector2i) -> Node3D:
	return _finish(coord, _generate_data(coord))


## Parte pesada (roda em thread): alturas, cores e triângulos do chunk.
func _generate_data(coord: Vector2i) -> Dictionary:
	var origin := Vector2(coord) * chunk_size
	var count := int(chunk_size / cell) + 1
	var heights := PackedFloat32Array()
	heights.resize(count * count)
	var colors := PackedColorArray()
	colors.resize(count * count)
	for j in count:
		for i in count:
			var x := origin.x + i * cell
			var z := origin.y + j * cell
			var biome := biome_at(x, z)
			var h := _height_from(x, z, biome)
			heights[j * count + i] = h
			colors[j * count + i] = _color_for(x, z, h, biome)

	var quads := (count - 1) * (count - 1)
	var vertices := PackedVector3Array()
	vertices.resize(quads * 6)
	var normals := PackedVector3Array()
	normals.resize(quads * 6)
	var vertex_colors := PackedColorArray()
	vertex_colors.resize(quads * 6)
	var uvs := PackedVector2Array()
	uvs.resize(quads * 6)
	var n := 0
	for j in count - 1:
		for i in count - 1:
			var ids := [j * count + i, j * count + i + 1, (j + 1) * count + i, (j + 1) * count + i + 1]
			var pos := [Vector3(i * cell, heights[ids[0]], j * cell), Vector3((i + 1) * cell, heights[ids[1]], j * cell),
				Vector3(i * cell, heights[ids[2]], (j + 1) * cell), Vector3((i + 1) * cell, heights[ids[3]], (j + 1) * cell)]
			# Rocha nas encostas íngremes.
			var steep := absf(heights[ids[0]] - heights[ids[3]]) / (cell * 1.41)
			var rock := clampf((steep - 0.9) * 2.0, 0.0, 0.85) if steep > 0.9 else 0.0
			# Sentido horário visto de cima = face da frente no Godot.
			for tri in [[0, 1, 2], [1, 3, 2]]:
				var a: Vector3 = pos[tri[0]]
				var b: Vector3 = pos[tri[1]]
				var c: Vector3 = pos[tri[2]]
				var normal := (c - a).cross(b - a).normalized()
				for k in tri:
					vertices[n] = pos[k]
					normals[n] = normal
					vertex_colors[n] = (colors[ids[k]] as Color).lerp(COLOR_ROCK, rock)
					uvs[n] = Vector2(origin.x + pos[k].x, origin.y + pos[k].z) * 0.25
					n += 1
	return {"vertices": vertices, "normals": normals, "colors": vertex_colors, "uvs": uvs,
		"props": _props.plan(self, coord, origin)}


## Parte leve (thread principal): cria malha, colisão e enfeites.
func _finish(coord: Vector2i, data: Dictionary) -> Node3D:
	var origin := Vector2(coord) * chunk_size
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_COLOR] = data.colors
	arrays[Mesh.ARRAY_TEX_UV] = data.uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk.position = Vector3(origin.x, 0, origin.y)
	add_child(chunk)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material
	chunk.add_child(visual)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var faces := ConcavePolygonShape3D.new()
	faces.set_faces(data.vertices)
	shape.shape = faces
	body.add_child(shape)
	chunk.add_child(body)
	_props.apply(data.props, chunk, body)
	_chunks[coord] = chunk
	chunk_loaded.emit(coord)
	return chunk


## Para o mapa: cor do chão e altura no ponto (seguro de chamar em thread).
func map_sample(x: float, z: float) -> Array:
	var biome := biome_at(x, z)
	var h := _height_from(x, z, biome)
	var lake := Lakes.at(lakes, x, z)
	if not lake.is_empty() and h < lake.level:
		var deep := clampf((lake.level - h) / lake.depth, 0.0, 1.0)
		return [Color(0.32, 0.5, 0.6).lerp(Color(0.12, 0.25, 0.4), deep), h] # água no mapa
	return [_color_for(x, z, h, biome), h]


func _color_for(x: float, z: float, h: float, biome: Dictionary) -> Color:
	var grass := COLOR_GRASS.lerp(COLOR_DRY_GRASS, clampf(biome.temperature * 1.6 - 0.6, 0.0, 1.0))
	var color: Color = grass * biome.plains + COLOR_SAND * biome.desert + COLOR_SNOW * biome.winter
	# Montanha: grama nas partes baixas, rocha subindo (as encostas íngremes viram rocha no mesh).
	var mountain_color := (grass * 0.85).lerp(COLOR_ROCK, smoothstep(30.0, 70.0, h))
	color += mountain_color * biome.mountain
	color = color.lerp(COLOR_SNOW, smoothstep(65.0, 85.0, h)) # topo das montanhas com neve
	# Ruas de terra batida dentro das cidades.
	var in_city := city_mask(x, z)
	if in_city > 0.0:
		color = color.lerp(Color(0.38, 0.33, 0.27), in_city * 0.75)
	var road := road_at(x, z)
	if not road.is_empty():
		var road_colors := {"avenue": Color(0.27, 0.26, 0.25), "street": Color(0.36, 0.34, 0.31),
			"dirt": Color(0.45, 0.36, 0.26), "asphalt": Color(0.2, 0.2, 0.21)}
		color = color.lerp(road_colors[road.kind], road.edge)
	# Fundo e margem dos lagos: areia molhada e lodo.
	var lake := {}
	for l in lakes:
		if Vector2(x, z).distance_to(l.center) < l.radius * 1.12:
			lake = l
	if not lake.is_empty() and h < lake.level + 0.6:
		var under := clampf((lake.level + 0.6 - h) / 1.5, 0.0, 1.0)
		color = color.lerp(Color(0.5, 0.45, 0.33), under * 0.8).lerp(Color(0.26, 0.24, 0.17), clampf((lake.level - h) / lake.depth, 0.0, 1.0) * 0.7)
	var jitter := _noise_detail.get_noise_2d(x * 3.0, z * 3.0) * 0.06
	return Color(color.r + jitter, color.g + jitter, color.b + jitter)


func _make_material() -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.25
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.78, 0.78, 0.78), Color(1, 1, 1)])
	var texture := NoiseTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = gradient
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness = 0.95
	return material
