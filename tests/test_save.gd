extends SceneTree
## Salva um mundo com construção, item solto, inventário mexido e carro movido;
## carrega de novo e confere se voltou tudo.
var main: Node

func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(20)
	main = current_scene
	var player: Player = main.player
	var building: BuildingManager = main.get_node("Building")
	building.host_apply("place", [BuildPiece.Kind.FLOOR, Vector3i(3, 0, 3), 0])
	var piece: BuildPiece = building.pieces.values()[0]
	building.host_apply("cut", [piece.net_id, 5])
	player.inventory.slots[7] = {"id": &"martelo", "amount": 1}
	player.health = 42.0
	player.global_position = Vector3(10, 3, 12)
	var car: VintageCar = get_nodes_in_group("vehicle")[0]
	car.global_position += Vector3(5, 1, 0)
	var car_pos := car.global_position
	Net.i.drop_item(&"colher", 3, Transform3D(Basis(), Vector3(2, 1, 2)), Vector3.ZERO)
	Net.i.taken["teste_pego"] = true
	await _frames(2)
	print("salvou=", SaveGame.save(main, "TesteSave"), " lista=", SaveGame.list().map(func(i): return i.name))
	# Recarrega do zero.
	SaveGame.load_world("TesteSave")
	await _frames(25)
	main = current_scene
	player = main.player
	building = main.get_node("Building")
	var loaded: BuildPiece = building.pieces.values()[0] if building.pieces.size() > 0 else null
	print("peças=", building.pieces.size(), " recorte=", loaded.removed[5] if loaded else -1)
	print("vida=", player.health, " slot7=", player.inventory.slots[7], " pos=", player.global_position.snapped(Vector3.ONE * 0.1))
	car = get_nodes_in_group("vehicle")[0]
	print("carro distância do salvo=", snappedf(car.global_position.distance_to(car_pos), 0.01))
	var spoons := 0
	for item in get_nodes_in_group("interactable"):
		if item is PickupItem and item.item_id == &"colher" and item.amount == 3:
			spoons += 1
	print("colheres soltas=", spoons, " taken teste=", Net.i.taken.has("teste_pego"))
	SaveGame.delete("TesteSave")
	quit()

func _frames(n: int) -> void:
	for i in n:
		await process_frame
