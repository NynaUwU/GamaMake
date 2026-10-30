class_name CityManager
extends Node
## Constrói as cidades geradas (TerrainWorld.cities) quando o player chega perto
## e apaga quando ele se afasta. Monta poucas casas por frame para não travar.
## Cada cidade ganha alguns zumbis nas ruas (somem junto com ela).

const ZOMBIE_SCENE := preload("res://scenes/zombie.tscn")
const ZOMBIES := {"small": 3, "medium": 6, "large": 10}

@export var terrain_path: NodePath
@export var player_path: NodePath
@export var build_distance := 230.0 ## além da borda da cidade
@export var houses_per_frame := 2

var _terrain: TerrainWorld
var _player: Node3D
var _built := {} # índice da cidade -> {"node": Node3D, "next": int}
var _timer := 0.0


func _ready() -> void:
	_terrain = get_node(terrain_path) as TerrainWorld
	_player = get_node(player_path) as Node3D


func _process(delta: float) -> void:
	if _terrain == null or _player == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_update_cities()
	# Constrói aos poucos as casas que faltam.
	var budget := houses_per_frame
	for index in _built:
		var entry: Dictionary = _built[index]
		var city: Dictionary = _terrain.cities[index]
		while budget > 0 and entry.next < city.lots.size():
			_add_house(entry.node, city, city.lots[entry.next])
			entry.next += 1
			budget -= 1
			if entry.next == city.lots.size():
				_spawn_zombies(entry.node, city)


## Cria/apaga cidades pela distância. build_all = constrói tudo agora (testes).
func _update_cities(build_all := false) -> void:
	# Host online: cidades em volta de todos os jogadores (os zumbis de lá precisam das casas).
	var centers: Array[Vector3] = [_player.global_position]
	if Net.i.world:
		centers.assign(Net.i.world.player_positions())
	for i in _terrain.cities.size():
		var city: Dictionary = _terrain.cities[i]
		var distance := INF
		for c in centers:
			distance = minf(distance, Vector2(c.x, c.z).distance_to(city.center) - city.radius)
		if distance < build_distance and not _built.has(i):
			var node := Node3D.new()
			node.name = "City_%d_%s" % [i, city.size]
			node.position = Vector3(city.center.x, city.base, city.center.y)
			get_parent().add_child(node)
			var plaza := CityGen.build_plaza(city)
			var plaza_pos: Vector2 = CityGen.to_world(city, city.plaza) - city.center
			plaza.position = Vector3(plaza_pos.x, 0, plaza_pos.y)
			node.add_child(plaza)
			_built[i] = {"node": node, "next": 0}
		elif distance > build_distance + 120.0 and _built.has(i):
			_built[i].node.queue_free()
			_built.erase(i)
	if build_all:
		for index in _built:
			var entry: Dictionary = _built[index]
			var city: Dictionary = _terrain.cities[index]
			while entry.next < city.lots.size():
				_add_house(entry.node, city, city.lots[entry.next])
				entry.next += 1


func _add_house(city_node: Node3D, city: Dictionary, lot: Dictionary) -> void:
	var house := CityGen.build_house(lot)
	var local: Vector2 = lot.pos - city.center
	house.position = Vector3(local.x, 0.0, local.y)
	house.rotation.y = lot.yaw
	city_node.add_child(house)


func _spawn_zombies(city_node: Node3D, city: Dictionary) -> void:
	if not Net.i.is_host():
		return # online os zumbis vêm do host
	var rng := RandomNumberGenerator.new()
	rng.seed = city.seed + 5
	for k in ZOMBIES[city.size]:
		# Nas ruas: ponto aleatório de uma rua da cidade.
		var street: Dictionary = city.streets[rng.randi() % city.streets.size()]
		var p: Vector2 = street.a.lerp(street.b, rng.randf()) - city.center
		var zombie: Zombie = ZOMBIE_SCENE.instantiate()
		zombie.position = Vector3(p.x, 0.5, p.y)
		zombie.rotation.y = rng.randf() * TAU
		city_node.add_child(zombie)
