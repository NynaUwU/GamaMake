extends SceneTree
## Tier 4: rede elétrica (painel solar, bateria, lâmpada, dínamo na roda d'água,
## falta de energia), bomba elétrica, cerca elétrica, geladeira x baú, rádio,
## tocha posta (duração, reabastecer, devolver) e decorações.

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
	# --- Painel solar + bateria + lâmpada, ligados por cabo.
	var solar: PlacedObject = spawn.call("solar_panel", at)
	var battery: PlacedObject = spawn.call("battery", at + Vector3(2, 0, 0))
	var lamp: PlacedObject = spawn.call("lamp", at + Vector3(4, 0, 0))
	player.inventory.add(&"cabo", 10)
	print("cabo painel-bateria: %s, bateria-lâmpada: %s, longe (20 m): %s" % [placed.host_apply("cable", [solar.net_id, battery.net_id]).size() > 0,
		placed.host_apply("cable", [battery.net_id, lamp.net_id]).size() > 0, Electric.cable_ok(solar, spawn.call("connector", at + Vector3(0, 0, 20)))])
	DayNight.i.hour = 12.0
	DayNight.i._apply()
	Weather.i.rain = 0.0
	for k in 20:
		placed._electric()
	print("meio-dia: painel gera %.1f, lâmpada acesa=%s, bateria %.0f (+%.1f/s)" % [Electric.output(solar), Electric.powered(lamp),
		battery.extra.get("charge", 0.0), battery.extra.get("charge", 0.0) / 20.0])
	DayNight.i.hour = 1.0
	DayNight.i._apply()
	var before: float = battery.extra.charge
	for k in 10:
		placed._electric()
	print("noite: painel gera %.1f, lâmpada acesa (da bateria)=%s, bateria %.0f -> %.0f" % [Electric.output(solar), Electric.powered(lamp), before, battery.extra.charge])
	battery.extra.charge = 0.2
	placed._electric()
	print("bateria vazia de noite: lâmpada acesa=%s, estado=%s, painel: %s" % [Electric.powered(lamp), lamp.extra.get("estate"), Electric.text(lamp)])
	lamp.extra.on = false
	placed._electric()
	print("lâmpada desligada no interruptor: pede energia=%s" % [Electric.powered(lamp)])
	lamp.extra.on = true
	# --- Dínamo na roda d'água.
	var wheel: PlacedObject = spawn.call("water_wheel", at + Vector3(0, 0, 8))
	var port: Vector3 = Power.world_ports(wheel)[0][0]
	var dynamo: PlacedObject = spawn.call("dynamo", port + Vector3(0.7, -0.6, 0))
	placed.host_apply("cable", [dynamo.net_id, lamp.net_id])
	for k in 3:
		placed._power()
		placed._electric()
	print("dínamo na roda: força %s, gera %.0f, carga no eixo=%s (rede: %s), lâmpada=%s" % [dynamo.extra.get("pstate"), Electric.output(dynamo),
		Power.busy(dynamo), dynamo.extra.get("load"), Electric.powered(lamp)])
	# --- Bomba elétrica enchendo a caixa d'água.
	var tank: PlacedObject = spawn.call("water_tank", at + Vector3(-4, 0, 4))
	var tank_port: Vector3 = Fluids.world_ports(tank)[1][0]
	var pump: PlacedObject = spawn.call("electric_pump", tank_port - Vector3(0.45, 0.25, 0) - Vector3(0.02, 0, 0))
	placed.host_apply("cable", [pump.net_id, dynamo.net_id])
	for k in 6:
		placed._power()
		placed._electric()
		placed._fluids()
	print("bomba elétrica: com energia=%s, caixa d'água %.1f" % [Electric.powered(pump), tank.extra.get("water", 0.0)])
	# --- Cerca elétrica dá choque.
	var fence: PlacedObject = spawn.call("electric_fence", at + Vector3(2, 0, 4))
	placed.host_apply("cable", [fence.net_id, dynamo.net_id])
	for k in 3:
		placed._power()
		placed._electric()
	var zombie: Zombie = main.ZOMBIE_SCENE.instantiate()
	zombie.position = fence.global_position + Vector3(0.3, 0.3, 0.3)
	main.enemies.add_child(zombie)
	var hp := zombie.health
	await physics_frame
	zombie.global_position = fence.global_position + Vector3(0.3, 0.2, 0.3)
	for k in 20:
		await physics_frame
	print("cerca elétrica: ligada=%s, zumbi %.0f -> %.0f de vida, tonto=%s" % [Electric.powered(fence), hp, zombie.health, zombie.state == Zombie.State.STUNNED if "STUNNED" in Zombie.State else "?"])
	zombie.queue_free()
	# --- Geladeira x baú.
	var fridge: PlacedObject = spawn.call("fridge", at + Vector3(6, 0, 0))
	var chest: PlacedObject = spawn.call("chest", at + Vector3(8, 0, 0))
	placed.host_apply("cable", [fridge.net_id, lamp.net_id])
	for k in 3:
		placed._power()
		placed._electric()
	for obj in [fridge, chest]:
		var slots := ContainerManager.empty_slots(ContainerManager.STORAGE_SLOTS)
		ContainerManager.add_to(slots, &"carne_crua", 3)
		ContainerManager.i.contents["placed_%d" % obj.net_id] = slots
	for k in 12:
		placed._spoil_containers()
	var dur_f: float = ContainerManager.i.slots_of("placed_%d" % fridge.net_id)[0].get("dur", 1.0)
	var dur_c: float = ContainerManager.i.slots_of("placed_%d" % chest.net_id)[0].get("dur", 1.0)
	print("2 min guardada: carne na geladeira ligada %.0f%%, no baú %.0f%% (geladeira com energia=%s)" % [dur_f * 100.0, dur_c * 100.0, Electric.powered(fridge)])
	# --- Rádio.
	var radio: PlacedObject = spawn.call("radio", at + Vector3(10, 0, 0))
	placed.host_apply("cable", [radio.net_id, lamp.net_id])
	for k in 3:
		placed._power()
		placed._electric()
	DayNight.i.hour = 15.0
	DayNight.i._apply()
	var update := Radio.broadcast(placed, radio)
	print("rádio ligado=%s, transmissão: %s" % [Electric.powered(radio), update.msg])
	radio.extra.mission = {"items": {"tabua": 2, "barra_ferro": 1}}
	player.inventory.add(&"tabua", 2)
	player.inventory.add(&"barra_ferro", 1)
	var items_before := 0
	for s in player.inventory.slots:
		if not s.is_empty():
			items_before += s.amount
	Radio.interact(player, radio)
	await process_frame
	var items_after := 0
	for s in player.inventory.slots:
		if not s.is_empty():
			items_after += s.amount
	print("pedido entregue: pedido agora=%s, itens na mochila %d -> %d (recompensa)" % [radio.extra.get("mission", {}), items_before, items_after])
	print("bússola: 0=%s, -PI/2=%s, PI/2=%s" % [Radio.compass(0.0), Radio.compass(-PI / 2), Radio.compass(PI / 2)])
	# --- Tocha posta: duração, reabastecer e devolver.
	var r := placed.host_apply("place", ["torch_wall", Transform3D(Basis(), at + Vector3(0, 1.5, -3)), {"fuel": 300.0}])
	var torch: PlacedObject = placed.objects[r[0]]
	print("tocha na parede: acesa=%s, queima %.0f s" % [torch.is_lit(placed.clock), PlacedTorch.left(torch, placed.clock)])
	player.inventory.add(&"pano", 1)
	player.inventory.add(&"graveto", 1)
	PlacedTorch.interact(player, torch)
	await process_frame
	print("reabasteceu com pano + graveto: queima %.0f s" % PlacedTorch.left(torch, placed.clock))
	var count_before := player.inventory.count(&"tocha")
	placed.host_apply("remove", [torch.net_id])
	await process_frame
	var dur := -1.0
	for s in player.inventory.slots:
		if not s.is_empty() and s.id == &"tocha":
			dur = s.get("dur", 1.0)
	print("desmontou: tochas %d -> %d (frescor %.2f)" % [count_before, player.inventory.count(&"tocha"), dur])
	var spot_floor := PlacedTorch.spot({"position": at, "normal": Vector3.UP}, 0.0)
	var spot_wall := PlacedTorch.spot({"position": at, "normal": Vector3.RIGHT}, 0.0)
	print("tocha: chão=%s, parede=%s (frente da tocha para %s)" % [spot_floor.kind, spot_wall.kind, spot_wall.xform.basis.z.snapped(Vector3.ONE * 0.01)])
	# --- Decorações e o relógio.
	var kinds := Decor.FLOOR_KINDS + Decor.WALL_KINDS
	var ok := 0
	for k in kinds.size():
		var res := placed.host_apply("place", [kinds[k], Transform3D(Basis(), at + Vector3(-10 + k * 1.6, 0, -12))])
		if res.size() > 0:
			ok += 1
	var clock: PlacedObject = placed.objects[placed._next_id - 1]
	DayNight.i.hour = 15.5
	clock.refresh(placed.clock)
	print("decorações postas: %d de %d; relógio às 15:30: ponteiro das horas %.0f°, minutos %.0f°" % [ok, kinds.size(),
		rad_to_deg(-clock.get_node("Hour").rotation.z), rad_to_deg(-clock.get_node("Minute").rotation.z)])
	print("martelo: lâmpada na parede vira %s, conector %s, quadro %s, mesa '%s'" % [Builder.wall_kind("lamp"), Builder.wall_kind("connector"),
		Builder.wall_kind("deco_painting"), Builder.wall_kind("deco_table")])
	print("cabo de 9 m gasta %d; barriga de um cabo de 10 m: %.2f m" % [Electric.cable_cost(9.0), Vector3.ZERO.lerp(Vector3(10, 0, 0), 0.5).y - Electric.catenary(Vector3.ZERO, Vector3(10, 0, 0))[6].y])
	# Save/load: cabos e carga voltam.
	var state := placed.save_data()
	placed.load_data(state)
	Electric.dirty = true
	var bat2: PlacedObject = placed.objects[battery.net_id]
	print("save/load: cabos da bateria %s, carga %.0f" % [bat2.extra.get("cables", []), bat2.extra.get("charge", 0.0)])
	quit()
