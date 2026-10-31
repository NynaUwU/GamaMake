extends SceneTree
## Árvores, rochas e veios: machado/picareta, troncos, tronco virando tábuas.
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 20:
		await process_frame
	var main := current_scene
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	terrain.update_around(Vector3(0, 0, 0), -1, 400.0)
	await process_frame
	var nodes := {}
	for n in terrain.find_children("*", "ResourceNode", true, false):
		nodes[n.kind] = nodes.get(n.kind, 0) + 1
	print("recursos no mapa: ", nodes)
	var tree: ResourceNode = null
	var rock: ResourceNode = null
	for n in terrain.find_children("*", "ResourceNode", true, false):
		if n.kind == "tree" and tree == null: tree = n
		if n.kind.begins_with("ore") and rock == null: rock = n
	player.global_position = tree.global_position + Vector3(2, 1, 0)
	var hits := 0
	while is_instance_valid(tree) and not tree._done and hits < 10:
		tree.tool_hit(player, Player.WeaponType.AXE, 34.0, tree.global_position + Vector3.UP)
		hits += 1
	print("árvore: golpes de machado=", hits, " marcada=", Net.i.taken.size())
	for k in 10:
		await process_frame
	var logs := get_nodes_in_group("interactable").filter(func(i): return i is PickupItem and i.item_id == &"tronco")
	print("troncos no chão=", logs.size())
	Net.i.convert_pickup(logs[0], &"tabua", 2)
	await process_frame
	await process_frame
	var boards := get_nodes_in_group("interactable").filter(func(i): return i is PickupItem and i.item_id == &"tabua")
	print("tábuas do tronco cortado=", boards.map(func(b): return b.amount))
	hits = 0
	var kind := rock.kind
	while is_instance_valid(rock) and not rock._done and hits < 20:
		rock.tool_hit(player, Player.WeaponType.PICKAXE, 30.0, rock.global_position)
		hits += 1
	for k in 5:
		await process_frame
	var ore := get_nodes_in_group("interactable").filter(func(i): return i is PickupItem and String(i.item_id).begins_with("minerio") or i is PickupItem and i.item_id == &"carvao")
	print(kind, ": golpes de picareta=", hits, " minério no chão=", ore.map(func(o): return [o.item_id, o.amount]))
	quit()
