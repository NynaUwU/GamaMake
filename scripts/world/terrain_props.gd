class_name TerrainProps
extends RefCounted
## Árvores, pinheiros, cactos e rochas espalhados por bioma em cada chunk.
## Visual em blocos (como os personagens), desenhado com MultiMesh (barato) e
## colisão simples no tronco/rocha. Posições vêm de um RNG com a semente do
## mapa + coordenada do chunk, então o mesmo mapa sempre tem as mesmas árvores.

const CANDIDATES := 24 ## pontos testados por chunk
const CACTUS_KINDS := ["cactus_a", "cactus_b", "cactus_c"]

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
		if kind.begins_with("cactus"):
			scale = rng.randf_range(1.15, 1.8) # cactos grandes
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
	# Chance por ponto testado (CANDIDATES por chunk). A neve é a mais densa.
	var weights := [
		["tree", biome.plains * 0.26], ["bush", biome.plains * 0.09],
		["cactus", biome.desert * 0.11], ["dead_bush", biome.desert * 0.07],
		["pine", biome.winter * 0.85], ["rock", biome.mountain * 0.22 + biome.winter * 0.03],
	]
	for pair in weights:
		if roll < pair[1]:
			if pair[0] == "cactus":
				return CACTUS_KINDS[rng.randi() % CACTUS_KINDS.size()]
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
		var cactus := kind.begins_with("cactus")
		cylinder.radius = (0.3 if cactus else 0.2) * scale
		cylinder.height = (3.2 if cactus else 2.4) * scale
		shape.shape = cylinder
		shape.position = local + Vector3.UP * cylinder.height * 0.5
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
		"cactus_a":
			# Tronco que entorta para um lado e dois braços tortos.
			var green := Color(0.3, 0.45, 0.22)
			var top := _chain(st, Vector3.ZERO, [Vector3(0.05, 1.2, 0), Vector3(0.15, 1.1, 0.05), Vector3(-0.1, 1.0, 0.1)], 0.55, green)
			_chain(st, Vector3(0.1, 1.3, 0), [Vector3(0.6, 0.15, 0), Vector3(0.1, 0.9, 0.1), Vector3(-0.1, 0.5, 0)], 0.38, green)
			_chain(st, Vector3(0.05, 1.9, 0), [Vector3(-0.55, 0.2, 0.1), Vector3(-0.15, 0.7, -0.05)], 0.34, green)
			_box(st, top + Vector3(0, 0.08, 0), Vector3(0.3, 0.16, 0.3), Color(0.75, 0.45, 0.6)) # florzinha
		"cactus_b":
			# Alto e inclinado, um braço só que sobe torto.
			var green := Color(0.28, 0.42, 0.2)
			_chain(st, Vector3.ZERO, [Vector3(0.1, 1.4, 0.05), Vector3(0.25, 1.3, -0.05), Vector3(0.15, 1.0, 0.1)], 0.5, green)
			_chain(st, Vector3(0.2, 1.6, 0), [Vector3(0.1, 0.1, 0.55), Vector3(-0.05, 1.0, 0.15), Vector3(0.1, 0.4, -0.05)], 0.36, green)
		"cactus_c":
			# Baixo e gordo, com três braços caídos para os lados.
			var green := Color(0.33, 0.48, 0.24)
			_chain(st, Vector3.ZERO, [Vector3(0, 1.0, 0), Vector3(-0.1, 0.8, 0.05)], 0.75, green)
			_chain(st, Vector3(0, 1.1, 0), [Vector3(0.7, 0.3, 0.1), Vector3(0.15, 0.8, 0)], 0.42, green)
			_chain(st, Vector3(0, 0.9, 0), [Vector3(-0.65, 0.2, 0.2), Vector3(-0.2, 0.6, 0.05), Vector3(0.05, 0.35, 0)], 0.4, green)
			_chain(st, Vector3(0, 1.4, 0), [Vector3(0.05, 0.25, -0.6), Vector3(0, 0.7, -0.1)], 0.36, green)
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


## Sequência de gomos tortos: cada passo é um bloco do ponto atual até +passo.
## Devolve a ponta final (para pôr enfeite em cima).
static func _chain(st: SurfaceTool, start: Vector3, steps: Array, thickness: float, color: Color) -> Vector3:
	var point := start
	var t := thickness
	for step in steps:
		var next: Vector3 = point + step
		_segment(st, point, next, t, color)
		point = next
		t *= 0.88
	return point


## Bloco ligando dois pontos (com sobra nas pontas para os gomos se encaixarem).
static func _segment(st: SurfaceTool, from: Vector3, to: Vector3, thickness: float, color: Color) -> void:
	var dir := to - from
	var up := dir.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up, side.cross(up))
	_box(st, (from + to) * 0.5, Vector3(thickness, dir.length() + thickness * 0.5, thickness), color, basis)


## Caixa com cor por vértice (6 faces, normais por face), opcionalmente girada.
static func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY) -> void:
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
				st.add_vertex(center + basis * c[face[k]])
