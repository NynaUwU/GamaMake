extends SceneTree
## Teste do equilíbrio: golpes seguidos fazem o zumbi cambalear e depois cair.
## Também confere que os pés ficam no chão durante o tranco.
var main: Node
var frame := 0
var z: Zombie
var player: Player
var log_states := []

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _foot_height(side: String) -> float:
	var sk := z.skeleton
	var idx := sk.find_bone("LowerLeg." + side)
	var shin := sk.global_transform * sk.get_bone_global_pose(idx)
	return (shin * Vector3(0, -0.47, 0)).y

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
		z.detect_range = 0.0
	var hit_frames := [20, 50, 80, 110]
	if frame in hit_frames:
		z.take_hit(_hit(30, &"Chest", z.global_position + Vector3(0, 1.3, 0), Vector3(0, 0, 1), 30))
		print("hit f", frame, ": balance=", snappedf(z.balance, 0.01), " state=", Zombie.State.keys()[z.state])
	if frame == 28:
		print("  feet during stagger: L=", snappedf(_foot_height("L"), 0.01), " R=", snappedf(_foot_height("R"), 0.01),
			" lean=", z._lean.snapped(Vector2.ONE * 0.01))
	if frame == 90:
		print("  during stumble: crouch=", snappedf(z.locomotion.crouch, 0.01), " wobble=", snappedf(z.locomotion.wobble, 0.01),
			" flail=", snappedf(z.locomotion.flail, 0.01), " speed=", snappedf(z.locomotion.speed, 0.01),
			" feet L=", snappedf(_foot_height("L"), 0.01))
	if frame == 300:
		print("later: state=", Zombie.State.keys()[z.state], " balance=", snappedf(z.balance, 0.01))
		# leg hit: knee buckle
		z.take_hit(_hit(10, &"LowerLeg.L", z.global_position + Vector3(0, 0.4, 0), Vector3(0, 0, 1), 20))
		print("leg hit: buckle=", z._buckle, " state=", Zombie.State.keys()[z.state])
		quit()
	return false



## Monta um HitInfo a partir dos argumentos antigos (dano, osso, ponto, direção, força, derruba, corta).
func _hit(damage: float, bone: StringName, point: Vector3, direction: Vector3, force: float,
		knockdown := false, cut := false) -> HitInfo:
	var info := HitInfo.make(damage, bone, point, direction, force,
			HitInfo.Type.CUT if cut else HitInfo.Type.BLUNT)
	info.knockdown = knockdown
	return info
