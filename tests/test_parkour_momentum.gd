extends SceneTree
## Velocidade antes, durante e logo depois de cada movimento de parkour:
## deslizar, vault e subir não devem "frear" o player; só a cerca para.
var main: Node
var frame := 0
var player: Player
var log := []
var phase := ""
var start_frame := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()

func _run(name: String, pos: Vector3, action: Callable) -> void:
	phase = name
	player.global_position = pos
	player.rotation.y = 0.0
	player.velocity = Vector3(0, 0, -6.5)
	start_frame = frame
	Input.action_press("sprint")
	Input.action_press("move_forward")
	action.call()

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		player = main.get_node("Player")
		for e in main.get_node("Enemies").get_children():
			e.global_position.x += 60
			e.detect_range = 0.0
	if frame == 10:
		_run("slide", Vector3(-20, 0, 12), func(): pass)
	if frame == 25 and phase == "slide":
		print("slide: before=", snappedf(_speed(), 0.1))
		player.parkour.on_crouch_pressed(true)
	if phase == "slide" and frame == 25 + 52:
		print("  right after slide ends: speed=", snappedf(_speed(), 0.1), " move=", Parkour.Move.keys()[player.parkour.move])
	if frame == 100:
		_run("vault", Vector3(4, 0, 6.6), func(): pass)
	if frame == 104:
		print("vault: before=", snappedf(_speed(), 0.1), " started=", player.parkour.try_traverse(true))
	if frame == 150:
		print("  after vault: speed=", snappedf(_speed(), 0.1), " z=", snappedf(player.global_position.z, 0.1))
	if frame == 160:
		_run("mantle", Vector3(-3, 0, -9.0), func(): pass)
	if frame == 163:
		print("mantle (car): before=", snappedf(_speed(), 0.1), " started=", player.parkour.try_traverse(true))
	if frame == 200:
		print("  after mantle: speed=", snappedf(_speed(), 0.1), " y=", snappedf(player.global_position.y, 0.1))
	if frame == 210:
		_run("fence", Vector3(-6, 0, -16.6), func(): pass)
	if frame == 212:
		print("fence: before=", snappedf(_speed(), 0.1), " started=", player.parkour.try_traverse(true))
	if frame == 275:
		print("  after fence: speed=", snappedf(_speed(), 0.1))
		quit()
	if player and player.parkour.move != Parkour.Move.NONE and frame % 6 == 0:
		print("    ", phase, " f", frame, " speed=", snappedf(_speed(), 0.1), " hand_w=", snappedf(player.parkour.hand_weight, 0.01), " pitch=", snappedf(player.parkour.camera_pitch, 0.01))
	return false
