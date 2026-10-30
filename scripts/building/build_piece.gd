class_name BuildPiece
extends StaticBody3D
## Peça de construção (parede, piso, teto ou pilar) presa na grade do mundo.
##
## Parede, piso e teto têm 7x7 quadrados de SEG metros; cada quadrado são dois
## triângulos que a talhadeira remove um a um (buracos de janela, porta,
## alçapão...). A malha e a colisão são refeitas sem os triângulos removidos;
## as bordas dos buracos ganham laterais (dá para ver a espessura).
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
const TRIS := N * N * 2
const NAMES := {Kind.WALL: "Parede", Kind.FLOOR: "Piso", Kind.ROOF: "Teto", Kind.PILLAR: "Pilar"}
const COLORS := {Kind.WALL: Color(0.46, 0.33, 0.2), Kind.FLOOR: Color(0.4, 0.29, 0.18),
	Kind.ROOF: Color(0.45, 0.2, 0.15), Kind.PILLAR: Color(0.3, 0.2, 0.12)}

var kind := Kind.WALL
var cell := Vector3i.ZERO ## origem na grade (em quadrados)
var rot := 0 ## 0 = ao longo de +X; 1 = ao longo de +Z
var net_id := 0
var removed := PackedByteArray() ## 1 = triângulo tirado (índice: (j * N + i) * 2 + k)

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


## Triângulo da face atingida (ponto no mundo, normal da face). -1 = nenhum.
func triangle_at(world_point: Vector3, world_normal: Vector3) -> int:
	if not has_panel():
		return -1
	# Um pouco para dentro da peça: acertando a borda de um buraco, pega o triângulo certo.
	var local := to_local(world_point - world_normal * 0.02)
	var uv := _to_uv(local)
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= SIZE or uv.y >= SIZE:
		return -1
	var i := clampi(floori(uv.x / SEG), 0, N - 1)
	var j := clampi(floori(uv.y / SEG), 0, N - 1)
	var fu := uv.x / SEG - i
	var fv := uv.y / SEG - j
	var index := (j * N + i) * 2 + (0 if fv <= fu else 1)
	return index if removed[index] == 0 else -1


func remove_triangle(index: int) -> void:
	if index >= 0 and index < TRIS and removed[index] == 0:
		removed[index] = 1
		rebuild()


func is_empty() -> bool:
	return has_panel() and removed.count(1) == TRIS


## Os 3 cantos de um triângulo no plano da peça (u, v em metros).
static func triangle_uv(index: int) -> PackedVector2Array:
	var square := index / 2
	var i := square % N
	var j := square / N
	var o := Vector2(i, j) * SEG
	if index % 2 == 0:
		return PackedVector2Array([o, o + Vector2(SEG, 0), o + Vector2(SEG, SEG)])
	return PackedVector2Array([o, o + Vector2(SEG, SEG), o + Vector2(0, SEG)])


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


func _panel(st: SurfaceTool, faces: PackedVector3Array) -> void:
	var w := _w_range()
	var base: Color = COLORS[kind]
	for index in TRIS:
		if removed[index] == 1:
			continue
		var square := index / 2
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


## Vizinho do lado "edge" (0, 1, 2 = arestas c0-c1, c1-c2, c2-c0) ainda existe?
func _neighbor_present(index: int, edge: int) -> bool:
	var square := index / 2
	var i := square % N
	var j := square / N
	var k := index % 2
	var other := -1
	if k == 0: # (0,0) (1,0) (1,1): baixo, direita, diagonal
		match edge:
			0: other = _tri_index(i, j - 1, 1)
			1: other = _tri_index(i + 1, j, 1)
			2: other = index + 1
	else: # (0,0) (1,1) (0,1): diagonal, cima, esquerda
		match edge:
			0: other = index - 1
			1: other = _tri_index(i, j + 1, 0)
			2: other = _tri_index(i - 1, j, 0)
	return other >= 0 and removed[other] == 0


static func _tri_index(i: int, j: int, k: int) -> int:
	if i < 0 or j < 0 or i >= N or j >= N:
		return -1
	return (j * N + i) * 2 + k


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
