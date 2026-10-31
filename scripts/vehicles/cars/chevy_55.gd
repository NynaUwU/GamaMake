class_name Chevy55Car
extends VintageCar
## "Final Objective" (inspirado num Chevrolet Sports Coupe 1955 depenado para
## o fim do mundo): cupê fechado, frente levantada, entrada de ar no capô,
## para-choques cromados, pintura queimada de sol e sem nenhum vidro. O mais
## equilibrado: aderência boa, torque cheio no meio e direção previsível.

const PAINT_55 := Color(0.33, 0.48, 0.46)
const PRIMER := Color(0.42, 0.4, 0.36)


func _configure() -> void:
	# Dirige igual ao primeiro carro (VintageCar): só torque e velocidade são dele.
	wheelbase = 2.95
	track_width = 1.52
	wheel_radius = 0.38
	wheel_style = "disc"
	max_engine_force = 4600.0
	top_speed = 44.0 # ~160 km/h
	speedo_max = 180.0
	torque_low = 0.85
	torque_peak = 0.3
	torque_high = 0.65
	seat_offset = Vector3(0.38, 0.3, -0.4) # volante à esquerda
	exit_offset = Vector3(1.6, 0.2, -0.4)
	eye_height = 0.74
	wheel_center = Vector3(0.38, 0.84, 0.05)
	wheel_tilt = 0.5
	wheel_size = 0.2
	column_base = Vector3(0.38, 0.66, 0.38)
	gauge_pos = Vector3(0.38, 0.84, 0.31)
	gauge_yaw = 0.0
	collision_boxes = [[Vector3(1.8, 0.7, 4.8), Vector3(0, 0.45, -0.05)], [Vector3(1.5, 0.55, 1.5), Vector3(0, 1.1, -0.45)]]
	bumper_size = Vector3(2.0, 1.5, 5.4)


func _build_body(model: Node3D) -> void:
	var paint := MeshBuilder.new()
	var primer := MeshBuilder.new()
	var lining := MeshBuilder.new()
	var chrome := MeshBuilder.new()
	var dark := MeshBuilder.new()
	var leather := MeshBuilder.new()
	var floor_y := 0.42 # a carroceria larga fica acima das rodas (que aparecem embaixo)
	# Frente (capô levantado de "gasser") e traseira quadradas, cabine no meio.
	_hull(paint, [[2.45, 0.63, 0.86, 0.24, 6.0], [1.6, 0.65, 0.9, 0.27, 6.0], [0.35, 0.63, 0.9, 0.27, 6.0]], floor_y)
	_hull(paint, [[-1.1, 0.63, 0.9, 0.28, 6.0], [-2.0, 0.63, 0.88, 0.28, 6.0], [-2.45, 0.6, 0.84, 0.25, 6.0]], floor_y)
	_tub(paint, lining, 0.35, -1.1, 0.63, 0.9, 0.28, floor_y, 6.0)
	# Soleira estreita entre as rodas, até perto do chão.
	_hull(dark, [[1.05, 0.3, 0.55, 0.16, 6.0], [-1.05, 0.3, 0.6, 0.16, 6.0]], -INF, 12)
	# Capô de primer com entrada de ar.
	primer.box(Vector3(0, 0.915, 1.4), Vector3(1.3, 0.03, 1.9))
	primer.box(Vector3(0, 0.99, 1.3), Vector3(0.5, 0.14, 0.8))
	dark.box(Vector3(0, 1.0, 1.71), Vector3(0.42, 0.08, 0.02))
	# Rabetas (barbatanas pequenas) em cima dos para-lamas traseiros.
	for side in [-1.0, 1.0]:
		paint.box(Vector3(side * 0.8, 0.95, -2.05), Vector3(0.1, 0.1, 0.7))
		chrome.box(Vector3(side * 0.8, 0.8, -2.47), Vector3(0.14, 0.12, 0.04)) # lanterna
	# Teto, colunas e janelas vazias (sem vidro).
	paint.box(Vector3(0, 1.38, -0.45), Vector3(1.5, 0.06, 1.35))
	for side in [-1.0, 1.0]:
		paint.box(Vector3(side * 0.72, 1.14, 0.25), Vector3(0.07, 0.5, 0.07), Basis(Vector3.RIGHT, -0.45)) # coluna A
		paint.box(Vector3(side * 0.72, 1.14, -1.15), Vector3(0.1, 0.52, 0.22), Basis(Vector3.RIGHT, 0.5)) # coluna C larga
	paint.box(Vector3(0, 1.14, -1.2), Vector3(1.4, 0.06, 0.06), Basis(Vector3.RIGHT, 0.5))
	paint.box(Vector3(0, 0.91, 0.36), Vector3(1.5, 0.04, 0.05))
	# Grade "caixa de ovos" e para-choques.
	dark.box(Vector3(0, 0.62, 2.46), Vector3(1.2, 0.28, 0.04))
	for i in 7:
		chrome.box(Vector3(-0.54 + i * 0.18, 0.62, 2.48), Vector3(0.02, 0.28, 0.03))
	chrome.box(Vector3(0, 0.62, 2.48), Vector3(1.22, 0.02, 0.03))
	chrome.box(Vector3(0, 0.42, 2.55), Vector3(1.85, 0.1, 0.1))
	chrome.box(Vector3(0, 0.42, -2.52), Vector3(1.85, 0.1, 0.1))
	# Escapamentos laterais saindo antes da roda de trás.
	for side in [-1.0, 1.0]:
		dark.tube(PackedVector3Array([Vector3(side * 0.6, 0.15, 1.0), Vector3(side * 0.93, 0.2, 0.3), Vector3(side * 0.95, 0.2, -0.6)]), 0.045, 6)
	# Faróis embutidos nos para-lamas.
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 0.68, 0.72, 2.42)
		chrome.lathe(PackedVector2Array([Vector2(0.03, -0.05), Vector2(0.1, -0.04), Vector2(0.12, 0.0)]), 12, Basis(Vector3.RIGHT, PI / 2), at)
		paint.box(at + Vector3(0, 0.12, -0.05), Vector3(0.28, 0.05, 0.16)) # "sobrancelha"
		_headlight_points.append(at + Vector3(0, 0, 0.03))
	# Banco inteiriço.
	leather.box(Vector3(0, 0.42, -0.45), Vector3(1.5, 0.12, 0.5))
	leather.box(Vector3(0, 0.66, -0.75), Vector3(1.5, 0.45, 0.1), Basis(Vector3.RIGHT, -0.2))
	_add(model, paint.finish(_material("paint", PAINT_55, 0.85, 0.1, true)))
	_add(model, primer.finish(_material("primer", PRIMER, 0.95, 0.0), false))
	_add(model, lining.finish(_material("interior", Color(0.2, 0.17, 0.15), 0.9, 0.0, true)))
	_add(model, chrome.finish(_material("chrome", CHROME, 0.25, 0.85), false))
	_add(model, dark.finish(_material("dark", DARK, 0.7, 0.3), false))
	_add(model, leather.finish(_material("leather", Color(0.55, 0.5, 0.42), 0.8, 0.0), false))


func _build_dash(model: Node3D) -> void:
	_plate_dash(model, 0.33, 0.62, 0.95, 0.86, PAINT_55.darkened(0.2))
