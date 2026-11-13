extends SceneTree
## Blocos do chão no jogo: pá cava (dá terra), terra na mão põe bloco, pilha de
## pedra, cubo de mira, zumbi quebra bloco posto e não cava o chão natural.

var main: Node3D
var terrain: TerrainWorld
var player: Player


func _hold(id: StringName) -> void:
	for i in player.inventory.slots.size():
		if not player.inventory.slots[i].is_empty() and player.inventory.slots[i].id == id:
			if i >= Inventory.HOTBAR_SIZE:
				player.inventory.swap(i, 0)
				i = 0
			player.inventory.select(i)
			return


func _look_down(pitch: float) -> void:
	player.head.rotation.x = pitch
	await physics_frame
	await process_frame


func _init() -> void:
	VoxelWorld.enabled = false # testa o chão de alturas (colunas de 0,4 m), sem a área de voxels
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	terrain = main.get_node("Terrain")
	player = main.player
	for e in main.get_node("Enemies").get_children():
		e.detect_range = 0.0
	# Leva o jogador para um campo aberto fora da cidade inicial.
	var spot := Vector3(120, 0, 75)
	spot.y = terrain.height_at(spot.x, spot.z) + 1.0
	player.global_position = spot
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	for k in 30:
		await physics_frame
	# --- Pá: golpe no chão cava.
	player.inventory.add(&"pa")
	player.equip_item(&"pa")
	player._equip = 1.0
	await _look_down(-0.9)
	var aim := TerrainTools.aim(player)
	print("mira no chão: %s" % ("coluna %s, ponto %s" % [aim.dig, aim.point.snapped(Vector3.ONE * 0.01)] if not aim.is_empty() else "nada"))
	var col: Vector2i = aim.dig
	var top0 := terrain.column_top(col)
	var terra0 := player.inventory.count(&"terra")
	for k in 3:
		TerrainTools.dig(player)
	await physics_frame
	print("pá 3 golpes: topo %.2f -> %.2f, terra na mochila %d -> %d, cursor visível %s" % [top0, terrain.column_top(col), terra0,
		player.inventory.count(&"terra"), TerrainTools._cursor != null and TerrainTools._cursor.visible])
	# --- Terra na mão: põe bloco; enche o buraco de volta e sobe 2 acima.
	player.inventory.add(&"terra", 10)
	_hold(&"terra")
	await physics_frame
	aim = TerrainTools.aim(player)
	var place_col: Vector2i = aim.place
	var before := terrain.column_offset(place_col)
	var terra1 := player.inventory.count(&"terra")
	for k in 3:
		TerrainTools.place(player)
		await physics_frame
	print("terra na mão, 3 cliques na coluna %s: desnível %d -> %d, terra %d -> %d, construídos %d" % [place_col, before,
		terrain.column_offset(place_col), terra1, player.inventory.count(&"terra"), terrain.built_count(place_col)])
	# --- Pedra: 2 por bloco.
	player.inventory.add(&"pedra", 6)
	_hold(&"pedra")
	await physics_frame
	var pedra0 := player.inventory.count(&"pedra")
	TerrainTools.place(player)
	print("pedra: 1 bloco gastou %d pedras; topo agora é %s" % [pedra0 - player.inventory.count(&"pedra"), terrain.top_material(TerrainTools.aim(player).place)])
	# --- Bloco embaixo do próprio jogador: não deixa.
	var under := TerrainWorld.column_at(player.global_position.x, player.global_position.z)
	print("pôr bloco embaixo do jogador bloqueado: %s" % TerrainTools._blocked(player, under))
	# --- Muro de terra 5 de altura: zumbi quebra; chão natural não.
	var wall_cols := []
	var base := TerrainWorld.column_at(spot.x, spot.z - 6.0)
	for dx in range(-3, 4):
		var c := base + Vector2i(dx, 0)
		wall_cols.append(c)
		for k in 5:
			terrain.request_place(c, TerrainWorld.Mat.DIRT)
	await physics_frame
	await physics_frame
	var z: Zombie = main.get_node("Enemies").get_children().filter(func(n): return n is Zombie)[0]
	var wall_z: float = (wall_cols[0].y + 0.5) * 0.4
	var zx := spot.x
	z.global_position = Vector3(zx, terrain.height_at(zx, wall_z - 1.0) + 0.05, wall_z - 1.0)
	z.velocity = Vector3.ZERO
	await physics_frame
	var from := z.global_position + Vector3.UP * 1.0
	var hit := z.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 0, 1) * 1.5, 1, [z.get_rid()]))
	print("zumbi vê o muro de terra como construção: %s" % Zombie.is_build_hit(hit, Vector3(0, 0, 1)))
	var total_before := 0
	for c in wall_cols:
		total_before += terrain.built_count(c)
	z._wall = {"normal": Vector3(0, 0, -1), "direction": Vector3(0, 0, 1)}
	for k in 12:
		z._damage_wall()
	var total_after := 0
	for c in wall_cols:
		total_after += terrain.built_count(c)
	print("12 golpes de zumbi no muro: blocos %d -> %d (terra = 3 golpes cada)" % [total_before, total_after])
	# Chão natural: morro sem blocos na frente do zumbi.
	var natural := TerrainWorld.column_at(z.global_position.x - 3.0, z.global_position.z)
	var nat_before := terrain.column_offset(natural)
	z.global_position = Vector3(z.global_position.x - 3.0, z.global_position.y, z.global_position.z)
	for k in 12:
		z._damage_wall()
	print("12 golpes de zumbi no chão natural: desnível %d -> %d" % [nat_before, terrain.column_offset(natural)])
	# Save do mundo guarda os blocos.
	var data := SaveGame.collect(main)
	print("save: blocos guardados %d" % data.persist.get("terrain", {}).get("blocks", []).size())
	quit()
