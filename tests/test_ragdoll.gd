extends SceneTree
## Teste headless: derruba um zumbi e confere estabilidade e ângulos das juntas.
## Rodar: godot --headless -s res://tests/test_ragdoll.gd

var zombie: Zombie
var frame := 0

func _initialize() -> void:
	var root3d := Node3D.new()
	root.add_child(root3d)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	root3d.add_child(floor_body)
	zombie = load("res://scenes/zombie.tscn").instantiate()
	root3d.add_child(zombie)

func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		zombie.balance = 1.0 # já tonto: o chute derruba
		zombie.take_hit(_hit(10, &"Chest", zombie.global_position + Vector3(0, 1.3, 0), Vector3(0, 0, 1), 90, true))
		print("state after kick: ", Zombie.State.keys()[zombie.state])
	if frame in [60, 120, 180]:
		_report()
	if frame == 200:
		zombie.global_position += Vector3(5, 0, 0)
	if frame == 202:
		print("hips after moving root (should stay): ", zombie.ragdoll.get_root_position())
	if frame == 260:
		print("state: ", Zombie.State.keys()[zombie.state], " root: ", zombie.global_position)
	if frame == 330:
		print("state after get up: ", Zombie.State.keys()[zombie.state])
		zombie.take_hit(_hit(500, &"Head", zombie.global_position + Vector3(0, 1.6, 0), Vector3(1, 0, 0), 60))
	if frame == 450:
		print("dead: ", Zombie.State.keys()[zombie.state])
		_report()
		quit()
	return false

func _report() -> void:
	var r := zombie.ragdoll
	var hips := r.get_root_position()
	print("f", frame, " hips=", hips.snapped(Vector3.ONE * 0.01), " speed=", snappedf(r.get_average_speed(), 0.01))
	for pair in [["UpperLeg.L", "LowerLeg.L"], ["UpperLeg.R", "LowerLeg.R"], ["UpperArm.L", "LowerArm.L"], ["UpperArm.R", "LowerArm.R"]]:
		var a := r.get_bone_body(pair[0]).global_basis
		var b := r.get_bone_body(pair[1]).global_basis
		var rel := (a.inverse() * b).get_euler()
		print("   ", pair[1], " rel X(deg)=", snappedf(rad_to_deg(rel.x), 1))
	var head := r.get_bone_body(&"Head").global_position
	print("   head-hips dist=", snappedf(head.distance_to(hips), 0.01))



## Monta um HitInfo a partir dos argumentos antigos (dano, osso, ponto, direção, força, derruba, corta).
func _hit(damage: float, bone: StringName, point: Vector3, direction: Vector3, force: float,
		knockdown := false, cut := false) -> HitInfo:
	var info := HitInfo.make(damage, bone, point, direction, force,
			HitInfo.Type.CUT if cut else HitInfo.Type.BLUNT)
	info.knockdown = knockdown
	return info
