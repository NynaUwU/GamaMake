extends SceneTree
## Rede dos blocos do chão (rode junto com tests/net_terrain_client.gd): o host cava e
## constrói antes do cliente entrar (o cliente recebe ao entrar), depois confere o
## bloco que o cliente pediu.
var t := 0.0
var started := false
var done_edit := false
const COL := Vector2i(300, 190)

func _process(delta: float) -> bool:
	t += delta
	if not started:
		started = true
		Net.i.host_game("Host", 0)
	var main: Node = current_scene
	if main == null or main.name != "Main":
		return false
	var terrain: TerrainWorld = main.get_node("Terrain")
	if not done_edit and t > 3.0:
		done_edit = true
		for k in 3:
			terrain.request_place(COL, TerrainWorld.Mat.STONE)
		terrain.request_dig(COL + Vector2i(2, 0))
		print("HOST pôs 3 de pedra e cavou 1: colunas mexidas=", terrain.blocks.size())
	if t > 22.0:
		print("HOST no fim: colunas=", terrain.blocks.size(), " coluna do cliente ", COL + Vector2i(0, 3), " = ", terrain.blocks.get(COL + Vector2i(0, 3), PackedByteArray()),
			" torre=", terrain.blocks.get(COL, PackedByteArray()))
		quit()
	return false
