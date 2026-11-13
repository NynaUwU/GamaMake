extends SceneTree
## Foto do vapor: caixa d'água -> caldeira acesa -> cano -> motor a vapor girando (SHOT=pasta).
## Duas fotos com 0,6 s de diferença: o vapor tem que subir e sumir.

var placed: PlacedManager


func _pipe(a: Vector3, b: Vector3) -> int:
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
	var r := placed.host_apply("pipe", [Transform3D(Basis.looking_at(-dir, up), a), a.distance_to(b)])
	return r[0] if not r.is_empty() else -1


func _place(kind: String, at: Vector3) -> PlacedObject:
	var r := placed.host_apply("place", [kind, Transform3D(Basis(), at)])
	return placed.objects.get(r[0]) if not r.is_empty() else null


func _port(obj: PlacedObject, index: int) -> Vector3:
	return obj.global_transform * Fluids.PORTS[obj.kind][index][0]


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	var main := current_scene
	placed = main.get_node("Placed")
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	var base := player.global_position + Vector3(0, 0, -7)
	base.y = terrain.height_at(base.x, base.z)
	var tank := _place("water_tank", base + Vector3(-4, 0, 0))
	tank.extra.water = 60.0
	var boiler := _place("boiler", base)
	ContainerManager.i.contents[Smelting.key_of(boiler)] = [{}, {"id": &"carvao", "amount": 20}, {}]
	boiler.extra.merge({"burn": 30.0, "burn_max": 40.0, "heat": 1.0, "water": 15.0, "pressure": 1.4}, true)
	_pipe(_port(tank, 0), _port(boiler, 0))
	var engine := _place("steam_engine", base + Vector3(2.5, 0, 2.0))
	# Cano posto ao contrário (do motor para a caldeira): as faixas têm que andar da caldeira ao motor.
	var steam_pipe := placed.objects[_pipe(_port(engine, 0), _port(boiler, 1))] as PlacedObject
	player.set_physics_process(false)
	player.global_position = base + Vector3(1.0, 0, 7.5)
	player.global_position.y = terrain.height_at(player.global_position.x, player.global_position.z) + 0.1
	player.rotation.y = 0.0
	player.head.rotation.x = -0.12
	for k in 300: # ~5 s: a caldeira manda vapor, o motor gira
		await process_frame
	print("caldeira: pressão %.2f calor %.2f água %.1f vent=%s | motor: vapor %.2f velocidade %.2f | fumaça %s válvula %s baforada %s" % [
		boiler.extra.get("pressure", 0.0), boiler.extra.get("heat", 0.0), boiler.extra.get("water", 0.0), boiler.extra.get("vent", false),
		engine.extra.get("steam", 0.0), engine.extra.get("speed", 0.0),
		_emitting(boiler, "Smoke"), _emitting(boiler, "Valve"), _emitting(engine, "Puff")])
	print("cano de vapor: %.1f/s, sentido %d (esperado -1) | texto da caldeira: %s" % [steam_pipe.extra.get("vapor", 0.0),
		steam_pipe.extra.get("fdir", 0), SteamModels.text(boiler)])
	for shot in ["vapor_a", "vapor_b"]:
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/" + shot + ".png")
		for k in 36:
			await process_frame
	quit()


func _emitting(obj: Node, name: String) -> String:
	var parts: Array = obj.find_children("*", "CPUParticles3D", true, false)
	var out := []
	for p: CPUParticles3D in parts:
		out.append("%s:%s" % [p.name, p.emitting])
	return ",".join(out)
