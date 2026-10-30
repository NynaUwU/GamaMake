class_name RaceTrack
extends Node
## Pista de corrida no deserto, inspirada na "The Motor Raceway" (FlatOut 2):
## um oval grande + um misto no meio (curvas em S, cotovelo) que sai e volta
## para o oval, e um cruzamento pelo meio. Nada fica fechado: todos os
## trechos são acessíveis ao mesmo tempo.
##
## plan() (chamado pelo TerrainWorld) escolhe o lugar e gera o traçado em
## segmentos de asfalto; este nó constrói muretas, pneus, arquibancada e a
## faixa de largada quando o player chega perto.

const HALF := Vector2(330.0, 140.0) ## meia área ocupada (local: u = comprimento, v = largura)
const OVAL_STRAIGHT := 180.0 ## meia reta
const OVAL_RADIUS := 85.0
const OVAL_WIDTH := 16.0
const INFIELD_WIDTH := 12.0

@export var terrain_path: NodePath
@export var player_path: NodePath

var _terrain: TerrainWorld
var _player: Node3D
var _built: Node3D
var _timer := 0.0


## Escolhe um lugar plano no deserto e devolve {center, yaw, base, segments, paths}.
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
		return info
	return {}


## Traçados em coordenadas locais.
static func _paths() -> Array:
	var oval := PackedVector2Array()
	for side in [1.0, -1.0]:
		for k in 13:
			var a := lerpf(-PI * 0.5, PI * 0.5, k / 12.0)
			oval.append(Vector2(side * (OVAL_STRAIGHT + cos(a) * OVAL_RADIUS), side * sin(a) * OVAL_RADIUS))
	oval.append(oval[0])
	# Misto: sai da reta de baixo, faz S, cotovelo e volta na reta de cima.
	var infield := PackedVector2Array([Vector2(-120, -OVAL_RADIUS), Vector2(-80, -55), Vector2(-20, -60), Vector2(30, -35),
		Vector2(0, -5), Vector2(-50, 10), Vector2(-60, 40), Vector2(-10, 55), Vector2(60, 40), Vector2(110, 55),
		Vector2(140, OVAL_RADIUS)])
	# Cruzamento pelo meio (estilo oito), cruzando o misto.
	var cross := PackedVector2Array([Vector2(-OVAL_STRAIGHT - 40, 0), Vector2(-100, 20), Vector2(0, 0), Vector2(100, -20), Vector2(OVAL_STRAIGHT + 40, 0)])
	return [{"points": oval, "width": OVAL_WIDTH}, {"points": infield, "width": INFIELD_WIDTH}, {"points": cross, "width": INFIELD_WIDTH}]


static func _segments(info: Dictionary) -> Array:
	var segments := []
	for path in info.paths:
		var pts: PackedVector2Array = path.points
		for i in pts.size() - 1:
			segments.append({"a": to_world(info, pts[i]), "b": to_world(info, pts[i + 1]), "width": path.width})
	return segments


static func to_world(info: Dictionary, local: Vector2) -> Vector2:
	return info.center + local.rotated(info.yaw)


## Achatamento da área da pista (usado pelo relevo).
static func flatten_weight(info: Dictionary, p: Vector2) -> float:
	var local: Vector2 = (p - info.center).rotated(-info.yaw).abs()
	var d := maxf(local.x - HALF.x, local.y - HALF.y)
	return 1.0 - smoothstep(0.0, 70.0, d)


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
	# Muretas de concreto no lado de fora do oval (com vãos onde o misto e o cruzamento saem).
	var oval: PackedVector2Array = info.paths[0].points
	for i in oval.size() - 1:
		var a := oval[i]
		var b := oval[i + 1]
		var mid := (a + b) * 0.5
		var out := Vector2(mid.x - signf(mid.x) * OVAL_STRAIGHT if absf(mid.x) > OVAL_STRAIGHT else 0.0, mid.y).normalized()
		if out.is_zero_approx():
			out = Vector2(0, signf(mid.y))
		var offset := out * (OVAL_WIDTH * 0.5 + 1.0)
		var wa := a + offset
		var wb := b + offset
		if absf(mid.y) < 25.0 and absf(mid.x) > OVAL_STRAIGHT:
			continue # vão para o cruzamento sair pelas pontas
		var length := wa.distance_to(wb)
		var center := (wa + wb) * 0.5
		var basis := Basis(Vector3.UP, -atan2(wb.y - wa.y, wb.x - wa.x))
		concrete.color(Color(0.62, 0.6, 0.56))
		concrete.box(Vector3(center.x, 0.45, center.y), Vector3(length + 0.2, 0.9, 0.6), basis)
		_shape(body, Vector3(center.x, 0.45, center.y), Vector3(length, 0.9, 0.6), basis)
		# Faixas vermelhas e brancas alternadas em cima da mureta.
		paint.color(Color(0.7, 0.12, 0.08) if i % 2 == 0 else Color(0.9, 0.9, 0.88))
		paint.box(Vector3(center.x, 0.93, center.y), Vector3(length + 0.2, 0.06, 0.62), basis)
	# Pilhas de pneus nos cotovelos do misto.
	var infield: PackedVector2Array = info.paths[1].points
	for k in [2, 4, 7, 9]:
		var p := infield[k]
		for t in 5:
			var at := Vector3(p.x + (t - 2) * 1.0, 0.0, p.y + 8.0)
			for level in 3:
				tires.lathe(PackedVector2Array([Vector2(0.25, level * 0.32), Vector2(0.5, level * 0.32 + 0.02), Vector2(0.5, level * 0.32 + 0.28), Vector2(0.25, level * 0.32 + 0.3)]), 8, Basis.IDENTITY, at)
			_shape(body, at + Vector3(0, 0.48, 0), Vector3(1.0, 0.96, 1.0), Basis.IDENTITY)
	# Faixa de largada xadrez na reta de cima e pórtico.
	for k in 16:
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


static func _shape(body: StaticBody3D, center: Vector3, size: Vector3, basis: Basis) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.transform = Transform3D(basis, center)
	body.add_child(collision)
