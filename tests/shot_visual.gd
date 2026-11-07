extends SceneTree
## Fotos do visual em lugares fixos (SHOT=pasta) e medição simples (BENCH=1).
## QUALITY=0/1/2 escolhe a qualidade gráfica (Baixa/Média/Alta) se existir.
## Rode com o Vulkan (Forward+) para ver SSAO/brilho como no jogo de verdade.

var main: Node3D
var player: Player
var terrain: TerrainWorld


func _shot(name: String, frames := 20) -> void:
	for k in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("SHOT")
	if dir != "":
		get_root().get_texture().get_image().save_png(dir + "/" + name + ".png")


func _look(from: Vector3, at: Vector3) -> void:
	terrain.update_around(from)
	player.global_position = from - Vector3(0, 1.6, 0)
	player.velocity = Vector3.ZERO
	await process_frame
	var to := at - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _ground(x: float, z: float) -> float:
	return terrain.height_at(x, z)


func _set_hour(h: float) -> void:
	if DayNight.i:
		DayNight.i.hour = h
		DayNight.i._apply()


## Campo aberto de planície (sem cidade, rua ou lago).
func _find_field() -> Vector3:
	for r: float in [180.0, 260.0, 340.0, 420.0, 520.0, 640.0]:
		for k in 24:
			var a := TAU * k / 24.0
			var x := cos(a) * r
			var z := sin(a) * r
			var b: Dictionary = terrain.biome_at(x, z)
			if b.plains < 0.85 or terrain.city_mask(x, z) > 0.0 or not terrain.road_at(x, z).is_empty():
				continue
			if TerrainProps._in_lake(terrain, x, z, 1.3):
				continue
			var h := _ground(x, z)
			if h < TerrainWorld.SEA_LEVEL + 4.0 or terrain.coast_distance(x, z) < TerrainWorld.SEA_BAND * 1.5:
				continue
			return Vector3(x, h, z)
	return Vector3(200, _ground(200, 0), 0)


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	main = current_scene
	player = main.player
	terrain = main.get_node("Terrain")
	var q := OS.get_environment("QUALITY")
	if q != "" and ResourceLoader.exists("res://scripts/util/look.gd"):
		load("res://scripts/util/look.gd").set_quality(int(q))
	for e in main.get_node("Enemies").get_children():
		e.free()
	var hud := main.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	if Weather.i:
		Weather.i.target_rain = 0.0
		Weather.i.rain = 0.0
		Weather.i._timer = 99999.0
	var bm: BuildingManager = main.get_node("Building")
	var placed: PlacedManager = main.get_node("Placed")
	# --- Base: casinha com telhado de duas águas e algumas máquinas na frente.
	var cx := 55
	var cz := 30
	var cy := floori(_ground(cx * 0.4 + 2.8, cz * 0.4 + 2.8) / 0.4)
	for k in 2:
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx + 7 * k, cy, cz), 0])
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx + 7 * k, cy, cz + 14), 0])
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx, cy, cz + 7 * k), 1])
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx + 14, cy, cz + 7 * k), 1])
		bm.host_apply("place", [BuildPiece.Kind.ROOF, Vector3i(cx + 7 * k, cy + 7, cz), 2])
		bm.host_apply("place", [BuildPiece.Kind.ROOF, Vector3i(cx + 7 * k, cy + 7, cz + 7), 4])
		for j in 2:
			bm.host_apply("place", [BuildPiece.Kind.FLOOR, Vector3i(cx + 7 * k, cy, cz + 7 * j), 0])
	var house := Vector3((cx + 7) * 0.4, cy * 0.4, (cz + 7) * 0.4)
	var front := house + Vector3(0, 0, -5.5)
	var things := [["furnace", Vector3(-2.2, 0, 0)], ["quern", Vector3(0.0, 0, -0.6)], ["rain_collector", Vector3(2.0, 0, 0)],
		["campfire", Vector3(0.6, 0, -3.0)], ["chest", Vector3(-3.6, 0, -1.2)], ["bed", Vector3(4.2, 0, -2.4)]]
	for t in things:
		var at: Vector3 = front + t[1]
		at.y = _ground(at.x, at.z)
		placed.host_apply("place", [t[0], Transform3D(Basis(), at)])
	_set_hour(16.5)
	await _look(house + Vector3(6.0, 2.3, -11.5), house + Vector3(-0.8, 1.0, -2.5))
	await _shot("base", 30)
	if OS.get_environment("BENCH") != "":
		await _bench("base_vazia")
		main._spawn_horde(60)
		await _bench("base_60_zumbis")
		for e in main.get_node("Enemies").get_children():
			e.free()
	# --- Campo aberto ao meio-dia.
	var field := _find_field()
	_set_hour(12.0)
	await _look(field + Vector3(0, 1.7, 0), field + Vector3(12, 0.6, 20))
	await _shot("campo", 60)
	if OS.get_environment("BENCH") != "":
		await _bench("campo")
	# --- Pôr do sol olhando para o oeste.
	_set_hour(18.9)
	await _look(field + Vector3(0, 1.8, 0), field + Vector3(-30, 3.0, 4))
	await _shot("por_do_sol", 20)
	# --- Cidade.
	if not terrain.cities.is_empty():
		var c: Vector2 = terrain.cities[0].center
		_set_hour(10.0)
		var at := Vector3(c.x + 4, _ground(c.x + 4, c.y + 3) + 1.7, c.y + 3)
		await _look(at, at + Vector3(14, -0.6, 10))
		await _shot("cidade", 80)
		if OS.get_environment("BENCH") != "":
			await _bench("cidade")
	# --- Chuva na base.
	_set_hour(15.0)
	Weather.i.target_rain = 1.0
	Weather.i.rain = 1.0
	await _look(house + Vector3(-4.0, 1.7, -9.0), house + Vector3(1.0, 1.0, -2.0))
	await _shot("chuva", 40)
	Weather.i.target_rain = 0.0
	Weather.i.rain = 0.0
	# --- Noite: tocha na mão e zumbis com olho aceso chegando.
	_set_hour(22.5)
	player.inventory.add(&"tocha", 1)
	player.inventory.equip_from(Cooking.find_any(player.inventory, {&"tocha": true}), "offhand")
	var eye := Vector3(field.x, _ground(field.x, field.z) + 1.7, field.z)
	var fire := field + Vector3(1.6, 0, -4.5)
	fire.y = _ground(fire.x, fire.z)
	placed.host_apply("place", ["campfire", Transform3D(Basis(), fire)])
	var lit: PlacedObject = placed.objects.values()[-1]
	lit.extra["fuel_until"] = placed.clock + 9999.0
	await _look(eye, eye + Vector3(0.5, -0.6, -20.0))
	for k in 5:
		var zombie: Zombie = main.ZOMBIE_SCENE.instantiate()
		var at := eye + Vector3(-5.0 + k * 2.5, 0.0, -26.0 - (k % 2) * 3.0)
		at.y = _ground(at.x, at.z) + 0.2
		zombie.position = at
		zombie.target = player
		main.enemies.add_child(zombie)
	await _shot("noite", 12)
	if OS.get_environment("BENCH") != "":
		await _bench("noite_tocha")
	quit()


## Média de tempo por quadro, chamadas de desenho e triângulos (só referência:
## no container o Vulkan é por software).
func _bench(label: String) -> void:
	var rid := get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for k in 10:
		await process_frame
	var frames := 40
	var t0 := Time.get_ticks_usec()
	var draws := 0.0
	var prims := 0.0
	var objs := 0.0
	var gpu := 0.0
	var cpu := 0.0
	for k in frames:
		await process_frame
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
	print("BENCH %-16s quadro %.1f ms  render-cpu %.1f ms  render-gpu %.1f ms  draws %d  tris %dk  objetos %d" % [label, ms,
		cpu / frames, gpu / frames, int(draws / frames), int(prims / frames / 1000.0), int(objs / frames)])
