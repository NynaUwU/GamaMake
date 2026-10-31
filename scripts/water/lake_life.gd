class_name LakeLife
extends Node3D
## Vida de um lago (criada pelo WaterManager quando o jogador chega perto):
##   bichos  peixes-baixo e atuns nadando, camarões, lagostas e caranguejos no
##           fundo (alguns caranguejos na margem). Pegos voltam depois de um tempo.
##   plantas algas compridas balançando no fundo, juncos/taboas na margem,
##           vitórias-régias boiando (com flor) e pedras no fundo.
## É visual/local de cada jogador (quem pega leva o bicho para o inventário).

const RESPAWN := 60.0
const KELP_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 color : source_color = vec4(0.18, 0.4, 0.2, 1.0);
void vertex() {
	float sway = sin(TIME * 1.3 + float(INSTANCE_ID) * 1.7 + VERTEX.y * 0.8) * 0.12 * VERTEX.y;
	VERTEX.x += sway;
	VERTEX.z += cos(TIME * 1.1 + float(INSTANCE_ID)) * 0.06 * VERTEX.y;
}
void fragment() {
	ALBEDO = COLOR.rgb * color.rgb * 2.0;
	ROUGHNESS = 0.9;
}
"""

var lake: Dictionary
var terrain: TerrainWorld
var creatures: Array[Creature] = []
var _respawns: Array = [] # [tempo, id]
var _rng := RandomNumberGenerator.new()


func setup(lake_: Dictionary, terrain_: TerrainWorld) -> void:
	lake = lake_
	terrain = terrain_
	_rng.seed = lake.seed
	_build_plants()
	var counts := {&"baixo": 6, &"atum": 3, &"camarao": 8, &"lagosta": 3, &"caranguejo": 5, &"caranguejo_aranha": 3}
	if lake.kind == "pond":
		counts = {&"baixo": 4, &"camarao": 6, &"caranguejo": 3, &"caranguejo_aranha": 2}
	for id in counts:
		for k in counts[id]:
			_spawn(id)


func _random_point(min_depth: float) -> Vector3:
	for attempt in 12:
		var a := _rng.randf() * TAU
		var r: float = sqrt(_rng.randf()) * lake.radius * 0.9
		var x: float = lake.center.x + cos(a) * r
		var z: float = lake.center.y + sin(a) * r
		var bottom := terrain.height_at(x, z)
		if lake.level - bottom >= min_depth:
			return Vector3(x, bottom, z)
	return Vector3(lake.center.x, terrain.height_at(lake.center.x, lake.center.y), lake.center.y)


func _spawn(id: StringName) -> void:
	var creature := Creature.new()
	creature.setup(id, self)
	add_child(creature)
	var swimmer := id in Creatures.SWIMMERS
	var p := _random_point(1.5 if swimmer else 0.3)
	if id == &"caranguejo" and _rng.randf() < 0.4:
		p = _shore_point() # alguns na margem
	creature.global_position = p + Vector3.UP * (_swim_height(p) if swimmer else 0.0)
	creature.rotation.y = _rng.randf() * TAU
	creature.target = creature.global_position
	creatures.append(creature)


func _shore_point() -> Vector3:
	var a := _rng.randf() * TAU
	var r: float = lake.radius * _rng.randf_range(0.95, 1.05)
	var x: float = lake.center.x + cos(a) * r
	var z: float = lake.center.y + sin(a) * r
	return Vector3(x, terrain.height_at(x, z), z)


func _swim_height(bottom: Vector3) -> float:
	var water: float = lake.level - bottom.y
	return clampf(_rng.randf_range(0.5, water - 0.5), 0.4, maxf(water - 0.4, 0.4))


func on_caught(creature: Creature) -> void:
	creatures.erase(creature)
	_respawns.append([RESPAWN, creature.id])


func _process(delta: float) -> void:
	for entry in _respawns.duplicate():
		entry[0] -= delta
		if entry[0] <= 0.0:
			_respawns.erase(entry)
			_spawn(entry[1])
	var player: Node3D = get_parent().get_parent().get("player")
	var ppos := player.global_position if player else Vector3(1e9, 0, 0)
	for c in creatures:
		if not is_instance_valid(c):
			continue
		c.think -= delta
		# Só fogem com alguém MUITO perto, ou se a pessoa ataca por perto.
		var distance := c.global_position.distance_to(ppos)
		var attacking: bool = player != null and player.get("_swing_phase") != null and player._swing_phase != 0
		var near := distance < (1.8 if c.swimmer else 1.2) or (attacking and distance < 4.5)
		if near:
			# Foge para o lado oposto de quem chegou.
			var away := (c.global_position - ppos)
			away.y = 0.0
			c.target = c.global_position + away.normalized() * 5.0
			c.speed = 2.6 if c.swimmer else 0.8
			c.think = 1.5
		elif c.think <= 0.0:
			c.think = _rng.randf_range(2.0, 6.0)
			c.speed = _rng.randf_range(0.25, 0.6) if c.swimmer else _rng.randf_range(0.06, 0.2)
			var p := _random_point(1.5 if c.swimmer else 0.3)
			if not c.swimmer:
				var step := Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2))
				p = c.global_position + step
			c.target = p + Vector3.UP * (_swim_height(p) if c.swimmer else 0.0)
		var to := c.target - c.global_position
		var moving := to.length() > 0.15
		if moving:
			var step_len := minf(to.length(), c.speed * delta)
			var next := c.global_position + to.normalized() * step_len
			# Dentro do lago e acima do fundo; os do fundo seguem o chão.
			var flat: Vector2 = Vector2(next.x, next.z) - lake.center
			if flat.length() > lake.radius * (1.05 if not c.swimmer else 0.92):
				c.target = Vector3(lake.center.x, c.global_position.y, lake.center.y)
			else:
				var bottom := terrain.height_at(next.x, next.z)
				if c.swimmer:
					next.y = clampf(next.y, bottom + 0.35, lake.level - 0.35)
				else:
					next.y = bottom
				c.global_position = next
				var heading := Vector2(to.x, to.z)
				if heading.length() > 0.01:
					var yaw := atan2(-heading.x, -heading.y)
					if c.id in [&"caranguejo", &"caranguejo_aranha"]:
						yaw += PI / 2 # caranguejo anda de lado
					c.rotation.y = lerp_angle(c.rotation.y, yaw, 1.0 - exp(-6.0 * delta))
		c.animate(delta, moving)


# --- Plantas ---------------------------------------------------------------------

func _build_plants() -> void:
	var area: float = lake.radius * lake.radius
	_kelp(int(area / 22.0) + 6)
	_reeds(int(lake.radius * 1.4) + 6)
	_lilies(int(area / (60.0 if lake.kind == "lake" else 18.0)) + 3)
	_rocks(int(area / 120.0) + 3)
	_motes()


func _multimesh(mesh: Mesh, transforms: Array, colors: Array = []) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for k in transforms.size():
		mm.set_instance_transform(k, transforms[k])
		if mm.use_colors:
			mm.set_instance_color(k, colors[k])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## Algas: fitas de blocos verdes que balançam (shader), mais altas no fundo.
func _kelp(count: int) -> void:
	var mb := MeshBuilder.new()
	for k in 6:
		mb.color(Color(1, 1, 1).darkened(0.1 * (k % 2)))
		mb.box(Vector3(0.03 * (k % 2), 0.25 + k * 0.5, 0), Vector3(0.12 - k * 0.01, 0.5, 0.03))
		mb.box(Vector3(0.08, 0.35 + k * 0.5, 0), Vector3(0.12, 0.05, 0.02), Basis(Vector3.BACK, -0.6)) # folhinha
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = KELP_SHADER
	material.shader = shader
	var mesh := mb.finish(null, false)
	mesh.surface_set_material(0, material)
	var transforms := []
	var colors := []
	for k in count:
		var p := _random_point(1.2)
		var water: float = lake.level - p.y
		var height := clampf(water * _rng.randf_range(0.4, 0.85), 0.6, 6.0)
		transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1, height / 3.0, 1)), p))
		colors.append(Color(0.5, 1.0, 0.55).lerp(Color(0.8, 0.85, 0.4), _rng.randf() * 0.5))
	_multimesh(mesh, transforms, colors)


## Juncos e taboas na margem (com a ponta marrom).
func _reeds(count: int) -> void:
	var mb := MeshBuilder.new()
	for k in 5:
		var off := Vector3(cos(k * 1.3) * 0.12, 0, sin(k * 1.3) * 0.12)
		var h := 1.1 + (k % 3) * 0.25
		mb.color(Color(0.36, 0.5, 0.22))
		mb.box(off + Vector3(0, h * 0.5, 0), Vector3(0.025, h, 0.025), Basis(Vector3.BACK, cos(k) * 0.08))
		if k % 2 == 0:
			mb.color(Color(0.4, 0.26, 0.14))
			mb.box(off + Vector3(0, h - 0.12, 0), Vector3(0.05, 0.22, 0.05))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var mesh := mb.finish(material, false)
	var transforms := []
	for k in count:
		var p := _shore_point()
		if absf(p.y - lake.level) > 0.8:
			continue
		transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.3)), p))
	_multimesh(mesh, transforms)


## Vitórias-régias boiando onde é raso (algumas com flor rosa).
func _lilies(count: int) -> void:
	var mb := MeshBuilder.new()
	mb.color(Color(0.25, 0.5, 0.2))
	mb.box(Vector3(0, 0.0, 0), Vector3(0.55, 0.02, 0.55))
	mb.color(Color(0.2, 0.42, 0.17))
	mb.box(Vector3(0.12, 0.012, 0.12), Vector3(0.3, 0.01, 0.04), Basis(Vector3.UP, 0.78)) # corte da folha
	var flower := MeshBuilder.new()
	flower.color(Color(0.25, 0.5, 0.2))
	flower.box(Vector3(0, 0.0, 0), Vector3(0.55, 0.02, 0.55))
	flower.color(Color(0.95, 0.6, 0.7))
	flower.box(Vector3(0, 0.06, 0), Vector3(0.14, 0.1, 0.14))
	flower.color(Color(1.0, 0.85, 0.3))
	flower.box(Vector3(0, 0.12, 0), Vector3(0.05, 0.03, 0.05))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.6
	var plain := []
	var flowered := []
	for k in count:
		var p := _random_point(0.4)
		if lake.level - p.y > 3.0:
			continue
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.7, 1.4)), Vector3(p.x, lake.level + 0.03, p.z))
		(flowered if _rng.randf() < 0.3 else plain).append(t)
	_multimesh(mb.finish(material, false), plain)
	_multimesh(flower.finish(material, false), flowered)


func _rocks(count: int) -> void:
	var mb := MeshBuilder.new()
	mb.color(Color(0.38, 0.38, 0.36))
	mb.box(Vector3(0, 0.15, 0), Vector3(0.7, 0.35, 0.55))
	mb.color(Color(0.3, 0.38, 0.28)) # musgo
	mb.box(Vector3(0.05, 0.33, 0), Vector3(0.5, 0.05, 0.4))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var transforms := []
	for k in count:
		var p := _random_point(0.5)
		transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.6, 1.8)), p))
	_multimesh(mb.finish(material, false), transforms)


## Partículas de sujeira flutuando dentro d'água (só aparecem mergulhando).
func _motes() -> void:
	var motes := CPUParticles3D.new()
	motes.amount = int(clampf(lake.radius * 4.0, 40, 200))
	motes.lifetime = 8.0
	motes.preprocess = 8.0
	motes.position = Vector3(lake.center.x, lake.level - lake.depth * 0.5, lake.center.y)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(lake.radius * 0.8, lake.depth * 0.45, lake.radius * 0.8)
	motes.direction = Vector3.UP
	motes.gravity = Vector3(0, 0.02, 0)
	motes.initial_velocity_min = 0.02
	motes.initial_velocity_max = 0.08
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.025
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.7, 0.85, 0.75, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	motes.mesh = mesh
	add_child(motes)
