extends SceneTree
var car: VintageCar
func _box(pos: Vector3, size: Vector3, basis := Basis()) -> void:
	var b := StaticBody3D.new()
	var s := CollisionShape3D.new()
	s.shape = BoxShape3D.new()
	s.shape.size = size
	b.add_child(s)
	get_root().add_child(b)
	b.global_transform = Transform3D(basis, pos)
func _init() -> void:
	await process_frame
	_box(Vector3(0, -0.5, 0), Vector3(800, 1, 800))
	var ramp_angle := deg_to_rad(20.0)
	_box(Vector3(0, 10.0 * sin(ramp_angle) - 0.4, -160.0 - 10.0 * cos(ramp_angle)), Vector3(10, 0.8, 20.0), Basis(Vector3.RIGHT, ramp_angle))
	car = load("res://scenes/vehicles/vintage_car.tscn").instantiate()
	get_root().add_child(car)
	car.global_position = Vector3(0, 1.0, 0)
	car.rotation.y = PI # anda para -Z
	var dummy := Node3D.new()
	get_root().add_child(dummy)
	car.driver = dummy
	for k in 30:
		await physics_frame
	Input.action_press("move_forward")
	var gears := []
	for k in 60 * 10:
		await physics_frame
		if gears.is_empty() or gears[-1][0] != car.gear:
			gears.append([car.gear, snappedf(car.linear_velocity.length() * 3.6, 1)])
	print("trocas (marcha, km/h): ", gears)
	# Curva fechada em alta
	var speed_before := car.linear_velocity.length() * 3.6
	Input.action_press("move_left")
	var max_tilt := 0.0
	var max_slip := 0.0
	for k in 60 * 4:
		await physics_frame
		max_tilt = maxf(max_tilt, rad_to_deg(acos(clampf(car.global_basis.y.dot(Vector3.UP), -1, 1))))
		var flat := car.linear_velocity
		flat.y = 0
		if flat.length() > 3.0:
			max_slip = maxf(max_slip, rad_to_deg(absf((car.global_basis.z).signed_angle_to(flat, Vector3.UP))))
	print("curva a %.0f km/h: inclinação máx %.0f°, derrapagem máx %.0f°, tombou=%s" % [speed_before, max_tilt, max_slip, car.is_tipped()])
	Input.action_release("move_left")
	# Rampa de 20° saindo parado
	car.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.0, -145.0))
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.gear = 0
	for k in 60 * 8:
		await physics_frame
		if k % 60 == 0:
			print("  t=%d pos=%s v=%.1f g=%d" % [k / 60, car.global_position.snapped(Vector3.ONE * 0.1), car.linear_velocity.length() * 3.6, car.gear])
	print("rampa 20°: subiu até y=%.1f (topo ~6.8), marcha=%d" % [car.global_position.y, car.gear])
	quit()
