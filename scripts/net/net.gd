extends Node
## Autoload "Network" (acesse por Net.i): multiplayer cooperativo por LAN (ENet), até 32 jogadores.
##
## Quem manda em quê:
##   - Host: IA, vida e estado de todos os zumbis; quem pega cada item; quem
##     dirige cada carro. Também é o único com as teclas de admin (Z, H, Backspace).
##   - Cada jogador: o próprio boneco (posição enviada ~20x/s). Os golpes são
##     calculados por quem bate e mandados para o host aplicar no zumbi.
##   - Carro: quem dirige simula a física e manda a posição; nos outros ele é
##     só uma cópia que segue (fica com quem dirigiu por último).
##   - O mundo (terreno, cidades, pista, frutas) é gerado igual em todo mundo
##     pela mesma semente; só o que muda (itens pegos/soltos) passa pela rede.
##
## Zumbis nos clientes são "marionetes": não pensam, só seguem a posição/estado
## do host e repetem os eventos visuais (ragdoll, membro arrancado, levantar...).
##
## Sem rede (jogar sozinho) tudo funciona como antes: is_host() é true e as
## chamadas de rede viram chamadas locais.

signal peers_changed
signal servers_changed
signal message(text: String) ## avisos para o HUD (entrou, saiu, conexão)

const PORT := 7777
const DISCOVERY_PORT := 7778
const MAX_PLAYERS := 32
const GAME_ID := "GAMAMAKE1"
const MAIN_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const ZOMBIE_SNAP_RATE := 1.0 / 15.0
const CAR_SNAP_RATE := 1.0 / 20.0
const RELEVANCE := 170.0 ## zumbis mais longe que isso de um jogador não são enviados a ele

var player_name := "Jogador"
var world_seed := 0 ## 0 = semente padrão da cena
var peers := {} ## id -> nome (todos, inclusive o host)
var servers := {} ## ip -> {"name", "players", "max", "seen"} (achados na LAN)
var taken := {} ## chaves de itens que já foram pegos
var world: Node ## cena principal ativa (main.gd)

var _zombies := {} # net_id -> Zombie
var _next_zombie := 1
var _pickups := {} # chave -> PickupItem
var _drops := {} # chave -> [item_id, amount] (soltos durante a partida, para quem entrar depois)
var _next_drop := 1
var _pending_ready: Array[int] = [] # clientes que pediram o estado antes do mundo do host existir
var _udp: PacketPeerUDP
var _listen: PacketPeerUDP
var _broadcast_timer := 0.0
var _zombie_timer := 0.0
var _car_timer := 0.0
var _idle_car_timer := 0.0
var _resetting := false


func _enter_tree() -> void:
	Net.i = self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail("Não deu para conectar."))
	multiplayer.server_disconnected.connect(func(): _fail("O host fechou a partida."))
	# Linha de comando (testes / atalhos): -- --host  ou  -- --join=IP  --name=Fulano
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--name="):
			player_name = arg.substr(7)
		elif arg.begins_with("--seed="):
			world_seed = int(arg.substr(7))
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			host_game.call_deferred(player_name, world_seed)
		elif arg.begins_with("--join="):
			join_game.call_deferred(arg.substr(7), player_name)


# --- Estado ------------------------------------------------------------------

func online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer) \
			and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	return not online() or multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if online() else 1


func player_count() -> int:
	return maxi(peers.size(), 1)


# --- Conectar ----------------------------------------------------------------

func host_game(name: String, seed := 0) -> Error:
	leave(false)
	player_name = name
	world_seed = seed
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		message.emit("Não deu para abrir o servidor na porta %d." % PORT)
		return err
	multiplayer.multiplayer_peer = peer
	peers = {1: name}
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_udp.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	peers_changed.emit()
	get_tree().change_scene_to_file(MAIN_SCENE)
	return OK


func join_game(ip: String, name: String) -> Error:
	leave(false)
	player_name = name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		message.emit("Endereço inválido: %s" % ip)
		return err
	multiplayer.multiplayer_peer = peer
	message.emit("Conectando em %s..." % ip)
	return OK


## Sai da partida (e volta para o menu, se to_menu).
func leave(to_menu := true) -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_udp = null
	peers.clear()
	taken.clear()
	_drops.clear()
	_pending_ready.clear()
	_clear_world_refs()
	if to_menu:
		Engine.time_scale = 1.0
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU_SCENE)


func _fail(text: String) -> void:
	leave()
	message.emit(text)


func _on_connected() -> void:
	_hello.rpc_id(1, player_name, GAME_ID)


func _on_peer_disconnected(id: int) -> void:
	var name: String = peers.get(id, "?")
	peers.erase(id)
	peers_changed.emit()
	if world:
		world.remove_puppet(id)
	if multiplayer.is_server():
		_peers.rpc(peers)
		# Carros que eram dele voltam para o host.
		for car in _cars():
			if car.net_owner == id:
				_car_owner.rpc(String(car.name), 1, 0)
				_apply_car_owner(String(car.name), 1, 0)
	message.emit("%s saiu" % name)


@rpc("any_peer", "reliable")
func _hello(name: String, game: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if game != GAME_ID or peers.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	peers[id] = name
	_welcome.rpc_id(id, world_seed, taken.keys())
	_peers.rpc(peers)
	peers_changed.emit()
	message.emit("%s entrou" % name)


@rpc("authority", "reliable")
func _welcome(seed: int, taken_keys: Array) -> void:
	world_seed = seed
	taken.clear()
	for key in taken_keys:
		taken[key] = true
	get_tree().change_scene_to_file(MAIN_SCENE)


@rpc("authority", "reliable")
func _peers(list: Dictionary) -> void:
	peers = list
	peers_changed.emit()


# --- Mundo -------------------------------------------------------------------

## A cena principal avisa que está pronta (depois de criar o player).
func register_world(main: Node) -> void:
	world = main
	_resetting = false
	if not online():
		return
	if multiplayer.is_server():
		for id in _pending_ready:
			_send_world_state(id)
		_pending_ready.clear()
	else:
		_client_ready.rpc_id(1)


func unregister_world(main: Node) -> void:
	if world == main:
		_clear_world_refs()


func _clear_world_refs() -> void:
	world = null
	_zombies.clear()
	_pickups.clear()


@rpc("any_peer", "reliable")
func _client_ready() -> void:
	var id := multiplayer.get_remote_sender_id()
	if world == null:
		_pending_ready.append(id)
	else:
		_send_world_state(id)


## Tudo o que um cliente que acabou de entrar precisa saber.
func _send_world_state(id: int) -> void:
	_taken_all.rpc_id(id, taken.keys())
	for net_id in _zombies:
		var zombie: Zombie = _zombies[net_id]
		if is_instance_valid(zombie):
			_zspawn.rpc_id(id, net_id, zombie.spawn_data())
	for key in _drops:
		var item: PickupItem = _pickups.get(key)
		if is_instance_valid(item):
			_pspawn.rpc_id(id, key, _drops[key][0], _drops[key][1], item.global_transform, Vector3.ZERO)
	for car in _cars():
		_car_owner.rpc_id(id, String(car.name), car.net_owner, car.driver_peer)
		_csnap.rpc_id(id, String(car.name), car.global_transform, car.linear_velocity, car.steering, car.headlights_on)


@rpc("authority", "reliable")
func _taken_all(keys: Array) -> void:
	for key in keys:
		_taken(key)


## Admin (só o host): recomeça a partida para todo mundo.
func restart_world() -> void:
	if not is_host():
		return
	if online():
		taken.clear()
		_drops.clear()
		_restart.rpc()
	_restart()


@rpc("authority", "reliable")
func _restart() -> void:
	_resetting = true
	taken.clear()
	_clear_world_refs()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	_poll_discovery(delta)
	if not online() or world == null:
		return
	if multiplayer.is_server():
		_zombie_timer -= delta
		if _zombie_timer <= 0.0:
			_zombie_timer = ZOMBIE_SNAP_RATE
			_send_zombie_snapshots()
	_car_timer -= delta
	_idle_car_timer -= delta
	if _car_timer <= 0.0:
		_car_timer = CAR_SNAP_RATE
		var idle := _idle_car_timer <= 0.0
		if idle:
			_idle_car_timer = 0.5
		for car in _cars():
			if car.net_owner == my_id() and (car.driver_peer != 0 or idle or car.linear_velocity.length() > 0.3):
				_csnap.rpc(String(car.name), car.global_transform, car.linear_velocity, car.steering, car.headlights_on)


# --- Descoberta na LAN ---------------------------------------------------------

## Começa a ouvir servidores na rede (menu).
func start_listening() -> void:
	if _listen:
		return
	_listen = PacketPeerUDP.new()
	if _listen.bind(DISCOVERY_PORT) != OK:
		_listen = null


func stop_listening() -> void:
	if _listen:
		_listen.close()
	_listen = null
	servers.clear()


func _poll_discovery(delta: float) -> void:
	if _udp and online() and multiplayer.is_server():
		_broadcast_timer -= delta
		if _broadcast_timer <= 0.0:
			_broadcast_timer = 1.0
			var text := "%s|%s|%d|%d" % [GAME_ID, player_name, peers.size(), MAX_PLAYERS]
			_udp.put_packet(text.to_utf8_buffer())
	if _listen == null:
		return
	var changed := false
	while _listen.get_available_packet_count() > 0:
		var text := _listen.get_packet().get_string_from_utf8()
		var ip := _listen.get_packet_ip()
		var parts := text.split("|")
		if parts.size() == 4 and parts[0] == GAME_ID:
			changed = changed or not servers.has(ip)
			servers[ip] = {"name": parts[1], "players": int(parts[2]), "max": int(parts[3]), "seen": Time.get_ticks_msec()}
	for ip in servers.keys():
		if Time.get_ticks_msec() - servers[ip].seen > 4000:
			servers.erase(ip)
			changed = true
	if changed:
		servers_changed.emit()


# --- Jogadores -----------------------------------------------------------------

func send_player_state(state: Array) -> void:
	if online():
		_pstate.rpc(state)


@rpc("any_peer", "unreliable_ordered")
func _pstate(state: Array) -> void:
	if world:
		world.update_puppet(multiplayer.get_remote_sender_id(), state)


## Host: zumbi acertou o boneco de outro jogador -> o dano vai para ele.
func damage_player(peer: int, amount: float, direction: Vector3, attacker: Node) -> void:
	var zombie_id: int = attacker.net_id if attacker is Zombie else 0
	_pdamage.rpc_id(peer, amount, direction, zombie_id)


@rpc("authority", "reliable")
func _pdamage(amount: float, direction: Vector3, zombie_id: int) -> void:
	if world and world.player:
		world.player.take_damage(amount, direction, _zombies.get(zombie_id))


# --- Zumbis --------------------------------------------------------------------

func register_zombie(zombie: Zombie) -> void:
	if zombie.puppet:
		_zombies[zombie.net_id] = zombie
		return
	zombie.net_id = _next_zombie
	_next_zombie += 1
	_zombies[zombie.net_id] = zombie
	if online():
		_zspawn.rpc(zombie.net_id, zombie.spawn_data())


func unregister_zombie(zombie: Zombie) -> void:
	if _zombies.get(zombie.net_id) == zombie:
		_zombies.erase(zombie.net_id)
		if online() and multiplayer.is_server() and not zombie.puppet and not _resetting:
			_zfree.rpc(zombie.net_id)


func get_zombie(net_id: int) -> Zombie:
	return _zombies.get(net_id)


@rpc("authority", "reliable")
func _zspawn(net_id: int, data: Dictionary) -> void:
	if world and not _zombies.has(net_id):
		world.spawn_puppet_zombie(net_id, data)


@rpc("authority", "reliable")
func _zfree(net_id: int) -> void:
	var zombie: Zombie = _zombies.get(net_id)
	_zombies.erase(net_id)
	if is_instance_valid(zombie):
		zombie.queue_free()


## Host: algo visual aconteceu com o zumbi (ragdoll, membro, levantar...).
func zombie_event(zombie: Zombie, event: String, args: Array) -> void:
	if online() and multiplayer.is_server():
		_zev.rpc(zombie.net_id, event, args)


@rpc("authority", "reliable")
func _zev(net_id: int, event: String, args: Array) -> void:
	var zombie: Zombie = _zombies.get(net_id)
	if is_instance_valid(zombie):
		zombie.callv("_ev_" + event, args)


## Cliente: golpe/empurrão num zumbi marionete -> o host aplica no de verdade.
func zombie_call(zombie: Zombie, method: String, args: Array, reliable := true) -> void:
	if not online():
		return
	if reliable:
		_zcall.rpc_id(1, zombie.net_id, method, args)
	else:
		_zcall_fast.rpc_id(1, zombie.net_id, method, args)


@rpc("any_peer", "reliable")
func _zcall(net_id: int, method: String, args: Array) -> void:
	var zombie: Zombie = _zombies.get(net_id)
	if is_instance_valid(zombie):
		zombie.call_from_peer(multiplayer.get_remote_sender_id(), method, args)


@rpc("any_peer", "unreliable_ordered")
func _zcall_fast(net_id: int, method: String, args: Array) -> void:
	_zcall(net_id, method, args)


func _send_zombie_snapshots() -> void:
	if _zombies.is_empty():
		return
	for peer in multiplayer.get_peers():
		var center: Vector3 = world.puppet_position(peer)
		var list := []
		for net_id in _zombies:
			var zombie: Zombie = _zombies[net_id]
			if is_instance_valid(zombie) and zombie.global_position.distance_to(center) < RELEVANCE:
				list.append(zombie.snapshot())
		if not list.is_empty():
			_zsnap.rpc_id(peer, list)


@rpc("authority", "unreliable_ordered")
func _zsnap(list: Array) -> void:
	for entry in list:
		var zombie: Zombie = _zombies.get(entry[0])
		if is_instance_valid(zombie):
			zombie.apply_snapshot(entry)


# --- Itens ---------------------------------------------------------------------

func register_pickup(item: PickupItem) -> void:
	if item.net_key == "":
		return
	if taken.has(item.net_key):
		item.queue_free()
		return
	_pickups[item.net_key] = item


func unregister_pickup(item: PickupItem) -> void:
	if item.net_key != "" and _pickups.get(item.net_key) == item:
		_pickups.erase(item.net_key)


## Jogador quer pegar o item: o host decide quem chega primeiro.
func request_pickup(item: PickupItem) -> void:
	if not online() or item.net_key == "":
		item.take_locally(world.player if world else null)
		return
	if multiplayer.is_server():
		_try_take(1, item.net_key, item.item_id, item.amount)
	else:
		_req_pickup.rpc_id(1, item.net_key, item.item_id, item.amount)


@rpc("any_peer", "reliable")
func _req_pickup(key: String, item_id: StringName, amount: int) -> void:
	_try_take(multiplayer.get_remote_sender_id(), key, item_id, amount)


func _try_take(peer: int, key: String, item_id: StringName, amount: int) -> void:
	if taken.has(key):
		return
	var item: PickupItem = _pickups.get(key)
	var where: Transform3D = item.global_transform if is_instance_valid(item) else Transform3D()
	_taken.rpc(key)
	_taken(key)
	if peer == 1:
		_give(item_id, amount, where)
	else:
		_give.rpc_id(peer, item_id, amount, where)


@rpc("authority", "reliable")
func _give(item_id: StringName, amount: int, where: Transform3D) -> void:
	if world == null or world.player == null:
		return
	var left: int = world.player.pick_up(item_id, ItemDB.display_name(item_id), amount)
	if left > 0: # não coube tudo: o resto volta para o chão
		drop_item(item_id, left, where, Vector3.ZERO)


@rpc("authority", "reliable")
func _taken(key: String) -> void:
	taken[key] = true
	_drops.erase(key)
	var item: PickupItem = _pickups.get(key)
	_pickups.erase(key)
	if is_instance_valid(item):
		item.collision_layer = 0
		item.remove_from_group("interactable")
		item.queue_free()


## Solta um item no mundo (player soltando, zumbi largando a arma).
func drop_item(item_id: StringName, amount: int, where: Transform3D, impulse: Vector3) -> void:
	if not online():
		if world:
			world.spawn_pickup("", item_id, amount, where, impulse)
		return
	if multiplayer.is_server():
		var key := "d%d" % _next_drop
		_next_drop += 1
		_drops[key] = [item_id, amount]
		_pspawn.rpc(key, item_id, amount, where, impulse)
		_pspawn(key, item_id, amount, where, impulse)
	else:
		_req_drop.rpc_id(1, item_id, amount, where, impulse)


@rpc("any_peer", "reliable")
func _req_drop(item_id: StringName, amount: int, where: Transform3D, impulse: Vector3) -> void:
	drop_item(item_id, amount, where, impulse)


@rpc("authority", "reliable")
func _pspawn(key: String, item_id: StringName, amount: int, where: Transform3D, impulse: Vector3) -> void:
	if world and not _pickups.has(key) and not taken.has(key):
		world.spawn_pickup(key, item_id, amount, where, impulse)


# --- Carros --------------------------------------------------------------------

func _cars() -> Array:
	if world == null:
		return []
	return world.get_tree().get_nodes_in_group("vehicle")


func _car(name: String) -> VintageCar:
	if world == null:
		return null
	return world.get_node_or_null(name) as VintageCar


## Jogador apertou E no carro.
func request_car(car: VintageCar) -> void:
	if not online():
		world.player.enter_vehicle(car)
	elif multiplayer.is_server():
		_try_car(1, String(car.name))
	else:
		_req_car.rpc_id(1, String(car.name))


@rpc("any_peer", "reliable")
func _req_car(name: String) -> void:
	_try_car(multiplayer.get_remote_sender_id(), name)


func _try_car(peer: int, name: String) -> void:
	var car := _car(name)
	if car == null or car.driver_peer != 0:
		return
	_car_owner.rpc(name, peer, peer)
	_apply_car_owner(name, peer, peer)


## Saiu do carro: continua dono (o carro parado segue simulado por ele).
func leave_car(car: VintageCar) -> void:
	if not online():
		return
	_car_owner.rpc(String(car.name), my_id(), 0)
	_apply_car_owner(String(car.name), my_id(), 0)


@rpc("any_peer", "reliable")
func _car_owner(name: String, owner: int, driver: int) -> void:
	var car := _car(name)
	var sender := multiplayer.get_remote_sender_id()
	if car == null or (sender != 1 and sender != car.net_owner):
		return # só o host ou o dono atual mudam o dono
	_apply_car_owner(name, owner, driver)


func _apply_car_owner(name: String, owner: int, driver: int) -> void:
	var car := _car(name)
	if car == null:
		return
	car.set_net_owner(owner, driver)
	if driver == my_id() and world.player.vehicle != car:
		world.player.enter_vehicle(car)
		if world.player.vehicle != car:
			leave_car(car) # não deu para entrar agora (no meio de um golpe): libera o carro


@rpc("any_peer", "unreliable_ordered")
func _csnap(name: String, xform: Transform3D, velocity: Vector3, steering: float, lights: bool) -> void:
	var car := _car(name)
	if car == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != car.net_owner and sender != 1:
		return
	if car.net_owner != my_id():
		car.apply_snapshot(xform, velocity, steering, lights)


# --- Efeitos -------------------------------------------------------------------

## Efeitos que os outros jogadores precisam ver (tiro, míssil).
func fx(kind: String, args: Array) -> void:
	if online():
		_fx.rpc(kind, args)


@rpc("any_peer", "unreliable")
func _fx(kind: String, args: Array) -> void:
	if world:
		world.play_fx(kind, args)
