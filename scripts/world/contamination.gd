class_name Contamination
extends Node3D
## Zonas contaminadas (Era 4): ar tóxico que só se atravessa de máscara de gás (o
## filtro dura uns 3 minutos dentro do gás). São os "portões" naturais da exploração:
##   - o miolo das cidades grandes (sempre) e de metade das médias: casas com o saque
##     "contaminado" (cartuchos, química, manuais);
##   - fábricas químicas abandonadas no meio do mapa: laje de concreto, tanques
##     vazando, chaminé, barris e caixotes com saque bom.
## O gás é pesado: fica nos primeiros ~14 m acima do chão da zona (telhado alto respira).
## A borda engrossa em EDGE metros. Placas amarelas de perigo marcam o limite.
## Vazamentos da bancada química (ácido) fazem nuvens pequenas por alguns segundos.
## Tudo sai da semente do mapa: todo jogador vê as mesmas zonas; nada vai no save.

static var i: Contamination
static var zones: Array = [] ## {"center", "radius", "kind" ("city"/"plant"), "base", "seed"}
static var clouds: Array = [] ## vazamentos: {"pos", "radius", "until"} (segundos do relógio local)

const EDGE := 22.0 ## metros da borda até o gás ficar cheio
const CEILING := 14.0 ## acima disso (do chão da zona) o ar é limpo
const FILTER_TIME := 180.0 ## segundos de um filtro dentro do gás cheio
const BUILD_DISTANCE := 260.0
const GAS_COLOR := Color(0.6, 0.7, 0.2)

var terrain: TerrainWorld
var _built := {} # índice da zona -> Node3D
var _timer := 0.0
static var _haze_material: StandardMaterial3D


## Onde ficam as zonas (chamado pelo TerrainWorld depois das cidades).
static func plan(world: TerrainWorld) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed * 17 + 404
	var list := []
	for city in world.cities:
		var roll := rng.randf()
		var angle := rng.randf() * TAU
		var shift := rng.randf_range(0.0, 0.25)
		var chance: float = {"large": 1.0, "medium": 0.5}.get(city.size, 0.0)
		if roll >= chance:
			continue
		list.append({"center": city.center + Vector2.from_angle(angle) * city.radius * shift, "radius": city.radius * (0.62 if city.size == "large" else 0.55),
			"kind": "city", "base": city.base, "seed": city.seed})
	var count := roundi(3 * WorldSettings.mult("cities"))
	var half := world.world_size * 0.5 - 200.0
	var plants := 0
	for attempt in 400:
		if plants >= count:
			break
		var c := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		var seed := rng.randi()
		if c.length() < 520.0 or world.coast_distance(c.x, c.y) < 160.0:
			continue
		var biome := world.biome_at(c.x, c.y)
		if biome.mountain > 0.35 or biome.winter > 0.6 or biome.get("depth", 0.0) > 0.1:
			continue
		if TerrainProps._in_lake(world, c.x, c.y, 1.6) or not world.river_near(c.x, c.y).is_empty() and world.river_near(c.x, c.y).get("dist", 999.0) < 60.0:
			continue
		if not world.track.is_empty() and c.distance_to(world.track.center) < RaceTrack.HALF.x + 120.0:
			continue
		var clear := true
		for city in world.cities:
			if c.distance_to(city.center) < city.radius + 150.0:
				clear = false
		for other in list:
			if c.distance_to(other.center) < other.radius + 260.0:
				clear = false
		if not clear:
			continue
		var heights := []
		for k in 9:
			var p := c if k == 0 else c + Vector2.from_angle(TAU * k / 8.0) * 24.0
			heights.append(world.height_at(p.x, p.y))
		if heights.max() - heights.min() > 5.0:
			continue
		list.append({"center": c, "radius": 58.0, "kind": "plant", "base": heights.max(), "seed": seed})
		plants += 1
	return list


## Quanto gás tem no ponto (0 = ar limpo, 1 = gás cheio).
static func level_at(p: Vector3) -> float:
	var best := 0.0
	var flat := Vector2(p.x, p.z)
	for zone in zones:
		var d: float = flat.distance_to(zone.center)
		if d >= zone.radius:
			continue
		var depth := clampf((zone.radius - d) / EDGE, 0.0, 1.0)
		var high := clampf((zone.base + CEILING - p.y) / 4.0, 0.0, 1.0) # gás pesado: telhado alto respira
		best = maxf(best, depth * high)
	var now := Time.get_ticks_msec() / 1000.0
	for cloud in clouds:
		if cloud.until > now:
			var d: float = p.distance_to(cloud.pos)
			if d < cloud.radius:
				best = maxf(best, clampf((cloud.radius - d) / 2.0, 0.0, 1.0))
	return best


## Zona em que o ponto (no chão) está, ou {}.
static func zone_at(p: Vector2) -> Dictionary:
	for zone in zones:
		if p.distance_to(zone.center) < zone.radius:
			return zone
	return {}


## Vazamento de gás (bancada química): nuvem pequena que some sozinha.
static func add_cloud(at: Vector3, radius: float, seconds: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	clouds = clouds.filter(func(c): return c.until > now)
	clouds.append({"pos": at, "radius": radius, "until": now + seconds})
	if i:
		var puff := i._haze(radius * 0.7, int(radius * 4.0), 6.0, Vector2(4.0, 3.0))
		i.add_child(puff)
		puff.global_position = at
		puff.one_shot = false
		i.get_tree().create_timer(seconds).timeout.connect(func():
			if is_instance_valid(puff):
				puff.emitting = false
				i.get_tree().create_timer(6.0).timeout.connect(puff.queue_free))


func _enter_tree() -> void:
	i = self


func _exit_tree() -> void:
	if i == self:
		i = null
	clouds.clear()


func _ready() -> void:
	zones = terrain.zones if terrain else []


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or terrain == null:
		return
	_timer = 0.5
	var centers: Array[Vector3] = []
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me:
		centers.append(me.global_position)
	if Net.i.world:
		centers.append_array(Net.i.world.player_positions())
	for k in zones.size():
		var zone: Dictionary = zones[k]
		var near := INF
		for c in centers:
			near = minf(near, Vector2(c.x, c.z).distance_to(zone.center) - zone.radius)
		if near < BUILD_DISTANCE and not _built.has(k):
			_built[k] = _build_zone(k, zone)
		elif near > BUILD_DISTANCE + 120.0 and _built.has(k):
			_built[k].queue_free()
			_built.erase(k)
	# Névoa acompanha a luz do dia (sem sombra: à noite fica escura, não brilha).
	if _haze_material and DayNight.i:
		_haze_material.albedo_color = Color.WHITE * lerpf(0.18, 1.0, DayNight.i.sun_factor)


func _build_zone(k: int, zone: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Zone_%d" % k
	add_child(root)
	root.global_position = Vector3(zone.center.x, zone.base, zone.center.y)
	var haze := _haze(zone.radius * 0.92, clampi(int(zone.radius * 2.2), 90, 240), 18.0, Vector2(18.0, 9.0))
	haze.position = Vector3(0, 3.5, 0)
	root.add_child(haze)
	_signs(root, zone)
	if zone.kind == "plant":
		ChemPlant.build(root, k, zone)
	return root


## Névoa amarelo-esverdeada: bolos de fumaça lentos (partículas grandes e transparentes).
func _haze(radius: float, amount: int, lifetime: float, size: Vector2) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Haze"
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-radius - 12.0, -6.0, -radius - 12.0), Vector3(radius * 2.0 + 24.0, 24.0, radius * 2.0 + 24.0))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = radius
	m.emission_ring_inner_radius = 0.0
	m.emission_ring_height = 5.0
	m.direction = Vector3(1, 0.05, 0)
	m.spread = 180.0
	m.initial_velocity_min = 0.2
	m.initial_velocity_max = 0.9
	m.gravity = Vector3(0, 0.03, 0)
	m.scale_min = 0.7
	m.scale_max = 1.5
	m.angle_min = -180.0
	m.angle_max = 180.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(GAS_COLOR, 0.0), Color(GAS_COLOR, 0.42), Color(GAS_COLOR.darkened(0.12), 0.36), Color(GAS_COLOR, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = _haze_mat()
	p.draw_pass_1 = quad
	return p


static func _haze_mat() -> StandardMaterial3D:
	if _haze_material == null:
		var soft := GradientTexture2D.new()
		soft.fill = GradientTexture2D.FILL_RADIAL
		soft.fill_from = Vector2(0.5, 0.5)
		soft.fill_to = Vector2(1.0, 0.5)
		soft.width = 64
		soft.height = 64
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		soft.gradient = g
		_haze_material = StandardMaterial3D.new()
		_haze_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_haze_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_haze_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_haze_material.vertex_color_use_as_albedo = true
		_haze_material.albedo_texture = soft
		_haze_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_haze_material.disable_receive_shadows = true
		_haze_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return _haze_material


## Placas de perigo na borda (poste de madeira, losango amarelo com o símbolo preto),
## fora das casas da cidade.
func _signs(root: Node3D, zone: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var lots: Array = []
	if zone.kind == "city":
		for city in terrain.cities:
			if city.seed == zone.seed:
				lots = city.lots
	var count := 14 if zone.kind == "city" else 9
	for s in count:
		var a := TAU * (s + 0.5) / count + float(zone.seed % 100) * 0.01
		var flat: Vector2 = zone.center + Vector2.from_angle(a) * (zone.radius + 1.5)
		var blocked := false
		for lot in lots:
			if flat.distance_to(lot.pos) < maxf(lot.w, lot.d) * 0.75 + 1.0:
				blocked = true
				break
		if blocked:
			continue
		var y: float = terrain.height_at(flat.x, flat.y) - zone.base
		var local := Vector3(flat.x - zone.center.x, y, flat.y - zone.center.y)
		var face := Basis(Vector3.UP, -a + PI * 0.5) # placa virada para fora
		mb.color(ObjectModels.WOOD_DARK)
		mb.box(local + Vector3(0, 0.8, 0), Vector3(0.1, 1.6, 0.1))
		mb.color(Color(0.92, 0.78, 0.12))
		mb.box(local + Vector3(0, 1.75, 0) + face * Vector3(0, 0, 0.07), Vector3(0.5, 0.5, 0.03), face * Basis(Vector3.BACK, PI / 4))
		mb.color(Color(0.08, 0.08, 0.08))
		mb.box(local + Vector3(0, 1.8, 0) + face * Vector3(0, 0, 0.09), Vector3(0.14, 0.12, 0.01), face) # caveira
		mb.box(local + Vector3(0, 1.66, 0) + face * Vector3(0, 0, 0.09), Vector3(0.2, 0.04, 0.01), face * Basis(Vector3.BACK, 0.6))
		mb.box(local + Vector3(0, 1.66, 0) + face * Vector3(0, 0, 0.09), Vector3(0.2, 0.04, 0.01), face * Basis(Vector3.BACK, -0.6))
	var mesh := MeshInstance3D.new()
	mesh.name = "Signs"
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	root.add_child(mesh)
