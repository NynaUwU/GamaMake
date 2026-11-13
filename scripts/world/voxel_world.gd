class_name VoxelWorld
extends Node3D
## Terreno em voxels 3D (fase 1: protótipo). Blocos de 0,4 m em seções de 16^3 (6,4 m),
## geradas a partir das alturas do TerrainWorld (as mesmas rampas de hoje na superfície)
## mais cavernas, veios de minério e rocha-mãe a 60 m abaixo do nível do mar.
##
## Quem faz a conta: a extensão C++ ApioVoxel (bin/apio_voxel.gdextension) quando está
## instalada; senão a VoxelRef (GDScript, o mesmo algoritmo, ~200x mais lenta).
##
## Nesta fase o mundo continua sendo o TerrainWorld; build_chunk() troca um pedaço por
## voxels (para fotos e testes). A troca de perto do jogador vem na fase 2.

const N := VoxelRef.N
const P := VoxelRef.P
const GRID := VoxelRef.GRID
const SECTION := N * GRID ## 6,4 m

var terrain: TerrainWorld
var backend: Object ## ApioVoxel (C++) ou VoxelRef
var native := false
var sections := {} ## Vector3i -> PackedByteArray (dados)
var _nodes := {} ## Vector3i -> Node3D


func _init(terrain_: TerrainWorld = null) -> void:
	terrain = terrain_
	if ClassDB.class_exists("ApioVoxel"):
		backend = ClassDB.instantiate("ApioVoxel")
		native = true
	else:
		backend = VoxelRef.new()
	var seed_value := terrain.seed if terrain else 1337
	backend.setup(seed_value, 1.0, 1.0)


## Seção que contém o ponto.
static func section_of(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / SECTION), floori(p.y / SECTION), floori(p.z / SECTION))


## Alturas, solo e cores do chão natural das 18 x 18 colunas (centro de cada bloco, com a
## borda) de uma coluna de seções.
func columns(sx: int, sz: int) -> Array:
	var heights := PackedFloat32Array()
	heights.resize(P * P)
	var soil := PackedByteArray()
	soil.resize(P * P)
	var colors := PackedColorArray()
	colors.resize(P * P)
	for pz in P:
		for px in P:
			var x := (sx * N + px - 1 + 0.5) * GRID
			var z := (sz * N + pz - 1 + 0.5) * GRID
			var i := pz * P + px
			var h := terrain._base_at(x, z) if terrain else 0.0
			heights[i] = h
			if terrain:
				var biome := terrain.biome_at(x, z)
				var c := terrain._color_for(x, z, terrain._height_from(x, z, biome), biome)
				colors[i] = c
				soil[i] = 1 if (c.r > 0.62 and c.g > 0.52 and c.b < c.g) else 0
	# Encosta íngreme: rocha (como na malha do TerrainWorld).
	for pz in P:
		for px in P:
			var i := pz * P + px
			var hx := heights[pz * P + mini(px + 1, P - 1)] - heights[pz * P + maxi(px - 1, 0)]
			var hz := heights[mini(pz + 1, P - 1) * P + px] - heights[maxi(pz - 1, 0) * P + px]
			var steep := Vector2(hx, hz).length() / (GRID * 2.0)
			if steep > 0.9:
				colors[i] = colors[i].lerp(TerrainWorld.COLOR_ROCK, clampf((steep - 0.9) * 2.0, 0.0, 0.85))
				soil[i] = 2
	return [heights, soil, colors]


## Gera (ou devolve) os dados de uma seção.
func data(sec: Vector3i, cols: Array = []) -> PackedByteArray:
	if sections.has(sec):
		return sections[sec]
	if cols.is_empty():
		cols = columns(sec.x, sec.z)
	var d: PackedByteArray = backend.fill(sec, cols[0], cols[1])
	sections[sec] = d
	return d


## Malha + colisão de uma seção (null se não tem superfície).
func build_section(sec: Vector3i, cols: Array, material: Material) -> Node3D:
	var d := data(sec, cols)
	var arrays_in: Array = backend.build_mesh(d, cols[2])
	var verts: PackedVector3Array = arrays_in[0]
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = arrays_in[1]
	arrays[Mesh.ARRAY_COLOR] = arrays_in[2]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := Node3D.new()
	node.name = "Sec_%d_%d_%d" % [sec.x, sec.y, sec.z]
	node.position = Vector3(sec) * SECTION
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	node.add_child(visual)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var faces := ConcavePolygonShape3D.new()
	faces.set_faces(verts)
	shape.shape = faces
	body.add_child(shape)
	node.add_child(body)
	add_child(node)
	_nodes[sec] = node
	return node


## Troca um pedaço do TerrainWorld (64 m) por voxels, de y_from a y_to (em seções).
## skip(sec) -> true pula a seção (para fotos em corte). Devolve {seções, triângulos, ms}.
func build_chunk(coord: Vector2i, y_from: int, y_to: int, skip := Callable()) -> Dictionary:
	var per := roundi(terrain.chunk_size / SECTION)
	var material: Material = terrain._material
	var made := 0
	var tris := 0
	var t0 := Time.get_ticks_msec()
	for j in per:
		for i in per:
			var sx := coord.x * per + i
			var sz := coord.y * per + j
			var cols := columns(sx, sz)
			for sy in range(y_from, y_to + 1):
				var sec := Vector3i(sx, sy, sz)
				if skip.is_valid() and skip.call(sec):
					continue
				var node := build_section(sec, cols, material)
				if node:
					made += 1
					tris += ((node.get_child(0) as MeshInstance3D).mesh as ArrayMesh).surface_get_array_len(0) / 3
	# Esconde o chão antigo desse pedaço (as plantas ficam).
	var chunk: Node3D = terrain._chunks.get(coord)
	if is_instance_valid(chunk):
		chunk.get_node("Ground").visible = false
		(chunk.get_node("Body/GroundShape") as CollisionShape3D).disabled = true
	return {"sections": made, "triangles": tris, "ms": Time.get_ticks_msec() - t0}
