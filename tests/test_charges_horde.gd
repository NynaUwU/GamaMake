extends SceneTree
## Gancho com 5 cargas e recarga; 100 zumbis; aceleração mais pesada.
var main: Node
var frame := 0
var player: Player
var worst := 0.0
var last := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		player = main.get_node("Player")
		player.equip_item(&"gancho")
		player.global_position = Vector3(6, 0, -12)
		player.head.rotation.x = 0.6
	if frame == 20:
		var fired := 0
		for i in 7:
			player._release_grapple()
			var before: int = player._grapple_left
			player._fire_grapple()
			if player._grapple_left < before:
				fired += 1
		player._release_grapple()
		print("fired ", fired, " of 7 attempts, left=", player._grapple_left)
	if frame == 20 + int(player.grapple_recharge * 60.0) + 5:
		print("after ", player.grapple_recharge, " s idle: left=", player._grapple_left)
		main._spawn_horde(100)
		print("zombies now: ", main.get_tree().get_nodes_in_group("enemy").size())
		last = Time.get_ticks_usec()
	if frame == 560:
		last = Time.get_ticks_usec()
	if frame > 560 and frame < 700:
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
	if frame == 700:
		print("worst physics frame with horde: ", snappedf(worst, 0.1), " ms")
		quit()
	return false
