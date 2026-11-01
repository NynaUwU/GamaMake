extends SceneTree
## Tier 3: canos (caixa d'água -> caldeira, caldeira -> motor), vapor vira força no
## torno e no alto-forno (multibloco), destilaria, aspersor, caldeira seca explode,
## carro abastece com álcool. Avança o relógio das máquinas na mão (1 tick = 1 s).

var placed: PlacedManager
var h := 0.0


func _pipe(a: Vector3, b: Vector3) -> int:
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
	var r := placed.host_apply("pipe", [Transform3D(Basis.looking_at(-dir, up), a), a.distance_to(b)])
	return r[0] if not r.is_empty() else -1


func _place(kind: String, at: Vector3, basis := Basis()) -> PlacedObject:
	var r := placed.host_apply("place", [kind, Transform3D(basis, at)])
	return placed.objects.get(r[0]) if not r.is_empty() else null


func _port(obj: PlacedObject, index: int) -> Vector3:
	return obj.global_transform * Fluids.PORTS[obj.kind][index][0]


func _tick(seconds: int) -> void:
	for k in seconds:
		placed.clock += 1.0
		placed._smelt()
		placed._fluids()
		placed._power()


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	placed = main.get_node("Placed")
	var terrain: TerrainWorld = main.get_node("Terrain")
	h = terrain.height_at(14, 14)
	var cm := ContainerManager.i
	# Caixa d'água cheia -> cano -> caldeira com carvão.
	var tank := _place("water_tank", Vector3(8, h, 12))
	tank.extra.water = 40.0
	var boiler := _place("boiler", Vector3(12, h, 12))
	cm.contents[Smelting.key_of(boiler)] = [{}, {"id": &"carvao", "amount": 10}, {}]
	var p1 := _pipe(_port(tank, 0), _port(boiler, 0))
	var engine := _place("steam_engine", Vector3(14, h, 14))
	var p2 := _pipe(_port(boiler, 1), _port(engine, 0))
	print("canos: %d %d  ligados caixa-cano=%s cano-caldeira=%s caldeira-cano=%s cano-motor=%s" % [p1, p2,
		Fluids.touching(tank, placed.objects[p1]), Fluids.touching(placed.objects[p1], boiler),
		Fluids.touching(boiler, placed.objects[p2]), Fluids.touching(placed.objects[p2], engine)])
	# Motor -> correia -> torno e alto-forno.
	var lathe := _place("lathe", Vector3(19, h, 14))
	var blast := _place("blast_furnace", Vector3(19, h, 9))
	var ring1 := _place("blast_stack", blast.global_position + Vector3.UP * Fluids.BLAST_BASE_H)
	print("anel no chão aceito=%s" % (_place("blast_stack", Vector3(25, h, 25)) != null))
	print("alto-forno com 1 anel: completo=%s" % Fluids.blast_complete(blast))
	var ring2 := _place("blast_stack", ring1.global_position + Vector3.UP * Fluids.BLAST_RING_H)
	print("alto-forno com 2 anéis: completo=%s (anéis %s %s)" % [Fluids.blast_complete(blast), ring1 != null, ring2 != null])
	engine.extra.belts = [lathe.net_id, blast.net_id]
	cm.contents[Smelting.key_of(blast)] = [{"id": &"barra_ferro", "amount": 6}, {"id": &"carvao", "amount": 5}, {}]
	var log := []
	for s in 40:
		_tick(1)
		if s in [4, 14, 24, 39]:
			log.append("t=%ds calor=%.2f água caldeira=%.1f caixa=%.1f pressão=%.2f vapor motor=%.2f força=%.1f torno=%.2f" % [s + 1,
				boiler.extra.get("heat", 0.0), boiler.extra.get("water", 0.0), tank.extra.get("water", 0.0),
				boiler.extra.get("pressure", 0.0), engine.extra.get("steam", 0.0), Power.output(engine), lathe.extra.get("speed", 0.0)])
	for line in log:
		print(line)
	print("cano mostra: ", placed.objects[p2].get_interact_text(), " | ", placed.objects[p1].get_interact_text())
	# Torno: com força, faz parafusos.
	var player: Player = main.player
	player.inventory.add(&"barra_ferro", 3)
	CraftingUI.heat_source = lathe
	var screw: Dictionary = CraftingUI.RECIPES.filter(func(r): return r.station == "torno" and r.id == &"parafuso")[0]
	print("torno girando=%s pode fazer parafuso=%s" % [CraftingUI.powered(lathe), CraftingUI.can_craft(player.inventory, screw)])
	CraftingUI.craft(player, screw, 1)
	print("parafusos na mochila: %d" % player.inventory.count(&"parafuso"))
	# Alto-forno: o fole gira e o ferro vira aço.
	_tick(40)
	var bslots: Array = cm.contents[Smelting.key_of(blast)]
	print("alto-forno: fole=%.2f entrada=%s saída=%s" % [blast.extra.get("speed", 0.0), bslots[0], bslots[2]])
	# Destilaria: água despejada + trigo + carvão.
	var still := _place("distillery", Vector3(8, h, 18))
	placed.host_apply("pour", [still.net_id])
	placed.host_apply("pour", [still.net_id])
	cm.contents[Smelting.key_of(still)] = [{"id": &"trigo", "amount": 8}, {"id": &"carvao", "amount": 3}, {}]
	_tick(30)
	var sslots: Array = cm.contents[Smelting.key_of(still)]
	print("destilaria: água=%.1f entrada=%s saída=%s" % [still.extra.get("water", 0.0), sslots[0], sslots[2]])
	# Aspersor ligado na caixa d'água.
	var sprinkler := _place("sprinkler", Vector3(5, h, 9))
	var p3 := _pipe(_port(tank, 3), _port(sprinkler, 0))
	_tick(2)
	print("aspersor: cano=%d molhado=%s planta perto irrigada=%s" % [p3, sprinkler.extra.get("wet", false), placed.irrigated(Vector3(6, h, 10))])
	# Caldeira seca com fogo: apita e explode.
	var dry := _place("boiler", Vector3(30, h, 30))
	cm.contents[Smelting.key_of(dry)] = [{}, {"id": &"carvao", "amount": 5}, {}]
	var exploded_at := -1
	for s in 60:
		_tick(1)
		if not placed.objects.has(dry.net_id if is_instance_valid(dry) else -1):
			exploded_at = s + 1
			break
	print("caldeira seca explodiu em %d s" % exploded_at)
	# Carro: abastece com álcool.
	var car: VintageCar = null
	for c in main.get_tree().get_nodes_in_group("vehicle"):
		if c is VintageCar:
			car = c
			break
	if car:
		car.fuel = 0.1
		Net.i.refuel_car(car, VintageCar.FUEL_ITEMS[&"alcool"])
		print("carro: tanque 10%% + álcool = %d%%  texto: %s" % [int(car.fuel * 100.0), car.get_interact_text()])
	# Encaixe da ferramenta de cano.
	var snap := Fluids.snap_point(placed.objects, _port(engine, 0) + Vector3(0.2, 0.1, 0.0), 0.5)
	print("encaixe perto da porta do motor: %s" % (snap.distance_to(_port(engine, 0)) < 0.01))
	# Ferramenta de cano: um trecho de 3 m gasta 2 canos.
	player.inventory.add(&"cano", 5)
	var before := placed.objects.size()
	var a := Vector3(4, h + 0.5, 4)
	player.pipe_tool._finish(placed, {"a": a, "b": a + Vector3(3, 0, 0), "len": 3.0, "valid": true, "snapped": false})
	await process_frame
	print("ferramenta de cano: objetos %d -> %d, canos sobrando %d" % [before, placed.objects.size(), player.inventory.count(&"cano")])
	# Janelas das máquinas abrem e fecham sem erro.
	for obj in [boiler, blast, still]:
		player.ui_blocked = false
		StorageUI.open_for(player, Smelting.key_of(obj), obj)
		await process_frame
		await process_frame
		var ui := main.get_children().filter(func(n): return n is StorageUI)
		print("janela %s: %s" % [obj.kind, ui[0]._status.text if not ui.is_empty() and ui[0]._status else "(sem aviso)"])
		for u in ui:
			u.close()
	# Fantasma do martelo de cada máquina nova.
	var counts := []
	for kind in ["blast_furnace", "blast_stack", "boiler", "steam_engine", "water_tank", "sprinkler", "lathe", "press", "distillery"]:
		player.builder._model_kind = ""
		player.builder._build_model_ghost(kind)
		counts.append("%s=%d" % [kind, player.builder._model_ghost.get_child_count()])
	print("fantasmas: ", " ".join(counts))
	# Save e volta: canos voltam com o tamanho certo.
	var data := placed.save_data()
	placed.load_data(data)
	print("depois de carregar: cano %d tem %.2f m (%s)" % [p2, placed.objects[p2].extra.get("len", 0.0), placed.objects[p2].has_node("PipeMesh")])
	quit()
