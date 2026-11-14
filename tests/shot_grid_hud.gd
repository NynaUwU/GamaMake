extends SceneTree
## Fotos (SHOT=pasta): canto do HUD (necessidades + termômetro) e canos/eixo na grade com
## curvas de 90° e tripés nas pontas soltas.
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	var main: Node3D = current_scene
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	var terrain: TerrainWorld = main.get_node("Terrain")
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	player.set_physics_process(false)
	var base := GridSnap.flat(player.global_position + Vector3(0, 0, -5))
	var gy := terrain.height_at(base.x, base.z)
	# Caixa d'água -> cano deitado -> curva de 90° subindo -> cano deitado no alto.
	var tank := placed.host_apply("place", ["water_tank", Builder.grid_snap("water_tank", Transform3D(Basis(), Vector3(base.x - 3.2, gy, base.z)))])
	var tank_obj: PlacedObject = placed.objects[tank[0]]
	tank_obj.extra.water = 40.0
	var port: Vector3 = Fluids.world_ports(tank_obj)[0][0]
	var a := port
	var b := a + Vector3.RIGHT * 2.4
	var c := b + Vector3.UP * 1.6
	var d := c + Vector3.BACK * 2.0
	for seg in [[a, b], [b, c], [c, d]]:
		var dir: Vector3 = (seg[1] - seg[0]).normalized()
		var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
		placed.host_apply("pipe", [Transform3D(Basis.looking_at(-dir, up), seg[0]), seg[0].distance_to(seg[1])])
	# Eixo deitado com tripés.
	var e0 := Vector3(base.x + 2.0, gy + 0.6, base.z - 1.2)
	placed.host_apply("axle", [Transform3D(Basis.looking_at(Vector3.FORWARD, Vector3.UP), e0), 2.4])
	var eye := Vector3(base.x + 1.0, gy + 2.4, base.z + 4.5)
	player.global_position = eye - Vector3.UP * 1.6
	var look := Vector3(base.x, gy + 0.9, base.z - 0.5) - eye
	player.rotation.y = atan2(-look.x, -look.z)
	player.head.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
	for k in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png(OS.get_environment("SHOT") + "/canos_grade.png")
	# Canto do HUD, ampliado.
	var corner := img.get_region(Rect2i(0, img.get_height() - 160, 200, 160))
	corner.resize(400, 320, Image.INTERPOLATE_NEAREST)
	corner.save_png(OS.get_environment("SHOT") + "/hud_canto.png")
	quit()
