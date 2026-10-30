class_name RaceTrack
extends Node
## Autódromo no deserto inspirado na "The Motor Raceway" (FlatOut 2). Todos os
## trechos ficam abertos ao mesmo tempo (nada de barreira mudando o circuito):
##
## - Oval com as curvas inclinadas (as pontas de fora mais altas) e uma
##   lombada na reta oposta que faz o carro voar a partir de ~85 km/h.
## - Misto no meio: desce num valeta, sobe o morro do infield, grampo lá em
##   cima, desce em S e volta para o oval.
## - Cruzamento pelo meio, num rebaixo de barrancos suaves; o misto passa por cima numa ponte.
## - Atalhos de terra: um corta a curva 1 por dentro (rampa sobre uma valeta),
##   outro sai do grampo e pula por cima do rebaixo do cruzamento.
##
## O traçado é 3D: cada ponto tem altura, e o relevo do terreno é moldado pela
## pista (surface()). Este nó constrói muretas, ponte, rampas, pneus,
## arquibancada e a largada quando o player chega perto.

const HALF := Vector2(330.0, 140.0) ## meia área ocupada (local: u = comprimento, v = largura)
const OVAL_STRAIGHT := 180.0 ## meia reta
const OVAL_RADIUS := 85.0
const OVAL_WIDTH := 18.0
const INFIELD_WIDTH := 13.0
const CROSS_WIDTH := 12.0
const DIRT_WIDTH := 9.0
const CROSS_FALLOFF := 11.0 ## barrancos suaves do rebaixo do cruzamento (a ponte cobre o vão)
const BANK := 0.18 ## inclinação das curvas do oval (~10°)
const HILL_CENTER := Vector2(-5.0, 35.0) ## morro do infield
const HILL_HEIGHT := 8.0
const HILL_RADIUS := 62.0

## Misto (u, v, altura).
const INFIELD := [Vector3(-200, 85, 0), Vector3(-186, 58, 0), Vector3(-160, 28, -1.5), Vector3(-122, 12, 0.5),
	Vector3(-82, 30, 4.5), Vector3(-42, 50, 7.8), Vector3(0, 52, 8.6), Vector3(28, 44, 8.6), Vector3(38, 28, 8.2),
	Vector3(20, 14, 7.2), Vector3(4, 4, 6.2), Vector3(-4, -10, 5.0), Vector3(-14, -28, 3.0), Vector3(-18, -42, 1.2),
	Vector3(12, -50, 0.2), Vector3(62, -30, 0.0), Vector3(100, -12, 0.6), Vector3(138, -32, 0.0), Vector3(160, -62, 0.0),
	Vector3(168, -85, 0.0)]
## Cruzamento de uma curva à outra, rebaixado por baixo do morro.
const CROSS := [Vector3(-254, 0, -1.4), Vector3(-200, 4, -0.5), Vector3(-120, -4, 0.0), Vector3(-24, 0, 0.0),
	Vector3(60, 2, 0.0), Vector3(150, -4, 0.0), Vector3(205, 0, -0.5), Vector3(254, 0, -1.4)]
## Atalhos de terra.
const SHORTCUT_TURN := [Vector3(172, 78, 0), Vector3(196, 46, 0.3), Vector3(206, 14, 0.0), Vector3(207, -6, -1.8),
	Vector3(204, -26, 0.0), Vector3(196, -48, 0.3), Vector3(172, -78, 0)]
const SHORTCUT_JUMP := [Vector3(38, 28, 8.2), Vector3(44, 24, 7.9), Vector3(47, 19, 7.4), Vector3(49, -12, 0.3),
	Vector3(52, -22, 0.2), Vector3(62, -30, 0.0)]
## Rampas de madeira: [posição local, direção (u, v), comprimento, altura da ponta].
const RAMPS := [[Vector2(206.0, 16.0), Vector2(0.03, -1.0), 7.0, 1.4], [Vector2(46.8, 22.0), Vector2(0.08, -1.0), 7.0, 1.6]]

@export var terrain_path: NodePath
@export var player_path: NodePath

var _terrain: TerrainWorld
var _player: Node3D
var _built: Node3D
var _timer := 0.0


## Escolhe um lugar plano no deserto e devolve {center, yaw, base, paths, segments}.
static func plan(world: TerrainWorld) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed * 17 + 3
	var half_world := world.world_size * 0.5 - 380.0
	for attempt in 1500:
		var center := Vector2(rng.randf_range(-half_world, half_world), rng.randf_range(-half_world, half_world))
		var yaw := rng.randf() * PI
		var ok := true
		for city in world.cities:
			if center.distance_to(city.center) < city.radius + HALF.x + 60.0:
				ok = false
				break
		if not ok or center.length() < 500.0:
			continue
		var heights := []
		for i in 9:
			var local := Vector2(lerpf(-HALF.x, HALF.x, (i % 3) / 2.0), lerpf(-HALF.y, HALF.y, floorf(i / 3.0) / 2.0))
			var p := center + local.rotated(yaw)
			var biome := world.biome_at(p.x, p.y)
			if biome.desert < 0.5 or biome.mountain > 0.2:
				ok = false
				break
			heights.append(world.raw_height(p.x, p.y, biome))
		if not ok or heights.max() - heights.min() > 26.0:
			continue
		var total := 0.0
		for h in heights:
			total += h
		var info := {"center": center, "yaw": yaw, "base": total / heights.size()}
		info["paths"] = _paths()
		info["segments"] = _segments(info)
		info["grid"] = _grid(info.paths)
		return info
	return {}


## Traçados locais. Cada um: pontos (u, v, altura), largura, "falloff" (quanto
## o terreno em volta leva para voltar ao normal), tipo de chão e prioridade
## (a ordem importa: o último manda onde se cruzam).
static func _paths() -> Array:
	var oval := PackedVector3Array()
	for side in [1.0, -1.0]:
		for k in 25:
			var a := lerpf(-PI * 0.5, PI * 0.5, k / 24.0)
			var u: float = side * (OVAL_STRAIGHT + cos(a) * OVAL_RADIUS)
			var v: float = side * sin(a) * OVAL_RADIUS
			oval.append(Vector3(u, v, 0.0))
		# Reta oposta (v < 0, depois da segunda curva): pontos extras para a lombada.
		if side < 0.0:
			for k in 25:
				var u := lerpf(-OVAL_STRAIGHT + 8.0, OVAL_STRAIGHT - 8.0, k / 24.0)
				oval.append(Vector3(u, -OVAL_RADIUS, _crest(u)))
	oval.append(oval[0])
	return [
		{"points": _smooth(INFIELD), "width": INFIELD_WIDTH, "falloff": 14.0, "kind": "asphalt", "name": "infield"},
		{"points": _smooth(SHORTCUT_TURN), "width": DIRT_WIDTH, "falloff": 10.0, "kind": "dirt", "name": "shortcut_turn"},
		{"points": _smooth(SHORTCUT_JUMP), "width": DIRT_WIDTH, "falloff": 8.0, "kind": "dirt", "name": "shortcut_jump"},
		{"points": oval, "width": OVAL_WIDTH, "falloff": 16.0, "kind": "asphalt", "name": "oval", "banked": true},
		{"points": _smooth(CROSS), "width": CROSS_WIDTH, "falloff": CROSS_FALLOFF, "kind": "asphalt", "name": "cross"},
	]


## Lombada da reta oposta: sobe 6 m em 40 m e desce de novo (dá salto).
static func _crest(u: float) -> float:
	var x := u + 20.0
	if absf(x) > 40.0:
		return 0.0
	return 6.0 * pow(cos(x / 40.0 * PI * 0.5), 2.0)


## Catmull-Rom: arredonda as curvas (posição e altura), um ponto a cada ~6 m.
static func _smooth(points: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in points.size() - 1:
		var p0: Vector3 = points[maxi(i - 1, 0)]
		var p1: Vector3 = points[i]
		var p2: Vector3 = points[i + 1]
		var p3: Vector3 = points[mini(i + 2, points.size() - 1)]
		var steps := maxi(int(Vector2(p1.x, p1.y).distance_to(Vector2(p2.x, p2.y)) / 6.0), 1)
		for s in steps:
			var t := float(s) / steps
			out.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	out.append(points[points.size() - 1])
	return out


## Grade de 16 m: em cada célula, os trechos [caminho, índice] que podem
## afetar o chão ali (o relevo consulta só esses, não a pista inteira).
const GRID := 16.0

static func _grid(paths: Array) -> Dictionary:
	var grid := {}
	for pi in paths.size():
		var path: Dictionary = paths[pi]
		var pts: PackedVector3Array = path.points
		var reach: float = path.width * 0.5 + path.falloff
		for i in pts.size() - 1:
			var lo := Vector2(minf(pts[i].x, pts[i + 1].x), minf(pts[i].y, pts[i + 1].y)) - Vector2.ONE * reach
			var hi := Vector2(maxf(pts[i].x, pts[i + 1].x), maxf(pts[i].y, pts[i + 1].y)) + Vector2.ONE * reach
			for gx in range(floori(lo.x / GRID), floori(hi.x / GRID) + 1):
				for gy in range(floori(lo.y / GRID), floori(hi.y / GRID) + 1):
					var key := Vector2i(gx, gy)
					if not grid.has(key):
						grid[key] = []
					grid[key].append(Vector2i(pi, i))
	return grid


## Segmentos no mundo (para a cor do chão e o minimapa).
static func _segments(info: Dictionary) -> Array:
	var segments := []
	for path in info.paths:
		var pts: PackedVector3Array = path.points
		for i in pts.size() - 1:
			segments.append({"a": to_world(info, Vector2(pts[i].x, pts[i].y)), "b": to_world(info, Vector2(pts[i + 1].x, pts[i + 1].y)),
				"width": path.width, "kind": path.kind})
	return segments


static func to_world(info: Dictionary, local: Vector2) -> Vector2:
	return info.center + local.rotated(info.yaw)


static func to_local(info: Dictionary, p: Vector2) -> Vector2:
	return (p - info.center).rotated(-info.yaw)


## Quanto o relevo da pista manda no ponto (1 = dentro da área, 0 = longe).
static func flatten_weight(info: Dictionary, p: Vector2) -> float:
	var local := to_local(info, p).abs()
	var d := maxf(local.x - HALF.x, local.y - HALF.y)
	return 1.0 - smoothstep(0.0, 70.0, d)


## Altura do chão da área da pista (relativa a base) antes das pistas: o morro
## do infield e ondulações leves.
static func _ground(local: Vector2) -> float:
	var hill := HILL_HEIGHT * exp(-local.distance_squared_to(HILL_CENTER) / (HILL_RADIUS * HILL_RADIUS))
	var inside := 1.0 - smoothstep(0.0, 30.0, maxf(absf(local.x) - OVAL_STRAIGHT - OVAL_RADIUS, absf(local.y) - OVAL_RADIUS))
	var waves := (sin(local.x * 0.045) * sin(local.y * 0.06 + 1.3) * 1.4 + sin(local.x * 0.11 + local.y * 0.07) * 0.5) * inside
	return hill + waves


## Altura final do terreno no ponto do mundo (com as pistas moldando o chão).
static func surface(info: Dictionary, p: Vector2) -> float:
	var local := to_local(info, p)
	var h := _ground(local)
	var near := _nearest(info, local)
	for pi in info.paths.size():
		if not near.has(pi):
			continue
		var path: Dictionary = info.paths[pi]
		var half: float = path.width * 0.5
		var reach: float = half + path.falloff
		var best_d: float = near[pi].x
		var best_h: float = near[pi].y
		if best_d >= reach:
			continue
		if path.get("banked", false):
			# Curva inclinada: quanto mais para fora, mais alto (só dentro da
			# largura). Entra aos poucos no fim da reta.
			var bank := smoothstep(OVAL_STRAIGHT - 40.0, OVAL_STRAIGHT + 25.0, absf(local.x))
			if bank > 0.0:
				var radial := local.distance_to(Vector2(signf(local.x) * OVAL_STRAIGHT, 0.0)) if absf(local.x) > OVAL_STRAIGHT else absf(local.y)
				var off := clampf(radial - OVAL_RADIUS, -half, half)
				best_h += (off + half) * BANK * bank
		h = lerpf(h, best_h, 1.0 - smoothstep(half + 0.5, reach, best_d))
	return info.base + h


## Trecho mais perto de cada caminho: {índice do caminho: Vector2(distância, altura)}.
static func _nearest(info: Dictionary, local: Vector2) -> Dictionary:
	var near := {}
	var cell: Array = info.grid.get(Vector2i(floori(local.x / GRID), floori(local.y / GRID)), [])
	for entry: Vector2i in cell:
		var pts: PackedVector3Array = info.paths[entry.x].points
		var a := pts[entry.y]
		var b := pts[entry.y + 1]
		var ab := Vector2(b.x - a.x, b.y - a.y)
		var t := clampf((local - Vector2(a.x, a.y)).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := local.distance_to(Vector2(a.x, a.y) + ab * t)
		if not near.has(entry.x) or d < near[entry.x].x:
			near[entry.x] = Vector2(d, lerpf(a.z, b.z, t))
	return near


## Tipo de chão da pista no ponto: {} ou {"kind", "edge"} (o último caminho manda).
static func road_at(info: Dictionary, p: Vector2) -> Dictionary:
	var local := to_local(info, p)
	var near := _nearest(info, local)
	var result := {}
	for pi in info.paths.size():
		if near.has(pi):
			var half: float = info.paths[pi].width * 0.5
			if near[pi].x < half:
				result = {"kind": info.paths[pi].kind, "edge": 1.0 - smoothstep(half - 0.8, half, near[pi].x)}
	return result


# --- Construção (quando o player chega perto) ----------------------------------

func _ready() -> void:
	_terrain = get_node(terrain_path) as TerrainWorld
	_player = get_node(player_path) as Node3D


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or _terrain == null or _terrain.track.is_empty():
		return
	_timer = 0.5
	var info: Dictionary = _terrain.track
	var distance := Vector2(_player.global_position.x, _player.global_position.z).distance_to(info.center)
	if distance < HALF.x + 250.0 and _built == null:
		_built = build(info)
		get_parent().add_child(_built)
	elif distance > HALF.x + 400.0 and _built != null:
		_built.queue_free()
		_built = null


## Altura local (relativa a base) do chão no ponto local.
static func _h(info: Dictionary, local: Vector2) -> float:
	return surface(info, to_world(info, local)) - info.base


static func build(info: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "RaceTrack"
	root.position = Vector3(info.center.x, info.base, info.center.y)
	root.rotation.y = -info.yaw # local (u, v) -> (x, z) como em to_world
	var concrete := MeshBuilder.new()
	var paint := MeshBuilder.new()
	var tires := MeshBuilder.new()
	var wood := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	_walls(info, concrete, paint, body)
	_bridge(info, concrete, paint, body)
	for ramp in RAMPS:
		_ramp(info, wood, body, ramp[0], ramp[1], ramp[2], ramp[3])
	# Pilhas de pneus por fora das curvas do misto e do grampo.
	for spot in [Vector2(-176, 30), Vector2(48, 50), Vector2(-46, -22), Vector2(112, 2), Vector2(150, -50)]:
		var y := _h(info, spot)
		for t in 5:
			var at := Vector3(spot.x + (t - 2) * 1.0, y, spot.y)
			for level in 3:
				tires.lathe(PackedVector2Array([Vector2(0.25, level * 0.32), Vector2(0.5, level * 0.32 + 0.02),
					Vector2(0.5, level * 0.32 + 0.28), Vector2(0.25, level * 0.32 + 0.3)]), 8, Basis.IDENTITY, at)
			_shape(body, at + Vector3(0, 0.48, 0), Vector3(1.0, 0.96, 1.0), Basis.IDENTITY)
	# Placas de madeira marcando os atalhos.
	for sign_at in [Vector2(166, 70), Vector2(30, 24)]:
		var y := _h(info, sign_at)
		wood.color(Color(0.3, 0.24, 0.18))
		wood.box(Vector3(sign_at.x, y + 1.0, sign_at.y), Vector3(0.15, 2.0, 0.15))
		paint.color(Color(0.85, 0.6, 0.1))
		paint.box(Vector3(sign_at.x, y + 2.1, sign_at.y), Vector3(1.6, 0.7, 0.06), Basis(Vector3.UP, 0.6))
	# Faixa de largada xadrez na reta de cima e pórtico.
	for k in 18:
		for row in 2:
			paint.color(Color(0.92, 0.92, 0.9) if (k + row) % 2 == 0 else Color(0.08, 0.08, 0.08))
			paint.box(Vector3(row * 1.0, 0.03, OVAL_RADIUS - OVAL_WIDTH * 0.5 + (k + 0.5) * 1.0), Vector3(1.0, 0.04, 1.0))
	for side in [-1.0, 1.0]:
		var z: float = OVAL_RADIUS + side * (OVAL_WIDTH * 0.5 + 1.5)
		wood.color(Color(0.3, 0.24, 0.18))
		wood.box(Vector3(0.5, 3.5, z), Vector3(0.5, 7.0, 0.5))
		_shape(body, Vector3(0.5, 3.5, z), Vector3(0.5, 7.0, 0.5), Basis.IDENTITY)
	wood.box(Vector3(0.5, 7.0, OVAL_RADIUS), Vector3(0.6, 1.2, OVAL_WIDTH + 4.0))
	# Arquibancada de madeira do lado de fora da reta de cima.
	for step in 8:
		var z: float = OVAL_RADIUS + OVAL_WIDTH * 0.5 + 6.0 + step * 1.4
		wood.color(Color(0.36, 0.27, 0.18).darkened(step * 0.02))
		wood.box(Vector3(0, 0.5 + step * 0.7, z), Vector3(80.0, 1.0 + step * 1.4, 1.4))
	_shape(body, Vector3(0, 2.8, OVAL_RADIUS + OVAL_WIDTH * 0.5 + 11.0), Vector3(80.0, 5.6, 11.2), Basis.IDENTITY)
	for mb in [concrete, paint, tires, wood]:
		var mesh := MeshInstance3D.new()
		mesh.mesh = mb.finish(CityGen.material(), false)
		root.add_child(mesh)
	root.add_child(body)
	return root


## Muretas de concreto por fora do oval, seguindo a altura (e a inclinação) da
## pista. Vãos nas pontas das curvas para entrar e sair da área.
static func _walls(info: Dictionary, concrete: MeshBuilder, paint: MeshBuilder, body: StaticBody3D) -> void:
	var oval: PackedVector3Array = info.paths[3].points
	for i in oval.size() - 1:
		var a := Vector2(oval[i].x, oval[i].y)
		var b := Vector2(oval[i + 1].x, oval[i + 1].y)
		var mid := (a + b) * 0.5
		if absf(mid.y) < 14.0 and absf(mid.x) > OVAL_STRAIGHT:
			continue
		var out := Vector2(mid.x - signf(mid.x) * OVAL_STRAIGHT if absf(mid.x) > OVAL_STRAIGHT else 0.0, mid.y).normalized()
		var offset := out * (OVAL_WIDTH * 0.5 + 0.6)
		var wa := a + offset
		var wb := b + offset
		var ya := _h(info, wa - out * 0.6)
		var yb := _h(info, wb - out * 0.6)
		var length := wa.distance_to(wb)
		var center := (wa + wb) * 0.5
		var pitch := atan2(yb - ya, length)
		var basis := Basis(Vector3.UP, -atan2(wb.y - wa.y, wb.x - wa.x)) * Basis(Vector3.BACK, pitch)
		var y := (ya + yb) * 0.5
		concrete.color(Color(0.62, 0.6, 0.56))
		concrete.box(Vector3(center.x, y + 0.2, center.y), Vector3(length + 0.3, 1.4, 0.6), basis)
		_shape(body, Vector3(center.x, y + 0.2, center.y), Vector3(length, 1.4, 0.6), basis)
		paint.color(Color(0.7, 0.12, 0.08) if i % 2 == 0 else Color(0.9, 0.9, 0.88))
		paint.box(Vector3(center.x, y + 0.93, center.y), Vector3(length + 0.3, 0.06, 0.62), basis)


## Ponte do misto por cima do rebaixo do cruzamento: trechos de laje que
## seguem a altura do próprio misto, com guarda-corpo e pilares.
static func _bridge(info: Dictionary, concrete: MeshBuilder, paint: MeshBuilder, body: StaticBody3D) -> void:
	var pts: PackedVector3Array = info.paths[0].points
	var span := CROSS_WIDTH * 0.5 + CROSS_FALLOFF + 7.0 # até onde a laje vai (a partir do eixo do cruzamento)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var mid := Vector2(a.x + b.x, a.y + b.y) * 0.5
		if mid.x < -60.0 or mid.x > 30.0 or absf(mid.y) > span:
			continue
		var flat := Vector2(b.x - a.x, b.y - a.y)
		var length := flat.length() + 0.4
		var basis := Basis(Vector3.UP, -atan2(flat.y, flat.x)) * Basis(Vector3.BACK, atan2(b.z - a.z, flat.length()))
		var top := (a.z + b.z) * 0.5
		concrete.color(Color(0.55, 0.53, 0.5))
		concrete.box(Vector3(mid.x, top - 0.36, mid.y), Vector3(length, 0.7, INFIELD_WIDTH), basis)
		_shape(body, Vector3(mid.x, top - 0.36, mid.y), Vector3(length, 0.7, INFIELD_WIDTH), basis)
		var side := flat.normalized().orthogonal()
		for s in [-1.0, 1.0]:
			var rail: Vector2 = mid + side * s * (INFIELD_WIDTH * 0.5 + 0.2)
			concrete.box(Vector3(rail.x, top + 0.45, rail.y), Vector3(length, 0.9, 0.4), basis)
			_shape(body, Vector3(rail.x, top + 0.45, rail.y), Vector3(length, 0.9, 0.4), basis)
			paint.color(Color(0.7, 0.12, 0.08) if i % 2 == 0 else Color(0.9, 0.9, 0.88))
			paint.box(Vector3(rail.x, top + 0.93, rail.y), Vector3(length, 0.06, 0.42), basis)
		# Pilares nas beiradas do rebaixo (sem fechar a passagem).
		if absf(mid.y) > CROSS_WIDTH * 0.5 and absf(mid.y) < CROSS_WIDTH * 0.5 + 4.0:
			var floor_y := _h(info, mid)
			if top - floor_y > 1.5:
				concrete.box(Vector3(mid.x, (floor_y + top) * 0.5 - 0.35, mid.y), Vector3(1.2, top - floor_y, INFIELD_WIDTH - 1.0), basis)


## Rampa de madeira (cunha) apontando para dir: sobe até "height" na ponta.
static func _ramp(info: Dictionary, wood: MeshBuilder, body: StaticBody3D, at: Vector2, dir: Vector2, length: float, height: float) -> void:
	dir = dir.normalized()
	var side := Vector2(-dir.y, dir.x) * (DIRT_WIDTH * 0.5 - 0.5)
	var back := at - dir * length * 0.5
	var lip := at + dir * length * 0.5
	var yb := _h(info, back) - 0.05
	var yl := _h(info, lip)
	var b0 := Vector3(back.x - side.x, yb, back.y - side.y)
	var b1 := Vector3(back.x + side.x, yb, back.y + side.y)
	var l0 := Vector3(lip.x - side.x, yl, lip.y - side.y)
	var l1 := Vector3(lip.x + side.x, yl, lip.y + side.y)
	var t0 := l0 + Vector3.UP * height
	var t1 := l1 + Vector3.UP * height
	wood.color(Color(0.42, 0.3, 0.18))
	wood.quad(b0, t0, t1, b1) # rampa
	wood.quad(b1, t1, t0, b0)
	wood.quad(l0, l1, t1, t0) # frente
	wood.quad(t0, t1, l1, l0)
	wood.tri(b0, l0, t0)
	wood.tri(t0, l0, b0)
	wood.tri(b1, t1, l1)
	wood.tri(l1, t1, b1)
	# Tábuas (riscas escuras) na subida.
	wood.color(Color(0.3, 0.2, 0.12))
	for k in 6:
		var t := (k + 0.5) / 6.0
		var p0 := b0.lerp(t0, t) + Vector3.UP * 0.02
		var p1 := b1.lerp(t1, t) + Vector3.UP * 0.02
		wood.quad(p0, p1, p1 + Vector3.UP * 0.02 + (t0 - b0).normalized() * 0.08, p0 + Vector3.UP * 0.02 + (t0 - b0).normalized() * 0.08)
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([b0, b1, l0, l1, t0, t1])
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)


static func _shape(body: StaticBody3D, center: Vector3, size: Vector3, basis: Basis) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.transform = Transform3D(basis, center)
	body.add_child(collision)
