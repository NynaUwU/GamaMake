extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	var o := player.global_position
	var inv := player.inventory
	# Comida estragando
	inv.add(&"atum", 2)
	inv.add(&"atum", 2, 0.5)
	var slot: Dictionary = inv.slots.filter(func(s): return not s.is_empty() and s.id == &"atum")[0]
	print("frescor médio de 2 frescos + 2 meio velhos=", snappedf(slot.dur, 0.01))
	inv.spoil(300.0)
	print("atum depois de +5 min: existe=", inv.count(&"atum"), " estragada=", inv.count(&"comida_estragada"))
	var key := "placed_77"
	ContainerManager.i.contents[key] = ContainerManager.empty_slots(21)
	ContainerManager.add_to(ContainerManager.i.contents[key], &"pao_fresco", 3)
	ContainerManager.i._spoil_timer = 0.0
	for k in 130:
		ContainerManager.i._spoil_timer = 0.0
		ContainerManager.i._process(0.016)
	print("pão no baú depois de 1300 s: ", ContainerManager.i.contents[key][0])
	# Moinho por manivela (pelo host)
	var q := placed.host_apply("place", ["quern", Transform3D(Basis(), o + Vector3(3, 0, 0))])
	var quern: PlacedObject = placed.objects[q[0]]
	placed.host_apply("machine_put", [quern.net_id, 5])
	for k in 13:
		placed.host_apply("crank", [quern.net_id, 1.0])
	print("moinho: ", quern.get_interact_text())
	var flour := inv.count(&"farinha")
	placed.host_apply("machine_take", [quern.net_id])
	await process_frame
	print("farinha pega: ", inv.count(&"farinha") - flour)
	# Segurar E de verdade (jogador) na roca
	var sp := placed.host_apply("place", ["spinning", Transform3D(Basis(), o + Vector3(0, 0, -2.5))])
	var wheel: PlacedObject = placed.objects[sp[0]]
	placed.host_apply("machine_put", [wheel.net_id, 4])
	player._crank_target = wheel
	player._crank_hold = 0.0
	player.stamina = player.max_stamina
	Input.action_press("interact")
	for k in 420:
		await physics_frame
	Input.action_release("interact")
	await physics_frame
	print("roca (segurando E 7 s): ", wheel.get_interact_text(), " stamina=", int(player.stamina))
	# Tear
	var lm := placed.host_apply("place", ["loom", Transform3D(Basis(), o + Vector3(-3, 0, 0))])
	placed.host_apply("machine_put", [lm[0], 6])
	for k in 10:
		placed.host_apply("crank", [lm[0], 1.0])
	print("tear: ", placed.objects[lm[0]].get_interact_text())
	# Fornalha de pedra + fole
	var sf := placed.host_apply("place", ["stone_furnace", Transform3D(Basis(), o + Vector3(5, 0, 4))])
	var furnace: PlacedObject = placed.objects[sf[0]]
	inv.add(&"minerio_ferro", 4)
	inv.add(&"carvao", 4)
	CraftingUI.heat_source = furnace
	var iron: Dictionary = CraftingUI.RECIPES.filter(func(r): return r.station == "fornalha_pedra" and r.cost.has(&"minerio_ferro"))[0]
	print("ferro na fornalha fria: ", CraftingUI.can_craft(inv, iron))
	for k in 3:
		placed.host_apply("crank", [furnace.net_id, 1.0])
	print("calor depois de 3 s de fole: %d%%, dá ferro: %s" % [Machines.heat(furnace) * 100.0, CraftingUI.can_craft(inv, iron)])
	placed.clock += 40.0
	print("40 s depois: %d%%, dá ferro: %s" % [Machines.heat(furnace) * 100.0, CraftingUI.can_craft(inv, iron)])
	print("fornalha de barro ainda funde minério de ferro? ", CraftingUI.RECIPES.any(func(r): return r.station == "fornalha" and r.cost.has(&"minerio_ferro")))
	# Forno: pão devolve a garrafa
	inv.add(&"farinha", 2)
	inv.add(&"agua", 1)
	var bottles := inv.count(&"garrafa")
	var bread: Dictionary = CraftingUI.RECIPES.filter(func(r): return r.id == &"pao_fresco")[0]
	CraftingUI.craft(player, bread)
	print("forno: pão=", inv.count(&"pao_fresco"), " garrafas +", inv.count(&"garrafa") - bottles)
	# Pedra de amolar (local)
	var gs := placed.host_apply("place", ["grindstone", Transform3D(Basis(), o + Vector3(-5, 0, 4))])
	player.equip_item(&"espada")
	inv.slots[inv.selected].dur = 0.3
	player.stamina = player.max_stamina
	for k in 60:
		Machines.crank_local(player, placed.objects[gs[0]], 0.1)
	print("amolar 6 s: durabilidade 30%% -> %d%%, stamina=%d" % [inv.slots[inv.selected].dur * 100.0, player.stamina])
	# Bomba: só na beira do lago
	var lake: Dictionary = WaterManager.i.lakes().filter(func(l): return not l.frozen)[0]
	var edge := Vector3(lake.center.x + lake.radius + 1.0, lake.level + 0.2, lake.center.y)
	var far := placed.host_apply("place", ["pump", Transform3D(Basis(), o + Vector3(8, 0, 8))])
	var near := placed.host_apply("place", ["pump", Transform3D(Basis(), edge)])
	print("bomba longe do lago aceita=", not far.is_empty(), " na beira=", not near.is_empty())
	inv.slots[0] = {"id": &"garrafa", "amount": 2}
	inv.select(0)
	player.stamina = player.max_stamina
	var dirty := inv.count(&"agua_suja")
	print("na mão: ", inv.selected_id(), " stamina=", player.stamina)
	for k in 32:
		Machines.crank_local(player, placed.objects[near[0]], 0.1)
	print("bomba 3,2 s: água suja +", inv.count(&"agua_suja") - dirty)
	# Filtro, defumador, composteira
	var fl := placed.host_apply("place", ["filter", Transform3D(Basis(), o + Vector3(0, 0, 6))])
	placed.host_apply("cook", [fl[0], 0, "agua_suja"])
	var sm := placed.host_apply("place", ["smoker", Transform3D(Basis(), o + Vector3(2, 0, 6))])
	placed.host_apply("cook", [sm[0], 0, "atum"])
	var cp := placed.host_apply("place", ["compost", Transform3D(Basis(), o + Vector3(-2, 0, 6))])
	placed.host_apply("cook", [cp[0], 0, "comida_estragada"])
	placed.clock += 200.0
	print("filtro -> ", Cooking.result_of(placed.objects[fl[0]].crops[0], placed.clock), ", defumador -> ", Cooking.result_of(placed.objects[sm[0]].crops[0], placed.clock),
		", composteira -> ", Cooking.result_of(placed.objects[cp[0]].crops[0], placed.clock))
	# Adubo: colheita em dobro
	var bd := placed.host_apply("place", ["pot_small", Transform3D(Basis(), o + Vector3(4, 0, -4))])
	var pot: PlacedObject = placed.objects[bd[0]]
	placed.host_apply("extra", [pot.net_id, {"fert": 3}])
	placed.host_apply("plant", [pot.net_id, 0, "trigo"])
	placed.clock += 400.0
	var before: int = get_nodes_in_group("interactable").filter(func(n): return n is PickupItem and n.item_id == &"trigo").reduce(func(a, n): return a + n.amount, 0)
	placed.host_apply("harvest", [pot.net_id, 0])
	await process_frame
	var got: int = get_nodes_in_group("interactable").filter(func(n): return n is PickupItem and n.item_id == &"trigo").reduce(func(a, n): return a + n.amount, 0) - before
	print("trigo adubado colhido: ", got, " (normal 2-4) adubo restante=", pot.extra.fert)
	quit()
