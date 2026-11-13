extends SceneTree
## Rede dos voxels (rode junto com tests/net_voxel_client.gd): o host cava e põe blocos antes
## do cliente entrar; quem entra recebe; o pedido do cliente vale no host e volta.
var t := 0.0
var started := false
var done := false
const SPOT := Vector2(12.0, 30.0)

func _process(delta: float) -> bool:
	t += delta
	if not started:
		started = true
		Engine.max_fps = 60
		Net.i.host_game("Host", 0)
	var main: Node = current_scene
	if main == null or main.name != "Main" or not main.has_node("Voxels"):
		return false
	var vw: VoxelWorld = main.get_node("Voxels")
	var terrain: TerrainWorld = main.get_node("Terrain")
	var top := VoxelWorld.block_of(Vector3(SPOT.x, terrain._base_at(SPOT.x, SPOT.y) - 0.2, SPOT.y))
	if not done and t > 4.0 and vw.material_at(top) > 0:
		done = true
		vw.request_dig(top)
		vw.request_dig(top + Vector3i(0, -1, 0))
		vw.request_place(top + Vector3i(3, 1, 0), VoxelRef.BUILT_STONE)
		print("HOST cavou 2 e pôs 1 pedra: edições %d" % vw.edits.size())
	if t > 24.0:
		print("HOST no fim: edições %d, bloco do cliente %d" % [vw.edits.size(), vw.material_at(top + Vector3i(0, 1, 3))])
		quit()
	return false
