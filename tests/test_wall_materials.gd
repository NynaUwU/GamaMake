extends SceneTree
## Paredes com material: madeira, chapa, pedra e taipa. Custo no menu, golpes de zumbi
## por quadrado, save novo (número) e save antigo (bool "metal"), conserto.

func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main: Node3D = current_scene
	var bm: BuildingManager = main.get_node("Building")
	for id in ["wall", "wall_metal", "wall_stone", "wall_earth", "floor_stone", "pillar_stone"]:
		for e in Builder.ENTRIES["Estrutura"]:
			if e.id == id:
				print("%s: %s, custo %s, material %s" % [id, e.name, e.cost, BuildPiece.MAT_NAMES[int(e.get("mat", 0))]])
	var base := Vector3i(40, 0, 40)
	var mats := [BuildPiece.Mat.WOOD, BuildPiece.Mat.METAL, BuildPiece.Mat.STONE, BuildPiece.Mat.EARTH]
	for k in mats.size():
		bm.request_place(BuildPiece.Kind.WALL, base + Vector3i(k * 8, 0, 0), 0, mats[k])
	await physics_frame
	var by_mat := {}
	for p: BuildPiece in bm.pieces.values():
		by_mat[p.material] = p
	for m in mats:
		var p: BuildPiece = by_mat.get(m)
		print("parede de %s: material %d, metal? %s, golpes por quadrado %d, conserto %s" % [BuildPiece.MAT_NAMES[m], p.material, p.metal, p.hits(),
			Builder.repair_cost(p)])
	var state := bm.state()
	print("save novo guarda material: %s" % str(state.map(func(e): return e[7])))
	# Save antigo: [7] era bool.
	var bm2 := BuildingManager.new()
	main.add_child(bm2)
	bm2.load_state([[901, BuildPiece.Kind.WALL, Vector3i(0, 0, 90), 0, PackedByteArray(), [], PackedInt32Array(), true],
		[902, BuildPiece.Kind.WALL, Vector3i(8, 0, 90), 0, PackedByteArray(), [], PackedInt32Array(), false],
		[903, BuildPiece.Kind.WALL, Vector3i(16, 0, 90), 0, PackedByteArray(), [], PackedInt32Array()]])
	print("save antigo: true -> %s, false -> %s, sem campo -> %s" % [BuildPiece.MAT_NAMES[bm2.pieces[901].material], BuildPiece.MAT_NAMES[bm2.pieces[902].material],
		BuildPiece.MAT_NAMES[bm2.pieces[903].material]])
	# Desmontar devolve a metade do custo certo.
	print("entrada pelo tipo+material: pedra -> %s, taipa -> %s, chapa (bool) -> %s" % [Builder.entry_for_kind(BuildPiece.Kind.WALL, BuildPiece.Mat.STONE).id,
		Builder.entry_for_kind(BuildPiece.Kind.WALL, BuildPiece.Mat.EARTH).id, Builder.entry_for_kind(BuildPiece.Kind.WALL, true).id])
	quit()
