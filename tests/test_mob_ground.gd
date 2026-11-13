extends SceneTree
## Mobs não caem do mundo:
##  1) longe do chão carregado (distância de visão curta): zumbi e bicho ficam parados no ar
##     esperando o chão, em vez de cair e voltar para cima sem parar;
##  2) borda dos voxels: corpos em pé onde as colunas de voxel são soltas (o jogador se
##     afasta) não caem por baixo do chão de alturas enquanto o buraco fecha.

class Walker extends CharacterBody3D:
	func _ready() -> void:
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.3
		capsule.height = 1.6
		shape.shape = capsule
		shape.position.y = 0.8
		add_child(shape)
		collision_layer = 0
		collision_mask = 1
	func _physics_process(delta: float) -> void:
		velocity.y -= 9.8 * delta
		move_and_slide()


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await process_frame
	var main: Node3D = current_scene
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	player.set_physics_process(false)
	# 1) Visão curta: chão só até ~154 m. Zumbi e bicho a 185 m.
	terrain.view_distance = 220.0 * 0.7
	for k in 60:
		await process_frame
	var p0 := player.global_position
	var dir := Vector3(1, 0, 0) if p0.x < 0.0 else Vector3(-1, 0, 0) # para dentro da ilha
	var far := p0 + dir * 320.0
	far.y = terrain.height_at(far.x, far.z) + 0.4
	print("chão carregado a 320 m? %s (esperado false)" % WorldFloor.ground_at(far))
	var zombie: Zombie = load("res://scenes/zombie.tscn").instantiate()
	zombie.position = far
	main.get_node("Enemies").add_child(zombie)
	var animals: AnimalManager = main.get_node("Animals")
	var deer := animals.spawn("cervo", far + Vector3(0, 0, 4))
	for id in animals.animals.keys(): # o gerenciador solta bichos a mais de 200 m: aqui fica
		if animals.animals[id] == deer:
			animals.animals.erase(id)
	var rescued0 := WorldFloor.i.rescued
	var start_z := zombie.global_position.y
	var start_d := deer.global_position.y
	for k in 180:
		await physics_frame
	print("longe sem chão: zumbi desceu %.2f m, bicho desceu %.2f m, resgates %d (esperado ~0, ~0, 0)" % [
		start_z - zombie.global_position.y, start_d - deer.global_position.y, WorldFloor.i.rescued - rescued0])
	# Chão chega (jogador vai até lá): voltam a andar no chão.
	player.global_position = far - dir * 60.0 + Vector3.UP * 2.0
	terrain.update_around(player.global_position, -1, 120.0)
	for k in 120:
		await physics_frame
	var floor_z := terrain.height_at(zombie.global_position.x, zombie.global_position.z)
	print("com chão: zumbi a %.2f m do chão, chão carregado? %s" % [zombie.global_position.y - floor_z, WorldFloor.ground_at(zombie.global_position)])
	zombie.queue_free()
	deer.queue_free()
	terrain.view_distance = 220.0
	# 2) Borda dos voxels.
	var vw: VoxelWorld = main.get_node_or_null("Voxels")
	if vw == null:
		print("sem voxels")
		quit()
		return
	var center := Vector3(120, 0, 60)
	center.y = terrain.height_at(center.x, center.z) + 1.0
	player.global_position = center
	terrain.update_around(center, -1, 140.0) # o chão em volta (voltando de longe)
	vw.update_around(center, VoxelWorld.NEAR) # síncrono: tudo pronto
	for k in 30:
		await process_frame
	var walkers := []
	for k in 24:
		var a := TAU * k / 24.0
		var at := center + Vector3(cos(a), 0, sin(a)) * randf_range(30.0, 38.0)
		at.y = terrain.height_at(at.x, at.z) + 0.05
		var w := Walker.new()
		main.add_child(w)
		w.global_position = at
		walkers.append(w)
	for k in 60:
		await physics_frame
	var on_voxel := 0
	for w: Walker in walkers:
		on_voxel += 1 if vw.covers(w.global_position + Vector3.DOWN * 0.3) else 0
	# Afasta o jogador 60 m: as colunas embaixo dos corpos são soltas.
	var first_fall := {}
	var before := []
	for w: Walker in walkers:
		before.append(w.global_position.y - terrain.height_at(w.global_position.x, w.global_position.z))
	print("antes de afastar: altura dos corpos sobre o chão: min %.2f max %.2f" % [before.min(), before.max()])
	for k in 210:
		if k < 90:
			player.global_position = center + Vector3(60.0 * k / 90.0, 0, 0)
			player.global_position.y = terrain.height_at(player.global_position.x, player.global_position.z) + 1.0
		await physics_frame
		for w: Walker in walkers:
			var below: float = terrain.height_at(w.global_position.x, w.global_position.z) - w.global_position.y
			if below > 0.5 and not first_fall.has(w):
				var col := Vector2i(floori(w.global_position.x / VoxelWorld.SECTION), floori(w.global_position.z / VoxelWorld.SECTION))
				var chunk := Vector2i(floori(w.global_position.x / terrain.chunk_size), floori(w.global_position.z / terrain.chunk_size))
				var holes: PackedByteArray = terrain._holes.get(chunk, PackedByteArray())
				var per := 10
				var li := Vector2i(posmod(col.x, per), posmod(col.y, per))
				var hole := holes[li.y * per + li.x] if not holes.is_empty() else 0
				var ground := terrain._chunks[chunk].get_node("Body/GroundShape") as CollisionShape3D
				var pieces: Array = terrain._chunks[chunk].get_node("Body").get_meta("pieces", [])
				var piece_off = pieces[li.y * per + li.x].disabled if not pieces.is_empty() else null
				first_fall[w] = true
				print("  caiu no quadro %d: coluna %s carregada=%s pronta=%s | buraco=%d chão inteiro desligado=%s forma=%s pedaço desligado=%s | retirando=%s sujo=%s refazendo=%s" % [k, col,
					vw._columns.has(col), vw._columns.get(col, {}).get("ready", false), hole, ground.disabled, ground.shape.get_class() if ground.shape else "null",
					piece_off, vw._retiring.has(chunk), vw._dirty_chunks.has(chunk), terrain._rebuilds.has(chunk)])
	var fell := 0
	var worst := 0.0
	for w: Walker in walkers:
		var below: float = terrain.height_at(w.global_position.x, w.global_position.z) - w.global_position.y
		worst = maxf(worst, below)
		fell += 1 if below > 0.5 else 0
	print("borda dos voxels: %d corpos (%d em cima de voxel), caíram por baixo do chão: %d (pior %.2f m abaixo)" % [walkers.size(), on_voxel, fell, worst])
	quit()
