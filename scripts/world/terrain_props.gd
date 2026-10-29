class_name TerrainProps
extends RefCounted
## Árvores, pinheiros, cactos e rochas espalhados por bioma em cada chunk.
## Visual em blocos (como os personagens), desenhado com MultiMesh (barato) e
## colisão simples no tronco/rocha. Posições vêm de um RNG com a semente do
## mapa + coordenada do chunk, então o mesmo mapa sempre tem as mesmas árvores.

const CANDIDATES := 14 ## pontos testados por chunk

static var _meshes := {}


func populate(world: TerrainWorld, chunk: Node3D, body: StaticBody3D, coord: Vector2i, origin: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.seed, coord.x, coord.y])
	var placed := {} # tipo -> Array[Transform3D]
	for n in CANDIDATES:
		var x := origin.x + rng.randf() * world.chunk_size
		var z := origin.y + rng.randf() * world.chunk_size
		if Vector2(x, z).length() < world.town_radius * 2.0:
			continue # deixa a cidade e o entorno livres
		var biome := world.biome_at(x, z)
		var kind := _pick_kind(biome, rng)
		if kind == "":
			continue
		var y := world.height_at(x, z)
		var scale := rng.randf_range(0.8, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
		if kind == "rock":
			basis = basis.scaled(Vector3(rng.randf_range(0.8, 1.6), rng.randf_range(0.5, 1.0), rng.randf_range(0.8, 1.6)))
		var local := Vector3(x - origin.x, y - 0.1, z - origin.y)
		if not placed.has(kind):
			placed[kind] = []
		placed[kind].append(Transform3D(basis, local))
		_add_collision(body, kind, local, scale)
	for kind in placed:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = false
		multimesh.mesh = _mesh(kind)
		multimesh.instance_count = placed[kind].size()
		for i in placed[kind].size():
			multimesh.set_instance_transform(i, placed[kind][i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		chunk.add_child(instance)


func _pick_kind(biome: Dictionary, rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	var weights := [
		["tree", biome.plains * 0.45], ["bush", biome.plains * 0.15],
		["cactus", biome.desert * 0.18], ["dead_bush", biome.desert * 0.12],
		["pine", biome.winter * 0.55], ["rock", biome.mountain * 0.35 + biome.winter * 0.08],
	]
	for pair in weights:
		if roll < pair[1]:
			return pair[0]
		roll -= pair[1]
	return ""


func _add_collision(body: StaticBody3D, kind: String, local: Vector3, scale: float) -> void:
	if kind in ["bush", "dead_bush"]:
		return
	var shape := CollisionShape3D.new()
	if kind == "rock":
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 1.0, 1.6) * scale
		shape.shape = box
		shape.position = local + Vector3.UP * 0.4 * scale
	else:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = (0.25 if kind == "cactus" else 0.2) * scale
		cylinder.height = 2.4 * scale
		shape.shape = cylinder
		shape.position = local + Vector3.UP * 1.2 * scale
	body.add_child(shape)


# --- Modelos (montados uma vez) -------------------------------------------------

static func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.33, 0.22, 0.13)
	match kind:
		"tree":
			_box(st, Vector3(0, 1.2, 0), Vector3(0.35, 2.4, 0.35), trunk)
			_box(st, Vector3(0, 3.0, 0), Vector3(2.2, 1.6, 2.2), Color(0.22, 0.38, 0.15))
			_box(st, Vector3(0.1, 4.1, -0.1), Vector3(1.4, 1.0, 1.4), Color(0.26, 0.43, 0.17))
		"bush":
			_box(st, Vector3(0, 0.35, 0), Vector3(1.0, 0.7, 0.9), Color(0.25, 0.4, 0.16))
		"pine":
			_box(st, Vector3(0, 1.0, 0), Vector3(0.3, 2.0, 0.3), trunk)
			var green := Color(0.12, 0.26, 0.16)
			var snow := Color(0.9, 0.93, 0.97)
			var y := 1.6
			for size in [2.4, 1.8, 1.2, 0.6]:
				_box(st, Vector3(0, y, 0), Vector3(size, 0.9, size), green)
				_box(st, Vector3(0, y + 0.48, 0), Vector3(size * 0.9, 0.08, size * 0.9), snow)
				y += 0.9
		"cactus":
			var cactus := Color(0.3, 0.45, 0.22)
			_box(st, Vector3(0, 1.2, 0), Vector3(0.45, 2.4, 0.45), cactus)
			_box(st, Vector3(0.45, 1.3, 0), Vector3(0.45, 0.3, 0.3), cactus)
			_box(st, Vector3(0.6, 1.75, 0), Vector3(0.3, 0.9, 0.3), cactus)
			_box(st, Vector3(-0.4, 1.0, 0), Vector3(0.4, 0.28, 0.28), cactus)
			_box(st, Vector3(-0.55, 1.35, 0), Vector3(0.28, 0.7, 0.28), cactus)
		"dead_bush":
			var dry := Color(0.45, 0.33, 0.2)
			_box(st, Vector3(0, 0.25, 0), Vector3(0.7, 0.5, 0.15), dry)
			_box(st, Vector3(0, 0.3, 0), Vector3(0.15, 0.6, 0.7), dry)
		"rock":
			_box(st, Vector3(0, 0.4, 0), Vector3(1.6, 1.0, 1.6), Color(0.45, 0.43, 0.41))
			_box(st, Vector3(0.3, 0.95, -0.2), Vector3(0.9, 0.5, 0.8), Color(0.5, 0.48, 0.46))
	st.generate_normals()
	var mesh := st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	mesh.surface_set_material(0, material)
	_meshes[kind] = mesh
	return mesh


## Caixa com cor por vértice (6 faces, normais por face).
static func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	var c := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var faces := [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]
	for face in faces:
		for tri in [[0, 2, 1], [0, 3, 2]]: # sentido horário = face da frente no Godot
			for k in tri:
				st.set_color(color)
				st.add_vertex(center + c[face[k]])
