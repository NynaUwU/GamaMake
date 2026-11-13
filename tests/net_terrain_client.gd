extends SceneTree
## Ver tests/net_terrain_host.gd.
var t := 0.0
var step := 0
const COL := Vector2i(300, 190)

func _process(delta: float) -> bool:
	t += delta
	if step == 0 and t > 6.0:
		step = 1
		Net.i.join_game("127.0.0.1", "Cliente")
	elif step == 1 and current_scene and current_scene.name == "Main" and t > 12.0:
		step = 2
		var terrain: TerrainWorld = current_scene.get_node("Terrain")
		print("CLIENT ao entrar: colunas=", terrain.blocks.size(), " torre=", terrain.blocks.get(COL, PackedByteArray()), " buraco=", terrain.blocks.get(COL + Vector2i(2, 0), PackedByteArray()))
		terrain.request_place(COL + Vector2i(0, 3), TerrainWorld.Mat.DIRT)
		terrain.request_place(COL + Vector2i(0, 3), TerrainWorld.Mat.DIRT)
	elif step == 2 and t > 17.0:
		step = 3
		var terrain: TerrainWorld = current_scene.get_node("Terrain")
		print("CLIENT depois de pedir 2 de terra: ", terrain.blocks.get(COL + Vector2i(0, 3), PackedByteArray()), " topo ", snappedf(terrain.column_top(COL + Vector2i(0, 3)), 0.01))
		quit()
	return false
