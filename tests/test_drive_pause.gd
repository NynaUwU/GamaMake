extends SceneTree
## Curva fechada em alta velocidade (não pode tombar), corpo sentado com a
## cabeça girando, carregador segurando o botão e menu de pausa.
var main: Node
var frame := 0
var car: VintageCar
var player: Player
var min_up := 1.0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		car = main.get_node("Carro")
		player = main.get_node("Player")
		for e in main.get_node("Enemies").get_children():
			e.global_position.x += 60
			e.detect_range = 0.0
	if frame == 60:
		player.enter_vehicle(car)
		Input.action_press("move_forward")
	if frame == 300:
		print("speed before turn: ", snappedf(car.linear_velocity.length() * 3.6, 1), " km/h")
		Input.action_press("move_left")
	if frame > 300 and frame < 480:
		min_up = minf(min_up, car.global_basis.y.dot(Vector3.UP))
	if frame == 480:
		Input.action_release("move_left")
		Input.action_release("move_forward")
		print("hard turn 3s: min up·Y=", snappedf(min_up, 0.01), " (1 = reto, <0.5 = tombando) final up·Y=", snappedf(car.global_basis.y.dot(Vector3.UP), 0.01))
		# Cabeça gira, corpo fica no banco.
		player._vehicle_yaw = 1.2
	if frame == 485:
		var body_fwd: Vector3 = -player.get_node("Body").global_basis.z
		var seat_fwd: Vector3 = -car.seat.global_basis.z
		var cam_fwd: Vector3 = -player.camera.global_basis.z
		print("body vs seat dot=", snappedf(body_fwd.dot(seat_fwd), 0.01), " camera vs seat dot=", snappedf(cam_fwd.dot(seat_fwd), 0.01))
		var rim: StandardMaterial3D = car._materials["wheel_rim"]
		print("wheel alpha=", rim.albedo_color.a, " arm alpha=", player._arm_materials[0].albedo_color.a)
		player.exit_vehicle()
		print("after exit: wheel alpha=", rim.albedo_color.a, " arm alpha=", player._arm_materials[0].albedo_color.a)
		player.inventory.add(&"lanterna")
		player.equip_item(&"carregador")
		player.flashlight_charge = 0.1
	if frame == 500:
		Input.action_press("attack")
	if frame == 740:
		Input.action_release("attack")
		print("holding attack 4s: charge 0.1 -> ", snappedf(player.flashlight_charge, 0.01), " label='", player._emit_weapon_text.get_method(), "'")
		var pause: PauseMenu = main.get_node("PauseMenu")
		pause.open()
		print("paused=", paused, " mouse visible=", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
		pause.close()
		print("resumed paused=", paused)
		quit()
	return false
