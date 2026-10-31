class_name HallScottCar
extends VintageCar
## Inspirado num especial de 1917 com motor de avião Hall-Scott de 4 cilindros:
## alto e estreito, radiador de latão reto, capô comprido com os quatro
## cilindros gigantes furando a tampa, escapamentos laterais e tanque redondo
## atrás. Muita força no arranque que acaba cedo: bom para subir morro, ruim de
## velocidade final.

const CREAM := Color(0.74, 0.68, 0.52)
const BRASS := Color(0.55, 0.45, 0.22)


func _configure() -> void:
	# Dirige igual ao primeiro carro (VintageCar): só torque e velocidade são dele.
	wheelbase = 2.8
	track_width = 1.36
	wheel_radius = 0.47
	wheel_style = "wood"
	max_engine_force = 4000.0
	top_speed = 35.0 # ~125 km/h
	speedo_max = 140.0
	torque_low = 1.0
	torque_peak = 0.12
	torque_high = 0.45
	seat_offset = Vector3(-0.23, 0.45, -0.6)
	exit_offset = Vector3(-1.35, 0.3, -0.6)
	wheel_center = Vector3(-0.23, 0.98, -0.22)
	wheel_tilt = 0.8
	column_base = Vector3(-0.23, 0.7, 0.2)
	gauge_pos = Vector3(0.0, 0.86, 0.035)
	collision_boxes = [[Vector3(0.9, 0.6, 3.9), Vector3(0, 0.45, -0.1)], [Vector3(0.7, 0.4, 1.7), Vector3(0, 0.9, 0.95)]]
	bumper_size = Vector3(1.6, 1.6, 4.6)


func _build_body(model: Node3D) -> void:
	var paint := MeshBuilder.new()
	var lining := MeshBuilder.new()
	var dark := MeshBuilder.new()
	var brass := MeshBuilder.new()
	var leather := MeshBuilder.new()
	var floor_y := 0.22
	# Capô comprido e estreito, quase quadrado.
	_hull(paint, [[1.85, 0.68, 0.33, 0.3, 4.0], [1.0, 0.7, 0.36, 0.32, 4.0], [0.05, 0.7, 0.4, 0.32, 4.0]], floor_y)
	for i in 4: # cilindros furando a tampa
		var z := 1.6 - i * 0.42
		dark.tube(PackedVector3Array([Vector3(0, 0.9, z), Vector3(0, 1.2, z)]), 0.13, 8)
		for k in 4:
			dark.tube(PackedVector3Array([Vector3(0, 0.95 + k * 0.06, z), Vector3(0, 0.97 + k * 0.06, z)]), 0.16, 8)
		dark.box(Vector3(0, 1.24, z), Vector3(0.24, 0.07, 0.3))
		dark.tube(PackedVector3Array([Vector3(-0.12, 1.1, z), Vector3(-0.42, 1.05, z - 0.04), Vector3(-0.5, 0.75, z - 0.1)]), 0.04, 5)
	dark.tube(PackedVector3Array([Vector3(-0.5, 0.75, 1.5), Vector3(-0.5, 0.6, 0.0), Vector3(-0.48, 0.5, -1.9)]), 0.06, 6) # coletor até atrás
	# Radiador de latão alto.
	brass.box(Vector3(0, 0.7, 1.95), Vector3(0.7, 0.78, 0.1))
	dark.box(Vector3(0, 0.68, 2.005), Vector3(0.56, 0.62, 0.02))
	brass.lathe(PackedVector2Array([Vector2(0.04, 0.0), Vector2(0.04, 0.05), Vector2(0.02, 0.08)]), 8, Basis.IDENTITY, Vector3(0, 1.09, 1.95))
	# Cockpit e tanque cilíndrico deitado atrás.
	_tub(paint, lining, 0.05, -1.05, 0.62, 0.45, 0.36, floor_y)
	_hull(brass, [[-1.15, 0.72, 0.26, 0.26, 2.0], [-1.2, 0.72, 0.3, 0.3, 2.0], [-1.9, 0.72, 0.3, 0.3, 2.0], [-1.95, 0.72, 0.26, 0.26, 2.0]], -INF, 12)
	# Estribos e para-lamas de chapa.
	for side in [-1.0, 1.0]:
		paint.box(Vector3(side * 0.55, 0.22, 0.0), Vector3(0.24, 0.03, 1.4))
		for z in [wheelbase * 0.5, -wheelbase * 0.5]:
			var grid := []
			for r in 9:
				var a := lerpf(-1.0, 1.0, r / 8.0)
				var row := PackedVector3Array()
				for c in 4:
					var u := lerpf(-1.0, 1.0, c / 3.0)
					row.append(Vector3(side * (track_width * 0.5 + u * 0.14), 0.1 + cos(a) * 0.58, z + sin(a) * 0.58))
				grid.append(row)
			paint.sheet(grid)
	for z in [wheelbase * 0.5, -wheelbase * 0.5]:
		dark.tube(PackedVector3Array([Vector3(-track_width * 0.5, 0.1, z), Vector3(track_width * 0.5, 0.1, z)]), 0.04, 6)
	# Faróis grandes de latão em cima dos para-lamas.
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 0.5, 0.92, 1.85)
		brass.lathe(PackedVector2Array([Vector2(0.02, -0.12), Vector2(0.1, -0.1), Vector2(0.13, -0.04), Vector2(0.13, 0.03)]), 12,
				Basis(Vector3.RIGHT, PI / 2), at)
		_headlight_points.append(at + Vector3(0, 0, 0.05))
		leather.box(Vector3(side * 0.23, 0.7, -0.6), Vector3(0.34, 0.1, 0.42))
		leather.box(Vector3(side * 0.23, 0.95, -0.85), Vector3(0.34, 0.42, 0.08), Basis(Vector3.RIGHT, -0.2))
	_add(model, paint.finish(_material("paint", CREAM, 0.85, 0.05, true)))
	_add(model, lining.finish(_material("interior", Color(0.16, 0.1, 0.07), 0.9, 0.0, true)))
	_add(model, dark.finish(_material("dark", DARK, 0.7, 0.3), false))
	_add(model, brass.finish(_material("brass", BRASS, 0.6, 0.4)))
	_add(model, leather.finish(_material("leather", LEATHER, 0.75, 0.0), false))


func _build_dash(model: Node3D) -> void:
	_plate_dash(model, 0.05, 0.62, 1.0, 0.4, Color(0.35, 0.24, 0.14))
