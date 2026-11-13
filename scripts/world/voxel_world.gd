class_name VoxelWorld
extends Node3D
## Terreno em voxels 3D perto do jogador (branch terreno-voxel, fase 2).
##
## Blocos de 0,4 m em seções de 16^3 (6,4 m), geradas a partir das alturas do TerrainWorld
## (a superfície fica igual) mais cavernas, veios de minério e rocha-mãe a 60 m abaixo do
## mar. Num raio em volta do jogador (NEAR) o chão é de voxels: dá para cavar para baixo e
## para o lado, entrar em caverna e construir com blocos. Mais longe continua o chão de
## alturas do TerrainWorld (mais barato; de longe não se vê caverna) com um "buraco" onde
## os voxels assumem.
##
## Quem faz a conta: a extensão C++ ApioVoxel (bin/apio_voxel.gdextension). Sem ela
## (outro sistema) o mundo fica só com o chão de alturas (a VoxelRef em GDScript é lenta
## demais para o jogo; serve para testes).
##
## Edições (blocos cavados e postos) ficam em `edits` (bloco -> material, 0 = ar), vão no
## save e na rede (o host decide, como os blocos da versão anterior). Bloco posto pelo
## jogador tem material >= BUILT_DIRT: é construção, zumbi quebra.

const N := VoxelRef.N
const P := VoxelRef.P
const P3 := VoxelRef.P3
const GRID := VoxelRef.GRID
const SECTION := N * GRID ## 6,4 m
const NEAR := 40.0 ## raio com voxels a pé
const CAR_NEAR := 28.0 ## no carro (anda rápido: menos coisa para gerar)
const DEEP := 26.0 ## colunas até essa distância ganham as seções de baixo (cavernas)
const MAX_TASKS := 12
const SHOW_BUDGET_USEC := 4000 ## criar malha + colisão das seções prontas: até 4 ms por quadro
const LOOKAHEAD := 1.3 ## segundos à frente: gera adiantado onde o jogador vai estar
const LOOKAHEAD_MAX := 32.0
const NO_BLOCK := Vector3i(-2147483647, 0, 0)
const BOTTOM_SECTION := -10 ## y -64 m: abaixo da rocha-mãe

## Material do bloco -> item que sai cavando (rocha-mãe não sai).
const DROPS := {VoxelRef.TOPSOIL: &"terra", VoxelRef.DIRT: &"terra", VoxelRef.SAND: &"areia", VoxelRef.STONE: &"pedra",
	VoxelRef.GRAVEL: &"pedra", VoxelRef.COAL: &"carvao", VoxelRef.IRON: &"minerio_ferro", VoxelRef.COPPER: &"minerio_cobre",
	VoxelRef.TIN: &"minerio_estanho", VoxelRef.SULFUR: &"enxofre", VoxelRef.BUILT_DIRT: &"terra",
	VoxelRef.BUILT_STONE: &"pedra", VoxelRef.BUILT_SAND: &"areia"}
const HARD := [VoxelRef.STONE, VoxelRef.GRAVEL, VoxelRef.COAL, VoxelRef.IRON, VoxelRef.COPPER, VoxelRef.TIN, VoxelRef.SULFUR,
	VoxelRef.BUILT_STONE] ## precisa de picareta (pá: 3 golpes; minério: só picareta)
const ORES := [VoxelRef.COAL, VoxelRef.IRON, VoxelRef.COPPER, VoxelRef.TIN, VoxelRef.SULFUR]
## Item na mão -> material do bloco posto.
const ITEM_BLOCK := {&"terra": VoxelRef.BUILT_DIRT, &"pedra": VoxelRef.BUILT_STONE, &"areia": VoxelRef.BUILT_SAND}
const BLOCK_COST := {VoxelRef.BUILT_DIRT: 1, VoxelRef.BUILT_STONE: 2, VoxelRef.BUILT_SAND: 1}
const BLOCK_HITS := {VoxelRef.BUILT_DIRT: 3, VoxelRef.BUILT_STONE: 8, VoxelRef.BUILT_SAND: 2}

static var i: VoxelWorld
static var enabled := true ## false: o mundo fica só com o chão de alturas (testes do sistema antigo)

var terrain: TerrainWorld
var backend: Object ## ApioVoxel (C++) ou VoxelRef
var native := false
var active := true ## false: só gera quando pedirem (testes, fotos)
var sections := {} ## Vector3i -> PackedByteArray (dados já com as edições)
var edits := {} ## Vector3i bloco -> material (0 = ar)
var cave_factor := 0.0 ## 0..1: câmera dentro de caverna (neblina e luz de subsolo)
var _nodes := {} ## Vector3i -> Node3D (só seções com superfície)
var _columns := {} ## Vector2i -> {"cols": [alturas, solo, cores], "lo", "hi", "pending"}
var _tasks := {} ## Vector3i -> id
var _results := {}
var _mutex := Mutex.new()
var _edit_index := {} ## Vector3i seção -> {bloco: true} (inclui a borda da seção)
var _hits := {} ## bloco -> golpes de zumbi
var _dirty_chunks := {} ## Vector2i chunk -> true (refazer o buraco no chão de alturas)
var _material: Material
var _imported := false
var _check := 0.0
## Pior tempo (ms) de cada parte num quadro, para testes de desempenho.
var stats := {"add": 0.0, "collect": 0.0, "holes": 0.0, "drop": 0.0}
var last_ms := 0.0 ## quanto o _process deste quadro levou
var _scan_timer := 0.0
var _last_scan_col := Vector2i(-99999, -99999)


func _init(terrain_: TerrainWorld = null, auto := true) -> void:
	name = "Voxels"
	terrain = terrain_
	active = auto
	if ClassDB.class_exists("ApioVoxel"):
		backend = ClassDB.instantiate("ApioVoxel")
		native = true
	else:
		backend = VoxelRef.new()
	backend.setup(terrain.seed if terrain else 1337, 1.0, 1.0)


func _ready() -> void:
	i = self
	add_to_group("persist")
	if terrain:
		_material = terrain._material


func _exit_tree() -> void:
	if i == self:
		i = null
	for sec in _tasks:
		WorkerThreadPool.wait_for_task_completion(_tasks[sec])
	_tasks.clear()
	for col in _column_tasks:
		WorkerThreadPool.wait_for_task_completion(_column_tasks[col])
	_column_tasks.clear()


## O jogo usa voxels? (só com a extensão C++; a versão GDScript é lenta demais)
static func available() -> bool:
	return enabled and ClassDB.class_exists("ApioVoxel")


# --- Coordenadas e consultas ------------------------------------------------------------

static func section_of(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / SECTION), floori(p.y / SECTION), floori(p.z / SECTION))


static func block_of(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / GRID), floori(p.y / GRID), floori(p.z / GRID))


static func block_center(b: Vector3i) -> Vector3:
	return (Vector3(b) + Vector3(0.5, 0.5, 0.5)) * GRID


static func _sec_of_block(b: Vector3i) -> Vector3i:
	return Vector3i(floori(b.x / float(N)), floori(b.y / float(N)), floori(b.z / float(N)))


## Índice do bloco nos dados (com a borda) da seção, ou -1 se não cabe.
static func _local(sec: Vector3i, b: Vector3i) -> int:
	var l := b - sec * N + Vector3i.ONE
	if l.x < 0 or l.y < 0 or l.z < 0 or l.x >= P or l.y >= P or l.z >= P:
		return -1
	return VoxelRef.idx(l.x, l.y, l.z)


## Material do bloco (-1 = seção não carregada).
func material_at(b: Vector3i) -> int:
	var sec := _sec_of_block(b)
	var d: PackedByteArray = sections.get(sec, PackedByteArray())
	if d.is_empty():
		return -1
	var at := _local(sec, b)
	return d[P3 + at] if VoxelRef.density(d, at) > 0 else VoxelRef.AIR


## O ponto está dentro de bloco cheio? (-1 = não sei: seção não carregada)
func solid_at(p: Vector3) -> int:
	var m := material_at(block_of(p))
	return -1 if m < 0 else int(m != VoxelRef.AIR)


func covers(p: Vector3) -> bool:
	return sections.has(section_of(p))


static func is_built(m: int) -> bool:
	return m >= VoxelRef.BUILT_DIRT


## Ponto dentro de caverna (abaixo do chão natural e em seção carregada): sem água de
## lago/rio/mar ali (a água fica em cima, na superfície).
func cave_at(p: Vector3) -> bool:
	return terrain != null and covers(p) and p.y < terrain._base_at(p.x, p.z) - 1.5 and solid_at(p) == 0


## O corpo atingido é chão de voxel?
static func is_voxel_body(collider: Object) -> bool:
	return collider is StaticBody3D and (collider as Node).has_meta("voxel")


# --- Geração em volta do jogador -----------------------------------------------------------

func _process(delta: float) -> void:
	var t_start := Time.get_ticks_usec()
	_process_inner(delta)
	last_ms = (Time.get_ticks_usec() - t_start) / 1000.0


func _process_inner(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_collect(1000, SHOW_BUDGET_USEC)
	stats.collect = maxf(stats.collect, (Time.get_ticks_usec() - t0) / 1000.0)
	if not active or terrain == null:
		return
	if not _imported:
		_imported = true
		_import_columns()
	var camera := get_viewport().get_camera_3d()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var center: Vector3 = player.global_position if player else (camera.global_position if camera else Vector3.ZERO)
	var in_car: bool = player != null and player.get("vehicle") != null
	# Buffer à frente: também gera em volta de onde o jogador vai estar daqui a ~1 s.
	var vel := Vector3.ZERO
	if in_car:
		vel = (player.get("vehicle") as RigidBody3D).linear_velocity
	elif player is CharacterBody3D:
		vel = (player as CharacterBody3D).velocity
	vel.y = 0.0
	var ahead := center + vel.limit_length(LOOKAHEAD_MAX / LOOKAHEAD) * LOOKAHEAD
	var tu := Time.get_ticks_usec()
	# Varredura (quais colunas querer, quais soltar, ordem da fila) a cada 0,2 s ou quando o
	# jogador muda de coluna; nos outros quadros só põe tarefas nas threads.
	_scan_timer -= delta
	var here := Vector2i(floori(center.x / SECTION), floori(center.z / SECTION))
	if _scan_timer <= 0.0 or here != _last_scan_col:
		_scan_timer = 0.2
		_last_scan_col = here
		update_around(center, CAR_NEAR if in_car else NEAR, 6, ahead)
	else:
		_pump()
	stats["update_around"] = maxf(stats.get("update_around", 0.0), (Time.get_ticks_usec() - tu) / 1000.0)
	var t1 := Time.get_ticks_usec()
	_update_holes(1)
	stats.holes = maxf(stats.holes, (Time.get_ticks_usec() - t1) / 1000.0)
	_check -= delta
	if _check <= 0.0 and camera:
		_check = 0.2
		_update_cave(camera.global_position)
	cave_factor = move_toward(cave_factor, _cave_target, delta * 0.8)


## Pede as colunas de seções num raio (budget: colunas novas por chamada; < 0 = todas e
## espera ficar pronto, para testes e para o começo).
func update_around(center: Vector3, radius: float, budget := -1, ahead := Vector3.INF) -> void:
	var c := Vector2(center.x, center.z)
	var a := Vector2(ahead.x, ahead.z) if ahead != Vector3.INF else c
	var reach := int(ceil((radius + c.distance_to(a)) / SECTION)) + 1
	var here := Vector2i(floori(center.x / SECTION), floori(center.z / SECTION))
	var wanted := []
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var col := here + Vector2i(dx, dz)
			var mid := (Vector2(col) + Vector2(0.5, 0.5)) * SECTION
			var dist := mid.distance_to(c)
			# Em volta do jogador, ou em volta do ponto à frente (um pouco menor).
			if dist <= radius or mid.distance_to(a) <= radius * 0.75:
				wanted.append([minf(dist, mid.distance_to(a) + 6.0), col, dist])
	wanted.sort_custom(func(x, y): return x[0] < y[0])
	var made := 0
	for w in wanted:
		var col: Vector2i = w[1]
		var deep: float = center.y - 16.0 if w[2] <= DEEP else INF
		if not _columns.has(col):
			if budget >= 0 and made >= budget:
				continue
			var t0 := Time.get_ticks_usec()
			if _add_column(col, deep):
				made += 1
			stats.add = maxf(stats.add, (Time.get_ticks_usec() - t0) / 1000.0)
		elif deep != INF and _columns[col].ready:
			_extend_down(col, deep)
	# Longe demais (com folga): solta (tarefas em andamento terminam e são descartadas).
	for col: Vector2i in _columns.keys():
		var mid := (Vector2(col) + Vector2(0.5, 0.5)) * SECTION
		if mid.distance_to(c) > radius + SECTION * 1.5 and mid.distance_to(a) > radius * 0.75 + SECTION * 1.5:
			var t0 := Time.get_ticks_usec()
			_drop_column(col)
			stats.drop = maxf(stats.drop, (Time.get_ticks_usec() - t0) / 1000.0)
	# O que está mais perto do jogador sai primeiro (teleporte, renascer, carro rápido).
	if _waiting.size() > 1:
		for job: Dictionary in _waiting:
			job.d = _job_dist(job, c)
		_waiting.sort_custom(func(x, y): return x.d < y.d)
	_pump()
	if budget < 0:
		while _running() > 0 or not _waiting.is_empty() or not _to_show.is_empty():
			_pump()
			if _collect(1000) == 0:
				OS.delay_usec(300)
		_update_holes(-1)
		while not terrain._rebuilds.is_empty():
			terrain._collect_rebuilds()
			OS.delay_usec(300)


## Alturas, solo e cores das 18 x 18 colunas (centro de cada bloco, com a borda) de uma
## coluna de seções, a partir da grade de 1,6 m dos chunks do terreno (cópia: roda em thread).
static func _columns_from_lattice(sx: int, sz: int, lat: Dictionary, q: int) -> Array:
	var heights := PackedFloat32Array()
	heights.resize(P * P)
	var soil := PackedByteArray()
	soil.resize(P * P)
	var colors := PackedColorArray()
	colors.resize(P * P)
	var n := q + 1
	for pz in P:
		for px in P:
			var x := (sx * N + px - 1 + 0.5) * GRID
			var z := (sz * N + pz - 1 + 0.5) * GRID
			var gx := x / TerrainWorld.STEP
			var gz := z / TerrainWorld.STEP
			var gi := floori(gx)
			var gj := floori(gz)
			var coord := Vector2i(floori(float(gi) / q), floori(float(gj) / q))
			var li := gi - coord.x * q
			var lj := gj - coord.y * q
			var arrays: Array = lat[coord]
			var hs: PackedFloat32Array = arrays[0]
			var cs: PackedColorArray = arrays[1]
			var k0 := lj * n + li
			var u := gx - gi
			var v := gz - gj
			var k := pz * P + px
			heights[k] = TerrainWorld.tri_lerp(hs[k0], hs[k0 + 1], hs[k0 + n], hs[k0 + n + 1], u, v)
			var col := TerrainWorld._tri_color(cs[k0], cs[k0 + 1], cs[k0 + n], cs[k0 + n + 1], u, v)
			colors[k] = col
			soil[k] = 1 if (col.r > 0.62 and col.g > 0.52 and col.b < col.g) else 0
	# Encosta íngreme: rocha (como na malha do TerrainWorld).
	for pz in P:
		for px in P:
			var k := pz * P + px
			var hx := heights[pz * P + mini(px + 1, P - 1)] - heights[pz * P + maxi(px - 1, 0)]
			var hz := heights[mini(pz + 1, P - 1) * P + px] - heights[maxi(pz - 1, 0) * P + px]
			var steep := Vector2(hx, hz).length() / (GRID * 2.0)
			if steep > 0.9:
				colors[k] = colors[k].lerp(TerrainWorld.COLOR_ROCK, clampf((steep - 0.9) * 2.0, 0.0, 0.85))
				soil[k] = 2
	return [heights, soil, colors]


## Mesma coisa, na hora (thread principal; usado por fotos e testes).
func columns(sx: int, sz: int) -> Array:
	var lat := _lattices_for(Vector2i(sx, sz))
	if lat.is_empty():
		return []
	return _columns_from_lattice(sx, sz, lat, terrain._lat_q())


## Grades de 1,6 m dos chunks que a coluna (com a borda) usa; {} se algum chunk ainda não existe.
func _lattices_for(col: Vector2i) -> Dictionary:
	var lo := Vector2((col.x * N - 0.5) * GRID, (col.y * N - 0.5) * GRID)
	var hi := Vector2((col.x * N + N + 0.5) * GRID, (col.y * N + N + 0.5) * GRID)
	var out := {}
	for cz in range(floori(lo.y / terrain.chunk_size), floori(hi.y / terrain.chunk_size) + 1):
		for cx in range(floori(lo.x / terrain.chunk_size), floori(hi.x / terrain.chunk_size) + 1):
			var lat: Array = terrain._lattice.get(Vector2i(cx, cz), [])
			if lat.is_empty():
				return {}
			out[Vector2i(cx, cz)] = lat
	return out


var _waiting := [] ## trabalhos esperando vaga de thread ({"col"} ou {"sec"})
var _column_tasks := {} ## Vector2i -> id (coluna inteira em thread)
var _column_results := {}
var _to_show := [] ## [seção, dados, malha, geração] prontos para virar nó
var _gen := 0


func _add_column(col: Vector2i, deep: float) -> bool:
	var lat := _lattices_for(col)
	if lat.is_empty():
		return false # o chunk do terreno ainda não foi gerado: tenta depois
	_gen += 1
	_columns[col] = {"cols": [], "lo": 0, "hi": -1, "pending": 0, "ready": false, "gen": _gen, "t_req": Time.get_ticks_usec()}
	var edit_lists := {}
	for sec: Vector3i in _edit_index:
		if sec.x == col.x and sec.z == col.y:
			edit_lists[sec] = _edit_list(sec)
	_waiting.append({"col": col, "lat": lat, "edits": edit_lists, "deep": deep, "gen": _gen})
	return true


func _extend_down(col: Vector2i, deep: float) -> void:
	var entry: Dictionary = _columns[col]
	var want := maxi(floori(deep / SECTION), BOTTOM_SECTION)
	if want >= entry.lo:
		return
	for sy in range(want, entry.lo):
		entry.pending += 1
		_waiting.append({"sec": Vector3i(col.x, sy, col.y), "gen": entry.gen})
	entry.lo = want


static func _job_dist(job: Dictionary, c: Vector2) -> float:
	var col: Vector2i = job.col if job.has("col") else Vector2i(job.sec.x, job.sec.z)
	return ((Vector2(col) + Vector2(0.5, 0.5)) * SECTION).distance_squared_to(c)


func _running() -> int:
	return _column_tasks.size() + _tasks.size()


## Prioridade das tarefas de streaming. As pesadas (chunks do chão de alturas, grama, casas)
## vão em prioridade baixa: o Godot as deixa em no máximo 75% das threads (project.godot,
## low_priority_thread_ratio), então sempre sobra um núcleo. Com tudo em alta, as 4 threads de
## um PC de 4 núcleos ocupavam tudo e a thread principal perdia a vez por alguns ms em qualquer
## parte do quadro (travadas de ~30-40 ms).
const STREAM_PRIORITY := false
## As colunas de voxel são curtas (~2 ms de thread) e poucas: vão em alta, usando o núcleo que
## sobra. Na fila baixa esperavam ~0,7 s (até 4 s) atrás dos chunks pesados.
const VOXEL_PRIORITY := true


## Põe trabalhos nas threads (no máximo MAX_TASKS de uma vez: andando rápido, o que ficou
## para trás é descartado antes de começar).
func _pump() -> void:
	var later := []
	while _running() < MAX_TASKS and not _waiting.is_empty():
		var job: Dictionary = _waiting.pop_front()
		if job.has("col"):
			var entry: Dictionary = _columns.get(job.col, {})
			if entry.is_empty() or entry.gen != job.gen:
				continue
			if _column_tasks.has(job.col):
				later.append(job) # a tarefa de antes (coluna solta e pedida de novo) ainda roda
				continue
			_column_tasks[job.col] = WorkerThreadPool.add_task(
				_work_column.bind(job.col, job.lat, terrain._lat_q(), job.edits, job.deep, job.gen), VOXEL_PRIORITY)
		else:
			var sec: Vector3i = job.sec
			var entry: Dictionary = _columns.get(Vector2i(sec.x, sec.z), {})
			if entry.is_empty() or entry.gen != job.gen or sections.has(sec):
				continue
			if _tasks.has(sec):
				later.append(job)
				continue
			var cols: Array = entry.cols
			_tasks[sec] = WorkerThreadPool.add_task(_work.bind(sec, cols[0], cols[1], cols[2], _edit_list(sec), job.gen), VOXEL_PRIORITY)
	_waiting.append_array(later)


## Thread: alturas da coluna, faixa de seções (superfície e, perto, o subsolo) e cada seção.
func _work_column(col: Vector2i, lat: Dictionary, q: int, edit_lists: Dictionary, deep: float, gen: int) -> void:
	var t_start := Time.get_ticks_usec()
	var cols := _columns_from_lattice(col.x, col.y, lat, q)
	var h_min := INF
	var h_max := -INF
	for h in (cols[0] as PackedFloat32Array):
		h_min = minf(h_min, h)
		h_max = maxf(h_max, h)
	# Faixa da superfície (mais uma seção embaixo para a boca das cavernas).
	var lo := floori((h_min - 4.0) / SECTION) - 1
	var hi := floori((h_max + 0.6) / SECTION)
	if deep != INF:
		lo = mini(lo, floori(minf(h_min - 20.0, deep) / SECTION))
	lo = maxi(lo, BOTTOM_SECTION)
	var made := {}
	for sy in range(lo, hi + 1):
		var sec := Vector3i(col.x, sy, col.y)
		var d: PackedByteArray = backend.fill(sec, cols[0], cols[1])
		_apply_edits(d, edit_lists.get(sec, []))
		made[sec] = [d, backend.build_mesh(d, cols[2])]
	_mutex.lock()
	_column_results[col] = {"cols": cols, "lo": lo, "hi": hi, "sections": made, "gen": gen,
		"t_start": t_start, "t_end": Time.get_ticks_usec()}
	_mutex.unlock()


## Thread: uma seção a mais (coluna descendo para o subsolo).
func _work(sec: Vector3i, heights: PackedFloat32Array, soil: PackedByteArray, colors: PackedColorArray, edit_list: Array, gen: int) -> void:
	var d: PackedByteArray = backend.fill(sec, heights, soil)
	_apply_edits(d, edit_list)
	var mesh: Array = backend.build_mesh(d, colors)
	_mutex.lock()
	_results[sec] = [d, mesh, gen]
	_mutex.unlock()


## Recolhe o que as threads terminaram e cria até "budget" seções (e até budget_usec de
## tempo, se dado); devolve quantas.
func _collect(budget: int, budget_usec := 0) -> int:
	var t0 := Time.get_ticks_usec()
	for col: Vector2i in _column_tasks.keys():
		if not WorkerThreadPool.is_task_completed(_column_tasks[col]):
			continue
		WorkerThreadPool.wait_for_task_completion(_column_tasks[col])
		_column_tasks.erase(col)
		_mutex.lock()
		var r: Dictionary = _column_results.get(col, {})
		_column_results.erase(col)
		_mutex.unlock()
		var entry: Dictionary = _columns.get(col, {})
		if r.is_empty() or entry.is_empty() or entry.gen != r.gen:
			continue # a coluna foi solta enquanto a thread trabalhava
		entry.cols = r.cols
		# Medição: espera na fila das threads, tempo de thread e do pedido até chegar aqui.
		var thread_ms: float = (r.t_end - r.t_start) / 1000.0
		var queue_ms: float = (r.t_start - entry.t_req) / 1000.0
		stats.thread_max = maxf(stats.get("thread_max", 0.0), thread_ms)
		stats.thread_sum = stats.get("thread_sum", 0.0) + thread_ms
		stats.queue_max = maxf(stats.get("queue_max", 0.0), queue_ms)
		stats.queue_sum = stats.get("queue_sum", 0.0) + queue_ms
		stats.columns_done = stats.get("columns_done", 0) + 1
		entry.lo = mini(entry.lo, r.lo) if entry.hi >= entry.lo else r.lo
		entry.hi = r.hi
		entry.pending += r.sections.size()
		for sec: Vector3i in r.sections:
			_to_show.append([sec, r.sections[sec][0], r.sections[sec][1], r.gen])
	for sec: Vector3i in _tasks.keys():
		if not WorkerThreadPool.is_task_completed(_tasks[sec]):
			continue
		WorkerThreadPool.wait_for_task_completion(_tasks[sec])
		_tasks.erase(sec)
		_mutex.lock()
		var r: Array = _results.get(sec, [])
		_results.erase(sec)
		_mutex.unlock()
		if not r.is_empty():
			_to_show.append([sec, r[0], r[1], r[2]])
	var made := 0
	while not _to_show.is_empty() and made < budget:
		if budget_usec > 0 and made > 0 and Time.get_ticks_usec() - t0 > budget_usec:
			break # o resto fica para o próximo quadro
		var item: Array = _to_show.pop_front()
		var sec: Vector3i = item[0]
		var entry: Dictionary = _columns.get(Vector2i(sec.x, sec.z), {})
		if entry.is_empty() or entry.gen != item[3]:
			continue
		var d: PackedByteArray = item[1]
		var mesh: Array = item[2]
		if _edit_index.has(sec):
			# Edição que chegou enquanto a thread trabalhava: aplica por cima e refaz a malha.
			_apply_edits(d, _edit_list(sec))
			mesh = backend.build_mesh(d, entry.cols[2])
		sections[sec] = d
		_show(sec, mesh)
		made += 1
		entry.pending -= 1
		if entry.pending <= 0 and not entry.ready:
			entry.ready = true # a coluna inteira existe: pode tirar o chão de alturas dali
			_dirty_chunks[_chunk_of_column(Vector2i(sec.x, sec.z))] = true
	return made


## Põe (ou troca) a malha e a colisão de uma seção.
func _show(sec: Vector3i, mesh_arrays: Array) -> void:
	var verts: PackedVector3Array = mesh_arrays[0]
	var node: Node3D = _nodes.get(sec)
	if verts.is_empty():
		if node:
			node.queue_free()
			_nodes.erase(sec)
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = mesh_arrays[1]
	arrays[Mesh.ARRAY_COLOR] = mesh_arrays[2]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var faces := ConcavePolygonShape3D.new()
	faces.set_faces(verts)
	if node == null:
		node = Node3D.new()
		node.name = "Sec_%d_%d_%d" % [sec.x, sec.y, sec.z]
		node.position = Vector3(sec) * SECTION
		var visual := MeshInstance3D.new()
		visual.name = "Mesh"
		visual.material_override = _material
		node.add_child(visual)
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("voxel", sec)
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		body.add_child(shape)
		node.add_child(body)
		add_child(node)
		_nodes[sec] = node
	(node.get_node("Mesh") as MeshInstance3D).mesh = mesh
	(node.get_node("Body/Shape") as CollisionShape3D).shape = faces


func _drop_column(col: Vector2i) -> void:
	var entry: Dictionary = _columns[col]
	if entry.hi >= entry.lo:
		for sy in range(entry.lo, entry.hi + 1):
			var sec := Vector3i(col.x, sy, col.y)
			sections.erase(sec)
			var node: Node3D = _nodes.get(sec)
			if node:
				node.queue_free()
				_nodes.erase(sec)
	_columns.erase(col)
	if entry.ready:
		_dirty_chunks[_chunk_of_column(col)] = true


func _chunk_of_column(col: Vector2i) -> Vector2i:
	var per := roundi(terrain.chunk_size / SECTION)
	return Vector2i(floori(float(col.x) / per), floori(float(col.y) / per))


## Refaz o buraco no chão de alturas dos chunks que mudaram (colunas prontas).
func _update_holes(budget: int) -> void:
	var done := 0
	var per := roundi(terrain.chunk_size / SECTION)
	for coord: Vector2i in _dirty_chunks.keys():
		if budget >= 0 and done >= budget:
			break
		_dirty_chunks.erase(coord)
		var holes := PackedByteArray()
		holes.resize(per * per)
		for j in per:
			for k in per:
				var entry: Dictionary = _columns.get(Vector2i(coord.x * per + k, coord.y * per + j), {})
				holes[j * per + k] = 1 if not entry.is_empty() and entry.ready else 0
		terrain.set_voxel_holes(coord, holes)
		done += 1


# --- Edições -------------------------------------------------------------------------------

## Seções cuja área (com a borda) contém o bloco (até 8).
static func _sections_touching(b: Vector3i) -> Array:
	var axes := []
	for a in 3:
		var v: int = b[a]
		var s := floori(v / float(N))
		var list := [s]
		if posmod(v, N) == 0:
			list.append(s - 1)
		elif posmod(v, N) == N - 1:
			list.append(s + 1)
		axes.append(list)
	var out := []
	for x in axes[0]:
		for y in axes[1]:
			for z in axes[2]:
				out.append(Vector3i(x, y, z))
	return out


## Edições que caem nos dados da seção: [índice, material, ...] (cópia para a thread).
func _edit_list(sec: Vector3i) -> Array:
	var list := []
	for b: Vector3i in _edit_index.get(sec, {}):
		var at := _local(sec, b)
		if at >= 0:
			list.append(at)
			list.append(edits[b])
	return list


static func _apply_edits(d: PackedByteArray, list: Array) -> void:
	if list.is_empty():
		return
	var solid := VoxelRef.solid_count(d)
	for k in range(0, list.size(), 2):
		var at: int = list[k]
		var mat: int = list[k + 1]
		var was := VoxelRef.density(d, at) > 0
		if mat == VoxelRef.AIR:
			d[at] = 129 # -127
			d[P3 + at] = VoxelRef.AIR
			solid -= 1 if was else 0
		else:
			d[at] = 127
			d[P3 + at] = mat
			solid += 0 if was else 1
	d.encode_s32(P3 * 2, solid)


## Troca um bloco e refaz as seções carregadas que o enxergam (chamado pelo host e pela rede).
func set_block(b: Vector3i, mat: int) -> void:
	edits[b] = mat
	_hits.erase(b)
	for sec: Vector3i in _sections_touching(b):
		if not _edit_index.has(sec):
			_edit_index[sec] = {}
		_edit_index[sec][b] = true
		var d: PackedByteArray = sections.get(sec, PackedByteArray())
		if d.is_empty():
			continue # ainda não carregada: a edição entra quando a seção chegar (_collect)
		_apply_edits(d, [_local(sec, b), mat])
		sections[sec] = d
		var entry: Dictionary = _columns.get(Vector2i(sec.x, sec.z), {})
		if not entry.is_empty():
			_show(sec, backend.build_mesh(d, entry.cols[2]))


## O que sai cavando o bloco: {"item", "amount", "hard", "ore"} ou {} (ar, rocha-mãe, não carregado).
func dig_result(b: Vector3i) -> Dictionary:
	var m := material_at(b)
	if m <= VoxelRef.AIR or m == VoxelRef.BEDROCK or not DROPS.has(m):
		return {}
	var item: StringName = DROPS[m]
	if m == VoxelRef.TOPSOIL:
		# Chão natural: areia no deserto/praia, pedra na encosta, terra no resto.
		var cols: Dictionary = _columns.get(Vector2i(floori(b.x / float(N)), floori(b.z / float(N))), {})
		if not cols.is_empty():
			var l := b - Vector3i(floori(b.x / float(N)), 0, floori(b.z / float(N))) * N + Vector3i.ONE
			var soil: int = (cols.cols[1] as PackedByteArray)[l.z * P + l.x]
			item = &"areia" if soil == 1 else (&"pedra" if soil == 2 else &"terra")
	return {"item": item, "amount": int(BLOCK_COST.get(m, 1)), "hard": m in HARD, "ore": m in ORES, "material": m}


## Bloco posto pelo jogador perto do ponto atingido (o golpe pega na rampa do lado).
func built_near(point: Vector3, direction: Vector3) -> Vector3i:
	var flat := Vector3(direction.x, 0.0, direction.z).normalized() * GRID
	for k in 3:
		var b := block_of(point + flat * k)
		for d in [Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
			if is_built(material_at(b + d)):
				return b + d
	return NO_BLOCK


# --- Pedidos (host decide; ver Net.system_request) -----------------------------------------

func request_dig(b: Vector3i) -> void:
	Net.i.system_request(name, "dig", [b])


func request_place(b: Vector3i, mat: int) -> void:
	Net.i.system_request(name, "place", [b, mat])


## Golpe de zumbi num bloco posto (host). true = quebrou.
func zombie_hit(b: Vector3i, power: int) -> bool:
	var m := material_at(b)
	if not is_built(m):
		return false
	_hits[b] = int(_hits.get(b, 0)) + power
	if _hits[b] < int(BLOCK_HITS.get(m, 3)):
		return false
	Net.i.system_request(name, "break", [b])
	return true


func host_apply(action: String, args: Array) -> Array:
	var b: Vector3i = args[0]
	var m := material_at(b)
	match action:
		"dig":
			if m <= VoxelRef.AIR or m == VoxelRef.BEDROCK:
				return []
			set_block(b, VoxelRef.AIR)
		"break":
			if not is_built(m):
				return []
			set_block(b, VoxelRef.AIR)
		"place":
			var mat: int = args[1]
			if m != VoxelRef.AIR or not is_built(mat):
				return [] # já tem bloco ali (ou fora da área carregada)
			set_block(b, mat)
		_:
			return []
	_edit_sound(action, b)
	return [b, edits[b]]


func apply_remote(action: String, args: Array) -> void:
	if args.size() < 2:
		return
	set_block(args[0], args[1])
	_edit_sound(action, args[0])


func _edit_sound(action: String, b: Vector3i) -> void:
	if not is_inside_tree():
		return
	var at := block_center(b)
	match action:
		"dig":
			Sfx.play_at("step_soft", at, 4.0, 0.8)
		"place":
			Sfx.play_at("step_soft", at, 4.0, 1.15)
		"break":
			Sfx.play_at("crunch", at, 4.0, 0.6)


# --- Salvar / rede -------------------------------------------------------------------------

func persist_key() -> String:
	return "voxels"


func save_data() -> Dictionary:
	var list := []
	for b: Vector3i in edits:
		list.append([b, edits[b]])
	return {"edits": list}


func load_data(data: Dictionary) -> void:
	for entry in data.get("edits", []):
		set_block(entry[0], entry[1])


func net_sync_to(peer: int) -> void:
	Net.i.send_system_state(peer, name, save_data())


## Blocos da versão anterior (colunas de 0,4 m do TerrainWorld): viram edições 3D. Coluna
## cavada n vezes: os n blocos de cima viram ar; pilha posta: blocos em cima do chão.
func _import_columns() -> void:
	if terrain.blocks.is_empty():
		return
	for col: Vector2i in terrain.blocks:
		var b: PackedByteArray = terrain.blocks[col]
		var h := terrain._base_at((col.x + 0.5) * GRID, (col.y + 0.5) * GRID)
		var top := floori(h / GRID) # bloco do chão natural
		for k in b[0]:
			set_block(Vector3i(col.x, top - k, col.y), VoxelRef.AIR)
		for k in range(1, b.size()):
			var mat := {TerrainWorld.Mat.DIRT: VoxelRef.BUILT_DIRT, TerrainWorld.Mat.STONE: VoxelRef.BUILT_STONE,
				TerrainWorld.Mat.SAND: VoxelRef.BUILT_SAND}.get(b[k], VoxelRef.BUILT_DIRT) as int
			set_block(Vector3i(col.x, top - b[0] + k, col.y), mat)
	terrain.load_data({"blocks": []})


# --- Caverna: neblina e luz -----------------------------------------------------------------

var _cave_target := 0.0


## A câmera está embaixo da terra (abaixo do chão natural e com teto de voxel em cima)?
func _update_cave(eye: Vector3) -> void:
	_cave_target = 0.0
	if terrain == null or not covers(eye):
		return
	if eye.y > terrain._base_at(eye.x, eye.z) - 2.0:
		return
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + Vector3.UP * 40.0, 1))
	if not hit.is_empty() and is_voxel_body(hit.collider):
		_cave_target = 1.0
