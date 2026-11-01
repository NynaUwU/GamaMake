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
	var ramp_angle := deg_to_rad(float(OS.get_environment("RAMP")) if OS.get_environment("RAMP") != "" else 20.0)
	_box(Vector3(300, 30.0 * sin(ramp_angle) - 0.4 * cos(ramp_angle), -160.0 - 30.0 * cos(ramp_angle)), Vector3(10, 0.8, 60.0), Basis(Vector3.RIGHT, ramp_angle))
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
	car.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(300, 1.0, -145.0))
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.gear = 0
	for k in 60 * 12:
		await physics_frame
		if k % 60 == 0:
			print("  t=%d pos=%s v=%.1f g=%d" % [k / 60, car.global_position.snapped(Vector3.ONE * 0.1), car.linear_velocity.length() * 3.6, car.gear])
	# Parado no meio da rampa.
	var mid := Vector3(300, 0, -160.0 - 9.0 * cos(ramp_angle))
	mid.y = 9.0 * sin(ramp_angle) + 1.2
	car.global_transform = Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -ramp_angle), mid)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.gear = 0
	var shifts := 0
	var last_gear := 0
	var y0 := mid.y
	for k in 60 * 8:
		await physics_frame
		if car.gear != last_gear:
			shifts += 1
			last_gear = car.gear
		if OS.get_environment("DBG") != "" and k % 10 == 0:
			var wl := []
			for w in car.get_children():
				if w is VehicleWheel3D:
					wl.append("%s%.2f" % ["c" if w.is_in_contact() else "-", w.get_skidinfo()])
			print("  %.1fs v=%.1f ef=%.0f rpm=%.2f %s" % [k / 60.0, car.linear_velocity.length() * 3.6, car.engine_force, car.gear_rpm(car.linear_velocity.length()), " ".join(wl)])
	print("parado na rampa: subiu %.1f m em 8 s, trocas=%d, v=%.0f km/h" % [car.global_position.y - y0, shifts, car.linear_velocity.length() * 3.6])
	print("rampa %.0f°: topo em y=%.1f" % [rad_to_deg(ramp_angle), 60.0 * sin(ramp_angle)])
	quit()
