extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var player: Player = main.player
	var car: VintageCar = get_nodes_in_group("vehicle")[0]
	print("gravidade do carro=", car.gravity_scale)
	# Porta-malas: atrás do carro.
	player.global_position = car.to_global(Vector3(0, 0.2, -car.wheelbase * 0.5 - 1.2))
	print("atrás: ", car.get_interact_text())
	car.interact(player)
	await process_frame
	var ui: StorageUI = main.get_children().filter(func(c): return c is StorageUI)[0]
	print("porta-malas aberto: chave=", ui.key, " slots=", ContainerManager.i.slots_of(ui.key).size())
	ui.close()
	player.global_position = car.to_global(Vector3(-1.6, 0.2, 0.3))
	print("do lado: ", car.get_interact_text())
	# Tomba e desvira.
	car.global_transform = Transform3D(Basis(Vector3.BACK, PI * 0.9), car.global_position + Vector3.UP * 1.0)
	for k in 60:
		await physics_frame
	print("tombado=", car.is_tipped(), " texto=", car.get_interact_text())
	car.interact(player)
	for k in 60:
		await physics_frame
	print("desvirou: tombado=", car.is_tipped(), " up=", snappedf(car.global_basis.y.y, 0.01))
	quit()
