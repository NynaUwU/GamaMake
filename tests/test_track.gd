extends SceneTree
## Pista: o carro voa na lombada e na rampa do atalho e passa pela ponte sem cair.
var main: Node
var terrain: TerrainWorld
var frame := 0
var runs := [
	# [nome, ponto local, direção local, velocidade m/s, segundos]
	["lombada", Vector2(-120, -85), Vector2(1, 0), 30.0, 4.0],
	["ponte", Vector2(31, 21), Vector2(-1.4, -1), 14.0, 3.5],
	["rampa atalho", Vector2(44, 28), Vector2(0.15, -1), 20.0, 3.5],
	["rampa curva", Vector2(204, 36), Vector2(0.04, -1), 20.0, 3.5],
]
var run := -1
var car: VintageCar
var start := 0
var air := 0
var max_air := 0
var min_y := INF
var min_up := 1.0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		terrain = main.get_node("Terrain")
		for e in main.get_node("Enemies").get_children(): e.queue_free()
		_next()
	if car and frame > start:
		var contact := car.get_children().filter(func(w): return w is VehicleWheel3D and w.is_in_contact()).size()
		air = air + 1 if contact == 0 else 0
		max_air = maxi(max_air, air)
		min_y = minf(min_y, car.global_position.y - terrain.track.base)
		min_up = minf(min_up, car.global_basis.y.dot(Vector3.UP))
		if run == int(OS.get_environment("TRACE_RUN")) and (frame - start) % 10 == 0:
			var l := RaceTrack.to_local(terrain.track, Vector2(car.global_position.x, car.global_position.z))
			print("  trace t=", frame - start, " local=", l.snapped(Vector2.ONE * 0.1), " y=", snappedf(car.global_position.y - terrain.track.base, 0.1), " contato=", contact, " built=", main.has_node("RaceTrack"))
		if frame - start > runs[run][4] * 60:
			print("%s: maior tempo no ar=%.2f s, menor altura=%.1f, menor up=%.2f, vel final=%d km/h" % [runs[run][0], max_air / 60.0, min_y, min_up, car.linear_velocity.length() * 3.6])
			car.queue_free()
			car = null
			_next()
	return false

func _next() -> void:
	run += 1
	Input.action_release("move_forward")
	if run >= runs.size():
		quit()
		return
	var r: Array = runs[run]
	var tr: Dictionary = terrain.track
	var p: Vector2 = RaceTrack.to_world(tr, r[1])
	var dir: Vector2 = Vector2(r[2]).normalized().rotated(tr.yaw)
	terrain.update_around(Vector3(p.x, 0, p.y), -1, 140.0)
	main.get_node("Player").global_position = Vector3(p.x, terrain.height_at(p.x, p.y) + 30.0, p.y)
	for i in 60: # espera a pista (muretas, ponte, rampas) ser montada
		await physics_frame
	car = load("res://scripts/vehicles/vintage_car.gd").new()
	main.add_child(car)
	car.global_position = Vector3(p.x, terrain.height_at(p.x, p.y) + 0.6, p.y)
	car.rotation.y = atan2(dir.x, dir.y)
	car.linear_velocity = Vector3(dir.x, 0, dir.y) * r[3]
	car.set_driver(Node3D.new())
	Input.action_press("move_forward")
	start = frame + 2
	air = 0
	max_air = 0
	min_y = INF
	min_up = 1.0
