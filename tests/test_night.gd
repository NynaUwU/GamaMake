extends SceneTree
## Fase 4: dia/noite, hordas noturnas, hordas do mapa e zumbi quebrando parede.
var main: Node

func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(20)
	main = current_scene
	var player: Player = main.player
	var dn: DayNight = main.get_node("DayNight")
	var hm: HordeManager = main.get_node("Hordes")
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	print("começo: ", dn.clock_text(), " noite=", dn.night, " sol visível=", main.get_node("Sun").visible)
	dn.hour = 22.0
	await _frames(3)
	print("22h: noite=", snappedf(dn.night, 0.01), " sol visível=", main.get_node("Sun").visible, " lua=", snappedf(main.get_node("Moon").light_energy, 0.01), " fog tint=", dn.fog_tint)
	# Hordas noturnas.
	hm._night_spawns()
	await _frames(3)
	var night_z := main.get_node("Enemies").get_children().filter(func(z): return z.has_meta("night"))
	print("noturnos=", night_z.size(), " cap=", hm.night_cap(), " distância média=", snappedf(night_z.reduce(func(a, z): return a + z.global_position.distance_to(player.global_position), 0.0) / maxf(night_z.size(), 1), 0.1))
	for z in night_z:
		z.queue_free()
	# Hordas no mapa.
	await _frames(2)
	print("hordas=", hm.hordes.size(), " mapa=", hm.map_list.size())
	var horde: Dictionary = hm.hordes[0]
	horde.pos = Vector2(player.global_position.x + 60, player.global_position.z)
	hm._update_hordes(0.5)
	for k in 10:
		await process_frame
	print("horda perto: viva=", horde.live, " zumbis=", horde.zombies.size(), " march_to definido=", horde.zombies.size() > 0 and horde.zombies[0].march_to != Vector3.INF)
	var p0: Vector3 = horde.zombies[0].global_position
	for k in 60:
		await physics_frame
	print("zumbi da horda andou=", snappedf(horde.zombies[0].global_position.distance_to(p0), 0.01), " m")
	player.global_position += Vector3(-400, 0, 0)
	hm._update_hordes(0.5)
	await _frames(2)
	print("jogador longe: viva=", horde.live, " tamanho=", horde.size)
	player.global_position -= Vector3(-400, 0, 0)
	dn.hour = 10.0
	# Zumbi quebrando parede: parede entre o zumbi e o jogador.
	await _frames(5)
	var building: BuildingManager = main.get_node("Building")
	var base := Vector3(-14.0, 0.0, 30.0)
	player.global_position = base + Vector3(1.4, 0.1, 3.0)
	var result := building.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(roundi(base.x / BuildPiece.SEG), 0, roundi(base.z / BuildPiece.SEG)), 0])
	var wall: BuildPiece = building.pieces[result[0]]
	var zombie: Zombie = load("res://scenes/zombie.tscn").instantiate()
	zombie.position = wall.global_position + Vector3(1.4, 0.2, -1.6)
	zombie.weapon_id = &"nenhuma"
	main.get_node("Enemies").add_child(zombie)
	zombie.target = player
	zombie.alert(player)
	for k in 60 * 25:
		await physics_frame
		if zombie.global_position.z > wall.global_position.z + 0.5:
			break
	print("parede: quadradinhos tirados=", wall.removed.count(1), " zumbi passou=", zombie.global_position.z > wall.global_position.z + 0.3, " estado=", Zombie.State.keys()[zombie.state])
	# Save do relógio e das hordas.
	var data: Dictionary = hm.save_data()
	print("save hordas=", data.list.size(), " relógio=", dn.save_data())
	quit()

func _frames(n: int) -> void:
	for i in n:
		await process_frame
