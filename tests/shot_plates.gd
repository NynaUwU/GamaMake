extends SceneTree
## Fotos (SHOT=pasta): casinha de chapa (paredes, porta, telhado e piso de chapa) ao lado
## de uma parede de madeira, bancada de maçarico acesa, janela dela e o minigame de
## solda de cobre (chama do maçarico).

var main: Node3D
var player: Player
var placed: PlacedManager
var building: BuildingManager
var terrain: TerrainWorld


func _shot(name: String, frames := 30) -> void:
	for k in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/" + name + ".png")


func _look(from: Vector3, at: Vector3) -> void:
	player.global_position = from - Vector3(0, 1.6, 0)
	player.velocity = Vector3.ZERO
	await process_frame
	var to := at - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _put(kind: String, pos: Vector3, yaw := 0.0) -> PlacedObject:
	var id: int = placed._next_id
	placed._spawn(id, kind, Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, terrain.height_at(pos.x, pos.z), pos.z)), true)
	return placed.objects[id]


func _close_ui() -> void:
	for node in main.get_children():
		if node is StorageUI or node is Minigame:
			node.queue_free()
	player.ui_blocked = false
	await process_frame


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	main = current_scene
	player = main.player
	placed = main.get_node("Placed")
	building = main.get_node("Building")
	terrain = main.get_node("Terrain")
	for e in main.get_node("Enemies").get_children():
		e.free()
	var hud := main.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	Weather.i.target_rain = 0.0
	Weather.i.rain = 0.0
	Weather.i._timer = 99999.0
	DayNight.i.hour = 15.5
	DayNight.i._apply()
	Progress.i.manuals[&"manual_soldagem"] = true
	# Casinha de chapa: 2 x 1 paredes de largura, porta de chapa na frente.
	var base := player.global_position + Vector3(-34, 0, 22)
	var gy := int(round(terrain.height_at(base.x, base.z) / BuildPiece.SEG))
	var c := Vector3i(int(base.x / BuildPiece.SEG), gy, int(base.z / BuildPiece.SEG))
	var n := BuildPiece.N
	var front := building.host_apply("place", [BuildPiece.Kind.WALL, c + Vector3i(0, 0, n), 0, true])
	building.host_apply("place", [BuildPiece.Kind.WALL, c + Vector3i(n, 0, n), 0, true])
	building.host_apply("place", [BuildPiece.Kind.WALL, c, 0, true])
	building.host_apply("place", [BuildPiece.Kind.WALL, c + Vector3i(n, 0, 0), 0, true])
	building.host_apply("place", [BuildPiece.Kind.WALL, c, 1, true])
	building.host_apply("place", [BuildPiece.Kind.WALL, c + Vector3i(2 * n, 0, 0), 1, true])
	building.host_apply("place", [BuildPiece.Kind.FLOOR, c, 0, true])
	building.host_apply("place", [BuildPiece.Kind.FLOOR, c + Vector3i(n, 0, 0), 0, true])
	for k in 2:
		building.host_apply("place", [BuildPiece.Kind.ROOF, c + Vector3i(k * n, n, 0), 0, true])
	building.host_apply("place", [BuildPiece.Kind.PILLAR, c + Vector3i(2 * n + 2, 0, n + 2), 0, true])
	building.host_apply("place", [BuildPiece.Kind.WALL, c + Vector3i(2 * n + 4, 0, n), 0]) # madeira, para comparar
	var tris := PackedInt32Array()
	for j in range(0, 5):
		for i in range(2, 4):
			for q in 4:
				tris.append((j * n + i) * 4 + q)
	building.host_apply("cut_many", [front[0], tris])
	building.host_apply("fill", [front[0], "door", tris, true])
	var corner := Vector3(c) * BuildPiece.SEG
	var torch := _put("torch_bench", corner + Vector3(7.2, 0, 4.4))
	torch.extra.hot_until = placed.clock + 40.0
	for obj in placed.objects.values():
		obj.refresh(placed.clock)
	await _look(corner + Vector3(10.5, 5.0, 10.0), corner + Vector3(3.4, 1.6, 2.2))
	await _shot("casa_de_chapa", 40)
	await _look(corner + Vector3(7.4, 1.7, 6.3), corner + Vector3(7.2, 0.8, 4.4))
	await _shot("macarico_mundo", 20)
	# Janela do maçarico.
	var key := Smelting.key_of(torch)
	ContainerManager.i.host_apply("open", [key, ""])
	var slots: Array = ContainerManager.i.contents[key]
	slots[Smelting.INPUT] = {"id": &"cano", "amount": 6}
	slots[Smithing.ALLOY] = {"id": &"barra_estanho", "amount": 3}
	slots[Smithing.EXTRA_SLOT] = {"id": &"vidro", "amount": 4}
	slots[Smelting.FUEL] = {"id": &"botijao", "amount": 1}
	StorageUI.open_for(player, key, torch)
	await _shot("macarico_janela", 30)
	await _close_ui()
	# Minigame de solda de cobre.
	var weld := Minigame.play(player, "welding", {"item": &"serpentina", "seams": 2, "mode": "brazing"}, func(_q): pass) as WeldingMinigame
	weld.manual_input = false
	var dt := 1.0 / 60.0
	for k in 300:
		weld.drive(weld.point_at(weld.front + 60.0 * dt), true, dt)
	for k in 4:
		weld.drive(weld.point_at(weld.front + 60.0 * dt), true, dt)
		await process_frame
	await _shot("minigame_macarico", 1)
	weld.queue_free()
	await _close_ui()
	quit()
