class_name AnimalManager
extends Node3D
## Nó "Animals": mantém alguns bichos em volta dos jogadores (host). Nascem a
## 60-110 m conforme o bioma (planície: cervo, coelho, javali; neve: cervo e
## coelho; deserto: só coelho, raro), somem a mais de 200 m. Manda posição e
## direção para os outros ~7x por segundo; golpe dado num cliente vira pedido
## ao host ("hit"). Não vai no save (nascem de novo).

const MAX_ANIMALS := 10
const SPAWN_MIN := 60.0
const SPAWN_MAX := 110.0
const DESPAWN := 200.0

var animals := {} ## id -> Animal
var _next_id := 1
var _spawn_timer := 2.0
var _send_timer := 0.0


func _process(delta: float) -> void:
	if not Net.i.is_host():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 3.0
		_populate()
	if Net.i.online():
		_send_timer -= delta
		if _send_timer <= 0.0:
			_send_timer = 0.15
			Net.i.broadcast_system_state(name, snapshot())


func _players() -> Array:
	var world: Node = Net.i.world
	return world.player_positions() if world and world.has_method("player_positions") else []


func _populate() -> void:
	var players := _players()
	if players.is_empty():
		return
	for id in animals.keys():
		var a: Animal = animals[id]
		if not is_instance_valid(a):
			animals.erase(id)
			continue
		var near := INF
		for p in players:
			near = minf(near, p.distance_to(a.global_position))
		if near > DESPAWN:
			a.queue_free()
			animals.erase(id)
	if animals.size() >= MAX_ANIMALS:
		return
	var terrain := get_parent().get_node_or_null("Terrain") as TerrainWorld
	if terrain == null:
		return
	var center: Vector3 = players[randi() % players.size()]
	var ang := randf() * TAU
	var r := randf_range(SPAWN_MIN, SPAWN_MAX)
	var x := center.x + cos(ang) * r
	var z := center.z + sin(ang) * r
	var biome := terrain.biome_at(x, z)
	var kind := ""
	if biome.desert > 0.5:
		kind = "coelho" if randf() < 0.3 else ""
	elif biome.winter > 0.5:
		kind = "cervo" if randf() < 0.6 else "coelho"
	elif biome.mountain < 0.5:
		var roll := randf()
		kind = "cervo" if roll < 0.45 else ("coelho" if roll < 0.8 else "javali")
	if kind == "" or not WaterManager.i or WaterManager.i.depth_at(Vector3(x, terrain.height_at(x, z) + 0.1, z)) > 0.0:
		return
	for city in terrain.cities:
		if Vector2(x, z).distance_to(city.center) < city.radius * 1.2:
			return # bicho não entra na cidade
	spawn(kind, Vector3(x, terrain.height_at(x, z) + 0.3, z))


func spawn(kind: String, at: Vector3, id := -1, puppet := false) -> Animal:
	if id < 0:
		id = _next_id
		_next_id += 1
	var animal := Animal.new()
	animal.name = "Animal_%d" % id
	animal.setup(kind, id, puppet)
	add_child(animal)
	animal.global_position = at
	animal.rotation.y = randf() * TAU
	animal.apply_snapshot(at, animal.rotation.y, 0.0)
	animals[id] = animal
	return animal


func forget(id: int) -> void:
	animals.erase(id)


func snapshot() -> Array:
	var list := []
	for id in animals:
		var a: Animal = animals[id]
		if is_instance_valid(a):
			list.append([id, a.kind, a.global_position, a.rotation.y, a.anim_speed])
	return list


# --- Rede ----------------------------------------------------------------------

func host_apply(action: String, args: Array) -> Array:
	if action == "hit":
		var a: Animal = animals.get(args[0])
		if a and is_instance_valid(a):
			a.apply_hit(clampf(float(args[1]), 0.0, 200.0), args[2])
	return []


func apply_remote(_action: String, _args: Array) -> void:
	pass


## Cliente: instantâneo do host (cria, move e apaga as cópias).
func load_data(data: Variant) -> void:
	if Net.i.is_host() or not data is Array:
		return
	var seen := {}
	for entry in data:
		var id: int = entry[0]
		seen[id] = true
		var a: Animal = animals.get(id)
		if a == null or not is_instance_valid(a):
			a = spawn(entry[1], entry[2], id, true)
		a.apply_snapshot(entry[2], entry[3], entry[4])
	for id in animals.keys():
		if not seen.has(id):
			if is_instance_valid(animals[id]):
				animals[id].queue_free()
			animals.erase(id)


func net_sync_to(peer: int) -> void:
	Net.i.send_system_state(peer, name, snapshot())
