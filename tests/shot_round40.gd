extends SceneTree
## Fotos da rodada 40 (SHOT=pasta): casa com telhado de duas águas inclinado, vigas
## deitadas emendadas, tocha na mão esquerda, inventário com a mão secundária e as
## receitas da fornalha.
func _shot(name: String) -> void:
	for k in 25:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/" + name + ".png")


func _look(player: Player, from: Vector3, at: Vector3) -> void:
	player.global_position = from - Vector3(0, 1.6, 0)
	await process_frame
	var to := at - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	var main := current_scene
	var player: Player = main.player
	var bm: BuildingManager = main.get_node("Building")
	var terrain: TerrainWorld = main.get_node("Terrain")
	for e in main.get_node("Enemies").get_children():
		e.free()
	var cx := 55
	var cz := 30
	var cy := floori(terrain.height_at(cx * 0.4 + 2.8, cz * 0.4 + 2.8) / 0.4)
	for k in 2:
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx + 7 * k, cy, cz), 0])
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx + 7 * k, cy, cz + 14), 0])
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx, cy, cz + 7 * k), 1])
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx + 14, cy, cz + 7 * k), 1])
		bm.host_apply("place", [BuildPiece.Kind.ROOF, Vector3i(cx + 7 * k, cy + 7, cz), 2]) # sobe para +Z
		bm.host_apply("place", [BuildPiece.Kind.ROOF, Vector3i(cx + 7 * k, cy + 7, cz + 7), 4]) # sobe para -Z
	# Pórtico: dois pilares em pé e duas vigas deitadas emendadas em cima.
	var bx := cx + 22
	var by := floori(terrain.height_at((bx + 7) * 0.4, cz * 0.4) / 0.4) + 1
	print("pilar ", bm.host_apply("place", [BuildPiece.Kind.PILLAR, Vector3i(bx, by, cz), 0]))
	print("pilar ", bm.host_apply("place", [BuildPiece.Kind.PILLAR, Vector3i(bx + 14, by, cz), 0]))
	print("viga ", bm.host_apply("place", [BuildPiece.Kind.PILLAR, Vector3i(bx, by + 7, cz), 1]))
	print("viga ", bm.host_apply("place", [BuildPiece.Kind.PILLAR, Vector3i(bx + 7, by + 7, cz), 1]))
	var gate := Vector3((bx + 7) * 0.4, (by + 4) * 0.4, cz * 0.4)
	var house := Vector3((cx + 7) * 0.4, cy * 0.4, (cz + 7) * 0.4)
	await _look(player, house + Vector3(-7.5, 3.2, -6.0), house + Vector3(0, 2.0, 0))
	await _shot("telhado_inclinado")
	await _look(player, gate + Vector3(1.0, 0.6, -6.5), gate)
	await _shot("vigas")
	# Tocha na mão esquerda (mão secundária) + espada na direita.
	player.inventory.add(&"tocha", 1)
	player.inventory.equip_from(Cooking.find_any(player.inventory, {&"tocha": true}), "offhand")
	if DayNight.i:
		DayNight.i.hour = 21.5
	await _look(player, house + Vector3(1.5, 1.6, 1.5), house + Vector3(1.5, 1.3, -3.0))
	await _shot("tocha_mao_esquerda")
	if DayNight.i:
		DayNight.i.hour = 12.0
	var inv := main.get_node("HUD/Root/InventoryUI")
	inv._set_open(true)
	await _shot("inventario_mao_secundaria")
	inv._set_open(false)
	var placed: PlacedManager = main.get_node("Placed")
	var r := placed.host_apply("place", ["furnace", Transform3D(Basis(), house + Vector3(0, 0.2, 0))])
	player.inventory.add(&"areia", 4)
	player.inventory.add(&"minerio_cobre", 6)
	player.ui_blocked = false
	StorageUI.open_for(player, Smelting.key_of(placed.objects[r[0]]), placed.objects[r[0]])
	await _shot("fornalha_receitas")
	quit()
