extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	var inv := player.inventory
	var o := player.global_position
	# Zumbi natural morto por explosão solta saque
	var drops_before := get_nodes_in_group("interactable").filter(func(n): return n is PickupItem).size()
	var zs: Array = main.get_node("Enemies").get_children().filter(func(z): return z is Zombie)
	for z: Zombie in zs.slice(0, 8):
		z.take_explosion(z.global_position, 500.0, 5.0)
	await process_frame
	await process_frame
	print("8 zumbis mortos por explosão soltaram ", get_nodes_in_group("interactable").filter(func(n): return n is PickupItem).size() - drops_before, " itens")
	# Área de pegar maior
	main.spawn_pickup(&"graveto", "Graveto", 1, Transform3D(Basis(), o + Vector3(2, 0.3, 0)), Vector3.ZERO)
	await process_frame
	var stick: PickupItem = get_nodes_in_group("interactable").filter(func(n): return n is PickupItem and n.item_id == &"graveto")[-1]
	print("graveto tem área de pegar: ", stick.get_node_or_null("Grab") != null)
	# Aviso de coleta + estragada numa pilha só
	var got := []
	inv.gained.connect(func(id, n): got.append("%s x%d" % [id, n]))
	inv.slots[20] = {"id": &"atum", "amount": 2, "dur": 0.01}
	inv.slots[30] = {"id": &"baixo", "amount": 3, "dur": 0.01}
	inv.slots[25] = {"id": &"comida_estragada", "amount": 1}
	inv.spoil(30.0)
	var rotten: Array = inv.slots.filter(func(s): return not s.is_empty() and s.id == &"comida_estragada")
	print("estragada: pilhas=", rotten.size(), " total=", rotten[0].amount, " aviso=", got)
	# Organizar
	for i in range(9, inv.slots.size()):
		inv.slots[i] = {}
	for it in [[&"cenoura", 3, 0.2], [&"tabua", 5, 1.0], [&"semente_trigo", 2, 1.0], [&"machado", 1, 1.0], [&"tronco", 4, 1.0], [&"lata", 1, 1.0], [&"atum", 1, 0.9], [&"espada", 1, 1.0], [&"capuz", 1, 1.0], [&"tabua", 3, 1.0]]:
		inv.slots[9 + randi() % 36] = {"id": it[0], "amount": it[1], "dur": it[2]} if inv.slots.size() else {}
	inv.sort_backpack()
	print("organizado: ", inv.slots.slice(9, 22).filter(func(s): return not s.is_empty()).map(func(s): return "%s:%d" % [s.id, s.amount]))
	# Fornalha estilo Minecraft
	var fr := placed.host_apply("place", ["furnace", Transform3D(Basis(), o + Vector3(4, 0, 2))])
	var furnace: PlacedObject = placed.objects[fr[0]]
	ContainerManager.i.host_apply("open", [Smelting.key_of(furnace), ""])
	ContainerManager.i.host_apply("put_at", [Smelting.key_of(furnace), 0, "minerio_cobre", 4, 1.0])
	ContainerManager.i.host_apply("put_at", [Smelting.key_of(furnace), 1, "carvao", 1, 1.0])
	var refused := ContainerManager.i.host_apply("put_at", [Smelting.key_of(furnace), 1, "pedra", 1, 1.0])
	print("fornalha recusa pedra como combustível: ", refused.is_empty())
	for k in 20:
		placed._smelt()
	print("fornalha depois de 20 s: ", ContainerManager.i.slots_of(Smelting.key_of(furnace)))
	var sf := placed.host_apply("place", ["stone_furnace", Transform3D(Basis(), o + Vector3(6, 0, 4))])
	var stone: PlacedObject = placed.objects[sf[0]]
	var sk := Smelting.key_of(stone)
	ContainerManager.i.host_apply("open", [sk, ""])
	ContainerManager.i.host_apply("put_at", [sk, 0, "minerio_ferro", 4, 1.0])
	ContainerManager.i.host_apply("put_at", [sk, 1, "carvao", 2, 1.0])
	for k in 8:
		placed._smelt()
	print("pedra fria: ", ContainerManager.i.slots_of(sk)[2])
	for k in 3:
		placed.host_apply("crank", [stone.net_id, 1.0])
	for k in 6:
		placed._smelt()
	print("pedra com fole: ", ContainerManager.i.slots_of(sk)[2])
	# Defumador com carvão + puxar da mochila
	var sm := placed.host_apply("place", ["smoker", Transform3D(Basis(), o + Vector3(-4, 0, 2))])
	var smoker: PlacedObject = placed.objects[sm[0]]
	inv.select(0)
	inv.slots[0] = {}
	inv.slots[40] = {"id": &"atum", "amount": 8}
	Cooking.interact(player, smoker)
	print("defumador sem carvão: peças=", smoker.crops.filter(func(c): return not c.is_empty()).size())
	inv.slots[41] = {"id": &"carvao", "amount": 3}
	Cooking.interact(player, smoker)
	print("com carvão: peças=", smoker.crops.filter(func(c): return not c.is_empty()).size(), " carvão gasto=", 3 - inv.count(&"carvao"), " carga=", smoker.extra.get("charge"))
	# Filtro puxa água suja da mochila
	var fl := placed.host_apply("place", ["filter", Transform3D(Basis(), o + Vector3(-4, 0, -2))])
	inv.slots[42] = {"id": &"agua_suja", "amount": 10}
	Cooking.interact(player, placed.objects[fl[0]])
	print("filtro puxou da mochila: ", placed.objects[fl[0]].crops.filter(func(c): return not c.is_empty()).size(), " de 6")
	# Muda na cova cresce
	var cv := placed.host_apply("place", ["ground", Transform3D(Basis(), o + Vector3(0, 0, 7))])
	var tr := placed.host_apply("plant_tree", [Transform3D(Basis(), o + Vector3(0, 0.04, 7)), cv[0]])
	print("muda na cova é decoração? ", placed.objects[tr[0]].extra.get("deco", false))
	# Peneira
	var sv := placed.host_apply("place", ["sieve", Transform3D(Basis(), o + Vector3(3, 0, -4))])
	placed.host_apply("machine_put", [sv[0], 100])
	for k in 200:
		placed.host_apply("crank", [sv[0], 1.0])
	print("peneira 100 argilas: ", placed.objects[sv[0]].get_interact_text())
	# Tocha
	inv.slots[0] = {"id": &"tocha", "amount": 1}
	inv.select(0)
	for k in 30:
		player._update_torch(1.0)
	print("tocha 30 s: %.1f%% , luz=%s" % [inv.slots[0].get("dur", 1.0) * 100.0, player._torch_light.visible])
	quit()
