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
##           inclinado (telhado, rot 2..5): o mesmo plano subindo 45° (sobe SIZE ao longo
##           de +Z local); rot 2 sobe para +Z do mundo, 3 para +X, 4 para -Z, 5 para -X
##   pilar:  x/z -0.2..0.2 (centrado no ponto da grade), y 0..SIZE
##           deitado (viga, rot 1 = ao longo de X, rot 2 = de Z): mesmo espaço local, girado

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
var rot := 0 ## 0 = ao longo de +X; 1 = ao longo de +Z (teto: 2..5 = inclinado)
var net_id := 0
var removed := PackedByteArray() ## 1 = quarto tirado (índice: (j * N + i) * 4 + q; q: 0 baixo, 1 direita, 2 cima, 3 esquerda)
## Janelas e portas encaixadas nos buracos: [{"type": "window"/"door", "tris": PackedInt32Array, "open": bool}]
var fills: Array = []
var damaged := {} ## quartos quebrados por zumbi (o martelo conserta; talhadeira não conta)
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


## Teto inclinado (telhado de 45°)?
static func is_slope(kind_: int, rot_: int) -> bool:
	return kind_ == Kind.ROOF and rot_ >= 2 and rot_ <= 5


## Sobe quanto por metro (telhado): 1 = 45°.
func slope() -> float:
	return 1.0 if is_slope(kind, rot) else 0.0


## Direção (no mundo) para onde o telhado sobe, pela rotação 2..5.
static func slope_dir(rot_: int) -> Vector3:
	return [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][clampi(rot_ - 2, 0, 3)]


static func piece_transform(kind_: Kind, cell_: Vector3i, rot_: int) -> Transform3D:
	if is_slope(kind_, rot_):
		# Gira em Y para o lado da subida e acerta a origem: a peça cobre o mesmo
		# quadrado da grade (cell .. cell + SIZE em x/z), com a borda de baixo na altura da grade.
		var basis := Basis(Vector3.UP, (rot_ - 2) * PI / 2.0)
		var low := Vector3(INF, 0, INF)
		for corner in [Vector3.ZERO, Vector3(SIZE, 0, 0), Vector3(0, 0, SIZE), Vector3(SIZE, 0, SIZE)]:
			var p: Vector3 = basis * corner
			low = Vector3(minf(low.x, p.x), 0, minf(low.z, p.z))
		return Transform3D(basis, Vector3(cell_) * SEG - low)
	if kind_ == Kind.PILLAR and rot_ > 0:
		# Pilar deitado (viga): ao longo de +X (rot 1) ou +Z (rot 2), com a base
		# na altura da grade (apoia em cima de parede, pilar ou piso).
		var lying := Basis(Vector3.BACK, -PI / 2) if rot_ == 1 else Basis(Vector3.RIGHT, PI / 2)
		return Transform3D(lying, Vector3(cell_) * SEG + Vector3.UP * SEG * 0.5)
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


## Os quartos que ainda existem do quadrado atingido e de "spread" vizinhos de
## cada lado na mesma fileira (zumbi quebrando: abre um buraco da largura dele).
func square_at(world_point: Vector3, world_normal: Vector3, spread := 0) -> PackedInt32Array:
	var result := PackedInt32Array()
	if not has_panel():
		return result
	var uv := _to_uv(to_local(world_point - world_normal * 0.02))
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= SIZE or uv.y >= SIZE:
		return result
	var i := clampi(floori(uv.x / SEG), 0, N - 1)
	var j := clampi(floori(uv.y / SEG), 0, N - 1)
	for k in range(maxi(i - spread, 0), mini(i + spread, N - 1) + 1):
		for q in 4:
			if removed[(j * N + k) * 4 + q] == 0:
				result.append((j * N + k) * 4 + q)
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
			return Vector3(u, w + v * slope(), v) # telhado inclinado: o plano sobe com v


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
	for index in TRIS:
		if removed[index] == 1:
			continue
		var square := index / 4
		var i := square % N
		var j := square / N
		var color := _tone(i, j)
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
	# Detalhes (sem colisão) só nos quadrados inteiros: cortou, o detalhe sai junto.
	for square in N * N:
		var q := square * 4
		if removed[q] == 1 or removed[q + 1] == 1 or removed[q + 2] == 1 or removed[q + 3] == 1:
			continue
		_square_details(st, square % N, square / N, w)


## Cor de cada quadrado: parede de tábuas deitadas, piso de tábuas com emendas
## desencontradas, teto de telhas em fiadas.
func _tone(i: int, j: int) -> Color:
	var base: Color = COLORS[kind]
	var noise := fposmod(sin(i * 3.7 + j * 12.9898 + cell.x * 3.1 + cell.z * 7.7 + cell.y * 1.3) * 43758.5453, 1.0)
	match kind:
		Kind.WALL:
			# Tábuas deitadas: cada fileira com um tom, quase sem variar no meio dela.
			var row := fposmod(sin(j * 12.9898 + cell.x * 3.1 + cell.z * 7.7) * 43758.5453, 1.0)
			return base.lightened(0.04).darkened(row * 0.16 + noise * 0.03)
		Kind.FLOOR:
			var board := fposmod(sin(j * 9.1 + floori((i + (j % 3)) / 3.0) * 4.3 + cell.x * 3.1 + cell.z * 7.7) * 43758.5453, 1.0)
			return base.darkened(board * 0.12 + noise * 0.02)
		Kind.ROOF:
			var tile := (i + (j % 2)) % 2
			return base.darkened(0.06 * tile + noise * 0.1 + (0.08 if j % 2 == 1 else 0.0))
	return base


## Frestas entre as tábuas, pregos nos caibros, beiral das telhas.
func _square_details(st: SurfaceTool, i: int, j: int, w: Vector2) -> void:
	var u0 := i * SEG
	var v0 := j * SEG
	var seam: Color = (COLORS[kind] as Color).darkened(0.55)
	var nail := Color(0.28, 0.27, 0.26)
	match kind:
		Kind.WALL:
			for face in [w.x - 0.003, w.y + 0.003]:
				if j > 0:
					_box(st, uvw(u0 + SEG * 0.5, v0 + 0.006, face), Vector3(SEG, 0.012, 0.006), seam) # fresta entre tábuas
				_box(st, uvw(u0 + SEG * 0.5, v0 + SEG * 0.5, face), Vector3(SEG, 0.008, 0.005), seam.lightened(0.15)) # meia tábua
				if i % 3 == 0:
					for k in 2:
						_box(st, uvw(u0 + 0.06, v0 + SEG * (0.25 + 0.5 * k), face), Vector3(0.022, 0.022, 0.012), nail) # pregos
		Kind.FLOOR:
			var top := w.y + 0.003
			_box(st, uvw(u0 + SEG * 0.5, v0 + 0.006, top), Vector3(SEG, 0.006, 0.012), seam) # fresta (ao longo de x)
			if (i + (j % 3)) % 3 == 0:
				_box(st, uvw(u0 + 0.006, v0 + SEG * 0.5, top), Vector3(0.012, 0.006, SEG), seam) # emenda da tábua
			if i % 3 == 0:
				for k in 2:
					_box(st, uvw(u0 + 0.05, v0 + SEG * (0.28 + 0.44 * k), top), Vector3(0.022, 0.01, 0.022), nail)
		Kind.ROOF:
			var top := w.y
			# Beiral de cada fiada: degrau de telha sobreposta na borda de baixo do quadrado.
			_box(st, uvw(u0 + SEG * 0.5, v0 + 0.04, top + 0.02), Vector3(SEG - 0.01, 0.04, 0.08), _tone(i, j).darkened(0.15))
			_box(st, uvw(u0 + 0.005, v0 + SEG * 0.5, top + 0.01), Vector3(0.01, 0.02, SEG), _tone(i, j).darkened(0.3)) # junta


## Caixa de enfeite (só na malha, sem colisão), em espaço local da peça.
func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var junk := PackedVector3Array()
	var h := size * 0.5
	var p := [center + Vector3(-h.x, -h.y, -h.z), center + Vector3(h.x, -h.y, -h.z), center + Vector3(h.x, h.y, -h.z), center + Vector3(-h.x, h.y, -h.z),
		center + Vector3(-h.x, -h.y, h.z), center + Vector3(h.x, -h.y, h.z), center + Vector3(h.x, h.y, h.z), center + Vector3(-h.x, h.y, h.z)]
	for f in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		_tri(st, junk, p[f[0]], p[f[2]], p[f[1]], color)
		_tri(st, junk, p[f[0]], p[f[3]], p[f[2]], color)


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
	var wa := a.z if kind == Kind.WALL else a.y + (THICK if kind == Kind.FLOOR else 0.0) - a.z * slope()
	var wb := b.z if kind == Kind.WALL else b.y + (THICK if kind == Kind.FLOOR else 0.0) - b.z * slope()
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
			Sfx.play_at("creak", node.global_position + node.global_basis * Vector3(0.4, 1.0, 0), 0.0, 1.1 if open else 0.9)
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
	# Colisão: o prisma simples de 0,4 m. Desenho uniforme de ponta a ponta (viga de
	# madeira de cantos chanfrados com cintas de ferro), para emendar bem deitado.
	var h := SEG * 0.5
	var corners := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	for e in 4:
		var a: Vector3 = corners[e]
		var b: Vector3 = corners[(e + 1) % 4]
		var top := Vector3.UP * SIZE
		faces.append_array(PackedVector3Array([a, b + top, b, a, a + top, b + top]))
	var wood: Color = COLORS[kind]
	_box(st, Vector3(0, SIZE * 0.5, 0), Vector3(0.34, SIZE, 0.34), wood)
	for k in 4: # chanfros (cantos mais escuros), inteiros de ponta a ponta
		var a := TAU * k / 4.0 + PI / 4.0
		_box(st, Vector3(cos(a) * 0.17, SIZE * 0.5, sin(a) * 0.17), Vector3(0.06, SIZE, 0.06), wood.darkened(0.12))
	for y in [0.35, SIZE * 0.5, SIZE - 0.35]:
		_box(st, Vector3(0, y, 0), Vector3(0.37, 0.06, 0.37), Color(0.24, 0.23, 0.23)) # cinta de ferro
		for k in 4:
			var a := TAU * k / 4.0
			_box(st, Vector3(cos(a) * 0.186, y, sin(a) * 0.186), Vector3(0.025, 0.025, 0.025), Color(0.62, 0.5, 0.26))


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
