extends SceneTree
## Não cair pelo mundo: sair do carro tombado/capotado, barreira no fundo do mundo,
## item abaixo do chão volta, drop de bicho morto não atravessa o chão, saque raro
## dos zumbis (sem roupa).

var main: Node
var player: Player
var terrain: TerrainWorld


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	player = main.player
	terrain = main.get_node("Terrain")
	main.get_node("ZombieSpawner").process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("Animals").set_process(false)
	for e in main.get_node("Enemies").get_children():
		e.free()
	await _car_exit()
	await _barrier()
	await _items()
	await _animal_drop()
	_zombie_loot()
	quit()


func _wait(frames: int) -> void:
	for k in frames:
		await physics_frame


func _ground(p: Vector3) -> float:
	return terrain.height_at(p.x, p.z)


func _car_exit() -> void:
	var car: VintageCar = null
	for c in main.get_tree().get_nodes_in_group("vehicle"):
		if c is VintageCar:
			car = c
			break
	for pose in ["de lado (esquerda)", "de lado (direita)", "capotado", "em pé"]:
		var at := Vector3(30, 0, 30)
		at.y = _ground(at) + 0.9
		var basis: Basis = {"de lado (esquerda)": Basis(Vector3.BACK, PI / 2), "de lado (direita)": Basis(Vector3.BACK, -PI / 2),
			"capotado": Basis(Vector3.BACK, PI), "em pé": Basis()}[pose]
		player.global_position = at + Vector3(4, 0.5, 0)
		await _wait(5)
		player.enter_vehicle(car)
		car.global_transform = Transform3D(basis, at)
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		await _wait(20)
		car.freeze = true
		player.exit_vehicle()
		var out := player.global_position
		await _wait(90)
		car.freeze = false
		print("saiu do carro %s: desceu em %s (chão %.2f), 1,5 s depois y=%.2f no chão=%s" % [pose, out.snapped(Vector3.ONE * 0.01),
			_ground(out), player.global_position.y, player.is_on_floor()])


func _barrier() -> void:
	var floor_node: WorldFloor = main.get_node("WorldFloor")
	var at := Vector3(10, 0, -10)
	player.global_position = Vector3(at.x, -120.0, at.z)
	await _wait(30)
	print("jogador em y=-120: voltou para y=%.2f (chão %.2f)" % [player.global_position.y, _ground(at)])
	player.global_position = Vector3(at.x, _ground(at) - 10.0, at.z)
	await _wait(30)
	print("jogador 10 m abaixo do terreno: voltou para y=%.2f, no chão=%s" % [player.global_position.y, player.is_on_floor()])
	player.global_position = Vector3(at.x, _ground(at) + 0.2, at.z)
	await _wait(30)
	var y0 := player.global_position.y
	await _wait(30)
	print("parado em pé no chão: não mexeu=%s (salvamentos até agora: %d)" % [absf(player.global_position.y - y0) < 0.05, floor_node.rescued])


func _items() -> void:
	var at := player.global_position + Vector3(2, 0, 0)
	Net.i.drop_item(&"pedra", 1, Transform3D(Basis(), Vector3(at.x, _ground(at) - 8.0, at.z)), Vector3.ZERO)
	await _wait(5)
	var items := get_nodes_in_group("interactable").filter(func(i): return i is PickupItem and i.item_id == &"pedra")
	var stone: PickupItem = items[-1]
	print("item pedido 8 m abaixo do chão nasceu em y=%.2f (chão %.2f)" % [stone.global_position.y, _ground(stone.global_position)])
	stone.global_position.y = _ground(at) - 20.0
	await _wait(30)
	print("item empurrado 20 m para baixo: voltou para y=%.2f" % stone.global_position.y)
	var far := Vector3(player.global_position.x + 900.0, 40.0, player.global_position.z)
	Net.i.drop_item(&"pedra", 1, Transform3D(Basis(), far), Vector3.ZERO)
	await _wait(5)
	var far_item: PickupItem = get_nodes_in_group("interactable").filter(func(i): return i is PickupItem and i.item_id == &"pedra")[-1]
	await _wait(240)
	print("item longe (sem colisão no chão): y=%.2f chão %.2f congelado=%s" % [far_item.global_position.y, _ground(far), far_item.freeze])


func _animal_drop() -> void:
	var animals: AnimalManager = main.get_node("Animals")
	var results := []
	for kind in ["cervo", "vaca", "urso", "galinha", "pombo"]:
		var at := player.global_position + Vector3(3, 0.3, 3)
		var a := animals.spawn(kind, at)
		await _wait(20)
		var before := get_nodes_in_group("interactable").filter(func(i): return i is PickupItem).size()
		a.apply_hit(9999.0, Vector3.LEFT)
		await _wait(120)
		var drops := get_nodes_in_group("interactable").filter(func(i): return i is PickupItem and i.global_position.distance_to(at) < 6.0)
		var under := drops.filter(func(i): return i.global_position.y < _ground(i.global_position) - 0.3)
		results.append("%s: %d itens, abaixo do chão=%d" % [kind, drops.size(), under.size()])
		for d in drops:
			d.free()
	print("drops de bicho: ", " | ".join(results))


func _zombie_loot() -> void:
	var z: Zombie = load("res://scenes/zombie.tscn").instantiate()
	z.position = player.global_position + Vector3(0, 0, 40)
	main.get_node("Enemies").add_child(z)
	var counts := {}
	var tally := 0
	for k in 1000:
		var before := get_nodes_in_group("interactable").filter(func(i): return i is PickupItem).size()
		z._drop_loot()
		for i in get_nodes_in_group("interactable"):
			if i is PickupItem and not i.has_meta("counted"):
				i.set_meta("counted", true)
				counts[i.item_id] = counts.get(i.item_id, 0) + 1
				tally += 1
	print("1000 zumbis mortos soltaram: %s (roupas=%d)" % [counts, counts.get(&"capuz", 0) + counts.get(&"calca", 0) + counts.get(&"botas", 0) + counts.get(&"colete", 0)])
