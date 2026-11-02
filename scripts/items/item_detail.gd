class_name ItemDetail
## Versões mais elaboradas dos modelos de item (ainda estilo PS2: polígonos
## visíveis, fosco). Mesma convenção do ItemModels: ferramenta aponta para -Z a
## partir da mão; comida/material centrado na origem, do tamanho do ItemDB.
## ItemModels.build() usa estas quando existe uma para o item.

const AXIS_Z := Basis(Vector3(1, 0, 0), -PI / 2)
const AXIS_X := Basis(Vector3(0, 1, 0), PI / 2)

const IDS := [&"pistola", &"espada", &"taco", &"martelo", &"talhadeira", &"pa", &"machado", &"picareta", &"lanca",
	&"machado_simples", &"picareta_simples", &"lanterna", &"bumerangue", &"tocha", &"bandeira", &"muda",
	&"fruta", &"lata", &"lata_quente", &"pao", &"pao_fresco", &"torrada", &"cenoura", &"cenoura_assada", &"batata", &"batata_assada",
	&"abobora", &"abobora_assada", &"bandagem", &"semente_cenoura", &"semente_batata", &"semente_abobora",
	&"semente_trigo", &"semente_algodao", &"trigo", &"farinha", &"peixe_seco", &"peixe_defumado", &"comida_estragada",
	&"adubo", &"tabua", &"tronco", &"graveto", &"pedra", &"minerio_ferro", &"minerio_cobre", &"carvao",
	&"barra_ferro", &"barra_cobre", &"vidro", &"sucata", &"pano", &"argila", &"areia", &"tijolo", &"fibra",
	&"fio", &"tecido", &"garrafa", &"agua", &"agua_suja", &"capuz", &"capacete", &"colete", &"peitoral",
	&"calca", &"botas", &"casaco",
	&"barra_aco", &"parafuso", &"engrenagem", &"eixo_aco", &"cano", &"suco", &"oleo", &"alcool", &"bandagem_esteril",
	&"carne_crua", &"carne_assada", &"carne_seca", &"pele", &"couro", &"gordura", &"casaco_pele", &"correia", &"vara",
	&"ovo", &"ovo_frito", &"leite", &"la", &"pena", &"gorro_la", &"casaco_la", &"casaco_penas",
	&"eixo", &"engrenagem_madeira", &"polia"]


static func has(id: StringName) -> bool:
	return id in IDS


static func build(id: StringName, p: Dictionary) -> void:
	match id:
		&"pistola": _revolver(p)
		&"espada": _sword(p)
		&"taco": _mace(p)
		&"martelo": _hammer(p)
		&"talhadeira": _chisel(p)
		&"pa": _shovel(p)
		&"machado": _axe(p)
		&"picareta": _pickaxe(p)
		&"lanca": _spear(p)
		&"machado_simples": _stone_tool(p, false)
		&"picareta_simples": _stone_tool(p, true)
		&"lanterna": _lantern(p)
		&"bumerangue": _boomerang(p)
		&"tocha": _torch(p)
		&"bandeira": _flag(p)
		&"muda": _sapling(p)
		&"fruta": _apple(p)
		&"lata", &"lata_quente": _can(p, id == &"lata_quente")
		&"pao", &"pao_fresco": _loaf(p, id == &"pao_fresco")
		&"torrada": _toast(p)
		&"cenoura", &"cenoura_assada": _carrot(p, id == &"cenoura_assada")
		&"batata", &"batata_assada": _potato(p, id == &"batata_assada")
		&"abobora", &"abobora_assada": _pumpkin(p, id == &"abobora_assada")
		&"bandagem": _bandage(p)
		&"semente_cenoura", &"semente_batata", &"semente_abobora", &"semente_trigo", &"semente_algodao": _seeds(p, id)
		&"trigo": _wheat(p)
		&"farinha": _sack(p, Color(0.82, 0.78, 0.66), Color(0.95, 0.93, 0.88))
		&"adubo": _sack(p, Color(0.5, 0.42, 0.3), Color(0.22, 0.15, 0.08))
		&"peixe_seco": _flat_fish(p, Color(0.72, 0.6, 0.4))
		&"peixe_defumado": _flat_fish(p, Color(0.45, 0.27, 0.14))
		&"comida_estragada": _rotten(p)
		&"tabua": _plank(p)
		&"tronco": _log(p)
		&"graveto": _stick(p)
		&"pedra": _stone(p, Color(0.5, 0.49, 0.46), 11, [])
		&"minerio_ferro": _stone(p, Color(0.42, 0.33, 0.28), 7, [Color(0.68, 0.38, 0.2), Color(0.55, 0.3, 0.18)])
		&"minerio_cobre": _stone(p, Color(0.42, 0.4, 0.37), 5, [Color(0.25, 0.6, 0.5), ItemModels.COPPER.lightened(0.15)])
		&"carvao": _coal(p)
		&"barra_ferro": _ingot(p, ItemModels.IRON.lightened(0.2))
		&"barra_cobre": _ingot(p, ItemModels.COPPER.lightened(0.12))
		&"vidro": _glass(p)
		&"sucata": _scrap(p)
		&"pano": _cloth_stack(p)
		&"argila": _clay(p)
		&"areia": _sand(p)
		&"tijolo": _brick(p)
		&"fibra": _cotton(p)
		&"fio": _spool(p)
		&"tecido": _bolt(p)
		&"garrafa", &"agua", &"agua_suja", &"suco", &"oleo", &"alcool", &"leite": _bottle(p, id)
		&"ovo": _egg(p)
		&"ovo_frito": _fried_egg(p)
		&"la": _wool(p)
		&"pena": _feather(p)
		&"gorro_la": _beanie(p)
		&"casaco_la": _wool_coat(p)
		&"casaco_penas": _down_coat(p)
		&"barra_aco": _ingot(p, Color(0.46, 0.49, 0.54))
		&"carne_crua", &"carne_assada": _steak(p, id == &"carne_assada")
		&"carne_seca": _jerky(p)
		&"pele": _fur_hide(p)
		&"couro": _leather_roll(p)
		&"gordura": _lard(p)
		&"casaco_pele": _fur_coat(p)
		&"correia": _belt_coil(p)
		&"vara": _fishing_rod(p)
		&"parafuso": _bolts(p)
		&"engrenagem": _gear(p)
		&"eixo": _wood_axle(p)
		&"engrenagem_madeira": _wood_cog(p, false)
		&"polia": _wood_pulley(p)
		&"eixo_aco": _steel_shaft(p)
		&"cano": _pipe_piece(p)
		&"bandagem_esteril":
			_bandage(p)
			_mb(p, Color(0.85, 0.65, 0.25)).box(Vector3(-0.031, 0.0, 0.0), Vector3(0.002, 0.05, 0.05)) # mancha de álcool (iodo)
		&"capuz": _hood(p)
		&"capacete": _helmet(p)
		&"colete", &"peitoral": _vest(p, id == &"peitoral")
		&"calca": _pants(p)
		&"botas": _boots(p)
		&"casaco": _coat(p)


# --- utilidades ------------------------------------------------------------------

static func _mb(p: Dictionary, c: Color) -> MeshBuilder:
	return ItemModels._mb(p, c)


## Bola irregular (pedra, batata, argila): anéis com raio sorteado por vértice.
static func _blob(mb: MeshBuilder, center: Vector3, radius: Vector3, seed: int, rough := 0.18, segments := 9, rings := 6) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var list := []
	for r in rings + 1:
		var lat := lerpf(-PI / 2, PI / 2, float(r) / rings)
		var ring := PackedVector3Array()
		for s in segments:
			var lon := TAU * s / segments
			var k := 1.0 + rng.randf_range(-rough, rough) if r > 0 and r < rings else 1.0
			var dir := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			ring.append(center + Vector3(dir.x * radius.x, dir.y * radius.y, dir.z * radius.z) * k)
		list.append(ring)
	mb.loft(list, true, false, true)


## Cabo torneado ao longo de -Z com anéis de couro enrolado.
static func _grip(p: Dictionary, from: float, to: float, radius: float, color: Color, wraps := 5) -> void:
	_mb(p, color).lathe(PackedVector2Array([Vector2(radius, from), Vector2(radius, to)]), 8, AXIS_Z)
	var step := (to - from) / wraps
	for k in wraps:
		var z := from + step * (k + 0.5)
		_mb(p, color.darkened(0.25)).lathe(PackedVector2Array([Vector2(radius + 0.003, z - step * 0.18), Vector2(radius + 0.004, z), Vector2(radius + 0.003, z + step * 0.18)]), 8, AXIS_Z)


## Peça curva que afina: anéis perpendiculares ao caminho (seção de "sides"
## lados), ligados e tampados. "across" = eixo que fica fixo de lado (não gira).
static func _taper(mb: MeshBuilder, path: PackedVector3Array, r0: float, r1: float, across: Vector3, sides := 4) -> void:
	var rings := []
	for i in path.size():
		var tangent := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var normal := tangent.cross(across).normalized()
		var radius := lerpf(r0, r1, float(i) / (path.size() - 1))
		var ring := PackedVector3Array()
		for k in sides:
			var a := TAU * k / sides + PI / sides
			ring.append(path[i] + (normal * cos(a) + across * sin(a)) * radius)
		rings.append(ring)
	mb.loft(rings, true, true)


static func _rivet(p: Dictionary, at: Vector3, color := Color(0.5, 0.45, 0.35), r := 0.006) -> void:
	_mb(p, color).box(at, Vector3(r, r, r) * 2.0)


# --- armas e ferramentas -----------------------------------------------------------

## Revólver de 6 tiros: cano octogonal com massa de mira, tambor canelado com as
## câmaras à mostra, armação fechada em volta do tambor, vareta de ejeção embaixo
## do cano, cão com espora, gatilho curvo, guarda-mato e coronha curva de madeira
## com placas quadriculadas, parafuso e argola. Boca do cano em (0, 0.035, -0.17).
static func _revolver(p: Dictionary) -> void:
	var blued := Color(0.2, 0.2, 0.22)
	var steel := ItemModels.STEEL.darkened(0.15)
	var axis := Vector3(0, 0.035, 0)
	# Cano octogonal com nervura em cima e a alma escura na boca.
	_mb(p, blued).lathe(PackedVector2Array([Vector2(0.002, -0.032), Vector2(0.0125, -0.032), Vector2(0.0115, 0.168), Vector2(0.002, 0.168)]), 8, AXIS_Z, axis)
	_mb(p, blued.lightened(0.08)).box(Vector3(0, 0.048, -0.1), Vector3(0.006, 0.004, 0.13)) # nervura
	_mb(p, ItemModels.DARK).lathe(PackedVector2Array([Vector2(0.006, 0.1685), Vector2(0.001, 0.169)]), 8, AXIS_Z, axis)
	_mb(p, steel).box(Vector3(0, 0.051, -0.16), Vector3(0.003, 0.008, 0.012)) # massa de mira
	# Vareta de ejeção embaixo do cano.
	_mb(p, steel).lathe(PackedVector2Array([Vector2(0.0045, -0.03), Vector2(0.0045, 0.12)]), 6, AXIS_Z, Vector3(0, 0.017, 0))
	_mb(p, steel).lathe(PackedVector2Array([Vector2(0.002, 0.12), Vector2(0.007, 0.121), Vector2(0.007, 0.13), Vector2(0.002, 0.131)]), 6, AXIS_Z, Vector3(0, 0.017, 0))
	# Tambor canelado (6 câmaras) com o pino na frente.
	var drum := Vector3(0, 0.03, 0.0)
	_mb(p, steel).lathe(PackedVector2Array([Vector2(0.002, -0.026), Vector2(0.02, -0.026), Vector2(0.024, -0.022), Vector2(0.024, 0.026), Vector2(0.021, 0.03), Vector2(0.002, 0.03)]), 12, AXIS_Z, drum)
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		_mb(p, steel.darkened(0.35)).box(drum + Vector3(cos(a) * 0.0235, sin(a) * 0.0235, -0.002), Vector3(0.006, 0.006, 0.034), Basis(Vector3.BACK, a)) # canelura
		var b := TAU * i / 6.0
		_mb(p, ItemModels.DARK).box(drum + Vector3(cos(b) * 0.014, sin(b) * 0.014, -0.0305), Vector3(0.008, 0.008, 0.002)) # câmara
		_mb(p, ItemModels.BRASS).box(drum + Vector3(cos(b) * 0.014, sin(b) * 0.014, 0.0265), Vector3(0.007, 0.007, 0.002)) # culote da bala atrás
	_mb(p, steel).lathe(PackedVector2Array([Vector2(0.004, 0.03), Vector2(0.004, 0.04)]), 6, AXIS_Z, drum) # pino
	# Armação: ponte em cima, parte de baixo e o escudo atrás do tambor.
	_mb(p, blued).box(Vector3(0, 0.057, 0.0), Vector3(0.012, 0.008, 0.075)) # ponte
	_mb(p, blued).box(Vector3(0, 0.004, 0.005), Vector3(0.016, 0.014, 0.075)) # baixo
	_mb(p, blued).box(Vector3(0, 0.03, -0.034), Vector3(0.016, 0.044, 0.01)) # frente do quadro
	_mb(p, blued).box(Vector3(0, 0.03, 0.034), Vector3(0.026, 0.06, 0.014)) # escudo
	_mb(p, blued.lightened(0.1)).box(Vector3(0, 0.062, 0.035), Vector3(0.004, 0.004, 0.012)) # mira traseira (entalhe)
	# Cão com espora.
	_mb(p, steel).box(Vector3(0, 0.052, 0.046), Vector3(0.008, 0.024, 0.012), Basis(Vector3.RIGHT, 0.5))
	_mb(p, steel).box(Vector3(0, 0.066, 0.058), Vector3(0.01, 0.007, 0.02), Basis(Vector3.RIGHT, 0.2)) # espora
	for k in 3:
		_mb(p, steel.darkened(0.3)).box(Vector3(0, 0.07, 0.052 + k * 0.006), Vector3(0.011, 0.002, 0.002)) # ranhuras
	# Gatilho curvo e guarda-mato de latão.
	_mb(p, steel).tube(PackedVector3Array([Vector3(0, -0.002, 0.012), Vector3(0, -0.014, 0.008), Vector3(0, -0.024, 0.014)]), 0.0028, 4)
	var guard := PackedVector3Array()
	for i in 7:
		var a := lerpf(0.0, PI, i / 6.0)
		guard.append(Vector3(0, -0.003 - sin(a) * 0.03, 0.012 + cos(a) * 0.026))
	_mb(p, ItemModels.BRASS).tube(guard, 0.0032, 4)
	# Coronha curva ("cabeça de pássaro"): miolo de ferro, placas de madeira, parafuso e argola.
	# Silhueta lateral: x negativo = para trás (+Z), y negativo = para baixo.
	var grip := PackedVector2Array([Vector2(-0.008, 0.0), Vector2(-0.032, 0.002), Vector2(-0.05, -0.03), Vector2(-0.07, -0.075),
		Vector2(-0.075, -0.105), Vector2(-0.055, -0.112), Vector2(-0.038, -0.09), Vector2(-0.022, -0.05), Vector2(-0.008, -0.02)])
	_mb(p, blued).extrude(grip, 0.014, Basis(Vector3(0, 1, 0), PI / 2), Vector3(-0.007, 0.0, 0.02))
	var panel := PackedVector2Array([Vector2(-0.03, -0.01), Vector2(-0.045, -0.035), Vector2(-0.062, -0.075), Vector2(-0.066, -0.098),
		Vector2(-0.055, -0.102), Vector2(-0.042, -0.085), Vector2(-0.03, -0.05), Vector2(-0.022, -0.025)])
	for side in [-1.0, 1.0]:
		_mb(p, ItemModels.DARK_WOOD.lightened(0.08)).extrude(panel, 0.005, Basis(Vector3(0, 1, 0), PI / 2), Vector3(side * 0.0095 - 0.0025, 0.0, 0.02))
		for k in 4: # quadriculado
			_mb(p, ItemModels.DARK_WOOD.darkened(0.25)).box(Vector3(side * 0.0121, -0.04 - k * 0.014, 0.062 + k * 0.006), Vector3(0.0008, 0.004, 0.012), Basis(Vector3.RIGHT, -0.4))
		_mb(p, ItemModels.BRASS).box(Vector3(side * 0.0124, -0.06, 0.07), Vector3(0.002, 0.006, 0.006)) # parafuso
	_mb(p, ItemModels.BRASS).box(Vector3(0, -0.108, 0.086), Vector3(0.016, 0.008, 0.022), Basis(Vector3.RIGHT, 0.3)) # chapa da base
	_mb(p, steel).torus(0.008, 0.0018, 8, 3, Basis(Vector3.BACK, PI / 2), Vector3(0, -0.12, 0.092)) # argola


static func _sword(p: Dictionary) -> void:
	# Lâmina com sulco (fuller) e ponta afiada.
	var blade := []
	for s in [[-0.05, 0.032, 0.008], [-0.3, 0.03, 0.0075], [-0.65, 0.027, 0.0065], [-0.86, 0.019, 0.0055], [-0.97, 0.002, 0.002]]:
		blade.append(MeshBuilder.ring(Vector3(0, 0, s[0]), s[1], s[2], 1.0, 4))
	blade.reverse()
	_mb(p, ItemModels.STEEL).loft(blade, true, true)
	for side in [-1.0, 1.0]:
		_mb(p, ItemModels.STEEL.darkened(0.25)).box(Vector3(0, side * 0.0075, -0.38), Vector3(0.012, 0.002, 0.58)) # sulco
	# Guarda com braços curvos e bolinhas nas pontas.
	_mb(p, ItemModels.BRASS).tube(PackedVector3Array([Vector3(-0.11, 0.0, -0.01), Vector3(-0.06, 0, -0.035), Vector3(0, 0, -0.04),
		Vector3(0.06, 0, -0.035), Vector3(0.11, 0.0, -0.01)]), 0.012, 6)
	for side in [-1.0, 1.0]:
		ItemModels._ball(_mb(p, ItemModels.BRASS), Vector3(side * 0.115, 0, -0.008), 0.016, 6)
	_mb(p, ItemModels.BRASS).box(Vector3(0, 0, -0.045), Vector3(0.05, 0.022, 0.03)) # ricasso
	_grip(p, -0.15, -0.01, 0.02, ItemModels.LEATHER, 6) # atrás da guarda (h negativo = +Z, lado da mão)
	# Pomo redondo com aro.
	ItemModels._ball(_mb(p, ItemModels.IRON), Vector3(0, 0, 0.165), 0.028, 8)
	_mb(p, ItemModels.BRASS).torus(0.024, 0.004, 10, 4, AXIS_Z, Vector3(0, 0, 0.145))


static func _mace(p: Dictionary) -> void:
	_mb(p, ItemModels.DARK_WOOD).lathe(PackedVector2Array([Vector2(0.024, -0.08), Vector2(0.026, 0.62)]), 8, AXIS_Z)
	_grip(p, -0.06, 0.13, 0.029, ItemModels.LEATHER, 5)
	_mb(p, ItemModels.IRON).lathe(PackedVector2Array([Vector2(0.002, -0.1), Vector2(0.034, -0.095), Vector2(0.032, -0.07)]), 8, AXIS_Z)
	# Cabeça com 6 flanges e pontas, colar de latão e rebites.
	_mb(p, ItemModels.IRON).lathe(PackedVector2Array([Vector2(0.05, 0.6), Vector2(0.06, 0.64), Vector2(0.062, 0.8), Vector2(0.03, 0.86), Vector2(0.002, 0.87)]), 8, AXIS_Z)
	for i in 6:
		var a := TAU * i / 6.0
		var out := Vector3(cos(a), sin(a), 0)
		var flange := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.04, 0.03), Vector2(0.05, 0.11), Vector2(0.02, 0.2), Vector2(0.0, 0.2)])
		_mb(p, ItemModels.IRON.lightened(0.08)).extrude(flange, 0.012, Basis(out, Vector3(0, 0, -1), out.cross(Vector3(0, 0, -1))), Vector3(0, 0, -0.62) + out * 0.05)
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		_rivet(p, Vector3(cos(a) * 0.064, sin(a) * 0.064, -0.7))
	_mb(p, ItemModels.BRASS).lathe(PackedVector2Array([Vector2(0.034, 0.55), Vector2(0.038, 0.575), Vector2(0.034, 0.6)]), 8, AXIS_Z)


static func _hammer(p: Dictionary) -> void:
	_mb(p, ItemModels.WOOD).lathe(PackedVector2Array([Vector2(0.018, -0.06), Vector2(0.021, 0.2), Vector2(0.019, 0.34)]), 8, AXIS_Z)
	_grip(p, -0.05, 0.09, 0.023, ItemModels.LEATHER, 4)
	_mb(p, ItemModels.BRASS).lathe(PackedVector2Array([Vector2(0.024, 0.29), Vector2(0.026, 0.31), Vector2(0.024, 0.33)]), 8, AXIS_Z)
	# Cabeça: miolo octogonal, face de bater larga, garra partida em duas.
	_mb(p, ItemModels.IRON).lathe(PackedVector2Array([Vector2(0.026, -0.03), Vector2(0.03, -0.02), Vector2(0.03, 0.06), Vector2(0.036, 0.075), Vector2(0.036, 0.09), Vector2(0.002, 0.092)]), 8,
		Basis.IDENTITY, Vector3(0, 0.0, -0.36))
	_mb(p, ItemModels.IRON).box(Vector3(0, -0.01, -0.36), Vector3(0.045, 0.06, 0.06))
	for side in [-1.0, 1.0]:
		_mb(p, ItemModels.IRON).box(Vector3(side * 0.011, -0.075, -0.35), Vector3(0.016, 0.1, 0.03), Basis(Vector3.RIGHT, 0.4)) # garra
	_mb(p, ItemModels.STEEL).box(Vector3(0, 0.0, -0.36), Vector3(0.006, 0.05, 0.062)) # cunha no olho


static func _chisel(p: Dictionary) -> void:
	_mb(p, ItemModels.DARK_WOOD).lathe(PackedVector2Array([Vector2(0.016, -0.05), Vector2(0.022, -0.03), Vector2(0.023, 0.06), Vector2(0.02, 0.1)]), 8, AXIS_Z)
	_mb(p, ItemModels.IRON).lathe(PackedVector2Array([Vector2(0.002, -0.065), Vector2(0.02, -0.06), Vector2(0.018, -0.05)]), 8, AXIS_Z) # topo de bater
	_mb(p, ItemModels.BRASS).lathe(PackedVector2Array([Vector2(0.024, 0.1), Vector2(0.026, 0.112), Vector2(0.024, 0.125)]), 8, AXIS_Z)
	var blade := []
	for s in [[-0.125, 0.011, 0.011], [-0.16, 0.012, 0.009], [-0.23, 0.015, 0.006], [-0.29, 0.018, 0.0015]]:
		blade.append(MeshBuilder.ring(Vector3(0, 0, s[0]), s[1], s[2], 4.0, 6))
	blade.reverse()
	_mb(p, ItemModels.STEEL).loft(blade, true, true)


static func _shovel(p: Dictionary) -> void:
	_mb(p, ItemModels.WOOD).lathe(PackedVector2Array([Vector2(0.018, -0.02), Vector2(0.02, 0.8)]), 8, AXIS_Z)
	# Punho em "D".
	_mb(p, ItemModels.DARK_WOOD).box(Vector3(0, 0, 0.1), Vector3(0.11, 0.03, 0.028))
	for side in [-1.0, 1.0]:
		_mb(p, ItemModels.IRON).tube(PackedVector3Array([Vector3(side * 0.05, 0, 0.1), Vector3(side * 0.03, 0, 0.04), Vector3(0, 0, -0.01)]), 0.008, 4)
	# Colarinho de ferro com rebites e lâmina com degrau para o pé.
	_mb(p, ItemModels.IRON).lathe(PackedVector2Array([Vector2(0.024, 0.74), Vector2(0.03, 0.82), Vector2(0.06, 0.86)]), 8, AXIS_Z)
	for side in [-1.0, 1.0]:
		_rivet(p, Vector3(side * 0.026, 0, -0.78))
	var blade := PackedVector2Array([Vector2(-0.1, 0.0), Vector2(0.1, 0.0), Vector2(0.095, -0.17), Vector2(0.04, -0.25), Vector2(0.0, -0.27), Vector2(-0.04, -0.25), Vector2(-0.095, -0.17)])
	_mb(p, ItemModels.IRON).extrude(blade, 0.012, Basis(Vector3.RIGHT, PI / 2) * Basis(Vector3.RIGHT, 0.12), Vector3(0, 0, -0.86))
	_mb(p, ItemModels.IRON.darkened(0.2)).box(Vector3(0, 0.012, -0.865), Vector3(0.2, 0.012, 0.02)) # degrau
	_mb(p, ItemModels.STEEL).box(Vector3(0, -0.035, -1.11), Vector3(0.07, 0.006, 0.02)) # fio gasto e brilhante


static func _axe(p: Dictionary) -> void:
	# Cabo em S suave.
	_mb(p, ItemModels.WOOD).tube(PackedVector3Array([Vector3(0, 0, 0.06), Vector3(0, -0.012, -0.2), Vector3(0, 0.008, -0.5), Vector3(0, 0, -0.76)]), 0.02, 8)
	_grip(p, -0.05, 0.1, 0.024, ItemModels.LEATHER, 4)
	_mb(p, ItemModels.BRASS).lathe(PackedVector2Array([Vector2(0.024, 0.6), Vector2(0.027, 0.62), Vector2(0.024, 0.64)]), 8, AXIS_Z)
	# Cabeça barbada: olho, face e gume largo.
	_mb(p, ItemModels.IRON).box(Vector3(0, 0, -0.71), Vector3(0.05, 0.08, 0.085))
	_mb(p, ItemModels.IRON).box(Vector3(-0.035, 0, -0.71), Vector3(0.025, 0.05, 0.07)) # nuca
	var blade := PackedVector2Array([Vector2(0.0, 0.04), Vector2(0.09, 0.06), Vector2(0.15, 0.1), Vector2(0.17, 0.02), Vector2(0.16, -0.08), Vector2(0.12, -0.14), Vector2(0.06, -0.06), Vector2(0.0, -0.04)])
	_mb(p, ItemModels.STEEL.darkened(0.15)).extrude(blade, 0.016, Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)), Vector3(0.02, 0, -0.71))
	_mb(p, ItemModels.STEEL.lightened(0.15)).box(Vector3(0.185, 0, -0.73), Vector3(0.012, 0.018, 0.2), Basis(Vector3.UP, 0.05)) # fio
	_mb(p, ItemModels.STEEL).box(Vector3(0, 0, -0.71), Vector3(0.052, 0.006, 0.02)) # cunha


static func _pickaxe(p: Dictionary) -> void:
	_mb(p, ItemModels.WOOD).lathe(PackedVector2Array([Vector2(0.019, -0.06), Vector2(0.023, 0.4), Vector2(0.021, 0.74)]), 8, AXIS_Z)
	_grip(p, -0.05, 0.1, 0.025, ItemModels.LEATHER, 4)
	_mb(p, ItemModels.BRASS).lathe(PackedVector2Array([Vector2(0.03, 0.66), Vector2(0.034, 0.7), Vector2(0.03, 0.72)]), 8, AXIS_Z)
	_mb(p, ItemModels.IRON).box(Vector3(0, 0, -0.74), Vector3(0.07, 0.065, 0.08))
	for side in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		for k in 8:
			var t := k / 7.0
			pts.append(Vector3(side * (0.03 + t * 0.21), -0.085 * t * t, -0.74))
		# Ponta contínua: seção quadrada que afina ao longo da curva, até a ponta.
		_taper(_mb(p, ItemModels.IRON.lightened(0.05)), pts, 0.027, 0.003, Vector3(0, 0, 1))
	_mb(p, ItemModels.STEEL).box(Vector3(0, 0, -0.74), Vector3(0.072, 0.006, 0.02))


static func _spear(p: Dictionary) -> void:
	_mb(p, ItemModels.WOOD).lathe(PackedVector2Array([Vector2(0.018, -0.1), Vector2(0.019, 0.7), Vector2(0.017, 1.45)]), 6, AXIS_Z)
	_mb(p, ItemModels.IRON).lathe(PackedVector2Array([Vector2(0.002, -0.13), Vector2(0.02, -0.11), Vector2(0.02, -0.1)]), 6, AXIS_Z) # ponteira de trás
	_grip(p, 0.2, 0.45, 0.022, ItemModels.LEATHER, 5)
	# Soquete e lâmina em folha.
	_mb(p, ItemModels.IRON).lathe(PackedVector2Array([Vector2(0.021, 1.42), Vector2(0.024, 1.5), Vector2(0.016, 1.54)]), 6, AXIS_Z)
	var blade := []
	for s in [[-1.54, 0.012, 0.01], [-1.6, 0.04, 0.008], [-1.66, 0.036, 0.006], [-1.74, 0.002, 0.002]]:
		blade.append(MeshBuilder.ring(Vector3(0, 0, s[0]), s[1], s[2], 1.2, 4))
	blade.reverse()
	_mb(p, ItemModels.STEEL).loft(blade, true, true)
	for k in 3:
		_mb(p, ItemModels.LEATHER.darkened(0.2)).lathe(PackedVector2Array([Vector2(0.024, 1.4 + k * 0.02), Vector2(0.024, 1.41 + k * 0.02)]), 6, AXIS_Z)


static func _stone_tool(p: Dictionary, pick: bool) -> void:
	var wood := Color(0.42, 0.3, 0.18)
	_mb(p, wood).tube(PackedVector3Array([Vector3(0, 0, 0.05), Vector3(0.006, 0.004, -0.25), Vector3(-0.004, 0, -0.62)]), 0.016, 6)
	_mb(p, wood.darkened(0.2)).tube(PackedVector3Array([Vector3(0.01, 0, -0.3), Vector3(0.03, 0.02, -0.34)]), 0.006, 4) # galhinho
	var stone := Color(0.5, 0.49, 0.46)
	if pick:
		for side in [-1.0, 1.0]:
			var tip := []
			for s in [[0.0, 0.03, 0.022], [0.08, 0.024, 0.018], [0.15, 0.004, 0.004]]:
				var r := MeshBuilder.ring(Vector3.ZERO, s[1], s[2], 1.5, 5)
				var placed := PackedVector3Array()
				for v in r:
					placed.append(Vector3(side * (0.02 + s[0]), v.y - s[0] * 0.25, -0.58 + v.x))
				tip.append(placed)
			_mb(p, stone).loft(tip, true, true)
	else:
		var flake := PackedVector2Array([Vector2(0.0, 0.03), Vector2(0.08, 0.06), Vector2(0.14, 0.02), Vector2(0.13, -0.05), Vector2(0.05, -0.06), Vector2(0.0, -0.03)])
		_mb(p, stone).extrude(flake, 0.03, Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)), Vector3(0.01, 0, -0.57))
		_mb(p, stone.lightened(0.15)).box(Vector3(0.145, 0, -0.58), Vector3(0.01, 0.012, 0.1)) # fio lascado
	# Amarração cruzada de pano.
	for k in 4:
		_mb(p, ItemModels.CLOTH.darkened(0.25)).box(Vector3(0, 0, -0.56 - k * 0.012), Vector3(0.045, 0.045, 0.008), Basis(Vector3.BACK, k * 0.4))


static func _lantern(p: Dictionary) -> void:
	_mb(p, ItemModels.BRASS).lathe(PackedVector2Array([Vector2(0.002, -0.01), Vector2(0.026, -0.008), Vector2(0.03, 0.005), Vector2(0.031, 0.15),
		Vector2(0.046, 0.2), Vector2(0.048, 0.225)]), 10, AXIS_Z)
	for z in [0.04, 0.09, 0.13]:
		_mb(p, ItemModels.BRASS.darkened(0.25)).lathe(PackedVector2Array([Vector2(0.0325, z), Vector2(0.0325, z + 0.008)]), 10, AXIS_Z) # ranhuras
	_mb(p, ItemModels.LENS).lathe(PackedVector2Array([Vector2(0.043, 0.22), Vector2(0.02, 0.228), Vector2(0.002, 0.23)]), 10, AXIS_Z)
	_mb(p, ItemModels.RED_PAINT).box(Vector3(0, 0.034, -0.07), Vector3(0.014, 0.01, 0.02)) # botão
	_mb(p, ItemModels.IRON).tube(PackedVector3Array([Vector3(0, 0.03, -0.01), Vector3(0, 0.06, -0.05), Vector3(0, 0.06, -0.12), Vector3(0, 0.034, -0.16)]), 0.005, 4) # alça


static func _boomerang(p: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		var rings := []
		for k in 6:
			var t := k / 5.0
			var center := Vector3(side * sin(0.95) * t * 0.3, 0, -cos(0.95) * t * 0.3 - 0.01)
			var w := lerpf(0.036, 0.024, t)
			var ring := PackedVector3Array()
			var across := Vector3(cos(0.95), 0, side * sin(0.95))
			for s in 6:
				var a := TAU * s / 6.0
				ring.append(center + across * cos(a) * w + Vector3.UP * sin(a) * 0.008 * (1.0 if sin(a) > 0 else 0.6))
			rings.append(ring)
		_mb(p, ItemModels.WOOD).loft(rings, true, true)
		var arm := Basis(Vector3.UP, side * 0.95)
		_mb(p, ItemModels.RED_PAINT).box(arm * Vector3(0, 0.008, -0.2), Vector3(0.05, 0.003, 0.025), arm)
		_mb(p, ItemModels.CREAM).box(arm * Vector3(0, 0.008, -0.12), Vector3(0.055, 0.003, 0.018), arm)


static func _torch(p: Dictionary) -> void:
	_mb(p, Color(0.42, 0.3, 0.18)).lathe(PackedVector2Array([Vector2(0.018, -0.2), Vector2(0.022, 0.0), Vector2(0.026, 0.14)]), 6)
	for k in 4: # pano enrolado em espiral
		_mb(p, ItemModels.CLOTH.darkened(0.1 + k * 0.08)).lathe(PackedVector2Array([Vector2(0.03, 0.12 + k * 0.025), Vector2(0.04, 0.13 + k * 0.025), Vector2(0.03, 0.145 + k * 0.025)]), 7)
	_mb(p, Color(0.12, 0.1, 0.08)).lathe(PackedVector2Array([Vector2(0.035, 0.22), Vector2(0.02, 0.24), Vector2(0.002, 0.245)]), 7) # queimado
	_mb(p, ItemModels.IRON).lathe(PackedVector2Array([Vector2(0.028, 0.1), Vector2(0.028, 0.115)]), 6) # anel


static func _flag(p: Dictionary) -> void:
	_mb(p, Color(0.42, 0.3, 0.18)).lathe(PackedVector2Array([Vector2(0.002, -0.62), Vector2(0.02, -0.58), Vector2(0.018, 0.6), Vector2(0.002, 0.61)]), 6)
	ItemModels._ball(_mb(p, ItemModels.BRASS), Vector3(0, 0.63, 0), 0.025, 6)
	var grid := []
	for r in 4:
		var row := PackedVector3Array()
		for c in 6:
			var x := 0.02 + c * 0.065
			row.append(Vector3(x, 0.55 - r * 0.075, sin(c * 1.3) * 0.02 * (c / 5.0)))
		grid.append(row)
	_mb(p, Color(0.75, 0.12, 0.1)).sheet(grid)


static func _sapling(p: Dictionary) -> void:
	_mb(p, Color(0.36, 0.25, 0.15)).lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.06, 0.0), Vector2(0.065, 0.03), Vector2(0.04, 0.05), Vector2(0.002, 0.055)]), 8) # torrão
	var stem := Color(0.4, 0.3, 0.16)
	_mb(p, stem).tube(PackedVector3Array([Vector3(0, 0.04, 0), Vector3(0.01, 0.15, 0), Vector3(-0.005, 0.28, 0.005)]), 0.01, 5)
	_mb(p, stem).tube(PackedVector3Array([Vector3(0.008, 0.15, 0), Vector3(0.05, 0.21, 0.02)]), 0.005, 4)
	for leaf in [[Vector3(0.05, 0.22, 0.02), 0.6], [Vector3(-0.03, 0.27, -0.02), -0.8], [Vector3(0.0, 0.31, 0.03), 0.2], [Vector3(0.03, 0.28, -0.03), 2.0]]:
		var shape := PackedVector2Array([Vector2(0, 0), Vector2(0.025, 0.02), Vector2(0.03, 0.05), Vector2(0.0, 0.08), Vector2(-0.03, 0.05), Vector2(-0.025, 0.02)])
		_mb(p, Color(0.3, 0.55, 0.22)).extrude(shape, 0.004, Basis(Vector3.UP, leaf[1]) * Basis(Vector3.RIGHT, -0.9), leaf[0])


# --- comida ---------------------------------------------------------------------

static func _apple(p: Dictionary) -> void:
	var profile := PackedVector2Array()
	for i in 9:
		var a := lerpf(-PI / 2, PI / 2, i / 8.0)
		var r := cos(a) * 0.07 * (1.0 + 0.08 * sin(a))
		profile.append(Vector2(maxf(r, 0.004), sin(a) * 0.065 - (0.012 if i == 8 else 0.0)))
	_mb(p, Color(0.68, 0.12, 0.08)).lathe(profile, 10)
	_mb(p, Color(0.85, 0.55, 0.15)).box(Vector3(0.04, 0.03, 0.04), Vector3(0.03, 0.025, 0.02), Basis(Vector3.UP, 0.8)) # mancha
	_mb(p, ItemModels.DARK_WOOD).tube(PackedVector3Array([Vector3(0, 0.05, 0), Vector3(0.008, 0.085, 0), Vector3(0.015, 0.1, 0)]), 0.006, 4)
	var leaf := PackedVector2Array([Vector2(0, 0), Vector2(0.015, 0.012), Vector2(0.02, 0.03), Vector2(0.0, 0.05), Vector2(-0.015, 0.03)])
	_mb(p, Color(0.25, 0.48, 0.18)).extrude(leaf, 0.003, Basis(Vector3.BACK, -1.1), Vector3(0.012, 0.09, 0))


static func _can(p: Dictionary, hot: bool) -> void:
	var tin := Color(0.52, 0.5, 0.46) if not hot else Color(0.38, 0.35, 0.32)
	var profile := PackedVector2Array([Vector2(0.002, -0.066), Vector2(0.046, -0.066), Vector2(0.05, -0.062)])
	for k in 6: # frisos
		var y := -0.05 + k * 0.02
		profile.append(Vector2(0.05, y - 0.004))
		profile.append(Vector2(0.052, y))
		profile.append(Vector2(0.05, y + 0.004))
	profile.append_array(PackedVector2Array([Vector2(0.05, 0.062), Vector2(0.046, 0.066), Vector2(0.002, 0.066)]))
	_mb(p, tin).lathe(profile, 12)
	_mb(p, Color(0.55, 0.2, 0.12) if not hot else Color(0.4, 0.16, 0.1)).lathe(PackedVector2Array([Vector2(0.0535, -0.035), Vector2(0.0535, 0.035)]), 12) # rótulo
	_mb(p, ItemModels.CREAM).box(Vector3(0, 0, 0.054), Vector3(0.04, 0.03, 0.002)) # etiqueta
	_mb(p, tin.darkened(0.2)).torus(0.03, 0.003, 10, 3, Basis.IDENTITY, Vector3(0, 0.067, 0)) # anel de abrir
	if hot:
		_mb(p, Color(0.62, 0.38, 0.2)).lathe(PackedVector2Array([Vector2(0.002, 0.06), Vector2(0.042, 0.06)]), 12) # aberta: comida
		_mb(p, tin).box(Vector3(0.0, 0.1, -0.035), Vector3(0.08, 0.002, 0.07), Basis(Vector3.RIGHT, -1.0)) # tampa dobrada


static func _loaf(p: Dictionary, fresh: bool) -> void:
	var crust := Color(0.78, 0.5, 0.22) if fresh else Color(0.58, 0.4, 0.2)
	var rings := []
	for k in 9:
		var t := lerpf(-1.0, 1.0, k / 8.0)
		var fall := sqrt(maxf(1.0 - t * t, 0.0))
		rings.append(MeshBuilder.ring(Vector3(0, 0.0, t * 0.11), 0.055 * fall + 0.004, 0.045 * fall + 0.004, 2.4, 10, -0.03))
	_mb(p, crust).loft(rings, true, true)
	for k in 3: # cortes na casca
		_mb(p, Color(0.92, 0.78, 0.5) if fresh else Color(0.75, 0.62, 0.4)).box(Vector3(0, 0.044, -0.05 + k * 0.05), Vector3(0.06, 0.006, 0.012), Basis(Vector3.UP, 0.5))
	if not fresh:
		_mb(p, Color(0.35, 0.4, 0.25)).box(Vector3(0.03, 0.03, 0.06), Vector3(0.02, 0.01, 0.02)) # bolor


static func _toast(p: Dictionary) -> void:
	var slice := PackedVector2Array([Vector2(-0.07, -0.05), Vector2(0.07, -0.05), Vector2(0.075, 0.03), Vector2(0.05, 0.06), Vector2(0.0, 0.065), Vector2(-0.05, 0.06), Vector2(-0.075, 0.03)])
	_mb(p, Color(0.42, 0.25, 0.1)).extrude(slice, 0.03, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.015, 0))
	_mb(p, Color(0.7, 0.48, 0.22)).box(Vector3(0, 0.031, 0), Vector3(0.12, 0.002, 0.08)) # miolo tostado


static func _carrot(p: Dictionary, roasted: bool) -> void:
	var orange := Color(0.85, 0.42, 0.1) if not roasted else Color(0.6, 0.27, 0.08)
	var profile := PackedVector2Array([Vector2(0.002, -0.1)])
	for k in 7:
		var t := k / 6.0
		profile.append(Vector2(lerpf(0.008, 0.026, sqrt(t)) + (0.002 if k % 2 == 0 else 0.0), lerpf(-0.09, 0.07, t)))
	profile.append(Vector2(0.002, 0.075))
	_mb(p, orange).lathe(profile, 8, AXIS_Z)
	if roasted:
		_mb(p, Color(0.3, 0.14, 0.05)).box(Vector3(0.0, 0.02, 0.0), Vector3(0.03, 0.008, 0.05)) # tostado
		return
	for k in 4:
		var a := k * 1.6
		_mb(p, Color(0.25, 0.5, 0.18)).tube(PackedVector3Array([Vector3(0, 0, -0.075), Vector3(cos(a) * 0.015, sin(a) * 0.015, -0.13), Vector3(cos(a) * 0.03, sin(a) * 0.03, -0.16)]), 0.004, 4)


static func _potato(p: Dictionary, roasted: bool) -> void:
	var skin := Color(0.6, 0.46, 0.28) if not roasted else Color(0.45, 0.28, 0.13)
	_blob(_mb(p, skin), Vector3.ZERO, Vector3(0.06, 0.045, 0.05), 7, 0.12)
	for e in [Vector3(0.03, 0.03, 0.02), Vector3(-0.035, 0.01, 0.03), Vector3(0.01, -0.02, -0.04)]:
		_mb(p, skin.darkened(0.35)).box(e, Vector3(0.008, 0.006, 0.008)) # olhos
	if roasted:
		_mb(p, Color(0.95, 0.85, 0.5)).box(Vector3(0, 0.045, 0), Vector3(0.05, 0.012, 0.03)) # aberta
		_mb(p, Color(0.98, 0.9, 0.45)).box(Vector3(0, 0.053, 0), Vector3(0.02, 0.006, 0.015)) # manteiga


static func _pumpkin(p: Dictionary, roasted: bool) -> void:
	var color := Color(0.86, 0.45, 0.1) if not roasted else Color(0.66, 0.3, 0.08)
	var rings := []
	for k in 8:
		var lat := lerpf(-PI / 2, PI / 2, k / 7.0)
		var ring := PackedVector3Array()
		for s in 16:
			var lon := TAU * s / 16.0
			var rib := 1.0 - 0.08 * absf(sin(lon * 4.0)) # gomos
			var r := cos(lat) * 0.13 * rib
			ring.append(Vector3(cos(lon) * r, sin(lat) * 0.1, sin(lon) * r))
		rings.append(ring)
	_mb(p, color).loft(rings, true, false, true)
	_mb(p, Color(0.3, 0.42, 0.15)).tube(PackedVector3Array([Vector3(0, 0.09, 0), Vector3(0.01, 0.13, 0), Vector3(0.03, 0.15, 0)]), 0.012, 5)
	if roasted:
		_mb(p, Color(0.95, 0.62, 0.2)).lathe(PackedVector2Array([Vector2(0.002, 0.1), Vector2(0.07, 0.095)]), 10) # tampa aberta: polpa


static func _bandage(p: Dictionary) -> void:
	var spiral := PackedVector2Array([Vector2(0.018, -0.03), Vector2(0.055, -0.03), Vector2(0.057, 0.0), Vector2(0.055, 0.03), Vector2(0.018, 0.03)])
	_mb(p, ItemModels.CREAM).lathe(spiral, 12, AXIS_X)
	for k in 3:
		_mb(p, ItemModels.CREAM.darkened(0.12)).torus(0.04 + k * 0.007, 0.0015, 12, 3, AXIS_X * Basis(Vector3.UP, 0.0), Vector3(0, 0, 0))
	_mb(p, ItemModels.CREAM).box(Vector3(0, -0.05, 0.05), Vector3(0.06, 0.002, 0.09), Basis(Vector3.RIGHT, -0.4)) # ponta solta
	_mb(p, Color(0.7, 0.15, 0.1)).box(Vector3(0.031, 0.03, 0.0), Vector3(0.002, 0.018, 0.018)) # cruz
	_mb(p, Color(0.7, 0.15, 0.1)).box(Vector3(0.031, 0.03, 0.0), Vector3(0.002, 0.006, 0.04))


static func _seeds(p: Dictionary, id: StringName) -> void:
	var color: Color = {&"semente_cenoura": Color(0.85, 0.42, 0.1), &"semente_batata": Color(0.6, 0.46, 0.28),
		&"semente_trigo": Color(0.85, 0.72, 0.35), &"semente_algodao": Color(0.92, 0.92, 0.88)}.get(id, Color(0.86, 0.6, 0.15))
	var burlap := ItemModels.CLOTH.darkened(0.15)
	_mb(p, burlap).lathe(PackedVector2Array([Vector2(0.002, -0.03), Vector2(0.045, -0.03), Vector2(0.056, -0.01), Vector2(0.05, 0.02),
		Vector2(0.025, 0.035), Vector2(0.02, 0.045), Vector2(0.03, 0.06)]), 9)
	_mb(p, ItemModels.LEATHER).torus(0.022, 0.004, 9, 3, Basis.IDENTITY, Vector3(0, 0.04, 0)) # cordão
	_mb(p, ItemModels.LEATHER).tube(PackedVector3Array([Vector3(0.02, 0.04, 0), Vector3(0.05, 0.03, 0.01), Vector3(0.06, 0.0, 0.02)]), 0.003, 3)
	_mb(p, color).lathe(PackedVector2Array([Vector2(0.026, 0.055), Vector2(0.002, 0.062)]), 9) # sementes na boca
	for k in 4: # algumas caídas do lado
		var a := k * 1.7
		_mb(p, color.darkened(0.1)).box(Vector3(cos(a) * 0.07, -0.026, sin(a) * 0.06), Vector3(0.008, 0.005, 0.012), Basis(Vector3.UP, a))
	_mb(p, color).box(Vector3(0, 0.0, 0.052), Vector3(0.03, 0.03, 0.002)) # desenho na frente


static func _wheat(p: Dictionary) -> void:
	for k in 7:
		var a := TAU * k / 7.0
		var lean := Vector3(cos(a), 0, sin(a)) * 0.02
		_mb(p, Color(0.72, 0.62, 0.3)).tube(PackedVector3Array([Vector3(cos(a) * 0.01, 0, sin(a) * 0.01), lean + Vector3(0, 0.25, 0)]), 0.004, 3)
		var head := lean + Vector3(0, 0.3, 0)
		_mb(p, Color(0.88, 0.75, 0.38)).lathe(PackedVector2Array([Vector2(0.002, -0.05), Vector2(0.012, -0.03), Vector2(0.012, 0.02), Vector2(0.002, 0.05)]), 5, Basis.IDENTITY, head)
	_mb(p, Color(0.55, 0.42, 0.22)).torus(0.016, 0.004, 8, 3, Basis.IDENTITY, Vector3(0, 0.12, 0)) # amarra


static func _sack(p: Dictionary, color: Color, top: Color) -> void:
	# anéis no plano XZ subindo em Y
	var list := []
	for s in [[0.0, 0.07, 0.05], [0.04, 0.085, 0.06], [0.12, 0.08, 0.058], [0.17, 0.05, 0.04], [0.19, 0.018, 0.016], [0.215, 0.03, 0.025]]:
		var ring := PackedVector3Array()
		for k in 10:
			var a := TAU * k / 10.0
			ring.append(Vector3(cos(a) * s[1], s[0], sin(a) * s[2]))
		list.append(ring)
	_mb(p, color).loft(list, true, true, true)
	_mb(p, top).lathe(PackedVector2Array([Vector2(0.02, 0.215), Vector2(0.002, 0.225)]), 8)
	_mb(p, ItemModels.LEATHER).torus(0.02, 0.004, 8, 3, Basis.IDENTITY, Vector3(0, 0.19, 0))
	_mb(p, color.darkened(0.2)).box(Vector3(0, 0.08, 0.062), Vector3(0.06, 0.05, 0.002)) # remendo


static func _flat_fish(p: Dictionary, color: Color) -> void:
	var body := PackedVector2Array([Vector2(-0.13, 0.0), Vector2(-0.09, 0.04), Vector2(0.0, 0.05), Vector2(0.08, 0.03), Vector2(0.11, 0.0),
		Vector2(0.08, -0.03), Vector2(0.0, -0.05), Vector2(-0.09, -0.04)])
	_mb(p, color).extrude(body, 0.025, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.012, 0))
	var tail := PackedVector2Array([Vector2(0.1, 0.0), Vector2(0.16, 0.05), Vector2(0.15, 0.0), Vector2(0.16, -0.05)])
	_mb(p, color.darkened(0.15)).extrude(tail, 0.012, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.006, 0))
	for k in 4: # costelas/marcas da grelha
		_mb(p, color.darkened(0.3)).box(Vector3(-0.06 + k * 0.04, 0.026, 0), Vector3(0.006, 0.002, 0.07))
	_mb(p, ItemModels.DARK).box(Vector3(-0.1, 0.026, 0.015), Vector3(0.008, 0.002, 0.008)) # olho
	_mb(p, ItemModels.LEATHER).tube(PackedVector3Array([Vector3(0.14, 0.012, 0), Vector3(0.17, 0.05, 0), Vector3(0.19, 0.03, 0)]), 0.003, 3) # barbante


static func _rotten(p: Dictionary) -> void:
	_blob(_mb(p, Color(0.35, 0.38, 0.2)), Vector3(0, 0.02, 0), Vector3(0.07, 0.035, 0.06), 31, 0.3)
	for k in 6:
		var a := k * 1.1
		_mb(p, [Color(0.55, 0.6, 0.35), Color(0.75, 0.75, 0.6), Color(0.25, 0.28, 0.12)][k % 3]).box(
			Vector3(cos(a) * 0.035, 0.05, sin(a) * 0.03), Vector3(0.018, 0.008, 0.015))
	for k in 3: # mosquinhas
		_mb(p, ItemModels.DARK).box(Vector3(-0.03 + k * 0.03, 0.1 + k * 0.015, 0.01), Vector3(0.006, 0.004, 0.006))


# --- materiais ------------------------------------------------------------------

static func _plank(p: Dictionary) -> void:
	_mb(p, ItemModels.WOOD).box(Vector3.ZERO, Vector3(0.12, 0.025, 0.6))
	for k in 4: # veios
		_mb(p, ItemModels.WOOD.darkened(0.2)).box(Vector3(-0.04 + k * 0.027, 0.0128, -0.02 + k * 0.05), Vector3(0.004, 0.001, 0.4 - k * 0.06))
	_mb(p, ItemModels.DARK_WOOD).lathe(PackedVector2Array([Vector2(0.002, 0.0128), Vector2(0.014, 0.0128)]), 6, Basis.IDENTITY, Vector3(0.02, 0, 0.12)) # nó
	_mb(p, ItemModels.IRON).box(Vector3(0, 0.014, 0.25), Vector3(0.012, 0.006, 0.012))
	_mb(p, ItemModels.IRON).box(Vector3(0.03, 0.014, -0.26), Vector3(0.01, 0.005, 0.01))
	_mb(p, ItemModels.WOOD.lightened(0.15)).box(Vector3(0, 0, 0.301), Vector3(0.12, 0.025, 0.002)) # corte claro


static func _log(p: Dictionary) -> void:
	var bark := Color(0.32, 0.22, 0.13)
	var rings := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 7:
		var z := lerpf(0.55, -0.55, k / 6.0)
		var ring := PackedVector3Array()
		for s in 10:
			var a := TAU * s / 10.0
			var r := 0.145 + rng.randf_range(-0.012, 0.012) + (0.01 if s % 2 == 0 else 0.0) # casca rugosa
			ring.append(Vector3(cos(a) * r, sin(a) * r, z))
		rings.append(ring)
	_mb(p, bark).loft(rings, true, true)
	for z in [0.556, -0.556]:
		_mb(p, Color(0.62, 0.48, 0.3)).lathe(PackedVector2Array([Vector2(0.002, 0), Vector2(0.135, 0)]), 10, AXIS_Z, Vector3(0, 0, z))
		for r in [0.04, 0.08, 0.115]:
			_mb(p, Color(0.5, 0.36, 0.2)).torus(r, 0.003, 12, 3, AXIS_Z, Vector3(0, 0, z * 1.003))
	_mb(p, bark).tube(PackedVector3Array([Vector3(0.13, 0.04, 0.1), Vector3(0.2, 0.08, 0.14)]), 0.025, 6) # toco de galho


static func _stick(p: Dictionary) -> void:
	var wood := Color(0.42, 0.3, 0.18)
	_mb(p, wood).tube(PackedVector3Array([Vector3(0, 0, 0.25), Vector3(0.012, 0.004, 0.08), Vector3(-0.008, 0.0, -0.1), Vector3(0.004, 0.0, -0.25)]), 0.015, 6)
	_mb(p, wood).tube(PackedVector3Array([Vector3(0.006, 0, 0.05), Vector3(0.05, 0.005, -0.03), Vector3(0.08, 0.01, -0.07)]), 0.008, 5)
	_mb(p, wood.lightened(0.3)).box(Vector3(0.004, 0.0, -0.252), Vector3(0.026, 0.026, 0.004)) # ponta quebrada
	for z in [0.15, -0.05, -0.18]:
		_mb(p, wood.darkened(0.3)).box(Vector3(0.0, 0.014, z), Vector3(0.012, 0.004, 0.02)) # casca


static func _stone(p: Dictionary, color: Color, seed: int, veins: Array) -> void:
	_blob(_mb(p, color), Vector3(0, 0.0, 0), Vector3(0.07, 0.05, 0.06), seed, 0.22, 7, 5)
	_mb(p, color.lightened(0.12)).box(Vector3(0.02, 0.04, -0.01), Vector3(0.04, 0.012, 0.035), Basis(Vector3(0.3, 1, 0).normalized(), 0.4)) # face lascada
	for k in veins.size() * 2:
		var a := k * 2.3
		_mb(p, veins[k % veins.size()]).box(Vector3(cos(a) * 0.045, 0.02 + (k % 2) * 0.015, sin(a) * 0.04), Vector3(0.03, 0.02, 0.02), Basis(Vector3.UP, a))


static func _coal(p: Dictionary) -> void:
	var black := Color(0.09, 0.08, 0.08)
	_blob(_mb(p, black), Vector3(-0.02, 0, 0), Vector3(0.05, 0.04, 0.045), 13, 0.28, 6, 4)
	_blob(_mb(p, black), Vector3(0.04, -0.01, 0.02), Vector3(0.032, 0.028, 0.03), 17, 0.3, 6, 4)
	_mb(p, Color(0.22, 0.22, 0.24)).box(Vector3(-0.02, 0.035, 0.0), Vector3(0.025, 0.006, 0.02)) # brilho fosco


static func _ingot(p: Dictionary, color: Color) -> void:
	# Lingote trapezoidal (base larga, topo estreito) feito de quads com a ordem
	# certa dos vértices: todas as faces viradas para fora.
	var mb := _mb(p, color)
	var bw := 0.05
	var tw := 0.038
	var bl := 0.14
	var tl := 0.125
	var h := 0.045
	var y0 := -0.022
	var b0 := Vector3(-bw, y0, -bl)
	var b1 := Vector3(bw, y0, -bl)
	var b2 := Vector3(bw, y0, bl)
	var b3 := Vector3(-bw, y0, bl)
	var t0 := Vector3(-tw, y0 + h, -tl)
	var t1 := Vector3(tw, y0 + h, -tl)
	var t2 := Vector3(tw, y0 + h, tl)
	var t3 := Vector3(-tw, y0 + h, tl)
	mb.quad(t0, t1, t2, t3) # topo
	mb.quad(b0, b3, b2, b1) # fundo
	mb.quad(b0, b1, t1, t0) # frente (-Z)
	mb.quad(b2, b3, t3, t2) # trás (+Z)
	mb.quad(b1, b2, t2, t1) # lado +X
	mb.quad(b3, b0, t0, t3) # lado -X
	_mb(p, color.darkened(0.25)).box(Vector3(0, y0 + h + 0.001, 0), Vector3(0.03, 0.002, 0.06)) # marca de fundição
	_mb(p, color.lightened(0.12)).box(Vector3(0, y0 + h + 0.0015, 0.08), Vector3(0.05, 0.001, 0.04))


static func _glass(p: Dictionary) -> void:
	_mb(p, Color(0.62, 0.78, 0.8)).box(Vector3.ZERO, Vector3(0.24, 0.012, 0.24))
	_mb(p, Color(0.75, 0.88, 0.9)).box(Vector3(-0.05, 0.007, -0.04), Vector3(0.08, 0.001, 0.015), Basis(Vector3.UP, 0.7)) # reflexo
	_mb(p, Color(0.5, 0.65, 0.68)).box(Vector3(0.11, 0.0, 0.0), Vector3(0.02, 0.014, 0.24)) # borda grossa
	_mb(p, Color(0.5, 0.65, 0.68)).box(Vector3(0.0, 0.0, 0.11), Vector3(0.24, 0.014, 0.02))


static func _scrap(p: Dictionary) -> void:
	ItemModels._gear(_mb(p, ItemModels.IRON), Vector3(-0.045, 0.0, 0.0), 0.075, 0.058, 10, Basis(Vector3(1, 0, 0), PI / 2), 0.018)
	_mb(p, ItemModels.IRON.darkened(0.3)).lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.018, 0.0)]), 8, Basis.IDENTITY, Vector3(-0.045, 0.011, 0.0))
	_mb(p, ItemModels.COPPER).tube(PackedVector3Array([Vector3(0.02, 0.01, -0.08), Vector3(0.07, 0.02, -0.02), Vector3(0.06, 0.02, 0.06), Vector3(0.12, 0.015, 0.08)]), 0.012, 6)
	_mb(p, ItemModels.BRASS).box(Vector3(0.05, 0.0, 0.0), Vector3(0.06, 0.02, 0.04), Basis(Vector3(0, 1, 0), 0.6))
	# Parafuso com porca e uma chapa torta furada.
	_mb(p, ItemModels.STEEL).lathe(PackedVector2Array([Vector2(0.008, 0.0), Vector2(0.008, 0.07)]), 6, Basis(Vector3.BACK, PI / 2), Vector3(0.0, 0.015, 0.07))
	_mb(p, ItemModels.STEEL.darkened(0.2)).lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.016, 0.0), Vector2(0.016, 0.012), Vector2(0.002, 0.012)]), 6, Basis(Vector3.BACK, PI / 2), Vector3(0.0, 0.015, 0.07))
	_mb(p, Color(0.45, 0.32, 0.25)).box(Vector3(-0.04, 0.02, 0.07), Vector3(0.08, 0.006, 0.05), Basis(Vector3.RIGHT, 0.3) * Basis(Vector3.UP, -0.4)) # chapa enferrujada


static func _cloth_stack(p: Dictionary) -> void:
	for k in 3:
		var color: Color = [ItemModels.CLOTH, ItemModels.CLOTH.darkened(0.12), Color(0.55, 0.45, 0.38)][k]
		var grid := []
		for r in 4:
			var row := PackedVector3Array()
			for c in 5:
				row.append(Vector3(lerpf(-0.13, 0.13, c / 4.0) + k * 0.01, 0.01 + k * 0.018 + sin(c * 1.9 + r + k) * 0.004, lerpf(-0.1, 0.1, r / 3.0) - k * 0.008))
			grid.append(row)
		_mb(p, color).sheet(grid)
		_mb(p, color.darkened(0.1)).tube(PackedVector3Array([Vector3(0.13 + k * 0.01, 0.012 + k * 0.018, -0.1 - k * 0.008), Vector3(0.135 + k * 0.01, 0.014 + k * 0.018, 0.1 - k * 0.008)]), 0.009, 4) # dobra
	_mb(p, ItemModels.LEATHER).box(Vector3(0, 0.05, 0), Vector3(0.012, 0.004, 0.22)) # cordão


static func _clay(p: Dictionary) -> void:
	var clay := Color(0.62, 0.45, 0.35)
	_blob(_mb(p, clay), Vector3(0, 0.0, 0), Vector3(0.08, 0.045, 0.065), 23, 0.12)
	for k in 3: # marcas de dedo
		_mb(p, clay.darkened(0.2)).box(Vector3(-0.03 + k * 0.03, 0.04, 0.0), Vector3(0.012, 0.004, 0.05), Basis(Vector3.UP, 0.2))


static func _sand(p: Dictionary) -> void:
	_mb(p, Color(0.82, 0.72, 0.5)).lathe(PackedVector2Array([Vector2(0.002, -0.03), Vector2(0.08, -0.03), Vector2(0.07, -0.01), Vector2(0.04, 0.02), Vector2(0.002, 0.035)]), 10)
	for k in 6: # grãos/pedrinhas
		var a := k * 1.05
		_mb(p, Color(0.7, 0.6, 0.42)).box(Vector3(cos(a) * 0.05, -0.012, sin(a) * 0.05), Vector3(0.008, 0.006, 0.008))


static func _brick(p: Dictionary) -> void:
	var red := Color(0.66, 0.3, 0.2)
	_mb(p, red).box(Vector3.ZERO, Vector3(0.22, 0.07, 0.11))
	_mb(p, red.darkened(0.25)).box(Vector3(0, 0.036, 0), Vector3(0.12, 0.002, 0.05)) # rebaixo
	_mb(p, red.lightened(0.1)).box(Vector3(0.07, 0.0, 0.0556), Vector3(0.05, 0.03, 0.001)) # lasca
	_mb(p, red.darkened(0.15)).box(Vector3(-0.111, 0.0, 0.0), Vector3(0.002, 0.07, 0.11))


static func _cotton(p: Dictionary) -> void:
	_mb(p, Color(0.4, 0.3, 0.18)).lathe(PackedVector2Array([Vector2(0.002, -0.02), Vector2(0.03, -0.015), Vector2(0.035, 0.0)]), 5) # cápsula
	for k in 5:
		var a := TAU * k / 5.0
		ItemModels._ball(_mb(p, Color(0.95, 0.94, 0.9)), Vector3(cos(a) * 0.028, 0.03, sin(a) * 0.028), 0.03, 7)
	ItemModels._ball(_mb(p, Color(0.98, 0.97, 0.94)), Vector3(0, 0.05, 0), 0.03, 7)


static func _spool(p: Dictionary) -> void:
	var wood := Color(0.45, 0.3, 0.18)
	_mb(p, wood).lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.055, 0.0), Vector2(0.055, 0.012), Vector2(0.02, 0.014)]), 10)
	_mb(p, wood).lathe(PackedVector2Array([Vector2(0.02, 0.096), Vector2(0.055, 0.098), Vector2(0.055, 0.11), Vector2(0.002, 0.11)]), 10)
	_mb(p, Color(0.85, 0.82, 0.74)).lathe(PackedVector2Array([Vector2(0.046, 0.014), Vector2(0.048, 0.055), Vector2(0.046, 0.096)]), 12)
	for k in 5:
		_mb(p, Color(0.75, 0.72, 0.64)).torus(0.0475, 0.0015, 12, 3, Basis(Vector3.RIGHT, 0.05), Vector3(0, 0.02 + k * 0.017, 0))
	_mb(p, Color(0.85, 0.82, 0.74)).tube(PackedVector3Array([Vector3(0.047, 0.06, 0), Vector3(0.07, 0.03, 0.02), Vector3(0.08, 0.0, 0.03)]), 0.002, 3) # ponta solta


static func _bolt(p: Dictionary) -> void:
	var cloth := Color(0.68, 0.62, 0.5)
	var side := Basis(Vector3.BACK, PI / 2) # eixo do rolo deitado em X
	_mb(p, cloth).lathe(PackedVector2Array([Vector2(0.002, -0.12), Vector2(0.04, -0.12), Vector2(0.04, 0.12), Vector2(0.002, 0.12)]), 10, side)
	_mb(p, cloth.darkened(0.12)).torus(0.042, 0.003, 10, 3, side, Vector3(0.06, 0, 0))
	_mb(p, cloth.darkened(0.12)).torus(0.042, 0.003, 10, 3, side, Vector3(-0.06, 0, 0))
	var grid := []
	for r in 3:
		var row := PackedVector3Array()
		for c in 5:
			row.append(Vector3(lerpf(-0.12, 0.12, c / 4.0), -0.04 + r * 0.002, 0.04 + r * 0.05))
		grid.append(row)
	_mb(p, cloth).sheet(grid) # pano desenrolado


static func _bottle(p: Dictionary, id: StringName) -> void:
	# O vidro do corpo toma a cor do que tem dentro (vazia: vidro claro).
	var glass := Color(0.62, 0.72, 0.68)
	var body: Color = {&"agua": Color(0.55, 0.78, 0.95), &"agua_suja": Color(0.4, 0.42, 0.24), &"suco": Color(0.95, 0.55, 0.15),
		&"oleo": Color(0.78, 0.62, 0.18), &"alcool": Color(0.82, 0.9, 0.95), &"leite": Color(0.96, 0.95, 0.9)}.get(id, glass)
	_mb(p, body).lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.04, 0.0), Vector2(0.046, 0.01), Vector2(0.046, 0.16),
		Vector2(0.032, 0.2)]), 10)
	_mb(p, glass).lathe(PackedVector2Array([Vector2(0.032, 0.2), Vector2(0.02, 0.215), Vector2(0.018, 0.26), Vector2(0.022, 0.265), Vector2(0.002, 0.268)]), 10)
	if id == &"agua_suja":
		_mb(p, Color(0.3, 0.28, 0.16)).lathe(PackedVector2Array([Vector2(0.002, 0.003), Vector2(0.044, 0.003), Vector2(0.046, 0.03)]), 10) # sujeira no fundo
	if id != &"garrafa":
		_mb(p, body.lightened(0.2)).lathe(PackedVector2Array([Vector2(0.0462, 0.13), Vector2(0.0462, 0.14)]), 10) # nível da água
	_mb(p, Color(0.5, 0.36, 0.2)).lathe(PackedVector2Array([Vector2(0.017, 0.255), Vector2(0.019, 0.29), Vector2(0.002, 0.292)]), 8) # rolha
	_mb(p, ItemModels.CREAM.darkened(0.1)).lathe(PackedVector2Array([Vector2(0.0465, 0.06), Vector2(0.0465, 0.11)]), 10) # rótulo
	_mb(p, ItemModels.LEATHER).torus(0.021, 0.003, 8, 3, Basis.IDENTITY, Vector3(0, 0.22, 0)) # barbante no gargalo


# --- roupas ---------------------------------------------------------------------

static func _hood(p: Dictionary) -> void:
	var cloth := ItemModels.CLOTH.darkened(0.2)
	_mb(p, cloth).lathe(PackedVector2Array([Vector2(0.13, 0.0), Vector2(0.14, 0.08), Vector2(0.125, 0.17), Vector2(0.08, 0.23), Vector2(0.03, 0.26), Vector2(0.002, 0.265)]), 10)
	_mb(p, ItemModels.DARK).box(Vector3(0, 0.1, 0.12), Vector3(0.14, 0.14, 0.04)) # abertura do rosto
	_mb(p, cloth.darkened(0.15)).torus(0.11, 0.012, 10, 4, Basis(Vector3.RIGHT, 0.5), Vector3(0, 0.1, 0.08)) # bainha
	_mb(p, cloth).box(Vector3(0, -0.02, -0.05), Vector3(0.3, 0.04, 0.2)) # gola caindo nos ombros
	_mb(p, ItemModels.LEATHER).box(Vector3(0.05, 0.04, 0.13), Vector3(0.006, 0.08, 0.006)) # cordão


static func _helmet(p: Dictionary) -> void:
	var iron := ItemModels.IRON.lightened(0.2)
	_mb(p, iron).lathe(PackedVector2Array([Vector2(0.15, 0.0), Vector2(0.145, 0.06), Vector2(0.13, 0.13), Vector2(0.09, 0.19), Vector2(0.04, 0.215), Vector2(0.002, 0.22)]), 12)
	_mb(p, iron.darkened(0.15)).torus(0.15, 0.01, 12, 4, Basis.IDENTITY, Vector3(0, 0.005, 0)) # aba
	_mb(p, iron.lightened(0.1)).box(Vector3(0, 0.12, 0.0), Vector3(0.02, 0.2, 0.3), Basis.IDENTITY) # crista
	_mb(p, iron).box(Vector3(0, 0.03, 0.15), Vector3(0.03, 0.12, 0.012)) # protetor de nariz
	for k in 8:
		var a := TAU * k / 8.0
		_rivet(p, Vector3(cos(a) * 0.145, 0.04, sin(a) * 0.145), ItemModels.BRASS)
	_mb(p, ItemModels.LEATHER).box(Vector3(0, -0.05, 0.0), Vector3(0.02, 0.1, 0.26)) # jugular


static func _vest(p: Dictionary, iron: bool) -> void:
	var plate: Color = ItemModels.IRON.lightened(0.2) if iron else Color(0.45, 0.4, 0.33)
	var rings := []
	for s in [[0.0, 0.2, 0.08], [0.2, 0.22, 0.09], [0.4, 0.2, 0.085], [0.5, 0.17, 0.07]]:
		var ring := PackedVector3Array()
		for k in 12:
			var a := TAU * k / 12.0
			ring.append(Vector3(cos(a) * s[1], s[0], sin(a) * s[2]))
		rings.append(ring)
	_mb(p, plate).loft(rings, true, false, true)
	if iron:
		for y in [0.12, 0.24, 0.36]:
			_mb(p, plate.lightened(0.12)).box(Vector3(0, y, 0.09), Vector3(0.36, 0.015, 0.012)) # placas sobrepostas
		_mb(p, plate.darkened(0.2)).box(Vector3(0, 0.27, 0.095), Vector3(0.02, 0.4, 0.01)) # quilha
	else:
		for k in 5: # chapas de sucata rebitadas
			var at := Vector3(-0.12 + (k % 3) * 0.12, 0.12 + (k / 3) * 0.18, 0.088)
			_mb(p, [Color(0.5, 0.42, 0.32), Color(0.4, 0.38, 0.35), Color(0.55, 0.35, 0.25)][k % 3]).box(at, Vector3(0.1, 0.12, 0.01), Basis(Vector3.BACK, (k - 2) * 0.08))
			_rivet(p, at + Vector3(0.04, 0.05, 0.006))
			_rivet(p, at + Vector3(-0.04, -0.05, 0.006))
	for side in [-1.0, 1.0]:
		_mb(p, ItemModels.LEATHER).box(Vector3(side * 0.12, 0.52, 0.0), Vector3(0.06, 0.04, 0.18)) # alça do ombro
		_mb(p, ItemModels.BRASS).box(Vector3(side * 0.21, 0.25, 0.0), Vector3(0.012, 0.02, 0.03)) # fivela lateral
	_mb(p, ItemModels.LEATHER).lathe(PackedVector2Array([Vector2(0.205, 0.04), Vector2(0.205, 0.07)]), 12) # cinto


static func _pants(p: Dictionary) -> void:
	var denim := Color(0.3, 0.32, 0.38)
	for side in [-1.0, 1.0]:
		var rings := []
		for s in [[0.0, 0.065], [0.3, 0.075], [0.55, 0.085]]:
			var ring := PackedVector3Array()
			for k in 8:
				var a := TAU * k / 8.0
				ring.append(Vector3(side * 0.09 + cos(a) * s[1], s[0], sin(a) * s[1] * 0.95))
			rings.append(ring)
		_mb(p, denim).loft(rings, true, false, true)
		_mb(p, Color(0.45, 0.4, 0.33)).box(Vector3(side * 0.09, 0.3, 0.075), Vector3(0.1, 0.1, 0.012)) # joelheira de remendo
		_mb(p, denim.darkened(0.2)).box(Vector3(side * 0.09, 0.02, 0.0), Vector3(0.14, 0.03, 0.14)) # barra
	_mb(p, denim).box(Vector3(0, 0.6, 0), Vector3(0.36, 0.1, 0.17))
	_mb(p, ItemModels.LEATHER).box(Vector3(0, 0.64, 0), Vector3(0.37, 0.03, 0.18)) # cinto
	_mb(p, ItemModels.BRASS).box(Vector3(0, 0.64, 0.092), Vector3(0.04, 0.03, 0.006)) # fivela


static func _boots(p: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 0.08
		_mb(p, ItemModels.LEATHER).lathe(PackedVector2Array([Vector2(0.05, 0.03), Vector2(0.055, 0.1), Vector2(0.06, 0.18)]), 8, Basis.IDENTITY, Vector3(x, 0, 0.02))
		var foot := []
		for s in [[0.06, 0.05, 0.045], [-0.04, 0.05, 0.04], [-0.12, 0.04, 0.03]]:
			foot.append(MeshBuilder.ring(Vector3(x, 0.035, s[0]), s[1], s[2], 2.5, 8, 0.0))
		_mb(p, ItemModels.LEATHER).loft(foot, true, true)
		_mb(p, ItemModels.DARK).box(Vector3(x, 0.008, -0.02), Vector3(0.11, 0.016, 0.22)) # sola
		_mb(p, ItemModels.DARK).box(Vector3(x, 0.02, 0.06), Vector3(0.1, 0.02, 0.05)) # salto
		for k in 3: # cadarço
			_mb(p, ItemModels.CREAM.darkened(0.2)).box(Vector3(x, 0.08 + k * 0.03, -0.02 - k * 0.004), Vector3(0.05, 0.005, 0.005))
		_mb(p, ItemModels.LEATHER.darkened(0.2)).torus(0.06, 0.006, 8, 3, Basis.IDENTITY, Vector3(x, 0.18, 0.02)) # borda


static func _coat(p: Dictionary) -> void:
	var coat := Color(0.5, 0.38, 0.26)
	var rings := []
	for s in [[0.0, 0.23, 0.11], [0.25, 0.22, 0.1], [0.45, 0.2, 0.095], [0.52, 0.16, 0.08]]:
		var ring := PackedVector3Array()
		for k in 12:
			var a := TAU * k / 12.0
			ring.append(Vector3(cos(a) * s[1], s[0], sin(a) * s[2]))
		rings.append(ring)
	_mb(p, coat).loft(rings, true, false, true)
	for side in [-1.0, 1.0]:
		_mb(p, coat.darkened(0.1)).tube(PackedVector3Array([Vector3(side * 0.19, 0.46, 0), Vector3(side * 0.27, 0.32, 0.01), Vector3(side * 0.29, 0.1, 0.02)]), 0.055, 7) # manga
		_mb(p, Color(0.85, 0.82, 0.72)).torus(0.05, 0.012, 8, 3, Basis.IDENTITY, Vector3(side * 0.29, 0.09, 0.02)) # punho forrado
		_mb(p, coat.darkened(0.2)).box(Vector3(side * 0.1, 0.15, 0.11), Vector3(0.09, 0.08, 0.01)) # bolso
	_mb(p, Color(0.85, 0.82, 0.72)).torus(0.12, 0.03, 12, 4, Basis.IDENTITY, Vector3(0, 0.52, 0)) # gola de lã
	for k in 4:
		_mb(p, ItemModels.DARK_WOOD).box(Vector3(0.02, 0.1 + k * 0.1, 0.112), Vector3(0.02, 0.02, 0.008)) # botões de madeira
	_mb(p, coat.darkened(0.25)).box(Vector3(0, 0.25, 0.111), Vector3(0.006, 0.48, 0.004)) # abertura


# --- Tier 3: peças de metal --------------------------------------------------------

static func _bolts(p: Dictionary) -> void:
	# Punhado de parafusos: cabeça sextavada, rosca em anéis.
	var steel := Color(0.44, 0.45, 0.48)
	for k in 4:
		var at := Vector3(cos(k * 1.7) * 0.025, 0.0, sin(k * 1.7) * 0.025)
		var lay := Basis(Vector3.UP, k * 1.1) * Basis(Vector3.BACK, PI / 2)
		_mb(p, steel.darkened(0.1)).lathe(PackedVector2Array([Vector2(0.002, -0.01), Vector2(0.014, -0.01), Vector2(0.014, 0.0), Vector2(0.002, 0.0)]), 6, lay, at) # cabeça
		_mb(p, steel).lathe(PackedVector2Array([Vector2(0.006, 0.0), Vector2(0.006, 0.05), Vector2(0.002, 0.055)]), 6, lay, at)
		for r in 3:
			_mb(p, steel.lightened(0.15)).lathe(PackedVector2Array([Vector2(0.0062, 0.015 + r * 0.012), Vector2(0.0072, 0.02 + r * 0.012), Vector2(0.0062, 0.025 + r * 0.012)]), 6, lay, at)


static func _gear(p: Dictionary) -> void:
	# Engrenagem de ferro: disco com furos de alívio, cubo e 14 dentes.
	var iron := ItemModels.IRON.lightened(0.25)
	_mb(p, iron).lathe(PackedVector2Array([Vector2(0.02, -0.012), Vector2(0.075, -0.012), Vector2(0.075, 0.012), Vector2(0.02, 0.012)]), 14)
	_mb(p, iron.darkened(0.15)).lathe(PackedVector2Array([Vector2(0.008, -0.02), Vector2(0.024, -0.02), Vector2(0.024, 0.02), Vector2(0.008, 0.02)]), 8) # cubo
	for k in 14:
		var a := TAU * k / 14.0
		_mb(p, iron).box(Vector3(cos(a) * 0.083, 0.0, sin(a) * 0.083), Vector3(0.018, 0.022, 0.014), Basis(Vector3.UP, -a))
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		_mb(p, ItemModels.DARK).box(Vector3(cos(a) * 0.048, 0.0, sin(a) * 0.048), Vector3(0.018, 0.026, 0.018), Basis(Vector3.UP, -a)) # furos


static func _steel_shaft(p: Dictionary) -> void:
	# Eixo de aço torneado com colares, chaveta e pontas chanfradas (deitado em Z).
	var steel := Color(0.48, 0.5, 0.54)
	_mb(p, steel).lathe(PackedVector2Array([Vector2(0.002, -0.22), Vector2(0.016, -0.22), Vector2(0.02, -0.21), Vector2(0.02, 0.21), Vector2(0.016, 0.22), Vector2(0.002, 0.22)]), 8, AXIS_Z)
	for z in [-0.12, 0.08]:
		_mb(p, steel.darkened(0.15)).lathe(PackedVector2Array([Vector2(0.02, z), Vector2(0.028, z), Vector2(0.028, z + 0.025), Vector2(0.02, z + 0.025)]), 8, AXIS_Z)
	_mb(p, ItemModels.DARK).box(Vector3(0, 0.02, 0.17), Vector3(0.006, 0.004, 0.05)) # rasgo da chaveta


static func _pipe_piece(p: Dictionary) -> void:
	# Pedaço de cano de cobre com flange numa ponta e luva na outra (deitado em Z).
	var copper := ItemModels.COPPER.lightened(0.1)
	_mb(p, copper).lathe(PackedVector2Array([Vector2(0.024, -0.19), Vector2(0.024, 0.19)]), 8, AXIS_Z)
	_mb(p, copper.darkened(0.25)).lathe(PackedVector2Array([Vector2(0.016, -0.19), Vector2(0.016, 0.19)]), 8, AXIS_Z) # boca escura por dentro
	_mb(p, ItemModels.BRASS).lathe(PackedVector2Array([Vector2(0.016, -0.2), Vector2(0.04, -0.2), Vector2(0.04, -0.18), Vector2(0.024, -0.18)]), 8, AXIS_Z) # flange
	_mb(p, copper.darkened(0.1)).lathe(PackedVector2Array([Vector2(0.024, 0.15), Vector2(0.03, 0.15), Vector2(0.03, 0.2), Vector2(0.016, 0.2)]), 8, AXIS_Z) # luva


# --- carnes, couro e pele -------------------------------------------------------------

## Bife com osso: peça grossa de contorno irregular, capa de gordura na borda,
## marmoreio, osso redondo saindo; assada = tostada com marcas de grelha.
static func _steak(p: Dictionary, cooked: bool) -> void:
	var meat := Color(0.5, 0.26, 0.12) if cooked else Color(0.72, 0.2, 0.18)
	var outline := PackedVector2Array([Vector2(-0.09, -0.045), Vector2(-0.02, -0.06), Vector2(0.06, -0.055), Vector2(0.095, -0.01),
		Vector2(0.08, 0.05), Vector2(0.0, 0.065), Vector2(-0.07, 0.05), Vector2(-0.1, 0.0)])
	_mb(p, meat).extrude(outline, 0.045, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.0225, 0))
	_mb(p, meat.darkened(0.25)).extrude(outline, 0.004, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.047, 0)) # casquinha de cima
	var fat := Color(0.85, 0.72, 0.5) if cooked else Color(0.95, 0.9, 0.8)
	for k in 4:
		var a := -0.5 + k * 0.45
		_mb(p, fat).box(Vector3(cos(a) * 0.095, 0.022, sin(a) * 0.058), Vector3(0.035, 0.044, 0.014), Basis(Vector3.UP, -a - PI / 2)) # capa de gordura
	for k in 5:
		_mb(p, fat.darkened(0.05)).box(Vector3(-0.05 + k * 0.025, 0.049, sin(k * 1.9) * 0.025), Vector3(0.03, 0.003, 0.004), Basis(Vector3.UP, k)) # marmoreio
	_mb(p, Color(0.92, 0.9, 0.82)).lathe(PackedVector2Array([Vector2(0.012, -0.03), Vector2(0.01, 0.0), Vector2(0.014, 0.03), Vector2(0.018, 0.04), Vector2(0.002, 0.045)]), 6, Basis(Vector3.BACK, -PI / 2), Vector3(0.09, 0.022, 0.0)) # osso
	if cooked:
		for k in 3:
			_mb(p, Color(0.2, 0.1, 0.05)).box(Vector3(-0.04 + k * 0.04, 0.05, 0.0), Vector3(0.008, 0.002, 0.1), Basis(Vector3.UP, 0.6)) # marcas da grelha


## Charque: tiras secas e torcidas amarradas com barbante.
static func _jerky(p: Dictionary) -> void:
	var dry := Color(0.42, 0.18, 0.12)
	for k in 4:
		var twist := Basis(Vector3.UP, (k - 1.5) * 0.12) * Basis(Vector3.RIGHT, sin(k * 1.7) * 0.15)
		_mb(p, dry.darkened(0.08 * (k % 2))).box(Vector3(0, 0.012 + (k % 2) * 0.012, -0.045 + k * 0.03), Vector3(0.19, 0.012, 0.028), twist)
		_mb(p, dry.lightened(0.15)).box(Vector3(-0.03, 0.019 + (k % 2) * 0.012, -0.045 + k * 0.03), Vector3(0.06, 0.002, 0.01), twist) # fibra
	_mb(p, Color(0.85, 0.8, 0.65)).torus(0.045, 0.004, 10, 3, Basis(Vector3.BACK, PI / 2), Vector3(0.0, 0.02, 0.0)) # barbante
	for k in 6:
		_mb(p, Color(0.95, 0.95, 0.92)).box(Vector3(-0.07 + k * 0.03, 0.034, sin(k) * 0.03), Vector3(0.006, 0.004, 0.006)) # sal grosso


## Pele crua: couro com contorno de bicho (patas e rabo), pelo em tufos por cima.
static func _fur_hide(p: Dictionary) -> void:
	var skin := Color(0.62, 0.48, 0.34)
	var fur := Color(0.45, 0.32, 0.2)
	var outline := PackedVector2Array([Vector2(-0.15, -0.04), Vector2(-0.12, -0.12), Vector2(-0.06, -0.08), Vector2(0.06, -0.08), Vector2(0.12, -0.12),
		Vector2(0.15, -0.04), Vector2(0.14, 0.05), Vector2(0.12, 0.12), Vector2(0.05, 0.08), Vector2(0.0, 0.13), Vector2(-0.05, 0.08),
		Vector2(-0.12, 0.12), Vector2(-0.14, 0.05)])
	_mb(p, skin).extrude(outline, 0.008, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.004, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 18:
		var at := Vector3(rng.randf_range(-0.11, 0.11), 0.012, rng.randf_range(-0.07, 0.08))
		_mb(p, fur.darkened(rng.randf_range(0.0, 0.2))).box(at, Vector3(0.035, 0.012, 0.025), Basis(Vector3.UP, rng.randf() * TAU)) # tufos
	_mb(p, fur.darkened(0.3)).box(Vector3(0, 0.014, 0.0), Vector3(0.02, 0.006, 0.16)) # listra do lombo


## Couro: rolo de couro curtido amarrado com tira, borda costurada aparecendo.
static func _leather_roll(p: Dictionary) -> void:
	var leather := Color(0.42, 0.26, 0.15)
	_mb(p, leather).lathe(PackedVector2Array([Vector2(0.002, -0.13), Vector2(0.045, -0.13), Vector2(0.05, -0.12), Vector2(0.05, 0.12), Vector2(0.045, 0.13), Vector2(0.002, 0.13)]), 10, Basis(Vector3.BACK, PI / 2), Vector3(0, 0.05, 0))
	_mb(p, leather.darkened(0.3)).lathe(PackedVector2Array([Vector2(0.02, 0.131), Vector2(0.035, 0.131)]), 10, Basis(Vector3.BACK, PI / 2), Vector3(0, 0.05, 0)) # espiral na ponta
	_mb(p, leather.lightened(0.08)).box(Vector3(0, 0.002, 0.07), Vector3(0.26, 0.004, 0.06)) # aba desenrolada
	for k in 9:
		_mb(p, Color(0.85, 0.78, 0.6)).box(Vector3(-0.12 + k * 0.03, 0.005, 0.098), Vector3(0.012, 0.002, 0.003)) # costura
	for x in [-0.07, 0.07]:
		_mb(p, leather.darkened(0.45)).torus(0.052, 0.006, 10, 3, Basis(Vector3.BACK, PI / 2), Vector3(x, 0.05, 0)) # tiras


## Gordura: banha num potinho de barro com pano amarrado na boca.
static func _lard(p: Dictionary) -> void:
	var clay := Color(0.6, 0.36, 0.22)
	_mb(p, clay).lathe(PackedVector2Array([Vector2(0.002, -0.04), Vector2(0.045, -0.04), Vector2(0.058, -0.01), Vector2(0.056, 0.025), Vector2(0.045, 0.035), Vector2(0.05, 0.042)]), 10)
	_mb(p, Color(0.95, 0.92, 0.8)).lathe(PackedVector2Array([Vector2(0.002, 0.045), Vector2(0.04, 0.042), Vector2(0.046, 0.036)]), 10) # banha aparecendo
	_mb(p, Color(0.8, 0.74, 0.6)).lathe(PackedVector2Array([Vector2(0.05, 0.035), Vector2(0.06, 0.03), Vector2(0.058, 0.0)]), 10) # pano
	_mb(p, Color(0.5, 0.36, 0.2)).torus(0.052, 0.004, 10, 3, Basis.IDENTITY, Vector3(0, 0.03, 0)) # barbante


## Casaco de pele: corpo afinando na cintura, mangas torneadas, gola e punhos de
## pelo claro, frente aberta com botões de osso e cinto.
static func _fur_coat(p: Dictionary) -> void:
	var hide := Color(0.48, 0.34, 0.22)
	var fur := Color(0.88, 0.82, 0.7)
	var rings := []
	for s in [[0.0, 0.2, 0.11], [0.2, 0.18, 0.1], [0.38, 0.2, 0.11], [0.5, 0.21, 0.11]]:
		rings.append(MeshBuilder.ring(Vector3(0, s[0], 0), s[1], s[2], 2.5, 10))
	_mb(p, hide).loft(rings, true, true)
	for side in [-1.0, 1.0]:
		var arm := Basis(Vector3.BACK, side * 0.25)
		_mb(p, hide.darkened(0.06)).lathe(PackedVector2Array([Vector2(0.06, 0.0), Vector2(0.065, 0.2), Vector2(0.058, 0.38)]), 8, Basis(Vector3.BACK, PI) * arm, Vector3(side * 0.25, 0.5, 0))
		_mb(p, fur).lathe(PackedVector2Array([Vector2(0.06, 0.0), Vector2(0.07, 0.05)]), 8, Basis(Vector3.BACK, PI) * arm, Vector3(side * 0.25 + side * 0.1, 0.13, 0)) # punho
	_mb(p, fur).torus(0.15, 0.04, 12, 4, Basis.IDENTITY, Vector3(0, 0.52, 0)) # gola
	_mb(p, fur).box(Vector3(0, 0.25, 0.112), Vector3(0.06, 0.48, 0.02)) # frente de pelo
	for k in 4:
		_mb(p, Color(0.92, 0.9, 0.82)).box(Vector3(0.05, 0.1 + k * 0.1, 0.118), Vector3(0.025, 0.025, 0.012)) # botões de osso
	_mb(p, Color(0.28, 0.18, 0.1)).box(Vector3(0, 0.2, 0.0), Vector3(0.38, 0.04, 0.24)) # cinto
	_mb(p, Color(0.62, 0.5, 0.26)).box(Vector3(0, 0.2, 0.122), Vector3(0.05, 0.05, 0.01)) # fivela
	for k in 6:
		_mb(p, hide.darkened(0.15)).box(Vector3(-0.15 + k * 0.06, 0.0, 0.1), Vector3(0.012, 0.03, 0.01)) # franja


## Correia: tira de couro enrolada em espiral com furos, ponta solta e fivela de latão.
static func _belt_coil(p: Dictionary) -> void:
	var leather := Color(0.32, 0.2, 0.12)
	var path := PackedVector3Array()
	for k in 40:
		var t := k / 39.0
		var a := t * TAU * 2.6
		var r := 0.035 + t * 0.06
		path.append(Vector3(cos(a) * r, 0.02, sin(a) * r))
	path.append(Vector3(0.12, 0.02, 0.06))
	_mb(p, leather).tube(path, 0.014, 4)
	for k in 4:
		_mb(p, Color(0.1, 0.07, 0.05)).box(Vector3(0.105 - k * 0.012, 0.035, 0.04 + k * 0.006), Vector3(0.006, 0.003, 0.006)) # furos
	_mb(p, Color(0.62, 0.5, 0.26)).torus(0.018, 0.004, 8, 3, Basis(Vector3.BACK, PI / 2), Vector3(0.035, 0.02, 0.0)) # fivela
	_mb(p, Color(0.62, 0.5, 0.26)).box(Vector3(0.035, 0.02, 0.0), Vector3(0.004, 0.004, 0.036)) # pino


## Vara de pesca: cabo de cortiça com arremate, molinete de latão com manivela,
## vara afinando com passadores (argolas) e a linha descendo até o anzol.
static func _fishing_rod(p: Dictionary) -> void:
	var cane := Color(0.62, 0.55, 0.3)
	_mb(p, Color(0.72, 0.6, 0.42)).lathe(PackedVector2Array([Vector2(0.02, -0.12), Vector2(0.024, -0.1), Vector2(0.022, 0.08), Vector2(0.018, 0.1)]), 8, AXIS_Z) # cortiça
	_mb(p, ItemModels.BRASS).lathe(PackedVector2Array([Vector2(0.002, -0.13), Vector2(0.022, -0.13), Vector2(0.022, -0.12)]), 8, AXIS_Z) # arremate
	_mb(p, cane).lathe(PackedVector2Array([Vector2(0.016, 0.1), Vector2(0.012, 0.6), Vector2(0.005, 1.45)]), 6, AXIS_Z)
	for k in 5:
		var z := 0.3 + k * 0.25
		_mb(p, cane.darkened(0.25)).lathe(PackedVector2Array([Vector2(0.017 - k * 0.0022, z), Vector2(0.017 - k * 0.0022, z + 0.02)]), 6, AXIS_Z) # amarrações
		_mb(p, ItemModels.STEEL).torus(0.008, 0.002, 6, 3, Basis(Vector3.RIGHT, PI / 2), Vector3(0, -0.018 + k * 0.002, -z - 0.01)) # passador
	# Molinete embaixo do cabo.
	_mb(p, ItemModels.BRASS).lathe(PackedVector2Array([Vector2(0.002, -0.015), Vector2(0.035, -0.015), Vector2(0.035, 0.015), Vector2(0.002, 0.015)]), 10, Basis(Vector3.BACK, PI / 2), Vector3(0, -0.05, 0.02))
	_mb(p, Color(0.85, 0.82, 0.75)).lathe(PackedVector2Array([Vector2(0.015, -0.012), Vector2(0.03, -0.012), Vector2(0.03, 0.012), Vector2(0.015, 0.012)]), 10, Basis(Vector3.BACK, PI / 2), Vector3(0, -0.05, 0.02)) # linha enrolada
	_mb(p, ItemModels.BRASS).box(Vector3(0, -0.025, 0.02), Vector3(0.01, 0.03, 0.02)) # pé do molinete
	_mb(p, ItemModels.IRON).box(Vector3(0.025, -0.05, 0.02), Vector3(0.01, 0.006, 0.04)) # manivela
	_mb(p, Color(0.2, 0.15, 0.1)).box(Vector3(0.03, -0.05, 0.04), Vector3(0.012, 0.012, 0.012))



# --- fazenda ----------------------------------------------------------------------

static func _egg(p: Dictionary) -> void:
	_mb(p, Color(0.93, 0.86, 0.72)).lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.016, 0.004), Vector2(0.024, 0.018),
		Vector2(0.025, 0.032), Vector2(0.021, 0.048), Vector2(0.012, 0.06), Vector2(0.002, 0.065)]), 10)
	_mb(p, Color(0.82, 0.72, 0.58)).box(Vector3(0.012, 0.035, 0.019), Vector3(0.004, 0.004, 0.002)) # pintinha


static func _fried_egg(p: Dictionary) -> void:
	var outline := PackedVector2Array([Vector2(-0.05, -0.02), Vector2(-0.02, -0.048), Vector2(0.03, -0.045), Vector2(0.052, -0.01),
		Vector2(0.045, 0.03), Vector2(0.01, 0.05), Vector2(-0.035, 0.04), Vector2(-0.055, 0.01)])
	_mb(p, Color(0.97, 0.96, 0.92)).extrude(outline, 0.008)
	_mb(p, Color(0.8, 0.62, 0.38)).box(Vector3(0.03, 0.004, -0.03), Vector3(0.02, 0.009, 0.012)) # beirada tostada
	ItemModels._ball(_mb(p, Color(0.98, 0.72, 0.12)), Vector3(-0.005, 0.01, 0.0), 0.018, 8)


static func _wool(p: Dictionary) -> void:
	# Chumaço de lã: bolotas fofas juntas.
	for k in 7:
		var a := TAU * k / 7.0
		ItemModels._ball(_mb(p, Color(0.93, 0.91, 0.85).darkened(0.04 * (k % 3))), Vector3(cos(a) * 0.05, 0.035 + (k % 2) * 0.015, sin(a) * 0.045), 0.04, 7)
	ItemModels._ball(_mb(p, Color(0.95, 0.93, 0.88)), Vector3(0, 0.07, 0), 0.045, 7)


static func _feather(p: Dictionary) -> void:
	_mb(p, Color(0.85, 0.82, 0.74)).tube(PackedVector3Array([Vector3(0, 0.003, -0.08), Vector3(0, 0.006, 0.0), Vector3(0, 0.004, 0.08)]), 0.0025, 4) # haste
	var vane := PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.018, -0.03), Vector2(0.02, 0.03), Vector2(0.008, 0.075),
		Vector2(0.0, 0.08), Vector2(-0.008, 0.075), Vector2(-0.02, 0.03), Vector2(-0.016, -0.03)])
	_mb(p, Color(0.55, 0.57, 0.62)).extrude(vane, 0.002)
	_mb(p, Color(0.35, 0.36, 0.4)).box(Vector3(0, 0.003, 0.05), Vector3(0.03, 0.003, 0.004)) # faixa escura


static func _beanie(p: Dictionary) -> void:
	var wool := Color(0.62, 0.22, 0.18)
	_mb(p, wool).lathe(PackedVector2Array([Vector2(0.12, 0.0), Vector2(0.125, 0.06), Vector2(0.11, 0.13), Vector2(0.07, 0.17), Vector2(0.002, 0.18)]), 10)
	_mb(p, wool.darkened(0.15)).lathe(PackedVector2Array([Vector2(0.125, 0.0), Vector2(0.13, 0.0), Vector2(0.13, 0.05), Vector2(0.125, 0.05)]), 10) # barra dobrada
	for k in 10:
		var a := TAU * k / 10.0
		_mb(p, wool.darkened(0.08)).box(Vector3(cos(a) * 0.12, 0.1, sin(a) * 0.12), Vector3(0.01, 0.08, 0.01)) # nervuras do tricô
	ItemModels._ball(_mb(p, Color(0.92, 0.9, 0.84)), Vector3(0, 0.2, 0), 0.03, 7) # pompom


static func _wool_coat(p: Dictionary) -> void:
	var wool := Color(0.55, 0.5, 0.42)
	var rings := []
	for s in [[0.0, 0.2, 0.11], [0.2, 0.18, 0.1], [0.38, 0.2, 0.11], [0.5, 0.21, 0.11]]:
		rings.append(MeshBuilder.ring(Vector3(0, s[0], 0), s[1], s[2], 2.5, 10))
	_mb(p, wool).loft(rings, true, true)
	for side in [-1.0, 1.0]:
		var arm := Basis(Vector3.BACK, side * 0.25)
		_mb(p, wool.darkened(0.05)).lathe(PackedVector2Array([Vector2(0.06, 0.0), Vector2(0.065, 0.2), Vector2(0.058, 0.38)]), 8, Basis(Vector3.BACK, PI) * arm, Vector3(side * 0.25, 0.5, 0))
	for k in 6:
		_mb(p, wool.darkened(0.1)).box(Vector3(0, 0.05 + k * 0.08, 0.112), Vector3(0.36, 0.012, 0.01)) # carreiras do tricô
	_mb(p, Color(0.4, 0.26, 0.15)).box(Vector3(-0.1, 0.3, 0.115), Vector3(0.1, 0.1, 0.01)) # remendo de couro
	_mb(p, wool.lightened(0.1)).torus(0.14, 0.035, 12, 4, Basis.IDENTITY, Vector3(0, 0.52, 0)) # gola rolê
	for k in 4:
		_mb(p, Color(0.35, 0.24, 0.14)).box(Vector3(0.04, 0.1 + k * 0.1, 0.118), Vector3(0.025, 0.025, 0.012)) # botões de madeira


static func _down_coat(p: Dictionary) -> void:
	var shell := Color(0.25, 0.4, 0.55)
	var rings := []
	for s in [[0.0, 0.21, 0.12], [0.12, 0.22, 0.13], [0.24, 0.21, 0.12], [0.36, 0.22, 0.13], [0.5, 0.21, 0.12]]:
		rings.append(MeshBuilder.ring(Vector3(0, s[0], 0), s[1], s[2], 2.5, 10))
	_mb(p, shell).loft(rings, true, true) # gomos acolchoados
	for side in [-1.0, 1.0]:
		var arm := Basis(Vector3.BACK, side * 0.25)
		_mb(p, shell.darkened(0.06)).lathe(PackedVector2Array([Vector2(0.065, 0.0), Vector2(0.075, 0.1), Vector2(0.065, 0.2), Vector2(0.075, 0.3), Vector2(0.06, 0.38)]), 8, Basis(Vector3.BACK, PI) * arm, Vector3(side * 0.26, 0.5, 0))
	for k in 4:
		_mb(p, shell.darkened(0.2)).box(Vector3(0, 0.06 + k * 0.12, 0.125), Vector3(0.4, 0.01, 0.01)) # costuras
	_mb(p, Color(0.75, 0.75, 0.78)).box(Vector3(0, 0.25, 0.13), Vector3(0.012, 0.48, 0.01)) # zíper
	_mb(p, Color(0.55, 0.57, 0.62)).box(Vector3(0.12, 0.45, 0.12), Vector3(0.02, 0.06, 0.004)) # pena escapando


# --- força rotacional ----------------------------------------------------------------

static func _wood_axle(p: Dictionary) -> void:
	var around_z := Basis(Vector3(1, 0, 0), PI / 2)
	_mb(p, Color(0.5, 0.35, 0.2)).lathe(PackedVector2Array([Vector2(0.04, -0.24), Vector2(0.04, 0.24)]), 8, around_z)
	for z in [-0.12, 0.0, 0.12]:
		_mb(p, ItemModels.IRON).lathe(PackedVector2Array([Vector2(0.045, z - 0.012), Vector2(0.045, z + 0.012)]), 8, around_z)
	for z in [-0.23, 0.23]:
		_mb(p, ItemModels.BRASS).lathe(PackedVector2Array([Vector2(0.002, z - 0.025), Vector2(0.06, z - 0.025), Vector2(0.06, z + 0.025), Vector2(0.002, z + 0.025)]), 10, around_z)


static func _wood_cog(p: Dictionary, large: bool) -> void:
	var around_z := Basis(Vector3(1, 0, 0), PI / 2)
	var r := 0.24 if large else 0.14
	var teeth := 16 if large else 10
	var wood := Color(0.52, 0.36, 0.2)
	_mb(p, wood).lathe(PackedVector2Array([Vector2(0.002, -0.03), Vector2(r - 0.03, -0.03), Vector2(r - 0.03, 0.03), Vector2(0.002, 0.03)]), teeth, around_z)
	for k in teeth:
		var a := TAU * k / teeth
		_mb(p, wood.lightened(0.06 * (k % 2))).box(Vector3(cos(a) * (r - 0.01), sin(a) * (r - 0.01), 0), Vector3(0.04, 0.045, 0.06), Basis(Vector3.BACK, a))
	if large:
		for k in 6:
			var a := TAU * k / 6.0
			_mb(p, wood.darkened(0.3)).box(Vector3(cos(a), sin(a), 0) * r * 0.45, Vector3(0.025, r * 0.7, 0.07), Basis(Vector3.BACK, a - PI / 2))
	_mb(p, ItemModels.IRON).lathe(PackedVector2Array([Vector2(0.002, -0.04), Vector2(0.05, -0.04), Vector2(0.05, 0.04), Vector2(0.002, 0.04)]), 8, around_z)


static func _wood_pulley(p: Dictionary) -> void:
	var around_z := Basis(Vector3(1, 0, 0), PI / 2)
	var r := 0.12
	_mb(p, Color(0.5, 0.35, 0.2)).lathe(PackedVector2Array([Vector2(0.002, -0.05), Vector2(r + 0.02, -0.05), Vector2(r + 0.02, -0.035), Vector2(r, -0.03),
		Vector2(r, 0.03), Vector2(r + 0.02, 0.035), Vector2(r + 0.02, 0.05), Vector2(0.002, 0.05)]), 12, around_z)
	_mb(p, ItemModels.IRON).lathe(PackedVector2Array([Vector2(0.002, -0.06), Vector2(0.04, -0.06), Vector2(0.04, 0.06), Vector2(0.002, 0.06)]), 8, around_z)
	_mb(p, Color(0.2, 0.13, 0.08)).lathe(PackedVector2Array([Vector2(r + 0.004, -0.028), Vector2(r + 0.004, 0.028)]), 12, around_z) # pedaço de esteira
