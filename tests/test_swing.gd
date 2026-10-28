extends SceneTree
## Teste do combo de espada: três golpes seguidos num zumbi parado na frente do player.
var main: Node
var frame := 0
var z: Zombie
var player: Player

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		player = main.get_node("Player")
		z = main.get_node("Enemies/Zombie1")
		for e in main.get_node("Enemies").get_children():
			if e != z:
				e.queue_free()
		z.max_health = 1000.0
		z.health = 1000.0
		z.detect_range = 0.0 # fica parado
		player.global_position = z.global_position + Vector3(0, 0, 1.7)
		player.rotation.y = 0.0
	if frame in [10, 40, 70]:
		player._melee_attack()
	if frame in [25, 55, 90]:
		print("f", frame, " combo=", player._swing_index, " hp=", z.health, " state=", Zombie.State.keys()[z.state],
			" springs=", z.hit_reaction._springs.size())
	if frame == 140:
		print("phase=", Player.SwingPhase.keys()[player._swing_phase], " springs after settle=", z.hit_reaction._springs.size())
		quit()
	return false
