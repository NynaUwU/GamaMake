class_name DarracqV8Car
extends VintageCar
## Inspirado no Darracq V8 de recorde (1905): quase só um chassi de longarinas,
## um V8 enorme à mostra na frente, radiador de latão e dois bancos de lata
## lá atrás. Levíssimo e rápido, mas o motor só "acorda" com giro e os pneus
## finos fazem a direção ficar nervosa.

const BLUE := Color(0.13, 0.18, 0.33)
const BRASS := Color(0.55, 0.45, 0.22)


func _configure() -> void:
	wheelbase = 2.35
	track_width = 1.3
	wheel_radius = 0.44
	wheel_style = "wood"
	car_mass = 850.0
	roll_influence = 0.1
	center_of_mass_y = 0.05
	max_engine_force = 4000.0
	top_speed = 50.0 # ~180 km/h
	speedo_max = 200.0
	torque_low = 0.5 # fraco embaixo...
	torque_peak = 0.55 # ...e bravo no meio
	torque_high = 0.8
	front_grip = 1.9
	rear_grip = 1.8
	wheelspin = 0.28
	max_steer = 0.62
	steer_min = 0.12
	steer_rate = 4.2 # direção rápida e nervosa
	max_brake = 22.0 # freio só atrás, fraco
	seat_offset = Vector3(-0.24, 0.32, -0.62)
	exit_offset = Vector3(-1.3, 0.3, -0.62)
	eye_height = 0.78
	wheel_center = Vector3(-0.24, 0.92, -0.22)
	wheel_tilt = 0.95
	wheel_size = 0.19
	column_base = Vector3(-0.24, 0.5, 0.35)
	gauge_pos = Vector3(0.0, 0.62, 0.09)
	collision_boxes = [[Vector3(0.9, 0.45, 3.2), Vector3(0, 0.35, -0.05)], [Vector3(0.7, 0.4, 1.0), Vector3(0, 0.75, 0.75)]]
	bumper_size = Vector3(1.5, 1.4, 3.9)


func _build_body(model: Node3D) -> void:
	var paint := MeshBuilder.new()
	var dark := MeshBuilder.new()
	var brass := MeshBuilder.new()
	var leather := MeshBuilder.new()
	# Chassi de longarinas e travessas, todo à mostra.
	for side in [-1.0, 1.0]:
		paint.box(Vector3(side * 0.34, 0.22, 0.0), Vector3(0.06, 0.12, 3.3))
	for z in [1.5, 0.3, -0.9, -1.55]:
		paint.box(Vector3(0, 0.22, z), Vector3(0.68, 0.08, 0.06))
	# V8 em pé: cárter, duas fileiras de 4 cilindros grandes e coletor no meio.
	dark.box(Vector3(0, 0.36, 0.85), Vector3(0.44, 0.22, 1.1))
	for side in [-1.0, 1.0]:
		_cylinders(dark, Vector3(side * 0.12, 0.45, 1.3), 4, 0.27, 0.085, 0.32, -side * 0.45)
		for i in 4: # escapamento curto de cada cilindro
			var z := 1.3 - i * 0.27
			dark.tube(PackedVector3Array([Vector3(side * 0.34, 0.75, z), Vector3(side * 0.48, 0.72, z), Vector3(side * 0.52, 0.6, z - 0.05)]), 0.03, 5)
	brass.tube(PackedVector3Array([Vector3(0, 0.82, 1.4), Vector3(0, 0.86, 0.95), Vector3(0, 0.82, 0.45)]), 0.04, 6)
	# Radiador de latão com favo e tampa.
	brass.box(Vector3(0, 0.62, 1.68), Vector3(0.64, 0.66, 0.1))
	dark.box(Vector3(0, 0.6, 1.735), Vector3(0.52, 0.52, 0.02))
	brass.lathe(PackedVector2Array([Vector2(0.035, 0.0), Vector2(0.035, 0.05), Vector2(0.02, 0.07)]), 8, Basis.IDENTITY, Vector3(0, 0.95, 1.68))
	# Parede corta-fogo de madeira e dois bancos de lata atrás.
	paint.box(Vector3(0, 0.5, 0.12), Vector3(0.72, 0.45, 0.04))
	for side in [-1.0, 1.0]:
		var seat := []
		for k in 3:
			seat.append(MeshBuilder.ring(Vector3(side * 0.24, 0.52 + k * 0.14, -0.66 - k * 0.02), 0.18 + k * 0.01, 0.16, 2.0, 10,
					-INF, PI * 0.9, PI * 2.1))
		paint.loft(seat, false)
		leather.box(Vector3(side * 0.24, 0.44, -0.6), Vector3(0.32, 0.08, 0.36))
	# Tanque de combustível redondo e estepe atrás.
	_hull(brass, [[-1.0, 0.5, 0.22, 0.22, 2.0], [-1.05, 0.5, 0.26, 0.26, 2.0], [-1.5, 0.5, 0.26, 0.26, 2.0], [-1.55, 0.5, 0.22, 0.22, 2.0]], -INF, 12)
	# Eixos e para-lamas mínimos (só na frente).
	for z in [wheelbase * 0.5, -wheelbase * 0.5]:
		dark.tube(PackedVector3Array([Vector3(-track_width * 0.5, 0.1, z), Vector3(track_width * 0.5, 0.1, z)]), 0.035, 6)
	for side in [-1.0, 1.0]:
		var grid := []
		for r in 7:
			var a := lerpf(-0.4, 1.1, r / 6.0)
			var row := PackedVector3Array()
			for c in 3:
				var u := lerpf(-1.0, 1.0, c / 2.0)
				row.append(Vector3(side * (track_width * 0.5 + u * 0.1), 0.1 + cos(a) * 0.54, wheelbase * 0.5 + sin(a) * 0.54))
			grid.append(row)
		paint.sheet(grid)
		# Lampião de acetileno.
		var at := Vector3(side * 0.45, 0.8, 1.6)
		brass.lathe(PackedVector2Array([Vector2(0.02, -0.1), Vector2(0.08, -0.08), Vector2(0.1, -0.02), Vector2(0.1, 0.02)]), 10,
				Basis(Vector3.RIGHT, PI / 2), at)
		_headlight_points.append(at + Vector3(0, 0, 0.04))
	_add(model, paint.finish(_material("paint", BLUE, 0.85, 0.1, true)))
	_add(model, dark.finish(_material("dark", DARK, 0.7, 0.3), false))
	_add(model, brass.finish(_material("brass", BRASS, 0.6, 0.4)))
	_add(model, leather.finish(_material("leather", LEATHER, 0.75, 0.0), false))


func _build_dash(model: Node3D) -> void:
	pass # sem painel: o velocímetro fica preso na parede corta-fogo
