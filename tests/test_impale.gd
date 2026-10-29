extends SceneTree
## Teste: empalar zumbis correndo com a espada, chutar para fora, raio de morte
## da explosão e aviso de "Pegar" sumindo depois de pegar o item.
var main: Node
var frame := 0
var player: Player
var zs: Array = []
var prompts: Array = []

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		player = main.get_node("Player")
		player.equip_item(&"espada")
		zs = main.get_node("Enemies").get_children()
		player.interact_prompt_changed.connect(func(t): prompts.append(t))
		player.global_position = Vector3(0, 0, 12)
		player.rotation.y = 0.0
		for i in zs.size():
			zs[i].detect_range = 0.0
			zs[i].global_position = Vector3(0.3 * (i % 2), 0, 6.0 - i * 1.0)
		zs[3].global_position = Vector3(25, 0, 25)
	# 1) Correr segurando o ataque com a espada.
	if frame == 5:
		Input.action_press("sprint")
		Input.action_press("move_forward")
	if frame == 10:
		Input.action_press("attack")
		var ev := InputEventAction.new()
		ev.action = "attack"
		ev.pressed = true
		player._unhandled_input(ev)
		print("charging=", player._charging)
	if frame == 110:
		print("impaled=", player._impaled.size(), " states=", zs.slice(0, 3).map(func(z): return Zombie.State.keys()[z.state]),
			" player speed=", snappedf(Vector2(player.velocity.x, player.velocity.z).length(), 0.1))
		var chest: PhysicalBone3D = zs[0].ragdoll.get_bone_body(&"Chest")
		print("  z0 chest dist to camera=", snappedf(chest.global_position.distance_to(player.camera.global_position), 0.01))
		Input.action_release("sprint")
	if frame == 112:
		print("released: charging=", player._charging, " impaled=", player._impaled.size())
	if frame == 140:
		print("after kick-off: states=", zs.slice(0, 3).map(func(z): return Zombie.State.keys()[z.state]))
		Input.action_release("attack")
		Input.action_release("move_forward")
	# 2) Explosão: zumbi colado ao impacto morre, zumbi a 2.5 m só cai.
	if frame == 150:
		var a: Zombie = zs[3]
		a.global_position = Vector3(20, 0, 20)
		a.max_health = 1000.0
		a.health = 1000.0
		var e := Explosion.new()
		main.add_child(e)
		e.global_position = Vector3(20.5, 0.2, 20)
		e.detonate(3.5, 70.0, 450.0, 1.3)
		print("explosion near (1000 hp): state=", Zombie.State.keys()[a.state], " cut=", a._cut_bones.size())
	# 3) Pegar item: o aviso precisa sumir.
	if frame == 160:
		var item: PickupItem = main.get_node("Props/Item1")
		player.global_position = Vector3(item.global_position.x, 0, item.global_position.z + 1.4)
		player.rotation.y = 0.0
	if frame == 162:
		var item: PickupItem = main.get_node("Props/Item1")
		var to_item := item.global_position - player.camera.global_position
		player.head.rotation.x = atan2(to_item.y, -to_item.z)
	if frame == 170:
		print("prompt before: '", player._interact_target.get_interact_text() if player._interact_target else "", "'")
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		player._unhandled_input(ev)
	if frame == 180:
		print("last prompt after pickup: '", prompts.back(), "'")
		quit()
	return false
