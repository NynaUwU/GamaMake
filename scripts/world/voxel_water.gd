class_name VoxelWater
extends RefCounted
## Água que escorre nos voxels, em blocos de 0,4 m (parte do VoxelWorld).
##
## Lagos, rios e o mar continuam como antes (superfície fixa; o mar fica parado em volta da
## ilha) e servem de FONTE sem fim: o "volume" deles é o ar entre o chão natural e o nível
## da água (is_static). Cavando perto, a água sai deles e:
##   - cai reto onde tem buraco embaixo (bloco "caindo", altura cheia);
##   - se espalha para os lados perdendo 1 de nível por bloco (FULL = 12: até ~4,8 m no plano),
##     só onde não pode cair;
##   - bloco com um vizinho-fonte do lado (na mesma altura), chão firme (ou água) embaixo e
##     inteiro abaixo da SUPERFÍCIE de onde a fonte veio (nível do lago/rio/mar) vira FONTE: um
##     canal abaixo do nível do lago enche até esse nível (vasos comunicantes), e água solta no
##     plano não se multiplica (só escorre e acaba);
##   - tirando a fonte (pondo bloco), o resto seca aos poucos.
## Só anda perto de onde mexeram (cavar/pôr acorda os vizinhos): o mundo não alaga sozinho ao
## carregar. O host simula (TICK); os outros recebem as mudanças ("water_sync") e o save leva tudo.

const FULL := 12
const TICK := 0.25
const BUDGET := 500 ## blocos atualizados por tick (no máximo)
const BUDGET_USEC := 2000 ## e no máximo 2 ms por tick: o resto fica para o próximo
const MAX_CELLS := 20000 ## teto de blocos de água (caverna enorme ligada a um lago não pesa)
const COLOR := Color(0.36, 0.6, 0.66, 0.68) ## perto da cor dos lagos

var vw: VoxelWorld
var cells := {} ## Vector3i -> nível 1..FULL
var sources := {} ## Vector3i -> altura da superfície de onde veio (fonte: não seca sozinha)
var falling := {} ## Vector3i -> true (caindo: altura cheia, espalha embaixo)
var _by_sec := {} ## seção -> {bloco: true}
var _active := {}
var _dirty := {} ## seções com malha a refazer
var _nodes := {} ## seção -> MeshInstance3D
var _timer := 0.0
var _static_cache := {} ## coluna (x, z) -> [nível da água fixa, chão natural]
var _changes := [] ## host: mudanças deste tick para mandar aos outros
var _material: StandardMaterial3D
var stats := {"ticks": 0, "updates": 0, "tick_ms": 0.0, "mesh_ms": 0.0}


func _init(world: VoxelWorld) -> void:
	vw = world
	_material = StandardMaterial3D.new()
	_material.albedo_color = COLOR
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.roughness = 0.08
	_material.metallic_specular = 0.7


# --- Consultas -----------------------------------------------------------------------------

## Água fixa (lago, rio, mar) no bloco: entre o chão natural e o nível da água.
func is_static(b: Vector3i) -> bool:
	var col := Vector2i(b.x, b.z)
	var info: Array = _static_cache.get(col, [])
	if info.is_empty():
		info = _static_info(col)
		_static_cache[col] = info
	var y := (b.y + 0.5) * VoxelWorld.GRID
	return y < info[0] and y > info[1] - VoxelWorld.GRID


func _static_info(col: Vector2i) -> Array:
	var x := (col.x + 0.5) * VoxelWorld.GRID
	var z := (col.y + 0.5) * VoxelWorld.GRID
	var terrain := vw.terrain
	if terrain == null:
		return [-INF, 0.0]
	var base := terrain._base_at(x, z)
	var level := -INF
	var lake := Lakes.at(terrain.lakes, x, z)
	if not lake.is_empty() and not lake.frozen:
		level = lake.level
	else:
		var river: Dictionary = terrain.river_at(x, z)
		if not river.is_empty():
			level = river.level
		elif base < TerrainWorld.SEA_LEVEL and terrain.sea_at(x, z, base):
			level = TerrainWorld.SEA_LEVEL
	return [level, base]


func level_at(b: Vector3i) -> int:
	if cells.has(b):
		return cells[b]
	return FULL if is_static(b) else 0


func has_water(b: Vector3i) -> bool:
	return cells.has(b) or is_static(b)


func is_source(b: Vector3i) -> bool:
	return sources.has(b) or is_static(b)


## Altura da superfície que alimenta a fonte (nível do lago/rio/mar) ou -INF.
func source_head(b: Vector3i) -> float:
	if sources.has(b):
		return sources[b]
	if is_static(b):
		return (_static_cache[Vector2i(b.x, b.z)] as Array)[0]
	return -INF


## Bloco que segura água (cheio ou fora da área carregada).
func _solid(b: Vector3i) -> bool:
	return vw.material_at(b) != VoxelRef.AIR


## Profundidade da água "nova" no ponto (nadar, efeito debaixo d'água) ou -INF.
func depth_at(p: Vector3) -> float:
	if cells.is_empty():
		return -INF
	var b := VoxelWorld.block_of(p)
	if not cells.has(b):
		return -INF
	var top := b
	while cells.has(top + Vector3i.UP) and top.y < b.y + 40:
		top += Vector3i.UP
	return top.y * VoxelWorld.GRID + _height(top) - p.y


## Altura da água dentro do bloco (0..0,4 m).
func _height(b: Vector3i) -> float:
	if falling.has(b) or sources.has(b) or cells.has(b + Vector3i.UP):
		return VoxelWorld.GRID * 0.92
	return VoxelWorld.GRID * 0.92 * float(cells.get(b, 0)) / FULL


# --- Simulação (host) -------------------------------------------------------------------

## Mexeram no bloco (cavou/pôs): ele e os vizinhos podem mudar.
func wake(b: Vector3i) -> void:
	_active[b] = true
	for d in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		_active[b + d] = true


func process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = TICK
		if Net.i == null or Net.i.is_host():
			_tick()
	_rebuild_meshes(2)


func _tick() -> void:
	if _active.is_empty():
		return
	stats.ticks += 1
	var t0 := Time.get_ticks_usec()
	var list := _active.keys()
	_active.clear()
	var done := 0
	for b: Vector3i in list:
		if done >= BUDGET or (done > 0 and Time.get_ticks_usec() - t0 > BUDGET_USEC):
			_active[b] = true # o resto fica para o próximo tick
			continue
		done += 1
		_update(b)
	stats.updates += done
	stats.tick_ms = maxf(stats.tick_ms, (Time.get_ticks_usec() - t0) / 1000.0)
	if not _changes.is_empty():
		if Net.i and Net.i.online():
			Net.i.system_request(vw.name, "water_sync", [Vector3i.ZERO, _changes.duplicate()])
		_changes.clear()


func _update(b: Vector3i) -> void:
	if vw.material_at(b) == -1:
		return # fora da área carregada: espera
	if _solid(b):
		if cells.has(b):
			_put(b, 0, false, -INF)
		return
	if is_static(b) or sources.has(b):
		return
	var level := 0
	var fall := false
	if has_water(b + Vector3i.UP):
		level = FULL
		fall = true
	else:
		var head := -INF
		for d in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			var n: Vector3i = b + d
			var lv := level_at(n)
			if lv <= 0:
				continue
			var under: Vector3i = n + Vector3i.DOWN
			if not (_solid(under) or has_water(under)):
				continue # o vizinho cai em vez de espalhar
			if is_source(n):
				head = maxf(head, source_head(n))
			level = maxi(level, (FULL if falling.has(n) else lv) - 1)
		var below := b + Vector3i.DOWN
		if (b.y + 1) * VoxelWorld.GRID <= head - 0.005 and (_solid(below) or has_water(below)):
			_put(b, FULL, false, head) # abaixo da superfície da fonte do lado: vira fonte
			return
	_put(b, level, fall, -INF)


## head: altura da superfície que alimenta a fonte (-INF = não é fonte).
func _put(b: Vector3i, level: int, fall: bool, head: float) -> void:
	var old: int = cells.get(b, 0)
	if old == level and falling.has(b) == fall and sources.get(b, -INF) == head:
		return
	if old == 0 and level > 0 and cells.size() >= MAX_CELLS:
		return # no teto: não cria água nova
	_apply(b, level, fall, head)
	_changes.append_array([b, level, int(fall), head])
	wake(b)


## Grava o bloco (host e quem recebe da rede/save).
func _apply(b: Vector3i, level: int, fall: bool, head: float) -> void:
	var sec := VoxelWorld.section_of_block(b)
	if level <= 0:
		cells.erase(b)
		falling.erase(b)
		sources.erase(b)
		if _by_sec.has(sec):
			_by_sec[sec].erase(b)
			if _by_sec[sec].is_empty():
				_by_sec.erase(sec)
	else:
		cells[b] = level
		if fall:
			falling[b] = true
		else:
			falling.erase(b)
		if head > -INF:
			sources[b] = head
		else:
			sources.erase(b)
		if not _by_sec.has(sec):
			_by_sec[sec] = {}
		_by_sec[sec][b] = true
	_mark(b)


func _mark(b: Vector3i) -> void:
	var sec := VoxelWorld.section_of_block(b)
	_dirty[sec] = true
	# Blocos na borda mudam a face do vizinho na seção do lado.
	var l := b - sec * VoxelWorld.N
	for a in 3:
		if l[a] == 0:
			var d := Vector3i.ZERO
			d[a] = -1
			_dirty[sec + d] = true
		elif l[a] == VoxelWorld.N - 1:
			var d := Vector3i.ZERO
			d[a] = 1
			_dirty[sec + d] = true


## Mudanças vindas do host (e o save): [bloco, nível, caindo (0/1), superfície da fonte (-INF = não é), ...].
const STRIDE := 4


func apply_changes(flat: Array) -> void:
	for k in range(0, flat.size() - STRIDE + 1, STRIDE):
		_apply(flat[k], flat[k + 1], int(flat[k + 2]) != 0, float(flat[k + 3]))


func save_list() -> Array:
	var out := []
	for b: Vector3i in cells:
		out.append_array([b, cells[b], int(falling.has(b)), sources.get(b, -INF)])
	return out


func load_list(flat: Array) -> void:
	apply_changes(flat)
	for b in cells:
		_active[b] = true # volta a escorrer de onde parou


## Seção apareceu/sumiu da área carregada.
func section_changed(sec: Vector3i) -> void:
	if _by_sec.has(sec) or _nodes.has(sec):
		_dirty[sec] = true


# --- Malha ---------------------------------------------------------------------------------

func _rebuild_meshes(budget: int) -> void:
	var done := 0
	for sec: Vector3i in _dirty.keys():
		if done >= budget:
			break
		_dirty.erase(sec)
		var t0 := Time.get_ticks_usec()
		_build_section(sec)
		stats.mesh_ms = maxf(stats.mesh_ms, (Time.get_ticks_usec() - t0) / 1000.0)
		done += 1


## Blocos de água da seção: topo na altura do nível; lados onde o vizinho é ar mais baixo;
## embaixo onde cai no ar. Transparente, sem cull (vista de dentro também).
func _build_section(sec: Vector3i) -> void:
	var node: MeshInstance3D = _nodes.get(sec)
	var list: Dictionary = _by_sec.get(sec, {})
	if list.is_empty() or not vw.sections.has(sec):
		if node:
			node.queue_free()
			_nodes.erase(sec)
		return
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var g := VoxelWorld.GRID
	var origin := Vector3(sec) * VoxelWorld.SECTION
	for b: Vector3i in list:
		var p := Vector3(b) * g - origin
		var h := _height(b)
		if not has_water(b + Vector3i.UP):
			_quad(verts, normals, p + Vector3(0, h, 0), Vector3(g, 0, 0), Vector3(0, 0, g), Vector3.UP)
		for d in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			var n: Vector3i = b + d
			if _solid(n) or is_static(n):
				continue
			var hn := _height(n) if cells.has(n) else 0.0
			if hn >= h:
				continue
			var dir := Vector3(d)
			var center := p + Vector3(g, 0, g) * 0.5 + dir * g * 0.5
			var side := Vector3(-dir.z, 0, dir.x) * g
			_quad(verts, normals, center - side * 0.5 + Vector3(0, hn, 0), side, Vector3(0, h - hn, 0), dir)
		var below := b + Vector3i.DOWN
		if not _solid(below) and not has_water(below):
			_quad(verts, normals, p, Vector3(0, 0, g), Vector3(g, 0, 0), Vector3.DOWN)
	if verts.is_empty():
		if node:
			node.queue_free()
			_nodes.erase(sec)
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if node == null:
		node = MeshInstance3D.new()
		node.name = "Water_%d_%d_%d" % [sec.x, sec.y, sec.z]
		node.material_override = _material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = origin
		vw.add_child(node)
		_nodes[sec] = node
	node.mesh = mesh


static func _quad(verts: PackedVector3Array, normals: PackedVector3Array, a: Vector3, u: Vector3, v: Vector3, n: Vector3) -> void:
	for p in [a, a + u, a + u + v, a, a + u + v, a + v]:
		verts.append(p)
		normals.append(n)
