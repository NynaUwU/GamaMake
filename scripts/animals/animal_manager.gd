class_name AnimalManager
extends Node3D
## Nó "Animals": mantém bichos em volta dos jogadores (host). Nascem a 60-110 m
## conforme o lugar, em grupos:
##   planície  cervo, coelho, javali, raposa, lobo (mais de noite), galinha, ovelha,
##             vaca, porco (de criação, selvagens) e pombos/corvos
##   neve      cervo, coelho, raposa, lobo (matilha), urso, corvo
##   montanha  cabra (rebanho), urso, lobo, cervo, corvo
##   deserto   coelho (raro), corvo
##   lago      bando de patos nadando · costa: gaivotas planando
## Selvagens somem a mais de 200 m; os MANSOS (fazenda) ficam, vão no save e não
## contam no limite. A cada 5 s o host cuida da fazenda: filhotes (bicho alimentado
## e com água perto de outro igual), ovos, leite, lã crescendo.
## Manda posição/direção/marcas para os outros ~7x por segundo; golpe e ações ([E])
## dos clientes viram pedidos ao host.

const MAX_ANIMALS := 16 ## selvagens por vez (pássaros contam)
const SPAWN_MIN := 60.0
const SPAWN_MAX := 110.0
const DESPAWN := 200.0
const BREED_TIME := 900.0 ## espera entre crias (s do relógio da fazenda)
const FARM_CAP := 24 ## mansos a até 30 m: acima disso não nasce mais
const EGG_TIME := 360.0
const MILK_TIME := 300.0
const WOOL_TIME := 600.0
## [espécie, peso, tamanho do grupo mín, máx]
const TABLES := {
	"plains": [["cervo", 14, 1, 2], ["coelho", 12, 1, 2], ["javali", 7, 1, 2], ["raposa", 6, 1, 1], ["lobo", 4, 2, 3],
		["galinha", 9, 3, 5], ["ovelha", 8, 2, 4], ["vaca", 6, 2, 3], ["porco", 6, 2, 3], ["pombo", 8, 3, 6], ["corvo", 5, 1, 3]],
	"winter": [["cervo", 25, 1, 2], ["coelho", 18, 1, 2], ["raposa", 12, 1, 1], ["lobo", 16, 2, 4], ["urso", 9, 1, 1], ["corvo", 6, 1, 3]],
	"mountain": [["cabra", 40, 2, 4], ["urso", 12, 1, 1], ["lobo", 10, 2, 3], ["cervo", 14, 1, 2], ["corvo", 12, 1, 3]],
	"desert": [["coelho", 10, 1, 1], ["corvo", 6, 1, 2], ["", 40, 0, 0]],
}

var animals := {} ## id -> Animal
var _next_id := 1
var _spawn_timer := 2.0
var _send_timer := 0.0
var _farm_timer := 5.0


func _ready() -> void:
	add_to_group("persist")


func _process(delta: float) -> void:
	if not Net.i.is_host():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 3.0
		_populate()
	_farm_timer -= delta
	if _farm_timer <= 0.0:
		_farm_timer = 5.0
		_farm()
	if Net.i.online():
		_send_timer -= delta
		if _send_timer <= 0.0:
			_send_timer = 0.15
			Net.i.broadcast_system_state(name, snapshot())


func _players() -> Array:
	var world: Node = Net.i.world
	return world.player_positions() if world and world.has_method("player_positions") else []


func _terrain() -> TerrainWorld:
	return get_parent().get_node_or_null("Terrain") as TerrainWorld


func wild_count() -> int:
	var n := 0
	for a: Animal in animals.values():
		if is_instance_valid(a) and not a.tame:
			n += 1
	return n


func _populate() -> void:
	var players := _players()
	if players.is_empty():
		return
	for id in animals.keys():
		var a: Animal = animals[id]
		if not is_instance_valid(a):
			animals.erase(id)
			continue
		if a.tame:
			continue
		var near := INF
		for p in players:
			near = minf(near, p.distance_to(a.global_position))
		if near > DESPAWN:
			a.queue_free()
			animals.erase(id)
	if wild_count() >= roundi(MAX_ANIMALS * WorldSettings.mult("animals")):
		return
	var terrain := _terrain()
	if terrain == null:
		return
	var center: Vector3 = players[randi() % players.size()]
	# Pássaros da água: patos num lago perto, gaivotas na costa.
	if WaterManager.i and randf() < 0.25:
		for lake in WaterManager.i.lakes():
			var lc: Vector2 = lake.center
			if not lake.frozen and lc.distance_to(Vector2(center.x, center.z)) < 140.0:
				var a := randf() * TAU
				var p: Vector2 = lc + Vector2(cos(a), sin(a)) * float(lake.radius) * randf_range(0.2, 0.6)
				_group("pato", Vector3(p.x, lake.level, p.y), randi_range(3, 5), 2.5)
				return
	var ang := randf() * TAU
	var r := randf_range(SPAWN_MIN, SPAWN_MAX)
	var x := center.x + cos(ang) * r
	var z := center.z + sin(ang) * r
	if terrain.coast_distance(x, z) < 40.0:
		if randf() < 0.5 and terrain.coast_distance(x, z) > 2.0:
			_group("gaivota", Vector3(x, terrain.height_at(x, z) + 0.2, z), randi_range(2, 4), 4.0)
		return
	var biome := terrain.biome_at(x, z)
	var table: Array = TABLES.plains
	if biome.desert > 0.5:
		table = TABLES.desert
	elif biome.winter > 0.5:
		table = TABLES.winter
	elif biome.mountain > 0.5:
		table = TABLES.mountain
	var pick := _pick(table)
	if pick.is_empty() or pick[0] == "":
		return
	if not WaterManager.i or WaterManager.i.depth_at(Vector3(x, terrain.height_at(x, z) + 0.1, z)) > 0.0:
		return
	for city in terrain.cities:
		if Vector2(x, z).distance_to(city.center) < city.radius * 1.2:
			return # bicho não entra na cidade
	_group(pick[0], Vector3(x, terrain.height_at(x, z) + 0.3, z), randi_range(pick[2], pick[3]), 3.0)


func _pick(table: Array) -> Array:
	var night := DayNight.i != null and DayNight.i.is_night()
	var total := 0.0
	for row in table:
		total += row[1] * (2.5 if night and row[0] == "lobo" else 1.0)
	var roll := randf() * total
	for row in table:
		roll -= row[1] * (2.5 if night and row[0] == "lobo" else 1.0)
		if roll <= 0.0:
			return row
	return table[0]


## Grupo (rebanho, matilha, bando) em volta de um ponto.
func _group(kind: String, at: Vector3, count: int, spread: float) -> void:
	var terrain := _terrain()
	for k in count:
		var p := at + Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread, spread))
		if terrain and kind != "pato":
			p.y = terrain.height_at(p.x, p.z) + 0.3
		spawn(kind, p)


func spawn(kind: String, at: Vector3, id := -1, puppet := false) -> Animal:
	if id < 0:
		id = _next_id
		_next_id += 1
	_next_id = maxi(_next_id, id + 1)
	var animal := Animal.new()
	animal.name = "Animal_%d" % id
	animal.setup(kind, id, puppet)
	add_child(animal)
	animal.global_position = at
	animal.home = at
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
			list.append([id, a.kind, a.global_position, a.rotation.y, a.anim_speed, a.net_flags()])
	return list


# --- Fazenda (host) ---------------------------------------------------------------------

func _clock() -> float:
	var placed: PlacedManager = get_parent().get_node_or_null("Placed")
	return placed.clock if placed else 0.0


func _farm() -> void:
	var now := _clock()
	var tame: Array = animals.values().filter(func(a): return is_instance_valid(a) and a.tame)
	for a: Animal in tame:
		if a.is_baby():
			continue
		# Produtos: galinha bota ovo (no chão, do lado dela); lã cresce de novo.
		match a.kind:
			"galinha":
				if a.is_fed() and now >= a.next_product:
					a.next_product = now + EGG_TIME * (0.75 if a.is_watered() else 1.0)
					Net.i.drop_item(&"ovo", 1, Transform3D(Basis(), a.global_position + Vector3.UP * 0.2), Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5)))
					Sfx.play_at("cluck", a.global_position + Vector3.UP * 0.3, 0.0, 1.0)
			"ovelha":
				if a.shorn and a.is_fed() and now >= a.next_product:
					a.shorn = false
		# Cria: alimentado + com água + outro igual pronto por perto.
		if now < a.next_breed or not a.is_fed() or not a.is_watered():
			continue
		for b: Animal in tame:
			if b == a or b.kind != a.kind or b.is_baby() or now < b.next_breed or not b.is_fed() or not b.is_watered():
				continue
			if b.global_position.distance_to(a.global_position) > 6.0:
				continue
			if tame.filter(func(t): return t.global_position.distance_to(a.global_position) < 30.0).size() >= FARM_CAP:
				break
			a.next_breed = now + BREED_TIME
			b.next_breed = now + BREED_TIME
			var mid := (a.global_position + b.global_position) * 0.5
			for k in int(a.def().get("litter", 1)):
				var baby := spawn(a.kind, mid + Vector3(randf_range(-0.5, 0.5), 0.2, randf_range(-0.5, 0.5)))
				baby.tame = true
				baby.birth = now
				baby.home = a.home
				baby.fed_until = now + 120.0
				baby.next_breed = now + Animal.GROW_TIME + BREED_TIME * 0.5
				tame.append(baby)
			Sfx.play_at(_voice(a.kind), mid + Vector3.UP * 0.5, 0.0, 1.3)
			ImpactFX.burst(self, mid + Vector3.UP * 0.8, Vector3.UP, Color(0.95, 0.5, 0.6), 14, 1.5, 0.05, 0.0)
			break


static func _voice(kind: String) -> String:
	return {"galinha": "cluck", "ovelha": "baa", "vaca": "moo", "porco": "oink"}.get(kind, "groan")


# --- Rede ----------------------------------------------------------------------

func host_apply(action: String, args: Array) -> Array:
	var a: Animal = animals.get(args[0]) if not args.is_empty() else null
	if a == null or not is_instance_valid(a):
		if action == "feed":
			Net.i.give_to(Net.i.request_peer, StringName(args[1]), 1) # bicho sumiu: devolve a comida
		elif action == "milk":
			Net.i.give_to(Net.i.request_peer, &"garrafa", 1)
		return []
	var now := _clock()
	match action:
		"hit":
			a.apply_hit(clampf(float(args[1]), 0.0, 200.0), args[2])
		"feed":
			var food := StringName(args[1])
			if not food in a.def().get("food", []) or (a.tame and a.is_fed()):
				Net.i.give_to(Net.i.request_peer, food, 1)
				return []
			if not a.tame:
				a.tame = true
				a.home = a.global_position
				a.next_breed = now + 60.0
				a.next_product = now + 60.0
			a.fed_until = now + Animal.FED_TIME
			Sfx.play_at(_voice(a.kind), a.global_position + Vector3.UP * 0.5, 0.0, 1.1)
		"milk":
			if a.kind != "vaca" or not a.product_ready():
				Net.i.give_to(Net.i.request_peer, &"garrafa", 1)
				return []
			a.next_product = now + MILK_TIME
			Net.i.give_to(Net.i.request_peer, &"leite", 1)
			Sfx.play_at("moo", a.global_position + Vector3.UP, -2.0, 1.0)
		"shear":
			if a.kind != "ovelha" or not a.product_ready():
				return []
			a.shorn = true
			a.next_product = now + WOOL_TIME
			Net.i.give_to(Net.i.request_peer, &"la", randi_range(2, 3))
			Sfx.play_at("baa", a.global_position + Vector3.UP, -2.0, 1.1)
	return []


func apply_remote(_action: String, _args: Array) -> void:
	pass


## Cliente: instantâneo do host (cria, move e apaga as cópias). Host: save (Dictionary).
func load_data(data: Variant) -> void:
	if data is Dictionary:
		_load_save(data)
		return
	if Net.i.is_host() or not data is Array:
		return
	var seen := {}
	for entry in data:
		var id: int = entry[0]
		seen[id] = true
		var a: Animal = animals.get(id)
		if a == null or not is_instance_valid(a):
			a = spawn(entry[1], entry[2], id, true)
		a.apply_snapshot(entry[2], entry[3], entry[4], entry[5] if entry.size() > 5 else 0)
	for id in animals.keys():
		if not seen.has(id):
			if is_instance_valid(animals[id]):
				animals[id].queue_free()
			animals.erase(id)


func net_sync_to(peer: int) -> void:
	Net.i.send_system_state(peer, name, snapshot())


# --- Save (só os mansos) --------------------------------------------------------------

func persist_key() -> String:
	return "animals"


func save_data() -> Dictionary:
	var list := []
	for a: Animal in animals.values():
		if is_instance_valid(a) and a.tame:
			list.append([a.kind, a.global_position, a.rotation.y, a.birth, a.fed_until, a.water_until, a.next_breed, a.next_product, a.home, a.shorn])
	return {"tame": list}


func _load_save(data: Dictionary) -> void:
	if not Net.i.is_host():
		return
	for id in animals.keys():
		if is_instance_valid(animals[id]) and animals[id].tame:
			animals[id].queue_free()
			animals.erase(id)
	for e in data.get("tame", []):
		var a := spawn(e[0], e[1])
		a.rotation.y = e[2]
		a.tame = true
		a.birth = e[3]
		a.fed_until = e[4]
		a.water_until = e[5]
		a.next_breed = e[6]
		a.next_product = e[7]
		a.home = e[8]
		a.shorn = e[9]
