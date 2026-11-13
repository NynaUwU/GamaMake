extends SceneTree
## Fase 2 dos voxels: chão de voxels em volta do jogador (com a extensão C++), andar nele,
## cavar/construir em 3D, zumbi quebra bloco posto, caverna (barreira do fundo do mundo
## não resgata, sem água de lago, neblina de caverna) e save das edições.

var main: Node3D
var player: Player
var vw: VoxelWorld
var terrain: TerrainWorld


func _hold(id: StringName) -> void:
	for k in player.inventory.slots.size():
		if not player.inventory.slots[k].is_empty() and player.inventory.slots[k].id == id:
			if k >= Inventory.HOTBAR_SIZE:
				player.inventory.swap(k, 0)
				k = 0
			player.inventory.select(k)
			return


func _frames(n: int) -> void:
	for k in n:
		await physics_frame


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	player = main.player
	terrain = main.get_node("Terrain")
	vw = main.get_node_or_null("Voxels")
	print("VoxelWorld: %s, C++: %s" % [vw != null, vw.native if vw else false])
	if vw == null:
		quit()
		return
	for e in main.get_node("Enemies").get_children():
		e.detect_range = 0.0
	# Leva o jogador para um campo e gera tudo em volta de uma vez (medindo).
	var spot := Vector3(150, 0, 100)
	spot.y = terrain.height_at(spot.x, spot.z) + 1.0
	player.global_position = spot
	player.velocity = Vector3.ZERO
	terrain.update_around(spot, -1, 120.0)
	var t0 := Time.get_ticks_msec()
	vw.update_around(spot, VoxelWorld.NEAR, -1)
	var ms := Time.get_ticks_msec() - t0
	var tris := 0
	for node in vw._nodes.values():
		tris += ((node.get_node("Mesh") as MeshInstance3D).mesh as ArrayMesh).surface_get_array_len(0) / 3
	print("em volta (raio %.0f m): %d colunas, %d seções (%d com superfície), %d triângulos, %d ms" % [VoxelWorld.NEAR, vw._columns.size(),
		vw.sections.size(), vw._nodes.size(), tris, ms])
	await _frames(40)
	var down := main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 3, spot + Vector3.DOWN * 10, 1, [player.get_rid()]))
	print("chão embaixo do jogador é voxel: %s; jogador parado em y=%.2f (chão natural %.2f)" % [VoxelWorld.is_voxel_body(down.get("collider")),
		player.global_position.y, terrain._base_at(spot.x, spot.z)])
	# Cavar com a pá olhando para baixo, e pôr terra de volta.
	player.inventory.add(&"pa")
	player.inventory.add(&"picareta")
	player.equip_item(&"pa")
	player._equip = 1.0
	player.rotation.y = 0.0
	player.head.rotation.x = -1.0
	await _frames(2)
	var aim := TerrainTools.aim(player)
	print("mira: voxel=%s, bloco %s, material %d" % [aim.get("voxel", false), aim.get("dig"), vw.material_at(aim.get("dig", VoxelWorld.NO_BLOCK))])
	var dug_block: Vector3i = aim.dig
	var item: StringName = vw.dig_result(dug_block).item
	var before := player.inventory.count(item)
	TerrainTools.dig(player)
	await _frames(2)
	var air := 0
	for off: Vector3i in VoxelWorld.sphere_offsets():
		air += 1 if vw.material_at(dug_block + off) == VoxelRef.AIR else 0
	print("pá: bloco agora %d (0 = ar), esfera 3x3x3: %d de %d blocos viraram ar, %s %d -> %d, edições %d" % [vw.material_at(dug_block),
		air, VoxelWorld.sphere_offsets().size(), item, before, player.inventory.count(item), vw.edits.size()])
	_hold(item)
	await _frames(2)
	var aim2 := TerrainTools.aim(player)
	TerrainTools.place(player)
	await _frames(2)
	print("pôs o bloco %s: material %d (16 terra, 17 pedra, 18 areia postas), construção: %s" % [aim2.place, vw.material_at(aim2.place), VoxelWorld.is_built(vw.material_at(aim2.place))])
	# Zumbi: o bloco posto é construção; chão natural não.
	var z: Zombie = main.get_node("Enemies").get_children().filter(func(n): return n is Zombie)[0]
	var hits := 0
	while VoxelWorld.is_built(vw.material_at(aim2.place)) and hits < 10:
		vw.zombie_hit(aim2.place, 1)
		hits += 1
	print("zumbi: %d golpes para quebrar o bloco posto; chão natural quebra? %s" % [hits, vw.zombie_hit(dug_block + Vector3i(0, -2, 0), 5)])
	# Caverna: procura ar bem abaixo do chão nas seções carregadas e põe o jogador lá.
	var cave := Vector3.INF
	for sec: Vector3i in vw.sections:
		if cave != Vector3.INF:
			break
		var d: PackedByteArray = vw.sections[sec]
		for k in range(0, VoxelRef.P3, 3):
			var x := k % VoxelRef.P
			var zz := (k / VoxelRef.P) % VoxelRef.P
			var y := k / (VoxelRef.P * VoxelRef.P)
			if x < 2 or zz < 2 or y < 2 or x > 15 or zz > 15 or y > 15 or VoxelRef.density(d, k) > 0:
				continue
			var p := VoxelWorld.block_center(sec * 16 + Vector3i(x - 1, y - 1, zz - 1))
			if p.y < terrain._base_at(p.x, p.z) - 8.0 and vw.solid_at(p + Vector3.DOWN * 0.8) == 1 and vw.solid_at(p + Vector3.UP * 1.2) == 0 \
					and vw.solid_at(p + Vector3.UP * 1.8) == 0:
				cave = p
				break
	print("caverna achada: %s" % cave)
	if cave != Vector3.INF:
		player.global_position = cave + Vector3.UP * 0.1
		player.velocity = Vector3(0, -6, 0) # caindo: a barreira confere
		var rescued_before: int = main.get_node("WorldFloor").rescued if main.has_node("WorldFloor") else -1
		await _frames(90)
		print("na caverna: y=%.2f (chão natural %.2f), resgatado para cima? %s, fator caverna %.2f, água: %s" % [player.global_position.y,
			terrain._base_at(cave.x, cave.z), player.global_position.y > terrain._base_at(cave.x, cave.z) - 2.0, vw.cave_factor,
			WaterManager.i.depth_at(player.global_position) if WaterManager.i else -INF])
		var env: Environment = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
		print("neblina na caverna termina em %.0f m, luz ambiente %.2f" % [env.fog_depth_end, env.ambient_light_energy])
		# Picareta na parede de pedra.
		player.equip_item(&"picareta")
		player._equip = 1.0
		player.head.rotation.x = 0.0
		var got := {}
		for turn in 8:
			player.rotation.y = TAU * turn / 8.0
			await _frames(1)
			var a := TerrainTools.aim(player)
			if a.is_empty() or not a.get("voxel", false):
				continue
			var res := vw.dig_result(a.dig)
			if res.is_empty():
				continue
			var have := player.inventory.count(res.item)
			TerrainTools.dig(player)
			got[res.item] = player.inventory.count(res.item) - have
		print("picareta na parede da caverna: %s" % got)
	# Save das edições.
	var data := SaveGame.collect(main)
	print("save: %d edições de voxel" % data.persist.get("voxels", {}).get("edits", []).size())
	quit()
