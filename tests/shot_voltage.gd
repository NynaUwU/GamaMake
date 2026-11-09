extends SceneTree
## Fotos da fase 3 (SHOT=pasta): banco de baterias de 110 V, carregador e inversor
## ligados por cabo (dínamo -> carregador -> bateria de 12 V; painel -> inversor ->
## bancada de solda) e o inversor queimado de sobrecarga.

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
	DayNight.i.hour = 13.0
	DayNight.i._apply()
	var o := player.global_position + Vector3(-36, 0, 26)
	# Banco de 110 V alimentando a bancada de solda.
	var bank := _put("battery_bank", o)
	bank.extra.cells = 9
	bank.extra.charge = 1800.0
	var bench := _put("weld_bench", o + Vector3(2.4, 0, -0.4))
	placed.host_apply("cable", [bank.net_id, bench.net_id])
	# Painel solar + bateria de 12 V -> inversor -> lâmpada de 110 V (bivolt).
	var solar := _put("solar_panel", o + Vector3(-2.6, 0, 2.6))
	var battery := _put("battery", o + Vector3(-1.0, 0, 2.6))
	battery.extra.cells = 4
	battery.extra.charge = 900.0
	var inverter := _put("inverter", o + Vector3(0.6, 0, 2.6))
	var charger := _put("charger", o + Vector3(1.6, 0, 3.6))
	var battery2 := _put("battery", o + Vector3(3.0, 0, 3.6))
	battery2.extra.cells = 2
	battery2.extra.charge = 100.0
	var lamp := _put("lamp", o + Vector3(2.0, 0, 2.2))
	placed.host_apply("cable", [solar.net_id, battery.net_id])
	placed.host_apply("cable", [battery.net_id, inverter.net_id])
	placed.host_apply("cable", [inverter.net_id, lamp.net_id])
	placed.host_apply("cable", [lamp.net_id, charger.net_id])
	placed.host_apply("cable", [charger.net_id, battery2.net_id])
	for k in 4:
		placed._power()
		placed._electric()
	for obj in placed.objects.values():
		obj.refresh(placed.clock)
	print("inversor %s, carregador %s, bancada %s, lâmpada %s" % [inverter.extra.get("status", ""), charger.extra.get("status", ""), Electric.powered(bench), Electric.powered(lamp)])
	await _look(o + Vector3(0.4, 1.9, 6.2), o + Vector3(0.3, 0.5, 1.4))
	await _shot("rede_12_110", 40)
	await _look(o + Vector3(0.9, 1.25, 4.0), o + Vector3(0.9, 0.45, 2.9))
	await _shot("inversor_carregador", 20)
	await _look(o + Vector3(0.6, 1.6, 2.0), o + Vector3(0.6, 0.4, -0.2))
	await _shot("banco_110v", 20)
	quit()
