extends SceneTree
## Baús (itens fora do móvel), fogueira/grelha, fornalha, mesa, conserto e armadilhas.
var main: Node

func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(20)
	main = current_scene
	var player: Player = main.player
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	# 1) Baús são inventários: abrir sorteia, pegar e guardar.
	var cm: ContainerManager = main.get_node("Containers")
	var box := LootBox.new()
	box.setup("teste_bau", "bau", "casa")
	main.add_child(box)
	box.global_position = Vector3(30, 0, 40)
	box.interact(player)
	await _frames(2)
	var cui: ContainerUI = main.get_children().filter(func(c): return c is ContainerUI)[0]
	var slots: Array = cm.slots_of("teste_bau")
	var filled := slots.filter(func(x): return not x.is_empty())
	print("baú aberto: itens=", filled.size(), " tampa aberta=", box._opened, " UI=", cui != null)
	var first: Dictionary = filled[0].duplicate()
	var before := player.inventory.count(first.id)
	cui._take(slots.find(filled[0]))
	print("pegou ", first.id, ": ", before, " -> ", player.inventory.count(first.id))
	player.inventory.slots[4] = {"id": &"pedra", "amount": 5}
	cui._put(4)
	print("guardou pedra: baú tem=", cm.slots_of("teste_bau").filter(func(x): return not x.is_empty() and x.id == &"pedra").map(func(x): return x.amount), " mochila slot4=", player.inventory.slots[4])
	cui._take_all()
	print("pegar tudo: baú vazio=", cm.slots_of("teste_bau").all(func(x): return x.is_empty()))
	cui.close()
	var saved := cm.save_data()
	cm.load_data(saved)
	print("save do baú ok=", cm.contents.has("teste_bau"))
	# 2) Fogueira: assa batata.
	var placed: PlacedManager = main.get_node("Placed")
	var fire := placed.host_apply("place", ["campfire", Transform3D(Basis(), Vector3(-10, 0, 20))])
	var camp: PlacedObject = placed.objects[fire[0]]
	player.inventory.slots[3] = {"id": &"batata", "amount": 2}
	player.inventory.select(3)
	camp.interact(player)
	print("grelha: ", camp.crops, " texto=", camp.get_interact_text())
	placed.clock += 25.0
	camp.refresh(placed.clock)
	print("pronta: ", camp.get_interact_text())
	camp.interact(player)
	await _frames(3)
	var baked := get_nodes_in_group("interactable").filter(func(i): return i is PickupItem and i.item_id == &"batata_assada").size()
	print("batatas assadas no chão=", baked)
	# 3) Fornalha: minério + carvão -> barra; mesa: barras -> espada.
	player.inventory.add(&"minerio_ferro", 6)
	player.inventory.add(&"carvao", 2)
	CraftingUI.open_for(player, "fornalha")
	await _frames(2)
	var ui: CraftingUI = main.get_children().filter(func(c): return c is CraftingUI)[0]
	var bar_recipe: Dictionary = ui.recipes().filter(func(r): return r.id == &"barra_ferro")[0]
	for k in 3:
		ui.craft(bar_recipe)
	print("fornalha: barras=", player.inventory.count(&"barra_ferro"), " carvão=", player.inventory.count(&"carvao"), " tábuas=", player.inventory.count(&"tabua"), " minério=", player.inventory.count(&"minerio_ferro"))
	ui.close()
	player.inventory.add(&"pano", 1)
	CraftingUI.open_for(player, "mesa")
	await _frames(2)
	ui = main.get_children().filter(func(c): return c is CraftingUI and not c.is_queued_for_deletion())[0]
	print("mesa: receitas=", ui.recipes().size(), " (bancada ", CraftingUI.RECIPES.filter(func(r): return r.station == "bancada").size(), ")")
	ui.craft(ui.recipes().filter(func(r): return r.id == &"espada")[0])
	print("espada=", player.inventory.count(&"espada"))
	ui.close()
	# 4) Conserto.
	var building: BuildingManager = main.get_node("Building")
	var res := building.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(-60, 0, 120), 0])
	var wall: BuildPiece = building.pieces[res[0]]
	building.host_apply("break", [res[0], PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7])])
	building.host_apply("cut", [res[0], 100])
	print("quebrada: tirados=", wall.removed.count(1), " dano=", wall.damaged.size(), " custo=", Builder.repair_cost(wall))
	building.host_apply("repair", [res[0]])
	print("consertada: tirados=", wall.removed.count(1), " (o corte da talhadeira fica)")
	# 5) Armadilhas.
	var zombie_scene := load("res://scenes/zombie.tscn")
	var bt := placed.host_apply("place", ["beartrap", Transform3D(Basis(), Vector3(-20, 0, 50))])
	var z: Zombie = zombie_scene.instantiate()
	z.position = Vector3(-20, 0.3, 50)
	main.get_node("Enemies").add_child(z)
	for f in 20:
		await physics_frame
	print("urso: estado do zumbi=", Zombie.State.keys()[z.state], " armada=", placed.objects[bt[0]].extra.armed, " texto=", placed.objects[bt[0]].get_interact_text())
	placed.objects[bt[0]].interact(player)
	print("rearmada=", placed.objects[bt[0]].extra.armed)
	var mine := placed.host_apply("place", ["mine", Transform3D(Basis(), Vector3(-30, 0, 50))])
	var z2: Zombie = zombie_scene.instantiate()
	z2.position = Vector3(-30.5, 0.3, 50)
	main.get_node("Enemies").add_child(z2)
	for f in 20:
		await physics_frame
	print("mina: existe=", placed.objects.has(mine[0]), " zumbi=", Zombie.State.keys()[z2.state])
	var sp := placed.host_apply("place", ["spikes", Transform3D(Basis(), Vector3(-40, 0, 50))])
	var z3: Zombie = zombie_scene.instantiate()
	z3.position = Vector3(-40, 0.3, 50)
	main.get_node("Enemies").add_child(z3)
	var hp0 := z3.health
	for f in 60:
		await physics_frame
	print("estacas: vida ", hp0, " -> ", snappedf(z3.health, 0.1), " usos=", placed.objects[sp[0]].extra.uses)
	var data := placed.save_data()
	placed.load_data(data)
	print("recarregou: urso armado=", placed.objects[bt[0]].extra.armed)
	quit()

func _frames(n: int) -> void:
	for i in n:
		await process_frame
