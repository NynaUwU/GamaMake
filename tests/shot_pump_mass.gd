extends SceneTree
## Fotos (SHOT=pasta): bomba de recalque levando água da caixa até a caldeira no alto, e
## parede de tábuas posta arrastando (em massa).
var placed: PlacedManager


func _pipe(a: Vector3, b: Vector3) -> void:
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
	placed.host_apply("pipe", [Transform3D(Basis.looking_at(-dir, up), a), a.distance_to(b)])


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	var main: Node3D = current_scene
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	placed = main.get_node("Placed")
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	player.set_physics_process(false)
	var base := GridSnap.flat(player.global_position + Vector3(0, 0, -6))
	var gy := terrain.height_at(base.x, base.z)
	var tank: PlacedObject = placed.objects[placed.host_apply("place", ["water_tank", Transform3D(Basis(), Vector3(base.x - 2.4, gy, base.z))])[0]]
	tank.extra.water = 50.0
	var pump: PlacedObject = placed.objects[placed.host_apply("place", ["pipe_pump", Transform3D(Basis(Vector3.UP, PI / 2), Vector3(base.x, gy, base.z))])[0]]
	# Cano: caixa -> bomba (deitado) -> sai da bomba, sobe 1,6 m e vai até o tanque alto.
	var t_port: Vector3 = tank.global_transform * Fluids.PORTS["water_tank"][0][0]
	var p_in: Vector3 = pump.global_transform * Fluids.PORTS["pipe_pump"][1][0]
	var p_out: Vector3 = pump.global_transform * Fluids.PORTS["pipe_pump"][0][0]
	_pipe(t_port, Vector3(p_in.x, t_port.y, t_port.z))
	_pipe(Vector3(p_in.x, t_port.y, t_port.z), p_in)
	var top := p_out + Vector3.UP * 2.0
	_pipe(p_out, top)
	_pipe(top, top + Vector3.RIGHT * 1.6)
	# Eixo do motor elétrico na porta de latão (só o visual: força posta na mão).
	pump.extra.pstate = "ok"
	pump.extra.speed = 1.0
	pump.refresh(placed.clock)
	for s in 4:
		placed.clock += 1.0
		placed._fluids()
	# Parede de tábuas em massa, ao lado.
	var vw: VoxelWorld = main.get_node_or_null("Voxels")
	if vw:
		var spot := Vector3(base.x + 4.0, 0, base.z - 1.0)
		vw.update_around(spot, VoxelWorld.NEAR)
		var g := VoxelWorld.block_of(Vector3(spot.x, terrain._base_at(spot.x, spot.z) + 0.2, spot.z))
		player.inventory.slots[8] = {"id": &"tabua", "amount": 100}
		player.inventory.select(8)
		TerrainTools._mass = {"start": g + Vector3i(0, 1, 0), "end": g + Vector3i(7, 5, 0), "id": &"tabua"}
		TerrainTools._finish_mass(player)
	var eye := Vector3(base.x + 1.5, gy + 2.2, base.z + 5.0)
	player.global_position = eye - Vector3.UP * 1.6
	var look := Vector3(base.x + 1.0, gy + 1.0, base.z - 0.5) - eye
	player.rotation.y = atan2(-look.x, -look.z)
	player.head.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
	for k in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/bomba_e_parede.png")
	print("bomba: %s" % SteamModels.text(pump))
	quit()
