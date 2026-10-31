extends SceneTree
## Teste de rede (rode depois de tests/net_host.gd): entra, bate num zumbi,
## pega a espada, dirige o carro e solta um item.
var t := 0.0
var step := 0
var main: Node
var zombie: Zombie
var car: VintageCar
var car_start := Vector3.ZERO

func _process(delta: float) -> bool:
	t += delta
	if step == 0 and t > 2.0:
		step = 1
		Net.i.join_game("127.0.0.1", "Cliente%d" % (randi() % 100))
	elif step == 1 and current_scene and current_scene.name == "Main" and Net.i._zombies.size() > 0 and t > 8.0:
		step = 2
		t = 0.0
		main = current_scene
		var player: Player = main.player
		Net.i.send_chat("oi do cliente")
		main.get_node("Placed").request("place", ["drawboard", Transform3D(Basis(), Vector3(-9, 0, 18))])
		Net.i.send_ping(player.global_position + Vector3(0, 0, -5), "zumbi")
		print("CLIENT bancada recebida=", main.get_node("Placed").objects.values().map(func(o): return o.kind), " hora=", DayNight.i.clock_text())
		print("CLIENT online=", Net.i.online(), " host=", Net.i.is_host(), " id=", Net.i.my_id(), " peers=", Net.i.peers.values())
		print("CLIENT puppet zombies=", Net.i._zombies.size(), " host puppet=", main.puppets.size(),
			" host puppet pos=", main.puppet_position(1).snapped(Vector3.ONE * 0.1), " own zombies (deveria ser 0)=",
			main.get_tree().get_nodes_in_group("enemy").filter(func(z): return not z.puppet).size())
		zombie = Net.i._zombies.values()[0]
		var hit := HitInfo.make(500.0, &"Chest", zombie.global_position + Vector3.UP, Vector3.FORWARD, 40.0, HitInfo.Type.BLUNT)
		zombie.take_hit(hit)
		for item in main.get_node("Props").get_children():
			if item is PickupItem and item.item_id == &"espada":
				item.interact(player)
	elif step == 2 and t > 2.0:
		step = 3
		t = 0.0
		print("CLIENT zombie after hit: state=", Zombie.State.keys()[zombie.state], " ragdoll=", zombie.ragdoll.is_ragdolling())
		print("CLIENT inventory has espada=", main.player.inventory.has(&"espada"),
			" espada still on bench=", main.get_node("Props").get_children().filter(func(n): return n is PickupItem and n.item_id == &"espada" and not n.is_queued_for_deletion()).size())
		car = main.get_node("Carro")
		car.interact(main.player)
	elif step == 3 and t > 1.0:
		step = 4
		t = 0.0
		var boards: Array = main.get_node("Placed").objects.values().filter(func(o): return o.board != null)
		if boards.size() > 0:
			main.get_node("Placed").request("draw", [boards[0].net_id, PackedVector2Array([Vector2(5, 20), Vector2(40, 20)]), Color(0.2, 0.45, 0.8), 6])
		print("CLIENT in car=", main.player.vehicle == car, " car owner=", car.net_owner, " frozen=", car.freeze)
		car_start = car.global_position
		Input.action_press("move_forward")
	elif step == 4 and t > 3.0:
		step = 5
		t = 0.0
		Input.action_release("move_forward")
		print("CLIENT car moved ", snappedf(car.global_position.distance_to(car_start), 0.1), " m, now at ", car.global_position.snapped(Vector3.ONE * 0.1))
		main.player.exit_vehicle()
		main.player.inventory.select(0)
		main.player._drop_selected()
		# Construção pela rede: o host valida e repassa.
		var building: BuildingManager = main.get_node("Building")
		building.request_place(BuildPiece.Kind.WALL, Vector3i(-50, 0, 40), 0)
	elif step == 5 and t > 2.0 and t - delta <= 2.0:
		var building: BuildingManager = main.get_node("Building")
		if building.pieces.size() > 0:
			building.request_cut(building.pieces.values()[0], 10)
			building.request_cut(building.pieces.values()[0], 11)
	elif step == 5 and t > 6.0:
		var building: BuildingManager = main.get_node("Building")
		print("CLIENT building: peças=", building.pieces.size(), " tirados=", building.pieces.values()[0].removed.count(1) if building.pieces.size() > 0 else -1)
		print("CLIENT hp=", main.player.health, " players seen=", main.puppets.size() + 1, " after drop: pickups espada in world=", main.get_tree().get_nodes_in_group("interactable").filter(func(n): return n is PickupItem and n.item_id == &"espada").size())
		quit()
	return false
