extends SceneTree
## Elétrica v2: bateria modular (células), ponteiros do dínamo e da bateria, interruptor
## com 2 bornes, isolador de cerâmica, motor elétrico nas máquinas (e não move dínamo),
## e as versões automáticas: peneira, fole, amolar, bomba e assador giratório.

func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	var terrain: TerrainWorld = main.get_node("Terrain")
	var at := player.global_position + Vector3(6, 0, -6)
	at.y = terrain.height_at(at.x, at.z)
	var spawn := func(kind: String, pos: Vector3, basis := Basis()) -> PlacedObject:
		var id: int = placed._next_id
		placed._spawn(id, kind, Transform3D(basis, pos))
		return placed.objects[id]
	var tick := func(n: int) -> void:
		for k in n:
			placed._power()
			placed._electric()
			placed._fluids()
			placed.clock += 1.0
	DayNight.i.hour = 12.0
	DayNight.i._apply()
	Weather.i.rain = 0.0
	# --- Bateria modular.
	var battery: PlacedObject = spawn.call("battery", at)
	player.inventory.add(&"celula", 3)
	for k in 3:
		Electric.interact(player, battery)
	print("bateria: %d células (capacidade %.0f), sobrou na mochila %d; painel: %s" % [Electric.cells(battery), Electric.capacity(battery),
		player.inventory.count(&"celula"), Electric.text(battery)])
	# --- Painel solar -> bateria -> interruptor -> lâmpada.
	var solar: PlacedObject = spawn.call("solar_panel", at + Vector3(-2, 0, 0))
	var sw: PlacedObject = spawn.call("switch", at + Vector3(2, 0, 0))
	var lamp: PlacedObject = spawn.call("lamp", at + Vector3(4, 0, 0))
	var other: PlacedObject = spawn.call("lamp", at + Vector3(2, 0, 3))
	placed.host_apply("cable", [solar.net_id, battery.net_id])
	placed.host_apply("cable", [battery.net_id, sw.net_id])
	placed.host_apply("cable", [sw.net_id, lamp.net_id])
	var third := placed.host_apply("cable", [sw.net_id, other.net_id])
	tick.call(3)
	print("interruptor ligado: lâmpada=%s; 3º cabo no interruptor (só 2 bornes) aceito=%s" % [Electric.powered(lamp), third.size() > 0])
	print("bornes: bateria fica no %s, lâmpada no %s" % ["esquerdo" if sw.to_local(Electric.end_point(sw, battery)).x < 0 else "direito",
		"esquerdo" if sw.to_local(Electric.end_point(sw, lamp)).x < 0 else "direito"])
	Electric.interact(player, sw)
	tick.call(2)
	print("interruptor desligado: lâmpada=%s (painel: %s)" % [Electric.powered(lamp), Electric.text(sw)])
	Electric.interact(player, sw)
	tick.call(2)
	print("ligado de novo: lâmpada=%s; textos sem consumo: lâmpada '%s', painel '%s'" % [Electric.powered(lamp), Electric.text(lamp), Electric.text(solar)])
	var fill: float = battery.extra.get("charge", 0.0) / Electric.capacity(battery)
	print("ponteiro da bateria: carga %.0f%% -> ângulo %.2f" % [fill * 100.0, battery.get_node("Needle").rotation.z])
	# --- Dínamo: ponteiro de consumo (carregar a bateria conta).
	var wheel: PlacedObject = spawn.call("water_wheel", at + Vector3(0, 0, 10))
	var port: Vector3 = Power.world_ports(wheel)[0][0]
	var dynamo: PlacedObject = spawn.call("dynamo", port + Vector3(0.7, -0.6, 0))
	placed.host_apply("cable", [dynamo.net_id, battery.net_id])
	battery.extra.charge = 0.0
	tick.call(3)
	print("dínamo gerando %.0f, ponteiro %.2f (bateria vazia enchendo)" % [Electric.output(dynamo), dynamo.extra.get("gauge", -1.0)])
	battery.extra.charge = Electric.capacity(battery)
	tick.call(2)
	print("bateria cheia: ponteiro do dínamo %.2f (só a lâmpada)" % dynamo.extra.get("gauge", -1.0))
	# --- Isolador: cabo esticado.
	var ins_a: PlacedObject = spawn.call("insulator", at + Vector3(-4, 2.0, 0), Basis.looking_at(Vector3.FORWARD))
	var ins_b: PlacedObject = spawn.call("insulator", at + Vector3(-4, 2.0, 6), Basis.looking_at(Vector3.FORWARD))
	var sag_tight := 2.0 - Electric.catenary(Electric.terminal(ins_a), Electric.terminal(ins_b), true)[6].y + Electric.terminal(ins_a).y - 2.0
	var sag_loose := Electric.terminal(ins_a).y - Electric.catenary(Electric.terminal(ins_a), Electric.terminal(ins_b), false)[6].y
	print("isolador: barriga de 6 m esticado %.2f m x solto %.2f m" % [Electric.terminal(ins_a).y - Electric.catenary(Electric.terminal(ins_a), Electric.terminal(ins_b), true)[6].y, sag_loose])
	# --- Motor elétrico num moinho.
	var quern: PlacedObject = spawn.call("quern", at + Vector3(8, 0, 0))
	var qport: Array = Power.world_ports(quern)[0]
	var out: Vector3 = qport[1]
	var motor: PlacedObject = spawn.call("electric_motor", qport[0], Basis(out, Vector3.UP, out.cross(Vector3.UP)))
	placed.host_apply("cable", [motor.net_id, battery.net_id])
	quern.extra["in"] = 4
	tick.call(4)
	print("motor no moinho: energia=%s, força %s, carga no eixo %s, farinha=%d (trigo sobrando %d)" % [Electric.powered(motor), quern.extra.get("pstate"),
		quern.extra.get("load"), quern.extra.get("out", 0), quern.extra.get("in", 0)])
	quern.extra["in"] = 0
	tick.call(3)
	print("moinho sem trigo: motor pede energia=%s" % Electric.wants(placed.objects, motor))
	# Motor ligado direto num dínamo: não gera nada (sem moto-contínuo).
	var dyn2: PlacedObject = spawn.call("dynamo", at + Vector3(14, 0, 0))
	var dport: Array = Power.world_ports(dyn2)[0]
	var motor2: PlacedObject = spawn.call("electric_motor", dport[0], Basis(dport[1], Vector3.UP, dport[1].cross(Vector3.UP)))
	placed.host_apply("cable", [motor2.net_id, battery.net_id])
	tick.call(3)
	print("motor no dínamo: força do motor %.0f (dínamo gera %.0f)" % [Power.output(motor2), Electric.output(dyn2)])
	# --- Máquinas automáticas com motor.
	var auto := {}
	for kind in ["sieve", "stone_furnace", "grindstone", "pump", "rotisserie"]:
		var m: PlacedObject = spawn.call(kind, at + Vector3(-12 + auto.size() * 4.5, 0, 14))
		var p: Array = Power.world_ports(m)[0]
		var mo: PlacedObject = spawn.call("electric_motor", p[0], Basis(p[1], Vector3.UP, p[1].cross(Vector3.UP)))
		placed.host_apply("cable", [mo.net_id, battery.net_id])
		auto[kind] = m
	var connector: PlacedObject = spawn.call("connector", at + Vector3(-6, 0, 10))
	placed.host_apply("cable", [connector.net_id, battery.net_id])
	for kind in auto:
		var mo_id := -1
		for obj in placed.objects.values():
			if obj.kind == "electric_motor" and obj.global_position.distance_to(Power.world_ports(auto[kind])[0][0]) < 0.1:
				mo_id = obj.net_id
		placed.host_apply("cable", [mo_id, connector.net_id])
	auto.sieve.extra["in"] = 3
	ContainerManager.i.contents[Smelting.key_of(auto.stone_furnace)] = ContainerManager.empty_slots(3)
	ContainerManager.i.contents[Smelting.key_of(auto.stone_furnace)][Smelting.INPUT] = {"id": &"minerio_ferro", "amount": 2}
	auto.grindstone.extra.pstate = "ok"
	player.inventory.add(&"machado", 1, 0.3)
	player.inventory.selected = player.inventory.slots.find(player.inventory.slots.filter(func(s): return not s.is_empty() and s.id == &"machado")[0])
	AutoMachines.grind_tap(player, auto.grindstone)
	var tank: PlacedObject = spawn.call("water_tank", Fluids.world_ports(auto.pump)[0][0] + Vector3(0.62 + 0.02, -0.35 + 0.25 - 0.25, 0))
	auto.rotisserie.extra.fuel_until = placed.clock + 9999.0
	battery.extra.charge = Electric.capacity(battery)
	tick.call(3)
	for k in 4:
		auto.rotisserie.crops[k] = Cooking.make_entry("rotisserie", &"carne_crua", placed.clock)
	tick.call(20)
	print("peneira com motor: argila %d, pedras %d" % [auto.sieve.extra.get("in", 0), auto.sieve.extra.get("out", 0)])
	print("fornalha de pedra com motor: calor %.0f%%" % (Machines.heat(auto.stone_furnace) * 100.0))
	print("amolar com motor: machado na pedra %s (afiar não mexe na durabilidade)" % [auto.grindstone.extra.get("tool", {})])
	print("bomba com motor: força %s, caixa d'água %.1f" % [auto.pump.extra.get("pstate"), tank.extra.get("water", 0.0)])
	placed.clock += 600.0 # muito depois de pronta: no assador não queima
	print("assador: força %s, depois de 10 min a carne é %s" % [auto.rotisserie.extra.get("pstate"), Cooking.result_of(auto.rotisserie.crops[0], placed.clock)])
	var took := AutoMachines.grind_tap(player, auto.grindstone)
	await process_frame
	print("pegar da pedra: tap=%s, na pedra agora %s, machados na mochila %d" % [took, auto.grindstone.extra.get("tool", {}), player.inventory.count(&"machado")])
	var axe := {}
	for k in player.inventory.slots.size():
		var s2: Dictionary = player.inventory.slots[k]
		if not s2.is_empty() and s2.id == &"machado":
			axe = s2
			player.inventory.selected = k
	print("pegou o machado de volta: durabilidade %.0f%%, fio %.0f%%, dano x%.2f" % [axe.get("dur", 1.0) * 100.0, axe.get("sharp", 0.0) * 100.0, player._sharp_mult()])
	for k in 10:
		player._wear_selected(1.0)
	print("depois de 10 golpes: fio %.0f%%, dano x%.2f" % [axe.get("sharp", 0.0) * 100.0, player._sharp_mult()])
	# Pedra na mão (sem força): segurar E afia a espada da mão, sem consertar.
	var stone: PlacedObject = spawn.call("grindstone", at + Vector3(-14, 0, -8))
	player.inventory.add(&"espada", 1, 0.5)
	for k in player.inventory.slots.size():
		if not player.inventory.slots[k].is_empty() and player.inventory.slots[k].id == &"espada":
			player.inventory.selected = k
	player.stamina = player.max_stamina
	for k in 30:
		Machines.crank_local(player, stone, 0.25)
	var sword: Dictionary = player.inventory.slots[player.inventory.selected]
	print("afiando na mão por 7,5 s: espada fio %.0f%%, durabilidade %.0f%% (continua gasta)" % [sword.get("sharp", 0.0) * 100.0, sword.get("dur", 1.0) * 100.0])
	quit()
