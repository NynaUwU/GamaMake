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
const STEEL := Color(0.58, 0.59, 0.6)

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
	for k in 6:
		mb.box(Vector3((k - 2.5) * 0.22, 1.3, 0), Vector3(0.012, 0.24, 0.012)) # cordinha de cada peça
	mb.color(WOOD.darkened(0.2))
	mb.box(Vector3(0, 0.03, 0), Vector3(1.5, 0.06, 0.08)) # trava no chão
	mb.color(Color(0.55, 0.48, 0.35))
	for x in [-0.7, 0.7]:
		mb.box(Vector3(x, 1.42, 0), Vector3(0.1, 0.1, 0.1), Basis(Vector3.UP, 0.6)) # amarração no topo
		mb.tube(PackedVector3Array([Vector3(x, 1.4, 0), Vector3(x * 1.35, 0.0, 0.0)]), 0.005, 3) # corda esticada
		mb.color(WOOD.darkened(0.3))
		mb.box(Vector3(x * 1.35, 0.06, 0), Vector3(0.04, 0.14, 0.04)) # estaca
		mb.color(Color(0.55, 0.48, 0.35))
	# Balde de sal e faca no chão.
	mb.color(WOOD)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.11, 0.0), Vector2(0.13, 0.2), Vector2(0.135, 0.21)]), 10, Basis.IDENTITY, Vector3(0.35, 0, 0.35))
	mb.color(Color(0.92, 0.92, 0.9))
	mb.lathe(PackedVector2Array([Vector2(0.125, 0.17), Vector2(0.002, 0.19)]), 10, Basis.IDENTITY, Vector3(0.35, 0, 0.35))
	mb.color(STEEL)
	mb.box(Vector3(-0.3, 0.01, 0.3), Vector3(0.025, 0.006, 0.16), Basis(Vector3.UP, 0.6))
	obj._shape(Vector3(0, 0.75, 0), Vector3(1.5, 1.5, 0.5))


## Coletor de chuva: barril redondo de aduelas com aros de ferro e um funil de
## pano em cone por cima; a água (cilindro) sobe lá dentro.
static func _rain_collector(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Barril: perfil com barriga (aduelas), fundo e boca aberta.
	mb.color(WOOD)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.02), Vector2(0.3, 0.02), Vector2(0.34, 0.25), Vector2(0.355, 0.47),
		Vector2(0.34, 0.7), Vector2(0.31, 0.92)]), 14)
	mb.color(WOOD.darkened(0.25)) # borda da boca
	mb.lathe(PackedVector2Array([Vector2(0.31, 0.92), Vector2(0.29, 0.94), Vector2(0.28, 0.9)]), 14)
	mb.color(IRON)
	for y in [0.14, 0.47, 0.8]:
		var r := 0.345 + (0.012 if y == 0.47 else 0.0) - (0.02 if y == 0.8 else 0.0)
		mb.lathe(PackedVector2Array([Vector2(r, y - 0.03), Vector2(r + 0.012, y - 0.03), Vector2(r + 0.012, y + 0.03), Vector2(r, y + 0.03)]), 14)
	# Funil: cone de pano largo em cima, afinando até a boca do barril.
	mb.color(Color(0.66, 0.62, 0.52))
	mb.lathe(PackedVector2Array([Vector2(0.14, 0.95), Vector2(0.62, 1.2), Vector2(0.64, 1.23)]), 14)
	mb.color(WOOD)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		mb.tube(PackedVector3Array([Vector3(cos(a) * 0.33, 0.6, sin(a) * 0.33), Vector3(cos(a) * 0.64, 1.24, sin(a) * 0.64)]), 0.015, 4)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.38
	cyl.height = 0.95
	shape.shape = cyl
	shape.position.y = 0.48
	obj.add_child(shape)
	# Água: cilindro dentro do barril (escala em Y a partir do fundo).
	var water := MeshBuilder.new()
	water.color(Color(0.3, 0.45, 0.55))
	water.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.86), Vector2(0.002, 0.86)]), 14)
	var mesh := MeshInstance3D.new()
	mesh.name = "Water"
	mesh.mesh = water.finish(PlacedObject._mat(), false)
	mesh.position.y = 0.03
	mesh.scale = Vector3(1, 0.01, 1)
	mesh.visible = false
	obj.add_child(mesh)


## Fogueira: anel de pedras de tamanhos diferentes, lenha em pirâmide com casca
## e ponta queimada, cinzas e brasas, grelha de ferro com pés tortos e uma
## panelinha pendurada de lado.
static func _campfire(mb: MeshBuilder, obj: PlacedObject) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for k in 11:
		var a := TAU * k / 11.0
		var size := Vector3(rng.randf_range(0.16, 0.24), rng.randf_range(0.12, 0.2), rng.randf_range(0.13, 0.18))
		mb.color(STONE.darkened(rng.randf_range(0.0, 0.25)))
		mb.box(Vector3(cos(a) * 0.48, size.y * 0.5, sin(a) * 0.48), size, Basis(Vector3.UP, -a) * Basis(Vector3.BACK, rng.randf_range(-0.2, 0.2)))
		mb.color(Color(0.12, 0.1, 0.09)) # fuligem no lado de dentro
		mb.box(Vector3(cos(a) * 0.4, size.y * 0.5, sin(a) * 0.4), Vector3(0.02, size.y * 0.9, size.z * 0.8), Basis(Vector3.UP, -a))
	mb.color(Color(0.18, 0.16, 0.15)) # cinzas
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.02), Vector2(0.36, 0.01), Vector2(0.38, 0.0)]), 10)
	for k in 6: # lenha em pirâmide
		var a := TAU * k / 6.0 + 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		mb.color(WOOD.darkened(0.3))
		mb.tube(PackedVector3Array([dir * 0.34 + Vector3.UP * 0.04, dir * 0.15 + Vector3.UP * 0.14]), 0.04, 6)
		mb.color(Color(0.1, 0.07, 0.06))
		mb.tube(PackedVector3Array([dir * 0.15 + Vector3.UP * 0.14, dir * 0.03 + Vector3.UP * 0.24]), 0.032, 6)
	mb.color(Color(0.95, 0.45, 0.1)) # brasas
	for k in 7:
		var a := k * 0.9
		mb.box(Vector3(cos(a) * 0.12, 0.03, sin(a) * 0.1), Vector3(0.05, 0.03, 0.04), Basis(Vector3.UP, a))
	# Grelha: pés tortos de ferro, moldura e varetas.
	mb.color(IRON)
	for x in [-0.36, 0.36]:
		for z in [-0.26, 0.26]:
			mb.tube(PackedVector3Array([Vector3(x * 1.1, 0.0, z * 1.1), Vector3(x, 0.3, z), Vector3(x, 0.55, z)]), 0.018, 5)
	for z in [-0.26, 0.26]:
		mb.box(Vector3(0, 0.55, z), Vector3(0.78, 0.03, 0.035))
	for x in [-0.37, 0.37]:
		mb.box(Vector3(x, 0.55, 0), Vector3(0.035, 0.03, 0.56))
	for k in 9:
		mb.box(Vector3(-0.32 + k * 0.08, 0.565, 0), Vector3(0.014, 0.014, 0.54))
	# Panelinha pendurada no canto.
	mb.color(IRON.lightened(0.15))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.08, 0.0), Vector2(0.09, 0.09), Vector2(0.095, 0.1)]), 10, Basis.IDENTITY, Vector3(0.52, 0.3, 0.0))
	mb.tube(PackedVector3Array([Vector3(0.43, 0.42, 0), Vector3(0.52, 0.48, 0), Vector3(0.61, 0.42, 0)]), 0.006, 4)
	mb.tube(PackedVector3Array([Vector3(0.37, 0.55, 0), Vector3(0.52, 0.48, 0)]), 0.006, 4)
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
	_register_fire(obj, glow)
	# Pilha de lenha do lado e uma pá de cinzas encostada.
	for k in 5:
		mb.color(WOOD.darkened(0.1 + 0.05 * (k % 2)))
		var y := 0.07 + (k / 3) * 0.13
		var z := -0.15 + (k % 3) * 0.14 + (0.07 if k >= 3 else 0.0)
		mb.tube(PackedVector3Array([Vector3(0.72, y, z), Vector3(1.05, y, z)]), 0.065, 6)
		mb.color(Color(0.6, 0.45, 0.28))
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.06, 0.0)]), 6, Basis(Vector3.BACK, PI / 2), Vector3(1.051, y, z))
	mb.color(IRON)
	mb.tube(PackedVector3Array([Vector3(-0.66, 0.05, 0.4), Vector3(-0.72, 0.9, 0.3)]), 0.015, 5)
	mb.box(Vector3(-0.65, 0.04, 0.42), Vector3(0.14, 0.02, 0.16), Basis(Vector3.UP, 0.3))
	obj._shape(Vector3(0, 0.6, 0), Vector3(1.3, 1.2, 1.3))
	_fire(obj, Vector3(0, 0.3, 0.66), 0.0, 0.8)


## Baú construído: tábuas com frestas e veios, tampa curva de ripas, cantoneiras
## e cintas de ferro rebitadas, alças laterais e fechadura de latão com chave.
static func _chest(mb: MeshBuilder, obj: PlacedObject) -> void:
	mb.color(WOOD)
	mb.box(Vector3(0, 0.27, 0), Vector3(1.0, 0.54, 0.6))
	for k in 4: # tábuas (frente e trás) com frestas
		var y := 0.07 + k * 0.135
		mb.color(WOOD.darkened(0.04 * (k % 2)))
		for z in [0.302, -0.302]:
			mb.box(Vector3(0, y, z), Vector3(0.98, 0.12, 0.006))
	mb.color(WOOD.darkened(0.3))
	for k in 3:
		mb.box(Vector3(0, 0.135 + k * 0.135, 0.306), Vector3(0.98, 0.01, 0.004))
	# Tampa: ripas curvas.
	for k in 7:
		var a := lerpf(0.0, PI, k / 6.0)
		mb.color(WOOD.lightened(0.04 * (k % 2)))
		mb.box(Vector3(0, 0.54 + sin(a) * 0.29, cos(a) * 0.29), Vector3(0.98, 0.04, 0.14), Basis(Vector3.RIGHT, -a + PI / 2))
	mb.color(IRON)
	for x in [-0.36, 0.36]: # cintas
		mb.box(Vector3(x, 0.27, 0), Vector3(0.06, 0.56, 0.62))
		mb.lathe(PackedVector2Array([Vector2(0.31, -0.03), Vector2(0.31, 0.03)]), 10, Basis(Vector3.BACK, PI / 2), Vector3(x, 0.54, 0))
		for y in [0.1, 0.27, 0.44]:
			mb.color(ItemModels.BRASS)
			mb.box(Vector3(x, y, 0.314), Vector3(0.016, 0.016, 0.006))
			mb.color(IRON)
	for x in [-0.5, 0.5]: # cantoneiras e alças
		for z in [-0.3, 0.3]:
			mb.box(Vector3(x, 0.27, z), Vector3(0.05, 0.56, 0.05))
		mb.tube(PackedVector3Array([Vector3(x * 1.03, 0.36, -0.08), Vector3(x * 1.08, 0.3, 0.0), Vector3(x * 1.03, 0.36, 0.08)]), 0.012, 4)
	mb.color(ItemModels.BRASS)
	mb.box(Vector3(0, 0.5, 0.315), Vector3(0.12, 0.14, 0.03))
	mb.color(Color(0.08, 0.06, 0.05))
	mb.box(Vector3(0, 0.48, 0.331), Vector3(0.02, 0.04, 0.004)) # buraco da chave
	obj._shape(Vector3(0, 0.42, 0), Vector3(1.0, 0.84, 0.62))


## Mesa de trabalho: tampo grosso de tábuas com marcas, pernas com travessas
## em X, prateleira com caixas, painel de ferramentas pendurado (martelo,
## serrote, chaves, alicate), engrenagem de latão, torno de bancada e bigorna.
static func _workbench(mb: MeshBuilder, obj: PlacedObject) -> void:
	for k in 5: # tampo em tábuas
		mb.color(WOOD.darkened(0.06 + 0.04 * (k % 2)))
		mb.box(Vector3(0, 0.88, -0.34 + k * 0.17), Vector3(1.9, 0.12, 0.165))
	mb.color(Color(0.2, 0.14, 0.09))
	for k in 4: # marcas/queimados no tampo
		mb.box(Vector3(-0.6 + k * 0.42, 0.942, 0.1 - k * 0.07), Vector3(0.12, 0.002, 0.04), Basis(Vector3.UP, k * 0.7))
	mb.color(WOOD.darkened(0.2))
	for x in [-0.85, 0.85]:
		for z in [-0.35, 0.35]:
			mb.box(Vector3(x, 0.42, z), Vector3(0.12, 0.84, 0.12))
		mb.box(Vector3(x, 0.45, 0), Vector3(0.06, 0.06, 0.8), Basis(Vector3.RIGHT, 0.75)) # X lateral
		mb.box(Vector3(x, 0.45, 0), Vector3(0.06, 0.06, 0.8), Basis(Vector3.RIGHT, -0.75))
	mb.box(Vector3(0, 0.22, 0), Vector3(1.7, 0.06, 0.7)) # prateleira
	mb.color(WOOD.lightened(0.05))
	mb.box(Vector3(-0.5, 0.33, 0.05), Vector3(0.35, 0.16, 0.3)) # caixote
	mb.color(IRON)
	mb.box(Vector3(0.4, 0.3, 0.1), Vector3(0.4, 0.1, 0.22)) # caixa de ferramentas
	mb.color(Color(0.5, 0.12, 0.08))
	mb.box(Vector3(0.4, 0.36, 0.1), Vector3(0.38, 0.02, 0.2))
	# Painel de ferramentas.
	mb.color(WOOD)
	mb.box(Vector3(0, 1.45, -0.4), Vector3(1.8, 1.0, 0.05))
	mb.box(Vector3(-0.85, 1.2, -0.4), Vector3(0.08, 1.5, 0.08))
	mb.box(Vector3(0.85, 1.2, -0.4), Vector3(0.08, 1.5, 0.08))
	mb.color(WOOD.darkened(0.25))
	for k in 6:
		for j in 3:
			mb.box(Vector3(-0.75 + k * 0.3, 1.2 + j * 0.3, -0.372), Vector3(0.02, 0.02, 0.006)) # furos
	mb.color(WOOD.darkened(0.1)) # martelo pendurado
	mb.box(Vector3(-0.6, 1.45, -0.36), Vector3(0.035, 0.32, 0.03))
	mb.color(IRON)
	mb.box(Vector3(-0.6, 1.62, -0.36), Vector3(0.14, 0.05, 0.05))
	mb.box(Vector3(-0.25, 1.48, -0.365), Vector3(0.22, 0.12, 0.008)) # serrote
	mb.color(WOOD.darkened(0.1))
	mb.box(Vector3(-0.1, 1.48, -0.36), Vector3(0.08, 0.1, 0.03))
	mb.color(STEEL)
	for k in 3: # chaves
		mb.box(Vector3(0.05 + k * 0.07, 1.35, -0.365), Vector3(0.02, 0.22 - k * 0.04, 0.008))
		mb.box(Vector3(0.05 + k * 0.07, 1.47 - k * 0.02, -0.365), Vector3(0.045, 0.03, 0.008))
	mb.color(ItemModels.BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.002, -0.015), Vector2(0.14, -0.015), Vector2(0.14, 0.015), Vector2(0.002, 0.015)]), 12,
			Basis(Vector3.RIGHT, PI / 2), Vector3(0.55, 1.6, -0.36))
	for k in 12:
		var a := TAU * k / 12.0
		mb.box(Vector3(0.55 + cos(a) * 0.15, 1.6 + sin(a) * 0.15, -0.36), Vector3(0.035, 0.035, 0.03), Basis(Vector3.BACK, a))
	# Bigorna e torno de bancada.
	mb.color(IRON)
	mb.box(Vector3(-0.45, 1.0, 0.05), Vector3(0.18, 0.12, 0.16))
	mb.box(Vector3(-0.45, 1.1, 0.05), Vector3(0.42, 0.1, 0.18))
	mb.tube(PackedVector3Array([Vector3(-0.66, 1.12, 0.05), Vector3(-0.78, 1.1, 0.05)]), 0.035, 6) # chifre
	mb.box(Vector3(0.55, 1.02, 0.25), Vector3(0.18, 0.16, 0.14))
	mb.box(Vector3(0.55, 1.12, 0.25), Vector3(0.2, 0.05, 0.05)) # mandíbulas
	mb.color(STEEL)
	mb.tube(PackedVector3Array([Vector3(0.55, 1.02, 0.32), Vector3(0.55, 1.02, 0.46)]), 0.012, 5)
	mb.box(Vector3(0.55, 1.02, 0.46), Vector3(0.14, 0.015, 0.015))
	obj._shape(Vector3(0, 0.5, 0), Vector3(1.9, 1.0, 0.85))
	obj._shape(Vector3(0, 1.45, -0.4), Vector3(1.8, 1.0, 0.1))


## Chamas (partículas) + luz alaranjada que tremula.
static func _fire(obj: Node3D, at: Vector3, radius: float, strength: float) -> void:
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
	_register_fire(obj, flames)
	var light := Flicker.new()
	light.position = at + Vector3.UP * 0.4
	light.light_color = Color(1.0, 0.6, 0.3)
	light.omni_range = 7.0 * strength
	light.base_energy = 1.6 * strength
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 50.0
	obj.add_child(light)
	_register_fire(obj, light)


## Guarda as peças do fogo (chamas, luz, brasa) para acender/apagar depois.
static func _register_fire(obj: Node3D, node: Node3D) -> void:
	var list: Array = obj.get_meta("fire_nodes", [])
	list.append(node)
	obj.set_meta("fire_nodes", list)


## Acende ou apaga o fogo de um objeto (fogueira, fornalhas, forno, defumador).
static func set_lit(obj: Node3D, lit: bool) -> void:
	if obj.get_meta("lit", null) == lit:
		return
	obj.set_meta("lit", lit)
	for node in obj.get_meta("fire_nodes", []):
		if is_instance_valid(node):
			node.visible = lit
			if node is CPUParticles3D:
				node.emitting = lit


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
