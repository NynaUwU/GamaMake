extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 20:
		await process_frame
	var placed: PlacedManager = current_scene.get_node("Placed")
	var r := placed.host_apply("place", ["drawboard", Transform3D(Basis(), Vector3(-8, 0, 16))])
	var obj: PlacedObject = placed.objects[r[0]]
	placed.request("draw", [r[0], PackedVector2Array([Vector2(10, 10), Vector2(60, 40)]), Color.RED, 4])
	print("pixel no traço=", obj.board.image.get_pixel(35, 25), " fora=", obj.board.image.get_pixel(100, 80))
	var data := placed.save_data()
	placed.request("clear_board", [r[0]])
	print("limpo=", obj.board.image.get_pixel(35, 25))
	placed.load_data(data)
	print("recarregado=", placed.objects[r[0]].board.image.get_pixel(35, 25), " bytes salvos=", data.list[-1][4].pixels.size())
	DrawUI.open_for(current_scene.player, placed.objects[r[0]].board)
	await process_frame
	print("UI aberta=", current_scene.get_children().filter(func(c): return c is DrawUI).size())
	quit()
