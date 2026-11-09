extends SceneTree
## Fotos de perto da elétrica v2 (SHOT=pasta): assador giratório com motor, moinho e
## pedra de amolar com motor, bateria com células, mostrador do dínamo, interruptor
## de pedestal e de parede, isoladores com o cabo esticado.

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


func _put(kind: String, pos: Vector3, basis := Basis()) -> PlacedObject:
	var id: int = placed._next_id
	placed._spawn(id, kind, Transform3D(basis, Vector3(pos.x, terrain.height_at(pos.x, pos.z), pos.z) if basis == Basis() else pos), true)
	return placed.objects[id]


func _motor_on(machine: PlacedObject, battery: PlacedObject) -> PlacedObject:
	var p: Array = Power.world_ports(machine)[0]
	var id: int = placed._next_id
	placed._spawn(id, "electric_motor", Transform3D(Basis(p[1], Vector3.UP, p[1].cross(Vector3.UP)), p[0]), true)
	placed.host_apply("cable", [id, battery.net_id])
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
	var o := player.global_position + Vector3(-40, 0, 30)
	var battery := _put("battery", o)
	battery.extra.cells = 4
	battery.extra.charge = 420.0
	var solar := _put("solar_panel", o + Vector3(-1.8, 0, 0.6), Basis())
	placed.host_apply("cable", [solar.net_id, battery.net_id])
	var rot := _put("rotisserie", o + Vector3(3.0, 0, 0))
	rot.extra.fuel_until = placed.clock + 9999.0
	_motor_on(rot, battery)
	var quern := _put("quern", o + Vector3(3.0, 0, 3.0))
	quern.extra["in"] = 30
	_motor_on(quern, battery)
	var grind := _put("grindstone", o + Vector3(0.6, 0, 3.6))
	grind.extra.tool = {"id": "espada", "dur": 0.8, "sharp": 0.3}
	_motor_on(grind, battery)
	var wheel_dynamo := _put("dynamo", o + Vector3(-1.4, 0, -2.4))
	wheel_dynamo.extra.gauge = 0.65
	var sw := _put("switch", o + Vector3(1.2, 0, -1.6), Basis())
	var lamp := _put("lamp", o + Vector3(2.6, 0, -2.6))
	placed.host_apply("cable", [battery.net_id, sw.net_id])
	placed.host_apply("cable", [sw.net_id, lamp.net_id])
	for k in 4:
		placed._power()
		placed._electric()
		placed._power()
	for k in 4:
		rot.crops[k] = Cooking.make_entry("rotisserie", [&"carne_crua", &"batata", &"carne_crua", &"cenoura"][k], placed.clock - 25.0 * (k % 2))
	for obj in placed.objects.values():
		obj.refresh(placed.clock)
	DayNight.i.hour = 16.8
	DayNight.i._apply()
	await _look(o + Vector3(4.8, 1.5, -2.2), o + Vector3(2.6, 0.5, 0.6))
	await _shot("assador_motor", 40)
	await _look(o + Vector3(-1.0, 1.4, 1.2), o + Vector3(2.4, 0.6, 3.4))
	await _shot("moinho_amolar_motor", 30)
	await _look(o + Vector3(0.4, 1.3, -3.4), o + Vector3(0.0, 0.7, -0.4))
	await _shot("bateria_interruptor_dinamo", 30)
	quit()
