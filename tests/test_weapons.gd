extends SceneTree
## Teste das armas novas: passos do tranco, corte de membros, taco, pistola e chute em área.
var main: Node
var frame := 0
var player: Player
var zs: Array = []

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _zombie_at(z: Zombie, pos: Vector3) -> void:
	z.global_position = pos
	z.rotation.y = 0.0
	z.detect_range = 0.0
	z.max_health = 1000.0
	z.health = 1000.0
	z.velocity = Vector3.ZERO

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		player = main.get_node("Player")
		zs = main.get_node("Enemies").get_children()
		player.global_position = Vector3(0, 0, 6)
		player.rotation.y = 0.0
		for i in zs.size():
			_zombie_at(zs[i], Vector3(20 + i * 3, 0, 0))
	# 1) Passos do tranco: deslocamento depois de um golpe leve.
	if frame == 5:
		_zombie_at(zs[0], Vector3(0, 0, 4))
	if frame == 10:
		zs[0].take_hit(_hit(10, &"Chest", zs[0].global_position + Vector3.UP * 1.3, Vector3(0, 0, -1), 30))
		print("stagger: state=", Zombie.State.keys()[zs[0].state], " duration=", zs[0]._stagger_duration)
	if frame == 40:
		print("  moved back: ", snappedf(4.0 - zs[0].global_position.z, 0.01), " m")
	# 2) Corte: força alta, chance forçada.
	if frame == 50:
		zs[0].take_hit(_hit(60, &"LowerArm.L", zs[0].global_position + Vector3(-0.3, 1.0, 0), Vector3(-1, 0, 0), 30, false, true))
		print("cut: bones=", zs[0]._cut_bones, " arms=", zs[0]._arm_count(),
			" limbs in scene=", main.get_node("Enemies").get_children().filter(func(n): return n is RigidBody3D).size())
		zs[0].take_hit(_hit(80, &"Head", zs[0].global_position + Vector3(0, 1.7, 0), Vector3(-1, 0, 0), 30, false, true))
		print("decapitated: state=", Zombie.State.keys()[zs[0].state], " cut=", zs[0]._cut_bones)
	# 3) Taco: força alta -> dois passos ou cambaleio.
	if frame == 70:
		_zombie_at(zs[1], Vector3(0, 0, 4))
	if frame == 75:
		zs[1].take_hit(_hit(24, &"Chest", zs[1].global_position + Vector3.UP * 1.3, Vector3(0, 0, -1), 58))
		print("bat: state=", Zombie.State.keys()[zs[1].state], " balance=", snappedf(zs[1].balance, 0.01))
	# 4) Pistola: tiro na cabeça de um zumbi na frente.
	if frame == 130:
		_zombie_at(zs[1], Vector3(0, 0, -4))
		zs[1].max_health = 100.0
		zs[1].health = 100.0
		zs[1].balance = 0.0
		zs[1]._set_state(Zombie.State.IDLE)
		player.equip_item(&"pistola")
		player.head.rotation.x = 0.0
	if frame == 150:
		# mira na cabeça (altura ~1.65 m); câmera em 1.6 m
		player.head.rotation.x = 0.01 # cabeça
		player._fire_pistol()
		print("pistol: ammo=", player._ammo, " z hp=", zs[1].health, " state=", Zombie.State.keys()[zs[1].state])
	# 5) Chute em área: três zumbis na frente, lado a lado.
	if frame == 170:
		player.equip_item(&"espada")
		player.global_position = Vector3(0, 0, 6)
		for i in 3:
			_zombie_at(zs[i + 1], Vector3(-1.0 + i, 0, 4.5))
	if frame == 180:
		player._kick()
	if frame == 230:
		for i in 3:
			var z: Zombie = zs[i + 1]
			print("kick z", i, ": state=", Zombie.State.keys()[z.state], " pushed=", snappedf(4.5 - z.global_position.z, 0.01))
		quit()
	return false



## Monta um HitInfo a partir dos argumentos antigos (dano, osso, ponto, direção, força, derruba, corta).
func _hit(damage: float, bone: StringName, point: Vector3, direction: Vector3, force: float,
		knockdown := false, cut := false) -> HitInfo:
	var info := HitInfo.make(damage, bone, point, direction, force,
			HitInfo.Type.CUT if cut else HitInfo.Type.BLUNT)
	info.knockdown = knockdown
	return info
