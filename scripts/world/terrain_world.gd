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
## O centro (0, 0) é achatado para a cidade inicial. O mapa é uma grande ilha:
## perto das bordas o chão desce em praia até o mar (SEA_LEVEL), e os rios
## correm até ele.
##
## Desempenho: alturas, cores e triângulos de cada chunk são calculados em
## threads (WorkerThreadPool); a thread principal só cria os nós prontos.
##
## Grade: o chão é feito de colunas de 0,4 m (GRID = o quadradinho da parede,
## BuildPiece.SEG). A altura natural é gerada a cada 4 colunas (1,6 m, STEP) e o
## chão entre esses pontos são rampas retas (os mesmos triângulos na malha, na
## colisão e em height_at). Cavar tira um bloco de 0,4 m da coluna; pôr bloco
## (terra, pedra, areia) empilha um. Os 4 cantos da coluna mexida puxam os
## vizinhos, então o desnível vira rampa e não degrau (estilo 7 Days to Die).
## Blocos postos pelo jogador ficam marcados como construção: zumbis quebram;
## o chão natural eles não cavam. A grade e os blocos servem de base para cavernas.

signal chunk_loaded(coord: Vector2i)
signal blocks_changed(column: Vector2i) ## um bloco foi cavado/posto (grama, mapa)

const GRID := 0.4 ## lado de um bloco do terreno (= BuildPiece.SEG)
const LAT := 4 ## altura natural gerada a cada 4 blocos
const STEP := GRID * LAT ## 1,6 m entre as alturas geradas (malha sem edição)
const MAX_DIG := 12 ## até 4,8 m abaixo do chão natural
const MAX_BUILD := 15 ## até 6 m acima dele
enum Mat { DUG = -1, NATURAL = 0, DIRT = 1, STONE = 2, SAND = 3 }
const MAT_ITEM := {Mat.DIRT: &"terra", Mat.STONE: &"pedra", Mat.SAND: &"areia"}
const MAT_COST := {Mat.DIRT: 1, Mat.STONE: 2, Mat.SAND: 1} ## itens por bloco posto
const MAT_HITS := {Mat.DIRT: 3, Mat.STONE: 8, Mat.SAND: 2} ## golpes de zumbi por bloco posto
const MAT_NAMES := {Mat.DIRT: "Bloco de terra", Mat.STONE: "Bloco de pedra", Mat.SAND: "Bloco de areia"}
const MAT_COLORS := {Mat.DUG: Color(0.37, 0.27, 0.18), Mat.DIRT: Color(0.43, 0.31, 0.2),
	Mat.STONE: Color(0.5, 0.49, 0.46), Mat.SAND: Color(0.76, 0.65, 0.45)}
const ITEM_MAT := {&"terra": Mat.DIRT, &"pedra": Mat.STONE, &"areia": Mat.SAND}

static var i: TerrainWorld ## o terreno do mundo atual

@export var seed := 1337
@export var randomize_seed := false ## true = mapa diferente a cada partida
@export var world_size := 3072.0 ## lado do mapa em metros
@export var chunk_size := 64.0
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
var _noise_coast := FastNoiseLite.new()
const SEA_LEVEL := -1.0
## Configurações do mundo (WorldSettings), lidas uma vez em _ready (as threads usam estas cópias).
var coast_radius := 0.86 ## raio da ilha (fração da metade do mapa), antes do recorte da costa
var coast_wobble := 0.07
var temp_shift := 0.0
var mountain_shift := 0.0
var mountain_height := 1.0
var hill_amount := 1.0
var tree_amount := 1.0
var rock_amount := 1.0
const SEA_BAND := 110.0 ## até onde (metros terra adentro) a água do mar pode chegar
var cities: Array = [] ## cidades geradas pela semente (CityGen): centro, raio, tamanho, altura, lotes, ruas
var zones: Array = [] ## zonas contaminadas (Contamination.plan): miolo de cidades e fábricas químicas
var avenues: Array = [] ## avenidas entre as cidades maiores ({a, b, width, kind})
var race_track: Array = [] ## segmentos de asfalto da pista de corrida (RaceTrack)
var track: Dictionary = {} ## lugar e traçado da pista (RaceTrack.plan)
var lakes: Array = [] ## lagos e lagoas (Lakes.place): centro, raio, nível da água, fundo
var rivers: Array = [] ## rios (Rivers.place): pontos, níveis, largura
var _river_grid := {}
var _avenue_grid := {} # Vector2i (células de AVENUE_CELL m) -> trechos de avenida que alcançam a célula
const AVENUE_CELL := 64.0
var _chunks := {} # Vector2i -> Node3D
## Colunas mexidas: Vector2i (coluna de 0,4 m) -> PackedByteArray [blocos cavados,
## material posto de baixo, ..., material do topo]. Altura = postos - cavados.
var blocks := {}
var _chunk_cols := {} # Vector2i chunk -> {coluna: true} (colunas que mexem nos cantos dele)
var _lattice := {} # Vector2i chunk -> [alturas, cores] da grade de 1,6 m (para refazer rápido)
var _hits := {} # coluna -> golpes de zumbi no bloco do topo (só no host)
var _chunk_ver := {} # Vector2i chunk -> quantas vezes os blocos dele mudaram
var _tasks := {} # Vector2i -> id da tarefa em andamento
var _results := {} # Vector2i -> dados prontos (escrito pelas threads)
var _mutex := Mutex.new()
var _material: Material
var _props: TerrainProps
var _player: Node3D


func _ready() -> void:
	i = self
	add_to_group("persist")
	if randomize_seed:
		seed = randi()
	if Net.i.world_seed != 0:
		seed = Net.i.world_seed # multiplayer: todo mundo gera o mesmo mapa
	apply_settings()
	_setup_noise()
	# A pista vem primeiro (precisa de um deserto plano e livre); as cidades desviam dela.
	track = RaceTrack.plan(self) if WorldSettings.get_value("track") > 0.5 else {}
	if not track.is_empty():
		race_track = track.segments
	cities = CityGen.place_cities(self)
	avenues = CityGen.connect_cities(cities)
	_avenue_grid = _index_roads(avenues)
	lakes = Lakes.place(self)
	rivers = Rivers.place(self)
	_river_grid = Rivers.index(rivers)
	zones = Contamination.plan(self)
	Contamination.zones = zones
	_material = _make_material()
	_props = TerrainProps.new()
	_player = get_node_or_null(player_path)
	if _player:
		# Gera o entorno de uma vez antes de começar (o resto vem aos poucos).
		update_around(_player.global_position, -1, 140.0)


## Copia as configurações do menu "Criar mundo" (WorldSettings).
func apply_settings() -> void:
	world_size = WorldSettings.get_value("size") * 1024.0
	coast_radius = WorldSettings.get_value("island") / 100.0
	coast_wobble = 0.07 * WorldSettings.mult("coast")
	temp_shift = WorldSettings.get_value("temperature") / 100.0 * 0.25
	mountain_shift = (1.0 - WorldSettings.mult("mountains")) * 0.3
	mountain_height = WorldSettings.mult("mountain_height")
	hill_amount = WorldSettings.mult("hills")
	tree_amount = WorldSettings.mult("trees")
	rock_amount = WorldSettings.mult("rocks")


func _setup_noise() -> void:
	var setups := [
		[_noise_temp, 1.0 / 700.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2],
		[_noise_rugged, 1.0 / 750.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2],
		[_noise_hills, 1.0 / 170.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 4],
		[_noise_ridge, 1.0 / 420.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3],
		[_noise_dunes, 1.0 / 75.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2],
		[_noise_bumps, 1.0 / 55.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2],
		[_noise_detail, 1.0 / 25.0, FastNoiseLite.TYPE_SIMPLEX, 2],
		[_noise_coast, 1.0 / 260.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3],
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
	var temperature := clampf(0.5 + (z / half) * 0.55 + _noise_temp.get_noise_2d(x, z) * 0.22 + temp_shift, 0.0, 1.0)
	var desert := smoothstep(0.62, 0.72, temperature)
	var winter := 1.0 - smoothstep(0.28, 0.38, temperature)
	var temperate := clampf(1.0 - desert - winter, 0.0, 1.0)
	var rugged := _noise_rugged.get_noise_2d(x, z) * 0.5 + 0.5
	# Limiar mais baixo e ruído mais largo = regiões de montanha maiores.
	var hot_cut := 1.0 - smoothstep(0.55, 0.76, temperature) # montanhas somem devagar perto do deserto
	var mountain := smoothstep(0.44 + mountain_shift, 0.66 + mountain_shift, rugged) * hot_cut
	# "Profundidade" dentro da cordilheira: o pé é baixo (morros) e os picos só
	# sobem bem no meio dela, então a borda nunca vira um paredão.
	var depth := smoothstep(0.5 + mountain_shift, 0.92 + mountain_shift, rugged) * hot_cut * hot_cut
	var dist := Vector2(x, z).length()
	depth *= smoothstep(town_radius * 2.4, town_radius * 9.0, dist) # sem picos perto da cidade
	mountain *= 1.0 - _town_mask(x, z)
	return {
		"desert": desert * (1.0 - mountain), "plains": temperate * (1.0 - mountain),
		"winter": winter * (1.0 - mountain), "mountain": mountain, "temperature": temperature,
		"depth": depth,
	}


## Altura do chão no ponto: a mesma da malha e da colisão (rampas da grade de 1,6 m
## e os blocos cavados/postos). Fora da thread principal, sem os blocos.
func height_at(x: float, z: float) -> float:
	var main := OS.get_thread_caller_id() == OS.get_main_thread_id()
	if main and not blocks.is_empty():
		var bx := floori(x / GRID)
		var bz := floori(z / GRID)
		var o00 := corner_offset(bx, bz)
		var o10 := corner_offset(bx + 1, bz)
		var o01 := corner_offset(bx, bz + 1)
		var o11 := corner_offset(bx + 1, bz + 1)
		if o00 != 0 or o10 != 0 or o01 != 0 or o11 != 0:
			var h00 := _base_at(bx * GRID, bz * GRID, main) + o00 * GRID
			var h10 := _base_at((bx + 1) * GRID, bz * GRID, main) + o10 * GRID
			var h01 := _base_at(bx * GRID, (bz + 1) * GRID, main) + o01 * GRID
			var h11 := _base_at((bx + 1) * GRID, (bz + 1) * GRID, main) + o11 * GRID
			return tri_lerp(h00, h10, h01, h11, x / GRID - bx, z / GRID - bz)
	return _base_at(x, z, main)


## Altura natural no ponto: rampa reta entre os 4 pontos gerados em volta (1,6 m).
func _base_at(x: float, z: float, main := true) -> float:
	var gx := x / STEP
	var gz := z / STEP
	var gi := floori(gx)
	var gj := floori(gz)
	return tri_lerp(_lattice_h(gi, gj, main), _lattice_h(gi + 1, gj, main), _lattice_h(gi, gj + 1, main),
		_lattice_h(gi + 1, gj + 1, main), gx - gi, gz - gj)


## Altura gerada no ponto (gi, gj) da grade de 1,6 m (do chunk carregado, se der).
func _lattice_h(gi: int, gj: int, main: bool) -> float:
	if main:
		var q := _lat_q()
		var coord := Vector2i(floori(float(gi) / q), floori(float(gj) / q))
		var lat: Array = _lattice.get(coord, [])
		if not lat.is_empty():
			return (lat[0] as PackedFloat32Array)[(gj - coord.y * q) * (q + 1) + gi - coord.x * q]
	var x := gi * STEP
	var z := gj * STEP
	return _height_from(x, z, biome_at(x, z))


## Cor do chão natural no ponto (a mesma da malha), para os voxels.
func base_color_at(x: float, z: float) -> Color:
	var gx := x / STEP
	var gz := z / STEP
	var gi := floori(gx)
	var gj := floori(gz)
	return _tri_color(_lattice_c(gi, gj), _lattice_c(gi + 1, gj), _lattice_c(gi, gj + 1), _lattice_c(gi + 1, gj + 1), gx - gi, gz - gj)


func _lattice_c(gi: int, gj: int) -> Color:
	var q := _lat_q()
	var coord := Vector2i(floori(float(gi) / q), floori(float(gj) / q))
	var lat: Array = _lattice.get(coord, [])
	if not lat.is_empty():
		return (lat[1] as PackedColorArray)[(gj - coord.y * q) * (q + 1) + gi - coord.x * q]
	var x := gi * STEP
	var z := gj * STEP
	var biome := biome_at(x, z)
	return _color_for(x, z, _height_from(x, z, biome), biome)


## Triângulos da grade (diagonal do canto (1,0) ao (0,1), a mesma do HeightMapShape3D).
static func tri_lerp(h00: float, h10: float, h01: float, h11: float, u: float, v: float) -> float:
	if u + v <= 1.0:
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)


static func _tri_color(c00: Color, c10: Color, c01: Color, c11: Color, u: float, v: float) -> Color:
	if u + v <= 1.0:
		return c00 + (c10 - c00) * u + (c01 - c00) * v
	return c11 + (c01 - c11) * (1.0 - u) + (c10 - c11) * (1.0 - v)


## Quadrados de 1,6 m por lado do chunk (40).
func _lat_q() -> int:
	return roundi(chunk_size / STEP)


## Blocos de 0,4 m por lado do chunk (160).
func _cols_q() -> int:
	return roundi(chunk_size / GRID)


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
	if not rivers.is_empty():
		h = Rivers.shape(rivers, _river_grid, x, z, h)
	return h


## Água de rio no ponto: {"level", "dir", ...} ou {}.
func river_at(x: float, z: float) -> Dictionary:
	return Rivers.water_at(rivers, _river_grid, x, z)


## Trecho de rio mais perto (para pôr a roda d'água na beira): {"dist", "half", ...} ou {}.
func river_near(x: float, z: float) -> Dictionary:
	return Rivers.nearest(rivers, _river_grid, x, z)


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
	var plains_h := 3.0 + (hills * 11.0 + bumps * 3.0) * hill_amount
	# Dunas: cristas suaves e vales largos (forma "ao quadrado"), até ~16 m.
	var dune := _noise_dunes.get_noise_2d(x, z) * 0.5 + 0.5
	var desert_h := 1.0 + dune * dune * 16.0 + hills * 2.0
	var winter_h := 6.0 + (hills * 14.0 + bumps * 2.0) * hill_amount
	# Montanhas arredondadas (ruído suave, sem cristas afiadas): boas para andar e
	# para estradas no futuro. smoothstep deixa topo e pé das encostas mais macios.
	var round_peak := smoothstep(0.0, 1.0, _noise_ridge.get_noise_2d(x, z) * 0.5 + 0.5)
	var mountain_h := 10.0 + round_peak * 115.0 * mountain_height * pow(biome.depth, 1.3) + hills * 8.0
	var base: float = plains_h * biome.plains + desert_h * biome.desert + winter_h * biome.winter
	var total_flat: float = biome.plains + biome.desert + biome.winter
	if total_flat > 0.001:
		base /= total_flat
	var h: float = lerpf(base, mountain_h + base * 0.3, biome.mountain)
	h += _noise_detail.get_noise_2d(x, z) * 0.4
	h = lerpf(-0.08, h, 1.0 - _town_mask(x, z))
	return _coast_shape(x, z, h)


## Ilha: perto da costa o chão desce em rampa até o fundo do mar.
func _coast_shape(x: float, z: float, h: float) -> float:
	var d := coast_distance(x, z)
	if d > 180.0:
		return h
	var seabed := maxf(SEA_LEVEL + d * 0.06, SEA_LEVEL - 22.0) # praia suave, depois fundo
	return lerpf(seabed, h, smoothstep(-30.0, 180.0, d))


## Metros até a costa (positivo = terra adentro, negativo = mar). Forma de
## quadrado arredondado (cabe o mapa todo) com a costa recortada pelo ruído.
func coast_distance(x: float, z: float) -> float:
	var half := world_size * 0.5
	var ax := absf(x) / half
	var az := absf(z) / half
	var e := pow(pow(ax, 5.0) + pow(az, 5.0), 0.2)
	var wobble := _noise_coast.get_noise_2d(x, z) * coast_wobble
	return (coast_radius + wobble - e) * half


## Ponto no mar (água salgada, perto da costa e abaixo do nível)?
func sea_at(x: float, z: float, h := NAN) -> bool:
	if coast_distance(x, z) > SEA_BAND:
		return false
	if is_nan(h):
		h = height_at(x, z)
	return h < SEA_LEVEL


func _town_mask(x: float, z: float) -> float:
	return 1.0 - smoothstep(town_radius, town_radius * 2.4, Vector2(x, z).length())


# --- Chunks ------------------------------------------------------------------

func _process(_delta: float) -> void:
	_collect_rebuilds()
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
			_lattice.erase(coord)
	if budget < 0:
		# Síncrono (início do jogo): calcula e cria tudo agora.
		for coord in wanted:
			if not _chunks.has(coord):
				_finish(coord, _generate_data(coord, _snapshot(coord)))
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
			# Alta prioridade: tarefas comuns dividem só ~30% das threads (o mapa ocupava tudo).
			_tasks[coord] = WorkerThreadPool.add_task(_threaded_generate.bind(coord, _snapshot(coord)), true)


func _threaded_generate(coord: Vector2i, snap: Dictionary) -> void:
	var data := _generate_data(coord, snap)
	_mutex.lock()
	_results[coord] = data
	_mutex.unlock()


func _exit_tree() -> void:
	if i == self:
		i = null
	for coord in _rebuilds:
		WorkerThreadPool.wait_for_task_completion(_rebuilds[coord])
	_rebuilds.clear()
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
	return _finish(coord, _generate_data(coord, _snapshot(coord)))


## Parte pesada (roda em thread): alturas e cores da grade de 1,6 m, triângulos e
## plantas. "snap" = blocos mexidos que tocam o chunk (cópia feita na thread principal).
func _generate_data(coord: Vector2i, snap: Dictionary = {}) -> Dictionary:
	var q := _lat_q()
	var n := q + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var colors := PackedColorArray()
	colors.resize(n * n)
	for j in n:
		for i in n:
			# Posição pelo índice global (o ponto da borda sai idêntico nos dois chunks).
			var x := (coord.x * q + i) * STEP
			var z := (coord.y * q + j) * STEP
			var biome := biome_at(x, z)
			var h := _height_from(x, z, biome)
			heights[j * n + i] = h
			colors[j * n + i] = _color_for(x, z, h, biome)
	var data := _surface_data(coord, heights, colors, snap)
	data.ver = snap.get("ver", 0)
	data.lat_h = heights
	data.lat_c = colors
	data.props = _props.plan(self, coord, Vector2(coord) * chunk_size)
	return data


## Malha do chão do chunk: cada quadrado de 1,6 m vira 2 triângulos; os que têm bloco
## mexido em algum canto viram 4x4 blocos de 0,4 m (2 triângulos cada) com as rampas.
func _surface_data(coord: Vector2i, heights: PackedFloat32Array, colors: PackedColorArray, snap: Dictionary) -> Dictionary:
	var q := _lat_q()
	var n := q + 1
	var origin := Vector2(coord) * chunk_size
	var off: Dictionary = snap.get("off", {})
	var corner_mat: Dictionary = snap.get("cmat", {})
	var mats: Dictionary = snap.get("mat", {})
	# Colunas de 6,4 m que viraram voxels (VoxelWorld): sem chão de alturas ali.
	var holes: PackedByteArray = snap.get("holes", PackedByteArray())
	var per_hole := 4 # quadrados de 1,6 m por coluna de voxel (6,4 m)
	var fine := PackedByteArray()
	fine.resize(q * q)
	var fine_count := 0
	for c: Vector2i in off:
		for qx in _quads_of(c.x, q):
			for qz in _quads_of(c.y, q):
				if fine[qz * q + qx] == 0:
					fine[qz * q + qx] = 1
					fine_count += 1
	for b: Vector2i in mats:
		if b.x >= 0 and b.y >= 0 and b.x < q * LAT and b.y < q * LAT:
			var k := (b.y / LAT) * q + b.x / LAT
			if fine[k] == 0:
				fine[k] = 1
				fine_count += 1
	var hole_quads := 0
	if not holes.is_empty():
		for j in q:
			for i in q:
				if holes[(j / per_hole) * (q / per_hole) + i / per_hole] != 0:
					hole_quads += 1
					if fine[j * q + i] != 0:
						fine[j * q + i] = 0
						fine_count -= 1
	var total := ((q * q - fine_count - hole_quads) + fine_count * LAT * LAT) * 6
	var vertices := PackedVector3Array()
	vertices.resize(total)
	var normals := PackedVector3Array()
	normals.resize(total)
	var vertex_colors := PackedColorArray()
	vertex_colors.resize(total)
	var uvs := PackedVector2Array()
	uvs.resize(total)
	var w := [0]
	for j in q:
		for i in q:
			var k0 := j * n + i
			var h00 := heights[k0]
			var h10 := heights[k0 + 1]
			var h01 := heights[k0 + n]
			var h11 := heights[k0 + n + 1]
			# Rocha nas encostas íngremes.
			var steep := absf(h00 - h11) / (STEP * 1.41)
			var rock := clampf((steep - 0.9) * 2.0, 0.0, 0.85) if steep > 0.9 else 0.0
			var c00 := colors[k0].lerp(COLOR_ROCK, rock)
			var c10 := colors[k0 + 1].lerp(COLOR_ROCK, rock)
			var c01 := colors[k0 + n].lerp(COLOR_ROCK, rock)
			var c11 := colors[k0 + n + 1].lerp(COLOR_ROCK, rock)
			var x0 := i * STEP
			var z0 := j * STEP
			if not holes.is_empty() and holes[(j / per_hole) * (q / per_hole) + i / per_hole] != 0:
				continue # coluna de voxel: o chão é desenhado pelo VoxelWorld
			if fine[j * q + i] == 0:
				var pos := [Vector3(x0, h00, z0), Vector3(x0 + STEP, h10, z0), Vector3(x0, h01, z0 + STEP), Vector3(x0 + STEP, h11, z0 + STEP)]
				var cols := [c00, c10, c01, c11]
				_quad(pos, cols, origin, vertices, normals, vertex_colors, uvs, w)
				continue
			# Quadrado com blocos mexidos: 4x4 blocos de 0,4 m.
			for b in LAT:
				for a in LAT:
					var pos := []
					var cols := []
					var strongest := 0
					var ramp_mat: int = Mat.NATURAL
					for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
						var u := float(a + corner.x) / LAT
						var v := float(b + corner.y) / LAT
						var key := Vector2i(i * LAT + a + corner.x, j * LAT + b + corner.y)
						var o: int = off.get(key, 0)
						if absi(o) > strongest:
							strongest = absi(o)
							ramp_mat = corner_mat.get(key, Mat.DUG)
						pos.append(Vector3(x0 + u * STEP, tri_lerp(h00, h10, h01, h11, u, v) + o * GRID, z0 + v * STEP))
						cols.append(_tri_color(c00, c10, c01, c11, u, v))
					# Cor do bloco: o material posto/cavado dele; rampa do vizinho: o material
					# de quem a puxou (lado da torre de pedra = pedra, beira do buraco = terra).
					var mat: int = mats.get(Vector2i(i * LAT + a, j * LAT + b), Mat.NATURAL)
					if mat == Mat.NATURAL and strongest > 0:
						mat = ramp_mat
					if mat != Mat.NATURAL:
						var tint: Color = MAT_COLORS.get(mat, MAT_COLORS[Mat.DUG])
						var amount := 0.85
						for k in 4:
							cols[k] = (cols[k] as Color).lerp(tint, amount)
					_quad(pos, cols, origin, vertices, normals, vertex_colors, uvs, w)
	if hole_quads > 0:
		vertices.resize(w[0])
		normals.resize(w[0])
		vertex_colors.resize(w[0])
		uvs.resize(w[0])
		_skirts(holes, per_hole, q, n, heights, colors, origin, vertices, normals, vertex_colors, uvs)
	return {"vertices": vertices, "normals": normals, "colors": vertex_colors, "uvs": uvs,
		"edited": not off.is_empty() or not mats.is_empty() or hole_quads > 0}


## Saia na borda entre o chão de alturas e a área de voxels: tira de 0,4 m para baixo dos
## dois lados (a malha dos voxels emenda na mesma linha, mas pode ficar 1-2 cm acima ou abaixo).
func _skirts(holes: PackedByteArray, per_hole: int, q: int, n: int, heights: PackedFloat32Array, colors: PackedColorArray,
		origin: Vector2, vertices: PackedVector3Array, normals: PackedVector3Array, vertex_colors: PackedColorArray, uvs: PackedVector2Array) -> void:
	var cols := q / per_hole
	var hole := func(ci: int, cj: int) -> bool:
		return ci >= 0 and cj >= 0 and ci < cols and cj < cols and holes[cj * cols + ci] != 0
	var w := [vertices.size()]
	for cj in cols:
		for ci in cols:
			if not hole.call(ci, cj):
				continue
			# Bordas desta coluna de voxel que dão para chão de alturas (ou para fora do chunk).
			for side in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				if hole.call(ci + side.x, cj + side.y):
					continue
				for k in per_hole:
					var a: Vector2i
					var b: Vector2i
					if side.x != 0:
						var gx := ci * per_hole + (per_hole if side.x > 0 else 0)
						a = Vector2i(gx, cj * per_hole + k)
						b = Vector2i(gx, cj * per_hole + k + 1)
					else:
						var gz := cj * per_hole + (per_hole if side.y > 0 else 0)
						a = Vector2i(ci * per_hole + k, gz)
						b = Vector2i(ci * per_hole + k + 1, gz)
					var pa := Vector3(a.x * STEP, heights[a.y * n + a.x], a.y * STEP)
					var pb := Vector3(b.x * STEP, heights[b.y * n + b.x], b.y * STEP)
					var down := Vector3.DOWN * 0.4
					var cols4 := [colors[a.y * n + a.x], colors[b.y * n + b.x], colors[a.y * n + a.x], colors[b.y * n + b.x]]
					for flip in 2:
						var pos := [pa, pb, pa + down, pb + down] if flip == 0 else [pb, pa, pb + down, pa + down]
						var grow: int = w[0] + 6
						vertices.resize(grow)
						normals.resize(grow)
						vertex_colors.resize(grow)
						uvs.resize(grow)
						_quad(pos, cols4, origin, vertices, normals, vertex_colors, uvs, w)


## Colunas de 6,4 m do chunk que viraram voxels (10 x 10; 1 = buraco no chão de alturas).
var _holes := {} # Vector2i chunk -> PackedByteArray


func set_voxel_holes(coord: Vector2i, holes: PackedByteArray) -> void:
	if holes.count(1) == 0:
		_holes.erase(coord)
	else:
		_holes[coord] = holes
	_chunk_ver[coord] = int(_chunk_ver.get(coord, 0)) + 1
	_queue_rebuild(coord)


# Refazer o chão de um chunk em thread (buracos dos voxels mudam o tempo todo andando).
var _rebuilds := {} # Vector2i -> id da tarefa
var _rebuild_results := {}
var _rebuild_again := {}


func _queue_rebuild(coord: Vector2i) -> void:
	if _rebuilds.has(coord):
		_rebuild_again[coord] = true # termina a atual e refaz com o mais novo
		return
	var lat: Array = _lattice.get(coord, [])
	if lat.is_empty() or not is_instance_valid(_chunks.get(coord)):
		return
	_rebuilds[coord] = WorkerThreadPool.add_task(_rebuild_task.bind(coord, lat[0], lat[1], _snapshot(coord)), true)


func _rebuild_task(coord: Vector2i, heights: PackedFloat32Array, colors: PackedColorArray, snap: Dictionary) -> void:
	var data := _surface_data(coord, heights, colors, snap)
	_mutex.lock()
	_rebuild_results[coord] = data
	_mutex.unlock()


func _collect_rebuilds() -> void:
	for coord: Vector2i in _rebuilds.keys():
		if not WorkerThreadPool.is_task_completed(_rebuilds[coord]):
			continue
		WorkerThreadPool.wait_for_task_completion(_rebuilds[coord])
		_rebuilds.erase(coord)
		_mutex.lock()
		var data: Dictionary = _rebuild_results.get(coord, {})
		_rebuild_results.erase(coord)
		_mutex.unlock()
		var chunk: Node3D = _chunks.get(coord)
		var lat: Array = _lattice.get(coord, [])
		if not data.is_empty() and is_instance_valid(chunk) and not lat.is_empty():
			_apply_surface(chunk, data, lat[0])
			_hide_foliage(chunk)
		if _rebuild_again.has(coord):
			_rebuild_again.erase(coord)
			_queue_rebuild(coord)


## Quadrados de 1,6 m que usam o canto "c" (índice de canto de 0,4 m no chunk).
static func _quads_of(c: int, q: int) -> Array:
	var list := []
	var a := c / LAT
	if c >= 0 and a < q:
		list.append(a)
	if c % LAT == 0 and a - 1 >= 0 and a - 1 < q:
		list.append(a - 1)
	return list


## Dois triângulos (sentido horário visto de cima = face da frente), normal reta.
static func _quad(pos: Array, cols: Array, origin: Vector2, vertices: PackedVector3Array, normals: PackedVector3Array,
		vertex_colors: PackedColorArray, uvs: PackedVector2Array, w: Array) -> void:
	var n: int = w[0]
	for tri in [[0, 1, 2], [1, 3, 2]]:
		var a: Vector3 = pos[tri[0]]
		var b: Vector3 = pos[tri[1]]
		var c: Vector3 = pos[tri[2]]
		var normal := (c - a).cross(b - a).normalized()
		for k in tri:
			vertices[n] = pos[k]
			normals[n] = normal
			vertex_colors[n] = cols[k]
			uvs[n] = Vector2(origin.x + pos[k].x, origin.y + pos[k].z) * 0.25
			n += 1
	w[0] = n


## Parte leve (thread principal): cria malha, colisão e enfeites.
func _finish(coord: Vector2i, data: Dictionary) -> Node3D:
	var origin := Vector2(coord) * chunk_size
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk.position = Vector3(origin.x, 0, origin.y)
	add_child(chunk)
	var visual := MeshInstance3D.new()
	visual.name = "Ground"
	visual.material_override = _material
	chunk.add_child(visual)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "GroundShape"
	body.add_child(shape)
	chunk.add_child(body)
	_lattice[coord] = [data.lat_h, data.lat_c]
	var surface := data
	if int(data.get("ver", 0)) != int(_chunk_ver.get(coord, 0)):
		# Cavaram/puseram bloco enquanto a thread trabalhava: refaz o chão com o atual.
		surface = _surface_data(coord, data.lat_h, data.lat_c, _snapshot(coord))
	_apply_surface(chunk, surface, data.lat_h)
	_props.apply(data.props, chunk, body)
	if _chunk_cols.has(coord):
		_hide_foliage(chunk)
	_chunks[coord] = chunk
	chunk_loaded.emit(coord)
	return chunk


## Põe a malha e a colisão do chão no chunk. Sem blocos mexidos a colisão é um
## HeightMapShape3D da grade de 1,6 m (leve); com blocos, os próprios triângulos.
func _apply_surface(chunk: Node3D, data: Dictionary, heights: PackedFloat32Array) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_COLOR] = data.colors
	arrays[Mesh.ARRAY_TEX_UV] = data.uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	(chunk.get_node("Ground") as MeshInstance3D).mesh = mesh
	var shape := chunk.get_node("Body/GroundShape") as CollisionShape3D
	if data.edited:
		var faces := ConcavePolygonShape3D.new()
		faces.set_faces(data.vertices)
		shape.shape = faces
		shape.position = Vector3.ZERO
		shape.scale = Vector3.ONE
	else:
		var n := _lat_q() + 1
		var map := HeightMapShape3D.new()
		map.map_width = n
		map.map_depth = n
		var scaled := PackedFloat32Array()
		scaled.resize(n * n)
		for k in n * n:
			scaled[k] = heights[k] / STEP
		map.map_data = scaled
		shape.shape = map
		shape.scale = Vector3.ONE * STEP
		shape.position = Vector3(chunk_size * 0.5, 0.0, chunk_size * 0.5)


## Para o mapa: cor do chão e altura no ponto (seguro de chamar em thread).
func map_sample(x: float, z: float) -> Array:
	var biome := biome_at(x, z)
	var h := _height_from(x, z, biome)
	var lake := Lakes.at(lakes, x, z)
	if not lake.is_empty() and h < lake.level:
		var deep := clampf((lake.level - h) / lake.depth, 0.0, 1.0)
		return [Color(0.32, 0.5, 0.6).lerp(Color(0.12, 0.25, 0.4), deep), h] # água no mapa
	var river := river_at(x, z)
	if not river.is_empty() and h < river.level:
		return [Color(0.28, 0.46, 0.6), h]
	if sea_at(x, z, h):
		var deep := clampf((SEA_LEVEL - h) / 18.0, 0.0, 1.0)
		return [Color(0.3, 0.5, 0.62).lerp(Color(0.1, 0.22, 0.38), deep), h]
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
		# Margem de areia molhada; fundo verde de alga (mais forte no fundo).
		var deep := clampf((lake.level - h) / lake.depth, 0.0, 1.0)
		color = color.lerp(Color(0.46, 0.44, 0.3), under * 0.7).lerp(Color(0.24, 0.46, 0.16), clampf(under * 1.4, 0.0, 1.0) * (0.6 + deep * 0.4))
	# Praia: areia na beira do mar (e areia molhada/escura debaixo d'água).
	var coast := coast_distance(x, z)
	if coast < SEA_BAND and h < SEA_LEVEL + 2.5:
		var beach := 1.0 - smoothstep(SEA_LEVEL + 1.2, SEA_LEVEL + 2.5, h)
		color = color.lerp(COLOR_SAND, beach)
		if h < SEA_LEVEL:
			color = color.lerp(Color(0.5, 0.46, 0.34), clampf((SEA_LEVEL - h) / 4.0, 0.0, 1.0))
	var jitter := _noise_detail.get_noise_2d(x * 3.0, z * 3.0) * 0.06
	return Color(color.r + jitter, color.g + jitter, color.b + jitter)


## Chão: superfície PS2 em coordenadas do mundo (grão fino na grama/areia, de
## pedra nas encostas, manchas que quebram o verde liso). Ver Look.surface.
func _make_material() -> Material:
	return Look.surface(false, 1.0, 0.95, 0.0, true)


# --- Blocos: cavar e construir com o chão -------------------------------------------

## Coluna de 0,4 m que contém o ponto.
static func column_at(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / GRID), floori(z / GRID))


## Quantos blocos a coluna está acima (+) ou abaixo (-) do chão natural.
func column_offset(col: Vector2i) -> int:
	var b: PackedByteArray = blocks.get(col, PackedByteArray())
	return 0 if b.is_empty() else b.size() - 1 - b[0]


## Material do bloco de cima: posto pelo jogador (DIRT/STONE/SAND), DUG (terra
## cavada) ou NATURAL (nunca mexido).
func top_material(col: Vector2i) -> int:
	var b: PackedByteArray = blocks.get(col, PackedByteArray())
	if b.size() > 1:
		return b[b.size() - 1]
	return Mat.DUG if not b.is_empty() and b[0] > 0 else Mat.NATURAL


## Blocos postos pelo jogador na coluna (construção: zumbi pode quebrar).
func built_count(col: Vector2i) -> int:
	var b: PackedByteArray = blocks.get(col, PackedByteArray())
	return maxi(b.size() - 1, 0)


## Canto (cx, cz) da grade de 0,4 m: entre as 4 colunas em volta vale o desnível
## mais forte (subida ganha de buraco no empate). Daí as rampas entre os blocos.
func corner_offset(cx: int, cz: int) -> int:
	if blocks.is_empty():
		return 0
	return _corner_info(cx, cz).x


## Desnível do canto e o material de quem o puxou (a rampa em volta de uma torre de
## pedra é de pedra; em volta de um buraco, terra cavada): Vector2i(desnível, material).
func _corner_info(cx: int, cz: int) -> Vector2i:
	var lo := 0
	var hi := 0
	var lo_col := Vector2i.ZERO
	var hi_col := Vector2i.ZERO
	for col in [Vector2i(cx - 1, cz - 1), Vector2i(cx, cz - 1), Vector2i(cx - 1, cz), Vector2i(cx, cz)]:
		var o := column_offset(col)
		if o < lo:
			lo = o
			lo_col = col
		if o > hi:
			hi = o
			hi_col = col
	if hi == 0 and lo == 0:
		return Vector2i.ZERO
	if hi >= -lo:
		return Vector2i(hi, top_material(hi_col))
	return Vector2i(lo, Mat.DUG)


## Chunks cujos cantos a coluna mexe (o dela e, na borda, o vizinho).
func _chunks_of(col: Vector2i) -> Array:
	var cq := _cols_q()
	var xs := [floori(float(col.x) / cq)]
	var zs := [floori(float(col.y) / cq)]
	if posmod(col.x, cq) == 0:
		xs.append(xs[0] - 1)
	elif posmod(col.x, cq) == cq - 1:
		xs.append(xs[0] + 1)
	if posmod(col.y, cq) == 0:
		zs.append(zs[0] - 1)
	elif posmod(col.y, cq) == cq - 1:
		zs.append(zs[0] + 1)
	var list := []
	for x in xs:
		for z in zs:
			list.append(Vector2i(x, z))
	return list


## Cópia dos blocos que tocam o chunk (para a thread): desnível de cada canto
## mexido e material de cada coluna mexida, em índices locais do chunk.
func _snapshot(coord: Vector2i) -> Dictionary:
	var cols: Dictionary = _chunk_cols.get(coord, {})
	var snap := {"ver": int(_chunk_ver.get(coord, 0))}
	if _holes.has(coord):
		snap.holes = _holes[coord]
	if cols.is_empty():
		return snap
	var cq := _cols_q()
	var base := coord * cq
	var off := {}
	var corner_mat := {}
	var mats := {}
	for col: Vector2i in cols:
		var local := col - base
		var mat := top_material(col)
		if mat != Mat.NATURAL and local.x >= 0 and local.y >= 0 and local.x < cq and local.y < cq:
			mats[local] = mat
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var lc: Vector2i = local + d
			if lc.x < 0 or lc.y < 0 or lc.x > cq or lc.y > cq or off.has(lc):
				continue
			var info := _corner_info(col.x + d.x, col.y + d.y)
			if info.x != 0:
				off[lc] = info.x
				corner_mat[lc] = info.y
	snap.off = off
	snap.cmat = corner_mat
	snap.mat = mats
	return snap


## Troca o conteúdo de uma coluna e refaz o chão dos chunks em volta (rebuild =
## false: só marca; quem chamou refaz depois, ver load_data).
func set_column(col: Vector2i, data: PackedByteArray, rebuild := true) -> Array:
	if data.is_empty() or (data.size() == 1 and data[0] == 0):
		blocks.erase(col)
	else:
		blocks[col] = data
	_hits.erase(col)
	for coord: Vector2i in _chunks_of(col):
		if blocks.has(col):
			if not _chunk_cols.has(coord):
				_chunk_cols[coord] = {}
			_chunk_cols[coord][col] = true
		elif _chunk_cols.has(coord):
			_chunk_cols[coord].erase(col)
			if _chunk_cols[coord].is_empty():
				_chunk_cols.erase(coord)
		_chunk_ver[coord] = int(_chunk_ver.get(coord, 0)) + 1
		if rebuild:
			_rebuild_surface(coord)
	if rebuild:
		blocks_changed.emit(col)
	return _chunks_of(col)


## Refaz só o chão (malha e colisão) de um chunk carregado, com os blocos de agora.
func _rebuild_surface(coord: Vector2i) -> void:
	var chunk: Node3D = _chunks.get(coord)
	var lat: Array = _lattice.get(coord, [])
	if not is_instance_valid(chunk) or lat.is_empty():
		return
	_apply_surface(chunk, _surface_data(coord, lat[0], lat[1], _snapshot(coord)), lat[0])
	_hide_foliage(chunk)


## Tufos de grama/arbustos do cenário em cima de bloco mexido (ou da rampa dele) somem.
func _hide_foliage(chunk: Node3D) -> void:
	for node in chunk.get_children():
		if not (node is MultiMeshInstance3D and node.has_meta("foliage")):
			continue
		var mm: MultiMesh = node.multimesh
		var original: Array = node.get_meta("foliage")
		for k in mini(mm.instance_count, original.size()):
			var t: Transform3D = original[k]
			var col := column_at(chunk.position.x + t.origin.x, chunk.position.z + t.origin.z)
			var hide := false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if blocks.has(col + Vector2i(dx, dz)):
						hide = true
			mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3.ZERO), t.origin) if hide else t)


## Altura do topo da coluna (o meio do bloco de cima).
func column_top(col: Vector2i) -> float:
	return height_at((col.x + 0.5) * GRID, (col.y + 0.5) * GRID)


## Do que é o chão natural da coluna (o que a pá tira): pedra nas encostas e
## montanhas altas, areia no deserto e na praia, terra no resto.
func natural_material(col: Vector2i) -> int:
	var x := (col.x + 0.5) * GRID
	var z := (col.y + 0.5) * GRID
	var biome := biome_at(x, z)
	var h := _height_from(x, z, biome)
	var c := _color_for(x, z, h, biome)
	var gx := x / STEP
	var gz := z / STEP
	var slope := absf(_lattice_h(floori(gx), floori(gz), true) - _lattice_h(floori(gx) + 1, floori(gz) + 1, true)) / (STEP * 1.41)
	if slope > 1.0 or (absf(c.r - c.g) < 0.04 and absf(c.g - c.b) < 0.05 and c.r < 0.5):
		return Mat.STONE
	if c.r > 0.62 and c.g > 0.52 and c.b < c.g:
		return Mat.SAND
	return Mat.DIRT


## O que sai de cavar a coluna agora (material do item), ou NATURAL se não dá.
func dig_result(col: Vector2i) -> int:
	var b: PackedByteArray = blocks.get(col, PackedByteArray([0]))
	if b.size() > 1:
		return b[b.size() - 1]
	if b[0] >= MAX_DIG:
		return Mat.NATURAL
	return natural_material(col)


## Dá para pôr um bloco na coluna? (altura máxima)
func can_place(col: Vector2i) -> bool:
	return column_offset(col) < MAX_BUILD


## Coluna com bloco posto pelo jogador perto do ponto atingido (o golpe pega na
## rampa do vizinho também): olha a coluna do ponto e até 2 adiante na direção.
func built_near(point: Vector3, direction: Vector3) -> Vector2i:
	if blocks.is_empty():
		return Vector2i(-2147483647, 0)
	var flat := Vector3(direction.x, 0.0, direction.z).normalized() * GRID
	for k in 3:
		var p := point + flat * k
		for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var col: Vector2i = column_at(p.x, p.z) + d
			if built_count(col) > 0 and column_top(col) > point.y - 0.25:
				return col
	return Vector2i(-2147483647, 0)


static func is_column(col: Vector2i) -> bool:
	return col.x != -2147483647


## O corpo atingido é o chão de um chunk?
static func is_ground(collider: Object) -> bool:
	var node := collider as Node
	return node != null and node.get_parent() != null and node.get_parent().get_parent() is TerrainWorld


## Pedidos (vão para o host e voltam para todos; ver Net.system_request).
func request_dig(col: Vector2i) -> void:
	Net.i.system_request(name, "dig", [col])


func request_place(col: Vector2i, mat: int) -> void:
	Net.i.system_request(name, "place", [col, mat])


## Golpe de zumbi num bloco posto (roda no host). true = quebrou.
func zombie_hit(col: Vector2i, power: int) -> bool:
	if built_count(col) <= 0:
		return false
	var mat := top_material(col)
	_hits[col] = int(_hits.get(col, 0)) + power
	if _hits[col] < int(MAT_HITS.get(mat, 3)):
		return false
	Net.i.system_request(name, "break", [col])
	return true


func host_apply(action: String, args: Array) -> Array:
	var col: Vector2i = args[0]
	var b: PackedByteArray = (blocks.get(col, PackedByteArray([0])) as PackedByteArray).duplicate()
	match action:
		"dig":
			if b.size() > 1:
				b.resize(b.size() - 1) # tira o bloco posto de cima
			elif b[0] < MAX_DIG:
				b[0] += 1 # cava o chão natural
			else:
				return []
		"place":
			var mat: int = args[1]
			if not MAT_ITEM.has(mat) or column_offset(col) >= MAX_BUILD:
				return []
			b.append(mat)
		"break":
			if b.size() <= 1:
				return []
			b.resize(b.size() - 1)
		"set":
			b = args[1]
		_:
			return []
	set_column(col, b)
	_edit_sound(action, col)
	return [col, b]


func apply_remote(action: String, args: Array) -> void:
	if args.size() < 2:
		return
	set_column(args[0], args[1])
	_edit_sound(action, args[0])


func _edit_sound(action: String, col: Vector2i) -> void:
	if not is_inside_tree():
		return
	var at := Vector3((col.x + 0.5) * GRID, column_top(col), (col.y + 0.5) * GRID)
	match action:
		"dig":
			Sfx.play_at("step_soft", at, 4.0, 0.8)
		"place":
			Sfx.play_at("step_soft", at, 4.0, 1.15)
		"break":
			Sfx.play_at("crunch", at, 4.0, 0.6)


# --- Salvar / rede -------------------------------------------------------------------

func persist_key() -> String:
	return "terrain"


func save_data() -> Dictionary:
	var list := []
	for col: Vector2i in blocks:
		list.append([col, blocks[col]])
	return {"blocks": list}


func load_data(data: Dictionary) -> void:
	var incoming := {}
	for entry in data.get("blocks", []):
		incoming[entry[0]] = entry[1]
	var touched := {}
	for col: Vector2i in blocks.keys():
		if not incoming.has(col):
			for coord in set_column(col, PackedByteArray(), false):
				touched[coord] = true
	for col: Vector2i in incoming:
		for coord in set_column(col, incoming[col], false):
			touched[coord] = true
	for coord: Vector2i in touched:
		_rebuild_surface(coord)
	blocks_changed.emit(Vector2i(-2147483647, 0)) # tudo


func net_sync_to(peer: int) -> void:
	Net.i.send_system_state(peer, name, save_data())
