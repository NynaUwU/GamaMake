class_name SaveGame
extends RefCounted
## Salvar e carregar o mundo. Um arquivo por mundo em user://saves/<nome>.save
## (store_var: guarda Vector3, Transform3D, PackedByteArray direto).
##
## O que vai no arquivo:
##   - semente do mapa (o terreno/cidades são gerados de novo, iguais);
##   - itens já pegos (do cenário e frutas) e itens soltos no chão;
##   - construções (peças, recortes, portas/janelas);
##   - carros (posição, faróis);
##   - jogador: posição, direção, vida, inventário (+ os outros jogadores do
##     multiplayer, pelo nome: quem voltar recebe o que tinha);
##   - qualquer nó no grupo "persist" (fome, plantações, baús, hora do dia...):
##     ele implementa persist_key() -> String, save_data() -> Variant e
##     load_data(dados). Assim cada sistema novo se salva sozinho.
##
## Só o host (ou o jogo solo) salva o mundo. Autosave a cada AUTOSAVE segundos.

const DIR := "user://saves/"
const VERSION := 1
const AUTOSAVE := 120.0

static var current := "" ## nome do mundo aberto ("" = ainda não salvo)
static var pending: Dictionary = {} ## save esperando a cena principal ficar pronta


static func path(name: String) -> String:
	return DIR + name + ".save"


## Lista os saves, do mais recente para o mais antigo: [{name, time, seed}].
static func list() -> Array:
	var result := []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return result
	for file in dir.get_files():
		if not file.ends_with(".save"):
			continue
		var name := file.trim_suffix(".save")
		result.append({"name": name, "time": FileAccess.get_modified_time(path(name))})
	result.sort_custom(func(a, b): return a.time > b.time)
	return result


static func exists(name: String) -> bool:
	return FileAccess.file_exists(path(name))


static func delete(name: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path(name)))


static func read(name: String) -> Dictionary:
	var file := FileAccess.open(path(name), FileAccess.READ)
	if file == null:
		return {}
	var data = file.get_var()
	return data if data is Dictionary and data.get("version", 0) >= 1 else {}


## Nome livre para um mundo novo: "Mundo 1", "Mundo 2"...
static func new_name() -> String:
	var n := 1
	while exists("Mundo %d" % n):
		n += 1
	return "Mundo %d" % n


# --- Salvar ----------------------------------------------------------------------

## Junta tudo e grava. Devolve true se gravou.
static func save(world: Node, name := "") -> bool:
	if world == null or not Net.i.is_host():
		return false
	if name == "":
		name = current if current != "" else new_name()
	var data := collect(world)
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(path(name), FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(data)
	file.close()
	current = name
	return true


static func collect(world: Node) -> Dictionary:
	var data := {"version": VERSION, "time": Time.get_unix_time_from_system()}
	var terrain := world.get_node_or_null("Terrain")
	data.seed = terrain.seed if terrain else Net.i.world_seed
	data.taken = Net.i.taken.keys()
	# Itens soltos (do jogador, de zumbi, que não couberam): os do cenário
	# e as frutas nascem de novo sozinhos, então só os sem dono ("" ou "d…").
	var drops := []
	for item in world.get_tree().get_nodes_in_group("interactable"):
		if item is PickupItem and not item.is_queued_for_deletion() and (item.net_key == "" or item.net_key.begins_with("d")):
			drops.append([item.item_id, item.amount, item.global_transform])
	data.drops = drops
	var building := world.get_node_or_null("Building")
	data.building = building.state() if building else []
	var cars := {}
	for car in world.get_tree().get_nodes_in_group("vehicle"):
		if car is VintageCar and car.is_inside_tree() and car.get_parent() == world:
			cars[String(car.name)] = [car.global_transform, car.headlights_on]
	data.cars = cars
	data.player = player_data(world.player)
	var others: Dictionary = Net.i.player_saves.duplicate(true)
	data.players = others
	var persist := {}
	for node in world.get_tree().get_nodes_in_group("persist"):
		if node.has_method("persist_key") and node.has_method("save_data"):
			persist[node.persist_key()] = node.save_data()
	data.persist = persist
	return data


## Estado de um jogador (o daqui ou, no cliente, o próprio para mandar ao host).
static func player_data(player: Player) -> Dictionary:
	if player == null:
		return {}
	var slots := []
	for slot in player.inventory.slots:
		slots.append(slot.duplicate())
	var data := {
		"position": player.global_position,
		"yaw": player.rotation.y,
		"pitch": player.head.rotation.x,
		"health": player.health,
		"slots": slots,
		"selected": player.inventory.selected,
	}
	if player.has_method("save_extra"):
		data.extra = player.save_extra()
	return data


# --- Carregar --------------------------------------------------------------------

## Menu: abre o mundo salvo (solo). A cena principal aplica o resto em apply().
static func load_world(name: String) -> bool:
	var data := read(name)
	if data.is_empty():
		return false
	Net.i.leave(false)
	Net.i.world_seed = data.get("seed", 0)
	current = name
	pending = data
	Net.i.player_saves = data.get("players", {}).duplicate(true)
	for key in data.get("taken", []):
		Net.i.taken[key] = true
	Net.i.get_tree().change_scene_to_file(Net.i.MAIN_SCENE)
	return true


## Mundo novo (solo ou servidor): esquece o save aberto.
static func start_new() -> void:
	current = ""
	pending = {}
	if Net.i:
		Net.i.player_saves.clear()


## Chamado pela cena principal quando está pronta.
static func apply(world: Node) -> void:
	if pending.is_empty():
		return
	var data := pending
	pending = {}
	# Itens já pegos que nasceram antes do taken ser lido somem agora.
	for item in world.get_tree().get_nodes_in_group("interactable"):
		if item is PickupItem and item.net_key != "" and Net.i.taken.has(item.net_key):
			item.queue_free()
	for drop in data.get("drops", []):
		world.spawn_pickup("", drop[0], drop[1], drop[2], Vector3.ZERO)
	var building := world.get_node_or_null("Building")
	if building:
		building.load_state(data.get("building", []))
	var cars: Dictionary = data.get("cars", {})
	for car in world.get_tree().get_nodes_in_group("vehicle"):
		if car is VintageCar and cars.has(String(car.name)):
			var entry: Array = cars[String(car.name)]
			car.global_transform = entry[0]
			car.linear_velocity = Vector3.ZERO
			car.angular_velocity = Vector3.ZERO
			car.set_headlights(entry[1])
	apply_player(world.player, data.get("player", {}))
	var persist: Dictionary = data.get("persist", {})
	for node in world.get_tree().get_nodes_in_group("persist"):
		if node.has_method("persist_key") and persist.has(node.persist_key()):
			node.load_data(persist[node.persist_key()])


static func apply_player(player: Player, data: Dictionary) -> void:
	if player == null or data.is_empty():
		return
	# Gera o chão em volta antes (senão o jogador cai pelo mapa ainda vazio).
	var terrain := player.get_tree().current_scene.get_node_or_null("Terrain") as TerrainWorld
	if terrain:
		terrain.update_around(data.position, -1, 140.0)
	player.global_position = data.position
	player.velocity = Vector3.ZERO
	player.rotation.y = data.get("yaw", 0.0)
	player.head.rotation.x = data.get("pitch", 0.0)
	player.health = data.get("health", player.max_health)
	player.health_changed.emit(player.health, player.max_health)
	var slots: Array = data.get("slots", [])
	for i in mini(slots.size(), player.inventory.slots.size()):
		player.inventory.slots[i] = slots[i].duplicate()
	player.inventory.changed.emit()
	player.inventory.select(data.get("selected", 0))
	if data.has("extra") and player.has_method("load_extra"):
		player.load_extra(data.extra)
