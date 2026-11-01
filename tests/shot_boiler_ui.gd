extends SceneTree
## Foto da janela da caldeira (SHOT=pasta).
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	var main := current_scene
	var placed: PlacedManager = main.get_node("Placed")
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	var at := player.global_position - player.global_basis.z * 4.0
	at.y = terrain.height_at(at.x, at.z)
	var r := placed.host_apply("place", ["boiler", Transform3D(Basis(Vector3.UP, player.rotation.y), at)])
	var boiler: PlacedObject = placed.objects[r[0]]
	ContainerManager.i.contents[Smelting.key_of(boiler)] = [{}, {"id": &"carvao", "amount": 12}, {}]
	boiler.extra.merge({"burn": 25.0, "burn_max": 40.0, "heat": 0.85, "water": 6.0, "pressure": 1.1, "dry": 0.0}, true)
	boiler.refresh(placed.clock)
	StorageUI.open_for(player, Smelting.key_of(boiler), boiler)
	for k in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/janela_caldeira.png")
	quit()
