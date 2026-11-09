class_name ChemPlant
extends RefCounted
## Fábrica química abandonada (centro de uma zona contaminada): laje de concreto, três
## tanques enferrujados vazando verde, chaminé de tijolo soltando fumaça tóxica, a
## tubulação em cavaletes, barris tombados com poças, o galpão do escritório e a
## cerca caída. Três caixotes com o saque "contaminado" (cada um só uma vez por mundo).

const CONCRETE := Color(0.46, 0.46, 0.44)
const RUST := [Color(0.45, 0.27, 0.17), Color(0.38, 0.33, 0.28), Color(0.52, 0.48, 0.4)]
const SLIME := Color(0.48, 0.62, 0.16)
const TANKS := [Vector3(-13, 0, -8), Vector3(-2, 0, -10), Vector3(9, 0, -8)]
const CHIMNEY := Vector3(17, 0, -12)
const SHED := Vector3(9, 0, 8)
const CRATES := [Vector3(4.5, 0, 6.5), Vector3(-6, 0, -1.5), Vector3(14.5, 0, 2.5)]


static func build(root: Node3D, index: int, zone: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = zone.seed
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.name = "Plant"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	# Laje (grossa para baixo: cobre o desnível do terreno) com rachaduras e manchas.
	mb.color(CONCRETE)
	mb.box(Vector3(0, -1.4, 0), Vector3(46, 3.0, 36))
	_box_shape(body, Vector3(0, -1.4, 0), Vector3(46, 3.0, 36))
	for k in 14:
		mb.color(CONCRETE.darkened(rng.randf_range(0.1, 0.25)))
		mb.box(Vector3(rng.randf_range(-21, 21), 0.105, rng.randf_range(-16, 16)), Vector3(rng.randf_range(2, 6), 0.01, 0.12),
			Basis(Vector3.UP, rng.randf() * PI))
	# Tanques: cilindro com domo, cinta, escada e o vazamento escorrendo até a poça.
	for k in TANKS.size():
		var at: Vector3 = TANKS[k]
		var color: Color = RUST[k % RUST.size()]
		var r := 3.6 + 0.4 * (k % 2)
		mb.color(color)
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.1), Vector2(r, 0.1), Vector2(r, 8.5), Vector2(r * 0.7, 9.6), Vector2(0.002, 10.0)]), 16, Basis.IDENTITY, at)
		mb.color(color.darkened(0.25))
		for y in [2.5, 5.5]:
			mb.lathe(PackedVector2Array([Vector2(r + 0.04, y), Vector2(r + 0.06, y + 0.3)]), 16, Basis.IDENTITY, at)
		mb.color(ObjectModels.IRON)
		var side := at + Vector3(0, 0, r + 0.15)
		for x in [-0.25, 0.25]:
			mb.box(side + Vector3(x, 4.5, 0), Vector3(0.06, 9.0, 0.06))
		for step in 18:
			mb.box(side + Vector3(0, 0.4 + step * 0.48, 0), Vector3(0.5, 0.04, 0.04))
		var leak := Vector3(cos(0.5 + k), 0, sin(0.5 + k)) # vazamento virado para a frente
		mb.color(SLIME)
		mb.box(at + leak * (r + 0.03) + Vector3(0, 1.6, 0), Vector3(0.35, 3.0, 0.05), Basis(Vector3.UP, atan2(leak.x, leak.z)))
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.11), Vector2(1.6 + k * 0.3, 0.11), Vector2(1.6 + k * 0.3, 0.13), Vector2(0.002, 0.13)]), 12,
			Basis.IDENTITY, at + leak * (r + 1.2))
		_cylinder_shape(body, at + Vector3(0, 5.0, 0), r, 10.0)
	# Chaminé de tijolo com cintas e boca preta.
	mb.color(ObjectModels.BRICK.darkened(0.15))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.1), Vector2(1.7, 0.1), Vector2(1.25, 24.0), Vector2(1.35, 24.4), Vector2(1.0, 24.4), Vector2(0.002, 23.0)]), 10, Basis.IDENTITY, CHIMNEY)
	mb.color(ObjectModels.IRON)
	for y in [6.0, 12.0, 18.0]:
		var rr := lerpf(1.7, 1.25, y / 24.0) + 0.05
		mb.lathe(PackedVector2Array([Vector2(rr, y), Vector2(rr, y + 0.3)]), 10, Basis.IDENTITY, CHIMNEY)
	_cylinder_shape(body, CHIMNEY + Vector3(0, 12.0, 0), 1.6, 24.0)
	# Tubulação nos cavaletes: dos tanques até o galpão.
	mb.color(ObjectModels.IRON)
	for x in [-13.0, -2.0, 9.0, 14.0]:
		mb.box(Vector3(x, 2.6, -3.0), Vector3(0.25, 5.2, 0.25))
		mb.box(Vector3(x, 5.2, -3.0), Vector3(0.25, 0.25, 1.4))
	for k in 3:
		mb.color(RUST[k].lightened(0.1))
		mb.tube(PackedVector3Array([Vector3(-14, 5.45, -3.4 + k * 0.4), Vector3(14.5, 5.45, -3.4 + k * 0.4), Vector3(14.5, 5.45, 4.0)]), 0.16, 6)
	for k in TANKS.size():
		mb.color(RUST[1])
		mb.tube(PackedVector3Array([TANKS[k] + Vector3(0, 8.0, 3.5), TANKS[k] + Vector3(0, 5.45, 5.0 + 0.4 * k)]), 0.14, 6)
	# Galpão do escritório: paredes de chapa, telhado inclinado, porta e janelas escuras.
	mb.color(RUST[2])
	mb.box(SHED + Vector3(0, 2.0, 0), Vector3(10, 4.0, 7))
	mb.color(RUST[2].darkened(0.3))
	mb.box(SHED + Vector3(0, 4.3, 0), Vector3(10.6, 0.25, 7.6), Basis(Vector3.RIGHT, 0.12))
	mb.color(Color(0.06, 0.06, 0.07))
	mb.box(SHED + Vector3(-2.5, 1.2, 3.52), Vector3(1.2, 2.4, 0.04)) # porta
	for x in [0.5, 3.0]:
		mb.box(SHED + Vector3(x, 2.4, 3.52), Vector3(1.4, 0.9, 0.04))
	mb.color(Color(0.85, 0.8, 0.2))
	mb.box(SHED + Vector3(-2.5, 2.9, 3.53), Vector3(1.0, 0.5, 0.02), Basis(Vector3.BACK, PI / 4)) # aviso na porta
	_box_shape(body, SHED + Vector3(0, 2.0, 0), Vector3(10, 4.0, 7))
	# Barris amarelos e azuis (uns tombados) com poças verdes.
	for k in 12:
		var at := Vector3(rng.randf_range(-20, 0), 0.1, rng.randf_range(2, 15))
		var tipped := rng.randf() < 0.35
		var color := Color(0.85, 0.66, 0.12) if k % 3 != 0 else Color(0.18, 0.32, 0.55)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * (Basis(Vector3.RIGHT, PI / 2) if tipped else Basis.IDENTITY)
		var center := at + (Vector3(0, 0.3, 0) if tipped else Vector3.ZERO)
		mb.color(color)
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.88), Vector2(0.002, 0.88)]), 10, basis, center + (basis * Vector3(0, -0.44, 0) if tipped else Vector3.ZERO))
		mb.color(color.darkened(0.3))
		for y in [0.25, 0.6]:
			mb.lathe(PackedVector2Array([Vector2(0.31, y), Vector2(0.31, y + 0.05)]), 10, basis, center + (basis * Vector3(0, -0.44, 0) if tipped else Vector3.ZERO))
		if tipped:
			mb.color(SLIME)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.11), Vector2(1.0, 0.11), Vector2(1.0, 0.125), Vector2(0.002, 0.125)]), 10, Basis.IDENTITY, at + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)))
		else:
			_cylinder_shape(body, at + Vector3(0, 0.44, 0), 0.3, 0.88)
	# Cerca de tela caída: postes em volta da laje (com o portão aberto na frente).
	mb.color(ObjectModels.IRON)
	for k in 28:
		var t := float(k) / 28.0
		var p := _rect_point(t, Vector2(24, 19))
		if p.y > 18.0 and absf(p.x) < 4.0:
			continue # portão
		var lean := Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25)) if rng.randf() < 0.3 else Basis.IDENTITY
		mb.box(Vector3(p.x, 1.0, p.y), Vector3(0.1, 2.0, 0.1), lean)
	var mesh := MeshInstance3D.new()
	mesh.name = "PlantMesh"
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	root.add_child(mesh)
	# Fumaça tóxica saindo da chaminé.
	var smoke := Contamination.i._haze(1.2, 26, 9.0, Vector2(4.0, 4.0)) if Contamination.i else null
	if smoke:
		var m := smoke.process_material as ParticleProcessMaterial
		m.direction = Vector3(0.3, 1, 0)
		m.spread = 12.0
		m.initial_velocity_min = 1.5
		m.initial_velocity_max = 2.5
		m.gravity = Vector3(0.6, 0.15, 0)
		smoke.position = CHIMNEY + Vector3(0, 24.5, 0)
		root.add_child(smoke)
	# Caixotes com o saque da zona.
	for k in CRATES.size():
		var box := LootBox.new()
		box.name = "Loot_%d" % k
		box.setup("loot_plant_%d_%d" % [zone.seed, k], "caixote", "contaminado")
		box.position = CRATES[k] + Vector3(0, 0.1, 0)
		box.rotation.y = rng.randf_range(-0.5, 0.5)
		root.add_child(box)


## Ponto no contorno do retângulo (t de 0 a 1 dá a volta).
static func _rect_point(t: float, half: Vector2) -> Vector2:
	var perimeter := 4.0 * (half.x + half.y)
	var d := t * perimeter
	if d < 2.0 * half.x:
		return Vector2(-half.x + d, -half.y)
	d -= 2.0 * half.x
	if d < 2.0 * half.y:
		return Vector2(half.x, -half.y + d)
	d -= 2.0 * half.y
	if d < 2.0 * half.x:
		return Vector2(half.x - d, half.y)
	d -= 2.0 * half.x
	return Vector2(-half.x, half.y - d)


static func _box_shape(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)


static func _cylinder_shape(body: StaticBody3D, center: Vector3, radius: float, height: float) -> void:
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	shape.position = center
	body.add_child(shape)
