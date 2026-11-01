extends SceneTree
## Ilha: cidades/lagos/pista em terra, rios chegando ao mar, mapa salvo em PNG.
func _init() -> void:
	await process_frame
	for s in [1337, 42, 7777]:
		var t0 := Time.get_ticks_msec()
		var terrain := TerrainWorld.new()
		terrain.seed = s
		get_root().add_child(terrain)
		var bad_cities := terrain.cities.filter(func(c): return terrain.coast_distance(c.center.x, c.center.y) < c.radius)
		var lens := []
		var to_sea := 0
		for r in terrain.rivers:
			lens.append(r.points.size() * 24)
			var e: Vector2 = r.points[r.points.size() - 1]
			if terrain.coast_distance(e.x, e.y) < 0.0:
				to_sea += 1
		print("seed %d: %d ms, cidades %d (na praia %d), lagos %d, pista %s, rios %d (no mar %d) comprimentos %s" % [s, Time.get_ticks_msec() - t0,
			terrain.cities.size(), bad_cities.size(), terrain.lakes.size(), not terrain.track.is_empty(), terrain.rivers.size(), to_sea, lens])
		var c := Vector2(terrain.world_size * 0.5 - 10, 0)
		print("  borda: altura %.1f  mar=%s" % [terrain.height_at(c.x, c.y), terrain.sea_at(c.x, c.y)])
		if s == 1337 and OS.get_environment("SHOT") != "":
			var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
			for j in 256:
				for i in 256:
					var x := (i / 256.0 - 0.5) * terrain.world_size
					var z := (j / 256.0 - 0.5) * terrain.world_size
					img.set_pixel(i, j, terrain.map_sample(x, z)[0])
			img.save_png(OS.get_environment("SHOT") + "/ilha.png")
		terrain.free()
	quit()
