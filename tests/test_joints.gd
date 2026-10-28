extends SceneTree
## Força joelho/cotovelo a girar nos dois sentidos e mede onde o limite segura.
var zs := []
var frame := 0

func _initialize() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	root.add_child(floor_body)
	for i in 2:
		var z: Zombie = load("res://scenes/zombie.tscn").instantiate()
		z.position = Vector3(i * 3, 0, 0)
		root.add_child(z)
		zs.append(z)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		for z in zs:
			z.ragdoll.start()
	if frame > 5 and frame < 60:
		for i in 2:
			var r: Ragdoll = zs[i].ragdoll
			var w := 10.0 if i == 0 else -10.0
			for pair in [["UpperLeg.L", "LowerLeg.L"], ["UpperArm.L", "LowerArm.L"]]:
				var a := r.get_bone_body(pair[0])
				var b := r.get_bone_body(pair[1])
				b.angular_velocity = a.angular_velocity + a.global_basis.x * w
	if frame == 60:
		for i in 2:
			var r: Ragdoll = zs[i].ragdoll
			for pair in [["UpperLeg.L", "LowerLeg.L"], ["UpperArm.L", "LowerArm.L"]]:
				var rel := (r.get_bone_body(pair[0]).global_basis.inverse() * r.get_bone_body(pair[1]).global_basis).get_euler()
				print("w=", 10 if i == 0 else -10, " ", pair[1], " relX=", snappedf(rad_to_deg(rel.x), 1))
		quit()
	return false
