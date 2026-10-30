class_name BuildFill
extends StaticBody3D
## Janela ou porta encaixada num buraco feito pela talhadeira. Tem exatamente
## o formato do buraco (os triângulos tirados), então qualquer recorte vira
## janela/porta: quadrada, em L, em diamante...
##   janela: vidro no meio da espessura + moldura de madeira na borda do buraco.
##   porta:  folha de madeira com maçaneta; gira na dobradiça (lado esquerdo do
##           buraco). [E] abre/fecha.

var piece: BuildPiece
var fill_index := 0
var type := "window"
var open := false

static var _glass: StandardMaterial3D
static var _wood: StandardMaterial3D


func build(type_: String, tris: PackedInt32Array, open_: bool) -> void:
	type = type_
	open = open_
	collision_layer = 1
	collision_mask = 0
	if type == "door":
		add_to_group("interactable")
	var set := {}
	for index in tris:
		set[index] = true
	var hinge := 0.0
	if type == "door":
		hinge = INF
		for index in tris:
			for c in BuildPiece.triangle_uv(index):
				hinge = minf(hinge, c.x)
		position = piece.uvw(hinge, 0.0, 0.0) - piece.uvw(0.0, 0.0, 0.0)
		rotation.y = -1.75 if open else 0.0
	var origin := position
	var w := Vector2(-BuildPiece.THICK * 0.5, BuildPiece.THICK * 0.5) if piece.kind == BuildPiece.Kind.WALL \
			else Vector2(0.0, BuildPiece.THICK)
	var mid := (w.x + w.y) * 0.5
	var wood := MeshBuilder.new()
	var glass := MeshBuilder.new()
	var faces := PackedVector3Array()
	var max_u := -INF
	var max_v := -INF
	var pane := _door_pane(set) if type == "door" else {}
	for index in tris:
		var c := BuildPiece.triangle_uv(index)
		for p in c:
			max_u = maxf(max_u, p.x)
			max_v = maxf(max_v, p.y)
		if pane.has(index):
			# Vidraça da porta (na altura dos olhos), com moldurinha onde encosta na madeira.
			_tri(glass, faces, _p(c[0], mid + 0.01, origin), _p(c[1], mid + 0.01, origin), _p(c[2], mid + 0.01, origin), Color.WHITE)
			_tri(glass, faces, _p(c[0], mid - 0.01, origin), _p(c[2], mid - 0.01, origin), _p(c[1], mid - 0.01, origin), Color.WHITE)
			for e in 3:
				if not pane.has(piece._neighbor_index(index, e)):
					_window_frame(wood, faces, c[e], c[(e + 1) % 3], (c[0] + c[1] + c[2]) / 3.0, Vector2(mid - 0.05, mid + 0.05), origin, false)
			continue
		if type == "window":
			# Vidro fininho no meio.
			_tri(glass, faces, _p(c[0], mid + 0.015, origin), _p(c[1], mid + 0.015, origin), _p(c[2], mid + 0.015, origin), Color.WHITE)
			_tri(glass, faces, _p(c[0], mid - 0.015, origin), _p(c[2], mid - 0.015, origin), _p(c[1], mid - 0.015, origin), Color.WHITE)
		else:
			var shade := Color(0.36, 0.22, 0.12).darkened(0.08 * ((index / 4) / BuildPiece.N % 2))
			_tri(wood, faces, _p(c[0], mid + 0.05, origin), _p(c[1], mid + 0.05, origin), _p(c[2], mid + 0.05, origin), shade)
			_tri(wood, faces, _p(c[0], mid - 0.05, origin), _p(c[2], mid - 0.05, origin), _p(c[1], mid - 0.05, origin), shade)
		# Borda do buraco: moldura (janela) ou lateral da folha (porta).
		for e in 3:
			var other := piece._neighbor_index(index, e)
			if set.has(other) and not pane.has(other):
				continue
			var a: Vector2 = c[e]
			var b: Vector2 = c[(e + 1) % 3]
			var center := (c[0] + c[1] + c[2]) / 3.0
			if type == "window":
				_window_frame(wood, faces, a, b, center, w, origin)
			else:
				var side := Color(0.28, 0.17, 0.09)
				_tri(wood, faces, _p(a, mid - 0.05, origin), _p(b, mid - 0.05, origin), _p(b, mid + 0.05, origin), side)
				_tri(wood, faces, _p(a, mid - 0.05, origin), _p(b, mid + 0.05, origin), _p(a, mid + 0.05, origin), side)
	if type == "window":
		_muntins(wood, set, mid, origin)
	if type == "door":
		# Maçaneta de latão do lado oposto à dobradiça, a ~1 m do chão.
		var at := Vector2(max_u - 0.12, minf(1.0, max_v * 0.45))
		for side in [1.0, -1.0]:
			wood.color(Color(0.6, 0.48, 0.25))
			wood.box(_p(at, mid + side * 0.08, origin), Vector3(0.05, 0.05, 0.06))
	var wood_instance := MeshInstance3D.new()
	wood_instance.mesh = wood.finish(_wood_material(), false)
	add_child(wood_instance)
	var glass_instance := MeshInstance3D.new()
	glass_instance.mesh = glass.finish(_glass_material(), false)
	add_child(glass_instance)
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.backface_collision = true
	concave.set_faces(faces)
	shape.shape = concave
	add_child(shape)


## Moldura numa aresta da borda do buraco: batente (forra a espessura), guarnição
## saliente dos dois lados (um pouco por cima da parede e do vidro) e, na base
## de uma janela de parede, um peitoril saindo para fora.
func _window_frame(wood: MeshBuilder, faces: PackedVector3Array, a: Vector2, b: Vector2, center: Vector2, w: Vector2, origin: Vector3, sill := true) -> void:
	var lining := Color(0.42, 0.29, 0.17)
	var trim := Color(0.3, 0.2, 0.12)
	# Batente.
	_tri(wood, faces, _p(a, w.x, origin), _p(b, w.x, origin), _p(b, w.y, origin), lining)
	_tri(wood, faces, _p(a, w.x, origin), _p(b, w.y, origin), _p(a, w.y, origin), lining)
	# Guarnição: faixa de 0,05 para fora (sobre a parede) até 0,06 para dentro (sobre o vidro).
	var inward := (center - (a + b) * 0.5).normalized()
	var o0 := a - inward * 0.05
	var o1 := b - inward * 0.05
	var i0 := a + inward * 0.06
	var i1 := b + inward * 0.06
	for side in [-1.0, 1.0]:
		var face: float = w.y if side > 0.0 else w.x
		var top: float = face + side * 0.025
		_quad(wood, _p(o0, top, origin), _p(o1, top, origin), _p(i1, top, origin), _p(i0, top, origin), trim)
		_quad(wood, _p(o0, face, origin), _p(o1, face, origin), _p(o1, top, origin), _p(o0, top, origin), trim.darkened(0.2))
		_quad(wood, _p(i0, face, origin), _p(i1, face, origin), _p(i1, top, origin), _p(i0, top, origin), trim.darkened(0.2))
	# Peitoril: aresta horizontal com o vidro em cima (só em parede).
	if sill and piece.kind == BuildPiece.Kind.WALL and absf(a.y - b.y) < 0.001 and center.y > a.y:
		var left := minf(a.x, b.x) - 0.04
		var right := maxf(a.x, b.x) + 0.04
		var y := a.y
		var sill_color := Color(0.36, 0.24, 0.13)
		wood.color(sill_color)
		wood.box(_p(Vector2((left + right) * 0.5, y - 0.03), 0.0, origin), Vector3(right - left, 0.06, BuildPiece.THICK + 0.16))


## Vidraça da porta: um quadrado de largura no meio da porta, de 1,2 a 2,0 m
## (fileiras 3 e 4: os olhos ficam a 1,6 m). Só se esses quadrados estiverem
## inteiros na porta e sobrar madeira dos dois lados. Devolve os quartos dela.
func _door_pane(set: Dictionary) -> Dictionary:
	var n := BuildPiece.N
	var columns := {}
	for index in set:
		columns[(index / 4) % n] = true
	var cols: Array = columns.keys()
	cols.sort()
	if cols.size() < 3:
		return {}
	var middle: int = cols[cols.size() / 2]
	var pane := {}
	for j in [3, 4]:
		for q in 4:
			var index: int = (j * n + middle) * 4 + q
			if not set.has(index):
				return {}
			pane[index] = true
	return pane


## Frisos: travessas de madeira a cada 2 quadrados dividindo o vidro (só onde
## o buraco continua dos dois lados da linha).
func _muntins(wood: MeshBuilder, set: Dictionary, mid: float, origin: Vector3) -> void:
	var n := BuildPiece.N
	var seg := BuildPiece.SEG
	var bar := Color(0.3, 0.2, 0.12)
	wood.color(bar)
	for index in set:
		var square: int = index / 4
		var i: int = square % n
		var j: int = square / n
		var q: int = index % 4
		if q == 1 and (i + 1) % 2 == 0 and set.has(piece._neighbor_index(index, 0)):
			# Linha vertical em u = (i+1) * SEG, de v = j a j+1.
			var center := Vector2((i + 1) * seg, (j + 0.5) * seg)
			wood.box(_p(center, mid, origin), _size(0.035, seg + 0.035, 0.05))
		elif q == 2 and (j + 1) % 2 == 0 and set.has(piece._neighbor_index(index, 0)):
			var center := Vector2((i + 0.5) * seg, (j + 1) * seg)
			wood.box(_p(center, mid, origin), _size(seg + 0.035, 0.035, 0.05))


## Tamanho (u, v, w) -> espaço local da peça.
func _size(su: float, sv: float, sw: float) -> Vector3:
	return Vector3(su, sv, sw) if piece.kind == BuildPiece.Kind.WALL else Vector3(su, sw, sv)


func _quad(mb: MeshBuilder, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	mb.color(color)
	mb.tri(a, c, b)
	mb.tri(a, d, c)


func get_interact_text() -> String:
	return "[E] %s porta" % ("Fechar" if open else "Abrir")


func interact(_player: Node) -> void:
	var manager := piece.get_parent() as BuildingManager
	if manager:
		manager.request_door(piece, fill_index, not open)


## Ponto (u, v) na profundidade w, no espaço deste nó (a porta gira na dobradiça).
func _p(uv: Vector2, w: float, origin: Vector3) -> Vector3:
	return piece.uvw(uv.x, uv.y, w) - origin


func _tri(mb: MeshBuilder, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	mb.color(color)
	mb.tri(a, c, b)
	faces.append_array(PackedVector3Array([a, c, b]))


static func _glass_material() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.albedo_color = Color(0.6, 0.75, 0.8, 0.28)
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.roughness = 0.15
		_glass.metallic = 0.2
		_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _glass


static func _wood_material() -> StandardMaterial3D:
	if _wood == null:
		_wood = StandardMaterial3D.new()
		_wood.vertex_color_use_as_albedo = true
		_wood.roughness = 0.95
		_wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _wood
