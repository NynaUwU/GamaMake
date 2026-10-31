class_name TerrainProps
extends RefCounted
## Árvores, pinheiros, cactos e rochas espalhados por bioma em cada chunk.
## Visual em blocos (como os personagens), desenhado com MultiMesh (barato) e
## colisão simples no tronco/rocha. Posições vêm de um RNG com a semente do
## mapa + coordenada do chunk, então o mesmo mapa sempre tem as mesmas árvores.

const CANDIDATES := 44 ## pontos testados por chunk (árvores, cactos, rochas...)
const GROUND_CANDIDATES := 150 ## tufos de grama/arbustos de folhas cruzadas por chunk
const PICKUP_SCENE := preload("res://scenes/props/pickup_item.tscn")
const FOLIAGE := ["grass", "leafy_bush"]
const CACTUS_KINDS := ["cactus_a", "cactus_b", "cactus_c"]

static var _meshes := {}
static var _foliage_material: StandardMaterial3D


## Parte pesada (roda na thread do terreno): sorteia onde fica cada planta.
func plan(world: TerrainWorld, coord: Vector2i, origin: Vector2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.seed, coord.x, coord.y])
	var placed := {} # tipo -> Array[Transform3D] (folhagem: [Transform3D, Color])
	var collisions := []
	var fruits := []
	for n in CANDIDATES:
		var x := origin.x + rng.randf() * world.chunk_size
		var z := origin.y + rng.randf() * world.chunk_size
		if Vector2(x, z).length() < world.town_radius * 2.0:
			continue # deixa a cidade e o entorno livres
		if world.city_mask(x, z) > 0.0:
			continue # nada de árvores dentro das cidades geradas
		if _in_lake(world, x, z, 1.08):
			continue # nem dentro dos lagos
		if not world.track.is_empty() and RaceTrack.flatten_weight(world.track, Vector2(x, z)) > 0.0:
			continue # nem na pista
		var biome := world.biome_at(x, z)
		var kind := _pick_kind(biome, rng)
		if kind == "":
			continue
		var y := world._height_from(x, z, biome) # reaproveita o bioma já calculado
		var scale := rng.randf_range(0.8, 1.35)
		if kind.begins_with("cactus"):
			scale = rng.randf_range(1.15, 1.8) # cactos grandes
		elif kind == "giant_tree":
			scale = rng.randf_range(0.9, 1.25)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
		if kind == "rock":
			basis = basis.scaled(Vector3(rng.randf_range(0.8, 1.6), rng.randf_range(0.5, 1.0), rng.randf_range(0.8, 1.6)))
		var local := Vector3(x - origin.x, y - 0.1, z - origin.y)
		if not placed.has(kind):
			placed[kind] = []
		placed[kind].append(Transform3D(basis, local))
		collisions.append([kind, local, scale, placed[kind].size() - 1])
		if kind == "fruit_tree":
			for k in rng.randi_range(2, 3):
				var a := rng.randf() * TAU
				fruits.append(local + basis * Vector3(cos(a) * 1.3, 2.2 + rng.randf() * 0.5, sin(a) * 1.3))
	_populate_ground(world, rng, origin, placed)
	return {"placed": placed, "collisions": collisions, "fruits": fruits}


## Parte leve (thread principal): cria MultiMeshes, colisões e frutas.
func apply(data: Dictionary, chunk: Node3D, body: StaticBody3D) -> void:
	var multimeshes := {}
	for i in data.fruits.size():
		var pos: Vector3 = data.fruits[i]
		var fruit: PickupItem = PICKUP_SCENE.instantiate()
		fruit.item_id = &"fruta"
		fruit.net_key = "%s_f%d" % [chunk.name, i] # igual em todos os jogadores
		fruit.freeze = true # fica presa no galho até alguém pegar
		chunk.add_child(fruit)
		fruit.position = pos
	var placed: Dictionary = data.placed
	for kind in placed:
		var foliage: bool = kind in FOLIAGE
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = foliage
		multimesh.mesh = _foliage_mesh(kind) if foliage else _mesh(kind)
		multimesh.instance_count = placed[kind].size()
		for i in placed[kind].size():
			if foliage:
				multimesh.set_instance_transform(i, placed[kind][i][0])
				multimesh.set_instance_color(i, placed[kind][i][1])
			else:
				multimesh.set_instance_transform(i, placed[kind][i])
		multimeshes[kind] = multimesh
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		if foliage:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # grama não suja de sombra
		chunk.add_child(instance)
	# Árvores, rochas e veios viram ResourceNode (derrubar/minerar); o resto só colide.
	for ci in data.collisions.size():
		var c: Array = data.collisions[ci]
		if not (c[0] in ResourceNode.TREES or c[0] in ResourceNode.STONES):
			_add_collision(body, c[0], c[1], c[2])
			continue
		var node := ResourceNode.new()
		node.setup("%s_r%d" % [chunk.name, ci], c[0], multimeshes.get(c[0]), c[3], c[2])
		node.position = c[1]
		chunk.add_child(node)
		if Net.i.taken.has(node.key):
			node.gone(false) # já derrubada/quebrada neste mundo
		if c[0] in ResourceNode.STONES:
			_loose_stones(chunk, ci, c[1], c[2])


## Pedras soltas no chão em volta de rochas e veios (dá para pegar com [E]
## antes de ter picareta). Chave fixa: quem pegou, pegou para todos.
func _loose_stones(chunk: Node3D, ci: int, at: Vector3, scale: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([chunk.name, ci])
	for k in rng.randi_range(1, 3):
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.2, 2.2) * maxf(scale, 1.0)
		var stone: PickupItem = PICKUP_SCENE.instantiate()
		stone.item_id = &"pedra"
		stone.amount = 1
		stone.net_key = "%s_s%d_%d" % [chunk.name, ci, k]
		stone.freeze = true # fica parada no chão até alguém pegar
		chunk.add_child(stone)
		var local := at + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var world := chunk.get_parent() as TerrainWorld
		if world:
			local.y = world.height_at(chunk.position.x + local.x, chunk.position.z + local.z)
		stone.position = local + Vector3.UP * 0.07
		stone.rotation.y = rng.randf() * TAU


static func _in_lake(world: TerrainWorld, x: float, z: float, margin: float) -> bool:
	for lake in world.lakes:
		if Vector2(x, z).distance_to(lake.center) < lake.radius * margin:
			return true
	return false


func _pick_kind(biome: Dictionary, rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	# Chance por ponto testado (CANDIDATES por chunk). A neve é a mais densa.
	var low_mountain: float = biome.mountain * (1.0 - biome.get("depth", 0.0))
	var weights := [
		["tree", biome.plains * 0.2 + low_mountain * 0.1], ["crooked_tree", biome.plains * 0.09 + low_mountain * 0.08],
		["fruit_tree", biome.plains * 0.035], ["giant_tree", biome.plains * 0.012 + low_mountain * 0.008],
		["bush", biome.plains * 0.08],
		["cactus", biome.desert * 0.08], ["dead_bush", biome.desert * 0.06],
		["pine", biome.winter * 0.6 + biome.mountain * 0.08], ["rock", biome.mountain * 0.16 + biome.winter * 0.03 + biome.plains * 0.012 + biome.desert * 0.02],
		["ore_iron", biome.mountain * 0.06 + biome.winter * 0.01], ["ore_copper", biome.mountain * 0.04 + biome.desert * 0.012],
		["ore_coal", biome.mountain * 0.05 + biome.plains * 0.005],
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
	if kind == "giant_tree":
		var trunk := CylinderShape3D.new()
		trunk.radius = 1.0 * scale
		trunk.height = 12.0 * scale
		shape.shape = trunk
		shape.position = local + Vector3.UP * trunk.height * 0.5
		body.add_child(shape)
		return
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
		"crooked_tree":
			# Tronco torto em gomos que entorta para um lado, copa caída e um galho solto.
			var top := _chain(st, Vector3.ZERO, [Vector3(0.15, 1.1, 0.05), Vector3(0.45, 0.9, -0.1), Vector3(0.6, 0.7, 0.2), Vector3(0.2, 0.6, 0.3)], 0.42, trunk)
			_box(st, top + Vector3(0.2, 0.5, 0), Vector3(2.0, 1.3, 1.8), Color(0.24, 0.36, 0.16), Basis(Vector3.BACK, -0.25))
			_box(st, top + Vector3(-0.6, 0.1, 0.4), Vector3(1.2, 0.8, 1.1), Color(0.28, 0.4, 0.17))
			var branch := _chain(st, Vector3(0.3, 1.4, 0), [Vector3(-0.8, 0.4, -0.2), Vector3(-0.5, 0.5, -0.3)], 0.2, trunk)
			_box(st, branch + Vector3(0, 0.2, 0), Vector3(1.0, 0.7, 0.9), Color(0.22, 0.34, 0.15))
		"fruit_tree":
			# Árvore baixa e redonda com frutas vermelhas (as de pegar são separadas).
			_box(st, Vector3(0, 1.0, 0), Vector3(0.32, 2.0, 0.32), trunk)
			_box(st, Vector3(0, 2.6, 0), Vector3(2.4, 1.5, 2.4), Color(0.2, 0.4, 0.17))
			_box(st, Vector3(0, 3.5, 0), Vector3(1.6, 0.8, 1.6), Color(0.24, 0.44, 0.19))
			for k in 6:
				var a := TAU * k / 6.0
				_box(st, Vector3(cos(a) * 1.2, 2.3 + (k % 2) * 0.6, sin(a) * 1.2), Vector3(0.2, 0.2, 0.2), Color(0.7, 0.12, 0.08))
		"giant_tree":
			# Árvore gigante: tronco largo com raízes, copa em camadas lá no alto.
			_box(st, Vector3(0, 6.0, 0), Vector3(2.0, 12.0, 2.0), trunk)
			for k in 4:
				var a := TAU * k / 4.0 + 0.4
				_chain(st, Vector3(cos(a) * 0.8, 1.4, sin(a) * 0.8), [Vector3(cos(a) * 1.0, -0.9, sin(a) * 1.0), Vector3(cos(a) * 0.8, -0.6, sin(a) * 0.8)], 0.7, trunk)
			var leaves := Color(0.17, 0.33, 0.14)
			_box(st, Vector3(0, 12.0, 0), Vector3(9.0, 3.0, 9.0), leaves)
			_box(st, Vector3(1.0, 14.5, -0.5), Vector3(6.5, 2.4, 6.5), leaves.lightened(0.08))
			_box(st, Vector3(-0.5, 16.4, 0.4), Vector3(3.8, 1.8, 3.8), leaves.lightened(0.12))
			_chain(st, Vector3(0.6, 9.0, 0), [Vector3(2.5, 1.5, 0.4), Vector3(1.5, 1.0, 0.3)], 0.6, trunk)
			_box(st, Vector3(4.8, 11.6, 0.7), Vector3(3.5, 2.0, 3.0), leaves)
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
		"ore_iron", "ore_copper", "ore_coal":
			# Rocha com pedaços do minério à mostra (cor diz o que é).
			var ore: Color = {"ore_iron": Color(0.66, 0.36, 0.2), "ore_copper": Color(0.25, 0.62, 0.52), "ore_coal": Color(0.07, 0.07, 0.07)}[kind]
			_box(st, Vector3(0, 0.4, 0), Vector3(1.5, 1.0, 1.5), Color(0.4, 0.38, 0.37))
			_box(st, Vector3(-0.25, 0.9, 0.2), Vector3(0.8, 0.45, 0.7), Color(0.44, 0.42, 0.4))
			for k in 7:
				var a := TAU * k / 7.0
				_box(st, Vector3(cos(a) * 0.72, 0.25 + (k % 3) * 0.25, sin(a) * 0.72), Vector3(0.26, 0.22, 0.26), ore, Basis(Vector3.UP, a))
			_box(st, Vector3(0.1, 1.15, -0.1), Vector3(0.3, 0.2, 0.3), ore)
	st.generate_normals()
	var mesh := st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	mesh.surface_set_material(0, material)
	_meshes[kind] = mesh
	return mesh


# --- Grama, arbustos de folhas e frutas -----------------------------------------

## Tufos de grama e arbustos de planos cruzados (como a grama do Minecraft), sem colisão.
func _populate_ground(world: TerrainWorld, rng: RandomNumberGenerator, origin: Vector2, placed: Dictionary) -> void:
	for n in GROUND_CANDIDATES:
		var x := origin.x + rng.randf() * world.chunk_size
		var z := origin.y + rng.randf() * world.chunk_size
		if Vector2(x, z).length() < world.town_radius * 1.6 or world.city_mask(x, z) > 0.5:
			continue
		if not world.road_at(x, z).is_empty():
			continue # sem grama em cima das ruas
		if _in_lake(world, x, z, 0.98):
			continue
		var biome := world.biome_at(x, z)
		var high := world._height_from(x, z, biome)
		var green: float = biome.plains + biome.mountain * (1.0 - smoothstep(30.0, 60.0, high)) * 0.7
		var chance: float = green * 0.75 + biome.winter * 0.12 + biome.desert * 0.06
		if rng.randf() > chance:
			continue
		var kind := "leafy_bush" if rng.randf() < 0.12 else "grass"
		var scale := rng.randf_range(0.7, 1.3) * (1.6 if kind == "leafy_bush" else 1.0)
		var color := Color(0.42, 0.58, 0.25).lerp(Color(0.62, 0.58, 0.32), biome.desert + biome.temperature * 0.3)
		color = color.lerp(Color(0.6, 0.66, 0.6), biome.winter * 0.6).darkened(rng.randf_range(0.0, 0.25))
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale), Vector3(x - origin.x, high - 0.05, z - origin.y))
		if not placed.has(kind):
			placed[kind] = []
		placed[kind].append([t, color])


## Dois planos cruzados com textura de folhas/grama recortada (alpha scissor).
static func _foliage_mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var size := Vector2(1.1, 0.8) if kind == "grass" else Vector2(1.8, 1.4)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := PI * k / 3.0
		var right := Vector3(cos(a), 0, sin(a)) * size.x * 0.5
		var corners := [-right, right, right + Vector3.UP * size.y, -right + Vector3.UP * size.y]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		# Frente e verso como triângulos separados, ambos com normal para cima:
		# iluminação igual dos dois lados (com cull desligado o verso fica preto).
		for tri in [[0, 1, 2], [0, 2, 3], [0, 2, 1], [0, 3, 2]]:
			for i in tri:
				st.set_normal(Vector3.UP)
				st.set_uv(uvs[i])
				st.add_vertex(corners[i])
	var mesh := st.commit()
	mesh.surface_set_material(0, _foliage_mat())
	_meshes[kind] = mesh
	return mesh


static func _foliage_mat() -> StandardMaterial3D:
	if _foliage_material:
		return _foliage_material
	# Textura gerada: folhinhas/lâminas brancas (a cor vem da instância) com fundo transparente.
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for blade in 22:
		var x := rng.randi_range(1, 30)
		var height := rng.randi_range(10, 31)
		var lean := rng.randf_range(-0.25, 0.25)
		var shade := rng.randf_range(0.65, 1.0)
		for y in height:
			var px := clampi(int(x + lean * y), 0, 31)
			image.set_pixel(px, 31 - y, Color(shade, shade, shade, 1))
			if y < height * 0.4 and px + 1 < 32:
				image.set_pixel(px + 1, 31 - y, Color(shade * 0.85, shade * 0.85, shade * 0.85, 1))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	_foliage_material = material
	return material


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
