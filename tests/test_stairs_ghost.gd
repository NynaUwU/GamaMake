extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	var terrain: TerrainWorld = main.get_node("Terrain")
	var base := Vector3(8, terrain.height_at(8, 8), 8)
	var r := placed.host_apply("place", ["stairs", Transform3D(Basis(), base)])
	print("escada colocada: ", not r.is_empty())
	for k in 5:
		await physics_frame
	player.global_position = base + Vector3(0, 0.1, 1.2)
	player.rotation.y = 0.0 # olhando para -Z (subindo)
	for k in 10:
		await physics_frame
	Input.action_press("move_forward")
	var top := 0.0
	for k in 240:
		await physics_frame
		top = maxf(top, player.global_position.y - base.y)
	Input.action_release("move_forward")
	print("subiu: %.2f m (topo 2,8)" % top)
	var b: Builder = player.builder
	b._build_model_ghost("stairs")
	print("fantasma escada: %d malhas" % b._model_ghost.get_child_count())
	b._model_kind = ""
	var fires_before := Cooking.fires.size()
	b._build_model_ghost("campfire")
	print("fantasma fogueira: %d malhas, fogos registrados mudou=%s" % [b._model_ghost.get_child_count(), Cooking.fires.size() != fires_before])
	var snapped := Builder.grid_snap("chest", Transform3D(Basis(Vector3.UP, 0.7), Vector3(1.13, 0, 2.77)))
	print("grade baú: ", snapped.origin, " giro ", rad_to_deg(snapped.basis.get_euler().y))
	snapped = Builder.grid_snap("stairs", Transform3D(Basis(Vector3.UP, 1.4), Vector3(1.13, 0, 2.77)))
	print("grade escada: ", snapped.origin, " giro ", rad_to_deg(snapped.basis.get_euler().y))
	quit()
