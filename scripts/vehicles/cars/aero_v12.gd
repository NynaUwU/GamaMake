class_name AeroV12Car
extends VintageCar
## Especial feito à mão em volta de um V12 de avião: capô comprido e aberto
## com as duas fileiras de cilindros à mostra, radiador grande, cockpit lá
## atrás e rabo de barco. Pesado e muito forte em velocidade; arranca
## patinando um pouco e é lento para virar (entre-eixos enorme).

const GREEN := Color(0.16, 0.24, 0.17)
const BRASS := Color(0.7, 0.55, 0.25)


func _configure() -> void:
	# Dirige igual ao primeiro carro (VintageCar): só torque e velocidade são dele.
	wheelbase = 3.3
	track_width = 1.46
	wheel_radius = 0.45
	max_engine_force = 5600.0
	top_speed = 50.0 # ~180 km/h
	speedo_max = 200.0
	torque_low = 0.8
	torque_peak = 0.3
	torque_high = 0.75
	seat_offset = Vector3(-0.22, 0.3, -0.75)
	exit_offset = Vector3(-1.4, 0.2, -0.75)
	wheel_center = Vector3(-0.22, 0.8, -0.3)
	column_base = Vector3(-0.22, 0.6, -0.05)
	gauge_pos = Vector3(0.0, 0.7, -0.17)
	collision_boxes = [[Vector3(1.0, 0.6, 4.7), Vector3(0, 0.4, -0.1)], [Vector3(0.9, 0.35, 2.0), Vector3(0, 0.75, 1.15)]]
	bumper_size = Vector3(1.7, 1.4, 5.6)


func _build_body(model: Node3D) -> void:
	var paint := MeshBuilder.new()
	var lining := MeshBuilder.new()
	var dark := MeshBuilder.new()
	var chrome := MeshBuilder.new()
	var leather := MeshBuilder.new()
	# Laterais do capô (sem tampa: só a "bacia" embaixo do motor).
	var shell := []
	for s in [[2.25, 0.46, 0.4, 0.28], [1.4, 0.48, 0.46, 0.3], [0.3, 0.48, 0.48, 0.3], [-0.2, 0.47, 0.48, 0.3]]:
		shell.append(MeshBuilder.ring(Vector3(0, s[1], s[0]), s[2], s[3], 3.0, 16, FLOOR_Y, PI * 0.85, PI * 2.15))
	shell.reverse()
	paint.loft(shell, false)
	# V12 de avião: bloco, duas fileiras de 6 cilindros em V, coletores.
	dark.box(Vector3(0, 0.6, 1.15), Vector3(0.42, 0.3, 2.0))
	for side in [-1.0, 1.0]:
		_cylinders(dark, Vector3(side * 0.12, 0.7, 2.0), 6, 0.33, 0.07, 0.2, -side * 0.55)
		for i in 6:
			var z := 2.0 - i * 0.33
			chrome.tube(PackedVector3Array([Vector3(side * 0.33, 0.86, z), Vector3(side * 0.55, 0.9, z - 0.06)]), 0.03, 5)
		dark.tube(PackedVector3Array([Vector3(side * 0.42, 0.5, 0.1), Vector3(side * 0.5, 0.36, -0.6),
			Vector3(side * 0.5, 0.32, -2.1)]), 0.04, 6)
	# Hélice-cubo vira enfeite na frente do bloco; radiador grande na ponta.
	chrome.box(Vector3(0, 0.55, 2.32), Vector3(0.72, 0.7, 0.08))
	dark.box(Vector3(0, 0.55, 2.37), Vector3(0.6, 0.58, 0.02))
	for i in 6:
		chrome.box(Vector3(-0.25 + i * 0.1, 0.55, 2.385), Vector3(0.012, 0.56, 0.01))
	# Cockpit e rabo de barco.
	_tub(paint, lining, -0.2, -1.2, 0.45, 0.48, 0.28, FLOOR_Y)
	_hull(paint, [[-1.2, 0.46, 0.48, 0.3, 3.0], [-1.7, 0.45, 0.44, 0.28, 3.0], [-2.2, 0.42, 0.32, 0.22, 2.8],
		[-2.55, 0.38, 0.16, 0.13, 2.4], [-2.7, 0.35, 0.05, 0.05, 2.2]])
	# Encosto de cabeça aerodinâmico atrás do motorista.
	_hull(paint, [[-1.1, 0.78, 0.12, 0.1, 2.0, -0.22], [-1.5, 0.76, 0.1, 0.08, 2.0, -0.22], [-1.9, 0.7, 0.02, 0.02, 2.0, -0.22]], -INF, 10)
	# Para-lamas de moto e eixos.
	for z in [wheelbase * 0.5, -wheelbase * 0.5]:
		dark.tube(PackedVector3Array([Vector3(-track_width * 0.5, 0.08, z), Vector3(track_width * 0.5, 0.08, z)]), 0.04, 6)
		for side in [-1.0, 1.0]:
			var grid := []
			for r in 9:
				var a := lerpf(-0.9, 1.2, r / 8.0)
				var row := PackedVector3Array()
				for c in 4:
					var u := lerpf(-1.0, 1.0, c / 3.0)
					row.append(Vector3(side * (track_width * 0.5 + u * 0.14), 0.08 + cos(a) * 0.57, z + sin(a) * 0.57))
				grid.append(row)
			paint.sheet(grid)
	# Faróis pequenos ao lado do radiador.
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 0.5, 0.7, 2.25)
		chrome.lathe(PackedVector2Array([Vector2(0.02, -0.09), Vector2(0.08, -0.08), Vector2(0.105, -0.03), Vector2(0.11, 0.02)]), 12,
				Basis(Vector3.RIGHT, PI / 2), at)
		_headlight_points.append(at + Vector3(0, 0, 0.04))
	for side in [-1.0, 1.0]:
		leather.box(Vector3(side * 0.22, 0.53, -0.75), Vector3(0.34, 0.1, 0.42))
		leather.box(Vector3(side * 0.22, 0.73, -1.0), Vector3(0.34, 0.36, 0.08), Basis(Vector3.RIGHT, -0.25))
	_add(model, paint.finish(_material("paint", GREEN, 0.8, 0.1, true)))
	_add(model, lining.finish(_material("interior", Color(0.16, 0.1, 0.07), 0.9, 0.0, true)))
	_add(model, dark.finish(_material("dark", DARK, 0.7, 0.3), false))
	_add(model, chrome.finish(_material("chrome", CHROME, 0.25, 0.85)))
	_add(model, leather.finish(_material("leather", LEATHER, 0.75, 0.0), false))


func _build_dash(model: Node3D) -> void:
	_plate_dash(model, -0.2, 0.5, 0.74, 0.44)
