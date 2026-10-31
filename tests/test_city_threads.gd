extends SceneTree
## Casas montadas em threads: chega perto de uma cidade e espera ficarem prontas.
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 20:
		await process_frame
	var main := current_scene
	var terrain: TerrainWorld = main.get_node("Terrain")
	var mgr: CityManager = main.get_node("Cities")
	var city: Dictionary = terrain.cities[1]
	main.player.global_position = Vector3(city.center.x, terrain.height_at(city.center.x, city.center.y) + 1.0, city.center.y)
	var start := Time.get_ticks_msec()
	var worst := 0
	var last := Time.get_ticks_msec()
	for k in 600:
		await process_frame
		var now := Time.get_ticks_msec()
		worst = maxi(worst, now - last)
		last = now
		if mgr._built.has(1) and mgr._built[1].next >= city.lots.size():
			break
	print("cidade 1: casas=", mgr._built[1].next if mgr._built.has(1) else -1, "/", city.lots.size(), " em ", Time.get_ticks_msec() - start, " ms, pior frame=", worst, " ms")
	quit()
