extends SceneTree
## Foto da água escorrendo (SHOT=pasta): vala saindo de um lago, poço no fim.
## (a água procura o nível), um poço no fim enche de cima para baixo, dá para nadar, bloco
## posto tira a água dali, e o save guarda.

func _ticks(water: VoxelWater, n: int) -> void:
	for k in n:
		water._tick()


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await process_frame
	var main: Node3D = current_scene
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	var vw: VoxelWorld = main.get_node_or_null("Voxels")
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	if vw == null:
		print("sem voxels")
		quit()
		return
	var water := vw.water
	# Lago (não congelado) mais perto do centro.
	var lakes: Array = terrain.lakes.filter(func(l): return not l.frozen)
	lakes.sort_custom(func(a, b): return a.center.length() < b.center.length())
	var lake: Dictionary = lakes[0]
	var c: Vector2 = lake.center
	# Margem: andando para +X até o chão natural passar do nível.
	var shore := c
	for step in 200:
		shore = c + Vector2(lake.radius * 0.6 + step * 0.4, 0)
		if terrain._base_at(shore.x, shore.y) > lake.level + 0.6 and Lakes.at(terrain.lakes, shore.x, shore.y).is_empty():
			break
	print("lago em %s, raio %.0f, nível %.2f; margem seca em x=%.1f" % [c.round(), lake.radius, lake.level, shore.x])
	player.set_physics_process(false)
	player.global_position = Vector3(shore.x, terrain._base_at(shore.x, shore.y) + 1.0, shore.y)
	terrain.update_around(player.global_position, -1, 140.0)
	vw.update_around(player.global_position, VoxelWorld.NEAR)
	for k in 10:
		await process_frame
	# Vala de 2 blocos de largura, do lago (3 m para dentro) até 8 m fora, com o fundo
	# 2 blocos abaixo do nível do lago.
	var floor_b := floori((lake.level - 0.8) / VoxelWorld.GRID)
	var x0 := floori((c.x + lake.radius - 3.0) / VoxelWorld.GRID) # começa 3 m dentro do lago
	var x1 := floori((shore.x + 8.0) / VoxelWorld.GRID)
	var z0 := floori(shore.y / VoxelWorld.GRID)
	var list := []
	for bx in range(x0, x1 + 1):
		for bz in [z0, z0 + 1]:
			var top := floori((terrain._base_at((bx + 0.5) * 0.4, (bz + 0.5) * 0.4) + 0.4) / VoxelWorld.GRID)
			for by in range(floor_b, top + 1):
				var b := Vector3i(bx, by, bz)
				if vw.material_at(b) > 0:
					list.append([b, VoxelRef.AIR])
	vw.set_blocks(list)
	print("vala: %d blocos cavados (x %d..%d, fundo y=%d)" % [list.size(), x0, x1, floor_b])
	_ticks(water, 80) # 20 s
	var wet := 0
	var total := 0
	for bx in range(x0, x1 + 1):
		var b := Vector3i(bx, floor_b, z0)
		if water.is_static(b):
			continue
		total += 1
		wet += 1 if water.has_water(b) else 0
	var far := Vector3((x1 - 1) * VoxelWorld.GRID, (floor_b + 1) * VoxelWorld.GRID, (z0 + 1) * VoxelWorld.GRID)
	print("depois de 20 s: %d blocos de água (%d fontes), fundo da vala com água fora do lago: %d de %d, ticks %d, blocos atualizados %d" % [
		water.cells.size(), water.sources.size(), wet, total, water.stats.ticks, water.stats.updates])
	print("profundidade no fim da vala (8 m fora do lago): %.2f m (nível do lago %.2f, fundo %.2f)" % [
		WaterManager.i.depth_at(far), lake.level, floor_b * VoxelWorld.GRID])
	# Poço de 2x2 no fim, 8 blocos mais fundo.
	var pit := []
	for by in range(floor_b - 8, floor_b):
		for bx in [x1 - 1, x1]:
			for bz in [z0, z0 + 1]:
				if vw.material_at(Vector3i(bx, by, bz)) > 0:
					pit.append([Vector3i(bx, by, bz), VoxelRef.AIR])
	vw.set_blocks(pit)
	_ticks(water, 60)
	var bottom := Vector3i(x1, floor_b - 8, z0)
	print("poço: fundo com água? %s (nível %d), meio do poço com água? %s" % [water.has_water(bottom), water.level_at(bottom),
		water.has_water(Vector3i(x1, floor_b - 4, z0))])
	for k in 30:
		await process_frame
	# Câmera na margem, olhando ao longo da vala (para o lago) e de cima.
	var eye := Vector3((x1 + 6) * 0.4, terrain._base_at((x1 + 6) * 0.4, (z0 + 1) * 0.4) + 2.4, (z0 + 4) * 0.4)
	player.global_position = eye - Vector3.UP * 1.6
	var look := Vector3((x0 + 10) * 0.4, lake.level - 0.5, (z0 + 1) * 0.4) - eye
	player.rotation.y = atan2(-look.x, -look.z)
	player.head.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
	for k in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/agua_vala.png")
	quit()
