extends SceneTree
## Teste das novidades: inventário/hotbar, soco, bloqueio, agachar, deslizar,
## vault/subir/cerca, lanterna atraindo, navegação, zumbi escalando, arma de
## zumbi, empalar de lado, membro quebrado e encontrão.
var main: Node
var frame := 0
var player: Player
var zs: Array = []
var log_climb := false

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _park_zombies() -> void:
	for i in zs.size():
		zs[i].detect_range = 0.0
		zs[i]._alerted = false
		zs[i].global_position = Vector3(-30 + i * 3, 0, 30)

func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	player._unhandled_input(ev)

func _look_at_point(p: Vector3) -> void:
	var to := p - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())

func _physics_process(_d: float) -> bool:
	frame += 1
	match frame:
		2:
			player = main.get_node("Player")
			zs = main.get_node("Enemies").get_children()
			_park_zombies()
			print("start weapon=", Player.WeaponType.keys()[player._weapon_type], " slots empty=", player.inventory.slots.all(func(s): return s.is_empty()))
		# --- Inventário: pegar espada do mapa ---
		5:
			var sword: PickupItem = main.get_node("Props/Espada")
			player.global_position = sword.global_position + Vector3(0, -0.3, 1.3)
			player.global_position.y = 0.0
		8:
			_look_at_point(main.get_node("Props/Espada").global_position)
		12:
			_press("interact")
		16:
			print("picked sword: slot0=", player.inventory.slots[0], " weapon=", Player.WeaponType.keys()[player._weapon_type])
			player.inventory.add(&"sucata", 15)
			print("materials into backpack: slot5=", player.inventory.slots[5], " slot6=", player.inventory.slots[6])
			player.inventory.select(1)
		20:
			print("slot 2 selected (empty) -> weapon=", Player.WeaponType.keys()[player._weapon_type])
		# --- Soco ---
		22:
			zs[0].global_position = player.global_position + Vector3(0, 0, -1.2)
			zs[0].rotation.y = 0.0
			player.rotation.y = 0.0
			player.head.rotation.x = -0.05
		36:
			player._punch()
		41:
			print("punch: z0 hp=", zs[0].health, " state=", Zombie.State.keys()[zs[0].state])
		# --- Bloqueio: perfeito e normal ---
		42:
			player.inventory.select(0)
		60:
			Input.action_press("block")
		62:
			var hp := player.health
			player.take_damage(12.0, Vector3(0, 0, 1), zs[0])
			print("parry: dmg=", hp - player.health, " z0 state=", Zombie.State.keys()[zs[0].state])
		90:
			var hp := player.health
			player.take_damage(12.0, Vector3(0, 0, 1), zs[0])
			print("block: dmg=", snappedf(hp - player.health, 0.01))
			Input.action_release("block")
		# --- Agachar ---
		95:
			_park_zombies()
			player.global_position = Vector3(0, 0, 12)
			player.rotation.y = 0.0
			_press("crouch")
		110:
			print("crouch: capsule h=", player.parkour._shape.height, " eye=", snappedf(player.head.position.y, 0.01))
			_press("crouch")
		125:
			print("stand: capsule h=", player.parkour._shape.height)
		# --- Deslizar por baixo de um zumbi ---
		130:
			zs[1].global_position = Vector3(0, 0, 8.5)
			zs[1].rotation.y = PI
			player.global_position = Vector3(0, 0, 12)
			player.velocity = Vector3(0, 0, -6.5)
			Input.action_press("sprint")
			Input.action_press("move_forward")
		134:
			_press("crouch")
			print("slide started: move=", Parkour.Move.keys()[player.parkour.move])
		175:
			print("slide: player z=", snappedf(player.global_position.z, 0.01), " zombie state=", Zombie.State.keys()[zs[1].state])
			Input.action_release("sprint")
			Input.action_release("move_forward")
		# --- Vault na barreira (0.9 m, fina) correndo ---
		180:
			_park_zombies()
			player.global_position = Vector3(4, 0, 6.4)
			player.rotation.y = 0.0
			player.head.rotation.x = 0.0
			Input.action_press("sprint")
			Input.action_press("move_forward")
		186:
			print("vault: started=", player.parkour.try_traverse(true), " move=", Parkour.Move.keys()[player.parkour.move])
		230:
			print("  after vault z=", snappedf(player.global_position.z, 0.01), " (barreira em z=5)")
			Input.action_release("sprint")
			Input.action_release("move_forward")
		# --- Carro ao longo (comprido): sobe em cima ---
		235:
			player.global_position = Vector3(-3, 0, -9.3)
			player.rotation.y = 0.0
		238:
			print("car lengthwise: started=", player.parkour.try_traverse(true), " move=", Parkour.Move.keys()[player.parkour.move])
		280:
			print("  on car y=", snappedf(player.global_position.y, 0.01))
		# --- Contêiner 2.1 m: escala ---
		285:
			player.global_position = Vector3(8, 0, 12.6)
			player.rotation.y = 0.0
		288:
			print("container: started=", player.parkour.try_traverse(false), " move=", Parkour.Move.keys()[player.parkour.move])
		340:
			print("  on container y=", snappedf(player.global_position.y, 0.01))
		# --- Cerca 1.9 m fina: passa por cima ---
		345:
			player.global_position = Vector3(-6, 0, -16.6)
			player.rotation.y = 0.0
		348:
			print("fence: started=", player.parkour.try_traverse(false), " move=", Parkour.Move.keys()[player.parkour.move])
		410:
			print("  after fence z=", snappedf(player.global_position.z, 0.01), " y=", snappedf(player.global_position.y, 0.01), " (cerca em z=-17.5)")
		# --- Lanterna: atrai zumbi longe que está de frente ---
		415:
			player.global_position = Vector3(0, 0, 25)
			player.rotation.y = 0.0
			player.inventory.add(&"lanterna")
			zs[2].global_position = Vector3(0, 0, -10)
			zs[2].rotation.y = PI # olhando para +Z (para o player)
			zs[2].detect_range = 22.0
			zs[3].global_position = Vector3(4, 0, -10)
			zs[3].rotation.y = 0.0 # de costas
			zs[3].detect_range = 22.0
		418:
			_look_at_point(zs[2].global_position + Vector3.UP * 1.4)
			_press("flashlight")
		430:
			print("flashlight on=", player.is_flashlight_on(), " facing zombie alerted=", zs[2]._alerted, " state=", Zombie.State.keys()[zs[2].state])
			_look_at_point(zs[3].global_position + Vector3.UP * 1.4)
		445:
			print("  back-turned zombie alerted=", zs[3]._alerted)
			_press("flashlight")
			_park_zombies()
		# --- Navegação: contorna o muro ---
		450:
			zs[2].global_position = Vector3(11, 0, 2)
			zs[2].detect_range = 50.0
			zs[2].target = player
			player.global_position = Vector3(6, 0, 2)
		520:
			var path: PackedVector3Array = zs[2]._agent.get_current_navigation_path()
			print("nav: path points=", path.size(), " zombie pos=", zs[2].global_position.snapped(Vector3.ONE * 0.1), " (muro em x=9, z -1..5)")
			_park_zombies()
		# --- Zumbi escala a cerca (volta seria > 2x) ---
		525:
			zs[4].global_position = Vector3(0, 0.2, -21)
			zs[4].rotation.y = PI
			zs[4].detect_range = 50.0
			zs[4].target = player
			player.global_position = Vector3(0, 0, -12)
			log_climb = true
		# --- Arma de zumbi cai quando ele morre ---
		700:
			log_climb = false
			print("climb: zombie z=", snappedf(zs[4].global_position.z, 0.01), " state=", Zombie.State.keys()[zs[4].state])
			_park_zombies()
			zs[0]._equip_weapon(&"taco")
			zs[0].global_position = Vector3(20, 0, 0)
		705:
			zs[0].take_hit(HitInfo.make(999, &"Chest", zs[0].global_position + Vector3.UP, Vector3.FORWARD, 10))
		710:
			var dropped := main.get_node("Enemies").get_children().filter(func(n): return n is PickupItem)
			print("zombie weapon dropped: ", dropped.map(func(n): return n.item_id))
		# --- Empalar de lado não pega ---
		712:
			var z: Zombie = zs[1]
			z._set_state(Zombie.State.IDLE)
			z.rotation.y = PI / 2
			print("impale sideways=", z.can_be_impaled(Vector3(0, 0, -1)), " front=", (func(): z.rotation.y = 0.0; return z.can_be_impaled(Vector3(0, 0, -1))).call(),
				" back=", (func(): z.rotation.y = PI; return z.can_be_impaled(Vector3(0, 0, -1))).call())
		# --- Membro quebrado: dano reduzido ---
		714:
			var z: Zombie = zs[2]
			z.max_health = 1000.0
			z.health = 1000.0
			z.global_position = Vector3(25, 0, 0)
			z.take_hit(HitInfo.make(40, &"UpperArm.L", z.global_position, Vector3.FORWARD, 5))
			var before := z.health
			z.take_hit(HitInfo.make(40, &"UpperArm.L", z.global_position, Vector3.FORWARD, 5))
			print("broken arm hit dmg=", snappedf(before - z.health, 0.01), " (sem quebra seria 24)")
		# --- Encontrão ---
		720:
			var a: Zombie = zs[3]
			var b: Zombie = zs[1]
			a._set_state(Zombie.State.IDLE)
			b._set_state(Zombie.State.IDLE)
			a.global_position = Vector3(-20, 0, 0)
			b.global_position = Vector3(-20, 0, -1.3)
			a.rotation.y = 0.0
			a.balance = 1.0
			a.take_hit(HitInfo.make(1, &"Chest", a.global_position + Vector3.UP, Vector3(0, 0, -1), 60))
		760:
			print("bump: pusher=", Zombie.State.keys()[zs[3].state], " bumped=", Zombie.State.keys()[zs[1].state], " b moved=", snappedf(-1.3 - zs[1].global_position.z, 0.01))
			quit()
	if log_climb and frame % 25 == 0:
		print("  climb f", frame, " z=", snappedf(zs[4].global_position.z, 0.01), " y=", snappedf(zs[4].global_position.y, 0.01),
			" state=", Zombie.State.keys()[zs[4].state], " climb_mode=", zs[4]._climb_mode)
	return false
