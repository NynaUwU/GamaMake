extends SceneTree
func _box(root: Node3D, pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var s := CollisionShape3D.new()
	s.shape = BoxShape3D.new()
	s.shape.size = size
	b.add_child(s)
	root.add_child(b)
	b.global_position = pos
func _run(step_h: float) -> float:
	var root := Node3D.new()
	get_root().add_child(root)
	_box(root, Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	_box(root, Vector3(0, step_h / 2.0, 5), Vector3(6, step_h, 4))
	var body := CharacterBody3D.new()
	var s := CollisionShape3D.new()
	s.shape = CapsuleShape3D.new()
	s.shape.radius = 0.35
	s.shape.height = 1.8
	s.position.y = 0.9
	body.add_child(s)
	root.add_child(body)
	body.global_position = Vector3(0, 0.0, 0)
	for k in 150:
		await physics_frame
		body.velocity.x = 0.0
		body.velocity.z = 4.0
		if not body.is_on_floor():
			body.velocity.y -= 20.0 / 60.0
		StepClimb.step(body, 1.0 / 60.0)
		body.move_and_slide()
	var z := body.global_position.z
	var y := body.global_position.y
	root.queue_free()
	await process_frame
	print("degrau %.2f m -> z=%.2f y=%.2f %s" % [step_h, z, y, "SUBIU" if z > 4.0 else "barrado"])
	return z
func _init() -> void:
	await process_frame
	for h in [0.2, 0.4, 0.45, 0.5, 0.8]:
		await _run(h)
	quit()
