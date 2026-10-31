class_name Creatures
extends RefCounted
## Bichos da água em blocos (seres vivos do jogo são blocados). A frente aponta
## para -Z. Mesmo modelo para o bicho nadando, o item no chão/ícone e a grelha
## (cooked = assado: crustáceos ficam vermelhos, peixe tostado).
##   camarao  baixo e curvado, rabo em leque, antenas compridas
##   lagosta  corpo em gomos, duas garras grandes, antenas
##   caranguejo  casco largo, 6 patas curtas, 2 garras, olhos em haste
##   caranguejo_aranha  corpo pequeno e 8 pernas enormes dobradas
##   atum     torpedo azul e prata, barbatanas amarelas, rabo em meia-lua
##   baixo    o peixe-baixo: corpo de contrabaixo (madeira sunburst), braço
##            com tarraxas fazendo de rabo, 4 cordas no lombo e captadores

const IDS := [&"camarao", &"lagosta", &"caranguejo", &"caranguejo_aranha", &"atum", &"baixo"]
const SWIMMERS := [&"atum", &"baixo"]
const CRAWLERS := [&"camarao", &"lagosta", &"caranguejo", &"caranguejo_aranha"]

static var _cache := {}
static var _material: StandardMaterial3D


## Id cru a partir do assado (para reaproveitar o modelo).
static func raw_of(id: StringName) -> StringName:
	var s := String(id)
	for suffix in ["_assado", "_assada"]:
		if s.ends_with(suffix):
			return StringName(s.trim_suffix(suffix))
	return id


static func is_creature(id: StringName) -> bool:
	return raw_of(id) in IDS


static func mesh(id: StringName) -> Mesh:
	var key := String(id)
	if _cache.has(key):
		return _cache[key]
	var cooked := raw_of(id) != id
	var mb := MeshBuilder.new()
	match raw_of(id):
		&"camarao":
			_shrimp(mb, cooked)
		&"lagosta":
			_lobster(mb, cooked)
		&"caranguejo":
			_crab(mb, cooked)
		&"caranguejo_aranha":
			_spider_crab(mb, cooked)
		&"atum":
			_tuna(mb, cooked)
		&"baixo":
			_bass(mb, cooked)
	var result := mb.finish(_mat(), false)
	_cache[key] = result
	return result


static func node(id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var instance := MeshInstance3D.new()
	instance.mesh = mesh(id)
	root.add_child(instance)
	return root


static func _shell(raw: Color, cooked: bool) -> Color:
	return Color(0.86, 0.25, 0.12) if cooked else raw


static func _shrimp(mb: MeshBuilder, cooked: bool) -> void:
	var body := _shell(Color(0.72, 0.68, 0.62), cooked)
	if cooked:
		body = Color(0.95, 0.5, 0.4)
	for k in 6: # gomos curvando para baixo no rabo
		var a := k * 0.22
		var p := Vector3(0, 0.012 - sin(a) * 0.02 * k * 0.4, -0.04 + k * 0.016)
		mb.color(body.darkened(0.06 * (k % 2)))
		mb.box(p, Vector3(0.026 - k * 0.002, 0.022 - k * 0.002, 0.018), Basis(Vector3.RIGHT, a))
	mb.color(body.lightened(0.1))
	mb.box(Vector3(0, -0.012, 0.062), Vector3(0.03, 0.004, 0.018), Basis(Vector3.RIGHT, 1.0)) # leque do rabo
	mb.color(body.darkened(0.3))
	for side in [-1.0, 1.0]:
		mb.box(Vector3(side * 0.012, 0.02, -0.055), Vector3(0.004, 0.004, 0.004)) # olho
		mb.box(Vector3(side * 0.01, 0.02, -0.1), Vector3(0.002, 0.002, 0.08), Basis(Vector3.UP, side * 0.2)) # antena
		for leg in 3:
			mb.box(Vector3(side * 0.012, -0.012, -0.03 + leg * 0.012), Vector3(0.003, 0.014, 0.003))


static func _lobster(mb: MeshBuilder, cooked: bool) -> void:
	var shell := _shell(Color(0.16, 0.24, 0.3), cooked)
	mb.color(shell)
	mb.box(Vector3(0, 0.03, -0.06), Vector3(0.07, 0.055, 0.12)) # cabeça/tórax
	for k in 5: # rabo em gomos
		mb.color(shell.darkened(0.08 * (k % 2)))
		mb.box(Vector3(0, 0.026 - k * 0.002, 0.02 + k * 0.03), Vector3(0.062 - k * 0.006, 0.042, 0.03))
	mb.color(shell.lightened(0.08))
	mb.box(Vector3(0, 0.018, 0.19), Vector3(0.08, 0.01, 0.04)) # leque
	for side in [-1.0, 1.0]:
		mb.color(shell)
		mb.box(Vector3(side * 0.05, 0.03, -0.11), Vector3(0.02, 0.02, 0.06), Basis(Vector3.UP, side * 0.5)) # braço
		mb.box(Vector3(side * 0.075, 0.03, -0.16), Vector3(0.045, 0.03, 0.07), Basis(Vector3.UP, side * 0.25)) # garra
		mb.box(Vector3(side * 0.07, 0.03, -0.2), Vector3(0.018, 0.024, 0.04), Basis(Vector3.UP, -side * 0.3)) # pinça
		mb.color(shell.darkened(0.3))
		mb.box(Vector3(side * 0.02, 0.06, -0.12), Vector3(0.008, 0.008, 0.008))
		mb.box(Vector3(side * 0.02, 0.05, -0.24), Vector3(0.004, 0.004, 0.2), Basis(Vector3.UP, side * 0.25)) # antena
		for leg in 4:
			mb.box(Vector3(side * 0.045, 0.0, -0.08 + leg * 0.02), Vector3(0.035, 0.006, 0.006), Basis(Vector3.BACK, side * -0.5))


static func _crab(mb: MeshBuilder, cooked: bool) -> void:
	var shell := _shell(Color(0.62, 0.36, 0.18), cooked)
	mb.color(shell)
	mb.box(Vector3(0, 0.03, 0), Vector3(0.17, 0.04, 0.12)) # casco
	mb.color(shell.lightened(0.08))
	mb.box(Vector3(0, 0.052, 0), Vector3(0.13, 0.012, 0.09))
	for side in [-1.0, 1.0]:
		mb.color(shell.darkened(0.15))
		for leg in 3:
			var z := -0.03 + leg * 0.03
			mb.box(Vector3(side * 0.1, 0.03, z), Vector3(0.05, 0.01, 0.01), Basis(Vector3.BACK, side * 0.4))
			mb.box(Vector3(side * 0.13, 0.008, z), Vector3(0.01, 0.04, 0.01))
		mb.color(shell)
		mb.box(Vector3(side * 0.09, 0.035, -0.08), Vector3(0.05, 0.03, 0.04)) # garra
		mb.box(Vector3(side * 0.075, 0.04, -0.11), Vector3(0.02, 0.016, 0.03))
		mb.color(Color(0.08, 0.08, 0.08))
		mb.box(Vector3(side * 0.025, 0.075, -0.055), Vector3(0.01, 0.025, 0.01)) # olho na haste


static func _spider_crab(mb: MeshBuilder, cooked: bool) -> void:
	var shell := _shell(Color(0.7, 0.45, 0.25), cooked)
	mb.color(shell)
	mb.box(Vector3(0, 0.12, 0), Vector3(0.1, 0.06, 0.12)) # corpo pequeno lá em cima
	mb.color(shell.lightened(0.1))
	mb.box(Vector3(0, 0.155, -0.02), Vector3(0.05, 0.02, 0.05))
	for side in [-1.0, 1.0]:
		for leg in 4:
			var hip := Vector3(side * 0.05, 0.12, -0.05 + leg * 0.035)
			var out := Vector3(side, 0.0, (leg - 1.5) * 0.55).normalized()
			var knee: Vector3 = hip + out * 0.17 + Vector3.UP * 0.07
			var foot: Vector3 = knee + out * 0.16 - Vector3.UP * 0.19
			mb.color(shell.darkened(0.1 * (leg % 2)))
			_stick(mb, hip, knee, 0.012)
			_stick(mb, knee, foot, 0.009)
		mb.color(shell)
		_stick(mb, Vector3(side * 0.03, 0.12, -0.06), Vector3(side * 0.09, 0.1, -0.22), 0.012) # garra fina
		mb.color(Color(0.08, 0.08, 0.08))
		mb.box(Vector3(side * 0.02, 0.16, -0.06), Vector3(0.008, 0.012, 0.008))


static func _tuna(mb: MeshBuilder, cooked: bool) -> void:
	var back := Color(0.12, 0.2, 0.36) if not cooked else Color(0.35, 0.22, 0.12)
	var belly := Color(0.75, 0.78, 0.8) if not cooked else Color(0.75, 0.55, 0.35)
	var fin := Color(0.85, 0.75, 0.2) if not cooked else Color(0.5, 0.35, 0.15)
	var sections := [[-0.42, 0.08, 0.1], [-0.3, 0.14, 0.18], [-0.12, 0.17, 0.24], [0.08, 0.15, 0.22], [0.24, 0.1, 0.14], [0.36, 0.05, 0.07]]
	for s in sections:
		mb.color(back)
		mb.box(Vector3(0, s[2] * 0.22, s[0]), Vector3(s[1], s[2] * 0.56, 0.17))
		mb.color(belly)
		mb.box(Vector3(0, -s[2] * 0.28, s[0]), Vector3(s[1] * 0.92, s[2] * 0.44, 0.17))
	mb.color(Color(0.05, 0.05, 0.05))
	for side in [-1.0, 1.0]:
		mb.box(Vector3(side * 0.045, 0.02, -0.4), Vector3(0.01, 0.025, 0.025))
	mb.color(back.darkened(0.2))
	mb.box(Vector3(0, 0.16, -0.1), Vector3(0.015, 0.1, 0.12), Basis(Vector3.RIGHT, -0.5)) # barbatana de cima
	mb.color(fin)
	for k in 4:
		mb.box(Vector3(0, 0.07 - k * 0.008, 0.2 + k * 0.05), Vector3(0.01, 0.025, 0.02)) # pínulas
	mb.color(back)
	mb.box(Vector3(0, 0.1, 0.45), Vector3(0.012, 0.2, 0.05), Basis(Vector3.RIGHT, 0.6)) # rabo em meia-lua
	mb.box(Vector3(0, -0.1, 0.45), Vector3(0.012, 0.2, 0.05), Basis(Vector3.RIGHT, -0.6))
	for side in [-1.0, 1.0]:
		mb.color(fin.darkened(0.2))
		mb.box(Vector3(side * 0.1, -0.02, -0.18), Vector3(0.1, 0.01, 0.05), Basis(Vector3.UP, side * -0.5)) # peitoral


## Peixe-baixo: um peixe de verdade (cabeça, boca, guelras, barbatanas e rabo
## bifurcado) com "acabamento" de contrabaixo: corpo de madeira sunburst,
## escudo claro, dois captadores e 4 cordas correndo pelo flanco, e a mão com
## as tarraxas de latão fazendo de barbatana dorsal.
static func _bass(mb: MeshBuilder, cooked: bool) -> void:
	var wood := Color(0.66, 0.36, 0.14) if not cooked else Color(0.4, 0.2, 0.08)
	var burst := Color(0.24, 0.1, 0.05) if not cooked else Color(0.14, 0.06, 0.03)
	var belly := Color(0.86, 0.72, 0.5) if not cooked else Color(0.6, 0.42, 0.25)
	# Corpo de peixe em fatias (alto no meio, afinando no rabo), borda escura (sunburst).
	var sections := [[-0.26, 0.14, 0.11], [-0.17, 0.2, 0.13], [-0.06, 0.23, 0.14], [0.06, 0.21, 0.13], [0.17, 0.15, 0.1], [0.26, 0.08, 0.07]]
	for s in sections:
		mb.color(burst)
		mb.box(Vector3(0, 0, s[0]), Vector3(s[2] * 0.62, s[1], 0.12))
		mb.color(wood)
		mb.box(Vector3(0, s[1] * 0.06, s[0]), Vector3(s[2] * 0.66, s[1] * 0.72, 0.1))
		mb.color(belly)
		mb.box(Vector3(0, -s[1] * 0.36, s[0]), Vector3(s[2] * 0.55, s[1] * 0.22, 0.11))
	# Cabeça com boca aberta (o "groove") e guelra.
	mb.color(wood.darkened(0.15))
	mb.box(Vector3(0, 0.0, -0.34), Vector3(0.06, 0.1, 0.06))
	mb.color(Color(0.3, 0.08, 0.06))
	mb.box(Vector3(0, -0.02, -0.375), Vector3(0.04, 0.03, 0.02))
	mb.color(burst)
	for side in [-1.0, 1.0]:
		mb.box(Vector3(side * 0.045, 0.0, -0.22), Vector3(0.006, 0.12, 0.012)) # guelra
	# Olhos grandes.
	for side in [-1.0, 1.0]:
		mb.color(Color(0.95, 0.95, 0.9))
		mb.box(Vector3(side * 0.043, 0.035, -0.28), Vector3(0.008, 0.035, 0.035))
		mb.color(Color(0.05, 0.05, 0.05))
		mb.box(Vector3(side * 0.047, 0.035, -0.283), Vector3(0.004, 0.018, 0.018))
	# Acabamento de contrabaixo no flanco: escudo, captadores, ponte e 4 cordas.
	for side in [-1.0, 1.0]:
		mb.color(Color(0.9, 0.88, 0.8))
		mb.box(Vector3(side * 0.046, -0.02, -0.02), Vector3(0.004, 0.09, 0.16))
		mb.color(Color(0.07, 0.07, 0.07))
		for z in [-0.05, 0.07]:
			mb.box(Vector3(side * 0.05, 0.01, z), Vector3(0.005, 0.07, 0.022))
		mb.box(Vector3(side * 0.048, 0.005, 0.17), Vector3(0.005, 0.06, 0.018))
		mb.color(Color(0.85, 0.85, 0.8))
		for k in 4:
			mb.box(Vector3(side * 0.054, -0.012 + k * 0.01, 0.0), Vector3(0.002, 0.002, 0.42))
	# Barbatana dorsal = mão do baixo com 4 tarraxas de latão.
	mb.color(Color(0.3, 0.17, 0.08))
	mb.box(Vector3(0, 0.14, -0.02), Vector3(0.025, 0.06, 0.16), Basis(Vector3.RIGHT, 0.15))
	mb.color(ItemModels.BRASS)
	for k in 4:
		mb.box(Vector3(0.02 * (1 if k % 2 == 0 else -1), 0.15, -0.08 + k * 0.04), Vector3(0.025, 0.012, 0.012))
	# Barbatanas peitorais e de baixo.
	mb.color(wood.lightened(0.12))
	for side in [-1.0, 1.0]:
		mb.box(Vector3(side * 0.05, -0.04, -0.14), Vector3(0.05, 0.008, 0.05), Basis(Vector3.UP, side * 0.6))
	mb.box(Vector3(0, -0.13, 0.1), Vector3(0.01, 0.05, 0.08), Basis(Vector3.RIGHT, -0.4))
	# Rabo bifurcado.
	mb.color(burst)
	mb.box(Vector3(0, 0.0, 0.31), Vector3(0.03, 0.05, 0.04))
	mb.color(wood)
	mb.box(Vector3(0, 0.06, 0.37), Vector3(0.012, 0.12, 0.05), Basis(Vector3.RIGHT, 0.55))
	mb.box(Vector3(0, -0.06, 0.37), Vector3(0.012, 0.12, 0.05), Basis(Vector3.RIGHT, -0.55))


static func _stick(mb: MeshBuilder, a: Vector3, b: Vector3, thickness: float) -> void:
	var dir := b - a
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT)
	mb.box((a + b) * 0.5, Vector3(thickness, thickness, dir.length()), basis)


static func _mat() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.85
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material
