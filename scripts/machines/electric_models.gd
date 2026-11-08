class_name ElectricModels
extends RefCounted
## Modelos das peças elétricas (Tier 4), no padrão das máquinas: madeira, ferro
## fundido, latão, cobre e isoladores de porcelana. Partes com nome:
##   "Spin"   eixo do dínamo (PowerSpin)        "Glow"   o que acende com energia
##   "Light"  luz da lâmpada                     "Needle" ponteiro (bateria, rádio)
##   "Level"  líquido dos jarros da bateria (escala pela carga)

const WOOD := Color(0.45, 0.3, 0.17)
const WOOD_DARK := Color(0.3, 0.19, 0.1)
const PORCELAIN := Color(0.88, 0.87, 0.82)
const GLASS := Color(0.62, 0.74, 0.72)
const CELL := Color(0.12, 0.16, 0.3)
const BULB := Color(0.86, 0.83, 0.72)

static var _warm: Material


static func build(kind: String, obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	match kind:
		"connector":
			# Poste de madeira com braço e isolador de porcelana no topo.
			mb.color(WOOD_DARK)
			mb.box(Vector3(0, 0.6, 0), Vector3(0.1, 1.2, 0.1))
			mb.box(Vector3(0, 0.03, 0), Vector3(0.24, 0.06, 0.24)) # sapata
			mb.color(WOOD)
			mb.box(Vector3(0, 1.08, 0), Vector3(0.36, 0.06, 0.07)) # braço
			mb.color(ItemModels.IRON)
			mb.box(Vector3(0, 1.08, 0.04), Vector3(0.05, 0.12, 0.012)) # abraçadeira
			_insulator(mb, Vector3(0, 1.2, 0))
			obj._shape(Vector3(0, 0.62, 0), Vector3(0.24, 1.24, 0.24))
		"connector_wall":
			# Suporte na parede (z = 0 é a parede, sai para +Z) com isolador.
			mb.color(WOOD_DARK)
			mb.box(Vector3(0, 0, 0.012), Vector3(0.12, 0.2, 0.024))
			mb.color(ItemModels.IRON)
			mb.box(Vector3(0, -0.03, 0.07), Vector3(0.025, 0.025, 0.11))
			for y in [-0.07, 0.07]:
				mb.box(Vector3(0, y, 0.026), Vector3(0.016, 0.016, 0.006)) # parafusos
			_insulator(mb, Vector3(0, -0.02, 0.14), 0.7)
			obj._shape(Vector3(0, 0, 0.08), Vector3(0.14, 0.22, 0.16))
		"dynamo":
			_dynamo(mb, obj)
		"solar_panel":
			_solar(mb, obj)
		"battery":
			_battery(mb, obj)
		"lamp":
			# Lampadário: pé de ferro fundido, haste e lâmpada numa gaiola de latão.
			mb.color(ItemModels.IRON)
			mb.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.16, 0.04), Vector2(0.06, 0.08), Vector2(0.03, 0.12)]), 10)
			mb.tube(PackedVector3Array([Vector3(0, 0.1, 0), Vector3(0, 1.45, 0)]), 0.018, 6)
			mb.color(ItemModels.BRASS)
			mb.lathe(PackedVector2Array([Vector2(0.02, 1.42), Vector2(0.09, 1.46), Vector2(0.1, 1.5), Vector2(0.03, 1.52)]), 10)
			_cage(mb, Vector3(0, 1.52, 0))
			_bulb(obj, Vector3(0, 1.6, 0), 1.0)
			_light(obj, Vector3(0, 1.62, 0), 9.0)
			_terminal_box(mb, Vector3(0, 0.18, -0.12))
			obj._shape(Vector3(0, 0.8, 0), Vector3(0.36, 1.6, 0.36))
		"lamp_wall":
			# Arandela: placa na parede, braço curvo e lâmpada pendurada numa gaiola.
			mb.color(ItemModels.BRASS.darkened(0.15))
			mb.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.06, 0.02), Vector2(0.0, 0.025)]), 10, Basis(Vector3.RIGHT, PI / 2))
			mb.color(ItemModels.IRON)
			mb.tube(PackedVector3Array([Vector3(0, 0, 0.02), Vector3(0, 0.05, 0.12), Vector3(0, 0.08, 0.22), Vector3(0, 0.04, 0.27)]), 0.012, 6)
			_cage(mb, Vector3(0, -0.06, 0.27))
			_bulb(obj, Vector3(0, 0.02, 0.27), 0.8)
			_light(obj, Vector3(0, 0.0, 0.3), 8.0)
			obj._shape(Vector3(0, 0.0, 0.15), Vector3(0.2, 0.25, 0.3))
		"electric_fence":
			_fence(mb, obj)
		"fridge":
			_fridge(mb, obj)
		"radio":
			_radio(mb, obj)
		"electric_pump":
			_pump(mb, obj)
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	refresh(obj)


# --- Peças ---------------------------------------------------------------------------

## Isolador de porcelana (sinos empilhados) com o borne de latão em cima.
static func _insulator(mb: MeshBuilder, at: Vector3, s := 1.0) -> void:
	mb.color(PORCELAIN)
	mb.lathe(_scaled(PackedVector2Array([Vector2(0.012, 0.0), Vector2(0.05, 0.0), Vector2(0.045, 0.02), Vector2(0.03, 0.025),
		Vector2(0.042, 0.035), Vector2(0.036, 0.05), Vector2(0.022, 0.055), Vector2(0.024, 0.07), Vector2(0.002, 0.075)]), s), 10, Basis.IDENTITY, at)
	mb.color(ItemModels.BRASS)
	mb.box(at + Vector3(0, 0.075 * s, 0), Vector3(0.025, 0.02, 0.025) * s)


static func _scaled(profile: PackedVector2Array, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in profile:
		out.append(p * s)
	return out


## Caixinha de bornes (onde o cabo entra) nas máquinas.
static func _terminal_box(mb: MeshBuilder, at: Vector3) -> void:
	mb.color(ItemModels.IRON.lightened(0.1))
	mb.box(at, Vector3(0.1, 0.08, 0.06))
	mb.color(PORCELAIN)
	mb.box(at + Vector3(0, 0.05, 0), Vector3(0.05, 0.03, 0.04))
	mb.color(ItemModels.BRASS)
	mb.box(at + Vector3(0, 0.075, 0), Vector3(0.02, 0.02, 0.02))


static func _cage(mb: MeshBuilder, base: Vector3) -> void:
	mb.color(ItemModels.BRASS)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		var p := Vector3(cos(a), 0, sin(a)) * 0.075
		mb.tube(PackedVector3Array([base + p * 0.6, base + p + Vector3.UP * 0.06, base + p + Vector3.UP * 0.15, base + p * 0.5 + Vector3.UP * 0.2]), 0.005, 4, false)
	mb.torus(0.075, 0.006, 12, 4, Basis.IDENTITY, base + Vector3.UP * 0.1)


## Lâmpada (vidro amarelado; acende com energia).
static func _bulb(obj: PlacedObject, at: Vector3, s: float) -> void:
	var bulb := MeshBuilder.new()
	bulb.color(BULB)
	bulb.lathe(PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.03, -0.045), Vector2(0.05, -0.02), Vector2(0.052, 0.0),
		Vector2(0.04, 0.03), Vector2(0.018, 0.05), Vector2(0.016, 0.07), Vector2(0.0, 0.072)]), 10)
	var node := MeshInstance3D.new()
	node.name = "Glow"
	node.mesh = bulb.finish(null, true)
	node.position = at
	node.scale = Vector3.ONE * s
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	obj.add_child(node)


static func _light(obj: PlacedObject, at: Vector3, radius: float) -> void:
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position = at
	light.light_color = Color(1.0, 0.82, 0.55)
	light.light_energy = 1.4
	light.omni_range = radius
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 45.0
	light.distance_fade_length = 10.0
	light.visible = false
	obj.add_child(light)


static func _dynamo(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Base de ferro fundido, carcaça com bobinas de cobre e eixo até a porta de latão (-X).
	mb.color(ItemModels.IRON)
	mb.box(Vector3(0.05, 0.06, 0), Vector3(1.0, 0.12, 0.6))
	for x in [-0.3, 0.4]:
		mb.box(Vector3(x, 0.24, 0), Vector3(0.12, 0.28, 0.5)) # mancais
	var axis := Basis(Vector3.BACK, -PI / 2) # lathe em Y -> ao longo de X
	mb.color(ItemModels.IRON.lightened(0.12))
	mb.lathe(PackedVector2Array([Vector2(0.0, -0.36), Vector2(0.2, -0.36), Vector2(0.27, -0.3), Vector2(0.27, 0.3), Vector2(0.2, 0.36), Vector2(0.0, 0.36)]), 12, axis, Vector3(0.05, 0.6, 0))
	mb.color(ItemModels.COPPER)
	for x in [-0.2, -0.07, 0.06, 0.19]:
		mb.lathe(PackedVector2Array([Vector2(0.272, -0.05), Vector2(0.29, -0.04), Vector2(0.29, 0.04), Vector2(0.272, 0.05)]), 12, axis, Vector3(x + 0.05, 0.6, 0))
	mb.color(ItemModels.BRASS)
	for k in 8:
		var a := TAU * k / 8.0
		mb.box(Vector3(0.43, 0.6 + sin(a) * 0.2, cos(a) * 0.2), Vector3(0.03, 0.04, 0.04)) # parafusos da tampa
	_terminal_box(mb, Vector3(0.18, 0.76, 0))
	# Eixo e polia de latão (gira).
	var spin := MeshBuilder.new()
	spin.color(ItemModels.STEEL)
	spin.tube(PackedVector3Array([Vector3(0.0, 0, 0), Vector3(-0.5, 0, 0)]), 0.035, 8)
	spin.color(ItemModels.BRASS)
	spin.lathe(PackedVector2Array([Vector2(0.03, -0.04), Vector2(0.14, -0.04), Vector2(0.16, -0.02), Vector2(0.16, 0.02), Vector2(0.14, 0.04), Vector2(0.03, 0.04)]), 12, axis, Vector3(-0.5, 0, 0))
	for k in 4:
		var a := TAU * k / 4.0
		spin.box(Vector3(-0.47, sin(a) * 0.08, cos(a) * 0.08), Vector3(0.02, 0.05, 0.02))
	var node := MeshInstance3D.new()
	node.name = "Spin"
	node.mesh = spin.finish(PlacedObject._mat(), false)
	node.position = Vector3(-0.2, 0.6, 0)
	obj.add_child(node)
	var spinner := PowerSpin.new()
	spinner.axis = Vector3.RIGHT
	obj.add_child(spinner)
	obj._shape(Vector3(0.05, 0.45, 0), Vector3(1.0, 0.9, 0.6))


static func _solar(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Poste com moldura de cobre inclinada para o sol e as células azul-escuras.
	mb.color(ItemModels.IRON)
	mb.box(Vector3(0, 0.04, 0), Vector3(0.4, 0.08, 0.4))
	mb.tube(PackedVector3Array([Vector3(0, 0.06, 0), Vector3(0, 0.9, 0)]), 0.035, 6)
	var tilt := Basis(Vector3.RIGHT, -0.55)
	var center := Vector3(0, 1.0, 0)
	mb.color(ItemModels.COPPER)
	mb.box(center, Vector3(1.3, 0.04, 0.9), tilt)
	for i in 4:
		for j in 3:
			mb.color(CELL.lightened(0.04 * ((i + j) % 2)))
			mb.box(center + tilt * Vector3(-0.48 + i * 0.32, 0.025, -0.28 + j * 0.28), Vector3(0.29, 0.012, 0.25), tilt)
	mb.color(ItemModels.BRASS)
	mb.box(center + tilt * Vector3(0, -0.04, 0), Vector3(0.12, 0.05, 0.12), tilt) # articulação
	_terminal_box(mb, Vector3(0, 0.52, -0.06))
	obj._shape(Vector3(0, 0.6, 0), Vector3(1.3, 1.2, 0.9))


static func _battery(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Engradado de madeira com 6 jarros de vidro (placas de cobre e zinco), mostrador em cima.
	mb.color(WOOD)
	mb.box(Vector3(0, 0.04, 0), Vector3(0.9, 0.08, 0.55))
	for x in [-0.43, 0.43]:
		mb.box(Vector3(x, 0.28, 0), Vector3(0.04, 0.48, 0.55))
	mb.color(WOOD_DARK)
	mb.box(Vector3(0, 0.5, 0.25), Vector3(0.9, 0.04, 0.04))
	mb.box(Vector3(0, 0.5, -0.25), Vector3(0.9, 0.04, 0.04))
	var level := MeshBuilder.new()
	for i in 3:
		for j in 2:
			var c := Vector3(-0.27 + i * 0.27, 0.08, -0.12 + j * 0.24)
			mb.color(GLASS)
			mb.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.1, 0.36), Vector2(0.085, 0.38)]), 10, Basis.IDENTITY, c)
			mb.color(ItemModels.COPPER)
			mb.box(c + Vector3(-0.03, 0.26, 0), Vector3(0.012, 0.3, 0.12))
			mb.color(ItemModels.STEEL)
			mb.box(c + Vector3(0.03, 0.26, 0), Vector3(0.012, 0.3, 0.12))
			level.color(Color(0.3, 0.62, 0.58))
			level.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.092, 0.0), Vector2(0.092, 1.0), Vector2(0.0, 1.0)]), 10, Basis.IDENTITY, Vector3(c.x, 0.0, c.z))
	# Fios de latão ligando os jarros e o mostrador.
	mb.color(ItemModels.BRASS)
	mb.tube(PackedVector3Array([Vector3(-0.3, 0.46, -0.12), Vector3(0.0, 0.5, 0.12), Vector3(0.3, 0.46, -0.12)]), 0.008, 4)
	mb.color(WOOD_DARK)
	mb.box(Vector3(0.36, 0.62, 0), Vector3(0.12, 0.2, 0.2))
	mb.color(PORCELAIN)
	mb.box(Vector3(0.36, 0.64, 0.101), Vector3(0.09, 0.09, 0.004))
	var lvl := MeshInstance3D.new()
	lvl.name = "Level"
	lvl.mesh = level.finish(PlacedObject._mat(), false)
	lvl.position = Vector3(0, 0.09, 0)
	lvl.scale = Vector3(1, 0.01, 1)
	obj.add_child(lvl)
	var needle := MeshBuilder.new()
	needle.color(Color(0.7, 0.1, 0.08))
	needle.box(Vector3(0, 0.03, 0), Vector3(0.006, 0.06, 0.004))
	var nd := MeshInstance3D.new()
	nd.name = "Needle"
	nd.mesh = needle.finish(PlacedObject._mat(), false)
	nd.position = Vector3(0.36, 0.61, 0.105)
	obj.add_child(nd)
	_terminal_box(mb, Vector3(0.36, 0.72, -0.05))
	obj._shape(Vector3(0, 0.36, 0), Vector3(0.9, 0.72, 0.55))


static func _fence(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Dois postes com isoladores e 4 fios esticados (2,4 m); faísca quando dá choque.
	for x in [-1.2, 1.2]:
		mb.color(WOOD_DARK)
		mb.box(Vector3(x, 0.65, 0), Vector3(0.1, 1.3, 0.1))
		mb.box(Vector3(x, 0.03, 0), Vector3(0.22, 0.06, 0.22))
		for y in [0.3, 0.6, 0.9, 1.2]:
			mb.color(PORCELAIN)
			mb.box(Vector3(x, y, 0.065), Vector3(0.04, 0.05, 0.03))
	mb.color(Color(0.6, 0.58, 0.55))
	for y in [0.3, 0.6, 0.9, 1.2]:
		mb.tube(PackedVector3Array([Vector3(-1.2, y, 0.07), Vector3(0, y - 0.03, 0.07), Vector3(1.2, y, 0.07)]), 0.006, 4)
	mb.color(Color(0.85, 0.7, 0.1))
	mb.box(Vector3(0, 0.75, 0.08), Vector3(0.16, 0.12, 0.008)) # placa de perigo
	mb.color(Color(0.1, 0.1, 0.1))
	mb.box(Vector3(0, 0.75, 0.085), Vector3(0.03, 0.08, 0.004), Basis(Vector3.BACK, 0.4))
	_insulator(mb, Vector3(-1.2, 1.3, 0))
	obj._shape(Vector3(0, 0.65, 0), Vector3(2.5, 1.3, 0.16))
	var zap := ElectricFence.new()
	zap.name = "Zap"
	obj.add_child(zap)


static func _fridge(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Geladeira de madeira (como as antigas "geladeiras de gelo"), com dobradiças de latão
	# e a serpentina do compressor em cima.
	mb.color(WOOD)
	mb.box(Vector3(0, 0.82, 0), Vector3(0.8, 1.5, 0.66))
	mb.color(WOOD.lightened(0.06))
	mb.box(Vector3(0, 1.12, 0.34), Vector3(0.7, 0.75, 0.03))
	mb.box(Vector3(0, 0.42, 0.34), Vector3(0.7, 0.55, 0.03))
	mb.color(ItemModels.BRASS)
	for y in [0.42, 1.12]:
		mb.box(Vector3(0.28, y, 0.37), Vector3(0.05, 0.14, 0.03)) # trinco
		for dy in [-0.22, 0.22]:
			mb.box(Vector3(-0.34, y + dy * (0.75 if y > 1.0 else 0.6), 0.36), Vector3(0.04, 0.08, 0.03)) # dobradiças
	mb.color(WOOD_DARK)
	for x in [-0.35, 0.35]:
		for z in [-0.28, 0.28]:
			mb.box(Vector3(x, 0.04, z), Vector3(0.08, 0.08, 0.08))
	mb.color(ItemModels.COPPER)
	var coil := PackedVector3Array()
	for k in 25:
		var a := k / 24.0 * TAU * 3.0
		coil.append(Vector3(cos(a) * 0.12, 1.62 + k * 0.004, sin(a) * 0.12 - 0.12))
	mb.tube(coil, 0.012, 4)
	mb.color(ItemModels.IRON)
	mb.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.08, 0.0), Vector2(0.08, 0.12), Vector2(0.0, 0.14)]), 10, Basis.IDENTITY, Vector3(0.2, 1.57, -0.12))
	_terminal_box(mb, Vector3(0, 1.62, -0.22))
	# Luzinha verde: ligada e com energia.
	var lamp := MeshBuilder.new()
	lamp.color(Color(0.3, 0.9, 0.4))
	lamp.box(Vector3.ZERO, Vector3(0.04, 0.04, 0.02))
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	glow.mesh = lamp.finish(null, false)
	glow.position = Vector3(0, 1.52, 0.35)
	obj.add_child(glow)
	obj._shape(Vector3(0, 0.82, 0), Vector3(0.8, 1.64, 0.7))


static func _radio(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Rádio de válvula: mesinha, gabinete de madeira com alto-falante, mostrador e antena.
	mb.color(WOOD_DARK)
	mb.box(Vector3(0, 0.25, 0), Vector3(0.7, 0.04, 0.45))
	for x in [-0.3, 0.3]:
		for z in [-0.18, 0.18]:
			mb.box(Vector3(x, 0.12, z), Vector3(0.04, 0.24, 0.04))
	mb.color(WOOD)
	mb.box(Vector3(0, 0.47, 0), Vector3(0.6, 0.4, 0.32))
	mb.color(WOOD.darkened(0.3))
	mb.box(Vector3(-0.12, 0.47, 0.162), Vector3(0.26, 0.28, 0.006)) # pano do alto-falante
	mb.color(WOOD.lightened(0.08))
	for k in 5:
		mb.box(Vector3(-0.12, 0.36 + k * 0.055, 0.166), Vector3(0.26, 0.012, 0.004)) # grade
	mb.color(ItemModels.BRASS)
	for k in 2:
		mb.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.03, 0.03), Vector2(0.0, 0.035)]), 8, Basis(Vector3.RIGHT, PI / 2), Vector3(0.12 + k * 0.1, 0.36, 0.16)) # botões
	mb.color(ItemModels.IRON)
	mb.tube(PackedVector3Array([Vector3(0.22, 0.67, -0.08), Vector3(0.3, 1.1, -0.12), Vector3(0.36, 1.45, -0.15)]), 0.006, 4) # antena
	_terminal_box(mb, Vector3(0.28, 0.54, -0.18))
	var dial := MeshBuilder.new()
	dial.color(Color(1.0, 0.75, 0.4))
	dial.box(Vector3.ZERO, Vector3(0.16, 0.08, 0.006))
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	glow.mesh = dial.finish(null, false)
	glow.position = Vector3(0.17, 0.53, 0.163)
	obj.add_child(glow)
	var needle := MeshBuilder.new()
	needle.color(Color(0.15, 0.1, 0.05))
	needle.box(Vector3(0, 0, 0), Vector3(0.006, 0.07, 0.004))
	var nd := MeshInstance3D.new()
	nd.name = "Needle"
	nd.mesh = needle.finish(PlacedObject._mat(), false)
	nd.position = Vector3(0.17, 0.53, 0.168)
	obj.add_child(nd)
	obj._shape(Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.45))


static func _pump(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Bomba de poço: tubo descendo no chão, corpo de ferro, motor elétrico em cima,
	# saída de latão para o cano (+X).
	mb.color(ItemModels.IRON)
	mb.box(Vector3(0, 0.05, 0), Vector3(0.6, 0.1, 0.6))
	mb.lathe(PackedVector2Array([Vector2(0.0, 0.1), Vector2(0.16, 0.1), Vector2(0.18, 0.15), Vector2(0.18, 0.45), Vector2(0.14, 0.5), Vector2(0.0, 0.5)]), 12)
	mb.color(ItemModels.IRON.lightened(0.15))
	mb.lathe(PackedVector2Array([Vector2(0.0, 0.5), Vector2(0.15, 0.5), Vector2(0.15, 0.82), Vector2(0.12, 0.86), Vector2(0.0, 0.86)]), 12)
	mb.color(ItemModels.COPPER)
	for y in [0.58, 0.66, 0.74]:
		mb.lathe(PackedVector2Array([Vector2(0.15, y), Vector2(0.165, y + 0.01), Vector2(0.165, y + 0.03), Vector2(0.15, y + 0.04)]), 12)
	mb.color(ItemModels.BRASS)
	mb.tube(PackedVector3Array([Vector3(0.15, 0.25, 0), Vector3(0.42, 0.25, 0)]), 0.045, 8)
	_terminal_box(mb, Vector3(0, 0.86, 0))
	obj._shape(Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.6))


# --- Estado visual -----------------------------------------------------------------

## Acende/apaga conforme a energia (chamado pelo refresh do objeto).
static func refresh(obj: PlacedObject) -> void:
	var on := Electric.powered(obj)
	var glow := obj.get_node_or_null("Glow") as MeshInstance3D
	if glow:
		var lit: Material = Look.glow_material()
		if obj.kind in ["lamp", "lamp_wall"]:
			if _warm == null:
				_warm = Look.glow_material().duplicate()
				_warm.set_shader_parameter("tint", Color(1.0, 0.78, 0.48))
				_warm.set_shader_parameter("boost", 2.6)
			lit = _warm
		glow.material_override = lit if on else PlacedObject._mat()
	var light := obj.get_node_or_null("Light") as OmniLight3D
	if light:
		light.visible = on
	if obj.kind == "battery":
		var level := obj.get_node_or_null("Level") as Node3D
		var fill := clampf(obj.extra.get("charge", 0.0) / Electric.BATTERY_CAP, 0.0, 1.0)
		if level:
			level.scale.y = maxf(0.01, fill * 0.3)
		var needle := obj.get_node_or_null("Needle") as Node3D
		if needle:
			needle.rotation.z = lerpf(1.1, -1.1, fill)
	if obj.kind == "radio":
		var needle := obj.get_node_or_null("Needle") as Node3D
		if needle:
			needle.position.x = 0.11 + fposmod(obj.extra.get("msg_t", 0.0) * 7.3, 1.0) * 0.12
