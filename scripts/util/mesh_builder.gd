class_name MeshBuilder
extends RefCounted
## Gera malhas poligonais "estilo PlayStation 2" por código: poucos lados,
## sombreamento suave (não fica quadrado) mas com silhueta facetada (não fica
## liso). Use para tudo que NÃO é ser vivo (seres vivos são em blocos).
##
## Todas as funções somam triângulos num SurfaceTool já começado; no fim,
## chame finish() para gerar normais e o Mesh.

var st := SurfaceTool.new()
var _color := Color.WHITE


func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


func color(c: Color) -> MeshBuilder:
	_color = c
	return self


## smooth = normais suaves (carroceria, pneus). false = arestas duras (peças mecânicas).
func finish(material: Material = null, smooth := true) -> ArrayMesh:
	var mesh: ArrayMesh
	if smooth:
		st.index()
		st.generate_normals()
		mesh = st.commit()
	else:
		mesh = _flat_mesh()
	if material and mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, material)
	return mesh


## Arestas duras de verdade: uma normal por triângulo. (O generate_normals do
## SurfaceTool suaviza vértices na mesma posição mesmo sem índice, o que
## deixava "faixas" escuras nas bordas.)
func _flat_mesh() -> ArrayMesh:
	var arrays := st.commit_to_arrays()
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
		return ArrayMesh.new() # nada desenhado (ex.: porta estreita sem vidraça)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in range(0, verts.size() - 2, 3):
		var n := (verts[i + 2] - verts[i]).cross(verts[i + 1] - verts[i]).normalized()
		normals[i] = n
		normals[i + 1] = n
		normals[i + 2] = n
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func tri(a: Vector3, b: Vector3, c: Vector3) -> void:
	# Sentido horário visto da frente = face visível no Godot.
	for v in [a, c, b]:
		st.set_color(_color)
		st.add_vertex(v)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	tri(a, b, c)
	tri(a, c, d)


## Anel de seção "superelipse" (n=2 elipse, n maior = mais quadrado arredondado).
static func ring(center: Vector3, half_width: float, half_height: float, n: float, segments: int,
		floor_y := -INF, start := 0.0, end := TAU) -> PackedVector3Array:
	var points := PackedVector3Array()
	var closed := is_equal_approx(end - start, TAU)
	var count := segments if closed else segments + 1
	for i in count:
		var a := lerpf(start, end, float(i) / segments)
		var c := cos(a)
		var s := sin(a)
		var x := half_width * signf(c) * pow(absf(c), 2.0 / n)
		var y := half_height * signf(s) * pow(absf(s), 2.0 / n)
		points.append(Vector3(center.x + x, maxf(center.y + y, floor_y), center.z))
	return points


## Liga anéis consecutivos (todos com o mesmo número de pontos).
## closed = anel fechado (tubo); caps = tampa as pontas.
## flip = inverte o lado da face (quando os anéis giram ao contrário).
func loft(rings: Array, closed := true, caps := false, flip := false) -> void:
	for r in rings.size() - 1:
		var a: PackedVector3Array = rings[r]
		var b: PackedVector3Array = rings[r + 1]
		var n := a.size()
		var edges := n if closed else n - 1
		for i in edges:
			var j := (i + 1) % n
			if flip:
				quad(a[i], b[i], b[j], a[j])
			else:
				quad(a[i], a[j], b[j], b[i])
	if caps:
		_cap(rings[0], true)
		_cap(rings[rings.size() - 1], false)


func _cap(points: PackedVector3Array, flip: bool) -> void:
	var center := Vector3.ZERO
	for p in points:
		center += p
	center /= points.size()
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		if flip:
			tri(center, b, a)
		else:
			tri(center, a, b)


## Sólido de revolução em volta do eixo local (profile = [raio, altura]).
func lathe(profile: PackedVector2Array, segments: int, basis := Basis.IDENTITY, origin := Vector3.ZERO) -> void:
	var rings := []
	for p in profile:
		var points := PackedVector3Array()
		for i in segments:
			var a := TAU * i / segments
			points.append(origin + basis * Vector3(cos(a) * p.x, p.y, sin(a) * p.x))
		rings.append(points)
	loft(rings, true, false, true)


func torus(major: float, minor: float, seg_major: int, seg_minor: int, basis := Basis.IDENTITY, origin := Vector3.ZERO) -> void:
	var rings := []
	for i in seg_major + 1:
		var a := TAU * i / seg_major
		var center := Vector3(cos(a) * major, 0, sin(a) * major)
		var out := Vector3(cos(a), 0, sin(a))
		var points := PackedVector3Array()
		for k in seg_minor:
			var b := TAU * k / seg_minor
			points.append(origin + basis * (center + out * cos(b) * minor + Vector3.UP * sin(b) * minor))
		rings.append(points)
	loft(rings, true, false)


## Tubo seguindo uma linha (cano, eixo, raio de roda, moldura).
func tube(path: PackedVector3Array, radius: float, segments := 6, caps := true) -> void:
	var rings := []
	for i in path.size():
		var forward := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side := forward.cross(Vector3.UP)
		if side.length() < 0.01:
			side = forward.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(forward)
		var points := PackedVector3Array()
		for k in segments:
			var a := TAU * k / segments
			points.append(path[i] + (side * cos(a) + up * sin(a)) * radius)
		rings.append(points)
	loft(rings, true, false, true)
	if caps:
		_cap(rings[0], false)
		_cap(rings[rings.size() - 1], true)


## Placa curva (para-lama, para-brisa): grade de pontos [linha][coluna].
func sheet(grid: Array) -> void:
	for r in grid.size() - 1:
		var a: PackedVector3Array = grid[r]
		var b: PackedVector3Array = grid[r + 1]
		for i in a.size() - 1:
			quad(a[i], a[i + 1], b[i + 1], b[i])


## Polígono 2D (no plano XY) extrudado em Z: frente em +Z.
func extrude(shape: PackedVector2Array, depth: float, basis := Basis.IDENTITY, origin := Vector3.ZERO) -> void:
	var front := PackedVector3Array()
	var back := PackedVector3Array()
	for p in shape:
		front.append(origin + basis * Vector3(p.x, p.y, depth * 0.5))
		back.append(origin + basis * Vector3(p.x, p.y, -depth * 0.5))
	loft([back, front], true, true)


## Caixa com quinas chanfradas (peças mecânicas simples).
func box(center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var c := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	for i in c.size():
		c[i] = center + basis * c[i]
	for face in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		quad(c[face[0]], c[face[3]], c[face[2]], c[face[1]])
