extends SceneTree
## Pôr em massa: arrastando com bloco na mão (terra/pedra/areia/tábua) põe a caixa toda; só
## paga o que tem; com o martelo, arrastar põe uma fileira de paredes e uma área de pisos.

func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await process_frame
	var main: Node3D = current_scene
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	var vw: VoxelWorld = main.get_node_or_null("Voxels")
	var building: BuildingManager = main.get_node("Building")
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	player.set_physics_process(false)
	var spot := Vector3(140, 0, 80)
	spot.y = terrain.height_at(spot.x, spot.z) + 0.1
	player.global_position = spot
	terrain.update_around(spot, -1, 140.0)
	if vw:
		vw.update_around(spot, VoxelWorld.NEAR)
	for k in 10:
		await process_frame
	# 1) Parede de tábuas 6 x 4 blocos (2,4 m x 1,6 m), na frente do jogador.
	var ground := VoxelWorld.block_of(Vector3(spot.x, terrain._base_at(spot.x, spot.z - 3.0) + 0.2, spot.z - 3.0))
	player.inventory.slots[8] = {"id": &"tabua", "amount": 100}
	player.inventory.select(8)
	var before := player.inventory.count(&"tabua")
	TerrainTools._mass = {"start": ground + Vector3i(0, 1, 0), "end": ground + Vector3i(5, 4, 0), "id": &"tabua"}
	TerrainTools._finish_mass(player)
	for k in 5:
		await process_frame
	var wood := 0
	for y in range(1, 5):
		for x in 6:
			wood += 1 if vw.material_at(ground + Vector3i(x, y, 0)) == VoxelRef.BUILT_WOOD else 0
	print("parede de tábuas: %d de 24 blocos postos, gastou %d tábuas" % [wood, before - player.inventory.count(&"tabua")])
	# 2) Pouca pedra (5 = 2 blocos de pedra a 2 cada): põe só o que dá.
	player.inventory.slots[7] = {"id": &"pedra", "amount": 5}
	player.inventory.select(7)
	var row := ground + Vector3i(0, 1, -3)
	TerrainTools._mass = {"start": row, "end": row + Vector3i(9, 0, 0), "id": &"pedra"}
	TerrainTools._finish_mass(player)
	for k in 5:
		await process_frame
	var stones := 0
	for x in 10:
		stones += 1 if vw.material_at(row + Vector3i(x, 0, 0)) == VoxelRef.BUILT_STONE else 0
	print("fileira de 10 pedras com material para 2: postos %d, sobrou %d pedra" % [stones, player.inventory.count(&"pedra")])
	print("tábua posta é construção (zumbi quebra)? %s" % VoxelWorld.is_built(VoxelRef.BUILT_WOOD))
	# 3) Martelo: fileira de 3 paredes e área de 2 x 2 pisos.
	player.equip_item(&"martelo")
	player.inventory.add(&"tabua", 100)
	var b := player.builder
	var n := BuildPiece.N
	var base := Vector3i(roundi(spot.x / BuildPiece.SEG) + 20, roundi(terrain.height_at(spot.x + 8.0, spot.z) / BuildPiece.SEG), roundi(spot.z / BuildPiece.SEG))
	b.select(Builder.ENTRIES["Estrutura"][0]) # parede
	var walls_before := building.pieces.size()
	b._row = {"kind": BuildPiece.Kind.WALL, "rot": 0, "start": base, "end": base + Vector3i(2 * n, 0, 0)}
	b._update_row()
	await process_frame
	print("martelo arrastando 3 paredes: %d peças novas" % (building.pieces.size() - walls_before))
	b.select(Builder.ENTRIES["Estrutura"][1]) # piso
	var floors_before := building.pieces.size()
	var fbase := base + Vector3i(0, 0, 3 * n)
	b._row = {"kind": BuildPiece.Kind.FLOOR, "rot": 0, "start": fbase, "end": fbase + Vector3i(n, 0, n)}
	b._update_row()
	await process_frame
	print("martelo arrastando 2 x 2 pisos: %d peças novas" % (building.pieces.size() - floors_before))
	quit()
