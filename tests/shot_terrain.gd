extends SceneTree
## Fotos (SHOT=pasta) do terreno em grade: paisagem, buraco cavado, monte/muro de terra,
## torre de pedra, escada de blocos e o cubo de mira.

var main: Node3D
var terrain: TerrainWorld
var player: Player


func _shot(name: String, frames := 20) -> void:
	for k in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/" + name + ".png")


func _view(from: Vector3, at: Vector3) -> void:
	player.set_physics_process(false)
	player.global_position = from - Vector3.UP * 1.6
	var flat := Vector3(at.x - from.x, 0, at.z - from.z)
	player.rotation.y = atan2(-flat.x, -flat.z)
	player.head.rotation.x = atan2(at.y - from.y, flat.length())


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	main = current_scene
	terrain = main.get_node("Terrain")
	player = main.player
	Weather.i.target_rain = 0.0
	Weather.i.rain = 0.0
	DayNight.i.hour = 15.5
	DayNight.i._apply()
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	var c := Vector3(120, 0, 75)
	c.y = terrain.height_at(c.x, c.z)
	# Paisagem sem mexer.
	_view(c + Vector3(-14, 9, 22), c + Vector3(10, -2, -30))
	terrain.update_around(player.global_position, -1, 160.0)
	await _shot("terreno_paisagem", 60)
	var base := TerrainWorld.column_at(c.x, c.z)
	# Buraco 3x3 de 3 blocos, um poço de 1 coluna com 6, e uma vala.
	for dz in 3:
		for dx in 3:
			for k in 3:
				terrain.request_dig(base + Vector2i(dx, dz))
	for k in 6:
		terrain.request_dig(base + Vector2i(6, 1))
	for dx in 9:
		for k in 2:
			terrain.request_dig(base + Vector2i(-2 + dx, 6))
	# Muro de terra (5 de altura), torre de pedra (8), monte de areia e escada de blocos.
	for dx in 10:
		for k in 5:
			terrain.request_place(base + Vector2i(-4 + dx, -6), TerrainWorld.Mat.DIRT)
	for k in 8:
		terrain.request_place(base + Vector2i(9, -2), TerrainWorld.Mat.STONE)
	for dz in 2:
		for dx in 2:
			for k in 2:
				terrain.request_place(base + Vector2i(10 + dx, 3 + dz), TerrainWorld.Mat.SAND)
	for step in 6:
		for k in step + 1:
			terrain.request_place(base + Vector2i(-8, -2 + step), TerrainWorld.Mat.DIRT)
	var mid := Vector3((base.x + 1.5) * 0.4, c.y, (base.y + 1.5) * 0.4)
	_view(mid + Vector3(-4.5, 4.2, 6.5), mid + Vector3(0.5, -0.5, -0.5))
	await _shot("terreno_blocos", 30)
	_view(mid + Vector3(1.0, 3.0, 5.0), mid + Vector3(0.0, -1.2, 0.2))
	await _shot("terreno_buraco", 20)
	_view(mid + Vector3(-1.0, 1.7, -0.5), mid + Vector3(0.5, 0.8, -2.6))
	await _shot("terreno_muro", 20)
	# Paredes de madeira, chapa, pedra e taipa lado a lado (+ pilar e piso de pedra).
	var bm: BuildingManager = main.get_node("Building")
	var wall_at := mid + Vector3(-2.0, 0, 9.0)
	var gy := roundi(terrain.height_at(wall_at.x, wall_at.z) / BuildPiece.SEG)
	var gx := roundi(wall_at.x / BuildPiece.SEG)
	var gz := roundi(wall_at.z / BuildPiece.SEG)
	var mats := [BuildPiece.Mat.WOOD, BuildPiece.Mat.METAL, BuildPiece.Mat.STONE, BuildPiece.Mat.EARTH]
	for k in 4:
		bm.request_place(BuildPiece.Kind.WALL, Vector3i(gx + k * 8, gy, gz), 0, mats[k])
	bm.request_place(BuildPiece.Kind.PILLAR, Vector3i(gx + 32, gy, gz), 0, BuildPiece.Mat.STONE)
	bm.request_place(BuildPiece.Kind.FLOOR, Vector3i(gx + 16, gy, gz - 8), 0, BuildPiece.Mat.STONE)
	var wall_mid := Vector3((gx + 16) * BuildPiece.SEG, gy * BuildPiece.SEG + 1.4, gz * BuildPiece.SEG)
	_view(wall_mid + Vector3(0.5, 3.6, 9.0), wall_mid + Vector3(0.5, -0.6, 0))
	await _shot("paredes_materiais", 30)
	_view(wall_mid + Vector3(2.0, 1.6, 4.2), wall_mid + Vector3(5.0, -0.4, 0))
	await _shot("paredes_pedra_taipa", 20)
	# Cubo de mira com a pá.
	player.set_physics_process(true)
	player.global_position = mid + Vector3(4.0, 1.0, 2.0)
	player.global_position.y = terrain.height_at(player.global_position.x, player.global_position.z) + 0.1
	for k in 20:
		await physics_frame
	player.rotation.y = 0.0
	player.head.rotation.x = -0.75
	player.inventory.add(&"pa")
	player.equip_item(&"pa")
	await _shot("terreno_mira_pa", 40)
	quit()
