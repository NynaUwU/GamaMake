extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 20:
		await process_frame
	var main := current_scene
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	var lakes := terrain.lakes
	print("lagos=", lakes.filter(func(l): return l.kind == "lake").size(), " lagoas=", lakes.filter(func(l): return l.kind == "pond").size(), " congelados=", lakes.filter(func(l): return l.frozen).size())
	var lake: Dictionary = lakes.filter(func(l): return l.kind == "lake" and not l.frozen)[0]
	var c := Vector3(lake.center.x, 0, lake.center.y)
	print("fundo no centro=", snappedf(terrain.height_at(c.x, c.z) - lake.level, 0.1), " m (nível ", snappedf(lake.level, 0.1), ") margem=", snappedf(terrain.height_at(c.x + lake.radius * 1.1, c.z) - lake.level, 0.1))
	terrain.update_around(c, -1, 120.0)
	player.global_position = Vector3(c.x, lake.level - 2.5, c.z)
	for k in 60:
		await physics_frame
	var water: WaterManager = main.get_node("Water")
	print("nadando=", player.swimming, " debaixo d'água=", water.underwater, " y-nível=", snappedf(player.global_position.y - lake.level, 0.01), " vida do lago=", water._lives.size())
	var life: LakeLife = water._lives.values()[0]
	var kinds := {}
	for cr in life.creatures:
		kinds[cr.id] = kinds.get(cr.id, 0) + 1
	print("bichos: ", kinds)
	# Lança num peixe; mão num caranguejo.
	var fish: Creature = life.creatures.filter(func(x): return x.swimmer)[0]
	fish.tool_hit(player, Player.WeaponType.SPEAR, 30.0, fish.global_position)
	var crab: Creature = life.creatures.filter(func(x): return not x.swimmer)[0]
	var crab_id := crab.id
	crab.interact(player)
	print("pegou com lança: ", fish.id, "=", player.inventory.count(fish.id), "  com a mão: ", crab_id, "=", player.inventory.count(crab_id))
	# Pesca: na margem olhando para a água.
	var shore := Vector3(c.x + lake.radius * 1.15, 0, c.z)
	shore.y = terrain.height_at(shore.x, shore.z) + 0.1
	player.global_position = shore
	player.rotation.y = PI / 2 # olha para -X (o centro)
	player.head.rotation.x = -0.25
	player.equip_item(&"vara")
	for k in 30:
		await physics_frame
	var f := player._fishing()
	f.click()
	print("lançou: estado=", Fishing.State.keys()[f.state])
	f._timer = 1.0 # boia já chegou na água
	await process_frame
	await process_frame
	print("esperando: ", Fishing.State.keys()[f.state], " boia na água=", snappedf(f._bobber.global_position.y - lake.level, 0.01))
	f._timer = 0.0
	await process_frame
	await process_frame
	print("mordeu: ", Fishing.State.keys()[f.state])
	f.click()
	print("briga: ", Fishing.State.keys()[f.state], " peixe=", f._hooked[0])
	f._progress = 0.999
	f._fish_pos = f._zone + 0.05
	f._fish_target = f._fish_pos
	await process_frame
	await process_frame
	print("resultado: ", Fishing.State.keys()[f.state], " inventário do peixe=", player.inventory.count(f._hooked[0]))
	quit()
