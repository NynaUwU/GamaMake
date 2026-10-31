class_name MormonMeteorCar
extends VintageCar
## Inspirado no Mormon Meteor (Duesenberg Special, 1935), carro de recorde de
## resistência: carroceria longa em gota, um lugar só no meio, encosto com
## barbatana e para-lamas aerodinâmicos. Sai devagar, mas não para de puxar:
## o mais rápido de todos e muito estável em reta (vira pouco em alta).

const YELLOW := Color(0.8, 0.68, 0.32)
const RED := Color(0.55, 0.08, 0.05)


func _configure() -> void:
	# Dirige igual ao primeiro carro (VintageCar): só torque e velocidade são dele.
	wheelbase = 3.3
	track_width = 1.44
	wheel_radius = 0.42
	wheel_style = "disc"
	max_engine_force = 5200.0
	top_speed = 63.0 # ~225 km/h
	speedo_max = 240.0
	torque_low = 0.55
	torque_peak = 0.6
	torque_high = 0.9
	seat_offset = Vector3(0.0, 0.17, -0.55) # monoposto: no meio
	exit_offset = Vector3(-1.3, 0.2, -0.55)
	wheel_center = Vector3(0.0, 0.66, -0.15)
	wheel_tilt = 0.6
	column_base = Vector3(0.0, 0.5, 0.2)
	gauge_pos = Vector3(0.22, 0.68, 0.1)
	gauge_yaw = -0.35
	collision_boxes = [[Vector3(1.1, 0.6, 5.2), Vector3(0, 0.4, -0.15)]]
	bumper_size = Vector3(1.8, 1.4, 6.0)


func _build_body(model: Node3D) -> void:
	var paint := MeshBuilder.new()
	var lining := MeshBuilder.new()
	var trim := MeshBuilder.new()
	var chrome := MeshBuilder.new()
	var dark := MeshBuilder.new()
	var leather := MeshBuilder.new()
	# Gota comprida: nariz redondo, cockpit pequeno, rabo afinando até a ponta.
	_hull(paint, [[2.5, 0.4, 0.05, 0.05, 2.0], [2.4, 0.42, 0.26, 0.22, 2.4], [2.0, 0.46, 0.42, 0.3, 2.6],
		[1.2, 0.5, 0.5, 0.33, 2.8], [0.15, 0.5, 0.52, 0.33, 2.8]])
	_tub(paint, lining, 0.15, -0.95, 0.5, 0.52, 0.33, FLOOR_Y, 2.8)
	_hull(paint, [[-0.95, 0.5, 0.52, 0.33, 2.8], [-1.8, 0.47, 0.46, 0.3, 2.6], [-2.6, 0.42, 0.3, 0.22, 2.4],
		[-3.0, 0.38, 0.12, 0.1, 2.2], [-3.15, 0.36, 0.02, 0.02, 2.0]])
	# Encosto de cabeça virando barbatana.
	_hull(paint, [[-0.95, 0.86, 0.1, 0.06, 2.0], [-1.6, 0.92, 0.06, 0.12, 2.0], [-2.4, 0.9, 0.03, 0.1, 2.0], [-2.7, 0.78, 0.01, 0.02, 2.0]], -INF, 10)
	trim.box(Vector3(0, 0.97, -1.9), Vector3(0.02, 0.32, 1.1), Basis(Vector3.RIGHT, 0.1))
	# Faixa vermelha nas laterais e grade estreita no nariz.
	for side in [-1.0, 1.0]:
		trim.box(Vector3(side * 0.5, 0.52, -0.3), Vector3(0.02, 0.06, 4.2))
	dark.box(Vector3(0, 0.42, 2.38), Vector3(0.28, 0.24, 0.04))
	for i in 5:
		chrome.box(Vector3(-0.1 + i * 0.05, 0.42, 2.4), Vector3(0.012, 0.24, 0.02))
	# Para-lamas em gota sobre cada roda (presos por haste).
	for z in [wheelbase * 0.5, -wheelbase * 0.5]:
		dark.tube(PackedVector3Array([Vector3(-track_width * 0.5, 0.08, z), Vector3(track_width * 0.5, 0.08, z)]), 0.04, 6)
		for side in [-1.0, 1.0]:
			var x: float = side * track_width * 0.5
			_hull(paint, [[z + 0.75, 0.36, 0.02, 0.02, 2.0, x], [z + 0.55, 0.42, 0.13, 0.14, 2.0, x], [z, 0.5, 0.15, 0.1, 2.0, x],
				[z - 0.6, 0.38, 0.13, 0.08, 2.0, x], [z - 0.8, 0.3, 0.02, 0.02, 2.0, x]], -INF, 10)
			dark.tube(PackedVector3Array([Vector3(x - side * 0.05, 0.5, z), Vector3(side * 0.45, 0.4, z)]), 0.02, 4)
	# Faróis carenados dentro do nariz.
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 0.3, 0.52, 2.15)
		chrome.lathe(PackedVector2Array([Vector2(0.02, -0.05), Vector2(0.09, -0.04), Vector2(0.1, 0.0)]), 12, Basis(Vector3.RIGHT, PI / 2), at)
		_headlight_points.append(at + Vector3(0, 0, 0.03))
	leather.box(Vector3(0, 0.4, -0.55), Vector3(0.42, 0.1, 0.45))
	leather.box(Vector3(0, 0.62, -0.82), Vector3(0.42, 0.4, 0.08), Basis(Vector3.RIGHT, -0.25))
	_add(model, paint.finish(_material("paint", YELLOW, 0.8, 0.1, true)))
	_add(model, lining.finish(_material("interior", Color(0.16, 0.1, 0.07), 0.9, 0.0, true)))
	_add(model, trim.finish(_material("trim", RED, 0.8, 0.0), false))
	_add(model, chrome.finish(_material("chrome", CHROME, 0.25, 0.85), false))
	_add(model, dark.finish(_material("dark", DARK, 0.7, 0.3), false))
	_add(model, leather.finish(_material("leather", LEATHER, 0.75, 0.0), false))


func _build_dash(model: Node3D) -> void:
	_plate_dash(model, 0.13, 0.5, 0.8, 0.48)
