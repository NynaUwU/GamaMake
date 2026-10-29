class_name ItemModels
## Modelos dos itens em malha poligonal estilo PS2 (MeshBuilder), no estilo
## MEDIEVAL STEAMPUNK: aço, ferro, latão, cobre, couro e madeira, com
## engrenagens, canos, rebites e manômetros.
##
## Uma única fonte para: arma na mão do player, item no chão, arma na mão dos
## zumbis e ícones (ItemIcons fotografa estes modelos).
##
## Convenção: o item aponta para -Z a partir da mão (origem = onde se segura).
## Pistola: cano para -Z, cabo para baixo, boca do cano em z = -0.17.
## Perfis de lathe com AXIS_Z: altura h vira z = -h (h positivo = para frente),
## sempre em ordem CRESCENTE de altura (senão as faces ficam viradas para dentro).

const STEEL := Color(0.72, 0.74, 0.77)
const IRON := Color(0.3, 0.3, 0.32)
const BRASS := Color(0.78, 0.6, 0.26)
const COPPER := Color(0.72, 0.4, 0.22)
const LEATHER := Color(0.32, 0.18, 0.1)
const WOOD := Color(0.42, 0.26, 0.14)
const DARK_WOOD := Color(0.26, 0.15, 0.08)
const GLOW := Color(0.75, 0.45, 1.0)
const LENS := Color(1.0, 0.92, 0.65)
const CLOTH := Color(0.62, 0.58, 0.5)
const TAPE := Color(0.6, 0.6, 0.62)

## Eixo de peças torneadas ao longo de -Z (lathe/torus giram em volta do Y local).
const AXIS_Z := Basis(Vector3(1, 0, 0), -PI / 2)
## Engrenagem/disco virado para o lado (eixo X).
const AXIS_X := Basis(Vector3(0, 1, 0), PI / 2)

static var _materials := {}


static func build(id: StringName) -> Node3D:
	var parts := {} # cor -> MeshBuilder
	match id:
		&"espada":
			_sword(parts)
		&"taco":
			_mace(parts)
		&"cajado":
			_staff(parts)
		&"pistola":
			_pistol(parts)
		&"lanterna":
			_lantern(parts)
		&"sucata":
			_scrap(parts)
		&"pano":
			_cloth(parts)
		&"fita":
			_tape(parts)
		_:
			_mb(parts, IRON).box(Vector3.ZERO, Vector3.ONE * 0.2)
	var root := Node3D.new()
	root.name = "Model"
	for color in parts:
		var mesh := MeshInstance3D.new()
		mesh.mesh = parts[color].finish(_material(color))
		root.add_child(mesh)
	return root


# --- Armas -------------------------------------------------------------------

## Espada longa: lâmina de aço em losango, guarda de latão curvada com
## engrenagem no centro, cabo de couro com fio de latão e pomo de engrenagem.
static func _sword(p: Dictionary) -> void:
	var blade := []
	for s in [[-0.04, 0.032, 0.007], [-0.3, 0.03, 0.0065], [-0.65, 0.026, 0.006], [-0.86, 0.018, 0.005], [-0.97, 0.002, 0.002]]:
		blade.append(MeshBuilder.ring(Vector3(0, 0, s[0]), s[1], s[2], 1.0, 4))
	blade.reverse()
	_mb(p, STEEL).loft(blade, true, true)
	# Cano de cobre correndo pela base da lâmina (o "vapor" da espada).
	_mb(p, COPPER).tube(PackedVector3Array([Vector3(0, 0.009, -0.05), Vector3(0, 0.009, -0.24), Vector3(0, 0.006, -0.27)]), 0.0045, 6)
	# Guarda: barra curvada para a lâmina com esferas nas pontas + engrenagem central.
	var guard := PackedVector3Array()
	for i in 9:
		var x := lerpf(-0.12, 0.12, i / 8.0)
		guard.append(Vector3(x, 0, -0.03 - x * x * 2.2))
	_mb(p, BRASS).tube(guard, 0.011, 6)
	for side in [-1.0, 1.0]:
		_ball(_mb(p, BRASS), Vector3(side * 0.12, 0, -0.03 - 0.0317), 0.017)
	_gear(_mb(p, BRASS), Vector3(0, 0, -0.03), 0.034, 0.022, 10, AXIS_X)
	_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.01, -0.012), Vector2(0.014, 0.0), Vector2(0.01, 0.012)]), 6, AXIS_X, Vector3(0, 0, -0.03))
	# Cabo de couro com voltas de fio de latão.
	_mb(p, LEATHER).lathe(PackedVector2Array([Vector2(0.02, -0.13), Vector2(0.022, -0.06), Vector2(0.019, 0.0)]), 8, AXIS_Z)
	for z in [0.025, 0.06, 0.095]:
		_mb(p, BRASS).torus(0.0215, 0.0028, 10, 4, AXIS_Z, Vector3(0, 0, z))
	# Pomo: engrenagem com miolo de ferro.
	_gear(_mb(p, BRASS), Vector3(0, 0, 0.16), 0.036, 0.024, 8, AXIS_X)
	_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.012, -0.014), Vector2(0.015, 0.0), Vector2(0.012, 0.014)]), 6, AXIS_X, Vector3(0, 0, 0.16))


## Maça a vapor: cabo de madeira escura, cabeça de ferro com 6 flanges,
## cintas de latão e uma serpentina de cobre subindo pelo cabo.
static func _mace(p: Dictionary) -> void:
	_mb(p, DARK_WOOD).lathe(PackedVector2Array([Vector2(0.022, -0.08), Vector2(0.024, 0.2), Vector2(0.028, 0.62)]), 8, AXIS_Z)
	_mb(p, LEATHER).lathe(PackedVector2Array([Vector2(0.027, -0.08), Vector2(0.029, 0.02), Vector2(0.027, 0.14)]), 8, AXIS_Z)
	_ball(_mb(p, BRASS), Vector3(0, 0, 0.09), 0.03)
	# Cabeça de ferro.
	_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.03, 0.6), Vector2(0.058, 0.64), Vector2(0.062, 0.76),
		Vector2(0.05, 0.84), Vector2(0.02, 0.88)]), 10, AXIS_Z)
	for i in 6:
		var a := TAU * i / 6.0
		var out := Vector3(cos(a), sin(a), 0)
		# Flange: placa radial (largura para fora, comprimento ao longo do cabo).
		var basis := Basis(out, Vector3(0, 0, 1).cross(out), Vector3(0, 0, 1))
		_mb(p, IRON).box(Vector3(0, 0, -0.74) + out * 0.07, Vector3(0.035, 0.012, 0.19), basis)
	for z in [-0.6, -0.86]:
		_mb(p, BRASS).torus(0.05, 0.006, 12, 4, AXIS_Z, Vector3(0, 0, z))
	# Serpentina de cobre.
	var coil := PackedVector3Array()
	for i in 41:
		var t := i / 40.0
		var a := t * TAU * 4.0
		coil.append(Vector3(cos(a) * 0.033, sin(a) * 0.033, lerpf(-0.22, -0.55, t)))
	_mb(p, COPPER).tube(coil, 0.0045, 5, true)


## Cajado: madeira com cintas de latão, bobina de cobre, manômetro e um orbe
## mágico preso numa gaiola de latão no topo.
static func _staff(p: Dictionary) -> void:
	_mb(p, WOOD).lathe(PackedVector2Array([Vector2(0.024, -0.05), Vector2(0.026, 0.4), Vector2(0.03, 0.94)]), 8, AXIS_Z)
	_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.012, -0.1), Vector2(0.026, -0.08), Vector2(0.026, -0.03)]), 8, AXIS_Z) # ponteira de ferro
	for z in [-0.25, -0.55, -0.8]:
		_mb(p, BRASS).torus(0.03, 0.006, 10, 4, AXIS_Z, Vector3(0, 0, z))
	var coil := PackedVector3Array()
	for i in 31:
		var t := i / 30.0
		var a := t * TAU * 5.0
		coil.append(Vector3(cos(a) * 0.036, sin(a) * 0.036, lerpf(-0.84, -0.93, t)))
	_mb(p, COPPER).tube(coil, 0.004, 5, true)
	# Manômetro na lateral.
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.024, 0.0), Vector2(0.024, 0.012), Vector2(0.002, 0.014)]), 10,
			Basis(Vector3(0, 0, 1), -PI / 2), Vector3(0.03, 0, -0.7))
	# Soquete e gaiola.
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.03, 0.93), Vector2(0.05, 0.97), Vector2(0.055, 0.99)]), 10, AXIS_Z)
	var center := Vector3(0, 0, -1.06)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4
		var arc := PackedVector3Array()
		for k in 9:
			var t := lerpf(-1.2, 1.35, k / 8.0)
			arc.append(center + Vector3(cos(a) * cos(t) * 0.07, sin(a) * cos(t) * 0.07, -sin(t) * 0.07))
		_mb(p, BRASS).tube(arc, 0.006, 5)
	_ball(_mb(p, BRASS), center + Vector3(0, 0, -0.075), 0.014)
	_ball(_mb(p, GLOW), center, 0.05, 10)


## Pistola steampunk: cano octogonal de latão, tambor com engrenagem, armação
## de ferro, cão, guarda-mato, cano de cobre e coronha curva de madeira.
static func _pistol(p: Dictionary) -> void:
	var barrel := []
	for z in [0.0, -0.15, -0.165]:
		barrel.append(MeshBuilder.ring(Vector3(0, 0.035, z), 0.014, 0.014, 2.0, 8))
	barrel.reverse()
	_mb(p, BRASS).loft(barrel, true, true)
	_mb(p, BRASS).torus(0.016, 0.004, 8, 4, AXIS_Z, Vector3(0, 0.035, -0.165))
	_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.024, -0.005), Vector2(0.026, 0.02), Vector2(0.024, 0.045)]), 8, AXIS_Z, Vector3(0, 0.03, 0.0))
	_gear(_mb(p, BRASS), Vector3(0.026, 0.03, -0.02), 0.018, 0.013, 8, AXIS_X, 0.006)
	_mb(p, IRON).box(Vector3(0, 0.012, 0.015), Vector3(0.026, 0.035, 0.07))
	_mb(p, BRASS).box(Vector3(0, 0.058, 0.05), Vector3(0.01, 0.03, 0.012), Basis(Vector3(1, 0, 0), 0.5)) # cão
	_mb(p, COPPER).tube(PackedVector3Array([Vector3(0, 0.014, 0.0), Vector3(0, 0.014, -0.12), Vector3(0, 0.022, -0.14)]), 0.005, 6)
	var guard := PackedVector3Array()
	for i in 9:
		var a := lerpf(0.0, PI, i / 8.0)
		guard.append(Vector3(0, -0.005 - sin(a) * 0.03, 0.0 + cos(a) * 0.025))
	_mb(p, BRASS).tube(guard, 0.003, 4)
	# Coronha: silhueta lateral extrudada na largura (X).
	var grip := PackedVector2Array([Vector2(-0.01, 0.0), Vector2(-0.045, 0.0), Vector2(-0.07, -0.06),
		Vector2(-0.085, -0.1), Vector2(-0.06, -0.11), Vector2(-0.035, -0.08), Vector2(-0.015, -0.03)])
	# Basis: u da silhueta -> -Z (u negativo = para trás), espessura -> X.
	_mb(p, DARK_WOOD).extrude(grip, 0.028, Basis(Vector3(0, 1, 0), PI / 2), Vector3(0, 0, 0))
	_mb(p, BRASS).box(Vector3(0, -0.105, 0.072), Vector3(0.03, 0.012, 0.03), Basis(Vector3(1, 0, 0), -0.4))


## Lanterna a manivela: corpo de latão, refletor alargado com lente acesa,
## cintas de cobre e manivela na lateral.
static func _lantern(p: Dictionary) -> void:
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.012, 0.0), Vector2(0.03, 0.005), Vector2(0.032, 0.15),
		Vector2(0.045, 0.2), Vector2(0.046, 0.22)]), 10, AXIS_Z)
	for z in [-0.04, -0.12]:
		_mb(p, COPPER).torus(0.033, 0.004, 10, 4, AXIS_Z, Vector3(0, 0, z))
	_mb(p, LENS).lathe(PackedVector2Array([Vector2(0.042, 0.215), Vector2(0.002, 0.23)]), 10, AXIS_Z)
	_mb(p, IRON).tube(PackedVector3Array([Vector3(0.032, 0, -0.08), Vector3(0.05, 0, -0.08), Vector3(0.05, 0.03, -0.08)]), 0.004, 4)
	_ball(_mb(p, WOOD), Vector3(0.05, 0.035, -0.08), 0.008, 6)


# --- Materiais de crafting -----------------------------------------------------

static func _scrap(p: Dictionary) -> void:
	_gear(_mb(p, IRON), Vector3(-0.04, 0.0, 0.0), 0.08, 0.06, 10, Basis(Vector3(1, 0, 0), PI / 2), 0.02)
	_mb(p, COPPER).tube(PackedVector3Array([Vector3(0.02, 0.01, -0.08), Vector3(0.07, 0.02, -0.02), Vector3(0.06, 0.02, 0.06), Vector3(0.12, 0.015, 0.08)]), 0.012, 6)
	_mb(p, BRASS).box(Vector3(0.05, 0.0, 0.0), Vector3(0.06, 0.02, 0.04), Basis(Vector3(0, 1, 0), 0.6))


static func _cloth(p: Dictionary) -> void:
	var grid := []
	for r in 5:
		var row := PackedVector3Array()
		for c in 6:
			var x := lerpf(-0.15, 0.15, c / 5.0)
			var z := lerpf(-0.12, 0.12, r / 4.0)
			row.append(Vector3(x, 0.02 + sin(c * 1.7 + r) * 0.012 + cos(r * 2.1) * 0.008, z))
		grid.append(row)
	_mb(p, CLOTH).sheet(grid)
	_mb(p, CLOTH).tube(PackedVector3Array([Vector3(-0.15, 0.025, -0.12), Vector3(-0.15, 0.035, 0.0), Vector3(-0.15, 0.025, 0.12)]), 0.015, 5)


static func _tape(p: Dictionary) -> void:
	var outer := PackedVector2Array([Vector2(0.065, -0.025), Vector2(0.068, 0.0), Vector2(0.065, 0.025)])
	_mb(p, TAPE).lathe(outer, 14)
	_mb(p, TAPE).torus(0.066, 0.003, 14, 3, Basis.IDENTITY, Vector3(0, 0.025, 0))
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.035, 0.026), Vector2(0.035, -0.026)]), 12)


# --- Peças --------------------------------------------------------------------

## Engrenagem: polígono com dentes extrudado (depth = espessura, ao longo do Z da base).
static func _gear(mb: MeshBuilder, center: Vector3, outer: float, inner: float, teeth: int, basis: Basis, depth := 0.01) -> void:
	var shape := PackedVector2Array()
	for i in teeth * 4:
		var a := TAU * i / (teeth * 4.0)
		var r := outer if (i % 4) in [1, 2] else inner
		shape.append(Vector2(cos(a), sin(a)) * r)
	mb.extrude(shape, depth, basis, center)


static func _ball(mb: MeshBuilder, center: Vector3, radius: float, segments := 8) -> void:
	var profile := PackedVector2Array()
	for i in 6:
		var a := lerpf(-PI / 2, PI / 2, i / 5.0)
		profile.append(Vector2(maxf(cos(a) * radius, 0.0005), sin(a) * radius))
	mb.lathe(profile, segments, Basis.IDENTITY, center)


static func _mb(parts: Dictionary, color: Color) -> MeshBuilder:
	if not parts.has(color):
		parts[color] = MeshBuilder.new()
	return parts[color]


static func _material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	match color:
		STEEL:
			material.metallic = 0.8
			material.roughness = 0.3
		BRASS, COPPER:
			material.metallic = 0.75
			material.roughness = 0.38
		IRON:
			material.metallic = 0.6
			material.roughness = 0.55
		GLOW, LENS:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 2.5
		_:
			material.roughness = 0.85
	_materials[color] = material
	return material
