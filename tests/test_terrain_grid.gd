extends SceneTree
## Terreno em grade de 0,4 m: altura (height_at) = colisão = malha, custo de gerar um
## chunk, cavar e pôr blocos (rampas em volta), save/load e chunk recarregado.

var main: Node3D
var terrain: TerrainWorld


## Raio de cima que só conta o chão do terreno (atravessa casas, árvores, asfalto da cena).
func _ray(x: float, z: float) -> float:
	var space := main.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for k in 12:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 300, z), Vector3(x, -100, z), 1, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return NAN
		if TerrainWorld.is_ground(hit.collider) and hit.collider.get_node_or_null("GroundShape"):
			var body: CollisionObject3D = hit.collider
			if body.shape_owner_get_owner(body.shape_find_owner(hit.shape)) == body.get_node("GroundShape"):
				return hit.position.y
		exclude.append(hit.rid)
	return NAN


func _compare(label: String, center: Vector2, radius: float, count: int) -> void:
	var worst := 0.0
	var where := Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var misses := 0
	for k in count:
		var p := center + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
		var ray := _ray(p.x, p.y)
		if is_nan(ray):
			misses += 1
			continue
		var d := absf(ray - terrain.height_at(p.x, p.y))
		if d > worst:
			worst = d
			where = p
	print("%s: %d pontos, maior diferença height_at x colisão %.4f m em %s (sem chão: %d)" % [label, count, worst, where, misses])


func _init() -> void:
	VoxelWorld.enabled = false # testa o chão de alturas (colunas de 0,4 m), sem a área de voxels
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	terrain = main.get_node("Terrain")
	var player: Player = main.player
	for e in main.get_node("Enemies").get_children():
		e.detect_range = 0.0
	print("chunks %d, grade %.1f m, alturas a cada %.1f m, bloco de %.1f m" % [terrain._chunks.size(), TerrainWorld.GRID, TerrainWorld.STEP, TerrainWorld.GRID])
	# Custo de um chunk (thread) e da parte da thread principal.
	var t0 := Time.get_ticks_usec()
	var data := terrain._generate_data(Vector2i(12, 7))
	var gen_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	terrain._finish(Vector2i(12, 7), data)
	var fin_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("chunk novo: gerar %.1f ms (thread), montar %.1f ms (principal), %d triângulos" % [gen_ms, fin_ms, data.vertices.size() / 3])
	await physics_frame
	await physics_frame
	var pos := player.global_position
	_compare("perto do início", Vector2(pos.x, pos.z), 60.0, 300)
	var far := Vector2(pos.x, pos.z) + Vector2(150, -90)
	_compare("150 m dali", far, 40.0, 300)
	# Cavar: 3 vezes a mesma coluna e uma vizinha; pôr 4 blocos de pedra numa terceira.
	var spot := Vector2(pos.x + 110.0, pos.z + 70.0) # fora da cidade inicial (lá o asfalto cobre)
	var col := TerrainWorld.column_at(spot.x, spot.y)
	var before := terrain.column_top(col)
	var neighbor_before := terrain.column_top(col + Vector2i(1, 0))
	print("material natural da coluna: %s; o que sai cavando: %s" % [terrain.natural_material(col), terrain.dig_result(col)])
	for k in 3:
		terrain.request_dig(col)
	terrain.request_dig(col + Vector2i(0, 1))
	var tower := col + Vector2i(6, 0)
	var tower_before := terrain.column_top(tower)
	for k in 4:
		terrain.request_place(tower, TerrainWorld.Mat.STONE)
	await physics_frame
	await physics_frame
	print("cavou 3x: topo %.2f -> %.2f (%.2f m); vizinha %.2f -> %.2f (rampa)" % [before, terrain.column_top(col), before - terrain.column_top(col),
		neighbor_before, terrain.column_top(col + Vector2i(1, 0))])
	print("4 blocos de pedra: topo %.2f -> %.2f; construídos %d, material do topo %d" % [tower_before, terrain.column_top(tower),
		terrain.built_count(tower), terrain.top_material(tower)])
	_compare("depois de cavar/construir", spot + Vector2(1.0, 0.0), 3.5, 400)
	# Raio direto no meio do buraco e no topo da torre.
	var mid := Vector2((col.x + 0.5) * 0.4, (col.y + 0.5) * 0.4)
	print("raio no buraco %.2f, height_at %.2f; raio na torre %.2f, height_at %.2f" % [_ray(mid.x, mid.y), terrain.height_at(mid.x, mid.y),
		_ray((tower.x + 0.5) * 0.4, (tower.y + 0.5) * 0.4), terrain.column_top(tower)])
	# Zumbi quebra o bloco posto (pedra = 8 golpes) mas não o chão natural.
	var hits := 0
	while terrain.built_count(tower) == 4 and hits < 20:
		terrain.zombie_hit(tower, 1)
		hits += 1
	print("zumbi: %d golpes para tirar 1 bloco de pedra (sobram %d); chão natural quebra? %s" % [hits, terrain.built_count(tower), terrain.zombie_hit(col, 5)])
	var near := terrain.built_near(Vector3((tower.x - 1) * 0.4, terrain.column_top(tower) - 0.5, (tower.y + 0.5) * 0.4), Vector3.RIGHT)
	print("built_near acha a torre pelo lado: %s (torre %s)" % [near, tower])
	# Save / load.
	var saved := terrain.save_data()
	terrain.load_data({"blocks": []})
	print("load vazio: colunas mexidas %d, topo da torre %.2f" % [terrain.blocks.size(), terrain.column_top(tower)])
	terrain.load_data(saved)
	print("load do save: colunas mexidas %d, topo da torre %.2f" % [terrain.blocks.size(), terrain.column_top(tower)])
	# Chunk descarregado e gerado de novo mantém os blocos.
	var coord := Vector2i(floori(spot.x / 64.0), floori(spot.y / 64.0))
	terrain._chunks[coord].free()
	terrain._chunks.erase(coord)
	terrain._lattice.erase(coord)
	terrain._build_chunk(coord)
	await physics_frame
	await physics_frame
	print("chunk recarregado: raio na torre %.2f, no buraco %.2f" % [_ray((tower.x + 0.5) * 0.4, (tower.y + 0.5) * 0.4), _ray(mid.x, mid.y)])
	quit()
