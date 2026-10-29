extends SceneTree
## Teste do carro: assenta nas rodas, entra, acelera para frente, vira,
## atropela um zumbi e sai. Também confere as armas da área inicial.
var main: Node
var frame := 0
var car: VintageCar
var player: Player
var z: Zombie
var start: Vector3

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	player._unhandled_input(ev)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		car = main.get_node("Carro")
		player = main.get_node("Player")
		var ids := []
		for n in main.get_node("Props").get_children():
			if n is PickupItem and ItemDB.def(n.item_id).kind != "material":
				ids.append(n.item_id)
		print("area inicial: ", ids)
		for e in main.get_node("Enemies").get_children():
			e.detect_range = 0.0
	if frame == 90:
		print("car settled: pos=", car.global_position.snapped(Vector3.ONE * 0.01), " up·Y=", snappedf(car.global_basis.y.dot(Vector3.UP), 0.01),
			" wheels contact=", car.get_children().filter(func(w): return w is VehicleWheel3D and w.is_in_contact()).size())
		var items: Array = main.get_node("Props").get_children().filter(func(n): return n is PickupItem and n.item_id == &"espada")
		print("espada on bench y=", snappedf(items[0].global_position.y, 0.01))
		player.enter_vehicle(car)
		print("driving=", player.vehicle != null, " car camera current=", car._camera.current)
		start = car.global_position
		Input.action_press("move_forward")
	if frame == 240:
		var moved := car.global_position - start
		print("after 2.5s throttle: speed=", snappedf(car.linear_velocity.length() * 3.6, 1), " km/h, moved along car front=",
			snappedf(moved.dot(car.global_basis.z), 0.1), " m (world dir ", moved.normalized().snapped(Vector3.ONE * 0.01), ")")
		Input.action_press("move_left")
		z = main.get_node("Enemies/Zombie1")
	if frame == 300:
		Input.action_release("move_left")
		print("after steering left 1s: yaw change=", snappedf(rad_to_deg(car.rotation.y), 1), " deg")
		# Põe um zumbi na frente do carro.
		car.steering = 0.0
		car.angular_velocity = Vector3.ZERO
		var ahead := car.global_position + car.linear_velocity.normalized() * 6.0
		z.global_position = Vector3(ahead.x, 0.0, ahead.z)
		z.velocity = Vector3.ZERO
		z._set_state(Zombie.State.IDLE)
		z.max_health = 100.0
		z.health = 100.0
	if frame == 360:
		print("zombie after hit: state=", Zombie.State.keys()[z.state], " hp=", snappedf(z.health, 0.1), " car speed=", snappedf(car.linear_velocity.length() * 3.6, 1))
		Input.action_release("move_forward")
		Input.action_press("jump")
	if frame == 450:
		Input.action_release("jump")
		print("handbrake: speed=", snappedf(car.linear_velocity.length() * 3.6, 1), " km/h")
		_press("interact")
		print("exited: driving=", player.vehicle != null, " player camera current=", player.camera.current,
			" dist to car=", snappedf(player.global_position.distance_to(car.global_position), 0.01))
	if frame == 470:
		quit()
	return false
