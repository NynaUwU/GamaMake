extends SceneTree
## Deslize curvando e descendo ladeira, vault em obstáculo de 3,5 m e colherona arremessando.
var main: Node
var frame := 0
var player: Player
var z: Zombie
var z_start: Vector3

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	# Rampa longa descendo (inclinação ~15°) e uma mesa comprida de 3,5 m.
	var ramp := CSGBox3D.new()
	ramp.use_collision = true
	ramp.size = Vector3(6, 0.4, 40)
	ramp.position = Vector3(60, 5.0, 40)
	ramp.rotation.x = deg_to_rad(-15) # desce para -Z
	main.add_child(ramp)
	var table := CSGBox3D.new()
	table.use_collision = true
	table.size = Vector3(1.4, 1.0, 3.5)
	table.position = Vector3(-60, 0.5, 40)
	main.add_child(table)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		player = main.get_node("Player")
		for e in main.get_node("Enemies").get_children():
			e.detect_range = 0.0
			e.global_position.x += 200
	# 1) Deslize no plano, segurando A.
	if frame == 10:
		player.global_position = Vector3(0, 0, 30)
		player.rotation.y = 0.0
		player.velocity = Vector3(0, 0, -6.5)
		Input.action_press("sprint")
		Input.action_press("move_forward")
	if frame == 14:
		player.parkour.on_crouch_pressed(true)
		Input.action_press("move_left")
	if frame == 50:
		var d := player.parkour._slide_dir
		print("flat slide steering left: dir=", d.snapped(Vector3.ONE * 0.01), " move=", Parkour.Move.keys()[player.parkour.move])
		Input.action_release("move_left")
	# 2) Deslize descendo a rampa.
	if frame == 100:
		player.global_position = Vector3(60, 10.5, 56)
		player.rotation.y = 0.0
		player.velocity = Vector3(0, 0, -6.5)
	if frame == 150:
		player.velocity = Vector3(0, 0, -6.5)
		player.parkour.on_crouch_pressed(true)
	if frame > 150 and frame < 290 and frame % 20 == 0:
		print("   f", frame, " pos=", player.global_position.snapped(Vector3.ONE*0.1), " floor=", player.is_on_floor(), " n=", player.get_floor_normal().snapped(Vector3.ONE*0.01), " v=", snappedf(player.parkour._slide_speed,0.1), " move=", Parkour.Move.keys()[player.parkour.move])
	if frame == 150 + 120:
		print("downhill 2s: still sliding=", player.parkour.move == Parkour.Move.SLIDE, " speed=", snappedf(player.parkour._slide_speed, 0.1))
	# 3) Vault na mesa de 3,5 m.
	if frame == 300:
		player.parkour._end_slide()
		player.parkour.move = Parkour.Move.NONE
		player.global_position = Vector3(-60, 0, 42.6)
		player.rotation.y = 0.0
		player.velocity = Vector3(0, 0, -6.5)
	if frame == 304:
		print("long table 3.5 m: started=", player.parkour.try_traverse(true), " move=", Parkour.Move.keys()[player.parkour.move])
	if frame == 360:
		print("  after: z=", snappedf(player.global_position.z, 0.1), " (mesa de 38.25 a 41.75) y=", snappedf(player.global_position.y, 0.1))
		Input.action_release("sprint")
		Input.action_release("move_forward")
	# 4) Colherona.
	if frame == 370:
		z = main.get_node("Enemies/Zombie1")
		z.global_position = Vector3(0, 0, 20)
		z.max_health = 1000.0
		z.health = 1000.0
		z_start = z.global_position
		var hit := HitInfo.make(20, &"Chest", z.global_position + Vector3.UP, Vector3(0, 0, -1), 95, HitInfo.Type.BLUNT)
		hit.launch = player.spoon_launch
		z.take_hit(hit)
	if frame == 370 + 150:
		var hips := z.ragdoll.get_root_position()
		print("spoon launch: flew ", snappedf(Vector2(hips.x - z_start.x, hips.z - z_start.z).length(), 0.1), " m, state=", Zombie.State.keys()[z.state])
		quit()
	return false
