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

const PORT := 7777 ## primeira porta tentada (se estiver ocupada, tenta as próximas)
const DISCOVERY_PORT := 7778 ## onde o host responde "quem está aí?" (também tenta as próximas)
const PORT_TRIES := 6
const MAX_PLAYERS := 32
const GAME_ID := "GAMAMAKE1"
const MAIN_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const ZOMBIE_SNAP_RATE := 1.0 / 15.0
const CAR_SNAP_RATE := 1.0 / 20.0
const RELEVANCE := 170.0 ## zumbis mais longe que isso de um jogador não são enviados a ele

var player_name := "Jogador"
var port := PORT ## porta do jogo deste host
var world_seed := 0 ## 0 = semente padrão da cena
var peers := {} ## id -> nome (todos, inclusive o host)
var servers := {} ## "nome|porta" -> {"ip", "port", "name", "players", "max", "seen"} (achados na LAN)
var taken := {} ## chaves de itens que já foram pegos
var player_saves := {} ## host: nome -> último estado salvo de cada jogador (SaveGame)
var request_peer := 1 ## host: quem fez o pedido que está sendo aplicado agora (system_request)
var world: Node ## cena principal ativa (main.gd)

var _zombies := {} # net_id -> Zombie
var _next_zombie := 1
var _pickups := {} # chave -> PickupItem
var _drops := {} # chave -> [item_id, amount] (soltos durante a partida, para quem entrar depois)
var _next_drop := 1
var _pending_ready: Array[int] = [] # clientes que pediram o estado antes do mundo do host existir
var _answer: PacketPeerUDP # host: responde as perguntas dos clientes
var _listen: PacketPeerUDP # cliente: pergunta na rede e recebe as respostas
var _query_timer := 0.0
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

## Cria a partida e entra nela (menu → "Criar servidor").
func host_game(name: String, seed := 0) -> Error:
	leave(false)
	player_name = name
	world_seed = seed
	var err := _start_server()
	if err == OK:
		get_tree().change_scene_to_file(MAIN_SCENE)
	return err


## Como o "Abrir para LAN" do Minecraft: transforma a partida solo que está
## rodando em servidor, sem recarregar nada.
func open_to_lan() -> Error:
	if online() or world == null:
		return ERR_UNAVAILABLE
	var terrain := world.get_node_or_null("Terrain")
	if terrain:
		world_seed = terrain.seed # quem entrar gera exatamente este mapa
	# Itens soltos antes de abrir ganham nome de rede (quem entrar também vê).
	for item in world.get_tree().get_nodes_in_group("interactable"):
		if item is PickupItem and item.net_key == "" and not item.is_queued_for_deletion():
			item.net_key = "d%d" % _next_drop
			_next_drop += 1
			_drops[item.net_key] = [item.item_id, item.amount]
			_pickups[item.net_key] = item
	var err := _start_server()
	if err == OK:
		message.emit("Partida aberta na rede local (porta %d)" % port)
	return err


func _start_server() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := ERR_CANT_CREATE
	for k in PORT_TRIES:
		err = peer.create_server(PORT + k * 2, MAX_PLAYERS - 1)
		if err == OK:
			port = PORT + k * 2
			break
	if err != OK:
		message.emit("Não deu para abrir o servidor (portas %d a %d ocupadas)." % [PORT, PORT + PORT_TRIES * 2])
		return err
	multiplayer.multiplayer_peer = peer
	peers = {1: player_name}
	# Responde quem perguntar "tem partida aí?" (resposta direta, não precisa de broadcast).
	_answer = PacketPeerUDP.new()
	for k in PORT_TRIES:
		if _answer.bind(DISCOVERY_PORT + k * 2) == OK:
			break
	peers_changed.emit()
	return OK


## Entra numa partida. "ip" pode ser "192.168.0.10" ou "192.168.0.10:7779".
func join_game(ip: String, name: String, game_port := PORT) -> Error:
	if ip.contains(":"):
		game_port = int(ip.get_slice(":", 1))
		ip = ip.get_slice(":", 0)
	leave(false)
	player_name = name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, game_port)
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
	if _answer:
		_answer.close()
	_answer = null
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
			_pspawn.rpc_id(id, key, _drops[key][0], _drops[key][1], item.global_transform, Vector3.ZERO, item.dur)
	if world.get_node_or_null("Building"):
		_build_state.rpc_id(id, world.get_node("Building").state())
	# Voltou para um mundo salvo: recebe posição, vida e inventário que tinha.
	var saved: Dictionary = player_saves.get(peers.get(id, ""), {})
	if not saved.is_empty():
		_restore_player.rpc_id(id, saved)
	for node in world.get_tree().get_nodes_in_group("persist"):
		if node.has_method("net_sync_to"):
			node.net_sync_to(id)
	for car in _cars():
		_car_owner.rpc_id(id, String(car.name), car.net_owner, car.driver_peer)
		_csnap.rpc_id(id, String(car.name), car.global_transform, car.linear_velocity, car.steering, car.headlights_on)


@rpc("authority", "reliable")
func _restore_player(data: Dictionary) -> void:
	if world:
		SaveGame.apply_player(world.player, data)


## Host vai salvar: pede a cada cliente o estado do próprio jogador.
func request_player_saves() -> void:
	if online() and multiplayer.is_server():
		_req_psave.rpc()


@rpc("authority", "reliable")
func _req_psave() -> void:
	if world:
		_psave.rpc_id(1, SaveGame.player_data(world.player))


@rpc("any_peer", "reliable")
func _psave(data: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if peers.has(id) and data.get("slots") is Array:
		player_saves[peers[id]] = data


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

## Como o Minecraft acha partidas na LAN, mas ao contrário: o cliente PERGUNTA
## (broadcast saindo de uma porta qualquer) e o host RESPONDE direto para ele.
## Resposta a uma pergunta que o próprio cliente fez passa pelo firewall sem
## regra nenhuma, então quem entra não precisa liberar nada. Só o host recebe
## conexões (o Windows pergunta uma vez "Permitir acesso?" para o jogo, igual
## acontece com o Java do Minecraft).
func start_listening() -> void:
	if _listen:
		return
	_listen = PacketPeerUDP.new()
	_listen.set_broadcast_enabled(true)
	if _listen.bind(0) != OK: # porta aleatória só para as respostas
		_listen = null
	_query_timer = 0.0


func stop_listening() -> void:
	if _listen:
		_listen.close()
	_listen = null
	servers.clear()


## Endereços para perguntar: broadcast geral, broadcast de cada rede deste PC
## (roteadores que bloqueiam o geral) e o próprio PC (host e cliente juntos).
func _query_targets() -> Array[String]:
	var targets: Array[String] = ["255.255.255.255", "127.0.0.1"]
	for iface in IP.get_local_interfaces():
		for address: String in iface.addresses:
			var parts := address.split(".")
			if parts.size() == 4 and not address.begins_with("127."):
				var subnet := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
				if subnet not in targets:
					targets.append(subnet)
	return targets


func _poll_discovery(delta: float) -> void:
	# Host: responde quem perguntou.
	if _answer and online() and multiplayer.is_server():
		while _answer.get_available_packet_count() > 0:
			var question := _answer.get_packet().get_string_from_utf8()
			if question == GAME_ID + "?":
				var reply := "%s|%s|%d|%d|%d" % [GAME_ID, player_name, peers.size(), MAX_PLAYERS, port]
				_answer.set_dest_address(_answer.get_packet_ip(), _answer.get_packet_port())
				_answer.put_packet(reply.to_utf8_buffer())
	if _listen == null:
		return
	# Cliente: pergunta a cada segundo e junta as respostas.
	_query_timer -= delta
	if _query_timer <= 0.0:
		_query_timer = 1.0
		for target in _query_targets():
			for k in PORT_TRIES:
				_listen.set_dest_address(target, DISCOVERY_PORT + k * 2)
				_listen.put_packet((GAME_ID + "?").to_utf8_buffer())
	var changed := false
	while _listen.get_available_packet_count() > 0:
		var text := _listen.get_packet().get_string_from_utf8()
		var ip := _listen.get_packet_ip()
		var parts := text.split("|")
		if parts.size() == 5 and parts[0] == GAME_ID:
			# O mesmo host responde por vários caminhos (rede e 127.0.0.1): uma entrada só.
			var key := "%s|%s" % [parts[1], parts[4]]
			if not servers.has(key):
				changed = true
				servers[key] = {"ip": ip}
			servers[key].merge({"name": parts[1], "players": int(parts[2]), "max": int(parts[3]),
				"port": int(parts[4]), "seen": Time.get_ticks_msec()}, true)
	for key in servers.keys():
		if Time.get_ticks_msec() - servers[key].seen > 4000:
			servers.erase(key)
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


## Golpe/soco/chute/tiro do próprio jogador: os outros tocam a animação no boneco dele.
func send_player_action(action: String, arg: int) -> void:
	if online():
		_paction.rpc(action, arg)


@rpc("any_peer", "reliable")
func _paction(action: String, arg: int) -> void:
	if world:
		var puppet: Node = world.puppets.get(multiplayer.get_remote_sender_id())
		if is_instance_valid(puppet):
			puppet.play_net_action(action, arg)


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
		# Até 8 zumbis por pacote: cabe num pacote UDP (~1400 bytes) sem ser picotado.
		for start in range(0, list.size(), 8):
			_zsnap.rpc_id(peer, list.slice(start, start + 8))


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
		if item.net_key != "" and item.is_queued_for_deletion():
			taken[item.net_key] = true # se abrir para LAN depois, quem entrar já não vê
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
	var dur: float = item.dur if is_instance_valid(item) else 1.0
	_taken.rpc(key)
	_taken(key)
	if peer == 1:
		_give(item_id, amount, where, dur)
	else:
		_give.rpc_id(peer, item_id, amount, where, dur)


@rpc("authority", "reliable")
func _give(item_id: StringName, amount: int, where: Transform3D, dur := 1.0) -> void:
	if world == null or world.player == null:
		return
	var left: int = world.player.pick_up(item_id, ItemDB.display_name(item_id), amount, dur)
	if left > 0: # não coube tudo: o resto volta para o chão
		drop_item(item_id, left, where, Vector3.ZERO, dur)


@rpc("authority", "reliable")
func _taken(key: String) -> void:
	taken[key] = true
	looted.emit(key)
	_drops.erase(key)
	var item: PickupItem = _pickups.get(key)
	_pickups.erase(key)
	if is_instance_valid(item):
		item.collision_layer = 0
		item.remove_from_group("interactable")
		item.queue_free()


## Transforma um item do chão em outro (tronco cortado com o machado -> tábuas).
func convert_pickup(item: PickupItem, new_id: StringName, amount: int) -> void:
	if item.is_queued_for_deletion():
		return
	var where := item.global_transform
	if not online() or item.net_key == "":
		if item.net_key != "":
			taken[item.net_key] = true
		item.queue_free()
		drop_item(new_id, amount, where, Vector3(0, 2.0, 0))
	elif multiplayer.is_server():
		_do_convert(item.net_key, new_id, amount, where)
	else:
		_req_convert.rpc_id(1, item.net_key, new_id, amount, where)


@rpc("any_peer", "reliable")
func _req_convert(key: String, new_id: StringName, amount: int, where: Transform3D) -> void:
	if new_id in [&"tabua", &"graveto"] and amount <= 200:
		_do_convert(key, new_id, amount, where)


func _do_convert(key: String, new_id: StringName, amount: int, where: Transform3D) -> void:
	if taken.has(key):
		return
	_taken.rpc(key)
	_taken(key)
	drop_item(new_id, amount, where, Vector3(0, 2.0, 0))


## Solta um item no mundo (player soltando, zumbi largando a arma).
func drop_item(item_id: StringName, amount: int, where: Transform3D, impulse: Vector3, dur := 1.0) -> void:
	if not online():
		if world:
			world.spawn_pickup("", item_id, amount, where, impulse, dur)
		return
	if multiplayer.is_server():
		var key := "d%d" % _next_drop
		_next_drop += 1
		_drops[key] = [item_id, amount, dur]
		_pspawn.rpc(key, item_id, amount, where, impulse, dur)
		_pspawn(key, item_id, amount, where, impulse, dur)
	else:
		_req_drop.rpc_id(1, item_id, amount, where, impulse, dur)


@rpc("any_peer", "reliable")
func _req_drop(item_id: StringName, amount: int, where: Transform3D, impulse: Vector3, dur := 1.0) -> void:
	drop_item(item_id, amount, where, impulse, dur)


@rpc("authority", "reliable")
func _pspawn(key: String, item_id: StringName, amount: int, where: Transform3D, impulse: Vector3, dur := 1.0) -> void:
	if world and not _pickups.has(key) and not taken.has(key):
		world.spawn_pickup(key, item_id, amount, where, impulse, dur)


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


# --- Construção -----------------------------------------------------------------

## Martelo/talhadeira: o host valida (lugar livre, triângulo existe) e repassa.
func build_request(action: String, args: Array) -> void:
	if world == null or world.get_node_or_null("Building") == null:
		return
	if is_host():
		var result: Array = world.get_node("Building").host_apply(action, args)
		if online() and not result.is_empty():
			_build.rpc(action, result)
	else:
		_req_build.rpc_id(1, action, args)


@rpc("any_peer", "reliable")
func _req_build(action: String, args: Array) -> void:
	build_request(action, args)


@rpc("authority", "reliable")
func _build(action: String, args: Array) -> void:
	if world and world.get_node_or_null("Building"):
		world.get_node("Building").apply_remote(action, args)


@rpc("authority", "reliable")
func _build_state(list: Array) -> void:
	if world and world.get_node_or_null("Building"):
		world.get_node("Building").load_state(list)


# --- Sistemas do mundo (potes/canteiros/bancadas...) -----------------------------

## Mesmo esquema da construção para qualquer nó da cena principal com
## host_apply(action, args) -> Array e apply_remote(action, args).
func system_request(system: String, action: String, args: Array) -> void:
	if world == null or world.get_node_or_null(system) == null:
		return
	if is_host():
		var result: Array = world.get_node(system).host_apply(action, args)
		if online() and not result.is_empty():
			_system.rpc(system, action, result)
	else:
		_req_system.rpc_id(1, system, action, args)


@rpc("any_peer", "reliable")
func _req_system(system: String, action: String, args: Array) -> void:
	request_peer = multiplayer.get_remote_sender_id()
	system_request(system, action, args)
	request_peer = 1


## Host: entrega um item no inventário de um jogador (o que não couber cai no
## chão). slot >= 0: tenta pôr naquele slot da mochila (arrastou do baú para lá).
func give_to(peer: int, item_id: StringName, amount: int, slot := -1, dur := 1.0) -> void:
	var where := Transform3D()
	if world:
		var who: Node3D = world.player if peer == my_id() else world.puppets.get(peer)
		if is_instance_valid(who):
			where = who.global_transform.translated(Vector3.UP)
	if peer == my_id() or not online():
		_give_at(item_id, amount, where, slot, dur)
	else:
		_give_at.rpc_id(peer, item_id, amount, where, slot, dur)


@rpc("authority", "reliable")
func _give_at(item_id: StringName, amount: int, where: Transform3D, slot: int, dur := 1.0) -> void:
	if world == null or world.player == null:
		return
	var inventory: Inventory = world.player.inventory
	if slot >= 0 and slot < inventory.slots.size():
		var target: Dictionary = inventory.slots[slot]
		if target.is_empty():
			var moved := mini(ItemDB.max_stack(item_id), amount)
			inventory.slots[slot] = {"id": item_id, "amount": moved}
			if dur < 1.0:
				inventory.slots[slot].dur = dur
			amount -= moved
			inventory.changed.emit()
		elif target.id == item_id:
			var moved := mini(ItemDB.max_stack(item_id) - target.amount, amount)
			target.amount += moved
			amount -= moved
			inventory.changed.emit()
	if amount > 0:
		_give(item_id, amount, where, dur)


## Host: marca uma chave como usada para todos (baú aberto, árvore derrubada...).
func mark_taken(key: String) -> void:
	if online():
		_taken.rpc(key)
	_taken(key)


@rpc("authority", "reliable")
func _system(system: String, action: String, args: Array) -> void:
	if world and world.get_node_or_null(system):
		world.get_node(system).apply_remote(action, args)


func send_system_state(peer: int, system: String, data: Variant) -> void:
	_system_state.rpc_id(peer, system, data)


func broadcast_system_state(system: String, data: Variant) -> void:
	_system_state.rpc(system, data)


@rpc("authority", "reliable")
func _system_state(system: String, data: Variant) -> void:
	if world and world.get_node_or_null(system):
		world.get_node(system).load_data(data)


# --- Saque (baús e armários das cidades) ------------------------------------------

signal looted(key: String) ## um baú foi revistado (por qualquer jogador)


## Abre o baú "key": o host sorteia os itens e solta no chão na frente dele.
## Cada baú só uma vez por mundo (fica em "taken", que vai no save).
func loot_request(key: String, where: Transform3D, table: String) -> void:
	if taken.has(key):
		return
	if not online() or multiplayer.is_server():
		_do_loot(key, where, table)
	else:
		_req_loot.rpc_id(1, key, where, table)


@rpc("any_peer", "reliable")
func _req_loot(key: String, where: Transform3D, table: String) -> void:
	if not taken.has(key):
		_do_loot(key, where, table)


func _do_loot(key: String, where: Transform3D, table: String) -> void:
	if online():
		_taken.rpc(key)
	_taken(key)
	for drop in Loot.roll(table):
		# Troncos saem um por um (cada um é carregado/cortado separado).
		var pieces: int = drop[1] if drop[0] == &"tronco" else 1
		for k in pieces:
			# Nasce na FRENTE do baú (fora da colisão dele) e é jogado para fora.
			var forward := Vector3(where.basis.z.x, 0, where.basis.z.z).normalized()
			var side := Vector3(-forward.z, 0, forward.x)
			var spot := Transform3D(Basis(), where.origin + forward * 0.8 + side * (randf_range(-0.3, 0.3) + k * 0.35) + Vector3.UP * 0.45)
			var push := forward * randf_range(1.0, 1.8) + side * randf_range(-0.6, 0.6) + Vector3.UP * randf_range(1.5, 2.2)
			drop_item(drop[0], drop[1] / pieces, spot, push)


# --- Desvirar carro ------------------------------------------------------------------

## Quem simula o carro (o dono) é quem desvira; os outros veem pela posição.
func flip_car(car: VintageCar) -> void:
	if not online() or car.net_owner == my_id():
		car.flip_upright()
	else:
		_flip_car.rpc_id(car.net_owner, String(car.name))


@rpc("any_peer", "reliable")
func _flip_car(car_name: String) -> void:
	var car := _car(car_name)
	if car and car.net_owner == my_id():
		car.flip_upright()


# --- Chat e ping -----------------------------------------------------------------

signal chat_received(from: String, text: String)


func send_chat(text: String) -> void:
	text = text.left(160)
	if online():
		_chat.rpc(player_name, text)
	_chat(player_name, text)


@rpc("any_peer", "reliable")
func _chat(from: String, text: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and peers.has(sender):
		from = peers[sender] # o nome vem da lista do host (ninguém finge ser outro)
	chat_received.emit(from, text.left(160))


func send_ping(pos: Vector3, kind: String) -> void:
	if online():
		_ping.rpc(pos, kind)
	_ping(pos, kind)


@rpc("any_peer", "unreliable_ordered")
func _ping(pos: Vector3, kind: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var from: String = peers.get(sender, player_name) if sender != 0 else player_name
	if PingMarkers.i:
		PingMarkers.i.add(pos, from, kind)


# --- Efeitos -------------------------------------------------------------------

## Efeitos que os outros jogadores precisam ver (tiro, míssil).
func fx(kind: String, args: Array) -> void:
	if online():
		_fx.rpc(kind, args)


@rpc("any_peer", "unreliable")
func _fx(kind: String, args: Array) -> void:
	if world:
		world.play_fx(kind, args)
