extends SceneTree
## Voxels gerados enquanto o jogador anda rápido (20 m/s, de carro): pior quadro, colunas
## geradas e soltas, e o chão de alturas com o buraco certo.

func _init() -> void:
	Engine.max_fps = 60 # tempo real (sem tela o Godot rodaria os quadros bem mais rápido)
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await process_frame
	var main: Node3D = current_scene
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	var vw: VoxelWorld = main.get_node_or_null("Voxels")
	if vw == null:
		print("sem voxels")
		quit()
		return
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	player.set_physics_process(false)
	# Espera o entorno do começo ficar pronto (como na tela de carregamento).
	for k in 120:
		await process_frame
	var start := Vector3(100, 0, 40)
	var speed := 20.0
	var worst := 0.0
	var total := 0.0
	var frames := 0
	var slow := 0
	var last := Time.get_ticks_usec()
	var made_cols := {}
	for k in 600: # 10 s a 60 quadros
		var p := start + Vector3(1, 0, 0.35).normalized() * speed * k / 60.0
		p.y = terrain.height_at(p.x, p.z) + 1.0
		player.global_position = p
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		if k > 5:
			if ms > worst:
				print("  quadro %d: %.1f ms" % [k, ms]) if ms > 60.0 else null
			worst = maxf(worst, ms)
			total += ms
			frames += 1
			slow += 1 if ms > 33.0 else 0
		for col in vw._columns:
			made_cols[col] = true
	print("10 s andando a %.0f m/s: quadro médio %.1f ms, pior %.1f ms, quadros acima de 33 ms: %d de %d" % [speed, total / frames, worst, slow, frames])
	print("pior tempo por parte (ms): uma coluna nova %.1f, recolher seções %.1f, buraco no chão %.1f, soltar coluna %.1f" % [vw.stats.add, vw.stats.collect, vw.stats.holes, vw.stats.drop])
	print("colunas de voxel geradas %d, carregadas agora %d, seções %d, tarefas na fila %d" % [made_cols.size(), vw._columns.size(), vw.sections.size(), vw._tasks.size()])
	# O chão embaixo do jogador é voxel (o buraco no chão de alturas acompanhou)?
	for k in 60:
		await process_frame
	var p := player.global_position
	var hit := main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2, p + Vector3.DOWN * 6, 1, [player.get_rid()]))
	print("no fim: chão embaixo é voxel? %s; chunks com buraco no chão de alturas: %d" % [VoxelWorld.is_voxel_body(hit.get("collider")), terrain._holes.size()])
	quit()
