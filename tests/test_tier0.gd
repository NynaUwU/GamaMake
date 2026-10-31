extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	var origin := player.global_position
	# Chuva + coletor
	Weather.i.target_rain = 1.0
	Weather.i.rain = 1.0
	var col := placed.host_apply("place", ["rain_collector", Transform3D(Basis(), origin + Vector3(3, 0, 3))])
	var collector: PlacedObject = placed.objects[col[0]]
	for k in 60:
		placed._collect_rain()
	print("coletor depois de 60 s de chuva: ", snappedf(collector.extra.get("water", 0.0), 0.1), " garrafas; texto=", collector.get_interact_text())
	player.inventory.add(&"garrafa", 3)
	var before := player.inventory.count(&"agua")
	player.inventory.select(player.inventory.slots.find(player.inventory.slots.filter(func(s): return not s.is_empty() and s.id == &"garrafa")[0]))
	placed.request("draw_water", [collector.net_id])
	player.inventory.take(player.inventory.selected, 1)
	await process_frame
	print("água potável: ", before, " -> ", player.inventory.count(&"agua"), " coletor=", snappedf(collector.extra.water, 0.1))
	# Sede, beber, doença
	player.thirst = 30.0
	player.equip_item(&"agua")
	player._eat_selected()
	print("sede depois de beber água: ", int(player.thirst), " garrafas=", player.inventory.count(&"garrafa"))
	var sick := false
	for k in 8:
		player.inventory.add(&"agua_suja", 1)
		player.equip_item(&"agua_suja")
		player.thirst = 10.0
		player._eat_selected()
		sick = sick or player.sick_time > 0.0
	print("água suja deixou doente=", sick)
	var regen := player.stamina_regen
	var h0 := player.hunger
	player._update_hunger(10.0)
	print("doente: fome caiu %.2f em 10 s (normal %.2f)" % [h0 - player.hunger, Player.HUNGER_RATE * 10.0])
	# Secador
	var dr := placed.host_apply("place", ["dryer", Transform3D(Basis(), origin + Vector3(-3, 0, 3))])
	var dryer: PlacedObject = placed.objects[dr[0]]
	placed.host_apply("cook", [dryer.net_id, 0, "atum"])
	print("secador: ", dryer.get_interact_text())
	placed.clock += 300.0
	dryer.refresh(placed.clock)
	print("secador depois de 5 min: ", dryer.get_interact_text(), " -> ", Cooking.result_of(dryer.crops[0], placed.clock))
	# Fogueira: argila -> tijolo (não queima)
	var cf := placed.host_apply("place", ["campfire", Transform3D(Basis(), origin + Vector3(0, 0, -6))])
	var fire: PlacedObject = placed.objects[cf[0]]
	placed.host_apply("cook", [fire.net_id, 0, "argila"])
	placed.host_apply("cook", [fire.net_id, 1, "batata"])
	placed.clock += 500.0
	print("fogueira depois de 500 s: argila -> ", Cooking.result_of(fire.crops[0], placed.clock), ", batata -> ", Cooking.result_of(fire.crops[1], placed.clock))
	# Argila na beira do lago
	var lake: Dictionary = WaterManager.i.lakes().filter(func(l): return not l.frozen)[0]
	var edge := Vector3(lake.center.x + lake.radius + 2.0, lake.level + 0.3, lake.center.y)
	print("beira do lago dá argila=", Farming._shore(edge), " longe=", Farming._shore(Vector3(lake.center.x + lake.radius + 40.0, lake.level + 5.0, lake.center.y)))
	# Fogueira afasta zumbi à noite
	DayNight.i.hour = 23.0
	DayNight.i._apply()
	for n in main.get_node("Enemies").get_children():
		n.queue_free() # só o zumbi do teste
	await process_frame
	var spot := origin + Vector3(30, 0, 30)
	var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 40, spot - Vector3.UP * 40, 1)
	spot = player.get_world_3d().direct_space_state.intersect_ray(q).position
	var cf2 := placed.host_apply("place", ["campfire", Transform3D(Basis(), spot)])
	fire = placed.objects[cf2[0]]
	for night in [true, false]:
		DayNight.i.hour = 23.0 if night else 12.0
		DayNight.i._apply()
		player.health = player.max_health
		player.global_position = fire.global_position + Vector3(1.5, 0.3, 0)
		var z: Zombie = load("res://scenes/zombie.tscn").instantiate()
		z.position = fire.global_position + Vector3(12, 0.3, 0)
		z.target = player
		main.get_node("Enemies").add_child(z)
		await physics_frame
		z.alert(player)
		var closest := 99.0
		for k in 600:
			await physics_frame
			closest = minf(closest, Vector2(z.global_position.x - fire.global_position.x, z.global_position.z - fire.global_position.z).length())
		print("estado=", Zombie.State.keys()[z.state])
		print("%s: zumbi chegou no máximo a %.1f m da fogueira (jogador a 1,5 m); vida do jogador=%d" % ["noite" if night else "dia (controle)", closest, player.health])
		z.queue_free()
		await process_frame
	quit()
