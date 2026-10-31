extends SceneTree
func _wear_after(player: Player, id: StringName, target: Object) -> float:
	player.equip_item(id)
	player.inventory.slots[player.inventory.selected].dur = 1.0
	player._swing_wear = 0.0
	player._swing_hits.clear()
	player._swing_hits.append(target) # finge que o golpe pegou o alvo
	player._apply_swing_hit({"collider": target}, Vector3.FORWARD, {}) if false else null
	var cost := player._wear_cost(target)
	player._wear_selected(cost)
	return (1.0 - player.inventory.slots[player.inventory.selected].get("dur", 1.0)) * ItemDB.max_durability(id)
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	var hordes: HordeManager = main.get_node("Hordes")
	# 1) zumbi da onda não solta nada
	var before := get_nodes_in_group("interactable").filter(func(n): return n is PickupItem).size()
	var zombies: Array = main.get_node("Enemies").get_children().filter(func(z): return z is Zombie)
	for k in 30:
		var z: Zombie = zombies[k % zombies.size()]
		z.set_meta("night", true)
		z._drop_loot()
	await process_frame
	var after := get_nodes_in_group("interactable").filter(func(n): return n is PickupItem).size()
	print("zumbis da onda soltaram: ", after - before)
	# 2) airdrop
	hordes._drop_airdrops()
	await process_frame
	var drops: Array = placed.objects.values().filter(func(o): return o.kind == "airdrop")
	var drop: PlacedObject = drops[0]
	var flat := Vector2(drop.global_position.x - player.global_position.x, drop.global_position.z - player.global_position.z).length()
	var slots: Array = ContainerManager.i.slots_of("placed_%d" % drop.net_id)
	print("airdrops=", drops.size(), " distância=%.1f m" % flat, " itens=", slots.filter(func(s): return not s.is_empty()).map(func(s): return "%s x%d" % [s.id, s.amount]))
	print("texto: ", drop.get_interact_text())
	await create_timer(7.5).timeout
	var fx: AirdropFX = drop.get_child(0)
	print("caiu=", fx._landed, " sinal aceso=", fx._beam.visible)
	for i in slots.size():
		slots[i] = {}
	await create_timer(1.5).timeout
	print("vazio: sinal aceso=", fx._beam.visible)
	# 3) desgaste
	var tree: ResourceNode = get_nodes_in_group("resource").filter(func(r): return r.kind in ResourceNode.TREES)[0] if not get_nodes_in_group("resource").is_empty() else null
	if tree == null:
		for n in get_root().find_children("*", "StaticBody3D", true, false):
			if n is ResourceNode and n.kind in ResourceNode.TREES:
				tree = n
				break
	var rock: ResourceNode = null
	for n in get_root().find_children("*", "StaticBody3D", true, false):
		if n is ResourceNode and n.kind == "rock":
			rock = n
	var zhit := Node.new()
	zhit.set_meta("enemy", zombies[0])
	print("usos gastos: espada/árvore=%.2f machado/árvore=%.2f machado/pedra=%.2f picareta/pedra=%.2f maça/árvore=%.2f espada/zumbi=%.2f machado/zumbi=%.2f" % [
		_wear_after(player, &"espada", tree), _wear_after(player, &"machado", tree), _wear_after(player, &"machado", rock),
		_wear_after(player, &"picareta", rock), _wear_after(player, &"taco", tree), _wear_after(player, &"espada", zhit), _wear_after(player, &"machado", zhit)])
	# 4) bandeira
	player.inventory.add(&"bandeira", 1)
	player.equip_item(&"bandeira")
	player.head.rotation.x = -1.2
	player._place_selected()
	await process_frame
	var flags: Array = placed.objects.values().filter(func(o): return o.kind == "flag")
	print("bandeira fincada=", flags.size(), " na mochila=", player.inventory.count(&"bandeira"), " texto=", flags[0].get_interact_text() if flags.size() else "")
	flags[0].interact(player)
	await process_frame
	print("recolhida: no mundo=", placed.objects.values().filter(func(o): return o.kind == "flag").size(), " na mochila=", player.inventory.count(&"bandeira"))
	var with_tape := CraftingUI.RECIPES.filter(func(r): return r.cost.has(&"fita")).map(func(r): return String(r.id))
	print("receitas com fita: ", with_tape)
	quit()
