extends Node3D
## Cena principal: atalhos de teste (novo zumbi, horda, recomeçar — só o host)
## e a ponte com o multiplayer (Net): bonecos dos outros jogadores, zumbis e
## itens que chegam pela rede, efeitos de tiro/míssil dos outros.

const ZOMBIE_SCENE := preload("res://scenes/zombie.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PICKUP_SCENE := preload("res://scenes/props/pickup_item.tscn")
const MISSILE_SCENE := preload("res://scenes/weapons/magic_missile.tscn")

@onready var player: Player = $Player
@onready var enemies: Node3D = $Enemies

var puppets := {} ## peer -> Player (boneco de outro jogador)
var _players_root: Node3D


func _ready() -> void:
	var pause := PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	_players_root = Node3D.new()
	_players_root.name = "RemotePlayers"
	add_child(_players_root)
	if Net.i.online():
		# Cada jogador nasce um pouco ao lado do outro.
		var slot: int = Net.i.my_id() % 16 if not Net.i.is_host() else 0
		player.position += Vector3((slot % 4) * 1.6 - 2.4, 0, (slot / 4) * 1.6)
		player.notify.emit.call_deferred("Multiplayer: %d jogador(es)%s" % [Net.i.player_count(), " · você é o host" if Net.i.is_host() else ""])
	player.spawn_point = player.global_position
	var placed := PlacedManager.new()
	placed.name = "Placed"
	add_child(placed)
	var day_night := DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	var hordes := HordeManager.new()
	hordes.name = "Hordes"
	add_child(hordes)
	var pings := PingMarkers.new()
	pings.name = "Pings"
	add_child(pings)
	_add_start_crate()
	Net.i.message.connect(_on_net_message)
	# Vento de fundo baixinho (preso no jogador).
	Sfx.loop_player("wind", player).play()
	Net.i.register_world(self)
	var loading := not SaveGame.pending.is_empty()
	SaveGame.apply(self)
	if not loading and Net.i.is_host():
		# Mundo novo: uma bancada de fabricação ao lado da mesa de armas.
		placed.host_apply("place", ["bench", Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-5.6, 0.0, 11.0))])
	# O CSG monta a geometria só depois do primeiro frame: espera para gerar a navegação.
	await get_tree().process_frame
	await get_tree().physics_frame
	_bake_navigation()


## Caixote da área inicial com o básico (tábuas, pedras, sementes, pá).
func _add_start_crate() -> void:
	var crate := LootBox.new()
	crate.name = "CaixoteInicial"
	crate.setup("loot_inicio", "caixote", "inicio")
	add_child(crate)
	crate.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-5.4, 0.0, 8.4))


func _exit_tree() -> void:
	Net.i.unregister_world(self)


func _on_net_message(text: String) -> void:
	player.notify.emit(text)


## Gera o NavigationMesh a partir da fase (CSG do nó Level) para os zumbis
## contornarem obstáculos. Mudou a fase? É recalculado sozinho ao iniciar.
func _bake_navigation() -> void:
	var level := $Level
	level.add_to_group("navigation_source")
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.5 # múltiplos de cell_size/cell_height (evita aviso de precisão)
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = &"navigation_source"
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = mesh
	add_child(region)
	region.bake_navigation_mesh(false)


func _unhandled_input(event: InputEvent) -> void:
	var admin: bool = Net.i.is_host() # teclas de teste/admin: só o host
	if event.is_action_pressed("spawn_zombie") and admin:
		_spawn_zombie_in_front()
	elif event.is_action_pressed("spawn_horde") and admin:
		_spawn_horde(100)
	elif event.is_action_pressed("restart"):
		if not Net.i.online():
			Engine.time_scale = 1.0
			get_tree().reload_current_scene()
		elif player.health <= 0.0:
			player.respawn() # online: morto renasce (sem recomeçar a partida)
		elif admin:
			Net.i.restart_world()


## Teste: muitos zumbis em volta do player (anel de 12 a 45 m). Nascem em
## lotes de 10 por quadro (criar 100 de uma vez travava o jogo por um instante).
var _horde_left := 0


func _spawn_horde(count: int) -> void:
	_horde_left += count


## Autosave (solo e host) a cada SaveGame.AUTOSAVE segundos.
var _autosave := SaveGame.AUTOSAVE


func save_now() -> bool:
	Net.i.request_player_saves()
	var ok := SaveGame.save(self)
	if ok:
		player.notify.emit("Jogo salvo (%s)" % SaveGame.current)
	return ok


func _process(delta: float) -> void:
	if Net.i.is_host():
		_autosave -= delta
		if _autosave <= 0.0:
			_autosave = SaveGame.AUTOSAVE
			if player.health > 0.0:
				save_now()
	if _horde_left > 0:
		var batch := mini(_horde_left, 10)
		_horde_left -= batch
		_spawn_horde_batch(batch)


func _spawn_horde_batch(count: int) -> void:
	var terrain := get_node_or_null("Terrain") as TerrainWorld
	for i in count:
		var a := randf() * TAU
		var r := randf_range(12.0, 45.0)
		var pos := player.global_position + Vector3(cos(a) * r, 0, sin(a) * r)
		if terrain:
			pos.y = terrain.height_at(pos.x, pos.z) + 0.3
		var zombie: Zombie = ZOMBIE_SCENE.instantiate()
		zombie.position = pos
		zombie.target = player
		enemies.add_child(zombie)


func _spawn_zombie_in_front() -> void:
	var forward := -player.global_basis.z
	var zombie: Zombie = ZOMBIE_SCENE.instantiate()
	zombie.position = player.global_position + forward * 6.0
	zombie.target = player
	enemies.add_child(zombie)


# --- Multiplayer ----------------------------------------------------------------

## Estado de outro jogador chegou: cria o boneco dele na primeira vez.
func update_puppet(peer: int, state: Array) -> void:
	var puppet: Player = puppets.get(peer)
	if puppet == null:
		puppet = PLAYER_SCENE.instantiate()
		puppet.remote_peer = peer
		puppet.name = "Remote_%d" % peer
		puppet.display_name = Net.i.peers.get(peer, "Jogador %d" % peer)
		_players_root.add_child(puppet)
		puppets[peer] = puppet
	puppet.apply_net_state(state)


func remove_puppet(peer: int) -> void:
	var puppet: Player = puppets.get(peer)
	puppets.erase(peer)
	if is_instance_valid(puppet):
		puppet.queue_free()


## Onde está o jogador "peer" (host: para saber quais zumbis mandar a ele).
func puppet_position(peer: int) -> Vector3:
	var puppet: Player = puppets.get(peer)
	return puppet.global_position if is_instance_valid(puppet) else Vector3(1e9, 0, 0)


## Posições de todos os jogadores (o host gera terreno/cidades/zumbis em volta de todos).
func player_positions() -> Array[Vector3]:
	var list: Array[Vector3] = [player.global_position]
	if Net.i.online() and Net.i.is_host():
		for peer in puppets:
			if is_instance_valid(puppets[peer]):
				list.append(puppets[peer].global_position)
	return list


func spawn_puppet_zombie(net_id: int, data: Dictionary) -> void:
	var zombie: Zombie = ZOMBIE_SCENE.instantiate()
	zombie.puppet = true
	zombie.net_id = net_id
	zombie.setup_from_net(data)
	enemies.add_child(zombie)


func spawn_pickup(key: String, item_id: StringName, amount: int, where: Transform3D, impulse: Vector3) -> void:
	var item: PickupItem = PICKUP_SCENE.instantiate()
	item.item_id = item_id
	item.amount = amount
	item.net_key = key
	add_child(item)
	item.global_transform = where
	if impulse != Vector3.ZERO:
		item.apply_central_impulse(impulse)


## Efeitos dos outros jogadores (só visuais: o dano já foi aplicado por quem atirou).
func play_fx(kind: String, args: Array) -> void:
	match kind:
		"tracer":
			ImpactFX.tracer(self, args[0], args[1])
			Sfx.play_at("shot", args[0])
		"burst":
			ImpactFX.burst(self, args[0], args[1], args[2], args[3], args[4])
		"slipper", "boomerang":
			var target: Zombie = Net.i.get_zombie(args[2]) if args[2] != 0 else null
			if kind == "slipper":
				var copy := ThrownSlipper.new()
				copy.cosmetic = true
				add_child(copy)
				copy.launch(args[0], args[1], target, null)
			else:
				var copy := Boomerang.new()
				copy.cosmetic = true
				add_child(copy)
				copy.launch(args[0], args[1], target, null)
		"missile":
			var missile: MagicMissile = MISSILE_SCENE.instantiate()
			missile.cosmetic = true
			add_child(missile)
			missile.global_position = args[0]
			missile.launch(args[1], null)
