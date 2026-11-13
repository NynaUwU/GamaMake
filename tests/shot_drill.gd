extends SceneTree
## Foto da jazida e da perfuratriz no salão do fim de uma caverna (SHOT=pasta), com uma luz
## (lá embaixo é escuro) e um motor a vapor girando a broca.
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	var main: Node3D = current_scene
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	var vw: VoxelWorld = main.get_node_or_null("Voxels")
	var placed: PlacedManager = main.get_node("Placed")
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	var deposits := terrain.deposits()
	if vw == null or deposits.is_empty():
		quit()
		return
	deposits.sort_custom(func(a, b): return Vector2(a[0].x, a[0].z).length() < Vector2(b[0].x, b[0].z).length())
	for pick in [deposits[0], deposits[1]]:
		var center: Vector3 = pick[0]
		var k: int = pick[2]
		var dir := Vector3(terrain.cave_entrances[k + 2], 0, terrain.cave_entrances[k + 3])
		player.set_physics_process(false)
		player.global_position = center - dir * 3.0 # o streaming solta o que fica longe do jogador
		terrain.update_around(center, -1, 140.0)
		vw.update_around(center, VoxelWorld.NEAR)
		for f in 10:
			await process_frame
		# Bloco de jazida exposto mais perto do salão.
		var c := VoxelWorld.block_of(center)
		var face := VoxelWorld.NO_BLOCK
		var best := INF
		var room := center - dir * 3.8 + Vector3.UP * 2.6 # centro do salão
		for dy in range(-7, 8):
			for dz in range(-7, 8):
				for dx in range(-7, 8):
					var b := c + Vector3i(dx, dy, dz)
					if VoxelWorld.is_deposit(vw.material_at(b)) and vw.material_at(b + Vector3i.UP) == VoxelRef.AIR:
						var d := VoxelWorld.block_center(b).distance_to(room)
						if d < best:
							best = d
							face = b
		if face == VoxelWorld.NO_BLOCK:
			continue
		var spot := VoxelWorld.block_center(face) + Vector3.UP * 0.2
		var side := dir.cross(Vector3.UP)
		var basis := Basis.looking_at(side, Vector3.UP) # porta de latão (−X local) virada para o salão
		var r := placed.host_apply("place", ["drill", Transform3D(basis, spot)])
		if r.is_empty():
			continue
		var drill: PlacedObject = placed.objects[r[0]]
		var port: Vector3 = Power.world_ports(drill)[0][0]
		var re := placed.host_apply("place", ["steam_engine", Transform3D(basis, port - basis * Vector3(1.08, 0.6, 0))])
		if not re.is_empty():
			placed.objects[re[0]].extra.steam = 1.0
		Power.dirty = true
		for s in 12:
			placed.clock += 1.0
			placed._power()
		var light := OmniLight3D.new()
		light.omni_range = 14.0
		light.light_energy = 2.2
		light.light_color = Color(1.0, 0.85, 0.6)
		main.add_child(light)
		light.global_position = room + Vector3.UP * 0.5 - dir * 1.5
		player.set_physics_process(false)
		var eye := room - dir * 3.0 + side * 1.2
		player.global_position = eye - Vector3.UP * 1.6
		var look := spot + Vector3.UP * 1.0 - eye
		player.rotation.y = atan2(-look.x, -look.z)
		player.head.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
		for f in 50:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/perfuratriz_%s.png" % pick[1])
		print("foto: jazida de %s, %s" % [pick[1], Drill.text(drill)])
		break
	quit()
