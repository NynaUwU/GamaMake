extends SceneTree
## Fotos da fase 2 das eras (SHOT=pasta): fundição e bancada de solda no mundo, veio de
## estanho, janela da fundição, minigame de despejar (3D) e minigame de solda.

var main: Node3D
var player: Player
var placed: PlacedManager
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
		if node is StorageUI or node is JournalUI or node is Minigame:
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
	terrain = main.get_node("Terrain")
	for e in main.get_node("Enemies").get_children():
		e.free()
	var hud := main.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	Weather.i.target_rain = 0.0
	Weather.i.rain = 0.0
	Weather.i._timer = 99999.0
	DayNight.i.hour = 16.6
	DayNight.i._apply()
	var o := player.global_position + Vector3(-36, 0, 26)
	var foundry := _put("foundry", o)
	foundry.extra.hot_until = placed.clock + 30.0
	var bench := _put("weld_bench", o + Vector3(3.0, 0, 0.4))
	bench.extra.hot_until = placed.clock + 30.0
	var battery := _put("battery", o + Vector3(4.6, 0, -0.8))
	battery.extra.cells = 3
	battery.extra.charge = 600.0
	placed.host_apply("cable", [battery.net_id, bench.net_id])
	for k in 2:
		placed._electric()
	for obj in placed.objects.values():
		obj.refresh(placed.clock)
	await _look(o + Vector3(1.2, 1.7, 3.0), o + Vector3(0.1, 0.6, 0))
	await _shot("fundicao_mundo", 40)
	await _look(o + Vector3(3.8, 1.75, 2.4), o + Vector3(2.9, 0.85, 0.3))
	await _shot("solda_mundo", 20)
	# Janela da fundição com o bronze pronto para fundir.
	var key := Smelting.key_of(foundry)
	ContainerManager.i.host_apply("open", [key, ""])
	var slots: Array = ContainerManager.i.contents[key]
	slots[Smelting.INPUT] = {"id": &"barra_cobre", "amount": 6}
	slots[Smithing.ALLOY] = {"id": &"barra_estanho", "amount": 2}
	slots[Smelting.FUEL] = {"id": &"carvao", "amount": 5}
	StorageUI.open_for(player, key, foundry)
	await _shot("fundicao_janela", 30)
	await _close_ui()
	# Minigame de despejar: no meio do despejo, com a vazão na faixa.
	var cast := Minigame.play(player, "casting", {"item": &"barra_bronze", "metal": &"barra_bronze", "mold": "ingot"}, func(_q): pass) as CastingMinigame
	cast.manual_input = false
	for k in 140:
		cast.target_tilt = cast.lip_angle() + 7.5 if cast.fill < 0.55 else cast.lip_angle() + 7.5
		cast.step(1.0 / 30.0)
		if cast.fill >= 0.55:
			break
	for k in 6:
		cast.target_tilt = cast.lip_angle() + 7.5
		await process_frame
	await _shot("minigame_fundicao", 1)
	cast.target_tilt = 120.0
	for k in 20:
		cast.step(1.0 / 30.0)
	await _shot("minigame_fundicao_espirra", 2)
	cast.queue_free()
	await _close_ui()
	# Minigame de solda: no meio do 1º cordão com o arco aceso.
	var weld := Minigame.play(player, "welding", {"item": &"couraca", "seams": 3}, func(_q): pass) as WeldingMinigame
	weld.manual_input = false
	var dt := 1.0 / 60.0
	for k in 220:
		weld.drive(weld.point_at(weld.front + (80.0 if k < 150 else 200.0) * dt), true, dt)
	for k in 4:
		weld.drive(weld.point_at(weld.front + 80.0 * dt), true, dt)
		await process_frame
	await _shot("minigame_solda", 1)
	weld.drive(weld.tip, false, dt)
	await _shot("minigame_solda_cordao", 3)
	weld.queue_free()
	await _close_ui()
	quit()
