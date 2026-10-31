extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 20:
		await process_frame
	var main := current_scene
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	var t1 := placed.host_apply("plant_tree", [Transform3D(Basis(), Vector3(20, 0, 30)), -1])
	var pot := placed.host_apply("place", ["pot_wide", Transform3D(Basis(), Vector3(24, 0, 30))])
	var t2 := placed.host_apply("plant_tree", [Transform3D(Basis(), Vector3(24, 0.34, 30)), pot[0]])
	var planter: PlacedObject = placed.objects[pot[0]]
	print("muda no chão=", not t1.is_empty(), " na floreira=", not t2.is_empty(), " floreira aceita cenoura? ", planter.allows("cenoura"))
	var tree: PlacedObject = placed.objects[t1[0]]
	print("texto: ", tree.get_interact_text())
	placed.request("chop", [t1[0], 200.0])
	print("muda não cai com machado: existe=", placed.objects.has(t1[0]))
	placed.clock += 500.0
	tree.refresh(placed.clock)
	print("depois de crescer: ", tree.get_interact_text(), " estágio=", tree._tree_stage)
	for k in 3:
		tree.tool_hit(player, Player.WeaponType.AXE, 34.0, tree.global_position + Vector3.UP)
	await process_frame
	await process_frame
	var saplings := 0
	var logs := 0
	for i in get_nodes_in_group("interactable"):
		if i is PickupItem and i.global_position.distance_to(Vector3(20, 0, 30)) < 6.0:
			if i.item_id == &"muda": saplings += i.amount
			if i.item_id == &"tronco": logs += 1
	print("derrubada: existe=", placed.objects.has(t1[0]), " mudas=", saplings, " troncos=", logs)
	placed.clock += 0.0
	var tree2: PlacedObject = placed.objects[t2[0]]
	tree2.refresh(placed.clock)
	for k in 3:
		tree2.tool_hit(player, Player.WeaponType.AXE, 34.0, tree2.global_position)
	print("árvore da floreira derrubada: floreira livre=", not planter.extra.has("tree"))
	var data := placed.save_data()
	placed.load_data(data)
	print("save ok: objetos=", placed.objects.size())
	quit()
