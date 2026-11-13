extends SceneTree
## Ver tests/net_voxel_host.gd.
var t := 0.0
var step := 0
const SPOT := Vector2(12.0, 30.0)

func _process(delta: float) -> bool:
	t += delta
	if step == 0 and t > 8.0:
		step = 1
		Engine.max_fps = 60
		Net.i.join_game("127.0.0.1", "Cliente")
	elif step == 1 and current_scene and current_scene.name == "Main" and current_scene.has_node("Voxels") and t > 15.0:
		var vw: VoxelWorld = current_scene.get_node("Voxels")
		var terrain: TerrainWorld = current_scene.get_node("Terrain")
		var top := VoxelWorld.block_of(Vector3(SPOT.x, terrain._base_at(SPOT.x, SPOT.y) - 0.2, SPOT.y))
		if vw.material_at(top) < 0:
			return false # a área ainda não carregou
		step = 2
		print("CLIENT ao entrar: edições %d; bloco cavado %d (0 = ar), pedra posta %d (17)" % [vw.edits.size(), vw.material_at(top),
			vw.material_at(top + Vector3i(3, 1, 0))])
		vw.request_place(top + Vector3i(0, 1, 3), VoxelRef.BUILT_DIRT)
	elif step == 2 and t > 20.0:
		step = 3
		var vw: VoxelWorld = current_scene.get_node("Voxels")
		var terrain: TerrainWorld = current_scene.get_node("Terrain")
		var top := VoxelWorld.block_of(Vector3(SPOT.x, terrain._base_at(SPOT.x, SPOT.y) - 0.2, SPOT.y))
		print("CLIENT depois de pedir terra: %d (16 = terra posta), edições %d" % [vw.material_at(top + Vector3i(0, 1, 3)), vw.edits.size()])
		quit()
	return false
