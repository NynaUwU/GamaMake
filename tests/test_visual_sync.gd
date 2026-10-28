extends SceneTree
## Confere se o visual (BoneAttachment) acompanha os ossos físicos no ragdoll.
var z: Zombie
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
	z = load("res://scenes/zombie.tscn").instantiate()
	root.add_child(z)
func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		z.take_hit(10, &"Chest", z.global_position + Vector3(0, 1.3, 0), Vector3(0, 0.2, 1).normalized(), 95, true)
	if frame in [20, 60]:
		var att: Node3D = z.skeleton.get_node("Att_Head")
		var pb := z.ragdoll.get_bone_body(&"Head")
		var pose := z.skeleton.global_transform * z.skeleton.get_bone_global_pose(z.skeleton.find_bone("Head"))
		print("f", frame, " visual head=", att.global_position.snapped(Vector3.ONE*0.01), " physics head=", pb.global_position.snapped(Vector3.ONE*0.01), " pose=", pose.origin.snapped(Vector3.ONE*0.01), " sim=", z.ragdoll.is_simulating_physics(), " infl=", z.ragdoll.influence)
	if frame == 61:
		quit()
	return false
