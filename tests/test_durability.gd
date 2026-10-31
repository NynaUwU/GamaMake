extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 20:
		await process_frame
	var main := current_scene
	var player: Player = main.player
	var inv := player.inventory
	inv.slots[0] = {"id": &"machado_simples", "amount": 1}
	inv.select(0)
	var uses := 0
	while not inv.slots[0].is_empty() and uses < 1000:
		player._wear_selected()
		uses += 1
	print("machado simples quebrou depois de ", uses, " usos (máx ", ItemDB.max_durability(&"machado_simples"), ")")
	inv.equipment.body = {"id": &"colete", "amount": 1}
	player.take_damage(10.0, Vector3.FORWARD)
	print("colete depois de 1 golpe: dur=", snappedf(inv.equipment.body.get("dur", 1.0), 0.001), " vida=", player.health)
	Net.i.drop_item(&"espada", 1, Transform3D(Basis(), player.global_position + Vector3.UP), Vector3.ZERO, 0.3)
	await process_frame
	var sword: PickupItem = get_nodes_in_group("interactable").filter(func(i): return i is PickupItem and i.item_id == &"espada" and i.dur < 1.0)[0]
	sword.take_locally(player)
	var slot := inv.slots.filter(func(s): return not s.is_empty() and s.id == &"espada" and s.get("dur", 1.0) < 1.0)
	print("espada gasta do chão: dur=", slot[0].dur if slot.size() > 0 else "perdeu")
	# Zumbi larga coisas.
	var drops := 0
	for k in 40:
		var z: Zombie = load("res://scenes/zombie.tscn").instantiate()
		z.position = Vector3(40 + k, 0.5, 40)
		main.get_node("Enemies").add_child(z)
		z._drop_loot()
		z.queue_free()
	await process_frame
	for i in get_nodes_in_group("interactable"):
		if i is PickupItem and i.item_id in [&"sucata", &"pano", &"capuz", &"calca", &"botas", &"colete"] and i.global_position.x > 39:
			drops += 1
	print("40 zumbis mortos: itens largados=", drops)
	quit()
