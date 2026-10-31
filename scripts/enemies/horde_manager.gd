class_name HordeManager
extends Node
## Hordas (nó "Hordes" da cena principal). Só o host decide; os clientes
## recebem a lista para o mapa e os zumbis pela rede, como sempre.
##
## Hordas no mapa: grupos de 12-30 zumbis andando de cidade em cidade (mais
## rápido de noite). Longe de todo mundo são só um ponto no mapa; quando um
## jogador chega a MATERIALIZE metros eles aparecem de verdade e marcham
## juntos; se todos se afastam, os vivos voltam a ser um ponto. Matou todos:
## a horda some e outra nasce longe depois de um tempo.
##
## Hordas noturnas: de noite nascem zumbis a 45-65 m de cada jogador, fora da
## vista, que já vêm atrás dele (até NIGHT_CAP por jogador, cresce a cada
## dia). Ao amanhecer os que estão longe vão embora.

const ZOMBIE_SCENE := preload("res://scenes/zombie.tscn")
const MATERIALIZE := 120.0
const DEMATERIALIZE := 200.0
const HORDES := 5
const HORDES_NIGHT := 7
const SPEED := 1.1 ## m/s andando pelo mapa (x1,8 de noite)

static var i: HordeManager

var hordes: Array = [] ## {id, pos: Vector2, dest: Vector2, size, live, zombies: []}
var map_list: Array = [] ## [[pos, size]] para o mapa (host e clientes)
## Onda noturna (HUD): vivos agora e abatidos nesta noite (host conta, clientes recebem).
var wave_alive := 0
var wave_killed := 0
var _wave_seen := {} # zumbi noturno -> true (para contar quando morre)
var _next_id := 1
var _tick := 0.0
var _night_tick := 0.0
var _respawn := 30.0
var _broadcast := 0.0
var _spawn_queue: Array = [] # [horde, quantos faltam]


func _enter_tree() -> void:
	i = self


func _exit_tree() -> void:
	if i == self:
		i = null


func _ready() -> void:
	add_to_group("persist")
	if DayNight.i:
		DayNight.i.nightfall.connect(_on_nightfall)


func _world() -> Node:
	return get_parent()


func _terrain() -> TerrainWorld:
	return _world().get_node_or_null("Terrain") as TerrainWorld


func _process(delta: float) -> void:
	if not Net.i.is_host() or _terrain() == null:
		return
	if hordes.is_empty() and _next_id == 1:
		for k in HORDES:
			_new_horde(true)
	_process_spawn_queue()
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_update_hordes(0.5)
	_night_tick -= delta
	if _night_tick <= 0.0:
		_night_tick = 6.0
		_night_spawns()
	_respawn -= delta
	if _respawn <= 0.0:
		_respawn = 60.0
		var night := DayNight.i != null and DayNight.i.is_night()
		if hordes.size() < (HORDES_NIGHT if night else HORDES):
			_new_horde(false)
	_broadcast -= delta
	if _broadcast <= 0.0:
		_broadcast = 2.0
		map_list = _make_map_list()
		_count_wave()
		if Net.i.online():
			Net.i.broadcast_system_state(name, {"map": map_list, "wave": [wave_alive, wave_killed]})


# --- Hordas no mapa --------------------------------------------------------------------

func _players() -> Array[Vector3]:
	return _world().player_positions()


func _random_city() -> Vector2:
	var cities: Array = _terrain().cities
	if cities.is_empty():
		return Vector2(randf_range(-400, 400), randf_range(-400, 400))
	return cities[randi() % cities.size()].center


## Nasce longe de todo mundo (start = começo do mundo: em qualquer lugar a 250+ m).
func _new_horde(start: bool) -> void:
	var half: float = _terrain().world_size * 0.45
	for attempt in 20:
		var pos := Vector2(randf_range(-half, half), randf_range(-half, half))
		var far := true
		for p in _players():
			if Vector2(p.x, p.z).distance_to(pos) < (250.0 if start else 320.0):
				far = false
		if far:
			hordes.append({"id": _next_id, "pos": pos, "dest": _random_city(), "size": randi_range(12, 30), "live": false, "zombies": []})
			_next_id += 1
			return


func _update_hordes(dt: float) -> void:
	var players := _players()
	var night := DayNight.i != null and DayNight.i.is_night()
	for horde in hordes.duplicate():
		var nearest := INF
		for p in players:
			nearest = minf(nearest, Vector2(p.x, p.z).distance_to(horde.pos))
		if horde.live:
			horde.zombies = horde.zombies.filter(func(z): return is_instance_valid(z) and z.state != Zombie.State.DEAD)
			var queued := _queued(horde)
			if horde.zombies.is_empty() and queued == 0:
				hordes.erase(horde) # mataram todos
				continue
			if not horde.zombies.is_empty():
				var center := Vector3.ZERO
				for z in horde.zombies:
					center += z.global_position
				center /= horde.zombies.size()
				horde.pos = Vector2(center.x, center.z)
			horde.size = horde.zombies.size() + queued
			_march(horde)
			if nearest > DEMATERIALIZE:
				_dematerialize(horde)
		else:
			var to: Vector2 = horde.dest - horde.pos
			if to.length() < 8.0:
				horde.dest = _random_city()
			else:
				horde.pos += to.normalized() * minf(to.length(), SPEED * (1.8 if night else 1.0) * dt)
			if nearest < MATERIALIZE:
				_materialize(horde)


## Comando /horda (host): uma horda a ~90 m vindo na direção do jogador.
func spawn_near(at: Vector3) -> void:
	var a := randf() * TAU
	var pos := Vector2(at.x, at.z) + Vector2(cos(a), sin(a)) * 90.0
	hordes.append({"id": _next_id, "pos": pos, "dest": Vector2(at.x, at.z), "size": randi_range(15, 25), "live": false, "zombies": []})
	_next_id += 1


func _queued(horde: Dictionary) -> int:
	for entry in _spawn_queue:
		if entry[0] == horde:
			return entry[1]
	return 0


func _materialize(horde: Dictionary) -> void:
	horde.live = true
	horde.zombies = []
	_spawn_queue.append([horde, horde.size])


## Poucos por quadro (criar 30 zumbis de uma vez dá um tranco).
func _process_spawn_queue() -> void:
	if _spawn_queue.is_empty():
		return
	var entry: Array = _spawn_queue[0]
	var horde: Dictionary = entry[0]
	var batch := mini(entry[1], 6)
	entry[1] -= batch
	if entry[1] <= 0:
		_spawn_queue.pop_front()
	if not horde.live:
		return
	var terrain := _terrain()
	for k in batch:
		var a := randf() * TAU
		var r := randf_range(1.0, 7.0)
		var p: Vector2 = horde.pos + Vector2(cos(a), sin(a)) * r
		var zombie: Zombie = ZOMBIE_SCENE.instantiate()
		zombie.position = Vector3(p.x, terrain.height_at(p.x, p.y) + 0.4, p.y)
		zombie.rotation.y = randf() * TAU
		zombie.set_meta("horde", horde.id)
		_world().get_node("Enemies").add_child(zombie)
		horde.zombies.append(zombie)


## Os parados marcham juntos para o destino da horda.
func _march(horde: Dictionary) -> void:
	var to: Vector2 = horde.dest - horde.pos
	if to.length() < 10.0:
		horde.dest = _random_city()
		to = horde.dest - horde.pos
	var ahead: Vector2 = horde.pos + to.normalized() * 25.0
	for z: Zombie in horde.zombies:
		var spread := Vector2(z.get_instance_id() % 7 - 3, (z.get_instance_id() / 7) % 7 - 3)
		z.march_to = Vector3(ahead.x + spread.x, z.global_position.y, ahead.y + spread.y)


func _dematerialize(horde: Dictionary) -> void:
	for entry in _spawn_queue.duplicate():
		if entry[0] == horde:
			horde.size = horde.zombies.size() + entry[1]
			_spawn_queue.erase(entry)
	for z in horde.zombies:
		if is_instance_valid(z):
			z.queue_free()
	horde.zombies = []
	horde.live = false


func _make_map_list() -> Array:
	var list := []
	for horde in hordes:
		list.append([horde.pos, horde.size])
	return list


# --- Hordas noturnas --------------------------------------------------------------------

func night_cap() -> int:
	var day := DayNight.i.day if DayNight.i else 1
	return mini(10 + day * 3, 30)


func _count_wave() -> void:
	var alive := 0
	for z in _wave_seen.keys():
		if not is_instance_valid(z):
			_wave_seen.erase(z) # sumiu ao amanhecer: não conta como abatido
		elif z.state == Zombie.State.DEAD:
			_wave_seen.erase(z)
			wave_killed += 1
		else:
			alive += 1
	wave_alive = alive


## Nova noite = nova onda: zera os abatidos.
func _on_nightfall() -> void:
	wave_killed = 0


func _night_spawns() -> void:
	var night := DayNight.i != null and DayNight.i.night > 0.6
	var enemies := _world().get_node("Enemies")
	var night_zombies := enemies.get_children().filter(func(z): return z is Zombie and z.has_meta("night") and z.state != Zombie.State.DEAD)
	if not night:
		# Amanheceu: os noturnos longe de todo mundo vão embora.
		for z: Zombie in night_zombies:
			if _distance_to_players(z.global_position) > 35.0:
				z.queue_free()
		return
	var terrain := _terrain()
	for player in _player_nodes():
		var near := night_zombies.filter(func(z): return z.global_position.distance_to(player.global_position) < 80.0).size()
		if near >= night_cap():
			continue
		for k in mini(3, night_cap() - near):
			var a := randf() * TAU
			var r := randf_range(45.0, 65.0)
			var p: Vector3 = player.global_position + Vector3(cos(a) * r, 0, sin(a) * r)
			p.y = terrain.height_at(p.x, p.z) + 0.4
			var zombie: Zombie = ZOMBIE_SCENE.instantiate()
			zombie.position = p
			zombie.set_meta("night", true)
			zombie.target = player
			enemies.add_child(zombie)
			_wave_seen[zombie] = true
			zombie.alert(player) # já sabe onde você está


func _player_nodes() -> Array:
	var list: Array = [_world().player]
	if Net.i.online():
		for peer in _world().puppets:
			if is_instance_valid(_world().puppets[peer]):
				list.append(_world().puppets[peer])
	return list.filter(func(p): return p.health > 0.0)


func _distance_to_players(at: Vector3) -> float:
	var best := INF
	for p in _players():
		best = minf(best, p.distance_to(at))
	return best


# --- Salvar / rede ---------------------------------------------------------------------

func persist_key() -> String:
	return "hordes"


func save_data() -> Dictionary:
	var list := []
	for horde in hordes:
		var size: int = horde.size
		if horde.live:
			size = horde.zombies.filter(func(z): return is_instance_valid(z) and z.state != Zombie.State.DEAD).size() + _queued(horde)
		if size > 0:
			list.append([horde.pos, horde.dest, size])
	return {"list": list, "next": _next_id, "map": _make_map_list()}


## Save (host) ou lista do mapa (clientes).
func load_data(data: Dictionary) -> void:
	if data.has("list") and Net.i.is_host():
		for horde in hordes:
			_dematerialize(horde)
		hordes.clear()
		for entry in data.list:
			hordes.append({"id": _next_id, "pos": entry[0], "dest": entry[1], "size": entry[2], "live": false, "zombies": []})
			_next_id += 1
		_next_id = maxi(_next_id, data.get("next", 1))
	map_list = data.get("map", map_list)
	if data.has("wave"):
		wave_alive = data.wave[0]
		wave_killed = data.wave[1]


func net_sync_to(peer: int) -> void:
	Net.i.send_system_state(peer, name, {"map": _make_map_list()})
