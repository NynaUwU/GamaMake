extends SceneTree
## Armas de fogo: munição própria de cada arma (carregada fica no slot da arma), recarga,
## revólver (cabeça = 1 tiro), rifle atravessando zumbis em fila, espingarda de perto e
## de longe, mira de ferro (zoom) e luneta, receitas e munição só nas zonas difíceis.

var main: Node3D
var player: Player
var zs: Array = []


func _place(z: Zombie, pos: Vector3, hp := 100.0) -> void:
	z.global_position = pos
	z.rotation.y = 0.0
	z.detect_range = 0.0
	z.max_health = hp
	z.health = hp
	z.balance = 0.0
	z.velocity = Vector3.ZERO
	z._set_state(Zombie.State.IDLE)


func _park() -> void:
	for i in zs.size():
		_place(zs[i], Vector3(60 + i * 3, 0, 60))


func _hp(list: Array) -> String:
	return ", ".join(list.map(func(z): return "%.0f" % z.health))


func _shoot(times: int) -> void:
	for k in times:
		player._fire_timer = 0.0
		player._fire_pistol()


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	player = main.player
	zs = main.get_node("Enemies").get_children().filter(func(n): return n is Zombie)
	print("zumbis para o teste: %d" % zs.size())
	_park()
	player.global_position = Vector3(0, 0, 6)
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0
	for id in Player.GUNS:
		var g: Dictionary = Player.GUNS[id]
		print("%s: munição %s, cabe %d, dano %.0f x%d, %.2f s entre tiros, recarga %.1f s, alcance %.0f m, atravessa %d, zoom %.0f°" % [
			id, g.ammo, g.mag, g.damage, g.pellets, g.rate, g.reload, g.range, g.pierce, g.zoom])
	# --- Revólver: munição própria e cabeça.
	player.equip_item(&"pistola")
	player._equip = 1.0
	player._start_reload()
	print("revólver sem balas: recarrega? %s" % (player._reload_timer > 0.0))
	player.inventory.add(&"cartucho", 10)
	player.inventory.add(&"bala_rifle", 4)
	player._start_reload()
	player._update_pistol(3.0)
	print("revólver: tambor %d (mochila %d balas de revólver, %d de rifle intactas)" % [player._ammo, player.inventory.count(&"cartucho"), player.inventory.count(&"bala_rifle")])
	_place(zs[0], Vector3(0, 0, 0))
	await physics_frame
	var head_y: float = zs[0].global_position.y + 1.62 - player.camera.global_position.y
	player.head.rotation.x = atan2(head_y, 6.0)
	_shoot(1)
	await physics_frame
	print("revólver na cabeça a 6 m: zumbi %s (vida %.0f)" % [Zombie.State.keys()[zs[0].state], zs[0].health])
	player.head.rotation.x = 0.0
	# --- Rifle: troca de arma guarda o que estava carregado em cada uma.
	player.equip_item(&"rifle")
	player._equip = 1.0
	player._start_reload()
	player._update_pistol(3.0)
	print("rifle: câmara %d, mochila %d; revólver guardou %d no slot" % [player._ammo, player.inventory.count(&"bala_rifle"),
		player.inventory.slots.filter(func(s): return not s.is_empty() and s.id == &"pistola")[0].get("ammo", 0)])
	_park()
	for i in 3:
		_place(zs[i], Vector3(0, 0, -2.0 - i * 2.5), 300.0)
	await physics_frame
	player.head.rotation.x = atan2(zs[0].global_position.y + 1.2 - player.camera.global_position.y, 8.0)
	_shoot(1)
	await physics_frame
	print("rifle no peito, 3 zumbis em fila (300 de vida): %s; câmara %d, recarregando %s" % [_hp(zs.slice(0, 3)), player._ammo, player._reload_timer > 0.0])
	player.head.rotation.x = 0.0
	# --- Espingarda: de perto e de longe.
	player.equip_item(&"espingarda")
	player._equip = 1.0
	player.inventory.add(&"cartucho_espingarda", 6)
	player._start_reload()
	player._update_pistol(3.0)
	print("espingarda: %d nos canos, mochila %d" % [player._ammo, player.inventory.count(&"cartucho_espingarda")])
	var near := []
	var far := []
	for k in 2:
		for d in [3.0, 25.0]:
			var z: Zombie = zs[3 + k]
			_park()
			_place(z, Vector3(0, 0, 6.0 - d), 1000.0)
			for f in 6:
				await process_frame
			player.head.rotation.x = atan2(z.global_position.y + 1.4 - player.camera.global_position.y, d)
			player._ammo = 2
			_shoot(1)
			(near if d < 10.0 else far).append(1000.0 - z.health)
			print("  bagos a %d m: %s" % [d, player.last_shot_bones])
	print("espingarda a 3 m: dano %s; a 25 m: %s" % [near.map(func(d): return int(d)), far.map(func(d): return int(d))])
	player.head.rotation.x = 0.0
	# --- Mira de ferro e luneta (segurando o botão direito).
	Input.action_press("block")
	for k in 20:
		player._update_pistol(0.05)
	print("espingarda mirando: zoom %.0f°, arma em %s" % [player.camera.fov, player.pistol.position])
	Input.action_release("block")
	for k in 20:
		player._update_pistol(0.05)
	player.inventory.add(&"rifle_luneta")
	player.equip_item(&"rifle_luneta")
	player._equip = 1.0
	var scopes := []
	player.scope_changed.connect(func(on): scopes.append(on))
	Input.action_press("block")
	for k in 20:
		player._update_pistol(0.05)
	print("rifle com luneta mirando: zoom %.0f°, luneta na tela %s, arma visível %s" % [player.camera.fov, scopes, player.pistol.visible])
	Input.action_release("block")
	for k in 20:
		player._update_pistol(0.05)
	print("soltou: zoom %.0f°, luneta %s" % [player.camera.fov, scopes])
	# --- Receitas e saque.
	for id in [&"rifle", &"espingarda", &"luneta", &"rifle_luneta", &"cartucho", &"bala_rifle", &"cartucho_espingarda"]:
		var r: Array = CraftingUI.RECIPES.filter(func(x): return x.id == id)
		print("receita %s: %s%s" % [id, r[0].cost, " (manual: %s)" % r[0].manual if r[0].has("manual") else ""])
	for table in Loot.TABLES:
		var ammo: Array = Loot.TABLES[table].filter(func(row): return row[0] in [&"cartucho", &"bala_rifle", &"cartucho_espingarda"])
		print("saque %s: munição %s" % [table, ammo.map(func(row): return "%s %d%%" % [row[0], int(row[1] * 100.0)])])
	quit()
