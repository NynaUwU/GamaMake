extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	var t0 := Time.get_ticks_msec()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 5:
		await process_frame
	print("cena pronta em %d ms" % (Time.get_ticks_msec() - t0))
	var main := current_scene
	var player: Player = main.player
	var city_cars := get_nodes_in_group("vehicle").filter(func(c): return c.parked)
	print("carros nas cidades=", city_cars.size(), " congelados=", city_cars.filter(func(c): return c.freeze).size())
	var car: VintageCar = city_cars[0]
	var start := car.global_position
	player.global_position = car.global_position + Vector3(6, 2, 0)
	for k in 300:
		await physics_frame
		if not car.freeze and k > 200:
			break
	print("perto: congelado=", car.freeze, " desceu=%.2f m, up=%.2f, tombado=%s" % [start.y - car.global_position.y, car.global_basis.y.y, car.is_tipped()])
	print("no mapa antes de entrar=", car.discovered)
	player.global_position = car.global_position + car.global_basis.x * 1.8
	car.interact(player)
	await physics_frame
	print("dirigindo=", player.vehicle == car, " no mapa=", car.discovered)
	player.exit_vehicle()
	quit()
