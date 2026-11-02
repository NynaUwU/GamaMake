extends SceneTree
## Fotos: roda d'água -> eixo com polia e engrenagem -> moinho; tripé; esteira até a
## serraria; eixo perpendicular pelas engrenagens; luzes; e a lousa (SHOT=pasta).
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	var main := current_scene
	var placed: PlacedManager = main.get_node("Placed")
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	for e in main.get_node("Enemies").get_children():
		e.free()
	var out := OS.get_environment("SHOT")
	var base := player.global_position + Vector3(22, 0, 8)
	base.y = terrain.height_at(base.x, base.z)
	var spawn := func(kind: String, at: Vector3, basis := Basis()) -> PlacedObject:
		var id := placed._next_id
		placed._spawn(id, kind, Transform3D(basis, at))
		return placed.objects[id]
	var axle := func(a: Vector3, b: Vector3) -> Array:
		var dir := (b - a).normalized()
		return placed.host_apply("axle", [Transform3D(Basis.looking_at(-dir, Vector3.UP), a), a.distance_to(b)])
	var wheel: PlacedObject = spawn.call("water_wheel", base)
	var quern: PlacedObject = spawn.call("quern", base + Vector3(5.6, 0, 0))
	var wp: Vector3 = Power.world_ports(wheel)[0][0]
	var qp: Vector3 = Power.world_ports(quern)[0][0]
	axle.call(wp, qp)
	var dir := (qp - wp).normalized()
	var along := Basis.looking_at(-dir, Vector3.UP)
	placed.host_apply("mount", ["pulley", Transform3D(along, wp + dir * 1.2)])
	placed.host_apply("mount", ["cog", Transform3D(along, wp + dir * 3.0)])
	# Cônica a 90°: centro = A + r*eixo de A + r*eixo de B (eixos se cruzam).
	var c2 := wp + dir * 3.0 + dir * 0.3 + Vector3(0, 0, 0.3)
	axle.call(c2, c2 + Vector3(0, 0, 3.4)) # sai pela engrenagem e termina num tripé
	placed.host_apply("mount", ["cog", Transform3D(Basis(), c2)])
	# Eixo paralelo ao lado: liga por polia + esteira (não por engrenagem).
	var p1 := c2 + Vector3(0, 0, 2.0)
	var p1r: Array = placed.host_apply("mount", ["pulley", Transform3D(Basis(), p1)])
	var c3 := p1 + Vector3(1.2, 0, -1.0)
	axle.call(c3, c3 + Vector3(0, 0, 2.0))
	var p2r: Array = placed.host_apply("mount", ["pulley", Transform3D(Basis(), c3 + Vector3(0, 0, 1.0))])
	placed.host_apply("belt", [p1r[0], p2r[0]])
	var big_at := p1
	var saw: PlacedObject = spawn.call("sawmill", wp + dir * 1.2 + Vector3(1.15, -0.6, -3.2))
	var pulley: PlacedObject = placed.objects.values().filter(func(o): return o.kind == "pulley")[0]
	placed.host_apply("belt", [pulley.net_id, saw.net_id])
	quern.extra["in"] = 20
	saw.extra["in"] = 1
	for k in 3:
		placed.clock += 1.0
		placed._power()
	for o in placed.objects.values():
		o.refresh(placed.clock)
	var views := [[base + Vector3(3.0, 5.5, 4.5), base + Vector3(2.6, 0.4, -1.0)], [base + Vector3(7.5, 2.2, -4.5), base + Vector3(2.5, 0.5, -0.8)],
		[c2 + Vector3(-1.1, 0.9, 1.0), c2], [big_at + Vector3(0.45, 1.4, -1.6), big_at + Vector3(0.45, 0, 0)]]
	for v in views.size():
		player.global_position = views[v][0] - Vector3(0, 1.6, 0)
		await process_frame
		var to: Vector3 = views[v][1] - player.camera.global_position
		player.rotation.y = atan2(-to.x, -to.z)
		player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
		for k in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(out + "/forca_%d.png" % (v + 1))
	# Lousa
	var board_at := base + Vector3(-6, 0, 0)
	board_at.y = terrain.height_at(board_at.x, board_at.z)
	placed.host_apply("place", ["drawboard", Transform3D(Basis(), board_at)])
	player.global_position = board_at + Vector3(0.4, 0, 2.2)
	await process_frame
	var to2: Vector3 = board_at + Vector3(0, 1.2, 0) - player.camera.global_position
	player.rotation.y = atan2(-to2.x, -to2.z)
	player.head.rotation.x = atan2(to2.y, Vector2(to2.x, to2.z).length())
	for k in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "/lousa.png")
	quit()
