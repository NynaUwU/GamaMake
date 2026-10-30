class_name BuildPiece
extends StaticBody3D
## Peça de construção (parede, piso, teto ou pilar) presa na grade do mundo.
##
## Parede, piso e teto têm 7x7 quadrados de SEG metros. Cada quadrado é cortado
## pelas DUAS diagonais em 4 triângulos de quarto (baixo, direita, cima,
## esquerda): assim a talhadeira tira meio quadrado em qualquer diagonal ("/"
## = baixo+direita ou cima+esquerda; "\\" = baixo+esquerda ou cima+direita).
## A malha e a colisão são refeitas sem as partes removidas; as bordas dos
## buracos ganham laterais (dá para ver a espessura).
##
## Espaço local:
##   parede: x 0..SIZE (comprimento), y 0..SIZE (altura), z -T/2..T/2
##   piso:   x/z 0..SIZE, y -T..0 (o topo fica na altura da grade: pisa-se em cima)
##   teto:   x/z 0..SIZE, y 0..T (a base fica na altura da grade: apoia no topo das paredes)
##   pilar:  x/z -0.2..0.2 (centrado no ponto da grade), y 0..SIZE

enum Kind { WALL, FLOOR, ROOF, PILLAR }

const SEG := 0.4 ## tamanho de cada quadrado = passo da grade do mundo
const N := 7 ## quadrados por lado
const SIZE := SEG * N
const THICK := 0.2
const TRIS := N * N * 4 ## partes removíveis (4 quartos por quadrado)
const NAMES := {Kind.WALL: "Parede", Kind.FLOOR: "Piso", Kind.ROOF: "Teto", Kind.PILLAR: "Pilar"}
const COLORS := {Kind.WALL: Color(0.46, 0.33, 0.2), Kind.FLOOR: Color(0.4, 0.29, 0.18),
	Kind.ROOF: Color(0.45, 0.2, 0.15), Kind.PILLAR: Color(0.3, 0.2, 0.12)}

var kind := Kind.WALL
var cell := Vector3i.ZERO ## origem na grade (em quadrados)
var rot := 0 ## 0 = ao longo de +X; 1 = ao longo de +Z
var net_id := 0
var removed := PackedByteArray() ## 1 = quarto tirado (índice: (j * N + i) * 4 + q; q: 0 baixo, 1 direita, 2 cima, 3 esquerda)
## Janelas e portas encaixadas nos buracos: [{"type": "window"/"door", "tris": PackedInt32Array, "open": bool}]
var fills: Array = []
var _fill_nodes: Array = []

var _mesh: MeshInstance3D
var _shape: CollisionShape3D
static var _material: StandardMaterial3D


func setup(kind_: Kind, cell_: Vector3i, rot_: int) -> void:
	kind = kind_
	cell = cell_
	rot = rot_
	removed.resize(TRIS)
	transform = piece_transform(kind, cell, rot)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("build_piece")
	if removed.size() != TRIS:
		removed.resize(TRIS)
	_mesh = MeshInstance3D.new()
	add_child(_mesh)
	_shape = CollisionShape3D.new()
	add_child(_shape)
	rebuild()


static func piece_transform(kind_: Kind, cell_: Vector3i, rot_: int) -> Transform3D:
	var basis := Basis(Vector3.UP, -PI / 2) if rot_ == 1 else Basis.IDENTITY
	return Transform3D(basis, Vector3(cell_) * SEG)


func has_panel() -> bool:
	return kind != Kind.PILLAR


## Meio quadrado da face atingida, na diagonal "diag" ("/" ou "\\"): os quartos
## que ainda existem dele (vazio = nada para tirar ali).
func half_at(world_point: Vector3, world_normal: Vector3, diag: String) -> PackedInt32Array:
	if not has_panel():
		return PackedInt32Array()
	# Um pouco para dentro da peça: acertando a borda de um buraco, pega a parte certa.
	var uv := _to_uv(to_local(world_point - world_normal * 0.02))
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= SIZE or uv.y >= SIZE:
		return PackedInt32Array()
	var i := clampi(floori(uv.x / SEG), 0, N - 1)
	var j := clampi(floori(uv.y / SEG), 0, N - 1)
	var result := PackedInt32Array()
	for q in half_quarters(uv.x / SEG - i, uv.y / SEG - j, diag):
		var index: int = (j * N + i) * 4 + q
		if removed[index] == 0:
			result.append(index)
	return result


## Quais quartos formam o meio quadrado que contém o ponto (fu, fv em 0..1).
static func half_quarters(fu: float, fv: float, diag: String) -> Array:
	if diag == "/":
		return [0, 1] if fv <= fu else [2, 3]
	return [0, 3] if fu + fv <= 1.0 else [1, 2]


## Quarto do quadrado que contém o ponto (fu, fv em 0..1).
static func quarter_at(fu: float, fv: float) -> int:
	var dx := fu - 0.5
	var dy := fv - 0.5
	if absf(dy) >= absf(dx):
		return 0 if dy < 0.0 else 2
	return 1 if dx > 0.0 else 3


func remove_triangle(index: int) -> void:
	if index >= 0 and index < TRIS and removed[index] == 0:
		removed[index] = 1
		rebuild()


func is_empty() -> bool:
	return has_panel() and removed.count(1) == TRIS


const _QUARTER_CORNERS := [[Vector2(0, 0), Vector2(1, 0)], [Vector2(1, 0), Vector2(1, 1)],
	[Vector2(1, 1), Vector2(0, 1)], [Vector2(0, 1), Vector2(0, 0)]]

## Os 3 cantos de um quarto no plano da peça (u, v em metros): aresta de fora
## do quadrado (c0-c1) e o centro do quadrado (c2).
static func triangle_uv(index: int) -> PackedVector2Array:
	var square := index / 4
	var o := Vector2(square % N, square / N) * SEG
	var corners: Array = _QUARTER_CORNERS[index % 4]
	return PackedVector2Array([o + corners[0] * SEG, o + corners[1] * SEG, o + Vector2(0.5, 0.5) * SEG])


## Plano da peça (u, v) + espessura (w) -> espaço local.
func uvw(u: float, v: float, w: float) -> Vector3:
	match kind:
		Kind.WALL:
			return Vector3(u, v, w)
		Kind.FLOOR:
			return Vector3(u, w - THICK, v)
		_:
			return Vector3(u, w, v)


func _to_uv(local: Vector3) -> Vector2:
	return Vector2(local.x, local.y) if kind == Kind.WALL else Vector2(local.x, local.z)


func _w_range() -> Vector2:
	return Vector2(-THICK * 0.5, THICK * 0.5) if kind == Kind.WALL else Vector2(0.0, THICK)


func rebuild() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1) # normais retas: sem isso o topo "borrava" com as laterais (faixas escuras)
	var faces := PackedVector3Array()
	if kind == Kind.PILLAR:
		_pillar(st, faces)
	else:
		_panel(st, faces)
	st.generate_normals()
	_mesh.mesh = st.commit()
	_mesh.material_override = _get_material()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	_shape.shape = shape
	_shape.disabled = faces.is_empty()
	_rebuild_fills()


func _panel(st: SurfaceTool, faces: PackedVector3Array) -> void:
	var w := _w_range()
	var base: Color = COLORS[kind]
	for index in TRIS:
		if removed[index] == 1:
			continue
		var square := index / 4
		var i := square % N
		var j := square / N
		# Tábuas: cada fileira com um tom (parede = fileiras na altura; piso/teto = ao longo de x).
		var row := j if kind == Kind.WALL else i
		var color := base.darkened(fposmod(sin(row * 12.9898 + cell.x * 3.1 + cell.z * 7.7) * 43758.5453, 1.0) * 0.18)
		var c := triangle_uv(index)
		# Frente e verso.
		_tri(st, faces, uvw(c[0].x, c[0].y, w.y), uvw(c[1].x, c[1].y, w.y), uvw(c[2].x, c[2].y, w.y), color)
		_tri(st, faces, uvw(c[0].x, c[0].y, w.x), uvw(c[2].x, c[2].y, w.x), uvw(c[1].x, c[1].y, w.x), color)
		# Laterais só onde o vizinho foi tirado (ou é a borda da peça).
		for e in 3:
			if _neighbor_present(index, e):
				continue
			var a := c[e]
			var b := c[(e + 1) % 3]
			var side := color.darkened(0.25)
			_tri(st, faces, uvw(a.x, a.y, w.x), uvw(b.x, b.y, w.x), uvw(b.x, b.y, w.y), side)
			_tri(st, faces, uvw(a.x, a.y, w.x), uvw(b.x, b.y, w.y), uvw(a.x, a.y, w.y), side)


## Vizinho do lado "edge" (0 = aresta de fora do quadrado, 1 e 2 = diagonais) ainda existe?
func _neighbor_present(index: int, edge: int) -> bool:
	var other := _neighbor_index(index, edge)
	return other >= 0 and removed[other] == 0


# --- Buracos, janelas e portas ------------------------------------------------

## Onde o raio cruza o meio da peça: triângulo nesse ponto (tirado ou não) e
## distância. Serve para mirar buracos (que não têm colisão).
func ray_to_panel(from: Vector3, to: Vector3) -> Dictionary:
	if not has_panel():
		return {}
	var a := to_local(from)
	var b := to_local(to)
	var mid := (_w_range().x + _w_range().y) * 0.5
	var wa := a.z if kind == Kind.WALL else a.y + (THICK if kind == Kind.FLOOR else 0.0)
	var wb := b.z if kind == Kind.WALL else b.y + (THICK if kind == Kind.FLOOR else 0.0)
	if is_equal_approx(wa, wb) or (wa - mid) * (wb - mid) > 0.0:
		return {}
	var t := (mid - wa) / (wb - wa)
	var uv := _to_uv(a.lerp(b, t))
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= SIZE or uv.y >= SIZE:
		return {}
	var i := floori(uv.x / SEG)
	var j := floori(uv.y / SEG)
	var index := (j * N + i) * 4 + quarter_at(uv.x / SEG - i, uv.y / SEG - j)
	return {"triangle": index, "t": t, "square": Vector2i(i, j), "frac": Vector2(uv.x / SEG - i, uv.y / SEG - j)}


## Buraco ligado ao triângulo (tirados vizinhos que ainda não têm janela/porta).
func hole_at(index: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if index < 0 or removed[index] == 0 or filled(index):
		return result
	var seen := {index: true}
	var stack := [index]
	while not stack.is_empty():
		var current: int = stack.pop_back()
		result.append(current)
		for edge in 3:
			var other := _neighbor_index(current, edge)
			if other >= 0 and not seen.has(other) and removed[other] == 1 and not filled(other):
				seen[other] = true
				stack.append(other)
	return result


func filled(index: int) -> bool:
	for fill in fills:
		if index in fill.tris:
			return true
	return false


## Porta: o buraco precisa encostar na base da parede (fileira de baixo).
static func touches_bottom(tris: PackedInt32Array) -> bool:
	for index in tris:
		if index % 4 == 0 and index / 4 < N: # quarto de baixo da 1ª fileira
			return true
	return false


func add_fill(type: String, tris: PackedInt32Array, open := false) -> void:
	fills.append({"type": type, "tris": tris, "open": open})
	_rebuild_fills()


func remove_fill(index: int) -> void:
	if index >= 0 and index < fills.size():
		fills.remove_at(index)
		_rebuild_fills()


func set_door_open(index: int, open: bool) -> void:
	if index >= 0 and index < fills.size():
		fills[index].open = open
		var node: BuildFill = _fill_nodes[index] if index < _fill_nodes.size() else null
		if node:
			node.open = open
			var tween := node.create_tween()
			tween.tween_property(node, "rotation:y", -1.75 if open else 0.0, 0.35).set_trans(Tween.TRANS_SINE)


func _rebuild_fills() -> void:
	for node in _fill_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_fill_nodes.clear()
	for index in fills.size():
		var fill: Dictionary = fills[index]
		var node := BuildFill.new()
		node.piece = self
		node.fill_index = index
		add_child(node)
		node.build(fill.type, fill.tris, fill.open)
		_fill_nodes.append(node)


## Parte do outro lado da aresta "edge" (-1 = borda da peça).
## Aresta 0: lado de fora do quadrado -> quarto oposto do quadrado vizinho.
## Arestas 1 e 2: diagonais -> quartos vizinhos no mesmo quadrado.
func _neighbor_index(index: int, edge: int) -> int:
	var square := index / 4
	var q := index % 4
	match edge:
		1:
			return square * 4 + (q + 1) % 4
		2:
			return square * 4 + (q + 3) % 4
	var i := square % N
	var j := square / N
	match q:
		0: return _part_index(i, j - 1, 2)
		1: return _part_index(i + 1, j, 3)
		2: return _part_index(i, j + 1, 0)
		_: return _part_index(i - 1, j, 1)


static func _part_index(i: int, j: int, q: int) -> int:
	if i < 0 or j < 0 or i >= N or j >= N:
		return -1
	return (j * N + i) * 4 + q


func _pillar(st: SurfaceTool, faces: PackedVector3Array) -> void:
	var h := SEG * 0.5
	var corners := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	var color: Color = COLORS[kind]
	for e in 4:
		var a: Vector3 = corners[e]
		var b: Vector3 = corners[(e + 1) % 4]
		var top := Vector3.UP * SIZE
		_tri(st, faces, a, b, b + top, color.darkened(0.08 * e))
		_tri(st, faces, a, b + top, a + top, color.darkened(0.08 * e))
	_tri(st, faces, corners[0] + Vector3.UP * SIZE, corners[1] + Vector3.UP * SIZE, corners[2] + Vector3.UP * SIZE, color)
	_tri(st, faces, corners[0] + Vector3.UP * SIZE, corners[2] + Vector3.UP * SIZE, corners[3] + Vector3.UP * SIZE, color)


func _tri(st: SurfaceTool, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for p in [a, c, b]: # sentido horário visto de fora = frente no Godot
		st.set_color(color)
		st.add_vertex(p)
	faces.append_array(PackedVector3Array([a, c, b]))


static func _get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.95
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED # buracos: dá para ver por dentro
	return _material
