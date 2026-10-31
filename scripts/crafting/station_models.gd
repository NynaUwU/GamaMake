class_name StationModels
extends RefCounted
## Modelos das estações colocadas pelo martelo (PS2 poligonal, fosco):
##   campfire   fogueira: roda de pedras, lenha cruzada, fogo, grelha de ferro em 4 pés
##   furnace    fornalha de pedra com boca acesa e chaminé
##   workbench  mesa de trabalho pesada: bigorna, torno, painel de ferramentas
## Cada um monta a colisão no próprio PlacedObject.

const STONE := Color(0.46, 0.44, 0.42)
const IRON := Color(0.22, 0.21, 0.21)
const WOOD := Color(0.4, 0.26, 0.15)
const FIRE := Color(1.0, 0.55, 0.15)

static var _glow: StandardMaterial3D


static func build(kind: String, obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	match kind:
		"campfire":
			_campfire(mb, obj)
		"furnace":
			_furnace(mb, obj)
		"workbench":
			_workbench(mb, obj)
		"chest":
			_chest(mb, obj)
		"dryer":
			_dryer(mb, obj)
		"rain_collector":
			_rain_collector(mb, obj)
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)


## Secador: armação de galhos em A com duas traves e cordas de pendurar.
static func _dryer(mb: MeshBuilder, obj: PlacedObject) -> void:
	mb.color(WOOD)
	for x in [-0.7, 0.7]:
		mb.tube(PackedVector3Array([Vector3(x, 0, -0.35), Vector3(x, 1.45, 0)]), 0.035, 5)
		mb.tube(PackedVector3Array([Vector3(x, 0, 0.35), Vector3(x, 1.45, 0)]), 0.035, 5)
	mb.tube(PackedVector3Array([Vector3(-0.78, 1.42, 0), Vector3(0.78, 1.42, 0)]), 0.03, 5)
	mb.color(Color(0.72, 0.66, 0.5))
	for x in [-0.45, -0.15, 0.15, 0.45]:
		mb.box(Vector3(x, 1.3, 0), Vector3(0.012, 0.24, 0.012)) # cordinha de cada peça
	mb.color(WOOD.darkened(0.2))
	mb.box(Vector3(0, 0.03, 0), Vector3(1.5, 0.06, 0.08)) # trava no chão
	obj._shape(Vector3(0, 0.75, 0), Vector3(1.5, 1.5, 0.5))


## Coletor de chuva: barril de tábuas com funil de pano em cima; a água sobe dentro.
static func _rain_collector(mb: MeshBuilder, obj: PlacedObject) -> void:
	for k in 10:
		var a := TAU * k / 10.0
		mb.color(WOOD.darkened(0.08 * (k % 2)))
		mb.box(Vector3(cos(a) * 0.34, 0.45, sin(a) * 0.34), Vector3(0.22, 0.9, 0.05), Basis(Vector3.UP, -a + PI / 2))
	mb.color(IRON)
	for y in [0.15, 0.75]:
		for k in 10:
			var a := TAU * k / 10.0
			mb.box(Vector3(cos(a) * 0.365, y, sin(a) * 0.365), Vector3(0.23, 0.05, 0.02), Basis(Vector3.UP, -a + PI / 2))
	mb.color(WOOD.darkened(0.3))
	mb.box(Vector3(0, 0.04, 0), Vector3(0.62, 0.08, 0.62)) # fundo
	# Funil de pano esticado em 4 varetas.
	mb.color(Color(0.62, 0.58, 0.48))
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		mb.box(Vector3(cos(a) * 0.42, 1.0, sin(a) * 0.42), Vector3(0.5, 0.03, 0.34), Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.35))
	mb.color(WOOD)
	for k in 4:
		var a := TAU * k / 4.0
		mb.tube(PackedVector3Array([Vector3(cos(a) * 0.36, 0.85, sin(a) * 0.36), Vector3(cos(a) * 0.62, 1.12, sin(a) * 0.62)]), 0.015, 4)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.4
	cyl.height = 0.95
	shape.shape = cyl
	shape.position.y = 0.48
	obj.add_child(shape)
	# Água dentro (sobe com o nível: escala em Y a partir do fundo).
	var water := MeshBuilder.new()
	water.color(Color(0.3, 0.45, 0.55))
	water.box(Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.6))
	var mesh := MeshInstance3D.new()
	mesh.name = "Water"
	mesh.mesh = water.finish(PlacedObject._mat(), false)
	mesh.position.y = 0.08
	mesh.scale = Vector3(1, 0.01, 1)
	mesh.visible = false
	obj.add_child(mesh)


static func _campfire(mb: MeshBuilder, obj: PlacedObject) -> void:
	for k in 9:
		var a := TAU * k / 9.0
		mb.color(STONE.darkened(0.1 * (k % 3)))
		mb.box(Vector3(cos(a) * 0.48, 0.08, sin(a) * 0.48), Vector3(0.2, 0.16, 0.16), Basis(Vector3.UP, -a))
	# Lenha cruzada (meio queimada na ponta).
	for k in 4:
		var a := PI * k / 4.0
		var dir := Vector3(cos(a), 0, sin(a))
		mb.color(WOOD.darkened(0.25))
		mb.tube(PackedVector3Array([dir * 0.34 + Vector3.UP * 0.05, -dir * 0.05 + Vector3.UP * 0.2]), 0.045, 5)
		mb.color(Color(0.1, 0.08, 0.07))
		mb.box(Vector3(0, 0.03, 0), Vector3(0.3, 0.04, 0.3), Basis(Vector3.UP, a)) # brasa/cinza
	# Grelha de ferro em quatro pés, por cima do fogo.
	mb.color(IRON)
	for x in [-0.36, 0.36]:
		for z in [-0.26, 0.26]:
			mb.box(Vector3(x, 0.27, z), Vector3(0.035, 0.54, 0.035))
	mb.box(Vector3(0, 0.55, -0.26), Vector3(0.78, 0.03, 0.035))
	mb.box(Vector3(0, 0.55, 0.26), Vector3(0.78, 0.03, 0.035))
	for k in 7:
		mb.box(Vector3(-0.33 + k * 0.11, 0.565, 0), Vector3(0.018, 0.018, 0.56))
	obj._shape(Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 1.0))
	_fire(obj, Vector3(0, 0.12, 0), 0.22, 1.0)


## Fornalha de barro: cúpula redonda sobre base de pedras, boca em arco acesa,
## chaminé de barro torta em cima e marcas de fuligem.
static func _furnace(mb: MeshBuilder, obj: PlacedObject) -> void:
	var clay := Color(0.66, 0.4, 0.26)
	var soot := Color(0.2, 0.15, 0.12)
	for k in 10: # base de pedras em volta
		var a := TAU * k / 10.0
		mb.color(STONE.darkened(0.08 * (k % 3)))
		mb.box(Vector3(cos(a) * 0.62, 0.1, sin(a) * 0.62), Vector3(0.3, 0.2, 0.22), Basis(Vector3.UP, -a))
	mb.color(clay)
	mb.lathe(PackedVector2Array([Vector2(0.62, 0.12), Vector2(0.64, 0.4), Vector2(0.58, 0.72), Vector2(0.45, 0.98),
		Vector2(0.26, 1.14), Vector2(0.12, 1.2)]), 14)
	mb.color(clay.darkened(0.12))
	mb.lathe(PackedVector2Array([Vector2(0.65, 0.38), Vector2(0.65, 0.44)]), 14) # cinta de barro
	# Chaminé de barro.
	mb.color(clay.lightened(0.05))
	mb.lathe(PackedVector2Array([Vector2(0.14, 1.12), Vector2(0.12, 1.5), Vector2(0.15, 1.56)]), 10, Basis(Vector3.BACK, 0.06), Vector3(0.05, 0, 0))
	mb.color(soot)
	mb.lathe(PackedVector2Array([Vector2(0.155, 1.53), Vector2(0.155, 1.57)]), 10, Basis(Vector3.BACK, 0.06), Vector3(0.05, 0, 0))
	# Boca em arco (moldura de pedra) e fuligem em cima dela.
	mb.color(STONE.darkened(0.2))
	for k in 7:
		var a := PI * k / 6.0
		mb.box(Vector3(cos(a) * 0.27, 0.3 + sin(a) * 0.27, 0.6), Vector3(0.1, 0.09, 0.1), Basis(Vector3.BACK, a))
	mb.color(soot)
	mb.box(Vector3(0, 0.66, 0.56), Vector3(0.3, 0.16, 0.06), Basis(Vector3.RIGHT, -0.3))
	var glow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.24
	disc.bottom_radius = 0.24
	disc.height = 0.02
	disc.radial_segments = 12
	glow.mesh = disc
	glow.material_override = _glow_mat()
	glow.rotation.x = PI / 2
	glow.position = Vector3(0, 0.3, 0.58)
	glow.scale = Vector3(1.0, 1.0, 1.0)
	obj.add_child(glow)
	obj._shape(Vector3(0, 0.6, 0), Vector3(1.3, 1.2, 1.3))
	_fire(obj, Vector3(0, 0.3, 0.66), 0.0, 0.8)


## Baú construído: caixa de tábuas com tampa arredondada, cintas de ferro e
## fechadura de latão.
static func _chest(mb: MeshBuilder, obj: PlacedObject) -> void:
	mb.color(WOOD)
	mb.box(Vector3(0, 0.27, 0), Vector3(1.0, 0.54, 0.6))
	mb.color(WOOD.darkened(0.15))
	for y in [0.12, 0.3, 0.46]:
		mb.box(Vector3(0, y, 0.302), Vector3(0.98, 0.012, 0.004)) # frestas das tábuas
	mb.color(WOOD.lightened(0.05))
	mb.lathe(PackedVector2Array([Vector2(0.3, -0.5), Vector2(0.3, 0.5)]), 8, Basis(Vector3.BACK, PI / 2), Vector3(0, 0.54, 0)) # tampa curva
	mb.color(IRON)
	for x in [-0.36, 0.36]:
		mb.box(Vector3(x, 0.27, 0), Vector3(0.06, 0.56, 0.62))
		mb.lathe(PackedVector2Array([Vector2(0.31, -0.03), Vector2(0.31, 0.03)]), 8, Basis(Vector3.BACK, PI / 2), Vector3(x, 0.54, 0))
	mb.color(ItemModels.BRASS)
	mb.box(Vector3(0, 0.5, 0.31), Vector3(0.1, 0.12, 0.03))
	obj._shape(Vector3(0, 0.42, 0), Vector3(1.0, 0.84, 0.62))


static func _workbench(mb: MeshBuilder, obj: PlacedObject) -> void:
	mb.color(WOOD.darkened(0.1))
	mb.box(Vector3(0, 0.88, 0), Vector3(1.9, 0.12, 0.85))
	for x in [-0.85, 0.85]:
		for z in [-0.35, 0.35]:
			mb.box(Vector3(x, 0.42, z), Vector3(0.12, 0.84, 0.12))
	mb.box(Vector3(0, 0.22, 0), Vector3(1.7, 0.06, 0.7))
	# Painel de ferramentas atrás, com martelo, serrote e chaves.
	mb.color(WOOD)
	mb.box(Vector3(0, 1.45, -0.4), Vector3(1.8, 1.0, 0.05))
	mb.box(Vector3(-0.85, 1.2, -0.4), Vector3(0.08, 1.5, 0.08))
	mb.box(Vector3(0.85, 1.2, -0.4), Vector3(0.08, 1.5, 0.08))
	mb.color(IRON)
	for k in 5:
		mb.box(Vector3(-0.6 + k * 0.3, 1.5, -0.36), Vector3(0.04, 0.35 - (k % 2) * 0.1, 0.02))
	mb.color(ItemModels.BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.002, -0.015), Vector2(0.14, -0.015), Vector2(0.14, 0.015), Vector2(0.002, 0.015)]), 12,
			Basis(Vector3.RIGHT, PI / 2), Vector3(0.55, 1.6, -0.36))
	# Bigorna e torno em cima da mesa.
	mb.color(IRON)
	mb.box(Vector3(-0.45, 1.0, 0.05), Vector3(0.18, 0.12, 0.16))
	mb.box(Vector3(-0.45, 1.1, 0.05), Vector3(0.42, 0.1, 0.18))
	mb.box(Vector3(-0.7, 1.1, 0.05), Vector3(0.14, 0.06, 0.1))
	mb.box(Vector3(0.55, 1.02, 0.25), Vector3(0.18, 0.16, 0.14))
	mb.box(Vector3(0.55, 1.02, 0.38), Vector3(0.03, 0.03, 0.2))
	obj._shape(Vector3(0, 0.5, 0), Vector3(1.9, 1.0, 0.85))
	obj._shape(Vector3(0, 1.45, -0.4), Vector3(1.8, 1.0, 0.1))


## Chamas (partículas) + luz alaranjada que tremula.
static func _fire(obj: PlacedObject, at: Vector3, radius: float, strength: float) -> void:
	var flames := CPUParticles3D.new()
	flames.amount = 26
	flames.lifetime = 0.7
	flames.position = at
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = maxf(radius, 0.05)
	flames.direction = Vector3.UP
	flames.spread = 12.0
	flames.gravity = Vector3(0, 1.2, 0)
	flames.initial_velocity_min = 0.3
	flames.initial_velocity_max = 0.7
	flames.scale_amount_min = 0.6
	flames.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	flames.scale_amount_curve = curve
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.09 * strength
	box.material = _glow_mat()
	flames.mesh = box
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.85, 0.3))
	gradient.set_color(1, Color(0.8, 0.2, 0.05))
	flames.color_ramp = gradient
	obj.add_child(flames)
	var light := Flicker.new()
	light.position = at + Vector3.UP * 0.4
	light.light_color = Color(1.0, 0.6, 0.3)
	light.omni_range = 7.0 * strength
	light.base_energy = 1.6 * strength
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 50.0
	obj.add_child(light)


static func _glow_mat() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.vertex_color_use_as_albedo = true
		_glow.albedo_color = FIRE
	return _glow


class Flicker extends OmniLight3D:
	var base_energy := 1.5
	var _t := randf() * 10.0

	func _process(delta: float) -> void:
		_t += delta
		light_energy = base_energy * (0.85 + 0.15 * sin(_t * 13.0) * sin(_t * 5.3 + 1.0))
