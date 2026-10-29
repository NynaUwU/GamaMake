class_name MeshBuilder
extends RefCounted
## Gera malhas poligonais "estilo PlayStation 2" por código: poucos lados,
## sombreamento suave (não fica quadrado) mas com silhueta facetada (não fica
## liso). Use para tudo que NÃO é ser vivo (seres vivos são em blocos).
##
## Todas as funções somam triângulos; no fim chame finish() para gerar o Mesh.
## Cada vértice leva em CUSTOM0 a "distância" até as arestas do triângulo,
## para o shader ps2_facets desenhar as linhas dos polígonos (as diagonais
## internas dos quadrados ficam escondidas).

const FACET_SHADER := preload("res://shaders/ps2_facets.gdshader")

var _verts := PackedVector3Array()
var _colors := PackedColorArray()
var _edges := PackedFloat32Array() # 4 floats por vértice (RGBA)
var _color := Color.WHITE


func color(c: Color) -> MeshBuilder:
	_color = c
	return self


## smooth = normais suaves entre faces parecidas (até ~60°); false = arestas duras.
func finish(material: Material = null, smooth := true) -> ArrayMesh:
	var normals := PackedVector3Array()
	normals.resize(_verts.size())
	var face_normals := PackedVector3Array()
	for t in _verts.size() / 3:
		var a := _verts[t * 3]
		var n := (_verts[t * 3 + 2] - a).cross(_verts[t * 3 + 1] - a).normalized() # sentido horário
		face_normals.append(n)
	if smooth:
		# Agrupa vértices pela posição e soma as normais das faces vizinhas parecidas.
		var buckets := {}
		for i in _verts.size():
			var key := (_verts[i] * 10000.0).round()
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append(i)
		for key in buckets:
			var ids: Array = buckets[key]
			for i in ids:
				var own := face_normals[i / 3]
				var sum := Vector3.ZERO
				for j in ids:
					var other := face_normals[j / 3]
					if own.dot(other) > 0.5:
						sum += other
				normals[i] = sum.normalized() if sum.length() > 0.0001 else own
	else:
		for i in _verts.size():
			normals[i] = face_normals[i / 3]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_CUSTOM0] = _edges
	var mesh := ArrayMesh.new()
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	if material:
		mesh.surface_set_material(0, material)
	return mesh


## Material com o shader facetado (use em tudo que sai do MeshBuilder).
static func facet_material(albedo: Color, roughness := 0.6, metallic := 0.0, facet := 0.55,
		edge_darkness := 0.35) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FACET_SHADER
	material.set_shader_parameter("albedo", albedo)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("metallic", metallic)
	material.set_shader_parameter("facet", facet)
	material.set_shader_parameter("edge_darkness", edge_darkness)
	return material


## hide: componente 1 = esconde a aresta oposta àquele vértice (0=a, 1=b, 2=c).
func tri(a: Vector3, b: Vector3, c: Vector3, hide := Vector3.ZERO) -> void:
	# Sentido horário visto da frente = face visível no Godot.
	var points := [a, c, b]
	var ids := [0, 2, 1]
	for k in 3:
		var e := Vector3.ZERO
		e[ids[k]] = 1.0
		e = Vector3(maxf(e.x, hide.x), maxf(e.y, hide.y), maxf(e.z, hide.z))
		_verts.append(points[k])
		_colors.append(_color)
		_edges.append_array([e.x, e.y, e.z, 1.0])


## Quadrado: a diagonal a-c fica escondida (só as 4 bordas aparecem).
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	tri(a, b, c, Vector3(0, 1, 0))
	tri(a, c, d, Vector3(0, 0, 1))


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
		# Tampa em leque: só a borda externa aparece (raios escondidos).
		if flip:
			tri(center, b, a, Vector3(0, 1, 1))
		else:
			tri(center, a, b, Vector3(0, 1, 1))


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
