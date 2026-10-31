class_name ItemModels
## Modelos dos itens em malha poligonal estilo PS2 (MeshBuilder), no estilo
## MEDIEVAL STEAMPUNK pós-apocalíptico, SIMPLES: poucas peças retas (cabo,
## guarda, cabeça, uma cinta de latão no máximo). Aço, ferro, latão, couro e
## madeira gastos — tudo fosco (quase nada reflete).
##
## Uma única fonte para: arma na mão do player, item no chão, arma na mão dos
## zumbis e ícones (ItemIcons fotografa estes modelos).
##
## Convenção: o item aponta para -Z a partir da mão (origem = onde se segura).
## Pistola: cano para -Z, cabo para baixo, boca do cano em z = -0.17.
## Perfis de lathe com AXIS_Z: altura h vira z = -h (h positivo = para frente),
## sempre em ordem CRESCENTE de altura (senão as faces ficam viradas para dentro).

# Cores gastas/oxidadas (pós-apocalíptico).
const STEEL := Color(0.58, 0.59, 0.6)
const IRON := Color(0.27, 0.26, 0.26)
const BRASS := Color(0.6, 0.48, 0.26)
const COPPER := Color(0.55, 0.34, 0.22)
const LEATHER := Color(0.32, 0.18, 0.1)
const WOOD := Color(0.42, 0.26, 0.14)
const DARK_WOOD := Color(0.26, 0.15, 0.08)
const GLOW := Color(0.75, 0.45, 1.0)
const LENS := Color(1.0, 0.92, 0.65)
const CLOTH := Color(0.62, 0.58, 0.5)
const DARK := Color(0.05, 0.05, 0.05)
const RED_PAINT := Color(0.5, 0.1, 0.07)
const CREAM := Color(0.88, 0.84, 0.72)
const WIRE := Color(0.18, 0.3, 0.6)
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
		&"colher":
			_spoon(parts)
		&"gancho":
			_grapple(parts)
		&"martelo":
			_hammer(parts)
		&"talhadeira":
			_chisel(parts)
		&"chinelo":
			_slipper(parts)
		&"bumerangue":
			_boomerang(parts)
		&"pistola":
			_pistol(parts)
		&"lanterna":
			_lantern(parts)
		&"carregador":
			return build_charger()
		&"fruta":
			_ball(_mb(parts, Color(0.68, 0.12, 0.08)), Vector3.ZERO, 0.07, 8)
			_mb(parts, DARK_WOOD).tube(PackedVector3Array([Vector3(0, 0.06, 0), Vector3(0.01, 0.1, 0)]), 0.008, 4)
			_mb(parts, Color(0.25, 0.45, 0.18)).box(Vector3(0.025, 0.09, 0), Vector3(0.05, 0.008, 0.025))
		&"sucata":
			_scrap(parts)
		&"pa":
			_shovel(parts)
		&"machado":
			_axe(parts)
		&"picareta":
			_pickaxe(parts)
		&"tronco":
			_mb(parts, Color(0.36, 0.24, 0.14)).lathe(PackedVector2Array([Vector2(0.002, -0.55), Vector2(0.14, -0.55), Vector2(0.15, 0.55), Vector2(0.002, 0.55)]), 7, AXIS_Z)
			_mb(parts, Color(0.62, 0.48, 0.3)).lathe(PackedVector2Array([Vector2(0.002, 0.553), Vector2(0.13, 0.553)]), 7, AXIS_Z) # anéis do corte
			_mb(parts, Color(0.62, 0.48, 0.3)).lathe(PackedVector2Array([Vector2(0.12, -0.553), Vector2(0.002, -0.553)]), 7, AXIS_Z)
		&"minerio_ferro":
			_rock(_mb(parts, Color(0.48, 0.32, 0.26)))
			_mb(parts, Color(0.62, 0.36, 0.2)).box(Vector3(0.03, 0.04, 0.02), Vector3(0.05, 0.03, 0.04))
		&"minerio_cobre":
			_rock(_mb(parts, Color(0.42, 0.4, 0.37)))
			_mb(parts, Color(0.25, 0.6, 0.5)).box(Vector3(0.03, 0.04, 0.02), Vector3(0.05, 0.03, 0.04))
			_mb(parts, COPPER).box(Vector3(-0.03, 0.03, -0.02), Vector3(0.04, 0.03, 0.03))
		&"carvao":
			_rock(_mb(parts, Color(0.09, 0.08, 0.08)))
		&"barra_ferro":
			_mb(parts, IRON.lightened(0.15)).lathe(PackedVector2Array([Vector2(0.002, -0.14), Vector2(0.045, -0.14), Vector2(0.04, 0.14), Vector2(0.002, 0.14)]), 4, AXIS_Z)
		&"barra_cobre":
			_mb(parts, COPPER.lightened(0.1)).lathe(PackedVector2Array([Vector2(0.002, -0.14), Vector2(0.045, -0.14), Vector2(0.04, 0.14), Vector2(0.002, 0.14)]), 4, AXIS_Z)
		&"vidro":
			_mb(parts, Color(0.62, 0.78, 0.8)).box(Vector3.ZERO, Vector3(0.24, 0.015, 0.24))
		&"batata_assada":
			_ball(_mb(parts, Color(0.5, 0.32, 0.15)), Vector3.ZERO, 0.055, 6)
			_mb(parts, Color(0.95, 0.85, 0.5)).box(Vector3(0, 0.045, 0), Vector3(0.04, 0.02, 0.06))
		&"cenoura_assada":
			_mb(parts, Color(0.62, 0.28, 0.08)).lathe(PackedVector2Array([Vector2(0.002, -0.1), Vector2(0.02, -0.04), Vector2(0.025, 0.06), Vector2(0.002, 0.075)]), 6, AXIS_Z)
		&"abobora_assada":
			_ball(_mb(parts, Color(0.66, 0.3, 0.08)), Vector3.ZERO, 0.12, 8)
			_mb(parts, Color(0.95, 0.62, 0.2)).box(Vector3(0, 0.09, 0), Vector3(0.12, 0.03, 0.12))
		&"lata_quente":
			_mb(parts, Color(0.35, 0.33, 0.3)).lathe(PackedVector2Array([Vector2(0.002, -0.065), Vector2(0.048, -0.065), Vector2(0.05, 0.06), Vector2(0.002, 0.065)]), 10)
			_mb(parts, Color(0.55, 0.2, 0.12)).lathe(PackedVector2Array([Vector2(0.051, -0.035), Vector2(0.051, 0.035)]), 10)
		&"torrada":
			_mb(parts, Color(0.45, 0.27, 0.1)).box(Vector3.ZERO, Vector3(0.18, 0.04, 0.11))
		&"lata":
			_mb(parts, Color(0.52, 0.5, 0.46)).lathe(PackedVector2Array([Vector2(0.002, -0.065), Vector2(0.048, -0.065), Vector2(0.05, -0.06), Vector2(0.05, 0.06), Vector2(0.048, 0.065), Vector2(0.002, 0.065)]), 10)
			_mb(parts, Color(0.55, 0.2, 0.12)).lathe(PackedVector2Array([Vector2(0.051, -0.035), Vector2(0.051, 0.035)]), 10)
		&"pao":
			_mb(parts, Color(0.62, 0.42, 0.2)).lathe(PackedVector2Array([Vector2(0.002, -0.11), Vector2(0.035, -0.1), Vector2(0.05, -0.05), Vector2(0.052, 0.05), Vector2(0.035, 0.1), Vector2(0.002, 0.11)]), 7, AXIS_X)
		&"cenoura":
			_mb(parts, Color(0.85, 0.42, 0.1)).lathe(PackedVector2Array([Vector2(0.002, -0.1), Vector2(0.02, -0.04), Vector2(0.025, 0.06), Vector2(0.002, 0.075)]), 6, AXIS_Z)
			_mb(parts, Color(0.25, 0.5, 0.18)).box(Vector3(0, 0, -0.12), Vector3(0.03, 0.01, 0.07))
		&"batata":
			_ball(_mb(parts, Color(0.6, 0.46, 0.28)), Vector3.ZERO, 0.055, 6)
		&"abobora":
			_ball(_mb(parts, Color(0.86, 0.45, 0.1)), Vector3(0, 0.0, 0), 0.13, 10)
			_mb(parts, Color(0.3, 0.42, 0.15)).box(Vector3(0, 0.13, 0), Vector3(0.025, 0.06, 0.025))
		&"bandagem":
			_mb(parts, CREAM).lathe(PackedVector2Array([Vector2(0.02, -0.03), Vector2(0.055, -0.03), Vector2(0.055, 0.03), Vector2(0.02, 0.03)]), 10)
		&"semente_cenoura", &"semente_batata", &"semente_abobora":
			_seed_pouch(parts, {&"semente_cenoura": Color(0.85, 0.42, 0.1), &"semente_batata": Color(0.6, 0.46, 0.28)}.get(id, Color(0.86, 0.6, 0.15)))
		&"tabua":
			_mb(parts, WOOD).box(Vector3.ZERO, Vector3(0.12, 0.025, 0.6))
			_mb(parts, IRON).box(Vector3(0, 0.014, 0.22), Vector3(0.012, 0.006, 0.012))
		&"pedra":
			_rock(_mb(parts, Color(0.5, 0.49, 0.46)))
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

## Espada longa: lâmina de aço em losango, guarda reta de latão, cabo reto de
## couro e pomo curto de ferro (simples de propósito).
static func _sword(p: Dictionary) -> void:
	var blade := []
	for s in [[-0.04, 0.032, 0.007], [-0.3, 0.03, 0.0065], [-0.65, 0.026, 0.006], [-0.86, 0.018, 0.005], [-0.97, 0.002, 0.002]]:
		blade.append(MeshBuilder.ring(Vector3(0, 0, s[0]), s[1], s[2], 1.0, 4))
	blade.reverse()
	_mb(p, STEEL).loft(blade, true, true)
	# Guarda: barra reta e simples.
	_mb(p, BRASS).box(Vector3(0, 0, -0.03), Vector3(0.2, 0.035, 0.035))
	# Cabo: cilindro reto de couro, sem enfeites (como o primeiro modelo).
	_mb(p, LEATHER).lathe(PackedVector2Array([Vector2(0.024, -0.15), Vector2(0.024, -0.01)]), 8, AXIS_Z)
	# Pomo: tampa curta de ferro.
	_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.002, -0.185), Vector2(0.03, -0.17), Vector2(0.03, -0.15)]), 8, AXIS_Z)


## Maça: cabo reto de madeira, empunhadura de couro, cabeça de ferro
## octogonal com 4 flanges e uma cinta de latão.
static func _mace(p: Dictionary) -> void:
	_mb(p, DARK_WOOD).lathe(PackedVector2Array([Vector2(0.024, -0.08), Vector2(0.026, 0.62)]), 8, AXIS_Z)
	_mb(p, LEATHER).lathe(PackedVector2Array([Vector2(0.029, -0.06), Vector2(0.029, 0.12)]), 8, AXIS_Z)
	_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.002, -0.1), Vector2(0.032, -0.09), Vector2(0.032, -0.07)]), 8, AXIS_Z)
	_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.05, 0.6), Vector2(0.06, 0.65), Vector2(0.06, 0.82), Vector2(0.002, 0.87)]), 8, AXIS_Z)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4
		var out := Vector3(cos(a), sin(a), 0)
		_mb(p, IRON).box(Vector3(0, 0, -0.73) + out * 0.075, Vector3(0.03, 0.03, 0.18), Basis(out, Vector3(0, 0, 1).cross(out), Vector3(0, 0, 1)))
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.034, 0.56), Vector2(0.034, 0.6)]), 8, AXIS_Z)


## Chinelo de borracha: sola achatada (mais larga na frente) e a tira em "Y".
static func _slipper(p: Dictionary) -> void:
	var sole := PackedVector2Array()
	for k in 12:
		var a := TAU * k / 12.0
		var width := 0.045 if sin(a) < 0.0 else 0.055 # calcanhar mais estreito
		sole.append(Vector2(cos(a) * width, -0.12 + sin(a) * 0.13))
	_mb(p, Color(0.2, 0.45, 0.7)).extrude(sole, 0.018, Basis(Vector3.RIGHT, PI / 2), Vector3(0, -0.009, 0))
	_mb(p, Color(0.88, 0.88, 0.85)).extrude(sole, 0.006, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.012, 0)) # palmilha
	var strap := Color(0.9, 0.92, 0.95)
	var toe := Vector3(0, 0.014, -0.2)
	for side in [-1.0, 1.0]:
		_mb(p, strap).tube(PackedVector3Array([toe, Vector3(side * 0.025, 0.04, -0.13), Vector3(side * 0.048, 0.016, -0.08)]), 0.007, 4)


## Bumerangue: duas pás chatas de madeira em "V" com faixas pintadas.
static func _boomerang(p: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		var arm := Basis(Vector3.UP, side * 0.95)
		var center := arm * Vector3(0, 0, -0.14)
		_mb(p, WOOD).box(center, Vector3(0.065, 0.014, 0.3), arm)
		_mb(p, RED_PAINT).box(center + arm * Vector3(0, 0.008, -0.06), Vector3(0.067, 0.004, 0.03), arm)
		_mb(p, CREAM).box(center + arm * Vector3(0, 0.008, 0.04), Vector3(0.067, 0.004, 0.025), arm)


## Martelo de construção: cabo reto de madeira, cabeça de ferro (face redonda
## de um lado, unha de tirar prego do outro) e uma cinta de latão.
static func _hammer(p: Dictionary) -> void:
	_mb(p, WOOD).lathe(PackedVector2Array([Vector2(0.018, -0.06), Vector2(0.02, 0.34)]), 8, AXIS_Z)
	_mb(p, LEATHER).lathe(PackedVector2Array([Vector2(0.023, -0.05), Vector2(0.023, 0.08)]), 8, AXIS_Z)
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.024, 0.3), Vector2(0.024, 0.33)]), 8, AXIS_Z)
	_mb(p, IRON).box(Vector3(0, 0, -0.36), Vector3(0.05, 0.16, 0.06)) # bloco da cabeça
	_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.03, 0.0), Vector2(0.03, 0.05), Vector2(0.026, 0.06)]), 8,
			Basis.IDENTITY, Vector3(0, 0.08, -0.36)) # face de bater (para cima)
	_mb(p, IRON).box(Vector3(0, -0.12, -0.35), Vector3(0.035, 0.09, 0.03), Basis(Vector3.RIGHT, 0.35)) # unha


## Talhadeira: cabo de madeira curto, virola de latão e haste de aço chata
## afinando até o fio.
static func _chisel(p: Dictionary) -> void:
	_mb(p, DARK_WOOD).lathe(PackedVector2Array([Vector2(0.018, -0.05), Vector2(0.022, 0.0), Vector2(0.022, 0.1)]), 8, AXIS_Z)
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.024, 0.1), Vector2(0.024, 0.125)]), 8, AXIS_Z)
	var blade := []
	for s in [[-0.125, 0.012, 0.009], [-0.22, 0.014, 0.006], [-0.29, 0.017, 0.0015]]:
		blade.append(MeshBuilder.ring(Vector3(0, 0, s[0]), s[1], s[2], 4.0, 4))
	blade.reverse()
	_mb(p, STEEL).loft(blade, true, true)


## Lançador do gancho: tubo de latão com carretel de corda, cabo de madeira
## e o gancho de ferro de 3 garras na boca. Simples, como as outras armas.
static func _grapple(p: Dictionary) -> void:
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.002, -0.06), Vector2(0.026, -0.06), Vector2(0.026, 0.2), Vector2(0.002, 0.2)]), 8, AXIS_Z, Vector3(0, 0.035, 0))
	_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.002, -0.02), Vector2(0.045, -0.02), Vector2(0.045, 0.02), Vector2(0.002, 0.02)]), 10,
			Basis(Vector3(0, 0, 1), PI / 2), Vector3(0, 0.03, 0.03)) # carretel
	_mb(p, CLOTH.darkened(0.45)).lathe(PackedVector2Array([Vector2(0.002, -0.018), Vector2(0.038, -0.018), Vector2(0.038, 0.018), Vector2(0.002, 0.018)]), 10,
			Basis(Vector3(0, 0, 1), PI / 2), Vector3(0, 0.03, 0.03)) # corda enrolada
	var grip := PackedVector2Array([Vector2(-0.01, 0.0), Vector2(-0.045, 0.0), Vector2(-0.065, -0.07), Vector2(-0.045, -0.1), Vector2(-0.015, -0.04)])
	_mb(p, DARK_WOOD).extrude(grip, 0.028, Basis(Vector3(0, 1, 0), PI / 2), Vector3(0, 0, 0.04))
	# Gancho: haste + 3 garras curvas.
	var tip := Vector3(0, 0.035, -0.2)
	_mb(p, IRON).tube(PackedVector3Array([tip, tip + Vector3(0, 0, -0.07)]), 0.01, 6)
	for i in 3:
		var a := TAU * i / 3.0
		var out := Vector3(cos(a), sin(a), 0)
		_mb(p, IRON).tube(PackedVector3Array([tip + Vector3(0, 0, -0.06), tip + out * 0.045 + Vector3(0, 0, -0.04), tip + out * 0.06 + Vector3(0, 0, 0.0)]), 0.007, 4)


## Colherona: colher de sopa ridiculamente grande. Cabo achatado de ferro com
## ponta de couro e uma concha funda (bem simples, como as outras armas).
static func _spoon(p: Dictionary) -> void:
	# Cabo: seção achatada que alarga perto da concha.
	var handle := []
	for s in [[0.06, 0.022, 0.008], [-0.4, 0.026, 0.009], [-0.85, 0.034, 0.01], [-1.02, 0.05, 0.012]]:
		handle.append(MeshBuilder.ring(Vector3(0, 0, s[0]), s[1], s[2], 2.5, 8))
	handle.reverse()
	_mb(p, STEEL).loft(handle, true, true)
	_mb(p, LEATHER).lathe(PackedVector2Array([Vector2(0.03, -0.08), Vector2(0.03, 0.14)]), 6, AXIS_Z)
	# Concha: casca oval funda (por fora e por dentro), aberta para cima.
	var center := Vector3(0, 0.03, -1.27)
	var outer := []
	var inner := []
	for i in 9:
		var t := lerpf(-1.0, 1.0, i / 8.0)
		var half_w := 0.17 * sqrt(maxf(1.0 - t * t, 0.0)) + 0.002
		var depth := 0.09 * sqrt(maxf(1.0 - t * t, 0.0)) + 0.002
		var z := center.z + t * 0.25
		outer.append(MeshBuilder.ring(Vector3(0, center.y, z), half_w, depth, 2.0, 12, -INF, PI, TAU))
		inner.append(MeshBuilder.ring(Vector3(0, center.y + 0.004, z), half_w * 0.94, depth * 0.9, 2.0, 12, -INF, PI, TAU))
	outer.reverse()
	inner.reverse()
	_mb(p, STEEL).loft(outer, false)
	_mb(p, STEEL).loft(inner, false, false, true)


## Cajado: cabo reto de madeira, ponteira de ferro, uma cinta de latão e o
## orbe preso por 3 garras retas de latão.
static func _staff(p: Dictionary) -> void:
	_mb(p, WOOD).lathe(PackedVector2Array([Vector2(0.026, -0.05), Vector2(0.028, 0.95)]), 8, AXIS_Z)
	_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.002, -0.1), Vector2(0.028, -0.08), Vector2(0.028, -0.05)]), 8, AXIS_Z)
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.031, 0.5), Vector2(0.031, 0.54)]), 8, AXIS_Z)
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.03, 0.93), Vector2(0.045, 0.98), Vector2(0.045, 1.0)]), 8, AXIS_Z)
	var center := Vector3(0, 0, -1.06)
	for i in 3:
		var a := TAU * i / 3.0
		var out := Vector3(cos(a), sin(a), 0)
		_mb(p, BRASS).tube(PackedVector3Array([Vector3(0, 0, -0.99) + out * 0.035, center + out * 0.055 + Vector3(0, 0, -0.03)]), 0.007, 4)
	_ball(_mb(p, GLOW), center, 0.05, 8)


## Pistola: cano reto de latão, tambor de ferro, armação de ferro, cão,
## guarda-mato e coronha curva de madeira.
static func _pistol(p: Dictionary) -> void:
	# Cano fechado nas pontas, com a alma escura na boca.
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.002, -0.005), Vector2(0.014, -0.005), Vector2(0.014, 0.165), Vector2(0.002, 0.165)]), 8, AXIS_Z, Vector3(0, 0.035, 0))
	_mb(p, DARK).lathe(PackedVector2Array([Vector2(0.007, 0.166), Vector2(0.001, 0.167)]), 8, AXIS_Z, Vector3(0, 0.035, 0))
	# Tambor fechado, com 6 câmaras na face da frente.
	_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.002, -0.01), Vector2(0.024, -0.01), Vector2(0.024, 0.04), Vector2(0.002, 0.04)]), 8, AXIS_Z, Vector3(0, 0.03, 0))
	for i in 6:
		var a := TAU * i / 6.0
		_mb(p, DARK).box(Vector3(cos(a) * 0.014, 0.03 + sin(a) * 0.014, -0.0405), Vector3(0.007, 0.007, 0.002))
	# Armação: base + parte de trás que sobe até o cão (o cão fica preso nela).
	_mb(p, IRON).box(Vector3(0, 0.012, 0.015), Vector3(0.026, 0.035, 0.07))
	_mb(p, IRON).box(Vector3(0, 0.035, 0.032), Vector3(0.022, 0.035, 0.03))
	_mb(p, IRON).box(Vector3(0, 0.054, 0.045), Vector3(0.01, 0.026, 0.012), Basis(Vector3(1, 0, 0), 0.5)) # cão
	var guard := PackedVector3Array()
	for i in 5:
		var a := lerpf(0.0, PI, i / 4.0)
		guard.append(Vector3(0, -0.005 - sin(a) * 0.028, cos(a) * 0.024))
	_mb(p, IRON).tube(guard, 0.003, 4)
	# Coronha: silhueta lateral extrudada na largura (X).
	var grip := PackedVector2Array([Vector2(-0.01, 0.0), Vector2(-0.045, 0.0), Vector2(-0.07, -0.06),
		Vector2(-0.085, -0.1), Vector2(-0.06, -0.11), Vector2(-0.035, -0.08), Vector2(-0.015, -0.03)])
	_mb(p, DARK_WOOD).extrude(grip, 0.028, Basis(Vector3(0, 1, 0), PI / 2), Vector3(0, 0, 0))


## Lanterna: corpo de latão, refletor alargado e lente acesa.
static func _lantern(p: Dictionary) -> void:
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.012, 0.0), Vector2(0.03, 0.005), Vector2(0.032, 0.15),
		Vector2(0.045, 0.2), Vector2(0.046, 0.22)]), 8, AXIS_Z)
	_mb(p, LENS).lathe(PackedVector2Array([Vector2(0.042, 0.215), Vector2(0.002, 0.23)]), 8, AXIS_Z)


## Carregador a dínamo (inspirado no do Metro Exodus), em layout HORIZONTAL:
## a mão segura o cabo à direita; o motor de ferro deitado (eixo X) vai para a
## esquerda com a bobina de cobre embaixo; o medidor fica em cima do cabo,
## virado para o player; vários fios ligam tudo. Peças móveis em nós
## separados: "Lever" (gira em X ao apertar), "Rotor" (gira em X, na ponta do
## motor) e "Needle" (gira em Z). Origem = empunhadura.
static func build_charger() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var p := {}
	var axis_x := Basis(Vector3(0, 0, 1), PI / 2) # lathe ao longo de X
	# Cabo fixo de ferro (mão) e trilho que segura o motor.
	_mb(p, IRON).box(Vector3(0, -0.04, 0.008), Vector3(0.03, 0.1, 0.034), Basis(Vector3(1, 0, 0), -0.2))
	_mb(p, IRON).box(Vector3(-0.07, 0.022, -0.02), Vector3(0.17, 0.016, 0.05))
	# Motor deitado para a esquerda, com tampas e tirantes de latão.
	var motor := Vector3(-0.095, 0.075, -0.02)
	_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.002, -0.06), Vector2(0.045, -0.06), Vector2(0.049, 0.0),
		Vector2(0.045, 0.06), Vector2(0.002, 0.06)]), 10, axis_x, motor)
	_mb(p, IRON).tube(PackedVector3Array([motor + Vector3(-0.06, 0, 0), motor + Vector3(-0.08, 0, 0)]), 0.006, 6) # eixo até o volante
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4
		var off := Vector3(0, cos(a), sin(a)) * 0.051
		_mb(p, BRASS).tube(PackedVector3Array([motor + off + Vector3(0.066, 0, 0), motor + off + Vector3(-0.066, 0, 0)]), 0.004, 4)
	# Bobina de cobre embaixo do motor, também deitada.
	var coil := Vector3(-0.09, 0.003, -0.02)
	_mb(p, COPPER).lathe(PackedVector2Array([Vector2(0.002, -0.045), Vector2(0.02, -0.045), Vector2(0.023, 0.0),
		Vector2(0.02, 0.045), Vector2(0.002, 0.045)]), 10, axis_x, coil)
	for x in [-0.05, 0.05]:
		_mb(p, IRON).lathe(PackedVector2Array([Vector2(0.002, -0.004), Vector2(0.026, -0.004), Vector2(0.026, 0.004), Vector2(0.002, 0.004)]),
				8, axis_x, coil + Vector3(x, 0, 0))
	# Medidor em cima do cabo, virado para o player (+Z).
	var gauge := Vector3(0.0, 0.095, 0.0)
	_mb(p, COPPER.darkened(0.4)).box(gauge, Vector3(0.07, 0.06, 0.024))
	_mb(p, CREAM).box(gauge + Vector3(0, 0.004, 0.0125), Vector3(0.056, 0.042, 0.002))
	for i in 5: # marcas da escala
		var a := lerpf(-0.9, 0.9, i / 4.0)
		_mb(p, DARK).box(gauge + Vector3(sin(a) * 0.022, -0.012 + cos(a) * 0.022, 0.0137), Vector3(0.0025, 0.006, 0.001), Basis(Vector3.BACK, -a))
	_mb(p, IRON).box(gauge + Vector3(0, -0.045, -0.01), Vector3(0.02, 0.035, 0.014)) # pé do medidor
	# Fios: soltos, fazendo curva, ligando medidor, motor, bobina e cabo.
	_wire(p, WIRE, [gauge + Vector3(-0.034, 0.01, -0.005), motor + Vector3(0.03, 0.07, 0.0), motor + Vector3(-0.02, 0.052, 0.0)])
	_wire(p, RED_PAINT, [gauge + Vector3(0.034, -0.015, 0.0), Vector3(0.06, 0.03, 0.02), Vector3(0.04, -0.07, 0.03), Vector3(0.01, -0.09, 0.02)])
	_wire(p, DARK, [gauge + Vector3(0.034, -0.025, -0.005), Vector3(0.07, 0.0, 0.0), Vector3(0.05, -0.08, 0.0), Vector3(0.012, -0.095, 0.0)])
	_wire(p, CREAM, [coil + Vector3(0.045, -0.01, 0.02), Vector3(-0.01, -0.03, 0.04), Vector3(-0.08, -0.06, 0.05), Vector3(-0.16, -0.03, 0.02), motor + Vector3(-0.07, -0.02, 0.03)])
	_wire(p, WIRE, [coil + Vector3(-0.045, 0.0, -0.02), Vector3(-0.17, -0.01, -0.06), motor + Vector3(-0.07, 0.0, -0.04)])
	for color in p:
		var mesh := MeshInstance3D.new()
		mesh.mesh = p[color].finish(_material(color))
		root.add_child(mesh)
	# Alavanca vermelha: pivô na base, na frente do cabo.
	var lever := Node3D.new()
	lever.name = "Lever"
	lever.position = Vector3(0, 0.01, -0.03)
	var lp := {}
	_mb(lp, RED_PAINT).box(Vector3(0, -0.055, -0.012), Vector3(0.026, 0.11, 0.018), Basis(Vector3(1, 0, 0), 0.35))
	_part(lever, lp)
	root.add_child(lever)
	# Rotor (volante) na ponta esquerda do motor; gira em X.
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = motor + Vector3(-0.078, 0, 0)
	var rp := {}
	# Volante grande de latão com 3 raios de ferro e uma manopla vermelha: bem visível girando.
	_mb(rp, BRASS).torus(0.055, 0.008, 12, 5, Basis(Vector3(0, 0, 1), PI / 2))
	_mb(rp, BRASS).lathe(PackedVector2Array([Vector2(0.002, -0.012), Vector2(0.014, -0.012), Vector2(0.014, 0.012), Vector2(0.002, 0.012)]), 8, axis_x)
	for i in 3:
		var a := TAU * i / 3.0
		_mb(rp, IRON).box(Vector3(0, cos(a), sin(a)) * 0.03, Vector3(0.008, 0.05, 0.01), Basis(Vector3.RIGHT, -a))
	_mb(rp, RED_PAINT).box(Vector3(-0.012, 0.055, 0.0), Vector3(0.022, 0.014, 0.014)) # manopla
	_part(rotor, rp)
	root.add_child(rotor)
	# Ponteiro do medidor (gira em volta do pivô embaixo do mostrador).
	var needle := Node3D.new()
	needle.name = "Needle"
	needle.position = gauge + Vector3(0, -0.012, 0.0145)
	var np := {}
	_mb(np, DARK).box(Vector3(0, 0.014, 0), Vector3(0.0018, 0.028, 0.001))
	_part(needle, np)
	root.add_child(needle)
	return root


## Fio curvo passando pelos pontos (curva suave entre eles).
static func _wire(parts: Dictionary, color: Color, points: Array) -> void:
	var path := PackedVector3Array()
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var sag := Vector3(0, -0.012, 0)
		for k in 4:
			var t := k / 4.0
			path.append(a.lerp(b, t) + sag * sin(t * PI))
	path.append(points[points.size() - 1])
	_mb(parts, color).tube(path, 0.0035, 4)


static func _part(parent: Node3D, parts: Dictionary) -> void:
	for color in parts:
		var mesh := MeshInstance3D.new()
		mesh.mesh = parts[color].finish(_material(color))
		parent.add_child(mesh)


# --- Materiais de crafting -----------------------------------------------------

static func _scrap(p: Dictionary) -> void:
	_gear(_mb(p, IRON), Vector3(-0.04, 0.0, 0.0), 0.08, 0.06, 10, Basis(Vector3(1, 0, 0), PI / 2), 0.02)
	_mb(p, COPPER).tube(PackedVector3Array([Vector3(0.02, 0.01, -0.08), Vector3(0.07, 0.02, -0.02), Vector3(0.06, 0.02, 0.06), Vector3(0.12, 0.015, 0.08)]), 0.012, 6)
	_mb(p, BRASS).box(Vector3(0.05, 0.0, 0.0), Vector3(0.06, 0.02, 0.04), Basis(Vector3(0, 1, 0), 0.6))


## Pá: cabo longo de madeira, punho em "T" e lâmina de ferro meio gasta.
static func _shovel(p: Dictionary) -> void:
	_mb(p, WOOD).lathe(PackedVector2Array([Vector2(0.018, -0.08), Vector2(0.02, 0.84)]), 8, AXIS_Z)
	_mb(p, DARK_WOOD).box(Vector3(0, 0, 0.08), Vector3(0.12, 0.03, 0.03)) # punho
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.024, 0.78), Vector2(0.026, 0.86)]), 8, AXIS_Z)
	var blade := PackedVector2Array([Vector2(-0.09, 0.0), Vector2(0.09, 0.0), Vector2(0.085, -0.16), Vector2(0.0, -0.24), Vector2(-0.085, -0.16)])
	_mb(p, IRON).extrude(blade, 0.012, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, -0.86))


## Machado: cabo de madeira levemente curvo, cabeça de ferro de um gume e cinta de latão.
static func _axe(p: Dictionary) -> void:
	_mb(p, WOOD).lathe(PackedVector2Array([Vector2(0.019, -0.06), Vector2(0.021, 0.72)]), 8, AXIS_Z)
	_mb(p, LEATHER).lathe(PackedVector2Array([Vector2(0.024, -0.05), Vector2(0.024, 0.1)]), 8, AXIS_Z)
	_mb(p, BRASS).lathe(PackedVector2Array([Vector2(0.025, 0.62), Vector2(0.025, 0.66)]), 8, AXIS_Z)
	_mb(p, IRON).box(Vector3(0, 0.0, -0.71), Vector3(0.05, 0.07, 0.08)) # olho
	var blade := PackedVector2Array([Vector2(0.0, 0.035), Vector2(0.14, 0.09), Vector2(0.16, 0.0), Vector2(0.14, -0.09), Vector2(0.0, -0.035)])
	_mb(p, STEEL).extrude(blade, 0.018, Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)), Vector3(0.02, 0, -0.71)) # gume para o lado, fino em Y


## Picareta: cabo longo e cabeça curva de ferro com duas pontas.
static func _pickaxe(p: Dictionary) -> void:
	_mb(p, WOOD).lathe(PackedVector2Array([Vector2(0.019, -0.06), Vector2(0.021, 0.74)]), 8, AXIS_Z)
	_mb(p, LEATHER).lathe(PackedVector2Array([Vector2(0.024, -0.05), Vector2(0.024, 0.1)]), 8, AXIS_Z)
	_mb(p, BRASS).box(Vector3(0, 0, -0.74), Vector3(0.06, 0.06, 0.07))
	for side in [-1.0, 1.0]:
		_mb(p, IRON).tube(PackedVector3Array([Vector3(0, 0, -0.74), Vector3(side * 0.12, -0.02, -0.75), Vector3(side * 0.2, -0.07, -0.74)]), 0.022, 4)


static func _seed_pouch(p: Dictionary, color: Color) -> void:
	_mb(p, CLOTH.darkened(0.15)).lathe(PackedVector2Array([Vector2(0.002, -0.03), Vector2(0.05, -0.025), Vector2(0.055, 0.0), Vector2(0.03, 0.03), Vector2(0.015, 0.045)]), 7)
	_mb(p, color).lathe(PackedVector2Array([Vector2(0.016, 0.04), Vector2(0.02, 0.06), Vector2(0.002, 0.065)]), 6)


static func _rock(mb: MeshBuilder) -> void:
	var profile := PackedVector2Array([Vector2(0.002, -0.05), Vector2(0.06, -0.04), Vector2(0.07, 0.0), Vector2(0.05, 0.04), Vector2(0.002, 0.055)])
	mb.lathe(profile, 5, Basis(Vector3(0.3, 1, 0.2).normalized(), 0.5))


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


## Tudo fosco: metal gasto quase não reflete (pós-apocalíptico).
static func _material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	# Peças torneadas abertas nas pontas (cabos, tubos): sem isso dá para ver
	# "através" delas por dentro (faces de trás sumiam).
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	match color:
		STEEL:
			material.metallic = 0.25
			material.roughness = 0.75
		BRASS, COPPER, IRON:
			material.metallic = 0.2
			material.roughness = 0.82
		GLOW, LENS:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 2.5
	_materials[color] = material
	return material
