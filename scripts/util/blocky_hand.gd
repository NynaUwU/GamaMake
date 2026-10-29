class_name BlockyHand
## Mão em blocos (seres vivos são em blocos): palma, 4 dedos com 2 gomos e
## polegar. Dois jeitos:
##   fist(): mão fechada segurando algo (primeira pessoa). Origem = centro da
##           empunhadura; o objeto segurado passa ao longo do eixo Z.
##   open(): mão pendurada no fim do antebraço (corpo/zumbi). Origem = pulso,
##           dedos para baixo (-Y), palma virada para dentro (X).


## left = mão esquerda (espelhada em X).
static func fist(material: Material, shadows := false, left := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Hand"
	root.set_meta("mirror", left)
	# Palma por fora do cabo (lado +X) e dedos dando a volta por cima/frente.
	_block(root, material, Vector3(0.03, 0.0, 0.0), Vector3(0.03, 0.075, 0.085), shadows)
	for i in 4:
		var z := -0.031 + i * 0.0207
		_block(root, material, Vector3(0.006, 0.033, z), Vector3(0.045, 0.02, 0.018), shadows)
		_block(root, material, Vector3(-0.02, 0.012, z), Vector3(0.018, 0.035, 0.018), shadows)
	# Polegar por baixo, cruzando o cabo.
	_block(root, material, Vector3(0.0, -0.032, -0.02), Vector3(0.05, 0.02, 0.022), shadows, Basis(Vector3.UP, 0.4))
	return root


static func open(material: Material, claw := false, shadows := GeometryInstance3D.SHADOW_CASTING_SETTING_ON) -> Node3D:
	var root := Node3D.new()
	root.name = "Hand"
	_block(root, material, Vector3(0, -0.05, 0), Vector3(0.035, 0.09, 0.09), shadows)
	# Zumbi: dedos tortos e abertos, como garras. Humano: retos e juntos.
	var bend := 0.5 if claw else 0.15
	for i in 4:
		var z := -0.033 + i * 0.022
		var spread := (i - 1.5) * (0.12 if claw else 0.03)
		var base := Vector3(0, -0.1, z)
		var b1 := Basis(Vector3.BACK, 0.0).rotated(Vector3.RIGHT, spread)
		_block(root, material, base + b1 * Vector3(0, -0.018, 0), Vector3(0.02, 0.036, 0.018), shadows, b1)
		var tip := base + b1 * Vector3(0, -0.036, 0)
		var b2 := Basis(Vector3.BACK, bend).rotated(Vector3.RIGHT, spread)
		_block(root, material, tip + b2 * Vector3(0, -0.015, 0), Vector3(0.018, 0.03, 0.016), shadows, b2)
	var thumb := Basis(Vector3.BACK, 0.6 if claw else 0.4)
	_block(root, material, Vector3(0.022, -0.06, -0.035) + thumb * Vector3(0, -0.02, 0), Vector3(0.018, 0.045, 0.018), shadows, thumb)
	return root


static func _block(parent: Node3D, material: Material, pos: Vector3, size: Vector3, shadows, basis := Basis.IDENTITY) -> void:
	if parent.get_meta("mirror", false):
		pos.x = -pos.x
		var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
		basis = (m * basis * m).orthonormalized() # mesma rotação, espelhada
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.transform = Transform3D(basis, pos)
	if shadows is bool:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		mesh.cast_shadow = shadows
	parent.add_child(mesh)
