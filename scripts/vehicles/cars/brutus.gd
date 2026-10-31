class_name BrutusCar
extends VintageCar
## "Brutus" (inspirado no carro experimental da BMW): chassi de 1907 com um
## motor V12 de avião de 46 litros enfiado na frente, transmissão por corrente
## e rodas de madeira enormes. Torque absurdo para pneus tão finos: com o pé
## no fundo a traseira escorrega de lado em qualquer marcha (dá para corrigir
## no contra-esterço, que sobra bastante mesmo rápido).

const BLACK := Color(0.13, 0.13, 0.14)
const BRASS := Color(0.5, 0.42, 0.22)


func _configure() -> void:
	# Dirige igual ao primeiro carro (VintageCar): só torque e velocidade são dele.
	wheelbase = 2.9
	track_width = 1.4
	wheel_radius = 0.54
	wheel_style = "wood"
	max_engine_force = 8200.0
	top_speed = 47.0 # ~170 km/h
	speedo_max = 200.0
	torque_low = 1.0 # tudo no arranque
	torque_peak = 0.0
	torque_high = 0.55
	seat_offset = Vector3(-0.24, 0.6, -0.55)
	exit_offset = Vector3(-1.45, 0.35, -0.55)
	eye_height = 0.78
	wheel_center = Vector3(-0.24, 1.1, -0.05)
	wheel_tilt = 0.85
	wheel_size = 0.21
	column_base = Vector3(-0.24, 0.8, 0.45)
	gauge_pos = Vector3(0.0, 0.93, 0.21)
	collision_boxes = [[Vector3(0.95, 0.7, 4.1), Vector3(0, 0.55, 0.0)], [Vector3(0.8, 0.35, 1.9), Vector3(0, 1.05, 1.0)]]
	bumper_size = Vector3(1.7, 1.6, 5.0)
	bumper_offset = Vector3(0, 0.6, 0.1)


func _build_body(model: Node3D) -> void:
	var paint := MeshBuilder.new()
	var lining := MeshBuilder.new()
	var dark := MeshBuilder.new()
	var brass := MeshBuilder.new()
	var leather := MeshBuilder.new()
	var floor_y := 0.25
	# Capô alto e quadrado (o V12 não cabe em nada menor), com cintas de couro.
	_hull(paint, [[2.05, 0.82, 0.38, 0.32, 5.0], [1.2, 0.84, 0.42, 0.34, 5.0], [0.3, 0.84, 0.43, 0.34, 5.0]], floor_y)
	for z in [1.7, 0.75]:
		leather.box(Vector3(0, 1.185, z), Vector3(0.88, 0.02, 0.06))
		for side in [-1.0, 1.0]:
			leather.box(Vector3(side * 0.435, 0.95, z), Vector3(0.02, 0.45, 0.06))
	# Bancos do V12 saindo pelo capô aberto: duas fileiras de 6 cilindros.
	for side in [-1.0, 1.0]:
		_cylinders(dark, Vector3(side * 0.15, 1.12, 1.9), 6, 0.29, 0.065, 0.18, -side * 0.45)
		# Escapamentos curtos (um por cilindro) saindo pela lateral.
		for i in 6:
			var z := 1.9 - i * 0.29
			dark.tube(PackedVector3Array([Vector3(side * 0.42, 0.98, z), Vector3(side * 0.56, 0.98, z - 0.04),
				Vector3(side * 0.6, 0.86, z - 0.08)]), 0.03, 5)
	# Radiador de latão alto e reto na frente.
	brass.box(Vector3(0, 0.85, 2.12), Vector3(0.8, 0.82, 0.1))
	dark.box(Vector3(0, 0.83, 2.175), Vector3(0.66, 0.66, 0.02))
	brass.lathe(PackedVector2Array([Vector2(0.04, 0.0), Vector2(0.04, 0.06), Vector2(0.02, 0.08)]), 8, Basis.IDENTITY, Vector3(0, 1.26, 2.12))
	# Cockpit alto (corpo de carroça) e tanque redondo atrás.
	_tub(paint, lining, 0.3, -1.05, 0.72, 0.48, 0.36, floor_y)
	_hull(paint, [[-1.15, 0.74, 0.3, 0.3, 2.0], [-1.25, 0.74, 0.34, 0.34, 2.0], [-1.85, 0.74, 0.34, 0.34, 2.0], [-1.95, 0.74, 0.28, 0.28, 2.0]], -INF, 12)
	brass.lathe(PackedVector2Array([Vector2(0.06, 0.0), Vector2(0.06, 0.04), Vector2(0.03, 0.06)]), 8, Basis.IDENTITY, Vector3(0, 1.08, -1.55))
	# Chassi de longarinas à mostra e transmissão por corrente de cada lado.
	for side in [-1.0, 1.0]:
		dark.box(Vector3(side * 0.38, 0.22, 0.05), Vector3(0.07, 0.14, 4.2))
		var rear := Vector3(side * 0.62, 0.1, -wheelbase * 0.5)
		var sprocket := Vector3(side * 0.62, 0.32, -0.45)
		dark.lathe(PackedVector2Array([Vector2(0.24, -0.02), Vector2(0.24, 0.02)]), 12, Basis(Vector3.FORWARD, PI / 2), rear)
		dark.lathe(PackedVector2Array([Vector2(0.1, -0.02), Vector2(0.1, 0.02)]), 10, Basis(Vector3.FORWARD, PI / 2), sprocket)
		dark.tube(PackedVector3Array([sprocket + Vector3(0, 0.1, 0), rear + Vector3(0, 0.24, 0)]), 0.015, 4)
		dark.tube(PackedVector3Array([sprocket - Vector3(0, 0.1, 0), rear - Vector3(0, 0.24, 0)]), 0.015, 4)
		# Para-lamas de carroça (tábua curva) sobre as rodas da frente.
		var grid := []
		for r in 9:
			var a := lerpf(-0.6, 1.4, r / 8.0)
			var row := PackedVector3Array()
			for c in 4:
				var u := lerpf(-1.0, 1.0, c / 3.0)
				row.append(Vector3(side * (track_width * 0.5 + u * 0.12), 0.1 + cos(a) * 0.66, wheelbase * 0.5 + sin(a) * 0.66))
			grid.append(row)
		paint.sheet(grid)
	# Eixos.
	for z in [wheelbase * 0.5, -wheelbase * 0.5]:
		dark.tube(PackedVector3Array([Vector3(-track_width * 0.5, 0.1, z), Vector3(track_width * 0.5, 0.1, z)]), 0.04, 6)
	# Dois faróis de latão em hastes ao lado do radiador.
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 0.55, 0.95, 2.1)
		brass.lathe(PackedVector2Array([Vector2(0.02, -0.12), Vector2(0.09, -0.1), Vector2(0.12, -0.04), Vector2(0.125, 0.03)]), 12,
				Basis(Vector3.RIGHT, PI / 2), at)
		dark.tube(PackedVector3Array([at + Vector3(-side * 0.02, -0.1, -0.05), Vector3(side * 0.42, 0.7, 2.05)]), 0.015, 4)
		_headlight_points.append(at + Vector3(0, 0, 0.05))
	# Bancos altos de couro, lado a lado.
	for side in [-1.0, 1.0]:
		leather.box(Vector3(side * 0.24, 0.8, -0.55), Vector3(0.36, 0.1, 0.42))
		leather.box(Vector3(side * 0.24, 1.06, -0.8), Vector3(0.36, 0.45, 0.08), Basis(Vector3.RIGHT, -0.2))
	_add(model, paint.finish(_material("paint", BLACK, 0.8, 0.1, true)))
	_add(model, lining.finish(_material("interior", Color(0.16, 0.1, 0.07), 0.9, 0.0, true)))
	_add(model, dark.finish(_material("dark", DARK, 0.7, 0.3), false))
	_add(model, brass.finish(_material("brass", BRASS, 0.6, 0.4)))
	_add(model, leather.finish(_material("leather", LEATHER, 0.75, 0.0), false))


func _build_dash(model: Node3D) -> void:
	_plate_dash(model, 0.24, 0.72, 1.05, 0.44, Color(0.35, 0.24, 0.14)) # painel de madeira
