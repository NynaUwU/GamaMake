extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 20:
		await process_frame
	var main := current_scene
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	var cm: ContainerManager = main.get_node("Containers")
	var r := placed.host_apply("place", ["chest", Transform3D(Basis(), Vector3(-9, 0, 16))])
	var chest: PlacedObject = placed.objects[r[0]]
	print("texto=", chest.get_interact_text())
	chest.interact(player)
	await process_frame
	var ui: StorageUI = main.get_children().filter(func(c): return c is StorageUI)[0]
	var key := "placed_%d" % r[0]
	print("slots do baú=", cm.slots_of(key).size())
	player.inventory.slots[7] = {"id": &"tabua", "amount": 12}
	ui._drop_on(Vector2.ZERO, {"storage_slot": true, "from": "bag", "index": 7}, "chest", 3)
	print("mochila->baú: baú[3]=", cm.slots_of(key)[3], " mochila[7]=", player.inventory.slots[7])
	ui._drop_on(Vector2.ZERO, {"storage_slot": true, "from": "chest", "index": 3}, "chest", 10)
	print("baú->baú: baú[10]=", cm.slots_of(key)[10], " baú[3]=", cm.slots_of(key)[3])
	player.inventory.slots[2] = {"id": &"pedra", "amount": 4}
	ui._drop_on(Vector2.ZERO, {"storage_slot": true, "from": "bag", "index": 2}, "chest", 10)
	print("trocou (pedra no lugar das tábuas): baú[10]=", cm.slots_of(key)[10], " tábuas voltaram=", player.inventory.count(&"tabua"))
	ui._drop_on(Vector2.ZERO, {"storage_slot": true, "from": "chest", "index": 10}, "bag", 15)
	print("baú->slot 15 da mochila: ", player.inventory.slots[15])
	player.inventory.slots[4] = {"id": &"lata", "amount": 1}
	ui._drop_on(Vector2.ZERO, {"storage_slot": true, "from": "bag", "index": 4}, "chest", 0)
	ui.close()
	# Baú da cidade: guardar é recusado (o item volta).
	cm.request("open", ["loot_teste", "casa"])
	var before := cm.slots_of("loot_teste").duplicate(true)
	cm.request("put_at", ["loot_teste", 11, "sucata", 2])
	print("baú da cidade recusou guardar=", cm.slots_of("loot_teste") == before, " sucata devolvida=", player.inventory.count(&"sucata"))
	# Desmontar o baú construído: a lata cai no chão.
	placed.host_apply("remove", [r[0]])
	await process_frame
	await process_frame
	var cans := get_nodes_in_group("interactable").filter(func(i): return i is PickupItem and i.item_id == &"lata")
	print("desmontou: lata no chão=", cans.size(), " conteúdo apagado=", not cm.contents.has(key))
	quit()
