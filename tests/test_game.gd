extends SceneTree
## Teste de fumaça: carrega a cena principal, simula golpes do player e confere estados.
var main: Node
var frame := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	frame += 1
	var player: Player = main.get_node("Player")
	var z: Zombie = main.get_node("Enemies/Zombie1")
	if frame == 2:
		player.equip_item(&"espada")
	if frame == 10:
		print("zombies: ", main.get_node("Enemies").get_child_count(), " state z1: ", Zombie.State.keys()[z.state])
	if frame == 120:
		print("z1 state after 2s: ", Zombie.State.keys()[z.state], " dist: ", snappedf(z.global_position.distance_to(player.global_position), 0.1))
	if frame == 130:
		# coloca o player de frente para o zumbi, perto, e golpeia
		player.global_position = z.global_position + Vector3(0, 0, 1.6).rotated(Vector3.UP, z.rotation.y) * -1.0
		player.look_at(Vector3(z.global_position.x, player.global_position.y, z.global_position.z))
		player.head.rotation.x = -0.15
	if frame == 135:
		player._melee_attack()
	if frame == 175:
		print("after melee: z1 hp=", z.health, " state=", Zombie.State.keys()[z.state], " player stamina=", int(player.stamina))
	if frame == 200:
		player._kick()
	if frame == 240:
		print("after kick: state=", Zombie.State.keys()[z.state])
	if frame == 520:
		print("later: state=", Zombie.State.keys()[z.state], " player hp=", player.health)
		quit()
	return false
