extends SceneTree
## Teste dos carros: cada um num chão plano, acelera 14 s, depois vira com tudo
## e mostra o quanto a traseira escorrega (ângulo entre a frente e a velocidade).
var CARS := ["res://scripts/vehicles/vintage_car.gd", "res://scripts/vehicles/cars/aero_v12.gd",
	"res://scripts/vehicles/cars/brutus.gd", "res://scripts/vehicles/cars/chevy_55.gd",
	"res://scripts/vehicles/cars/darracq_v8.gd", "res://scripts/vehicles/cars/hall_scott.gd",
	"res://scripts/vehicles/cars/mormon_meteor.gd"]
var index := -1
var frame := 0
var car: VintageCar
var t100 := -1.0
var max_slip := 0.0
var min_up := 1.0
var report := ""

func _initialize() -> void:
	var only := OS.get_environment("CAR")
	if only != "":
		CARS = CARS.filter(func(c: String) -> bool: return only in c)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000, 1, 4000)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	root.add_child(ground)
	_next()

func _next() -> void:
	if car:
		car.queue_free()
	Input.action_release("move_forward")
	Input.action_release("move_left")
	index += 1
	if index >= CARS.size():
		print(report)
		quit()
		return
	car = load(CARS[index]).new()
	car.position = Vector3(index * 30, 1.0, 0)
	root.add_child(car)
	frame = 0
	t100 = -1.0
	max_slip = 0.0
	min_up = 1.0

func _physics_process(_d: float) -> bool:
	if car == null or not is_instance_valid(car):
		return false
	frame += 1
	var t := frame / 60.0
	var fwd := car.global_basis.z
	var kmh := car.linear_velocity.dot(fwd) * 3.6
	min_up = minf(min_up, car.global_basis.y.dot(Vector3.UP))
	if frame == 60:
		var local_y := (car.to_local(car.get_children().filter(func(w): return w is VehicleWheel3D)[0].global_position)).y
		print(CARS[index]); report += "\n%s: altura=%.2f roda local y=%.2f" % [CARS[index].get_file(), car.global_position.y, local_y]
		car.set_driver(Node3D.new())
		Input.action_press("move_forward")
	if frame > 60:
		if t100 < 0 and kmh >= 100.0:
			t100 = t - 1.0
		if frame == 60 + 300:
			report += " | 5s=%d km/h" % kmh
		if frame == 60 + 600:
			report += " 10s=%d" % kmh
		if frame == 60 + 840:
			report += " 14s=%d 0-100=%.1fs" % [kmh, t100]
			Input.action_release("move_forward")
			Input.action_press("move_back")
			min_up = 1.0
		if frame > 60 + 840 and Input.is_action_pressed("move_back") and kmh < 80.0:
			Input.action_release("move_back")
			Input.action_press("move_forward")
			Input.action_press("move_left")
			min_up = 1.0
			frame = 2000
		if frame > 2000:
			var v := car.linear_velocity
			v.y = 0
			if v.length() > 3.0:
				max_slip = maxf(max_slip, rad_to_deg(acos(clampf(v.normalized().dot(fwd), -1, 1))))
		if frame > 2000 and frame % 10 == 0 and OS.get_environment("TRACE") != "":
			var vv := car.linear_velocity
			vv.y = 0
			print("t=%d slip=%d |v|=%d yaw=%.2f" % [frame - 2000, rad_to_deg(fwd.signed_angle_to(vv, Vector3.UP)), vv.length() * 3.6, car.angular_velocity.y])
		if frame == 2000 + 40:
			Input.action_release("move_left") # vira 0,7 s e solta: escorrega e volta?
		if frame == 2000 + 160:
			var v2 := car.linear_velocity
			v2.y = 0
			var end_slip := rad_to_deg(acos(clampf(v2.normalized().dot(fwd), -1, 1))) if v2.length() > 3.0 else 0.0
			report += " | curva a 80: escorregou=%d° depois=%d° menor up=%.2f vel=%d (|v|=%d)" % [max_slip, end_slip, min_up, kmh, car.linear_velocity.length() * 3.6]
			_next()
		if frame == 60 + 1800:
			report += " (não freou)"
			_next()
	return false
