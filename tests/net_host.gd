extends SceneTree
## Teste de rede (rode junto com tests/net_client.gd): abre o servidor e,
## no fim, mostra o que chegou do cliente.
var t := 0.0
var started := false

func _process(delta: float) -> bool:
	t += delta
	if not started:
		started = true
		Net.i.host_game("Host", 0)
		Net.i.chat_received.connect(func(from, text): print("HOST chat de ", from, ": ", text))
	if current_scene and current_scene.name == "Main" and int(t) == 18 and int(t - delta) == 17:
		var main: Node = current_scene
		var items := []
		for p in main.puppets.values():
			items.append([p.display_name, p._net_item, p.global_position.snapped(Vector3.ONE * 0.1)])
		print("HOST t=18 puppets=", main.puppets.size(), " ", items)
		var chasing := main.get_tree().get_nodes_in_group("enemy").filter(func(z): return z.target and z.target.is_in_group("remote_player")).size()
		print("HOST zombies chasing remote players=", chasing)
	if current_scene and current_scene.name == "Main" and int(t) == 19 and int(t - delta) == 18:
		Net.i.request_player_saves() # o host vai salvar: pede o estado de cada cliente
	if t > 34.0:
		var main: Node = current_scene
		print("HOST player_saves=", Net.i.player_saves.keys(), " slots ok=", Net.i.player_saves.values().all(func(d): return d.slots.size() == 20))
		var zombies: Array = main.get_tree().get_nodes_in_group("enemy")
		var dead := zombies.filter(func(z): return z.state == Zombie.State.DEAD).size()
		var car: VintageCar = main.get_node("Carro")
		var puppet: Player = main.puppets.values()[0] if not main.puppets.is_empty() else null
		print("HOST peers=", Net.i.peers.values(), " puppets=", main.puppets.size(),
			" puppet pos=", puppet.global_position.snapped(Vector3.ONE * 0.1) if puppet else null,
			" puppet item=", puppet._net_item if puppet else null)
		print("HOST zombies=", zombies.size(), " dead=", dead, " car owner=", car.net_owner, " driver=", car.driver_peer,
			" car pos=", car.global_position.snapped(Vector3.ONE * 0.1))
		print("HOST taken=", Net.i.taken.keys(), " drops=", Net.i._drops)
		var building: BuildingManager = main.get_node("Building")
		print("HOST pings=", PingMarkers.i.list.map(func(p): return [p.from, p.kind]) if PingMarkers.i else [])
		print("HOST building: peças=", building.pieces.size(), " tirados=", building.pieces.values()[0].removed.count(1) if building.pieces.size() > 0 else -1)
		quit()
	return false
