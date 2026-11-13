extends SceneTree
## Ré com a mesma força da 1ª marcha; queda de 3 m: as rodas não entram no chão.
var main: Node
var car: VintageCar
var player: Player


func _flat(t: float) -> void:
	for k in int(t * 60.0):
		await physics_frame


func _launch(dir: float) -> float:
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	await _flat(0.6)
	var start := car.global_position
	Input.action_press("move_forward" if dir > 0 else "move_back")
	await _flat(1.5)
	Input.action_release("move_forward" if dir > 0 else "move_back")
	var d := (car.global_position - start).dot(car.global_basis.z)
	var v := car.linear_velocity.dot(car.global_basis.z) * 3.6
	print("%s: 1,5 s -> %.1f m, %.1f km/h, marcha %d, força do motor no fim %.0f" % ["frente" if dir > 0 else "ré", d, v, car.gear, car.engine_force])
	Input.action_press("jump")
	await _flat(1.5)
	Input.action_release("jump")
	return absf(v)


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await physics_frame
	main = current_scene
	player = main.player
	car = main.get_node("Carro")
	for e in main.get_node("Enemies").get_children():
		e.detect_range = 0.0
	car.fuel = 1.0
	player.enter_vehicle(car)
	await _flat(0.5)
	var fwd := await _launch(1.0)
	var back := await _launch(-1.0)
	print("ré / frente = %.2f" % (back / maxf(fwd, 0.01)))
	print("gravidade do carro %.2f, mola máx %.0f N por roda" % [car.gravity_scale, car._wheels[0].suspension_max_force])
	# Queda de 3 m: menor folga da carroceria e das rodas até o chão durante o pouso.
	var ground: float = main.terrain.height_at(car.global_position.x, car.global_position.z) if main.get("terrain") else 0.0
	car.global_position += Vector3.UP * 3.0
	car.linear_velocity = Vector3.ZERO
	var low := 99.0
	var sunk := 0
	for k in 180:
		await physics_frame
		for w: VehicleWheel3D in car._wheels:
			var bottom := w.global_position.y - car.wheel_radius - car.suspension_rest
			var gy := ground
			if main.get("terrain"):
				gy = main.terrain.height_at(w.global_position.x, w.global_position.z)
			var hub := w.get_child(0) as Node3D
			var tire_bottom := hub.global_position.y - car.wheel_radius if hub else bottom
			low = minf(low, tire_bottom - gy)
			if tire_bottom - gy < -0.08:
				sunk += 1
	print("queda de 3 m: menor folga do pneu ao chão %.2f m, quadros com pneu enterrado (>8 cm) %d, rodas no chão %d" % [low, sunk,
		car._wheels.filter(func(w): return w.is_in_contact()).size()])
	quit()
