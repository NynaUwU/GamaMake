class_name Furniture
extends StaticBody3D
## Móvel dentro das casas com interior (mesa, cadeira, cama, armário, estante,
## fogão a lenha). Qualquer golpe (arma, ferramenta ou soco) desmonta: ao zerar a
## "vida" ele quebra e solta material (tábuas, gravetos, pano, sucata).
## Chave fixa (casa + índice): quebrado fica quebrado para todos e no save.
## Montado dentro da thread das casas: só cria nós aqui; liga no Net no _ready.

const HP := {"mesa": 40.0, "cadeira": 20.0, "cama": 50.0, "armario": 60.0, "estante": 45.0, "fogao": 70.0,
	"sofa": 45.0, "banheira": 70.0, "privada": 40.0, "pia": 35.0, "balcao": 50.0, "comoda": 40.0}
const PORCELAIN := Color(0.86, 0.86, 0.82)
const WOOD := Color(0.45, 0.3, 0.17)
const DARK := Color(0.28, 0.18, 0.1)

var key := ""
var kind := "mesa"
var hp := 40.0
var _done := false
var _material: StandardMaterial3D


func setup(key_: String, kind_: String, material: StandardMaterial3D) -> void:
	key = key_
	kind = kind_
	hp = HP.get(kind, 40.0)
	_material = material
	collision_layer = 1
	collision_mask = 0
	_build()


func _ready() -> void:
	if Net.i.taken.has(key):
		queue_free() # já quebrado neste mundo
		return
	Net.i.looted.connect(_on_looted)


## Golpe de qualquer arma/ferramenta (Player._apply_swing_hit) ou soco.
func tool_hit(_player: Node, _weapon_type: int, damage: float, point: Vector3) -> void:
	if _done:
		return
	hp -= damage
	ImpactFX.burst(get_parent(), point, Vector3.UP, WOOD if kind != "fogao" else Color(0.3, 0.3, 0.3), 8, 2.0, 0.04)
	Sfx.play_at("knock", point, 2.0, 0.8 if kind != "fogao" else 1.3)
	if hp <= 0.0:
		_done = true
		Net.i.loot_request(key, global_transform.translated(Vector3.UP * 0.2), "movel_" + kind)


func _on_looted(k: String) -> void:
	if k != key:
		return
	Sfx.play_at("crunch", global_position + Vector3.UP * 0.5, 4.0, 0.7)
	ImpactFX.burst(get_parent(), global_position + Vector3.UP * 0.5, Vector3.UP, WOOD, 24, 3.0, 0.06)
	queue_free()


## Malha e colisões de cada tipo, montadas uma vez só (todas as camas são
## iguais): as casas ocas mobiliam na thread principal e montar de novo a cada
## móvel travava o jogo quando uma cidade carregava.
static var _cache := {}
var _shape_log: Array = []


func _build() -> void:
	if _cache.has(kind):
		var cached: Dictionary = _cache[kind]
		for entry in cached.shapes:
			_shape(entry[0], entry[1])
		var copy := MeshInstance3D.new()
		copy.mesh = cached.mesh
		copy.material_override = _material
		add_child(copy)
		return
	var mb := MeshBuilder.new()
	match kind:
		"mesa": _table(mb)
		"cadeira": _chair(mb)
		"cama": _bed(mb)
		"armario": _wardrobe(mb)
		"estante": _bookcase(mb)
		"fogao": _stove(mb)
		"sofa": _sofa(mb)
		"banheira": _bathtub(mb)
		"privada": _toilet(mb)
		"pia": _sink(mb)
		"balcao": _counter(mb)
		"comoda": _dresser(mb)
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(_material, false)
	add_child(mesh)
	_cache[kind] = {"mesh": mesh.mesh, "shapes": _shape_log.duplicate()}


# --- Ajudantes ------------------------------------------------------------------------

## Perna torneada (bolacha, gargalo, pé).
func _leg(mb: MeshBuilder, at: Vector3, height: float, r := 0.035, color := DARK) -> void:
	mb.color(color)
	mb.lathe(PackedVector2Array([Vector2(r * 0.8, 0.0), Vector2(r, 0.03), Vector2(r * 0.7, height * 0.25), Vector2(r * 1.2, height * 0.45),
		Vector2(r * 0.75, height * 0.7), Vector2(r, height * 0.92), Vector2(r, height)]), 8, Basis.IDENTITY, at)


## Porta de almofada (moldura + painel rebaixado) virada para +Z.
func _panel_door(mb: MeshBuilder, center: Vector3, w: float, h: float, color := WOOD) -> void:
	mb.color(color)
	mb.box(center, Vector3(w, h, 0.03))
	mb.color(color.darkened(0.18))
	mb.box(center + Vector3(0, 0, 0.016), Vector3(w - 0.1, h - 0.1, 0.004))
	mb.color(color.lightened(0.05))
	mb.box(center + Vector3(0, 0, 0.02), Vector3(w - 0.16, h - 0.16, 0.006))


func _knob(mb: MeshBuilder, at: Vector3) -> void:
	mb.color(ItemModels.BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.012, 0.0), Vector2(0.008, 0.015), Vector2(0.018, 0.03), Vector2(0.002, 0.035)]), 6, Basis(Vector3.RIGHT, PI / 2), at)


func _pull(mb: MeshBuilder, at: Vector3, width := 0.1) -> void:
	mb.color(ItemModels.BRASS)
	mb.box(at + Vector3(0, 0, 0.012), Vector3(width, 0.018, 0.012))
	for side in [-1.0, 1.0]:
		mb.box(at + Vector3(side * width * 0.45, 0, 0.005), Vector3(0.016, 0.018, 0.012))


# --- Sala e quarto ----------------------------------------------------------------------

func _table(mb: MeshBuilder) -> void:
	# Tampo de tábuas com frestas e borda, saia, pernas torneadas, travessa em H,
	# toalha de renda, pratos, caneca, castiçal com vela.
	ObjectModels._boards(mb, Vector3(0, 0.765, 0), Vector3(1.3, 0.05, 0.8), 4, true, WOOD)
	mb.color(DARK)
	mb.box(Vector3(0, 0.715, 0), Vector3(1.18, 0.07, 0.68)) # saia
	for x in [-0.56, 0.56]:
		for z in [-0.31, 0.31]:
			_leg(mb, Vector3(x, 0, z), 0.7)
		mb.box(Vector3(x, 0.15, 0), Vector3(0.04, 0.04, 0.6))
	mb.box(Vector3(0, 0.15, 0), Vector3(1.1, 0.04, 0.04))
	mb.color(Color(0.86, 0.84, 0.76))
	mb.box(Vector3(0, 0.793, 0), Vector3(0.48, 0.006, 0.86)) # caminho de mesa
	for z in [-0.43, 0.43]:
		mb.box(Vector3(0, 0.76, z), Vector3(0.48, 0.07, 0.006))
	mb.color(Color(0.9, 0.88, 0.82))
	for x in [-0.36, 0.32]:
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.795), Vector2(0.06, 0.797), Vector2(0.095, 0.805), Vector2(0.1, 0.815)]), 12, Basis.IDENTITY, Vector3(x, 0, 0.14))
		mb.color(Color(0.3, 0.45, 0.6))
		mb.lathe(PackedVector2Array([Vector2(0.075, 0.806), Vector2(0.08, 0.808)]), 12, Basis.IDENTITY, Vector3(x, 0, 0.14)) # friso azul
		mb.color(Color(0.9, 0.88, 0.82))
	mb.color(ItemModels.STEEL)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.795), Vector2(0.032, 0.795), Vector2(0.036, 0.9), Vector2(0.032, 0.905)]), 8, Basis.IDENTITY, Vector3(0.05, 0, -0.15))
	mb.tube(PackedVector3Array([Vector3(0.085, 0.88, -0.15), Vector3(0.11, 0.85, -0.15), Vector3(0.085, 0.82, -0.15)]), 0.006, 3) # asa
	mb.color(ItemModels.BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.795), Vector2(0.06, 0.795), Vector2(0.02, 0.81), Vector2(0.015, 0.86), Vector2(0.03, 0.87)]), 8, Basis.IDENTITY, Vector3(-0.1, 0, -0.25))
	mb.color(Color(0.95, 0.9, 0.7))
	mb.lathe(PackedVector2Array([Vector2(0.015, 0.87), Vector2(0.013, 0.97), Vector2(0.002, 0.98)]), 6, Basis.IDENTITY, Vector3(-0.1, 0, -0.25))
	_shape(Vector3(0, 0.4, 0), Vector3(1.3, 0.8, 0.8))


func _chair(mb: MeshBuilder) -> void:
	# Assento de tábuas com almofada amarrada, pernas torneadas com travessas,
	# encosto com montantes torneados e três travessas curvas.
	ObjectModels._boards(mb, Vector3(0, 0.45, 0), Vector3(0.42, 0.04, 0.42), 3, true, WOOD.darkened(0.1))
	for x in [-0.18, 0.18]:
		for z in [-0.18, 0.18]:
			_leg(mb, Vector3(x, 0, z), 0.43, 0.025, WOOD.darkened(0.15))
	mb.color(WOOD.darkened(0.15))
	for z in [-0.18, 0.18]:
		mb.box(Vector3(0, 0.15, z), Vector3(0.36, 0.025, 0.025))
	mb.box(Vector3(0, 0.22, 0), Vector3(0.025, 0.025, 0.36))
	for x in [-0.18, 0.18]:
		mb.lathe(PackedVector2Array([Vector2(0.022, 0.47), Vector2(0.018, 0.6), Vector2(0.025, 0.75), Vector2(0.018, 0.92), Vector2(0.028, 0.97), Vector2(0.002, 1.0)]), 6, Basis.IDENTITY, Vector3(x, 0, 0.19))
	for y in [0.62, 0.76, 0.9]:
		mb.box(Vector3(0, y, 0.2), Vector3(0.36, 0.05, 0.022), Basis(Vector3.UP, 0.0))
		mb.box(Vector3(0, y, 0.205), Vector3(0.3, 0.035, 0.022))
	mb.color(Color(0.48, 0.26, 0.22))
	mb.box(Vector3(0, 0.485, 0), Vector3(0.36, 0.035, 0.36)) # almofada
	mb.color(Color(0.4, 0.2, 0.17))
	for x in [-0.12, 0.12]:
		mb.box(Vector3(x, 0.504, 0.0), Vector3(0.02, 0.005, 0.02)) # botões
	mb.color(Color(0.62, 0.55, 0.42))
	for x in [-0.17, 0.17]:
		mb.box(Vector3(x, 0.48, 0.17), Vector3(0.012, 0.03, 0.04)) # amarração
	_shape(Vector3(0, 0.45, 0), Vector3(0.45, 0.9, 0.45))


func _bed(mb: MeshBuilder) -> void:
	# Estrado com laterais de tábua, cabeceira e peseira de almofada com postes
	# torneados de pinha, colchão com costura, lençol, colcha caindo dos lados,
	# travesseiro e um tapetinho do lado.
	mb.color(DARK)
	for side in [-1.0, 1.0]:
		mb.box(Vector3(side * 0.45, 0.24, 0), Vector3(0.05, 0.16, 1.9)) # laterais
	for x in [-0.44, 0.44]:
		for z in [-0.95, 0.95]:
			var top := 0.95 if z < 0 else 0.62
			mb.lathe(PackedVector2Array([Vector2(0.04, 0.0), Vector2(0.045, 0.05), Vector2(0.035, top * 0.4), Vector2(0.045, top * 0.7),
				Vector2(0.035, top * 0.9), Vector2(0.05, top), Vector2(0.03, top + 0.04), Vector2(0.002, top + 0.07)]), 8, Basis.IDENTITY, Vector3(x, 0, z))
	_panel_door(mb, Vector3(0, 0.62, -0.95), 0.84, 0.5, DARK.lightened(0.05)) # cabeceira
	_panel_door(mb, Vector3(0, 0.42, 0.95), 0.84, 0.28, DARK.lightened(0.05)) # peseira
	mb.color(WOOD.lightened(0.05))
	mb.box(Vector3(0, 0.88, -0.95), Vector3(0.9, 0.05, 0.08)) # coroa da cabeceira
	mb.color(Color(0.78, 0.74, 0.62))
	mb.box(Vector3(0, 0.37, 0.02), Vector3(0.86, 0.13, 1.8)) # colchão
	mb.color(Color(0.66, 0.62, 0.5))
	mb.box(Vector3(0, 0.37, 0.02), Vector3(0.87, 0.01, 1.81)) # costura
	mb.color(Color(0.92, 0.9, 0.84))
	mb.box(Vector3(0, 0.44, -0.55), Vector3(0.84, 0.02, 0.5)) # lençol dobrado
	mb.color(Color(0.5, 0.18, 0.15))
	var quilt := []
	for r in 5:
		var row := PackedVector3Array()
		for c in 7:
			var x := lerpf(-0.5, 0.5, c / 6.0)
			var edge := absf(x) > 0.43
			row.append(Vector3(x, (0.26 if edge else 0.45) + sin(c * 1.7 + r) * 0.012, lerpf(-0.32, 0.92, r / 4.0)))
		quilt.append(row)
	mb.sheet(quilt)
	mb.color(Color(0.85, 0.75, 0.35))
	for r in 4:
		mb.box(Vector3(0, 0.456, -0.25 + r * 0.32), Vector3(0.84, 0.006, 0.02)) # faixas da colcha
	mb.color(Color(0.92, 0.9, 0.84))
	mb.lathe(PackedVector2Array([Vector2(0.002, -0.3), Vector2(0.08, -0.27), Vector2(0.1, 0.0), Vector2(0.08, 0.27), Vector2(0.002, 0.3)]), 8, Basis(Vector3.BACK, PI / 2), Vector3(0, 0.49, -0.72))
	mb.color(Color(0.45, 0.32, 0.25))
	mb.box(Vector3(0.75, 0.005, 0.2), Vector3(0.5, 0.01, 0.8)) # tapete
	mb.color(Color(0.65, 0.5, 0.3))
	mb.box(Vector3(0.75, 0.011, 0.2), Vector3(0.4, 0.002, 0.7))
	_shape(Vector3(0, 0.3, 0), Vector3(0.95, 0.6, 1.95))


func _wardrobe(mb: MeshBuilder) -> void:
	# Guarda-roupa: corpo com laterais de almofada, cornija em degraus, rodapé com
	# pés, duas portas de almofada dupla com dobradiças e puxadores, gaveta embaixo.
	mb.color(DARK)
	mb.box(Vector3(0, 0.98, -0.02), Vector3(1.0, 1.76, 0.46))
	mb.box(Vector3(0, 1.88, 0.0), Vector3(1.06, 0.06, 0.52))
	mb.color(DARK.lightened(0.06))
	mb.box(Vector3(0, 1.93, 0.01), Vector3(1.12, 0.05, 0.56)) # cornija
	mb.color(DARK)
	mb.box(Vector3(0, 0.08, 0.0), Vector3(1.04, 0.1, 0.5)) # rodapé
	for x in [-0.46, 0.46]:
		for z in [-0.2, 0.2]:
			mb.box(Vector3(x, 0.015, z), Vector3(0.08, 0.03, 0.08))
	for x in [-0.245, 0.245]:
		for y in [0.72, 1.38]:
			_panel_door(mb, Vector3(x, y, 0.22), 0.47, 0.64)
		mb.color(WOOD.darkened(0.05))
		mb.box(Vector3(x, 1.05, 0.22), Vector3(0.47, 0.04, 0.03)) # travessa entre as almofadas
	_panel_door(mb, Vector3(0, 0.25, 0.22), 0.96, 0.2)
	for x in [-0.03, 0.03]:
		_knob(mb, Vector3(x, 1.02, 0.24))
	_pull(mb, Vector3(0, 0.25, 0.24), 0.12)
	mb.color(ItemModels.IRON)
	for x in [-0.47, 0.47]:
		for y in [0.55, 1.55]:
			mb.box(Vector3(x, y, 0.235), Vector3(0.02, 0.08, 0.02))
	_shape(Vector3(0, 0.95, 0), Vector3(1.0, 1.9, 0.5))


func _bookcase(mb: MeshBuilder) -> void:
	# Estante: laterais e fundo de tábuas, prateleiras com borda, livros de
	# alturas e cores variadas (um deitado, um caído), pote e vela em cima.
	for side in [-0.48, 0.48]:
		mb.color(WOOD.darkened(0.05))
		mb.box(Vector3(side, 0.9, 0), Vector3(0.05, 1.8, 0.35))
	ObjectModels._boards(mb, Vector3(0, 0.9, -0.165), Vector3(0.92, 1.76, 0.02), 5, false, WOOD.darkened(0.2))
	for k in 4:
		mb.color(WOOD)
		mb.box(Vector3(0, 0.1 + k * 0.55, 0), Vector3(0.92, 0.04, 0.33))
		mb.color(WOOD.darkened(0.1))
		mb.box(Vector3(0, 0.1 + k * 0.55, 0.17), Vector3(0.92, 0.06, 0.02)) # borda
	mb.color(WOOD.darkened(0.1))
	mb.box(Vector3(0, 1.82, 0.01), Vector3(1.04, 0.05, 0.38))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var covers := [Color(0.55, 0.15, 0.12), Color(0.2, 0.35, 0.5), Color(0.3, 0.45, 0.25), Color(0.6, 0.5, 0.25), Color(0.35, 0.25, 0.2), Color(0.42, 0.2, 0.35)]
	for shelf in 3:
		var x := -0.42
		while x < 0.36:
			var w := rng.randf_range(0.04, 0.08)
			var h := rng.randf_range(0.22, 0.36)
			var color: Color = covers[rng.randi() % covers.size()]
			var y := 0.12 + shelf * 0.55
			if rng.randf() < 0.08:
				mb.color(color)
				mb.box(Vector3(x + 0.12, y + 0.025, 0.02), Vector3(0.24, 0.05, 0.18)) # deitado
				x += 0.26
				continue
			mb.color(color)
			mb.box(Vector3(x + w * 0.5, y + h * 0.5, 0.02), Vector3(w, h, rng.randf_range(0.18, 0.26)))
			mb.color(Color(0.85, 0.72, 0.35))
			mb.box(Vector3(x + w * 0.5, y + h * 0.75, 0.13), Vector3(w * 0.7, 0.012, 0.004)) # título dourado
			x += w + 0.005
	mb.color(Color(0.62, 0.5, 0.3))
	mb.lathe(PackedVector2Array([Vector2(0.002, 1.845), Vector2(0.07, 1.845), Vector2(0.08, 1.93), Vector2(0.05, 2.0)]), 8, Basis.IDENTITY, Vector3(-0.25, 0, 0))
	mb.color(Color(0.95, 0.9, 0.7))
	mb.lathe(PackedVector2Array([Vector2(0.02, 1.845), Vector2(0.018, 1.97), Vector2(0.002, 1.98)]), 6, Basis.IDENTITY, Vector3(0.25, 0, 0))
	_shape(Vector3(0, 0.9, 0), Vector3(1.0, 1.8, 0.35))


func _stove(mb: MeshBuilder) -> void:
	# Fogão a lenha de ferro fundido: corpo com frisos, boca da lenha (mesma das
	# fornalhas) e porta do forno, cinzeiro, chapa com duas bocas e tampas,
	# barra de toalha, pés de garra, chaminé em gomos e panela.
	var iron := Color(0.18, 0.17, 0.16)
	mb.color(iron)
	mb.box(Vector3(0, 0.44, 0), Vector3(0.8, 0.7, 0.6))
	for x in [-0.36, 0.36]:
		for z in [-0.26, 0.26]:
			mb.lathe(PackedVector2Array([Vector2(0.03, 0.0), Vector2(0.045, 0.03), Vector2(0.025, 0.07), Vector2(0.035, 0.09)]), 6, Basis.IDENTITY, Vector3(x, 0, z))
	mb.color(iron.lightened(0.08))
	for y in [0.12, 0.76]:
		mb.box(Vector3(0, y, 0.0), Vector3(0.82, 0.03, 0.62)) # frisos
	ObjectModels.mouth(mb, Vector3(-0.18, 0.5, 0.3), 0.26, 0.2, 0.0, iron.lightened(0.15))
	mb.color(iron.lightened(0.1))
	mb.box(Vector3(0.2, 0.42, 0.31), Vector3(0.32, 0.36, 0.02)) # porta do forno
	mb.color(ItemModels.BRASS)
	mb.box(Vector3(0.2, 0.55, 0.33), Vector3(0.2, 0.02, 0.02)) # puxador do forno
	mb.color(Color(0.08, 0.07, 0.06))
	mb.box(Vector3(-0.18, 0.2, 0.305), Vector3(0.26, 0.08, 0.01)) # cinzeiro
	mb.color(ItemModels.STEEL)
	mb.box(Vector3(0, 0.72, 0.34), Vector3(0.7, 0.015, 0.015)) # barra da toalha
	mb.color(Color(0.86, 0.84, 0.76))
	mb.box(Vector3(0.15, 0.62, 0.345), Vector3(0.16, 0.2, 0.008))
	mb.color(iron.lightened(0.12))
	mb.box(Vector3(0, 0.81, 0), Vector3(0.86, 0.04, 0.66)) # chapa
	mb.color(Color(0.1, 0.1, 0.09))
	for x in [-0.2, 0.2]:
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.832), Vector2(0.11, 0.832), Vector2(0.11, 0.838), Vector2(0.002, 0.838)]), 10, Basis.IDENTITY, Vector3(x, 0, 0.05))
		mb.torus(0.11, 0.01, 10, 3, Basis.IDENTITY, Vector3(x, 0.838, 0.05))
		mb.box(Vector3(x + 0.07, 0.85, 0.05), Vector3(0.03, 0.02, 0.012)) # cabo da tampa
	mb.color(iron)
	for k in 4:
		var y0 := 0.83 + k * 0.42
		mb.lathe(PackedVector2Array([Vector2(0.07, y0), Vector2(0.07, y0 + 0.4), Vector2(0.078, y0 + 0.41), Vector2(0.078, y0 + 0.43)]), 8, Basis.IDENTITY, Vector3(0.25, 0, -0.22))
	mb.tube(PackedVector3Array([Vector3(0.25, 2.48, -0.22), Vector3(0.25, 2.6, -0.3), Vector3(0.25, 2.65, -0.42)]), 0.07, 8)
	mb.color(ItemModels.STEEL)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.84), Vector2(0.11, 0.84), Vector2(0.12, 0.98), Vector2(0.125, 0.99)]), 10, Basis.IDENTITY, Vector3(-0.2, 0, 0.05))
	mb.tube(PackedVector3Array([Vector3(-0.08, 0.95, 0.05), Vector3(0.05, 0.95, 0.05)]), 0.01, 4)
	_shape(Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.6))


func _sofa(mb: MeshBuilder) -> void:
	# Sofá: base estofada com saia, pés torneados, encosto com botões, braços em
	# rolo com ponteira, almofadas soltas, uma almofadinha e um rasgo com espuma.
	var cloth := Color(0.48, 0.26, 0.22)
	for x in [-0.72, 0.72]:
		for z in [-0.3, 0.3]:
			_leg(mb, Vector3(x, 0, z), 0.1, 0.025)
	mb.color(cloth)
	mb.box(Vector3(0, 0.25, 0), Vector3(1.6, 0.28, 0.75))
	mb.color(cloth.darkened(0.15))
	mb.box(Vector3(0, 0.13, 0.0), Vector3(1.62, 0.06, 0.77)) # saia
	mb.color(cloth)
	mb.box(Vector3(0, 0.64, -0.3), Vector3(1.6, 0.55, 0.18))
	mb.color(cloth.darkened(0.2))
	for x in [-0.5, -0.17, 0.17, 0.5]:
		for y in [0.62, 0.78]:
			mb.box(Vector3(x, y, -0.205), Vector3(0.025, 0.025, 0.01)) # botões
	for x in [-0.72, 0.72]:
		mb.color(cloth)
		mb.lathe(PackedVector2Array([Vector2(0.002, -0.37), Vector2(0.11, -0.36), Vector2(0.12, 0.0), Vector2(0.11, 0.36), Vector2(0.002, 0.37)]), 8, Basis(Vector3.RIGHT, PI / 2), Vector3(x, 0.45, 0))
		mb.color(DARK)
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.06, 0.0), Vector2(0.06, 0.02), Vector2(0.002, 0.02)]), 8, Basis(Vector3.RIGHT, -PI / 2), Vector3(x, 0.45, 0.37)) # ponteira
	mb.color(cloth.lightened(0.1))
	for x in [-0.36, 0.36]:
		mb.box(Vector3(x, 0.43, 0.04), Vector3(0.66, 0.1, 0.6))
		mb.box(Vector3(x, 0.68, -0.17), Vector3(0.62, 0.36, 0.1), Basis(Vector3.RIGHT, -0.15))
	mb.color(Color(0.78, 0.7, 0.45))
	mb.box(Vector3(-0.2, 0.52, 0.0), Vector3(0.28, 0.08, 0.28), Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -0.3))
	mb.color(Color(0.3, 0.17, 0.14))
	mb.box(Vector3(0.45, 0.483, 0.15), Vector3(0.18, 0.005, 0.12))
	mb.color(Color(0.9, 0.85, 0.6))
	mb.box(Vector3(0.45, 0.484, 0.15), Vector3(0.1, 0.006, 0.05)) # espuma aparecendo
	_shape(Vector3(0, 0.42, 0), Vector3(1.6, 0.85, 0.75))


# --- Banheiro e cozinha ----------------------------------------------------------------

func _bathtub(mb: MeshBuilder) -> void:
	# Banheira de pés de garra: casco oval em camadas com borda enrolada, fundo,
	# água parada, ralo com corrente, torneira dupla e pés de latão.
	var shells := [[0.14, 0.7, 0.3], [0.2, 0.78, 0.36], [0.55, 0.8, 0.38], [0.62, 0.83, 0.4]]
	mb.color(PORCELAIN)
	for k in 3:
		var ra := PackedVector3Array()
		var rb := PackedVector3Array()
		for i in 16:
			var a := TAU * i / 16.0
			ra.append(Vector3(cos(a) * shells[k][1], shells[k][0], sin(a) * shells[k][2]))
			rb.append(Vector3(cos(a) * shells[k + 1][1], shells[k + 1][0], sin(a) * shells[k + 1][2]))
		mb.loft([ra, rb], true, false, true)
	mb.color(PORCELAIN.lightened(0.05))
	mb.torus(0.82, 0.03, 16, 4, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.48)), Vector3(0, 0.63, 0)) # borda enrolada
	mb.color(PORCELAIN.darkened(0.1))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.25), Vector2(0.7, 0.25)]), 16, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.45)))
	mb.color(Color(0.4, 0.5, 0.45))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.35), Vector2(0.72, 0.35)]), 16, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.45)))
	mb.color(ItemModels.BRASS)
	for x in [-0.6, 0.6]:
		for z in [-0.28, 0.28]:
			mb.lathe(PackedVector2Array([Vector2(0.05, 0.0), Vector2(0.06, 0.02), Vector2(0.03, 0.07), Vector2(0.045, 0.16)]), 6, Basis.IDENTITY, Vector3(x, 0, z))
			for k in 3:
				var a := TAU * k / 3.0
				mb.box(Vector3(x + cos(a) * 0.05, 0.015, z + sin(a) * 0.05), Vector3(0.03, 0.03, 0.02), Basis(Vector3.UP, -a)) # garras
	mb.tube(PackedVector3Array([Vector3(-0.78, 0.6, 0), Vector3(-0.78, 0.86, 0), Vector3(-0.64, 0.9, 0), Vector3(-0.62, 0.86, 0)]), 0.02, 6)
	for z in [-0.09, 0.09]:
		mb.box(Vector3(-0.78, 0.76, z), Vector3(0.05, 0.02, 0.05))
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.03, 0.0), Vector2(0.002, 0.03)]), 4, Basis.IDENTITY, Vector3(-0.78, 0.77, z)) # registros
	mb.color(ItemModels.STEEL)
	mb.tube(PackedVector3Array([Vector3(-0.55, 0.36, 0), Vector3(-0.6, 0.5, 0.05), Vector3(-0.78, 0.62, 0.05)]), 0.004, 3) # corrente do ralo
	_shape(Vector3(0, 0.38, 0), Vector3(1.6, 0.76, 0.75))


func _toilet(mb: MeshBuilder) -> void:
	# Privada com caixa d'água alta: bacia torneada, assento de madeira com tampa
	# levantada, cano até a caixa de porcelana na parede, corrente com puxador.
	mb.color(PORCELAIN)
	mb.lathe(PackedVector2Array([Vector2(0.13, 0.0), Vector2(0.1, 0.15), Vector2(0.16, 0.38), Vector2(0.18, 0.4)]), 12, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 1.25)), Vector3(0, 0, 0.06))
	mb.color(Color(0.35, 0.42, 0.38))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.33), Vector2(0.12, 0.33)]), 10, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 1.25)), Vector3(0, 0, 0.06))
	mb.color(WOOD)
	mb.torus(0.165, 0.028, 12, 4, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 1.25)), Vector3(0, 0.425, 0.06)) # assento
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.19, 0.0), Vector2(0.19, 0.025), Vector2(0.002, 0.025)]), 12,
		Basis(Vector3.RIGHT, -1.45) * Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 1.25)), Vector3(0, 0.44, -0.16)) # tampa levantada
	mb.color(PORCELAIN)
	mb.box(Vector3(0, 1.5, -0.24), Vector3(0.44, 0.3, 0.16)) # caixa alta
	mb.box(Vector3(0, 1.66, -0.24), Vector3(0.47, 0.03, 0.19))
	mb.color(WOOD.darkened(0.2))
	for x in [-0.18, 0.18]:
		mb.box(Vector3(x, 1.33, -0.26), Vector3(0.04, 0.06, 0.12)) # mão-francesa
	mb.color(ItemModels.BRASS)
	mb.tube(PackedVector3Array([Vector3(0, 1.35, -0.22), Vector3(0, 0.6, -0.22), Vector3(0, 0.42, -0.12)]), 0.02, 6) # cano
	mb.box(Vector3(0.2, 1.5, -0.15), Vector3(0.08, 0.02, 0.02)) # alavanca
	mb.tube(PackedVector3Array([Vector3(0.24, 1.5, -0.15), Vector3(0.24, 1.0, -0.14)]), 0.004, 3) # corrente
	mb.color(WOOD)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.92), Vector2(0.015, 0.94), Vector2(0.015, 0.98), Vector2(0.002, 1.0)]), 6, Basis.IDENTITY, Vector3(0.24, 0, -0.14))
	_shape(Vector3(0, 0.4, 0), Vector3(0.45, 0.8, 0.6))


func _sink(mb: MeshBuilder) -> void:
	# Pia de coluna com bacia de borda larga, torneira dupla, espelho com moldura
	# e uma rachadura, prateleirinha com sabão e escova.
	mb.color(PORCELAIN)
	mb.lathe(PackedVector2Array([Vector2(0.09, 0.0), Vector2(0.07, 0.04), Vector2(0.05, 0.3), Vector2(0.07, 0.72)]), 10, Basis.IDENTITY, Vector3(0, 0, -0.05))
	mb.lathe(PackedVector2Array([Vector2(0.12, 0.72), Vector2(0.27, 0.8), Vector2(0.3, 0.87), Vector2(0.29, 0.89), Vector2(0.25, 0.89), Vector2(0.22, 0.82), Vector2(0.002, 0.8)]), 12, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.75)))
	mb.color(Color(0.3, 0.3, 0.3))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.802), Vector2(0.025, 0.802)]), 6) # ralo
	mb.color(Color(0.55, 0.6, 0.62))
	mb.box(Vector3(0, 1.3, -0.19), Vector3(0.4, 0.5, 0.02))
	mb.color(WOOD)
	for x in [-0.21, 0.21]:
		mb.box(Vector3(x, 1.3, -0.18), Vector3(0.04, 0.58, 0.03))
	for y in [1.03, 1.57]:
		mb.box(Vector3(0, y, -0.18), Vector3(0.46, 0.04, 0.03))
	mb.box(Vector3(0, 0.98, -0.16), Vector3(0.42, 0.02, 0.08)) # prateleirinha
	mb.color(Color(0.92, 0.85, 0.6))
	mb.box(Vector3(-0.12, 1.0, -0.15), Vector3(0.07, 0.025, 0.045)) # sabão
	mb.color(WOOD.lightened(0.2))
	mb.box(Vector3(0.12, 1.0, -0.15), Vector3(0.12, 0.015, 0.02)) # escova
	mb.color(Color(0.4, 0.42, 0.45))
	mb.box(Vector3(-0.1, 1.4, -0.177), Vector3(0.12, 0.2, 0.002), Basis(Vector3.BACK, 0.5))
	mb.color(ItemModels.BRASS)
	mb.tube(PackedVector3Array([Vector3(0, 0.88, -0.17), Vector3(0, 0.98, -0.17), Vector3(0, 0.98, -0.08)]), 0.015, 6)
	for x in [-0.09, 0.09]:
		mb.box(Vector3(x, 0.92, -0.17), Vector3(0.045, 0.02, 0.045))
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.025, 0.0), Vector2(0.002, 0.03)]), 4, Basis.IDENTITY, Vector3(x, 0.93, -0.17))
	_shape(Vector3(0, 0.5, 0), Vector3(0.55, 1.0, 0.42))


func _counter(mb: MeshBuilder) -> void:
	# Balcão de cozinha: corpo com rodapé recuado, três portas de almofada com
	# puxadores e gavetas em cima, tampo de pedra com veios, cuba de ágata com
	# torneira, panela, tábua de cortar com faca e cebolas.
	mb.color(WOOD.darkened(0.08))
	mb.box(Vector3(0, 0.46, -0.02), Vector3(1.6, 0.8, 0.56))
	mb.color(DARK)
	mb.box(Vector3(0, 0.03, 0.0), Vector3(1.6, 0.06, 0.54))
	for x in [-0.53, 0.0, 0.53]:
		_panel_door(mb, Vector3(x, 0.34, 0.27), 0.5, 0.48)
		_panel_door(mb, Vector3(x, 0.71, 0.27), 0.5, 0.15)
		_knob(mb, Vector3(x + 0.19, 0.42, 0.29))
		_pull(mb, Vector3(x, 0.71, 0.29))
	mb.color(Color(0.5, 0.48, 0.45))
	mb.box(Vector3(0, 0.885, 0), Vector3(1.64, 0.05, 0.64))
	mb.color(Color(0.42, 0.4, 0.38))
	mb.box(Vector3(0.0, 0.911, -0.1), Vector3(0.5, 0.002, 0.02))
	mb.box(Vector3(-0.5, 0.911, 0.12), Vector3(0.3, 0.002, 0.015), Basis(Vector3.UP, 0.4))
	mb.color(Color(0.86, 0.86, 0.82))
	mb.box(Vector3(0.45, 0.88, 0.0), Vector3(0.42, 0.06, 0.36)) # cuba
	mb.color(Color(0.6, 0.62, 0.62))
	mb.box(Vector3(0.45, 0.875, 0.0), Vector3(0.36, 0.06, 0.3))
	mb.color(ItemModels.BRASS)
	mb.tube(PackedVector3Array([Vector3(0.45, 0.91, -0.24), Vector3(0.45, 1.06, -0.24), Vector3(0.45, 1.06, -0.12), Vector3(0.45, 1.0, -0.1)]), 0.014, 6)
	mb.color(ItemModels.STEEL)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.91), Vector2(0.1, 0.91), Vector2(0.11, 1.02), Vector2(0.115, 1.03)]), 10, Basis.IDENTITY, Vector3(-0.05, 0, -0.1))
	mb.color(Color(0.6, 0.45, 0.25))
	mb.box(Vector3(-0.5, 0.92, 0.1), Vector3(0.35, 0.03, 0.22))
	mb.color(ItemModels.STEEL)
	mb.box(Vector3(-0.5, 0.94, 0.1), Vector3(0.2, 0.005, 0.03), Basis(Vector3.UP, 0.3))
	mb.color(Color(0.82, 0.66, 0.4))
	for k in 2:
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.035, 0.02), Vector2(0.03, 0.05), Vector2(0.002, 0.07)]), 6, Basis.IDENTITY, Vector3(-0.68 + k * 0.07, 0.935, -0.1)) # cebolas
	_shape(Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.6))


func _dresser(mb: MeshBuilder) -> void:
	# Cômoda: corpo com laterais de almofada, tampo com borda, pés torneados,
	# três gavetas com filete e puxadores, espelho com moldura torneada e um vaso.
	mb.color(DARK)
	mb.box(Vector3(0, 0.48, -0.01), Vector3(0.9, 0.82, 0.43))
	mb.color(DARK.lightened(0.06))
	mb.box(Vector3(0, 0.91, 0.01), Vector3(0.96, 0.04, 0.5))
	for x in [-0.4, 0.4]:
		for z in [-0.18, 0.18]:
			_leg(mb, Vector3(x, 0, z), 0.07, 0.03)
	for y in [0.26, 0.51, 0.76]:
		_panel_door(mb, Vector3(0, y, 0.215), 0.84, 0.22)
		for x in [-0.25, 0.25]:
			_pull(mb, Vector3(x, y, 0.235), 0.08)
	mb.color(DARK)
	mb.box(Vector3(0, 1.28, -0.21), Vector3(0.66, 0.66, 0.03))
	mb.color(Color(0.6, 0.62, 0.65))
	mb.box(Vector3(0, 1.28, -0.19), Vector3(0.58, 0.58, 0.01))
	for x in [-0.34, 0.34]:
		mb.color(DARK.lightened(0.08))
		mb.lathe(PackedVector2Array([Vector2(0.02, 0.92), Vector2(0.015, 1.1), Vector2(0.022, 1.3), Vector2(0.015, 1.55), Vector2(0.025, 1.6)]), 6, Basis.IDENTITY, Vector3(x, 0, -0.21))
	mb.color(Color(0.85, 0.82, 0.75))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.93), Vector2(0.05, 0.93), Vector2(0.06, 1.04), Vector2(0.03, 1.1), Vector2(0.035, 1.12)]), 8, Basis.IDENTITY, Vector3(-0.3, 0, 0.05))
	mb.color(Color(0.3, 0.5, 0.2))
	for k in 3:
		mb.box(Vector3(-0.3 + (k - 1) * 0.03, 1.17, 0.05), Vector3(0.012, 0.12, 0.012), Basis(Vector3.BACK, (k - 1) * 0.3)) # flores secas
	_shape(Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.45))


func _shape(center: Vector3, size: Vector3) -> void:
	_shape_log.append([center, size])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	add_child(shape)
