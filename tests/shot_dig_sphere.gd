extends SceneTree
## Foto da picareta cavando em esfera (SHOT=pasta): a caixa da mira (3x3x3) e o buraco depois
## de alguns golpes.
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
	if vw == null:
		quit()
		return
	var spot := Vector3(150, 0, 90)
	terrain.update_around(spot, -1, 140.0)
	vw.update_around(spot, VoxelWorld.NEAR)
	spot.y = terrain._base_at(spot.x, spot.z) + 0.1
	player.set_physics_process(false)
	player.global_position = spot
	player.rotation.y = 0.0
	player.head.rotation.x = -0.75
	player.inventory.add(&"picareta")
	player.equip_item(&"picareta")
	player._equip = 1.0
	for k in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/esfera_mira.png")
	for hit in 4:
		var aim := TerrainTools.aim(player)
		if aim.is_empty():
			break
		TerrainTools.dig(player)
		TerrainTools.dig(player) # terra com a picareta: 2 golpes
		for k in 10:
			await process_frame
	player.head.rotation.x = -0.6
	for k in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/esfera_buraco.png")
	print("edições: %d, itens: terra %d pedra %d areia %d" % [vw.edits.size(), player.inventory.count(&"terra"), player.inventory.count(&"pedra"), player.inventory.count(&"areia")])
	quit()
