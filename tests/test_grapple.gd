extends SceneTree
## Gancho: prende num prédio, balança (pêndulo), corda não estica, recolhe e solta mantendo o impulso.
var main: Node
var frame := 0
var player: Player
var max_dist := 0.0
var min_y := INF
var max_speed := 0.0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		player = main.get_node("Player")
		for e in main.get_node("Enemies").get_children():
			e.detect_range = 0.0
			e.global_position.x += 200
		player.equip_item(&"gancho")
		# Predio_2 em (6, 6, -29) com 12 m de altura: mira na quina de cima.
		player.global_position = Vector3(6, 0, -12)
		player.rotation.y = 0.0
	if frame == 30:
		var to := Vector3(6, 11.5, -25.2) - player.camera.global_position
		player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	if frame == 32:
		Input.action_press("attack")
		player._fire_grapple()
		print("attached=", player._grapple_active, " anchor=", player._anchor.snapped(Vector3.ONE * 0.1), " rope=", snappedf(player._rope_length, 0.1))
		Input.action_press("move_forward")
	if frame > 32 and frame < 200 and player._grapple_active:
		max_dist = maxf(max_dist, player._chest().distance_to(player._anchor) - player._rope_length)
		min_y = minf(min_y, player.global_position.y)
		max_speed = maxf(max_speed, player.velocity.length())
	if frame == 160:
		print("swinging: rope stretch max=", snappedf(max_dist, 0.01), " min y=", snappedf(min_y, 0.1), " max speed=", snappedf(max_speed, 0.1), " rope now=", snappedf(player._rope_length, 0.1))
		player.velocity = Vector3(3, 2, 9) # para longe da parede
	if frame == 162:
		Input.action_release("attack")
		Input.action_release("move_forward")
	if frame == 170:
		print("released: pos=", player.global_position.snapped(Vector3.ONE*0.1), " floor=", player.is_on_floor(), " active=", player._grapple_active, " horizontal speed=", snappedf(Vector2(player.velocity.x, player.velocity.z).length(), 0.1), " rope visible=", player._rope.visible)
	if frame == 185:
		print("  0.25 s later in air: horizontal speed=", snappedf(Vector2(player.velocity.x, player.velocity.z).length(), 0.1))
		quit()
	return false
