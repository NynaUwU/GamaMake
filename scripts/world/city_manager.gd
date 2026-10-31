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
var _flickering: Array = [] # luzes de poste com mau contato
var _flicker_time := 0.0
const MAX_LAMP_LIGHTS := 45 ## por cidade (o resto dos postes fica apagado)
var _lamps_on := true
var _house_tasks: Array = [] # [cidade, lote, id da tarefa]
var _house_results := {} # "cidade_lote" -> Node3D montado na thread
var _house_mutex := Mutex.new()


func _ready() -> void:
	CityGen.material() # cria o material compartilhado aqui (as threads só usam)
	var _plans := HousePlans.PLANS.size() # carrega a classe aqui, não dentro das threads
	_terrain = get_node(terrain_path) as TerrainWorld
	_player = get_node(player_path) as Node3D


func _process(delta: float) -> void:
	if _terrain == null or _player == null:
		return
	_flicker(delta)
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_update_cities()
	# As casas são montadas (malha + colisão) em threads do WorkerThreadPool;
	# aqui só entram na cena as que ficaram prontas (algumas por frame).
	var budget := houses_per_frame * 3
	for index in _built:
		var entry: Dictionary = _built[index]
		var city: Dictionary = _terrain.cities[index]
		while entry.queued < city.lots.size() and _house_tasks.size() < 24:
			var lot: Dictionary = city.lots[entry.queued]
			_house_tasks.append([index, entry.queued, WorkerThreadPool.add_task(_build_house_task.bind(index, entry.queued, lot), true)])
			entry.queued += 1
	for task in _house_tasks.duplicate():
		if budget <= 0:
			break
		if not WorkerThreadPool.is_task_completed(task[2]):
			continue
		WorkerThreadPool.wait_for_task_completion(task[2])
		_house_tasks.erase(task)
		_house_mutex.lock()
		var house: Node3D = _house_results.get("%d_%d" % [task[0], task[1]])
		_house_results.erase("%d_%d" % [task[0], task[1]])
		_house_mutex.unlock()
		if not _built.has(task[0]) or house == null:
			if house:
				house.free() # a cidade sumiu enquanto a casa era montada
			continue
		var entry: Dictionary = _built[task[0]]
		var city: Dictionary = _terrain.cities[task[0]]
		_place_house(entry.node, city, city.lots[task[1]], house)
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
			_add_lamps(node, city)
			_built[i] = {"node": node, "next": 0, "queued": 0}
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
			entry.queued = city.lots.size()


## Postes ao longo das ruas, alternando os lados. Cenário de fim de mundo:
## alguns tortos, alguns piscando e alguns quebrados (apagados).
func _add_lamps(city_node: Node3D, city: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = city.seed + 11
	var lights := 0
	var spacing := 24.0 if city.size != "small" else 34.0
	for street: Dictionary in city.streets:
		var a: Vector2 = street.a
		var b: Vector2 = street.b
		var length := a.distance_to(b)
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var count := int(length / spacing)
		for k in count:
			if rng.randf() > 0.7:
				continue # poste caído/levado: falta
			var flip := 1.0 if k % 2 == 0 else -1.0
			var p: Vector2 = a + dir * (spacing * (k + 0.5)) + side * flip * (street.width * 0.5 + 0.7) - city.center
			var lit := rng.randf() > 0.2 and lights < MAX_LAMP_LIGHTS
			var tilt := rng.randf_range(0.12, 0.3) * (1.0 if rng.randf() < 0.5 else -1.0) if rng.randf() < 0.2 else 0.0
			var lamp := CityGen.build_lamp(rng, lit, tilt)
			lamp.position = Vector3(p.x, 0, p.y)
			lamp.rotation.y = atan2(side.x * flip, side.y * flip) + PI * 0.5
			city_node.add_child(lamp)
			if lit:
				lights += 1
				var light: OmniLight3D = lamp.get_node("Light")
				light.add_to_group("street_light")
				light.set_meta("energy", light.light_energy)
				if rng.randf() < 0.25:
					_flickering.append(light) # mau contato: pisca


func _flicker(delta: float) -> void:
	_flicker_time += delta
	# Postes só acesos de noite (acendem no fim da tarde).
	var lit := DayNight.i == null or DayNight.i.night > 0.25
	if lit != _lamps_on or int(_flicker_time * 2.0) != int((_flicker_time - delta) * 2.0):
		_lamps_on = lit
		for light: OmniLight3D in get_tree().get_nodes_in_group("street_light"):
			light.visible = lit
	if not lit:
		return
	_flickering = _flickering.filter(func(l): return is_instance_valid(l))
	for light: OmniLight3D in _flickering:
		var seed := float(light.get_instance_id() % 997)
		var n := sin(_flicker_time * 23.0 + seed) * sin(_flicker_time * 7.3 + seed * 1.7)
		# Fica quase sempre aceso e de vez em quando apaga/treme.
		light.light_energy = 0.05 if n > 0.55 else (0.8 if n > 0.3 else 1.4)


## Roda numa thread: monta a casa fora da cena (permitido enquanto não entra na árvore).
func _build_house_task(index: int, lot_index: int, lot: Dictionary) -> void:
	var house := CityGen.build_house(lot)
	_house_mutex.lock()
	_house_results["%d_%d" % [index, lot_index]] = house
	_house_mutex.unlock()


func _exit_tree() -> void:
	for task in _house_tasks:
		WorkerThreadPool.wait_for_task_completion(task[2])
	for house in _house_results.values():
		if is_instance_valid(house):
			house.free()


func _add_house(city_node: Node3D, city: Dictionary, lot: Dictionary) -> void:
	_place_house(city_node, city, lot, CityGen.build_house(lot))


func _place_house(city_node: Node3D, city: Dictionary, lot: Dictionary, house: Node3D) -> void:
	var local: Vector2 = lot.pos - city.center
	house.position = Vector3(local.x, 0.0, local.y)
	house.rotation.y = lot.yaw
	city_node.add_child(house)
	CityGen.furnish(house, lot)
	_add_loot(house, lot)


## Baú/armário/caixote na frente de ~65% das casas (escombros: caixote de ruína).
func _add_loot(house: Node3D, lot: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = lot.seed + 77
	if rng.randf() > 0.65:
		return
	var style: String = "caixote" if lot.ruin else LootBox.STYLES[rng.randi() % LootBox.STYLES.size()]
	var table: String = "ruina" if lot.ruin else ("caixote" if style == "caixote" else "casa")
	var box := LootBox.new()
	box.name = "Loot"
	box.setup("loot_%d" % lot.seed, style, table)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	box.position = Vector3(side * rng.randf_range(1.2, maxf(1.3, lot.w * 0.4)), 0.0, -lot.d * 0.5 - 0.75)
	box.rotation.y = PI + rng.randf_range(-0.25, 0.25) # frente para a rua
	house.add_child(box)


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
