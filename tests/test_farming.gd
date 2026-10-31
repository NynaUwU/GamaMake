extends SceneTree
## Fase 3: caixote inicial, custo de construção, potes/canteiro, plantar e
## colher, pá cavando, fome e bancada.
var main: Node

func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(20)
	main = current_scene
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	print("bancada inicial=", placed.objects.values().map(func(o): return o.kind))
	# Revista o caixote inicial e pega tudo que caiu.
	var crate: LootBox = main.get_node("CaixoteInicial")
	crate.interact(player)
	await _frames(5)
	var got := 0
	for item in get_nodes_in_group("interactable"):
		if item is PickupItem and item.global_position.distance_to(crate.global_position) < 4.0:
			item.take_locally(player)
			got += 1
	await _frames(2)
	print("caixote: itens=", got, " tabua=", player.inventory.count(&"tabua"), " pedra=", player.inventory.count(&"pedra"),
		" pa=", player.inventory.count(&"pa"), " revistado=", Net.i.taken.has("loot_inicio"), " interagível=", crate.is_in_group("interactable"))
	# Custo: martelo coloca parede.
	player.equip_item(&"martelo")
	var builder: Builder = player.builder
	var before := player.inventory.count(&"tabua")
	builder.target = {"kind": BuildPiece.Kind.WALL, "cell": Vector3i(10, 0, 30), "rot": 0, "valid": true}
	builder.selection = Builder.ENTRIES["Estrutura"][0]
	builder.use("hammer")
	await _frames(2)
	print("parede: tabua ", before, " -> ", player.inventory.count(&"tabua"))
	# Pote pequeno pelo martelo.
	builder.select(Builder.entry_for("place", "pot_small"))
	builder.target = {"xform": Transform3D(Basis(), player.global_position + Vector3(0, 0, -2)), "valid": true}
	var stones := player.inventory.count(&"pedra")
	builder.use("hammer")
	await _frames(2)
	var pot: PlacedObject = null
	for o in placed.objects.values():
		if o.kind == "pot_small":
			pot = o
	print("pote colocado=", pot != null, " pedra ", stones, " -> ", player.inventory.count(&"pedra"))
	# Planta cenoura e acelera o relógio.
	placed.request("plant", [pot.net_id, 0, "cenoura"])
	print("plantado: ", pot.crops[0], " texto=", pot.get_interact_text())
	placed.request("plant", [pot.net_id, 0, "batata"])
	print("vaga ocupada recusa: ", pot.crops[0].crop)
	placed.clock += 250.0
	pot.refresh(placed.clock)
	await _frames(2)
	print("pronta: ", pot.get_interact_text(), " estágio=", pot._stages[0])
	pot.interact(player)
	await _frames(5)
	var carrots := 0
	for item in get_nodes_in_group("interactable"):
		if item is PickupItem and item.item_id in [&"cenoura", &"semente_cenoura"]:
			carrots += item.amount
	print("colheu: itens no chão (cenoura+sementes)=", carrots, " vaga vazia=", pot.crops[0].is_empty())
	# Abóbora não cabe no pote pequeno.
	print("abóbora no pote pequeno recusada=", placed.host_apply("plant", [pot.net_id, 0, "abobora"]).is_empty())
	# Canteiro (9 vagas) + cova.
	var bed := placed.host_apply("place", ["bed", BuildPiece.piece_transform(BuildPiece.Kind.FLOOR, Vector3i(20, 0, 40), 0)])
	var cova := placed.host_apply("place", ["ground", Transform3D(Basis(), Vector3(4, 0, 20))])
	print("canteiro vagas=", placed.objects[bed[0]].crops.size(), " cova vagas=", placed.objects[cova[0]].crops.size())
	# Fome.
	player.hunger = 30.0
	player.inventory.slots[4] = {"id": &"lata", "amount": 1}
	player.inventory.select(4)
	player._eat_selected()
	print("fome 30 + lata = ", player.hunger)
	# Bancada: fabrica bandagem com 2 panos.
	player.inventory.add(&"pano", 2)
	CraftingUI.open_for(player)
	await _frames(2)
	var ui: CraftingUI = null
	for c in main.get_children():
		if c is CraftingUI:
			ui = c
	ui.craft(CraftingUI.RECIPES.filter(func(r): return r.id == &"bandagem")[0])
	print("bandagem=", player.inventory.count(&"bandagem"), " pano=", player.inventory.count(&"pano"))
	ui.close()
	# Save guarda os potes e as plantas.
	placed.request("plant", [bed[0], 4, "abobora"])
	var data := placed.save_data()
	placed.load_data(data)
	print("depois de recarregar: objetos=", placed.objects.size(), " canteiro vaga 4=", placed.objects[bed[0]].crops[4].get("crop"))
	# Pá cavando o terreno (olhando para o chão, longe de tudo).
	var terrain: TerrainWorld = main.get_node("Terrain")
	var spot := Vector3(40, 0, -40)
	terrain.update_around(spot, -1, 60.0)
	await _frames(3)
	player.global_position = Vector3(spot.x, terrain.height_at(spot.x, spot.z) + 0.1, spot.z)
	player.head.rotation.x = -1.2
	await physics_frame
	await physics_frame
	var count := placed.objects.size()
	var dug := Farming.use(player, "")
	print("pá cavou=", dug, " objetos ", count, " -> ", placed.objects.size())
	quit()

func _frames(n: int) -> void:
	for i in n:
		await process_frame
