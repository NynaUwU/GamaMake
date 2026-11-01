extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var player: Player = main.player
	var animals: AnimalManager = main.get_node("Animals")
	var placed: PlacedManager = main.get_node("Placed")
	var o := player.global_position
	for k in 30:
		animals._populate()
	var kinds := {}
	for a in animals.animals.values():
		kinds[a.kind] = kinds.get(a.kind, 0) + 1
	print("animais em volta: ", kinds)
	# Cervo foge
	var deer: Animal = animals.spawn("cervo", o + Vector3(8, 0.5, 0))
	await create_timer(0.3).timeout
	var d0 := deer.global_position.distance_to(player.global_position)
	await create_timer(2.0).timeout
	print("cervo fugiu: %.1f m -> %.1f m" % [d0, deer.global_position.distance_to(player.global_position)])
	# Javali revida
	var boar: Animal = animals.spawn("javali", o + Vector3(-4, 0.5, 0))
	await create_timer(0.3).timeout
	var hp0 := player.health
	boar.take_hit(HitInfo.make(10.0, &"", boar.global_position, Vector3.LEFT, 1.0))
	await create_timer(3.0).timeout
	print("javali bravo mordeu: vida %d -> %d" % [hp0, player.health])
	# Matar e pegar
	var before := get_nodes_in_group("interactable").filter(func(n): return n is PickupItem).size()
	boar.take_hit(HitInfo.make(500.0, &"", boar.global_position, Vector3.LEFT, 1.0))
	await process_frame
	await process_frame
	var drops := get_nodes_in_group("interactable").filter(func(n): return n is PickupItem and n.item_id in [&"carne_crua", &"pele", &"gordura"]).map(func(n): return "%s x%d" % [n.item_id, n.amount])
	print("javali morto soltou: ", drops)
	# Secador: pele -> couro; fogueira: carne -> assada
	var dr := placed.host_apply("place", ["dryer", Transform3D(Basis(), o + Vector3(3, 0, 3))])
	placed.host_apply("cook", [dr[0], 0, "pele"])
	placed.host_apply("cook", [dr[0], 1, "carne_crua"])
	placed.clock += 120.0
	print("secador: pele -> ", Cooking.result_of(placed.objects[dr[0]].crops[0], placed.clock), ", carne -> ", Cooking.result_of(placed.objects[dr[0]].crops[1], placed.clock))
	# Frio: noite no frio sem roupa x com casaco de pele x perto do fogo
	DayNight.i.hour = 2.0
	DayNight.i._apply()
	Weather.i.rain = 1.0
	var base := player.ambient_temperature()
	print("noite + chuva aqui: %.1f°  isolamento sem roupa=%.2f" % [base, player.insulation()])
	player.heat = 100.0
	for k in 120:
		player._cold_timer = 0.0
		player._update_cold(0.5)
	print("1 min assim, sem roupa: calor do corpo %.0f, sentida %.1f°" % [player.heat, player.temperature])
	player.inventory.equipment["body"] = {"id": &"casaco_pele"}
	player.inventory.equipment["head"] = {"id": &"capuz"}
	player._cold_timer = 0.0
	player._update_cold(0.5)
	print("com casaco de pele + capuz: sentida %.1f°" % player.temperature)
	player.inventory.equipment["body"] = {}
	player.inventory.equipment["head"] = {}
	var cf := placed.host_apply("place", ["campfire", Transform3D(Basis(), player.global_position + Vector3(1.5, 0, 0))])
	placed.host_apply("fuel", [cf[0], 900.0, "fuel_until"])
	player._cold_timer = 0.0
	player._update_cold(0.5)
	print("ao lado da fogueira acesa, sem roupa: sentida %.1f°" % player.temperature)
	# Rio: margem plana
	var terrain: TerrainWorld = main.get_node("Terrain")
	var r: Dictionary = terrain.rivers[0]
	var p: Vector2 = r.points[10]
	var dv: Vector2 = (r.points[11] - r.points[10]).normalized()
	var side := Vector2(-dv.y, dv.x)
	var hs := []
	for dist in [r.width * 0.5 + 1.0, r.width * 0.5 + 6.0, r.width * 0.5 + 12.0]:
		var q: Vector2 = p + side * dist
		hs.append(snappedf(terrain.height_at(q.x, q.y) - r.levels[10], 0.01))
	print("margem do rio (altura acima da água a 1, 6 e 12 m da beira): ", hs)
	quit()
