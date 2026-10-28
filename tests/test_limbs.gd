extends SceneTree
## Teste dos membros: quebrar (impacto), arrancar (corte), rastejar sem perna,
## explosão despedaçando e as etapas de levantar.
var main: Node
var frame := 0
var zs: Array = []

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _place(z: Zombie, pos: Vector3) -> void:
	z.global_position = pos
	z.rotation.y = 0.0
	z.detect_range = 0.0
	z.max_health = 1000.0
	z.health = 1000.0

func _hit(damage: float, bone: StringName, z: Zombie, type: HitInfo.Type, force := 20.0) -> HitInfo:
	return HitInfo.make(damage, bone, z.global_position + Vector3.UP, Vector3(0, 0, 1), force, type)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		zs = main.get_node("Enemies").get_children()
		for i in zs.size():
			_place(zs[i], Vector3(i * 4 - 6, 0, -4))
	if frame == 5:
		# 1) Braço quebrado por impacto: fica mole, continua no corpo.
		zs[0].take_hit(_hit(40, &"UpperArm.L", zs[0], HitInfo.Type.BLUNT))
		print("blunt arm: state=", Zombie.LimbState.keys()[zs[0]._limb_state[&"ArmL"]],
			" limp=", zs[0].limp_limbs.is_limp(&"LowerArm.L"), " cut=", zs[0]._cut_bones, " arms=", zs[0]._arm_count())
		# 2) Golpe de cima (bias braço) arranca o braço de uma vez.
		var overhead := _hit(34 * 1.5, &"UpperArm.R", zs[1], HitInfo.Type.CUT, 45)
		overhead.limb_bias = {"head": 0.7, "leg": 0.3, "arm": 2.4}
		zs[1].take_hit(overhead)
		print("overhead cut arm: state=", Zombie.LimbState.keys()[zs[1]._limb_state[&"ArmR"]], " cut=", zs[1]._cut_bones)
		# 3) Golpe horizontal na perna: arranca e o zumbi cai para rastejar.
		var low := _hit(34, &"LowerLeg.L", zs[2], HitInfo.Type.CUT, 30)
		low.limb_bias = {"head": 2.0, "leg": 1.8, "arm": 0.8}
		zs[2].take_hit(low)
		print("leg cut: crawler=", zs[2].crawler, " state=", Zombie.State.keys()[zs[2].state], " cut=", zs[2]._cut_bones)
		# 4) Explosão que mata: despedaça.
		zs[3].max_health = 50.0
		zs[3].health = 50.0
		zs[3].take_explosion(zs[3].global_position + Vector3(0.5, 0.3, 0.5), 70.0, 450.0)
		print("explosion kill: state=", Zombie.State.keys()[zs[3].state], " cut=", zs[3]._cut_bones.size(), " bones")
	if frame == 60:
		var hand: Node3D = zs[0].skeleton.get_node(HumanoidRig.attachment_name("LowerArm.L"))
		print("limp hand height=", snappedf(hand.global_position.y, 0.01), " (pendurado, abaixo do ombro ~1.35)")
	if frame == 300:
		print("crawler after get up: state=", Zombie.State.keys()[zs[2].state], " mode=",
			ZombieLocomotion.Mode.keys()[zs[2].locomotion.mode])
		var head: Node3D = zs[2].skeleton.get_node("Att_Head")
		print("  crawler head height=", snappedf(head.global_position.y, 0.01))
	# 5) Levantar em etapas: derruba um zumbi e acompanha as poses.
	if frame == 310:
		zs[1].balance = 2.0
		zs[1].take_hit(_hit(5, &"Chest", zs[1], HitInfo.Type.BLUNT, 80))
	if frame > 310 and frame % 20 == 0 and frame < 640:
		var z: Zombie = zs[1]
		var hips := z.skeleton.global_transform * z.skeleton.get_bone_global_pose(0).origin
		print("f", frame, " ", Zombie.State.keys()[z.state], " mode=", ZombieLocomotion.Mode.keys()[z.locomotion.mode],
			" getup_t=", snappedf(z.locomotion.getup_t, 0.01), " face_down=", z.locomotion.getup_face_down, " hips y=", snappedf(hips.y, 0.01))
	if frame == 640:
		quit()
	return false
