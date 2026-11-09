class_name SmithingModels
extends RefCounted
## Modelos das estações de oficina (Smithing): forja com bigorna, trefiladora,
## fundição com cadinho basculante e bancada de solda.

const CRUCIBLE := Color(0.5, 0.48, 0.46) ## cadinho de grafite e argila (cinza-claro)


static func build(kind: String, obj: PlacedObject) -> void:
	match kind:
		"forge":
			_forge(obj)
		"wire_drawer":
			_wire_drawer(obj)
		"foundry":
			_foundry(obj)
		"weld_bench":
			_weld_bench(obj)
		"torch_bench":
			_torch_bench(obj)


## Forja de tijolo (esquerda) com leito de carvão, coifa de chapa em pirâmide e
## chaminé, fole de couro do lado; bigorna no toco (direita) com martelo e tenaz,
## balde de água para temperar.
static func _forge(obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	var hx := -0.4
	ObjectModels._bricks(mb, Vector3(hx, 0.4, 0), Vector3(1.1, 0.8, 0.9), 7)
	mb.color(ObjectModels.IRON)
	mb.box(Vector3(hx, 0.82, 0), Vector3(1.16, 0.05, 0.96)) # aro de ferro
	mb.color(ObjectModels.SOOT)
	mb.box(Vector3(hx, 0.85, 0.02), Vector3(0.74, 0.03, 0.56)) # leito de carvão
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for k in 22:
		mb.color(Color(0.08, 0.07, 0.07).lightened(rng.randf_range(0.0, 0.08)))
		mb.box(Vector3(hx + rng.randf_range(-0.32, 0.32), 0.875, rng.randf_range(-0.22, 0.24)), Vector3(0.07, 0.04, 0.06),
			Basis(Vector3.UP, rng.randf_range(0, PI)))
	mb.color(ObjectModels.BRICK.darkened(0.3))
	mb.box(Vector3(hx, 0.3, 0.452), Vector3(0.36, 0.26, 0.01)) # cinzeiro na frente
	# Coifa: pirâmide de chapa presa em 4 hastes, e a chaminé.
	mb.color(ObjectModels.IRON)
	for x in [-0.5, 0.5]:
		for z in [-0.4, 0.4]:
			mb.box(Vector3(hx + x, 1.12, z), Vector3(0.03, 0.56, 0.03))
	mb.color(Color(0.2, 0.19, 0.19))
	mb.lathe(PackedVector2Array([Vector2(0.76, 1.38), Vector2(0.74, 1.42), Vector2(0.2, 1.8), Vector2(0.2, 1.84)]), 4, Basis(Vector3.UP, PI / 4), Vector3(hx, 0, 0))
	mb.color(Color(0.16, 0.15, 0.15))
	mb.lathe(PackedVector2Array([Vector2(0.12, 1.8), Vector2(0.12, 2.55), Vector2(0.15, 2.58), Vector2(0.15, 2.62)]), 8, Basis.IDENTITY, Vector3(hx, 0, 0))
	# Fole de couro sanfonado (esquerda) soprando por um bico de ferro.
	mb.color(ObjectModels.WOOD_DARK)
	mb.box(Vector3(-1.2, 0.5, 0.0), Vector3(0.34, 0.035, 0.56))
	mb.box(Vector3(-1.2, 0.25, 0.0), Vector3(0.07, 0.5, 0.07))
	mb.color(Color(0.42, 0.28, 0.17))
	for k in 3:
		mb.box(Vector3(-1.2, 0.54 + k * 0.03, 0.0), Vector3(0.32 - k * 0.04, 0.03, 0.52 - k * 0.05))
	mb.color(ObjectModels.WOOD)
	mb.box(Vector3(-1.2, 0.635, 0.0), Vector3(0.34, 0.03, 0.56), Basis(Vector3.BACK, 0.08))
	mb.box(Vector3(-1.2, 0.66, 0.34), Vector3(0.05, 0.04, 0.16))
	mb.color(ObjectModels.IRON)
	mb.tube(PackedVector3Array([Vector3(-1.04, 0.55, 0.0), Vector3(-0.95, 0.6, 0.0)]), 0.035, 6)
	# Toco, bigorna (base, cintura, mesa, bico e talão), martelo e tenaz.
	var ax := 0.72
	mb.color(ObjectModels.WOOD_DARK)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.24, 0.0), Vector2(0.23, 0.44), Vector2(0.002, 0.44)]), 10, Basis.IDENTITY, Vector3(ax, 0, 0))
	mb.color(ObjectModels.WOOD_LIGHT)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.441), Vector2(0.2, 0.441)]), 10, Basis.IDENTITY, Vector3(ax, 0, 0))
	mb.color(Color(0.17, 0.17, 0.18))
	mb.box(Vector3(ax, 0.48, 0), Vector3(0.34, 0.07, 0.22))
	mb.box(Vector3(ax, 0.56, 0), Vector3(0.18, 0.1, 0.13))
	mb.box(Vector3(ax, 0.645, 0), Vector3(0.44, 0.08, 0.17))
	mb.lathe(PackedVector2Array([Vector2(0.075, 0.0), Vector2(0.002, 0.2)]), 8, Basis(Vector3.BACK, PI / 2), Vector3(ax - 0.22, 0.65, 0)) # bico
	mb.box(Vector3(ax + 0.25, 0.655, 0), Vector3(0.08, 0.06, 0.12)) # talão
	mb.color(Color(0.36, 0.36, 0.38))
	mb.box(Vector3(ax, 0.687, 0), Vector3(0.42, 0.006, 0.15)) # mesa polida
	mb.color(ObjectModels.WOOD)
	mb.tube(PackedVector3Array([Vector3(ax + 0.06, 0.705, -0.06), Vector3(ax + 0.34, 0.705, -0.15)]), 0.016, 5) # cabo do martelo (atrás)
	mb.color(ObjectModels.IRON)
	mb.box(Vector3(ax + 0.05, 0.712, -0.055), Vector3(0.05, 0.05, 0.1), Basis(Vector3.UP, 0.32))
	mb.color(Color(0.15, 0.15, 0.16))
	for side in [-0.015, 0.015]:
		mb.tube(PackedVector3Array([Vector3(ax + 0.32, 0.0, 0.28 + side), Vector3(ax + 0.24, 0.5, 0.2 + side)]), 0.01, 4) # tenaz
	# Balde de água para temperar.
	mb.color(ObjectModels.WOOD)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.15, 0.0), Vector2(0.18, 0.3), Vector2(0.16, 0.3), Vector2(0.14, 0.03)]), 10, Basis.IDENTITY, Vector3(ax - 0.05, 0, 0.55))
	mb.color(ObjectModels.IRON)
	for y in [0.06, 0.24]:
		mb.lathe(PackedVector2Array([Vector2(0.155 + y * 0.1, y), Vector2(0.158 + y * 0.1, y + 0.025)]), 10, Basis.IDENTITY, Vector3(ax - 0.05, 0, 0.55))
	mb.color(ObjectModels.WATER)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.26), Vector2(0.165, 0.26)]), 10, Basis.IDENTITY, Vector3(ax - 0.05, 0, 0.55))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	# Brasas acesas (só com a forja quente) e a peça em brasa na bigorna.
	var embers := MeshBuilder.new()
	for k in 14:
		embers.color(Color(1.0, 0.42 + rng.randf_range(0.0, 0.3), 0.1))
		embers.box(Vector3(hx + rng.randf_range(-0.3, 0.3), 0.885, rng.randf_range(-0.2, 0.22)), Vector3(0.06, 0.03, 0.05))
	var glow := MeshInstance3D.new()
	glow.mesh = embers.finish(StationModels._glow_mat(), false)
	obj.add_child(glow)
	var nodes: Array = obj.get_meta("fire_nodes", [])
	nodes.append(glow)
	obj.set_meta("fire_nodes", nodes)
	StationModels._fire(obj, Vector3(hx, 0.9, 0.02), 0.22, 0.6)
	_hot_piece(obj, Vector3(0.24, 0.022, 0.045), Vector3(ax - 0.06, 0.702, 0.035))
	obj._shape(Vector3(-0.2, 0.45, 0), Vector3(2.4, 0.9, 1.0))


## Peça quente (some quando esfria): caixinha com o shader de cor por temperatura.
## Smithing.refresh esfria pelo tempo desde o último uso.
static func _hot_piece(obj: PlacedObject, size: Vector3, at: Vector3) -> void:
	var bar := MeshInstance3D.new()
	bar.name = "HotBar"
	var box := BoxMesh.new()
	box.size = size
	bar.mesh = box
	var heat := ShaderMaterial.new()
	heat.shader = load("res://shaders/forge_heat.gdshader")
	bar.material_override = heat
	bar.position = at
	bar.visible = false
	obj.add_child(bar)


## Fundição: fornalhinha redonda de tijolo com o fogo em cima (esquerda), o cadinho
## de barro inclinado num cavalete com o cabo comprido (meio) e a caixa de areia com
## os moldes (direita): três lingoteiras e o funil; o metal fica brilhando nelas
## depois de despejar. Lingoteiras de ferro, escumadeira e lingotes de bronze.
static func _foundry(obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	var fx := -0.62
	# Fornalhinha quadrada de tijolo com boca redonda em cima (a brasa) e cinzeiro na frente.
	ObjectModels._bricks(mb, Vector3(fx, 0.36, 0), Vector3(0.7, 0.72, 0.7), 6)
	mb.color(ObjectModels.BRICK.darkened(0.25))
	mb.box(Vector3(fx, 0.735, 0), Vector3(0.74, 0.04, 0.74)) # coroa
	mb.color(ObjectModels.SOOT)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.745), Vector2(0.22, 0.745), Vector2(0.25, 0.757)]), 10, Basis.IDENTITY, Vector3(fx, 0, 0))
	ObjectModels.mouth(mb, Vector3(fx, 0.2, 0.35), 0.24, 0.18)
	mb.color(ObjectModels.IRON)
	for x in [-0.35, 0.35]:
		for z in [-0.35, 0.35]:
			mb.box(Vector3(fx + x, 0.36, z), Vector3(0.04, 0.74, 0.04)) # cantoneiras
	mb.color(ObjectModels.STONE.darkened(0.25))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.28, 0.0), Vector2(0.28, 0.04), Vector2(0.002, 0.04)]), 10,
		Basis(Vector3.BACK, 1.2), Vector3(fx - 0.4, 0.28, 0.2)) # tampa encostada
	mb.color(ObjectModels.IRON)
	mb.tube(PackedVector3Array([Vector3(fx - 0.3, 0.18, 0.12), Vector3(fx - 0.5, 0.12, 0.2)]), 0.04, 6) # bico do fole
	# Cavalete com o cadinho basculante (pino no alto, cabo comprido para trás).
	var cx := 0.02
	mb.color(ObjectModels.IRON)
	for z in [-0.22, 0.22]:
		mb.box(Vector3(cx, 0.45, z), Vector3(0.05, 0.9, 0.05))
		mb.box(Vector3(cx, 0.03, z), Vector3(0.3, 0.05, 0.06))
	mb.tube(PackedVector3Array([Vector3(cx, 0.88, -0.24), Vector3(cx, 0.88, 0.24)]), 0.02, 6) # pino
	var tilt := Basis(Vector3.BACK, -0.45)
	var pot := Vector3(cx, 0.88, 0)
	mb.color(CRUCIBLE)
	mb.lathe(PackedVector2Array([Vector2(0.002, -0.2), Vector2(0.1, -0.2), Vector2(0.15, -0.05), Vector2(0.16, 0.1), Vector2(0.14, 0.1), Vector2(0.13, -0.04)]), 10, tilt, pot)
	mb.color(Color(1.0, 0.55, 0.15))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.04), Vector2(0.13, 0.04)]), 10, tilt, pot) # metal derretido
	mb.color(ItemModels.STEEL)
	mb.lathe(PackedVector2Array([Vector2(0.165, 0.0), Vector2(0.168, 0.015)]), 10, tilt, pot) # anel do cavalete
	mb.tube(PackedVector3Array([pot + tilt * Vector3(-0.17, 0.0, 0), pot + tilt * Vector3(-0.6, -0.05, 0)]), 0.018, 5) # cabo
	mb.color(ObjectModels.WOOD_DARK)
	mb.tube(PackedVector3Array([pot + tilt * Vector3(-0.6, -0.05, 0), pot + tilt * Vector3(-0.78, -0.07, 0)]), 0.026, 6)
	# Caixa de areia com os moldes.
	var sx := 0.62
	mb.color(ObjectModels.WOOD)
	mb.box(Vector3(sx, 0.2, 0), Vector3(0.7, 0.4, 0.8))
	mb.color(ObjectModels.WOOD_DARK)
	for z in [-0.41, 0.41]:
		mb.box(Vector3(sx, 0.38, z), Vector3(0.74, 0.06, 0.03))
	for x in [-0.36, 0.36]:
		mb.box(Vector3(sx + x, 0.38, 0), Vector3(0.03, 0.06, 0.84))
	mb.color(Color(0.62, 0.5, 0.34))
	mb.box(Vector3(sx, 0.4, 0), Vector3(0.68, 0.02, 0.78)) # areia batida
	mb.color(Color(0.3, 0.24, 0.17))
	for z in [-0.22, 0.0, 0.22]:
		mb.box(Vector3(sx + 0.05, 0.408, z), Vector3(0.4, 0.008, 0.12)) # lingoteiras na areia
	mb.box(Vector3(sx - 0.24, 0.408, 0.0), Vector3(0.08, 0.008, 0.08)) # funil
	mb.box(Vector3(sx - 0.17, 0.408, 0.0), Vector3(0.06, 0.008, 0.5)) # canal
	# Lingoteiras de ferro e lingotes de bronze no chão, escumadeira encostada.
	mb.color(ObjectModels.IRON)
	mb.box(Vector3(sx + 0.15, 0.03, 0.62), Vector3(0.36, 0.06, 0.14))
	mb.color(Color(0.66, 0.46, 0.2))
	for k in 2:
		mb.box(Vector3(sx - 0.2 + k * 0.08, 0.025, 0.6), Vector3(0.06, 0.04, 0.2), Basis(Vector3.UP, 0.2 * k))
	mb.color(ObjectModels.IRON)
	mb.tube(PackedVector3Array([Vector3(sx + 0.42, 0.0, -0.3), Vector3(sx + 0.38, 0.75, -0.36)]), 0.012, 4)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.06, 0.0), Vector2(0.06, 0.02)]), 8, Basis.IDENTITY, Vector3(sx + 0.42, 0.0, -0.3))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	var embers := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for k in 10:
		embers.color(Color(1.0, 0.45 + rng.randf_range(0.0, 0.3), 0.1))
		embers.box(Vector3(fx + rng.randf_range(-0.18, 0.18), 0.715, rng.randf_range(-0.18, 0.18)), Vector3(0.06, 0.03, 0.05))
	var glow := MeshInstance3D.new()
	glow.mesh = embers.finish(StationModels._glow_mat(), false)
	obj.add_child(glow)
	StationModels._register_fire(obj, glow)
	StationModels._fire(obj, Vector3(fx, 0.74, 0), 0.2, 0.6)
	_hot_piece(obj, Vector3(0.38, 0.02, 0.1), Vector3(sx + 0.05, 0.41, 0.0)) # lingote recém-despejado
	obj._shape(Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 1.0))


## Bancada de solda: mesa de chapa de aço com pernas de tubo, morsa na ponta, duas
## chapas presas com o cordão no meio, a máquina de solda (transformador) com o
## mostrador e o borne de latão em cima (o cabo da rede prende ali), o porta-eletrodo
## e a garra-terra nos cabos pretos, e a máscara de solda pendurada.
static func _weld_bench(obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	var steel := ItemModels.STEEL.darkened(0.25)
	mb.color(steel)
	mb.box(Vector3(0, 0.85, 0), Vector3(1.6, 0.05, 0.75)) # tampo de chapa
	mb.color(ObjectModels.IRON)
	for x in [-0.74, 0.74]:
		for z in [-0.33, 0.33]:
			mb.box(Vector3(x, 0.42, z), Vector3(0.06, 0.84, 0.06))
		mb.box(Vector3(x, 0.2, 0), Vector3(0.05, 0.05, 0.66))
	mb.box(Vector3(0, 0.2, 0), Vector3(1.5, 0.04, 0.55)) # prateleira
	# Morsa na ponta direita.
	mb.color(Color(0.22, 0.32, 0.45))
	mb.box(Vector3(0.66, 0.93, 0.2), Vector3(0.16, 0.12, 0.14))
	mb.box(Vector3(0.66, 0.93, 0.33), Vector3(0.16, 0.12, 0.05))
	mb.color(ItemModels.STEEL)
	mb.tube(PackedVector3Array([Vector3(0.66, 0.93, 0.36), Vector3(0.66, 0.93, 0.48)]), 0.012, 5)
	mb.box(Vector3(0.66, 0.93, 0.48), Vector3(0.14, 0.015, 0.015))
	# Duas chapas sendo soldadas e o cordão.
	mb.color(ItemModels.STEEL.darkened(0.05))
	mb.box(Vector3(0.05, 0.882, 0.05), Vector3(0.5, 0.014, 0.18))
	mb.box(Vector3(0.05, 0.882, 0.24), Vector3(0.5, 0.014, 0.18))
	for k in 12:
		mb.color(ItemModels.STEEL.lightened(0.2 if k % 2 == 0 else 0.1))
		mb.box(Vector3(-0.18 + k * 0.04, 0.892, 0.145), Vector3(0.036, 0.01, 0.024), Basis(Vector3.UP, 0.5))
	# Máquina de solda (transformador) em cima, à esquerda e atrás.
	mb.color(Color(0.62, 0.18, 0.12))
	mb.box(Vector3(-0.58, 1.01, -0.18), Vector3(0.34, 0.27, 0.28))
	mb.color(ObjectModels.IRON)
	for k in 5:
		mb.box(Vector3(-0.58, 0.94 + k * 0.035, -0.035), Vector3(0.26, 0.012, 0.01)) # grade de ventilação
	mb.color(Color(0.92, 0.85, 0.5))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.05, 0.0)]), 12, Basis(Vector3.RIGHT, PI / 2), Vector3(-0.68, 1.06, -0.035)) # mostrador
	mb.color(ItemModels.DARK)
	mb.box(Vector3(-0.66, 1.07, -0.03), Vector3(0.006, 0.04, 0.004), Basis(Vector3.BACK, -0.6)) # ponteiro
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.03, 0.0), Vector2(0.03, 0.03), Vector2(0.002, 0.03)]), 8,
		Basis(Vector3.RIGHT, PI / 2), Vector3(-0.5, 1.02, -0.035)) # botão
	mb.color(ItemModels.BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.018, 0.0), Vector2(0.018, 0.04), Vector2(0.025, 0.05), Vector2(0.002, 0.05)]), 8,
		Basis.IDENTITY, Vector3(-0.66, 1.145, -0.2)) # borne da rede
	mb.color(ObjectModels.IRON)
	mb.box(Vector3(-0.58, 1.155, -0.18), Vector3(0.1, 0.02, 0.04)) # alça
	# Cabos pretos: porta-eletrodo na mesa e garra-terra na chapa.
	mb.color(Color(0.08, 0.08, 0.09))
	mb.tube(PackedVector3Array([Vector3(-0.5, 0.95, -0.04), Vector3(-0.42, 0.9, 0.1), Vector3(-0.3, 0.89, 0.25), Vector3(-0.22, 0.89, 0.3)]), 0.012, 5)
	mb.tube(PackedVector3Array([Vector3(-0.62, 0.95, -0.04), Vector3(-0.62, 0.89, 0.1), Vector3(-0.3, 0.89, 0.0)]), 0.012, 5)
	mb.color(Color(0.75, 0.6, 0.15))
	mb.box(Vector3(-0.16, 0.9, 0.32), Vector3(0.14, 0.03, 0.04), Basis(Vector3.UP, -0.3)) # porta-eletrodo
	mb.color(ItemModels.STEEL)
	mb.box(Vector3(-0.06, 0.895, 0.36), Vector3(0.1, 0.006, 0.006), Basis(Vector3.UP, -0.3)) # eletrodo
	mb.color(Color(0.7, 0.18, 0.12))
	mb.box(Vector3(-0.28, 0.9, 0.0), Vector3(0.06, 0.03, 0.05)) # garra-terra
	# Máscara de solda pendurada na lateral.
	mb.color(ItemModels.DARK.lightened(0.08))
	mb.box(Vector3(-0.83, 0.62, 0.0), Vector3(0.03, 0.26, 0.22))
	mb.color(Color(0.25, 0.45, 0.22))
	mb.box(Vector3(-0.85, 0.66, 0.0), Vector3(0.006, 0.05, 0.12))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	# Faíscas e o clarão azulado (só logo depois de soldar).
	var sparks := CPUParticles3D.new()
	sparks.amount = 24
	sparks.lifetime = 0.5
	sparks.position = Vector3(0.05, 0.9, 0.145)
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.gravity = Vector3(0, -6, 0)
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 2.0
	var spark := BoxMesh.new()
	spark.size = Vector3.ONE * 0.012
	spark.material = StationModels._glow_mat()
	sparks.mesh = spark
	sparks.color = Color(1.0, 0.75, 0.35)
	obj.add_child(sparks)
	StationModels._register_fire(obj, sparks)
	var flash := OmniLight3D.new()
	flash.position = Vector3(0.05, 1.05, 0.145)
	flash.light_color = Color(0.7, 0.8, 1.0)
	flash.omni_range = 3.0
	flash.light_energy = 0.8
	obj.add_child(flash)
	StationModels._register_fire(obj, flash)
	_hot_piece(obj, Vector3(0.46, 0.012, 0.03), Vector3(0.05, 0.895, 0.145)) # cordão ainda quente
	obj._shape(Vector3(0, 0.5, 0), Vector3(1.7, 1.0, 0.8))


## Trefiladora: bancada comprida de madeira; a barra de cobre passa pela fieira
## (bloco de ferro com o furo de latão) e sai fio, que enrola no tambor de cima
## (gira com o eixo). Porta de latão à esquerda (AutoMachines.add_hub).
static func _wire_drawer(obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	mb.color(ObjectModels.WOOD)
	mb.box(Vector3(0, 0.62, 0), Vector3(1.8, 0.07, 0.6)) # tampo
	mb.color(ObjectModels.WOOD_DARK)
	for x in [-0.75, 0.75]:
		for z in [-0.24, 0.24]:
			mb.box(Vector3(x, 0.3, z), Vector3(0.08, 0.6, 0.08))
		mb.box(Vector3(x, 0.12, 0), Vector3(0.06, 0.06, 0.5))
	mb.box(Vector3(0, 0.12, 0), Vector3(1.5, 0.05, 0.05))
	# Fieira: bloco de ferro preso no tampo, com o furo de latão.
	mb.color(ObjectModels.IRON)
	mb.box(Vector3(-0.35, 0.8, 0), Vector3(0.12, 0.3, 0.28))
	mb.box(Vector3(-0.35, 0.67, 0), Vector3(0.2, 0.04, 0.34))
	mb.color(ItemModels.BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.01, -0.065), Vector2(0.05, -0.065), Vector2(0.05, 0.065), Vector2(0.01, 0.065)]), 10, Basis(Vector3.BACK, PI / 2), Vector3(-0.35, 0.82, 0))
	# Barra de cobre entrando e o fio saindo até o tambor.
	mb.color(ObjectModels.COPPER)
	mb.box(Vector3(-0.66, 0.82, 0), Vector3(0.5, 0.035, 0.035))
	mb.tube(PackedVector3Array([Vector3(-0.29, 0.82, 0), Vector3(0.3, 0.82, -0.17)]), 0.006, 4)
	# Mesa de apoio da barra.
	mb.color(ObjectModels.WOOD_LIGHT)
	mb.box(Vector3(-0.66, 0.68, 0), Vector3(0.5, 0.05, 0.12))
	# Caixa de engrenagens embaixo do tambor, ligada à porta da esquerda por um eixo.
	mb.color(ObjectModels.IRON)
	mb.box(Vector3(0.48, 0.5, 0), Vector3(0.3, 0.2, 0.3))
	mb.color(ItemModels.STEEL)
	mb.tube(PackedVector3Array([Vector3(-0.9, 0.6, 0), Vector3(0.34, 0.6, 0)]), 0.02, 6)
	# Rolos de fio prontos na ponta da bancada.
	for k in 2:
		mb.color(ObjectModels.COPPER.lightened(0.05 * k))
		mb.torus(0.07, 0.022, 10, 4, Basis.IDENTITY, Vector3(0.8, 0.675 + k * 0.035, 0.12))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	# Tambor (gira com o eixo): carretel de ferro com o fio de cobre enrolado.
	var drum := MeshBuilder.new()
	drum.color(ObjectModels.IRON)
	drum.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.24, 0.0), Vector2(0.24, 0.03), Vector2(0.18, 0.03), Vector2(0.18, 0.2),
		Vector2(0.24, 0.2), Vector2(0.24, 0.23), Vector2(0.002, 0.23)]), 14)
	for k in 5:
		drum.color(ObjectModels.COPPER.darkened(0.06 * (k % 2)))
		drum.torus(0.185, 0.014, 16, 4, Basis.IDENTITY, Vector3(0, 0.05 + k * 0.032, 0))
	drum.color(ItemModels.BRASS)
	drum.box(Vector3(0.0, 0.25, 0.0), Vector3(0.36, 0.03, 0.04)) # trava
	var spin := MeshInstance3D.new()
	spin.name = "Spin"
	spin.mesh = drum.finish(PlacedObject._mat(), false)
	spin.position = Vector3(0.48, 0.655, 0)
	obj.add_child(spin)
	var spinner := PowerSpin.new()
	spinner.axis = Vector3.UP
	obj.add_child(spinner)
	obj._shape(Vector3(0, 0.45, 0), Vector3(1.9, 0.9, 0.65))


## Bancada de maçarico: bancada de madeira com tampo de tijolo refratário, o botijão
## de gás no chão com a mangueira até o maçarico deitado na bancada, a lamparina de
## álcool, canos de cobre sendo emendados, a serpentina pronta e o rolo de estanho.
static func _torch_bench(obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	mb.color(ObjectModels.WOOD)
	mb.box(Vector3(0, 0.78, 0), Vector3(1.5, 0.06, 0.7))
	mb.color(ObjectModels.WOOD_DARK)
	for x in [-0.68, 0.68]:
		for z in [-0.29, 0.29]:
			mb.box(Vector3(x, 0.38, z), Vector3(0.07, 0.76, 0.07))
	mb.box(Vector3(0, 0.15, 0), Vector3(1.4, 0.04, 0.6)) # prateleira
	for k in 3: # tampo de tijolo refratário
		for m in 2:
			mb.color(Color(0.78, 0.68, 0.52).darkened(0.06 * ((k + m) % 2)))
			mb.box(Vector3(-0.1 + k * 0.24, 0.825, -0.08 + m * 0.24), Vector3(0.23, 0.035, 0.23))
	# Canos de cobre emendados no tijolo e a junta brilhando de estanho.
	mb.color(ObjectModels.COPPER)
	mb.tube(PackedVector3Array([Vector3(-0.18, 0.86, 0.04), Vector3(0.12, 0.86, 0.04)]), 0.022, 8)
	mb.tube(PackedVector3Array([Vector3(0.14, 0.86, 0.04), Vector3(0.4, 0.86, 0.04)]), 0.022, 8)
	mb.color(Color(0.75, 0.75, 0.72))
	mb.lathe(PackedVector2Array([Vector2(0.024, -0.015), Vector2(0.028, 0.0), Vector2(0.024, 0.015)]), 8, Basis(Vector3.BACK, PI / 2), Vector3(0.13, 0.86, 0.04))
	# Serpentina pronta na ponta esquerda.
	for k in 5:
		mb.color(ObjectModels.COPPER.lightened(0.05 * (k % 2)))
		mb.torus(0.1, 0.014, 14, 4, Basis.IDENTITY, Vector3(-0.52, 0.85 + k * 0.032, 0.1))
	mb.color(ObjectModels.COPPER)
	mb.tube(PackedVector3Array([Vector3(-0.42, 1.0, 0.1), Vector3(-0.42, 1.08, 0.1)]), 0.014, 5)
	# Rolo de estanho e lamparina de álcool.
	mb.color(Color(0.72, 0.72, 0.7))
	mb.torus(0.04, 0.012, 10, 4, Basis(Vector3.RIGHT, PI / 2), Vector3(0.52, 0.86, -0.2))
	mb.color(Color(0.62, 0.74, 0.72))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.81), Vector2(0.05, 0.81), Vector2(0.05, 0.87), Vector2(0.02, 0.9), Vector2(0.002, 0.9)]), 8, Basis.IDENTITY, Vector3(0.3, 0, -0.22))
	mb.color(ObjectModels.CLOTH)
	mb.box(Vector3(0.3, 0.915, -0.22), Vector3(0.012, 0.03, 0.012)) # pavio
	# Botijão de gás no chão (vermelho, com alça e registro) e a mangueira até o maçarico.
	var gx := -0.95
	mb.color(Color(0.62, 0.12, 0.1))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.03), Vector2(0.15, 0.03), Vector2(0.17, 0.1), Vector2(0.17, 0.36), Vector2(0.13, 0.46), Vector2(0.05, 0.5), Vector2(0.002, 0.5)]), 12,
		Basis.IDENTITY, Vector3(gx, 0, 0.05))
	mb.color(ObjectModels.IRON)
	mb.lathe(PackedVector2Array([Vector2(0.14, 0.0), Vector2(0.16, 0.0), Vector2(0.16, 0.04), Vector2(0.14, 0.04)]), 12, Basis.IDENTITY, Vector3(gx, 0, 0.05)) # base
	mb.torus(0.09, 0.012, 12, 4, Basis.IDENTITY, Vector3(gx, 0.58, 0.05)) # alça
	for k in 3:
		var a := TAU * k / 3.0
		mb.box(Vector3(gx + cos(a) * 0.08, 0.53, 0.05 + sin(a) * 0.08), Vector3(0.015, 0.08, 0.015))
	mb.color(ItemModels.BRASS)
	mb.box(Vector3(gx, 0.53, 0.05), Vector3(0.05, 0.05, 0.05)) # registro
	mb.color(Color(0.1, 0.1, 0.11))
	mb.tube(PackedVector3Array([Vector3(gx + 0.03, 0.53, 0.05), Vector3(gx + 0.25, 0.45, 0.25), Vector3(-0.55, 0.7, 0.33), Vector3(-0.2, 0.84, 0.28)]), 0.012, 5)
	mb.color(ItemModels.BRASS)
	mb.tube(PackedVector3Array([Vector3(-0.2, 0.84, 0.28), Vector3(0.02, 0.86, 0.2)]), 0.016, 6) # maçarico
	mb.color(ItemModels.STEEL)
	mb.tube(PackedVector3Array([Vector3(0.02, 0.86, 0.2), Vector3(0.08, 0.875, 0.14)]), 0.008, 5) # bico
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	# Chama do maçarico (só logo depois de soldar): azul por dentro, laranja na ponta.
	var flame := MeshBuilder.new()
	flame.color(Color(0.45, 0.65, 1.0))
	flame.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.012, 0.02), Vector2(0.002, 0.07)]), 6, Basis(Vector3.BACK, -1.2), Vector3(0.09, 0.878, 0.13))
	flame.color(Color(1.0, 0.6, 0.2))
	flame.lathe(PackedVector2Array([Vector2(0.002, 0.05), Vector2(0.01, 0.07), Vector2(0.002, 0.12)]), 6, Basis(Vector3.BACK, -1.2), Vector3(0.09, 0.878, 0.13))
	var cone := MeshInstance3D.new()
	cone.mesh = flame.finish(StationModels._glow_mat(), false)
	obj.add_child(cone)
	StationModels._register_fire(obj, cone)
	var light := OmniLight3D.new()
	light.position = Vector3(0.15, 0.95, 0.1)
	light.light_color = Color(0.8, 0.75, 1.0)
	light.omni_range = 2.5
	light.light_energy = 0.7
	obj.add_child(light)
	StationModels._register_fire(obj, light)
	_hot_piece(obj, Vector3(0.05, 0.05, 0.05), Vector3(0.13, 0.86, 0.04)) # emenda quente
	obj._shape(Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.75))
