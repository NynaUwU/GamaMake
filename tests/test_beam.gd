extends SceneTree
## Pilar deitado (viga): coloca, transforma, salva/carrega e a colisão fica na horizontal.
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var bm: BuildingManager = main.get_node("Building")
	var wall := bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(20, 0, 20), 0])
	var beam := bm.host_apply("place", [BuildPiece.Kind.PILLAR, Vector3i(20, 7, 20), 1])
	var beam_z := bm.host_apply("place", [BuildPiece.Kind.PILLAR, Vector3i(30, 0, 20), 2])
	var bad := bm.host_apply("place", [BuildPiece.Kind.PILLAR, Vector3i(30, 0, 30), 5])
	print("parede=%s viga X=%s viga Z=%s rot inválido aceito=%s" % [not wall.is_empty(), not beam.is_empty(), not beam_z.is_empty(), not bad.is_empty()])
	await physics_frame
	var piece: BuildPiece = bm.pieces[beam[0]]
	var a := piece.global_transform * Vector3(0, 0, 0)
	var b := piece.global_transform * Vector3(0, BuildPiece.SIZE, 0)
	print("viga X: de %s a %s (base y=%.2f)" % [a.snapped(Vector3.ONE * 0.01), b.snapped(Vector3.ONE * 0.01), (piece.global_transform * Vector3(-0.2, 0, -0.2)).y])
	var pz: BuildPiece = bm.pieces[beam_z[0]]
	print("viga Z: ponta em %s" % (pz.global_transform * Vector3(0, BuildPiece.SIZE, 0)).snapped(Vector3.ONE * 0.01))
	# Raio de cima acerta a viga em cima da parede.
	var space: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(8.6, 6, 8.0), Vector3(8.6, 0, 8.0))
	var hit: Dictionary = space.intersect_ray(q)
	print("raio de cima: acertou %s em y=%.2f" % [hit.get("collider"), hit.get("position", Vector3.ZERO).y])
	var state: Array = bm.state()
	bm.load_state(state)
	await physics_frame
	var again: BuildPiece = bm.pieces.get(beam[0])
	print("depois de carregar: rot=%d mesmo lugar=%s" % [again.rot, again.global_transform.origin.is_equal_approx(piece.global_transform.origin)])
	quit()
