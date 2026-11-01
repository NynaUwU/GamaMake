extends SceneTree
## Configurações do "Criar mundo" chegam no jogo; save guarda; desmontar (Shift + direito).
func _init() -> void:
	WorldSettings.values = {"size": 2.0, "track": 0.0, "cities": 50.0, "rivers": 2.0, "day_length": 5.0, "zombies": 0.0}
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var terrain: TerrainWorld = main.get_node("Terrain")
	print("mapa %.0f m, pista=%s, cidades=%d, rios=%d" % [terrain.world_size, not terrain.track.is_empty(), terrain.cities.size(), terrain.rivers.size()])
	var h0 := DayNight.i.hour
	var t0 := Time.get_ticks_msec()
	for k in 60:
		await process_frame
	print("relógio: %.3f h por segundo (5 min/dia = 0.080)" % ((DayNight.i.hour - h0) / ((Time.get_ticks_msec() - t0) / 1000.0)))
	var data := SaveGame.collect(main)
	print("save guarda: ", data.settings)
	# Desmontar: baú na frente do jogador, mira nele.
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	var front := player.global_position - player.global_basis.z * 2.0
	front.y = terrain.height_at(front.x, front.z)
	placed.host_apply("place", ["chest", Transform3D(Basis(), front)])
	for k in 3:
		await physics_frame
	player.head.rotation.x = -atan2(player.camera.global_position.y - front.y - 0.4, 2.0)
	for k in 3:
		await physics_frame
	var before := placed.objects.size()
	var ok := player.builder.dismantle()
	for k in 3:
		await physics_frame
	print("desmontou=%s objetos %d -> %d" % [ok, before, placed.objects.size()])
	quit()
