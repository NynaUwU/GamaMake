extends SceneTree
## Água que escorre (blocos de 0,4 m): vala saindo de um lago abaixo do nível dele enche
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
	# Nadar: o jogador dentro do poço.
	player.global_position = Vector3((x1 + 0.5) * 0.4, (floor_b - 5) * 0.4, (z0 + 0.5) * 0.4)
	player.set_physics_process(true)
	for k in 30:
		await physics_frame
	print("jogador no poço: nadando? %s" % player.swimming)
	player.set_physics_process(false)
	# Bloco posto dentro da água: a água sai dali.
	var mid := Vector3i(x1 - 4, floor_b, z0)
	var had := water.has_water(mid)
	vw.set_block(mid, VoxelRef.BUILT_STONE)
	_ticks(water, 2)
	print("bloco posto na água: tinha água %s, agora tem %s" % [had, water.cells.has(mid)])
	# Save.
	var data := vw.save_data()
	var copy := VoxelWater.new(vw)
	copy.load_list(data.water)
	print("save: %d blocos de água guardados, recarregados %d (fontes %d)" % [data.water.size() / VoxelWater.STRIDE, copy.cells.size(), copy.sources.size()])
	# Malha.
	for k in 20:
		await process_frame
	print("malhas de água: %d seções; pior passo da água %.2f ms, pior malha %.2f ms" % [water._nodes.size(), water.stats.tick_ms, water.stats.mesh_ms])
	quit()
