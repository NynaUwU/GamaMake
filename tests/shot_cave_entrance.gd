extends SceneTree
## Entradas de caverna (SHOT=pasta): quantas a ilha tem; foto de fora (a boca na encosta),
## de dentro do túnel olhando para baixo e do salão no fim. Confere que não tem árvore em
## cima da boca e que dá para descer andando (o chão do túnel tem colisão).
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	var main := current_scene
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	var vw: VoxelWorld = main.get_node_or_null("Voxels")
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	var list := terrain.cave_entrances
	print("entradas de caverna na ilha: %d, com jazida: %d" % [list.size() / VoxelRef.STRIDE, terrain.deposits().size()])
	if vw == null or list.is_empty():
		quit()
		return
	# A mais perto do começo.
	var best := 0
	for k in range(0, list.size(), VoxelRef.STRIDE):
		if Vector2(list[k], list[k + 1]).length() < Vector2(list[best], list[best + 1]).length():
			best = k
	var start := Vector2(list[best], list[best + 1])
	var dir := Vector2(list[best + 2], list[best + 3])
	print("entrada em (%.0f, %.0f), %.0f m do centro, direção (%.2f, %.2f)" % [start.x, start.y, start.length(), dir.x, dir.y])
	player.set_physics_process(false)
	var shot := func(name: String, at: Vector2, back: float, height: float, pitch: float) -> void:
		var p := at - dir * back
		var pos := Vector3(p.x, 0, p.y)
		terrain.update_around(pos, -1, 140.0)
		vw.update_around(pos, VoxelWorld.NEAR)
		pos.y = terrain._base_at(pos.x, pos.z) + height
		player.global_position = pos
		player.rotation.y = atan2(-dir.x, -dir.y)
		player.head.rotation.x = pitch
		for k in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/" + name + ".png")
	await shot.call("entrada_fora", start, 9.0, 1.7, -0.25)
	await shot.call("entrada_alto", start, 12.0, 6.0, -0.5)
	# Plantas em cima da boca?
	var floating := 0
	for chunk in terrain._chunks.values():
		for mm: MultiMeshInstance3D in chunk.find_children("*", "MultiMeshInstance3D", false, false):
			for i in mm.multimesh.instance_count:
				var w: Vector3 = chunk.global_transform * mm.multimesh.get_instance_transform(i).origin
				if terrain.cave_mouth_at(w.x, w.z, 0.0):
					floating += 1
	print("plantas em cima da boca: %d" % floating)
	# Andando para dentro: o jogador desce a rampa (física ligada).
	var p0 := start - dir * 2.0
	player.global_position = Vector3(p0.x, terrain._base_at(p0.x, p0.y) + 1.0, p0.y)
	player.set_physics_process(true)
	player.rotation.y = atan2(-dir.x, -dir.y)
	player.head.rotation.x = -0.3
	Input.action_press("move_forward")
	var lowest := player.global_position.y
	for k in 360:
		await physics_frame
		lowest = minf(lowest, player.global_position.y)
	Input.action_release("move_forward")
	var here := player.global_position
	print("andou %.1f m para dentro, desceu %.1f m (chão natural ali %.1f m acima), caverna? %.2f" % [
		Vector2(here.x, here.z).distance_to(start), p0.length() * 0.0 + (terrain._base_at(p0.x, p0.y) + 1.0 - here.y),
		terrain._base_at(here.x, here.z) - here.y, vw.cave_factor])
	for k in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/entrada_dentro.png")
	quit()
