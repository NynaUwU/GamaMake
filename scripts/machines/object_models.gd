class_name ObjectModels
extends RefCounted
## Modelos dos objetos do martelo anteriores ao Tier 3 (plantadores, estações,
## máquinas de manivela e de energia), no mesmo padrão das máquinas a vapor:
## estilo PS2 (poucos polígonos, fosco), tábuas com frestas e tons alternados,
## fiadas de tijolo, cintas de ferro rebitadas, polias de latão nas portas de
## energia e efeitos (fogo, fumaça, respingos).
## Contratos que a lógica usa (não mudar sem mexer nela):
##   "Crank"  parte movida pela manivela (Machines._spin; meta "crank_mode")
##   "Spin"   parte girada pela energia (PowerSpin)
##   "Water"  água do coletor (escala em Y)
##   fogo     StationModels._fire / _register_fire (acende com set_lit)
##   vagas    PlacedObject.slot_positions (plantas, grelha, ganchos...)

const KINDS := ["flag", "pot_small", "pot_wide", "bed", "ground", "bench", "workbench", "campfire", "furnace", "chest",
	"dryer", "rain_collector", "grindstone", "quern", "pump", "spinning", "loom", "stone_furnace", "oven", "filter",
	"smoker", "compost", "sieve", "shaft", "water_wheel", "windmill", "sawmill", "ram_pump"]

const WOOD := Color(0.42, 0.28, 0.16)
const WOOD_DARK := Color(0.3, 0.2, 0.12)
const WOOD_LIGHT := Color(0.55, 0.4, 0.25)
const STONE := Color(0.5, 0.48, 0.45)
const IRON := Color(0.24, 0.23, 0.23)
const STEEL := Color(0.5, 0.51, 0.53)
const BRASS := Color(0.62, 0.5, 0.26)
const COPPER := Color(0.72, 0.42, 0.25)
const BRICK := Color(0.6, 0.3, 0.2)
const CLAY := Color(0.64, 0.36, 0.22)
const SOIL := Color(0.34, 0.23, 0.15)
const CLOTH := Color(0.84, 0.8, 0.68)
const ROPE := Color(0.62, 0.55, 0.42)
const SOOT := Color(0.1, 0.08, 0.07)
const WATER := Color(0.3, 0.48, 0.62)

const AROUND_X := Basis(Vector3(0, 0, 1), PI / 2) # torno em X (o perfil cresce para -X)
const AROUND_Z := Basis(Vector3(1, 0, 0), PI / 2) # torno em Z


static func has(kind: String) -> bool:
	return kind in KINDS


static func build(kind: String, obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	var crank := MeshBuilder.new()
	var crank_at := Vector3.ZERO
	var spin := MeshBuilder.new()
	var spin_at := Vector3.ZERO
	var spin_axis := Vector3.RIGHT
	match kind:
		"flag": _flag(mb, obj)
		"pot_small": _pot_small(mb, obj)
		"pot_wide": _pot_wide(mb, obj)
		"bed": _bed(mb, obj)
		"ground": _ground(mb, obj)
		"bench": _bench(mb, obj)
		"workbench": _workbench(mb, obj)
		"campfire": _campfire(mb, obj)
		"furnace": _furnace(mb, obj)
		"chest": _chest(mb, obj)
		"dryer": _dryer(mb, obj)
		"rain_collector": _rain_collector(mb, obj)
		"grindstone":
			crank_at = Vector3(0, 0.78, 0)
			obj.set_meta("crank_mode", "spin_x") # a pedra gira no eixo entre os mancais (X)
			_grindstone(mb, crank, obj)
		"quern":
			crank_at = Vector3(0, 0.74, 0)
			obj.set_meta("crank_mode", "spin_up")
			_quern(mb, crank, obj)
		"pump":
			crank_at = Vector3(0, 1.12, -0.05)
			obj.set_meta("crank_mode", "swing")
			_pump(mb, crank, obj)
		"spinning":
			crank_at = Vector3(0.25, 0.72, 0)
			_spinning(mb, crank, obj)
		"loom":
			crank_at = Vector3(0, 0.98, -0.1)
			obj.set_meta("crank_mode", "bob")
			_loom(mb, crank, obj)
		"stone_furnace":
			crank_at = Vector3(0.62, 0.48, 0.42)
			obj.set_meta("crank_mode", "swing")
			_stone_furnace(mb, crank, obj)
		"oven": _oven(mb, obj)
		"filter": _filter(mb, obj)
		"smoker": _smoker(mb, obj)
		"compost": _compost(mb, obj)
		"sieve":
			crank_at = Vector3(0, 0.74, 0)
			obj.set_meta("crank_mode", "shake")
			_sieve(mb, crank, obj)
		"shaft":
			spin_at = Vector3(0, 0.6, 0)
			_shaft(mb, spin, obj)
		"water_wheel":
			spin_at = Vector3(0, 0.6, -1.6)
			spin_axis = Vector3.BACK
			_water_wheel(mb, spin, obj)
		"windmill":
			spin_at = Vector3(0, 3.62, 0.78)
			spin_axis = Vector3.BACK
			_windmill(mb, spin, obj)
		"sawmill":
			spin_at = Vector3(0, 0.88, 0)
			spin_axis = Vector3.BACK
			_sawmill(mb, spin, obj)
		"ram_pump": _ram_pump(mb, obj)
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	if spin_at != Vector3.ZERO:
		var node := MeshInstance3D.new()
		node.name = "Spin"
		node.mesh = spin.finish(PlacedObject._mat(), false)
		node.position = spin_at
		obj.add_child(node)
		var spinner := PowerSpin.new()
		spinner.axis = spin_axis
		obj.add_child(spinner)
	if crank_at != Vector3.ZERO:
		var node := MeshInstance3D.new()
		node.name = "Crank"
		node.mesh = crank.finish(PlacedObject._mat(), false)
		node.position = crank_at
		obj.add_child(node)
		obj.set_meta("crank_base", crank_at)


# --- Ajudantes ------------------------------------------------------------------------

## Tábuas deitadas formando um painel (frestas e tons alternados).
static func _slats(mb: MeshBuilder, center: Vector3, length: float, height: float, thick: float, count: int, along_x: bool, color: Color, gap := 0.012) -> void:
	var h := height / count
	for k in count:
		mb.color(color.darkened(0.07 * ((k * 7 + 3) % 3)))
		var y := center.y - height * 0.5 + h * (k + 0.5)
		var size := Vector3(length, h - gap, thick) if along_x else Vector3(thick, h - gap, length)
		mb.box(Vector3(center.x, y, center.z), size)


## Tábuas em pé lado a lado (tampo, piso, porta).
static func _boards(mb: MeshBuilder, center: Vector3, size: Vector3, count: int, along_x: bool, color: Color, gap := 0.01) -> void:
	var span := size.z if along_x else size.x
	var w := span / count
	for k in count:
		mb.color(color.darkened(0.06 * ((k * 5 + 1) % 3)))
		var off := -span * 0.5 + w * (k + 0.5)
		if along_x:
			mb.box(center + Vector3(0, 0, off), Vector3(size.x, size.y, w - gap))
		else:
			mb.box(center + Vector3(off, 0, 0), Vector3(w - gap, size.y, size.z))


## Bloco de tijolo em fiadas (alternando o tom; um ou outro tijolo saltado).
static func _bricks(mb: MeshBuilder, center: Vector3, size: Vector3, rows: int, color := BRICK) -> void:
	var h := size.y / rows
	for r in rows:
		mb.color(color if r % 2 == 0 else color.darkened(0.09))
		var y := center.y - size.y * 0.5 + h * (r + 0.5)
		mb.box(Vector3(center.x, y, center.z), Vector3(size.x - (r % 2) * 0.01, h - 0.012, size.z - (r % 2) * 0.01))


## Boca de fornalha numa face virada para +Z ("center" fica bem na face):
## buraco escuro rente à face, moldura de ferro e porta presa na dobradiça da
## esquerda, aberta para fora ("open" em radianos; 0 = fechada).
static func mouth(mb: MeshBuilder, center: Vector3, w: float, h: float, open := 1.15, frame := IRON) -> void:
	mb.color(SOOT)
	mb.box(center + Vector3(0, 0, 0.006), Vector3(w, h, 0.012))
	var t := 0.035
	mb.color(frame)
	for side in [-1.0, 1.0]:
		mb.box(center + Vector3(0, side * (h * 0.5 + t * 0.5), 0.012), Vector3(w + 2.0 * t, t, 0.024))
		mb.box(center + Vector3(side * (w * 0.5 + t * 0.5), 0, 0.012), Vector3(t, h, 0.024))
	var hinge := center + Vector3(-w * 0.5 - t * 0.5, 0, 0.03)
	var basis := Basis(Vector3.UP, -open)
	var along := basis * Vector3.RIGHT
	mb.color(frame.lightened(0.08))
	mb.box(hinge + along * (w * 0.5 + t * 0.5), Vector3(w + t, h + t, 0.025), basis) # porta
	mb.color(frame.darkened(0.2))
	for k in 3:
		mb.box(hinge + along * (w * 0.3 + k * w * 0.2) + basis * Vector3(0, 0.0, 0.016), Vector3(0.05, h * 0.25, 0.01), basis) # respiros
	for y in [-h * 0.3, h * 0.3]:
		mb.box(hinge + Vector3(0, y, 0), Vector3(0.04, 0.06, 0.04)) # dobradiças
	mb.color(BRASS)
	mb.box(hinge + along * (w * 0.92) + basis * Vector3(0, 0, 0.025), Vector3(0.03, 0.06, 0.03), basis) # trinco


static func _nail(mb: MeshBuilder, at: Vector3, color := IRON) -> void:
	mb.color(color)
	mb.box(at, Vector3(0.014, 0.014, 0.014))


## Cinta de ferro em volta de um tambor/coluna (anel no plano XZ).
static func _hoop(mb: MeshBuilder, at: Vector3, radius: float, segments := 12, width := 0.04) -> void:
	mb.color(IRON)
	mb.lathe(PackedVector2Array([Vector2(radius, -width * 0.5), Vector2(radius + 0.012, -width * 0.5),
		Vector2(radius + 0.012, width * 0.5), Vector2(radius, width * 0.5)]), segments, Basis.IDENTITY, at)


## Polia de latão numa porta de energia (eixo X ou Z), com mancal de ferro atrás.
static func _pulley(mb: MeshBuilder, at: Vector3, along_x: bool, radius := 0.1) -> void:
	var basis := AROUND_X if along_x else AROUND_Z
	mb.color(BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.002, -0.04), Vector2(radius, -0.04), Vector2(radius - 0.015, 0.0),
		Vector2(radius, 0.04), Vector2(0.002, 0.04)]), 12, basis, at)
	mb.color(BRASS.darkened(0.25))
	mb.lathe(PackedVector2Array([Vector2(0.002, -0.05), Vector2(0.025, -0.05), Vector2(0.025, 0.05), Vector2(0.002, 0.05)]), 6, basis, at)


## Pedras irregulares em anel (base de fogueira, de fornalha).
static func _stone_ring(mb: MeshBuilder, center: Vector3, radius: float, count: int, size: Vector3, seed := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in count:
		var a := TAU * k / count + rng.randf_range(-0.08, 0.08)
		var s := size * Vector3(rng.randf_range(0.8, 1.2), rng.randf_range(0.75, 1.15), rng.randf_range(0.85, 1.15))
		mb.color(STONE.darkened(rng.randf_range(0.0, 0.22)))
		mb.box(center + Vector3(cos(a) * radius, s.y * 0.5, sin(a) * radius), s,
			Basis(Vector3.UP, -a + rng.randf_range(-0.2, 0.2)) * Basis(Vector3.BACK, rng.randf_range(-0.15, 0.15)))


static func _smoke(obj: PlacedObject, at: Vector3, width: float, lit_only := true) -> CPUParticles3D:
	var smoke := SteamModels._smoke(at, width)
	obj.add_child(smoke)
	if lit_only:
		StationModels._register_fire(obj, smoke)
	else:
		smoke.emitting = true
	return smoke


static func _drops(obj: PlacedObject, at: Vector3, dir: Vector3, amount: int, speed: float, spread: float) -> CPUParticles3D:
	var spray := CPUParticles3D.new()
	spray.amount = amount
	spray.lifetime = 1.0
	spray.position = at
	spray.direction = dir
	spray.spread = spread
	spray.gravity = Vector3(0, -7, 0)
	spray.initial_velocity_min = speed * 0.7
	spray.initial_velocity_max = speed
	var drop := BoxMesh.new()
	drop.size = Vector3.ONE * 0.03
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.75, 0.9, 0.6)
	drop.material = mat
	spray.mesh = drop
	obj.add_child(spray)
	return spray


# --- Bandeira e plantadores ---------------------------------------------------------------

static func _flag(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Monte de pedras com argamassa, mastro torneado com anéis de ferro, ponteira de
	# latão, cunho para amarrar a corda e pano ondulado com bainha e emblema.
	_stone_ring(mb, Vector3.ZERO, 0.16, 7, Vector3(0.15, 0.13, 0.12), 4)
	_stone_ring(mb, Vector3(0, 0.1, 0), 0.08, 5, Vector3(0.12, 0.1, 0.1), 7)
	mb.color(STONE.lightened(0.15))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.2), Vector2(0.12, 0.18), Vector2(0.14, 0.15)]), 8) # argamassa
	mb.color(WOOD)
	mb.lathe(PackedVector2Array([Vector2(0.045, 0.0), Vector2(0.042, 0.8), Vector2(0.035, 2.0), Vector2(0.03, 2.62)]), 8)
	for y in [0.3, 1.2, 2.1]:
		_hoop(mb, Vector3(0, y, 0), 0.04 - y * 0.004, 8, 0.03)
	mb.color(BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.03, 2.62), Vector2(0.05, 2.65), Vector2(0.055, 2.7), Vector2(0.04, 2.75), Vector2(0.012, 2.78), Vector2(0.002, 2.86)]), 8)
	mb.color(IRON)
	mb.box(Vector3(0.05, 1.0, 0), Vector3(0.04, 0.12, 0.03)) # cunho
	mb.box(Vector3(0.06, 1.0, 0), Vector3(0.015, 0.2, 0.025))
	mb.color(ROPE)
	mb.tube(PackedVector3Array([Vector3(0.035, 2.55, 0.02), Vector3(0.05, 1.8, 0.03), Vector3(0.065, 1.05, 0.02)]), 0.006, 3)
	mb.tube(PackedVector3Array([Vector3(0.035, 2.08, -0.02), Vector3(0.055, 1.5, -0.02), Vector3(0.065, 0.97, -0.01)]), 0.006, 3)
	var cloth := []
	for r in 7:
		var row := PackedVector3Array()
		for c in 10:
			var x := 0.04 + c * 0.075
			row.append(Vector3(x, 2.55 - r * 0.075, sin(c * 0.9 + r * 0.35) * 0.06 * (c / 9.0)))
		cloth.append(row)
	mb.color(Color(0.78, 0.12, 0.1))
	mb.sheet(cloth)
	mb.color(Color(0.62, 0.08, 0.07))
	mb.box(Vector3(0.05, 2.33, 0.0), Vector3(0.03, 0.46, 0.02)) # bainha do mastro
	mb.color(Color(0.95, 0.9, 0.8))
	mb.box(Vector3(0.4, 2.33, sin(4.4) * 0.03), Vector3(0.13, 0.13, 0.025), Basis(Vector3.BACK, PI / 4)) # emblema
	mb.color(Color(0.78, 0.12, 0.1))
	mb.box(Vector3(0.4, 2.33, sin(4.4) * 0.03 + 0.004), Vector3(0.06, 0.06, 0.025), Basis(Vector3.BACK, PI / 4))
	obj._shape(Vector3(0, 1.2, 0), Vector3(0.2, 2.6, 0.2))


static func _pot_small(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Vaso de barro torneado com borda grossa, faixas pintadas em zigue-zague,
	# pratinho embaixo e terra com torrões e pedrinhas (planta em y = 0,3).
	mb.color(CLAY.darkened(0.1))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.2, 0.0), Vector2(0.21, 0.02), Vector2(0.19, 0.03), Vector2(0.002, 0.03)]), 14) # pratinho
	mb.color(CLAY)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.02), Vector2(0.14, 0.02), Vector2(0.16, 0.04), Vector2(0.205, 0.23),
		Vector2(0.235, 0.25), Vector2(0.245, 0.29), Vector2(0.23, 0.31), Vector2(0.2, 0.31), Vector2(0.185, 0.28)]), 14)
	mb.color(Color(0.86, 0.76, 0.56))
	for k in 12:
		var a := TAU * k / 12.0
		var r := 0.183
		mb.box(Vector3(cos(a) * r, 0.14 + (0.02 if k % 2 == 0 else -0.02), sin(a) * r), Vector3(0.012, 0.05, 0.006), Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.7 if k % 2 == 0 else -0.7))
	mb.color(CLAY.darkened(0.3))
	mb.lathe(PackedVector2Array([Vector2(0.168, 0.075), Vector2(0.172, 0.09)]), 14)
	mb.lathe(PackedVector2Array([Vector2(0.199, 0.2), Vector2(0.203, 0.215)]), 14)
	mb.color(SOIL)
	mb.lathe(PackedVector2Array([Vector2(0.19, 0.27), Vector2(0.12, 0.285), Vector2(0.002, 0.292)]), 12)
	for k in 6:
		mb.color(SOIL.lightened(0.08 + 0.06 * (k % 2)))
		mb.box(Vector3(cos(k * 1.1) * 0.12, 0.29, sin(k * 1.1) * 0.12), Vector3(0.03, 0.016, 0.025), Basis(Vector3.UP, k))
	mb.color(STONE.lightened(0.1))
	mb.box(Vector3(0.06, 0.292, -0.09), Vector3(0.025, 0.012, 0.02))
	obj._shape(Vector3(0, 0.155, 0), Vector3(0.42, 0.31, 0.42))


static func _pot_wide(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Floreira de tábuas: pés, laterais em duas tábuas, cantoneiras rebitadas,
	# alças de ferro nas pontas e terra fofa (plantas em x = -0,4 / 0 / 0,4).
	mb.color(WOOD_DARK)
	for x in [-0.56, 0.56]:
		for z in [-0.18, 0.18]:
			mb.box(Vector3(x, 0.035, z), Vector3(0.09, 0.07, 0.09))
	mb.color(WOOD.darkened(0.1))
	mb.box(Vector3(0, 0.085, 0), Vector3(1.22, 0.04, 0.44)) # fundo
	for side in [-1.0, 1.0]:
		_slats(mb, Vector3(0, 0.215, side * 0.215), 1.24, 0.25, 0.04, 2, true, WOOD)
		_slats(mb, Vector3(side * 0.6, 0.215, 0), 0.4, 0.25, 0.04, 2, false, WOOD)
	for x in [-0.6, 0.6]:
		for z in [-0.215, 0.215]:
			mb.color(IRON)
			mb.box(Vector3(x, 0.215, z), Vector3(0.075, 0.26, 0.075))
			for y in [0.13, 0.3]:
				_nail(mb, Vector3(x + signf(x) * 0.039, y, z), BRASS)
	for side in [-1.0, 1.0]:
		mb.color(IRON.lightened(0.1))
		mb.tube(PackedVector3Array([Vector3(side * 0.64, 0.24, -0.08), Vector3(side * 0.68, 0.26, 0.0), Vector3(side * 0.64, 0.24, 0.08)]), 0.009, 4) # alça
		for x in [-0.4, 0.0, 0.4]:
			_nail(mb, Vector3(x, 0.15, side * 0.237))
			_nail(mb, Vector3(x, 0.28, side * 0.237))
	mb.color(SOIL)
	mb.box(Vector3(0, 0.3, 0), Vector3(1.14, 0.05, 0.38))
	for k in 10:
		mb.color(SOIL.lightened(0.08 + 0.06 * (k % 2)))
		mb.box(Vector3(-0.52 + k * 0.115, 0.33, sin(k * 2.0) * 0.12), Vector3(0.05, 0.02, 0.04), Basis(Vector3.UP, k))
	obj._shape(Vector3(0, 0.18, 0), Vector3(1.24, 0.36, 0.48))


static func _bed(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Canteiro na grade (origem no canto, 2,8 m): moldura de dormentes em duas
	# fiadas com estacas nos cantos e chapas de ferro, terra em leiras (3 fileiras
	# de 3 plantas, y = 0,22), sulcos de água e plaquinhas de cada fileira.
	var s := BuildPiece.SIZE
	var t := BuildPiece.THICK
	var y0 := -t
	for course in 2:
		var y := y0 + 0.1 + course * 0.2
		for side in [0.0, 1.0]:
			mb.color(WOOD_DARK.lightened(0.05 * course))
			mb.box(Vector3(s * 0.5, y, side * s + (0.07 if side == 0.0 else -0.07)), Vector3(s, 0.18, 0.14))
			mb.color(WOOD_DARK.lightened(0.05 * (1 - course)))
			mb.box(Vector3(side * s + (0.07 if side == 0.0 else -0.07), y, s * 0.5), Vector3(0.14, 0.18, s - 0.28))
	for x in [0.07, s - 0.07]:
		for z in [0.07, s - 0.07]:
			mb.color(WOOD.darkened(0.1))
			mb.box(Vector3(x, 0.15, z), Vector3(0.1, 0.5, 0.1)) # estaca do canto
			mb.color(IRON)
			mb.box(Vector3(x, 0.1, z), Vector3(0.17, 0.1, 0.17)) # chapa
			for k in 2:
				_nail(mb, Vector3(x + (0.09 if x < 1.0 else -0.09), 0.1, z + (k - 0.5) * 0.08), BRASS)
	var earth := Color(0.24, 0.16, 0.1)
	mb.color(earth)
	mb.box(Vector3(s * 0.5, (0.15 + y0) * 0.5, s * 0.5), Vector3(s - 0.28, 0.15 - y0, s - 0.28))
	for j in 3:
		var z := 0.47 + j * 0.93
		mb.color(earth.lightened(0.08))
		mb.box(Vector3(s * 0.5, 0.17, z), Vector3(s - 0.36, 0.05, 0.46), Basis.IDENTITY) # leira (monte de terra)
		mb.color(earth.lightened(0.14))
		mb.box(Vector3(s * 0.5, 0.2, z), Vector3(s - 0.42, 0.03, 0.3))
		for k in 12:
			mb.color(earth.lightened(0.05 + 0.08 * (k % 3)))
			var x := 0.3 + k * 0.2 + (j % 2) * 0.08
			mb.box(Vector3(x, 0.215, z + sin(k * 1.7 + j) * 0.12), Vector3(0.06, 0.03, 0.05), Basis(Vector3.UP, k * 0.9)) # torrões
		mb.color(Color(0.92, 0.88, 0.78))
		mb.box(Vector3(0.22, 0.32, z + 0.24), Vector3(0.1, 0.07, 0.01)) # plaquinha
		mb.color(WOOD_LIGHT)
		mb.box(Vector3(0.22, 0.22, z + 0.24), Vector3(0.015, 0.2, 0.015))
	mb.color(earth.darkened(0.45))
	for j in 2:
		mb.box(Vector3(s * 0.5, 0.152, 0.93 * (j + 1)), Vector3(s - 0.34, 0.012, 0.16)) # sulco
	mb.color(WATER.darkened(0.2))
	mb.box(Vector3(s * 0.5 + 0.4, 0.156, 0.93), Vector3(0.6, 0.01, 0.09)) # poça no sulco
	_basket(mb, Vector3(s * 0.5, 0.19, s * 0.5))
	obj._shape(Vector3(s * 0.5, (0.22 - t) * 0.5, s * 0.5), Vector3(s, 0.22 + t, s))
	obj._shape(Vector3(s * 0.5, 0.19 + 0.17, s * 0.5), Vector3(0.6, 0.34, 0.5)) # cesto (mira e colisão)
	# O que já foi colhido aparece dentro do cesto ("Fill").
	var fill := MeshBuilder.new()
	var produce := [Color(0.86, 0.42, 0.1), Color(0.85, 0.72, 0.35), Color(0.82, 0.8, 0.9), Color(0.86, 0.45, 0.1), Color(0.95, 0.94, 0.9)]
	for k in 9:
		fill.color(produce[k % produce.size()])
		fill.box(Vector3(-0.17 + (k % 3) * 0.17, (k / 3) * 0.015, -0.12 + (k / 3) * 0.12), Vector3(0.12, 0.08, 0.1), Basis(Vector3.UP, k * 0.8))
	var node := MeshInstance3D.new()
	node.name = "Fill"
	node.mesh = fill.finish(PlacedObject._mat(), false)
	node.position = Vector3(s * 0.5, 0.19 + 0.27, s * 0.5)
	node.visible = false
	obj.add_child(node)


## Cesto de vime no meio do canteiro: corpo trançado (faixas alternadas), borda
## grossa e alça em arco. Tudo que é colhido no canteiro vai para ele.
static func _basket(mb: MeshBuilder, at: Vector3) -> void:
	var wicker := Color(0.66, 0.5, 0.28)
	var w := 0.56
	var d := 0.44
	var h := 0.32
	mb.color(wicker.darkened(0.2))
	mb.box(at + Vector3(0, 0.02, 0), Vector3(w - 0.04, 0.04, d - 0.04)) # fundo
	for row in 5:
		var y := 0.05 + row * 0.06
		for side in [-1.0, 1.0]:
			mb.color(wicker.darkened(0.08 * ((row + (1 if side > 0 else 0)) % 2)))
			mb.box(at + Vector3(0, y, side * d * 0.5), Vector3(w, 0.055, 0.03))
			mb.color(wicker.darkened(0.08 * ((row + (0 if side > 0 else 1)) % 2)))
			mb.box(at + Vector3(side * w * 0.5, y, 0), Vector3(0.03, 0.055, d))
	for k in 7:
		mb.color(wicker.darkened(0.25))
		var x := -w * 0.5 + 0.04 + k * (w - 0.08) / 6.0
		for side in [-1.0, 1.0]:
			mb.box(at + Vector3(x, h * 0.5 + 0.02, side * (d * 0.5 + 0.012)), Vector3(0.015, h, 0.01)) # varetas
	mb.color(wicker.lightened(0.08))
	for side in [-1.0, 1.0]:
		mb.box(at + Vector3(0, h + 0.02, side * d * 0.5), Vector3(w + 0.04, 0.04, 0.05)) # borda
		mb.box(at + Vector3(side * w * 0.5, h + 0.02, 0), Vector3(0.05, 0.04, d + 0.04))
	mb.color(wicker.darkened(0.1))
	var arc := PackedVector3Array()
	for k in 9:
		var a := PI * k / 8.0
		arc.append(at + Vector3(cos(a) * w * 0.42, h + 0.04 + sin(a) * 0.22, 0))
	mb.tube(arc, 0.018, 5) # alça


static func _ground(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Cova: terra revirada em monte, borda de torrões, buraco úmido, pedrinhas e
	# um graveto marcando o lugar.
	mb.color(SOIL)
	mb.lathe(PackedVector2Array([Vector2(0.48, -0.05), Vector2(0.43, 0.03), Vector2(0.32, 0.075), Vector2(0.16, 0.065), Vector2(0.002, 0.035)]), 12)
	mb.color(SOIL.darkened(0.35))
	mb.lathe(PackedVector2Array([Vector2(0.13, 0.064), Vector2(0.06, 0.05), Vector2(0.002, 0.045)]), 10)
	for k in 12:
		var a := TAU * k / 12.0 + 0.4
		var r := 0.38 + (k % 3) * 0.03
		mb.color(SOIL.lightened(0.04 + 0.05 * (k % 3)))
		mb.box(Vector3(cos(a) * r, 0.045, sin(a) * r), Vector3(0.1 + (k % 2) * 0.04, 0.065, 0.08), Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.25))
	for k in 5:
		var a := k * 1.7
		mb.color(STONE.darkened(0.05 * (k % 3)))
		mb.box(Vector3(cos(a) * 0.28, 0.07, sin(a) * 0.26), Vector3(0.045, 0.03, 0.04), Basis(Vector3.UP, a))
	mb.color(WOOD_LIGHT)
	mb.tube(PackedVector3Array([Vector3(0.3, 0.0, 0.22), Vector3(0.33, 0.28, 0.24)]), 0.012, 4)
	mb.color(Color(0.3, 0.52, 0.2))
	mb.box(Vector3(0.33, 0.27, 0.25), Vector3(0.05, 0.02, 0.03), Basis(Vector3.UP, 0.5)) # folhinha
	obj._shape(Vector3(0, 0.0, 0), Vector3(0.8, 0.12, 0.8))


# --- Estações ---------------------------------------------------------------------------------

static func _bench(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Bancada antiga (saves velhos): mesa de tábuas com torno e prateleira.
	mb.color(WOOD_DARK)
	for x in [-0.72, 0.72]:
		for z in [-0.3, 0.3]:
			mb.box(Vector3(x, 0.41, z), Vector3(0.09, 0.82, 0.09))
	_boards(mb, Vector3(0, 0.86, 0), Vector3(1.6, 0.08, 0.75), 4, true, WOOD)
	_boards(mb, Vector3(0, 0.25, 0), Vector3(1.44, 0.04, 0.6), 3, true, WOOD.darkened(0.1))
	mb.color(IRON)
	mb.box(Vector3(0.6, 0.97, 0.22), Vector3(0.16, 0.14, 0.12))
	mb.box(Vector3(0.6, 0.97, 0.34), Vector3(0.03, 0.03, 0.16))
	obj._shape(Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.75))


static func _workbench(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Mesa de trabalho: pés grossos com travessas, tampo de pranchas com marcas,
	# torno de bancada, bigorninha, gaveteiro com puxadores de latão, painel de
	# ferramentas (serrote, martelo, chave, esquadro), prateleira com potes,
	# lampião pendurado e serragem no chão.
	mb.color(WOOD_DARK)
	for x in [-0.85, 0.85]:
		for z in [-0.33, 0.33]:
			mb.box(Vector3(x, 0.45, z), Vector3(0.12, 0.9, 0.12))
		mb.box(Vector3(x, 0.15, 0), Vector3(0.08, 0.08, 0.66)) # travessa baixa
	mb.box(Vector3(0, 0.15, -0.33), Vector3(1.7, 0.08, 0.06))
	_boards(mb, Vector3(0, 0.93, 0), Vector3(1.9, 0.08, 0.85), 5, true, WOOD)
	mb.color(SOOT)
	mb.box(Vector3(-0.3, 0.972, 0.1), Vector3(0.16, 0.003, 0.12), Basis(Vector3.UP, 0.4)) # queimado
	_boards(mb, Vector3(0, 0.3, 0), Vector3(1.66, 0.04, 0.62), 4, true, WOOD.darkened(0.12)) # prateleira de baixo
	# Gaveteiro do lado direito.
	mb.color(WOOD.darkened(0.15))
	mb.box(Vector3(0.55, 0.62, 0.05), Vector3(0.5, 0.5, 0.7))
	for k in 3:
		mb.color(WOOD.lightened(0.04 * (k % 2)))
		mb.box(Vector3(0.55, 0.47 + k * 0.155, 0.405), Vector3(0.46, 0.14, 0.02))
		mb.color(BRASS)
		mb.box(Vector3(0.55, 0.47 + k * 0.155, 0.42), Vector3(0.1, 0.025, 0.02))
	# Torno de bancada e bigorninha.
	mb.color(IRON)
	mb.box(Vector3(-0.7, 1.04, 0.32), Vector3(0.2, 0.14, 0.14))
	mb.box(Vector3(-0.7, 1.04, 0.44), Vector3(0.18, 0.12, 0.04))
	mb.box(Vector3(-0.7, 1.04, 0.52), Vector3(0.03, 0.03, 0.18))
	mb.box(Vector3(-0.7, 1.04, 0.6), Vector3(0.18, 0.025, 0.025))
	mb.color(IRON.lightened(0.08))
	mb.box(Vector3(0.25, 1.02, 0.1), Vector3(0.12, 0.1, 0.14))
	mb.box(Vector3(0.25, 1.1, 0.1), Vector3(0.32, 0.06, 0.12))
	mb.box(Vector3(0.43, 1.11, 0.1), Vector3(0.08, 0.035, 0.06))
	# Painel de ferramentas atrás.
	for x in [-0.88, 0.88]:
		mb.color(WOOD_DARK)
		mb.box(Vector3(x, 1.45, -0.38), Vector3(0.08, 1.05, 0.08))
	_boards(mb, Vector3(0, 1.45, -0.4), Vector3(1.76, 0.95, 0.04), 7, false, WOOD.lightened(0.05))
	mb.color(WOOD_DARK)
	mb.box(Vector3(0, 1.95, -0.38), Vector3(1.86, 0.06, 0.12))
	var pegs := [Vector3(-0.6, 1.62, -0.37), Vector3(-0.25, 1.68, -0.37), Vector3(0.1, 1.6, -0.37), Vector3(0.45, 1.66, -0.37)]
	for p: Vector3 in pegs:
		_nail(mb, p)
	mb.color(STEEL)
	mb.extrude(PackedVector2Array([Vector2(0, 0), Vector2(0.34, 0.0), Vector2(0.34, 0.1), Vector2(0.0, 0.16)]), 0.008, Basis.IDENTITY, Vector3(-0.78, 1.42, -0.37)) # serrote
	mb.color(WOOD_LIGHT)
	mb.box(Vector3(-0.8, 1.5, -0.365), Vector3(0.08, 0.12, 0.02))
	mb.box(Vector3(-0.25, 1.48, -0.365), Vector3(0.025, 0.3, 0.02)) # cabo do martelo
	mb.color(IRON)
	mb.box(Vector3(-0.25, 1.64, -0.36), Vector3(0.12, 0.05, 0.04))
	mb.color(STEEL)
	mb.box(Vector3(0.1, 1.46, -0.365), Vector3(0.022, 0.26, 0.012)) # chave
	mb.lathe(PackedVector2Array([Vector2(0.015, -0.006), Vector2(0.03, -0.006), Vector2(0.03, 0.006), Vector2(0.015, 0.006)]), 6, AROUND_Z, Vector3(0.1, 1.6, -0.365))
	mb.box(Vector3(0.45, 1.52, -0.365), Vector3(0.02, 0.28, 0.01)) # esquadro
	mb.box(Vector3(0.53, 1.39, -0.365), Vector3(0.18, 0.02, 0.01))
	mb.color(BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.002, -0.01), Vector2(0.11, -0.01), Vector2(0.11, 0.01), Vector2(0.002, 0.01)]), 12, AROUND_Z, Vector3(0.72, 1.62, -0.37)) # engrenagem pendurada
	for k in 10:
		var a := TAU * k / 10.0
		mb.box(Vector3(0.72 + cos(a) * 0.12, 1.62 + sin(a) * 0.12, -0.37), Vector3(0.03, 0.03, 0.02), Basis(Vector3.BACK, a))
	# Prateleira com potes e o lampião.
	mb.color(WOOD)
	mb.box(Vector3(0, 1.22, -0.3), Vector3(1.6, 0.03, 0.14))
	for k in 4:
		mb.color([Color(0.55, 0.68, 0.62), CLAY, Color(0.35, 0.3, 0.25), Color(0.6, 0.6, 0.55)][k])
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.04, 0.0), Vector2(0.045, 0.08), Vector2(0.03, 0.11), Vector2(0.002, 0.11)]), 8, Basis.IDENTITY, Vector3(-0.55 + k * 0.32, 1.235, -0.3))
	mb.color(IRON)
	mb.tube(PackedVector3Array([Vector3(0.2, 1.95, -0.32), Vector3(0.2, 1.95, -0.1), Vector3(0.2, 1.85, -0.1)]), 0.008, 4)
	mb.color(BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.002, 1.62), Vector2(0.06, 1.62), Vector2(0.05, 1.66), Vector2(0.05, 1.78), Vector2(0.03, 1.82), Vector2(0.002, 1.85)]), 8, Basis.IDENTITY, Vector3(0.2, 0, -0.1))
	mb.color(Color(1.0, 0.85, 0.5))
	mb.lathe(PackedVector2Array([Vector2(0.045, 1.66), Vector2(0.045, 1.78)]), 8, Basis.IDENTITY, Vector3(0.2, 0, -0.1))
	mb.color(Color(0.72, 0.6, 0.4))
	mb.box(Vector3(-0.35, 0.01, 0.55), Vector3(0.5, 0.02, 0.3)) # serragem
	obj._shape(Vector3(0, 0.5, 0), Vector3(1.9, 1.0, 0.85))
	obj._shape(Vector3(0, 1.45, -0.4), Vector3(1.8, 1.0, 0.1))


static func _campfire(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Duas voltas de pedras com fuligem, cinza e brasas, lenha em pirâmide com casca
	# e ponta queimada, grelha de ferro (pés tortos, varetas, alça), chaleira num
	# gancho de galho e lenha de reserva do lado. Grelha em y = 0,57.
	_stone_ring(mb, Vector3.ZERO, 0.5, 12, Vector3(0.2, 0.17, 0.15), 9)
	_stone_ring(mb, Vector3(0, 0.12, 0), 0.47, 8, Vector3(0.15, 0.1, 0.12), 13)
	mb.color(SOOT)
	for k in 8:
		var a := TAU * k / 8.0
		mb.box(Vector3(cos(a) * 0.4, 0.08, sin(a) * 0.4), Vector3(0.02, 0.14, 0.12), Basis(Vector3.UP, -a))
	mb.color(Color(0.2, 0.18, 0.17))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.03), Vector2(0.37, 0.012), Vector2(0.39, 0.0)]), 12)
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		mb.color(WOOD_DARK)
		mb.tube(PackedVector3Array([dir * 0.35 + Vector3.UP * 0.04, dir * 0.16 + Vector3.UP * 0.15]), 0.042, 6)
		mb.color(SOOT)
		mb.tube(PackedVector3Array([dir * 0.16 + Vector3.UP * 0.15, dir * 0.03 + Vector3.UP * 0.25]), 0.034, 6)
	mb.color(Color(0.98, 0.5, 0.12))
	for k in 9:
		var a := k * 0.8
		mb.box(Vector3(cos(a) * 0.13, 0.03, sin(a) * 0.11), Vector3(0.05, 0.03, 0.04), Basis(Vector3.UP, a))
	mb.color(IRON)
	for x in [-0.37, 0.37]:
		for z in [-0.27, 0.27]:
			mb.tube(PackedVector3Array([Vector3(x * 1.12, 0.0, z * 1.12), Vector3(x, 0.3, z), Vector3(x, 0.55, z)]), 0.018, 5)
	for z in [-0.27, 0.27]:
		mb.box(Vector3(0, 0.55, z), Vector3(0.8, 0.03, 0.035))
	for x in [-0.38, 0.38]:
		mb.box(Vector3(x, 0.55, 0), Vector3(0.035, 0.03, 0.58))
	for k in 10:
		mb.box(Vector3(-0.34 + k * 0.0755, 0.565, 0), Vector3(0.014, 0.014, 0.55))
	mb.tube(PackedVector3Array([Vector3(0.38, 0.55, 0.1), Vector3(0.5, 0.58, 0.1), Vector3(0.5, 0.58, -0.1), Vector3(0.38, 0.55, -0.1)]), 0.01, 4) # alça
	# Gancho de galho com a chaleira, do lado.
	mb.color(WOOD)
	mb.tube(PackedVector3Array([Vector3(-0.75, 0.0, 0.2), Vector3(-0.72, 0.75, 0.15)]), 0.025, 5)
	mb.tube(PackedVector3Array([Vector3(-0.72, 0.7, 0.15), Vector3(-0.56, 0.72, 0.1)]), 0.018, 4)
	mb.color(IRON)
	mb.tube(PackedVector3Array([Vector3(-0.58, 0.72, 0.1), Vector3(-0.58, 0.5, 0.1)]), 0.006, 3)
	mb.color(IRON.lightened(0.15))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.28), Vector2(0.09, 0.29), Vector2(0.11, 0.36), Vector2(0.1, 0.43), Vector2(0.06, 0.47), Vector2(0.002, 0.48)]), 10, Basis.IDENTITY, Vector3(-0.58, 0, 0.1))
	mb.tube(PackedVector3Array([Vector3(-0.49, 0.4, 0.1), Vector3(-0.42, 0.45, 0.1)]), 0.012, 4) # bico
	obj._shape(Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 1.0))
	StationModels._fire(obj, Vector3(0, 0.12, 0), 0.22, 1.0)
	_smoke(obj, Vector3(0, 0.8, 0), 0.12)


static func _furnace(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Fornalha de barro: base de pedras em duas fiadas, cúpula com anéis da
	# modelagem (marcas de dedo), boca em arco de pedra com porta de ferro aberta,
	# chaminé torta com chapéu, fuligem, lenha e pá de cinzas.
	_stone_ring(mb, Vector3.ZERO, 0.62, 11, Vector3(0.3, 0.16, 0.22), 21)
	_stone_ring(mb, Vector3(0, 0.12, 0), 0.6, 9, Vector3(0.26, 0.1, 0.2), 23)
	for k in 6:
		var y0 := 0.18 + k * 0.17
		var r0 := 0.64 - pow(k / 6.0, 2.0) * 0.5
		var r1 := 0.64 - pow((k + 1) / 6.0, 2.0) * 0.5
		mb.color(CLAY.darkened(0.04 * (k % 2)))
		mb.lathe(PackedVector2Array([Vector2(r0, y0), Vector2(r0 + 0.012, y0 + 0.085), Vector2(r1, y0 + 0.17)]), 14)
	mb.color(CLAY.lightened(0.05))
	mb.lathe(PackedVector2Array([Vector2(0.14, 1.18), Vector2(0.13, 1.5), Vector2(0.16, 1.56)]), 10, Basis(Vector3.BACK, 0.07), Vector3(0.06, 0, 0))
	mb.color(SOOT)
	mb.lathe(PackedVector2Array([Vector2(0.16, 1.53), Vector2(0.165, 1.57), Vector2(0.12, 1.57)]), 10, Basis(Vector3.BACK, 0.07), Vector3(0.06, 0, 0))
	mb.color(IRON)
	mb.lathe(PackedVector2Array([Vector2(0.002, 1.66), Vector2(0.22, 1.63), Vector2(0.2, 1.61)]), 8, Basis.IDENTITY, Vector3(0.1, 0, 0)) # chapéu
	for k in 3:
		mb.tube(PackedVector3Array([Vector3(0.1 + cos(k * 2.1) * 0.15, 1.56, sin(k * 2.1) * 0.15), Vector3(0.1 + cos(k * 2.1) * 0.19, 1.63, sin(k * 2.1) * 0.19)]), 0.008, 3)
	# Entrada: túnel de pedra saindo da cúpula, com a boca na frente dele.
	mb.color(STONE.darkened(0.15))
	mb.box(Vector3(0, 0.33, 0.6), Vector3(0.62, 0.5, 0.24))
	mb.color(STONE.darkened(0.25))
	for k in 7:
		var a := PI * k / 6.0
		mb.box(Vector3(cos(a) * 0.27, 0.5 + sin(a) * 0.12, 0.7), Vector3(0.1, 0.08, 0.06), Basis(Vector3.BACK, a)) # arco
	mb.color(SOOT)
	mb.box(Vector3(0, 0.72, 0.6), Vector3(0.3, 0.18, 0.08), Basis(Vector3.RIGHT, -0.4)) # fuligem
	mouth(mb, Vector3(0, 0.32, 0.72), 0.34, 0.3)
	var glow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.22
	disc.bottom_radius = 0.22
	disc.height = 0.02
	disc.radial_segments = 12
	glow.mesh = disc
	glow.material_override = StationModels._glow_mat()
	glow.rotation.x = PI / 2
	glow.position = Vector3(0, 0.32, 0.735)
	glow.scale = Vector3(0.7, 1.0, 0.62)
	obj.add_child(glow)
	StationModels._register_fire(obj, glow)
	obj._shape(Vector3(0, 0.6, 0), Vector3(1.3, 1.2, 1.3))
	StationModels._fire(obj, Vector3(0, 0.3, 0.68), 0.0, 0.8)
	_smoke(obj, Vector3(0.12, 1.62, 0), 0.08)


static func _chest(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Baú: tábuas com frestas, tampa curva de ripas, cantoneiras e cintas de
	# ferro rebitadas, pés, alças de argola e fechadura de latão com chave.
	var w := 1.0
	var d := 0.62
	mb.color(WOOD_DARK)
	for x in [-0.44, 0.44]:
		for z in [-0.25, 0.25]:
			mb.box(Vector3(x, 0.025, z), Vector3(0.1, 0.05, 0.1))
	for side in [-1.0, 1.0]:
		_slats(mb, Vector3(0, 0.31, side * (d * 0.5 - 0.02)), w, 0.52, 0.04, 4, true, WOOD)
		_slats(mb, Vector3(side * (w * 0.5 - 0.02), 0.31, 0), d - 0.08, 0.52, 0.04, 4, false, WOOD)
	mb.color(WOOD.darkened(0.15))
	mb.box(Vector3(0, 0.07, 0), Vector3(w - 0.06, 0.03, d - 0.06))
	for k in 7:
		var a0 := PI * k / 7.0
		var a1 := PI * (k + 1) / 7.0
		var am := (a0 + a1) * 0.5
		mb.color(WOOD.lightened(0.03 * (k % 2)))
		mb.box(Vector3(0, 0.57 + sin(am) * 0.26, cos(am) * 0.3), Vector3(w + 0.02, 0.04, 0.125), Basis(Vector3.RIGHT, -(am - PI / 2)))
	for side in [-1.0, 1.0]:
		mb.color(WOOD.darkened(0.1))
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.035), Vector2(0.002, 0.035)]), 10, AROUND_X, Vector3(side * (w * 0.5 + 0.0175) + 0.0175, 0.57, 0)) # tampa da ponta
	mb.color(IRON)
	for x in [-0.32, 0.32]:
		mb.box(Vector3(x, 0.31, d * 0.5 + 0.005), Vector3(0.06, 0.54, 0.012))
		mb.box(Vector3(x, 0.31, -d * 0.5 - 0.005), Vector3(0.06, 0.54, 0.012))
		mb.torus(0.29, 0.012, 10, 3, AROUND_X, Vector3(x, 0.57, 0))
		for y in [0.12, 0.3, 0.48]:
			_nail(mb, Vector3(x, y, d * 0.5 + 0.014), BRASS)
	for x in [-w * 0.5, w * 0.5]:
		for z in [-d * 0.5, d * 0.5]:
			mb.color(IRON)
			mb.box(Vector3(x, 0.31, z), Vector3(0.07, 0.56, 0.07)) # cantoneira
	for side in [-1.0, 1.0]:
		mb.color(IRON.lightened(0.1))
		mb.box(Vector3(side * (w * 0.5 + 0.03), 0.42, 0), Vector3(0.03, 0.06, 0.1))
		mb.torus(0.05, 0.01, 8, 3, Basis(Vector3.BACK, PI / 2) * Basis(Vector3.RIGHT, 0.0), Vector3(side * (w * 0.5 + 0.05), 0.36, 0)) # argola
	mb.color(BRASS)
	mb.box(Vector3(0, 0.5, d * 0.5 + 0.02), Vector3(0.14, 0.16, 0.02))
	mb.color(SOOT)
	mb.box(Vector3(0, 0.49, d * 0.5 + 0.032), Vector3(0.02, 0.05, 0.005))
	mb.color(BRASS.darkened(0.1))
	mb.box(Vector3(0, 0.47, d * 0.5 + 0.05), Vector3(0.012, 0.012, 0.05)) # chave
	mb.lathe(PackedVector2Array([Vector2(0.006, -0.004), Vector2(0.02, -0.004), Vector2(0.02, 0.004), Vector2(0.006, 0.004)]), 6, AROUND_Z, Vector3(0, 0.47, d * 0.5 + 0.08))
	obj._shape(Vector3(0, 0.42, 0), Vector3(w, 0.84, d))


static func _dryer(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Varal de secar: dois cavaletes em A de galhos amarrados, viga de cima com
	# 6 ganchos em S (vagas em y = 1,05), travessa de baixo com uma pele e um pano
	# estendidos, pedras segurando os pés e um balde de sal.
	for x in [-0.7, 0.7]:
		for z in [-0.22, 0.22]:
			mb.color(WOOD.darkened(0.05 if z < 0 else 0.15))
			mb.tube(PackedVector3Array([Vector3(x, 0.0, z * 1.6), Vector3(x, 0.7, z * 0.6), Vector3(x, 1.3, 0.0)]), 0.03, 5)
			_stone_ring(mb, Vector3(x, 0, z * 1.6), 0.0, 1, Vector3(0.12, 0.08, 0.1), int(x * 10 + z * 100))
		mb.color(ROPE)
		mb.lathe(PackedVector2Array([Vector2(0.045, 1.22), Vector2(0.05, 1.28), Vector2(0.045, 1.34)]), 6, Basis.IDENTITY, Vector3(x, 0, 0))
	mb.color(WOOD)
	mb.lathe(PackedVector2Array([Vector2(0.035, -0.8), Vector2(0.035, 0.8)]), 7, AROUND_X, Vector3(0, 1.22, 0)) # viga
	mb.lathe(PackedVector2Array([Vector2(0.025, -0.72), Vector2(0.025, 0.72)]), 6, AROUND_X, Vector3(0, 0.55, 0.13))
	mb.color(IRON)
	for i in 6:
		var x := (i - 2.5) * 0.22
		mb.tube(PackedVector3Array([Vector3(x, 1.25, 0.0), Vector3(x + 0.02, 1.2, 0.03), Vector3(x, 1.15, 0.0), Vector3(x - 0.02, 1.11, -0.02), Vector3(x, 1.09, 0.0)]), 0.006, 3)
	mb.color(Color(0.55, 0.4, 0.28))
	var hide := []
	for r in 4:
		var row := PackedVector3Array()
		for c in 5:
			row.append(Vector3(-0.6 + c * 0.11, 0.56 - r * 0.09 - absf(c - 2) * 0.01, 0.15 + r * 0.02))
		hide.append(row)
	mb.sheet(hide) # pele estendida
	mb.color(CLOTH)
	mb.box(Vector3(0.35, 0.42, 0.14), Vector3(0.36, 0.28, 0.01))
	mb.color(WOOD_DARK)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.11, 0.0), Vector2(0.13, 0.2), Vector2(0.135, 0.21)]), 10, Basis.IDENTITY, Vector3(0.0, 0, -0.42))
	_hoop(mb, Vector3(0.0, 0.17, -0.42), 0.125, 10, 0.025)
	mb.color(Color(0.92, 0.92, 0.88))
	mb.lathe(PackedVector2Array([Vector2(0.12, 0.19), Vector2(0.06, 0.23), Vector2(0.002, 0.24)]), 10, Basis.IDENTITY, Vector3(0.0, 0, -0.42)) # sal
	obj._shape(Vector3(0, 0.75, 0), Vector3(1.5, 1.5, 0.5))


static func _rain_collector(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Barril de aduelas com cintas, funil de lona com varetas e anel de ferro,
	# torneira de latão na frente (a porta do cano fica logo abaixo) e a água
	# dentro ("Water", escala em Y).
	for k in 14:
		var a := TAU * k / 14.0
		mb.color(WOOD.lightened(0.04 * (k % 3)))
		mb.box(Vector3(cos(a) * 0.33, 0.47, sin(a) * 0.33), Vector3(0.05, 0.92, 0.155), Basis(Vector3.UP, -a))
	mb.color(WOOD.darkened(0.1))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.04), Vector2(0.32, 0.04), Vector2(0.32, 0.07), Vector2(0.002, 0.07)]), 14)
	for y in [0.14, 0.47, 0.82]:
		_hoop(mb, Vector3(0, y, 0), 0.355, 14, 0.05)
	mb.color(CLOTH.darkened(0.08))
	mb.lathe(PackedVector2Array([Vector2(0.14, 0.95), Vector2(0.4, 1.08), Vector2(0.62, 1.2), Vector2(0.64, 1.23)]), 14)
	mb.color(IRON)
	mb.torus(0.63, 0.012, 16, 3, Basis.IDENTITY, Vector3(0, 1.22, 0))
	mb.color(WOOD)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		mb.tube(PackedVector3Array([Vector3(cos(a) * 0.34, 0.6, sin(a) * 0.34), Vector3(cos(a) * 0.64, 1.24, sin(a) * 0.64)]), 0.015, 4)
	mb.color(BRASS)
	mb.tube(PackedVector3Array([Vector3(0, 0.3, 0.34), Vector3(0, 0.3, 0.44), Vector3(0, 0.26, 0.46)]), 0.018, 6) # torneira
	mb.box(Vector3(0, 0.34, 0.42), Vector3(0.07, 0.015, 0.015))
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.38
	cyl.height = 0.95
	shape.shape = cyl
	shape.position.y = 0.48
	obj.add_child(shape)
	var water := MeshBuilder.new()
	water.color(WATER)
	water.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.86), Vector2(0.002, 0.86)]), 14)
	var node := MeshInstance3D.new()
	node.name = "Water"
	node.mesh = water.finish(PlacedObject._mat(), false)
	node.position.y = 0.07
	node.scale = Vector3(1, 0.01, 1)
	node.visible = false
	obj.add_child(node)


# --- Máquinas de manivela (Tier 1) ----------------------------------------------------------------

static func _grindstone(mb: MeshBuilder, crank: MeshBuilder, obj: PlacedObject) -> void:
	# Cavalete de vigas com cavilhas, mancais de ferro, pedra de amolar (gira em Z)
	# com manivela, cocho d'água embaixo, pedal com biela e uma faca no apoio.
	mb.color(WOOD_DARK)
	mb.box(Vector3(0, 0.07, 0), Vector3(0.95, 0.1, 0.55))
	for x in [-0.36, 0.36]:
		mb.color(WOOD)
		mb.box(Vector3(x, 0.42, 0), Vector3(0.1, 0.7, 0.14))
		mb.box(Vector3(x, 0.14, 0), Vector3(0.14, 0.06, 0.5)) # pé
		mb.color(WOOD_LIGHT)
		mb.lathe(PackedVector2Array([Vector2(0.015, -0.08), Vector2(0.015, 0.08)]), 5, AROUND_X, Vector3(x, 0.25, 0)) # cavilha
		mb.color(IRON)
		mb.box(Vector3(x, 0.78, 0), Vector3(0.13, 0.08, 0.16)) # mancal
		_nail(mb, Vector3(x, 0.82, 0.06))
		_nail(mb, Vector3(x, 0.82, -0.06))
	mb.color(WOOD.darkened(0.2))
	mb.box(Vector3(0, 0.36, 0), Vector3(0.56, 0.14, 0.32))
	mb.color(WATER)
	mb.box(Vector3(0, 0.425, 0), Vector3(0.5, 0.01, 0.26))
	mb.color(WOOD)
	mb.box(Vector3(0, 0.6, 0.24), Vector3(0.5, 0.04, 0.1)) # apoio da ferramenta
	mb.color(STEEL)
	mb.box(Vector3(0.1, 0.63, 0.24), Vector3(0.22, 0.008, 0.04)) # faca
	mb.color(WOOD_DARK)
	mb.box(Vector3(-0.06, 0.63, 0.24), Vector3(0.1, 0.03, 0.035))
	mb.color(WOOD)
	mb.box(Vector3(0.0, 0.12, 0.34), Vector3(0.5, 0.04, 0.14), Basis(Vector3.RIGHT, 0.2)) # pedal
	mb.color(IRON)
	mb.tube(PackedVector3Array([Vector3(0.22, 0.14, 0.32), Vector3(0.3, 0.5, 0.15), Vector3(0.38, 0.78, 0.06)]), 0.012, 4)
	# Pedra em pé no plano YZ: o eixo passa pelos dois mancais (X) e gira nele.
	crank.color(STONE)
	crank.lathe(PackedVector2Array([Vector2(0.002, -0.065), Vector2(0.31, -0.065), Vector2(0.33, -0.04), Vector2(0.33, 0.04), Vector2(0.31, 0.065), Vector2(0.002, 0.065)]), 16, AROUND_X)
	crank.color(STONE.darkened(0.15))
	for side in [-1.0, 1.0]:
		crank.lathe(PackedVector2Array([Vector2(0.18, side * 0.066), Vector2(0.2, side * 0.066)]), 16, AROUND_X)
	crank.color(IRON)
	crank.lathe(PackedVector2Array([Vector2(0.03, -0.46), Vector2(0.03, 0.46)]), 6, AROUND_X) # eixo
	for side in [-1.0, 1.0]:
		crank.lathe(PackedVector2Array([Vector2(0.03, side * 0.07), Vector2(0.07, side * 0.07), Vector2(0.07, side * 0.1), Vector2(0.03, side * 0.1)]), 8, AROUND_X) # flanges da pedra
	crank.box(Vector3(0.46, 0.09, 0), Vector3(0.04, 0.22, 0.05)) # braço da manivela
	crank.color(WOOD_LIGHT)
	crank.lathe(PackedVector2Array([Vector2(0.022, 0.0), Vector2(0.022, 0.13)]), 6, Basis(Vector3.BACK, -PI / 2), Vector3(0.46, 0.18, 0)) # pega (para fora, +X)
	obj._shape(Vector3(0, 0.55, 0), Vector3(0.9, 1.1, 0.5))


static func _quern(mb: MeshBuilder, crank: MeshBuilder, obj: PlacedObject) -> void:
	# Tina de aduelas com cintas, mó de baixo fixa, mó de cima (gira em Y) com
	# sulcos, olho de alimentação e cabo; bica de farinha, saco, feixe de trigo e
	# caixa de engrenagem com polia de latão na porta de energia (esquerda).
	for k in 12:
		var a := TAU * k / 12.0
		mb.color(WOOD.lightened(0.04 * (k % 3)))
		mb.box(Vector3(cos(a) * 0.36, 0.3, sin(a) * 0.36), Vector3(0.05, 0.6, 0.19), Basis(Vector3.UP, -a))
	for y in [0.1, 0.48]:
		_hoop(mb, Vector3(0, y, 0), 0.385, 12, 0.05)
	mb.color(STONE)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.6), Vector2(0.36, 0.6), Vector2(0.36, 0.73), Vector2(0.002, 0.73)]), 14)
	mb.color(WOOD.darkened(0.2))
	mb.box(Vector3(0, 0.62, 0.43), Vector3(0.12, 0.05, 0.22), Basis(Vector3.RIGHT, 0.35)) # bica
	mb.color(Color(0.95, 0.93, 0.88))
	mb.box(Vector3(0, 0.55, 0.5), Vector3(0.06, 0.08, 0.04))
	mb.color(Color(0.8, 0.74, 0.6))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.14, 0.0), Vector2(0.16, 0.16), Vector2(0.11, 0.33), Vector2(0.06, 0.38)]), 8, Basis.IDENTITY, Vector3(0, 0, 0.66))
	mb.color(ROPE)
	mb.torus(0.07, 0.012, 8, 3, Basis.IDENTITY, Vector3(0, 0.34, 0.66))
	mb.color(Color(0.86, 0.72, 0.38))
	for k in 7:
		mb.tube(PackedVector3Array([Vector3(-0.32 + k * 0.025, 0.0, -0.42), Vector3(-0.3 + k * 0.03, 0.62, -0.36)]), 0.008, 3)
	mb.color(ROPE)
	mb.box(Vector3(-0.23, 0.25, -0.4), Vector3(0.2, 0.04, 0.06))
	mb.color(IRON)
	mb.box(Vector3(-0.45, 0.6, 0), Vector3(0.12, 0.18, 0.18)) # caixa de engrenagem
	mb.tube(PackedVector3Array([Vector3(-0.45, 0.68, 0), Vector3(-0.2, 0.8, 0), Vector3(0, 0.8, 0)]), 0.015, 4)
	_pulley(mb, Vector3(-0.55, 0.6, 0), true)
	crank.color(STONE.lightened(0.08))
	crank.lathe(PackedVector2Array([Vector2(0.06, 0.0), Vector2(0.35, 0.0), Vector2(0.35, 0.13), Vector2(0.3, 0.15), Vector2(0.08, 0.15), Vector2(0.06, 0.13)]), 14)
	crank.color(STONE.darkened(0.12))
	for k in 8:
		var a := TAU * k / 8.0
		crank.box(Vector3(cos(a) * 0.2, 0.152, sin(a) * 0.2), Vector3(0.24, 0.005, 0.015), Basis(Vector3.UP, -a + 0.3)) # sulcos
	crank.color(IRON)
	crank.box(Vector3(0, 0.14, 0), Vector3(0.26, 0.03, 0.05)) # traveja
	crank.color(WOOD_DARK)
	crank.lathe(PackedVector2Array([Vector2(0.025, 0.15), Vector2(0.022, 0.42), Vector2(0.03, 0.44), Vector2(0.002, 0.46)]), 6, Basis.IDENTITY, Vector3(0.27, 0, 0)) # cabo
	obj._shape(Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.8))


static func _pump(mb: MeshBuilder, crank: MeshBuilder, obj: PlacedObject) -> void:
	# Bomba de ferro fundido: coluna com frisos e tampa, bica com boca, alavanca
	# (sobe e desce) com pega de madeira, cano descendo para a água, mureta de
	# pedra, estrado e balde embaixo da bica.
	_stone_ring(mb, Vector3.ZERO, 0.3, 8, Vector3(0.17, 0.14, 0.13), 31)
	mb.color(WOOD.darkened(0.1))
	_boards(mb, Vector3(0, 0.15, 0), Vector3(0.62, 0.04, 0.62), 4, true, WOOD)
	mb.color(IRON)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.17), Vector2(0.12, 0.17), Vector2(0.1, 0.24), Vector2(0.08, 0.3), Vector2(0.085, 0.95),
		Vector2(0.1, 0.98), Vector2(0.1, 1.04), Vector2(0.07, 1.08), Vector2(0.002, 1.1)]), 10)
	mb.color(IRON.lightened(0.12))
	for y in [0.4, 0.7]:
		mb.lathe(PackedVector2Array([Vector2(0.086, y), Vector2(0.095, y + 0.015), Vector2(0.086, y + 0.03)]), 10)
	mb.color(IRON)
	mb.tube(PackedVector3Array([Vector3(0, 0.88, 0.07), Vector3(0, 0.88, 0.28), Vector3(0, 0.83, 0.33)]), 0.035, 6) # bica
	mb.lathe(PackedVector2Array([Vector2(0.035, 0.0), Vector2(0.045, 0.02)]), 6, Basis(Vector3.RIGHT, PI), Vector3(0, 0.82, 0.33))
	mb.box(Vector3(0, 1.12, -0.05), Vector3(0.05, 0.12, 0.04)) # garfo do pivô
	mb.color(IRON.darkened(0.2))
	mb.tube(PackedVector3Array([Vector3(0, 0.17, -0.06), Vector3(0, -0.2, -0.4), Vector3(0, -0.6, -0.62)]), 0.04, 6)
	mb.color(WOOD)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.1, 0.0), Vector2(0.12, 0.2), Vector2(0.125, 0.21)]), 10, Basis.IDENTITY, Vector3(0, 0.17, 0.33))
	_hoop(mb, Vector3(0, 0.36, 0.33), 0.118, 10, 0.02)
	_hoop(mb, Vector3(0, 0.22, 0.33), 0.104, 10, 0.02)
	mb.color(WATER)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.33), Vector2(0.11, 0.33)]), 10, Basis.IDENTITY, Vector3(0, 0, 0.33))
	crank.color(IRON.lightened(0.15))
	crank.box(Vector3(0, 0.02, -0.32), Vector3(0.045, 0.045, 0.64))
	crank.box(Vector3(0, -0.05, 0.08), Vector3(0.03, 0.12, 0.03)) # haste do pistão
	crank.color(WOOD_DARK)
	crank.lathe(PackedVector2Array([Vector2(0.03, -0.7), Vector2(0.034, -0.6), Vector2(0.03, -0.5)]), 6, AROUND_Z, Vector3(0, 0.02, 0)) # pega
	obj._shape(Vector3(0, 0.55, 0), Vector3(0.4, 1.1, 0.4))


static func _spinning(mb: MeshBuilder, crank: MeshBuilder, obj: PlacedObject) -> void:
	# Roca de pedal: banco inclinado de três pés, dois montantes com a roda
	# grande (gira em Z), pedal e biela, cabeçote com o fuso e as asas (onde o fio
	# enrola), roca de fibra e cesto; polia de latão na porta de energia.
	mb.color(WOOD)
	mb.box(Vector3(0, 0.3, 0), Vector3(1.0, 0.07, 0.26), Basis(Vector3.BACK, -0.08))
	for p: Vector3 in [Vector3(-0.42, 0.0, 0.11), Vector3(-0.42, 0.0, -0.11), Vector3(0.42, 0.0, 0.0)]:
		mb.color(WOOD_DARK)
		mb.tube(PackedVector3Array([p, Vector3(p.x * 0.9, 0.3 - p.x * 0.08, p.z * 0.7)]), 0.025, 5)
	for z in [-0.08, 0.08]:
		mb.color(WOOD)
		mb.box(Vector3(0.25, 0.53, z), Vector3(0.05, 0.42, 0.04))
	mb.color(IRON)
	mb.box(Vector3(0.25, 0.72, 0), Vector3(0.06, 0.06, 0.2))
	mb.color(WOOD.darkened(0.15))
	mb.box(Vector3(0.25, 0.06, 0.16), Vector3(0.32, 0.03, 0.14), Basis(Vector3.RIGHT, 0.15)) # pedal
	mb.color(IRON)
	mb.tube(PackedVector3Array([Vector3(0.25, 0.08, 0.16), Vector3(0.28, 0.45, 0.1), Vector3(0.3, 0.72, 0.1)]), 0.006, 3)
	# Cabeçote: dois "donzelas" e o fuso com as asas.
	mb.color(WOOD)
	mb.box(Vector3(-0.32, 0.42, 0), Vector3(0.24, 0.06, 0.08))
	for x in [-0.42, -0.22]:
		mb.lathe(PackedVector2Array([Vector2(0.02, 0.42), Vector2(0.025, 0.5), Vector2(0.018, 0.62), Vector2(0.025, 0.64)]), 6, Basis.IDENTITY, Vector3(x, 0, 0))
	mb.color(WOOD_LIGHT)
	mb.lathe(PackedVector2Array([Vector2(0.03, -0.1), Vector2(0.04, -0.06), Vector2(0.04, 0.06), Vector2(0.03, 0.1)]), 8, AROUND_X, Vector3(-0.32, 0.6, 0)) # carretel
	mb.color(CLOTH)
	mb.lathe(PackedVector2Array([Vector2(0.041, -0.05), Vector2(0.05, 0.0), Vector2(0.041, 0.05)]), 8, AROUND_X, Vector3(-0.32, 0.6, 0)) # fio enrolado
	mb.color(WOOD)
	for side in [-1.0, 1.0]:
		mb.box(Vector3(-0.32, 0.6 + side * 0.06, 0), Vector3(0.24, 0.015, 0.02)) # asas
	mb.color(ROPE)
	mb.tube(PackedVector3Array([Vector3(-0.2, 0.6, 0.02), Vector3(0.0, 0.66, 0.03), Vector3(0.25, 0.72 + 0.31, 0.03)]), 0.004, 3) # correia da roda
	# Roca com fibra e cesto.
	mb.color(WOOD_DARK)
	mb.tube(PackedVector3Array([Vector3(-0.45, 0.33, -0.05), Vector3(-0.55, 0.95, -0.1)]), 0.012, 4)
	mb.color(Color(0.95, 0.94, 0.9))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.82), Vector2(0.06, 0.86), Vector2(0.07, 0.95), Vector2(0.04, 1.02), Vector2(0.002, 1.04)]), 8, Basis(Vector3.BACK, 0.16), Vector3(-0.42, 0, -0.1))
	mb.color(Color(0.5, 0.4, 0.25))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.14, 0.0), Vector2(0.17, 0.16), Vector2(0.175, 0.17)]), 10, Basis.IDENTITY, Vector3(-0.3, 0, 0.36))
	mb.color(Color(0.95, 0.94, 0.9))
	mb.lathe(PackedVector2Array([Vector2(0.16, 0.15), Vector2(0.1, 0.21), Vector2(0.002, 0.23)]), 10, Basis.IDENTITY, Vector3(-0.3, 0, 0.36))
	mb.color(IRON)
	mb.box(Vector3(-0.6, 0.6, 0), Vector3(0.08, 0.12, 0.12))
	_pulley(mb, Vector3(-0.65, 0.6, 0), true, 0.08)
	crank.color(WOOD.lightened(0.12))
	crank.lathe(PackedVector2Array([Vector2(0.002, -0.04), Vector2(0.05, -0.04), Vector2(0.05, 0.04), Vector2(0.002, 0.04)]), 8, AROUND_Z) # cubo
	for k in 10:
		var a := TAU * k / 10.0
		crank.lathe(PackedVector2Array([Vector2(0.012, 0.04), Vector2(0.016, 0.16), Vector2(0.012, 0.3)]), 5, Basis(Vector3.BACK, a - PI / 2))
	crank.color(WOOD)
	crank.lathe(PackedVector2Array([Vector2(0.29, -0.025), Vector2(0.33, -0.025), Vector2(0.33, 0.025), Vector2(0.29, 0.025)]), 20, AROUND_Z) # aro
	crank.color(IRON)
	crank.box(Vector3(0.0, 0.0, 0.12), Vector3(0.03, 0.03, 0.14)) # eixo com manivela
	crank.box(Vector3(0.0, 0.04, 0.18), Vector3(0.02, 0.1, 0.02))
	obj._shape(Vector3(0, 0.55, 0), Vector3(1.0, 1.1, 0.4))


static func _loom(mb: MeshBuilder, crank: MeshBuilder, obj: PlacedObject) -> void:
	# Tear de pedal: quatro montantes com travessas e castelo em cima, rolo de
	# urdume atrás, fios esticados até o pano listrado pronto na frente, quadro de
	# liços (sobe e desce), pente batedor, lançadeira, pedais e polia de latão.
	for x in [-0.6, 0.6]:
		for z in [-0.35, 0.35]:
			mb.color(WOOD_DARK)
			mb.box(Vector3(x, 0.6, z), Vector3(0.08, 1.2, 0.08))
		mb.color(WOOD)
		mb.box(Vector3(x, 0.2, 0), Vector3(0.06, 0.08, 0.76))
		mb.box(Vector3(x, 1.18, 0), Vector3(0.08, 0.08, 0.8))
	mb.color(WOOD)
	mb.box(Vector3(0, 1.18, -0.1), Vector3(1.28, 0.07, 0.07)) # castelo
	mb.box(Vector3(0, 1.18, 0.12), Vector3(1.28, 0.07, 0.07))
	mb.color(WOOD_LIGHT)
	mb.lathe(PackedVector2Array([Vector2(0.06, -0.58), Vector2(0.06, 0.58)]), 8, AROUND_X, Vector3(0, 0.78, -0.35)) # rolo do urdume
	mb.color(CLOTH.lightened(0.05))
	mb.lathe(PackedVector2Array([Vector2(0.075, -0.5), Vector2(0.075, 0.5)]), 8, AROUND_X, Vector3(0, 0.78, -0.35))
	for k in 18:
		var x := -0.48 + k * 0.0565
		mb.color(CLOTH.darkened(0.05 * (k % 2)))
		mb.tube(PackedVector3Array([Vector3(x, 0.85, -0.33), Vector3(x, 0.78, 0.18)]), 0.003, 3) # urdume
	var stripes := [Color(0.62, 0.22, 0.18), CLOTH, Color(0.25, 0.35, 0.55), CLOTH, Color(0.62, 0.22, 0.18)]
	for k in 5:
		mb.color(stripes[k])
		mb.box(Vector3(0, 0.77, 0.21 + k * 0.035), Vector3(1.0, 0.012, 0.035)) # pano tecido
	mb.color(WOOD_LIGHT)
	mb.lathe(PackedVector2Array([Vector2(0.06, -0.58), Vector2(0.06, 0.58)]), 8, AROUND_X, Vector3(0, 0.72, 0.38)) # rolo do pano
	mb.color(stripes[0])
	mb.lathe(PackedVector2Array([Vector2(0.08, -0.5), Vector2(0.08, 0.5)]), 8, AROUND_X, Vector3(0, 0.72, 0.38))
	mb.color(WOOD)
	mb.box(Vector3(0, 0.82, 0.12), Vector3(1.1, 0.05, 0.06)) # pente batedor
	for k in 22:
		mb.box(Vector3(-0.5 + k * 0.0476, 0.9, 0.12), Vector3(0.006, 0.14, 0.01))
	mb.color(WOOD_LIGHT)
	mb.box(Vector3(0.2, 0.8, 0.2), Vector3(0.24, 0.03, 0.045)) # lançadeira
	mb.color(WOOD_DARK)
	for x in [-0.25, -0.08, 0.08, 0.25]:
		mb.box(Vector3(x, 0.06, 0.12), Vector3(0.1, 0.03, 0.55), Basis(Vector3.RIGHT, 0.08))
	mb.color(IRON)
	mb.box(Vector3(-0.72, 0.6, 0), Vector3(0.1, 0.12, 0.12))
	_pulley(mb, Vector3(-0.8, 0.6, 0), true, 0.08)
	crank.color(WOOD.lightened(0.15))
	crank.box(Vector3(0, 0.12, 0), Vector3(1.16, 0.04, 0.04))
	crank.box(Vector3(0, -0.12, 0), Vector3(1.16, 0.04, 0.04))
	for x in [-0.56, 0.56]:
		crank.box(Vector3(x, 0, 0), Vector3(0.04, 0.28, 0.04))
	crank.color(IRON.lightened(0.3))
	for k in 18:
		crank.box(Vector3(-0.48 + k * 0.0565, 0, 0), Vector3(0.004, 0.24, 0.004)) # liços
	crank.color(ROPE)
	for x in [-0.4, 0.4]:
		crank.tube(PackedVector3Array([Vector3(x, 0.14, 0), Vector3(x, 0.2, 0)]), 0.005, 3)
	obj._shape(Vector3(0, 0.6, 0), Vector3(1.3, 1.2, 0.8))


static func _stone_furnace(mb: MeshBuilder, crank: MeshBuilder, obj: PlacedObject) -> void:
	# Fornalha de tijolo: corpo em fiadas com cintas e tirantes de ferro, boca em
	# arco com porta, cadinho no topo, chaminé afinando com chapéu e fumaça, fole
	# de couro do lado direito (a tábua de cima abre e fecha) com bico até o fogo,
	# carvão, lingotes e uma tenaz encostada.
	_bricks(mb, Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.1), 10)
	mb.color(BRICK.darkened(0.25))
	mb.box(Vector3(0, 1.22, 0), Vector3(1.26, 0.06, 1.16)) # coroa
	mb.color(IRON)
	for y in [0.18, 1.0]:
		mb.box(Vector3(0, y, 0), Vector3(1.24, 0.05, 1.14))
	for x in [-0.6, 0.6]:
		for z in [-0.55, 0.55]:
			mb.box(Vector3(x, 0.6, z), Vector3(0.06, 1.2, 0.06))
	mouth(mb, Vector3(0, 0.38, 0.55), 0.44, 0.34)
	mb.color(BRICK.darkened(0.3))
	for k in 7:
		var a := PI * k / 6.0
		mb.box(Vector3(cos(a) * 0.28, 0.6 + sin(a) * 0.1, 0.565), Vector3(0.1, 0.07, 0.03), Basis(Vector3.BACK, a)) # arco
	mb.color(SOOT)
	mb.box(Vector3(0, 0.82, 0.553), Vector3(0.4, 0.16, 0.01)) # fuligem
	mb.color(STONE.darkened(0.3))
	mb.lathe(PackedVector2Array([Vector2(0.002, 1.25), Vector2(0.16, 1.25), Vector2(0.18, 1.38), Vector2(0.14, 1.38), Vector2(0.13, 1.3), Vector2(0.002, 1.3)]), 10, Basis.IDENTITY, Vector3(0.25, 0, 0.15)) # cadinho
	mb.color(Color(1.0, 0.55, 0.15))
	mb.lathe(PackedVector2Array([Vector2(0.002, 1.34), Vector2(0.13, 1.34)]), 10, Basis.IDENTITY, Vector3(0.25, 0, 0.15))
	for k in 6:
		mb.color(BRICK.darkened(0.12 + 0.06 * (k % 2)))
		var w := 0.46 - k * 0.025
		mb.box(Vector3(-0.2, 1.3 + k * 0.14, -0.2), Vector3(w, 0.13, w))
	mb.color(IRON)
	mb.box(Vector3(-0.2, 2.15, -0.2), Vector3(0.44, 0.03, 0.44)) # chapéu
	for x in [-0.38, -0.02]:
		mb.box(Vector3(x, 2.1, -0.2), Vector3(0.02, 0.08, 0.02))
	# Fole: caixa de couro sanfonada com bico e base.
	mb.color(WOOD_DARK)
	mb.box(Vector3(0.82, 0.36, 0.25), Vector3(0.44, 0.04, 0.66))
	mb.color(Color(0.42, 0.28, 0.17))
	for k in 3:
		mb.box(Vector3(0.82, 0.41 + k * 0.025, 0.25), Vector3(0.42 - k * 0.04, 0.025, 0.62 - k * 0.04))
	mb.color(IRON)
	mb.tube(PackedVector3Array([Vector3(0.82, 0.38, -0.08), Vector3(0.7, 0.38, -0.25), Vector3(0.55, 0.38, -0.3)]), 0.04, 6) # bico
	mb.color(WOOD_DARK)
	mb.box(Vector3(0.82, 0.18, 0.25), Vector3(0.08, 0.36, 0.08))
	# Tábua de cima do fole (a manivela: dobradiça atrás, abre e fecha).
	crank.color(WOOD)
	crank.box(Vector3(0, 0.0, -0.32), Vector3(0.44, 0.04, 0.66))
	crank.color(WOOD_DARK)
	crank.box(Vector3(0, 0.03, 0.02), Vector3(0.06, 0.05, 0.22)) # cabo
	obj._shape(Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.1))
	StationModels._fire(obj, Vector3(0, 0.36, 0.48), 0.1, 0.8)
	_smoke(obj, Vector3(-0.2, 2.2, -0.2), 0.12)


static func _oven(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Forno de tijolo: base de pedra quadrada, cúpula em fiadas, boca em arco com
	# porta de ferro encostada, chaminé, prateleira com pães, pá de padeiro e lenha.
	mb.color(STONE.darkened(0.1))
	mb.box(Vector3(0, 0.12, 0), Vector3(1.3, 0.24, 1.3))
	mb.color(STONE)
	mb.box(Vector3(0, 0.25, 0), Vector3(1.34, 0.04, 1.34))
	for k in 7:
		var y0 := 0.27 + k * 0.12
		var r0 := 0.6 * cos(asin(clampf(k / 7.0, 0.0, 1.0)))
		var r1 := 0.6 * cos(asin(clampf((k + 1) / 7.0, 0.0, 1.0)))
		mb.color(BRICK if k % 2 == 0 else BRICK.darkened(0.09))
		mb.lathe(PackedVector2Array([Vector2(r0, y0), Vector2(maxf(r1, 0.002), y0 + 0.115)]), 12)
	# Entrada: túnel de tijolo saindo da cúpula, com a boca na frente dele.
	_bricks(mb, Vector3(0, 0.5, 0.6), Vector3(0.6, 0.48, 0.22), 4)
	mb.color(BRICK.darkened(0.25))
	for k in 7:
		var a := PI * k / 6.0
		mb.box(Vector3(cos(a) * 0.25, 0.68 + sin(a) * 0.1, 0.71), Vector3(0.09, 0.07, 0.04), Basis(Vector3.BACK, a)) # arco
	mb.color(SOOT)
	mb.box(Vector3(0, 0.8, 0.6), Vector3(0.28, 0.12, 0.06), Basis(Vector3.RIGHT, -0.4)) # fuligem
	mouth(mb, Vector3(0, 0.49, 0.71), 0.32, 0.26)
	mb.color(BRICK.darkened(0.15))
	mb.lathe(PackedVector2Array([Vector2(0.12, 0.9), Vector2(0.1, 1.45), Vector2(0.14, 1.5), Vector2(0.14, 1.55)]), 8, Basis.IDENTITY, Vector3(0, 0, -0.25))
	obj._shape(Vector3(0, 0.55, 0), Vector3(1.24, 1.1, 1.24))
	StationModels._fire(obj, Vector3(0, 0.45, 0.62), 0.06, 0.6)
	_smoke(obj, Vector3(0, 1.6, -0.25), 0.08)


static func _filter(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Filtro de areia: estante de madeira (as garrafas ficam embaixo, no chão),
	# tanque de lata com faixas de vidro mostrando cascalho, areia e carvão,
	# pano de coar na boca, torneirinha pingando e um saco de areia do lado.
	for x in [-0.32, 0.32]:
		for z in [-0.19, 0.19]:
			mb.color(WOOD_DARK)
			mb.box(Vector3(x, 0.5, z), Vector3(0.05, 1.0, 0.05))
	mb.color(WOOD)
	for z in [-0.19, 0.19]:
		mb.box(Vector3(0, 0.55, z), Vector3(0.7, 0.05, 0.04))
	for x in [-0.32, 0.32]:
		mb.box(Vector3(x, 0.55, 0), Vector3(0.04, 0.05, 0.42))
	mb.color(STEEL.darkened(0.1))
	mb.lathe(PackedVector2Array([Vector2(0.03, 0.42), Vector2(0.04, 0.48), Vector2(0.17, 0.58), Vector2(0.17, 0.98), Vector2(0.19, 1.0), Vector2(0.16, 1.0)]), 12)
	var layers := [[0.6, 0.68, Color(0.55, 0.52, 0.48)], [0.68, 0.78, Color(0.12, 0.12, 0.12)], [0.78, 0.92, Color(0.85, 0.74, 0.5)]]
	for layer: Array in layers:
		mb.color(layer[2])
		mb.lathe(PackedVector2Array([Vector2(0.172, layer[0]), Vector2(0.172, layer[1])]), 12, Basis.IDENTITY, Vector3(0, 0, 0)) # faixa (janela de vidro)
	mb.color(CLOTH)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.95), Vector2(0.16, 0.95), Vector2(0.2, 0.99), Vector2(0.19, 1.02)]), 12)
	_hoop(mb, Vector3(0, 0.62, 0), 0.172, 12, 0.02)
	_hoop(mb, Vector3(0, 0.9, 0), 0.172, 12, 0.02)
	mb.color(BRASS)
	mb.box(Vector3(0, 0.4, 0), Vector3(0.03, 0.06, 0.03))
	mb.box(Vector3(0.04, 0.44, 0), Vector3(0.06, 0.012, 0.012))
	mb.color(WATER)
	mb.box(Vector3(0, 0.34, 0), Vector3(0.015, 0.05, 0.015))
	mb.color(CLOTH.darkened(0.2))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.11, 0.0), Vector2(0.13, 0.14), Vector2(0.08, 0.26), Vector2(0.05, 0.3)]), 8, Basis.IDENTITY, Vector3(0.48, 0, 0.1))
	mb.color(Color(0.85, 0.74, 0.5))
	mb.lathe(PackedVector2Array([Vector2(0.06, 0.26), Vector2(0.002, 0.3)]), 8, Basis.IDENTITY, Vector3(0.48, 0, 0.1))
	_drops(obj, Vector3(0, 0.33, 0), Vector3.DOWN, 3, 0.4, 2.0)
	obj._shape(Vector3(0, 0.75, 0), Vector3(0.7, 0.5, 0.45))


static func _smoker(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Defumador: fornalha de tijolo em fiadas com portinhola de ferro, armário de
	# tábuas com a porta aberta de lado (peixes pendurados nas varas, y = 1,2),
	# frestas com fuligem, teto com chaminé de lata e fumaça.
	_bricks(mb, Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.6), 5, BRICK.darkened(0.08))
	mouth(mb, Vector3(0, 0.26, 0.3), 0.28, 0.2)
	for x in [-0.38, 0.38]:
		for z in [-0.27, 0.27]:
			mb.color(WOOD_DARK)
			mb.box(Vector3(x, 0.96, z), Vector3(0.05, 0.72, 0.05))
	_slats(mb, Vector3(0, 0.96, -0.285), 0.8, 0.7, 0.03, 5, true, WOOD.darkened(0.15))
	for side in [-1.0, 1.0]:
		_slats(mb, Vector3(side * 0.39, 0.96, 0), 0.55, 0.7, 0.03, 5, false, WOOD.darkened(0.1))
	mb.color(SOOT)
	mb.box(Vector3(0, 1.28, -0.27), Vector3(0.7, 0.08, 0.01))
	mb.color(WOOD.darkened(0.2))
	mb.box(Vector3(0, 1.34, 0), Vector3(0.9, 0.05, 0.7)) # teto
	mb.color(WOOD.darkened(0.1))
	_slats(mb, Vector3(0.62, 0.96, 0.36), 0.42, 0.68, 0.03, 4, true, WOOD) # porta aberta
	mb.color(IRON)
	for y in [0.75, 1.15]:
		mb.box(Vector3(0.4, y, 0.3), Vector3(0.04, 0.05, 0.04)) # dobradiças
	for z in [-0.08, 0.08]:
		mb.box(Vector3(0, 1.22, z), Vector3(0.74, 0.02, 0.02)) # varas
	mb.color(STEEL.darkened(0.25))
	mb.lathe(PackedVector2Array([Vector2(0.06, 1.36), Vector2(0.06, 1.6), Vector2(0.1, 1.64), Vector2(0.002, 1.7)]), 8, Basis.IDENTITY, Vector3(-0.25, 0, -0.15))
	obj._shape(Vector3(0, 0.7, 0), Vector3(0.8, 1.4, 0.6))
	StationModels._fire(obj, Vector3(0, 0.22, 0.24), 0.06, 0.5)
	_smoke(obj, Vector3(-0.25, 1.72, -0.15), 0.06)


static func _compost(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Composteira: postes com tampinha, ripas com frestas (ventila), tábuas da
	# frente mais baixas para mexer, tampa apoiada atrás, monte escuro com restos
	# (vagas em y = 0,5), forcado encostado e moscas.
	for x in [-0.5, 0.5]:
		for z in [-0.45, 0.45]:
			mb.color(WOOD_DARK)
			mb.box(Vector3(x, 0.4, z), Vector3(0.08, 0.8, 0.08))
			mb.color(WOOD.darkened(0.3))
			mb.box(Vector3(x, 0.81, z), Vector3(0.1, 0.03, 0.1))
	for k in 4:
		var y := 0.1 + k * 0.17
		mb.color(WOOD.darkened(0.04 * (k % 2)))
		mb.box(Vector3(0, y, -0.46), Vector3(1.0, 0.11, 0.035))
		for side in [-1.0, 1.0]:
			mb.box(Vector3(side * 0.51, y, 0), Vector3(0.035, 0.11, 0.86))
		if k < 2:
			mb.box(Vector3(0, y, 0.46), Vector3(1.0, 0.11, 0.035))
	mb.color(WOOD.darkened(0.15))
	mb.box(Vector3(0.62, 0.3, 0.55), Vector3(0.04, 0.6, 0.12), Basis(Vector3.BACK, 0.2)) # tábua tirada encostada
	mb.color(Color(0.22, 0.15, 0.08))
	mb.lathe(PackedVector2Array([Vector2(0.44, 0.38), Vector2(0.38, 0.46), Vector2(0.2, 0.52), Vector2(0.002, 0.55)]), 10)
	mb.box(Vector3(0, 0.25, 0), Vector3(0.95, 0.26, 0.85))
	for k in 10:
		var a := k * 2.1
		mb.color([Color(0.35, 0.5, 0.2), Color(0.55, 0.4, 0.2), Color(0.3, 0.42, 0.18), Color(0.85, 0.6, 0.2)][k % 4])
		mb.box(Vector3(cos(a) * (0.12 + k * 0.025), 0.5 + (k % 3) * 0.01, sin(a) * 0.2), Vector3(0.06, 0.025, 0.05), Basis(Vector3.UP, a))
	mb.color(WOOD.darkened(0.15))
	_boards(mb, Vector3(0, 0.95, -0.62), Vector3(1.05, 0.04, 0.5), 3, false, WOOD.darkened(0.12))
	mb.color(WOOD_LIGHT)
	mb.tube(PackedVector3Array([Vector3(-0.62, 0.0, 0.5), Vector3(-0.58, 1.1, 0.42)]), 0.018, 5) # forcado
	mb.color(IRON)
	for k in 3:
		mb.tube(PackedVector3Array([Vector3(-0.64 + k * 0.03, 0.02, 0.51), Vector3(-0.63 + k * 0.03, 0.22, 0.5)]), 0.006, 3)
	mb.box(Vector3(-0.61, 0.22, 0.5), Vector3(0.1, 0.02, 0.02))
	obj._shape(Vector3(0, 0.4, 0), Vector3(1.05, 0.8, 0.95))


static func _sieve(mb: MeshBuilder, crank: MeshBuilder, obj: PlacedObject) -> void:
	# Peneira: cavalete com trilhos onde a bandeja corre (vai e volta), tela de
	# arame, monte de argila, caixa de pedras peneiradas e balde.
	for x in [-0.45, 0.45]:
		for z in [-0.3, 0.3]:
			mb.color(WOOD_DARK)
			mb.tube(PackedVector3Array([Vector3(x * 1.05, 0.0, z * 1.1), Vector3(x, 0.7, z)]), 0.025, 5)
	mb.color(WOOD)
	for z in [-0.33, 0.33]:
		mb.box(Vector3(0, 0.7, z), Vector3(1.2, 0.04, 0.04)) # trilhos
	mb.box(Vector3(0, 0.3, 0), Vector3(0.95, 0.03, 0.04))
	mb.color(Color(0.62, 0.45, 0.35))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.14), Vector2(0.22, 0.1), Vector2(0.3, 0.0)]), 8, Basis.IDENTITY, Vector3(-0.1, 0, 0))
	_slats(mb, Vector3(0.28, 0.08, 0.1), 0.34, 0.16, 0.02, 2, true, WOOD.darkened(0.1))
	mb.color(STONE)
	for k in 5:
		mb.box(Vector3(0.22 + (k % 3) * 0.06, 0.17, 0.08 + (k / 3) * 0.06), Vector3(0.05, 0.04, 0.05), Basis(Vector3.UP, k))
	mb.color(WOOD)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.11, 0.0), Vector2(0.13, 0.22)]), 10, Basis.IDENTITY, Vector3(-0.6, 0, 0.35))
	_hoop(mb, Vector3(-0.6, 0.18, 0.35), 0.125, 10, 0.02)
	crank.color(WOOD.lightened(0.1))
	for side in [-1.0, 1.0]:
		crank.box(Vector3(0, 0, side * 0.3), Vector3(0.9, 0.09, 0.04))
		crank.box(Vector3(side * 0.45, 0, 0), Vector3(0.04, 0.09, 0.64))
	crank.color(IRON)
	for x in [-0.45, 0.45]:
		for z in [-0.3, 0.3]:
			crank.box(Vector3(x, 0.0, z), Vector3(0.06, 0.1, 0.06))
	crank.color(Color(0.55, 0.55, 0.5))
	for k in 11:
		crank.box(Vector3(-0.4 + k * 0.08, -0.03, 0), Vector3(0.006, 0.006, 0.58))
	for k in 8:
		crank.box(Vector3(0, -0.03, -0.27 + k * 0.077), Vector3(0.86, 0.006, 0.006))
	crank.color(Color(0.62, 0.45, 0.35))
	crank.box(Vector3(0.1, -0.01, 0.05), Vector3(0.25, 0.04, 0.2), Basis(Vector3.UP, 0.4)) # argila na tela
	crank.color(WOOD_DARK)
	crank.box(Vector3(0.52, 0.0, 0), Vector3(0.12, 0.04, 0.05)) # pega
	obj._shape(Vector3(0, 0.38, 0), Vector3(0.95, 0.76, 0.65))


# --- Energia (Tier 2) --------------------------------------------------------------------------------

static func _shaft(mb: MeshBuilder, spin: MeshBuilder, obj: PlacedObject) -> void:
	# Eixo de transmissão: cavaletes em A com sapata, mancais de ferro com
	# tampa aparafusada e copo de graxa, eixo com cintas e acoplamentos de latão.
	for x in [-0.65, 0.65]:
		mb.color(WOOD_DARK)
		for z in [-0.26, 0.26]:
			mb.tube(PackedVector3Array([Vector3(x, 0.0, z), Vector3(x, 0.52, z * 0.2)]), 0.035, 5)
		mb.box(Vector3(x, 0.04, 0), Vector3(0.1, 0.08, 0.62)) # sapata
		mb.box(Vector3(x, 0.3, 0), Vector3(0.06, 0.06, 0.36))
		mb.color(IRON)
		mb.box(Vector3(x, 0.55, 0), Vector3(0.14, 0.06, 0.2))
		mb.box(Vector3(x, 0.64, 0), Vector3(0.12, 0.05, 0.16)) # tampa
		for z in [-0.07, 0.07]:
			_nail(mb, Vector3(x, 0.67, z), STEEL)
		mb.color(BRASS)
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.67), Vector2(0.02, 0.67), Vector2(0.025, 0.72), Vector2(0.002, 0.73)]), 6, Basis.IDENTITY, Vector3(x, 0, 0)) # copo de graxa
	spin.color(WOOD)
	spin.lathe(PackedVector2Array([Vector2(0.045, -0.95), Vector2(0.045, 0.95)]), 8, AROUND_X)
	spin.color(IRON)
	for x in [-0.3, 0.0, 0.3]:
		spin.lathe(PackedVector2Array([Vector2(0.05, x - 0.025), Vector2(0.05, x + 0.025)]), 8, AROUND_X)
	spin.color(BRASS)
	for x in [-0.97, 0.97]:
		spin.lathe(PackedVector2Array([Vector2(0.002, -0.035), Vector2(0.085, -0.035), Vector2(0.085, 0.035), Vector2(0.002, 0.035)]), 10, AROUND_X, Vector3(x, 0, 0))
		for k in 4:
			var a := TAU * k / 4.0
			spin.box(Vector3(x, cos(a) * 0.06, sin(a) * 0.06), Vector3(0.08, 0.015, 0.015)) # parafusos do acoplamento
	obj._shape(Vector3(0, 0.35, 0), Vector3(2.0, 0.7, 0.5))


static func _water_wheel(mb: MeshBuilder, spin: MeshBuilder, obj: PlacedObject) -> void:
	# Roda de pás no rio (à frente, -Z): estacas com travessas e calha de madeira,
	# eixo até a margem, mancal, caixa de engrenagem de ferro com rebites e a
	# polia de latão na porta de energia (direita); respingos na água.
	for x in [-0.55, 0.55]:
		mb.color(WOOD_DARK)
		mb.box(Vector3(x, 0.15, -1.6), Vector3(0.12, 1.6, 0.12))
		mb.box(Vector3(x, 0.5, -0.55), Vector3(0.1, 1.0, 0.1))
		mb.box(Vector3(x, 0.95, -1.08), Vector3(0.08, 0.08, 1.2))
		mb.color(IRON)
		mb.box(Vector3(x, 0.6, -1.6), Vector3(0.14, 0.12, 0.16)) # mancal
	mb.color(WOOD)
	mb.box(Vector3(0, 0.95, -1.08), Vector3(1.22, 0.06, 0.08))
	_slats(mb, Vector3(0, -0.45, -2.3), 0.7, 0.3, 0.04, 2, true, WOOD.darkened(0.15)) # calha
	mb.color(IRON)
	mb.box(Vector3(0, 0.6, 0.0), Vector3(0.4, 0.4, 0.4))
	for x in [-0.2, 0.2]:
		for y in [0.42, 0.78]:
			_nail(mb, Vector3(x, y, 0.205), STEEL)
	mb.color(IRON.lightened(0.1))
	mb.box(Vector3(0.6, 0.6, 0), Vector3(0.8, 0.08, 0.08)) # eixo de saída
	mb.box(Vector3(0.95, 0.4, 0), Vector3(0.1, 0.4, 0.14)) # mancal da saída
	_pulley(mb, Vector3(1.05, 0.6, 0), true)
	for side in [-0.2, 0.2]:
		spin.color(WOOD)
		spin.torus(1.05, 0.045, 20, 4, AROUND_Z, Vector3(0, 0, side))
		spin.color(IRON)
		spin.torus(1.09, 0.012, 20, 3, AROUND_Z, Vector3(0, 0, side))
	spin.color(WOOD)
	spin.tube(PackedVector3Array([Vector3(0, 0, -0.3), Vector3(0, 0, 1.4)]), 0.06, 8) # eixo reto até a caixa
	for k in 12:
		var a := TAU * k / 12.0
		var out := Vector3(cos(a), sin(a), 0)
		spin.color(WOOD.darkened(0.08))
		spin.box(out * 0.55, Vector3(0.05, 1.05, 0.05), Basis(Vector3.BACK, a - PI / 2))
		spin.color(WOOD.lightened(0.04 * (k % 2)))
		spin.box(out * 1.1, Vector3(0.38, 0.06, 0.44), Basis(Vector3.BACK, a))
	spin.color(IRON)
	spin.lathe(PackedVector2Array([Vector2(0.002, -0.25), Vector2(0.14, -0.25), Vector2(0.14, 0.25), Vector2(0.002, 0.25)]), 8, AROUND_Z) # cubo
	_drops(obj, Vector3(0, -0.45, -1.3), Vector3(0, 1, 0.6), 24, 2.0, 30.0)
	obj._shape(Vector3(0, 0.6, 0), Vector3(0.4, 0.4, 0.4))


static func _windmill(mb: MeshBuilder, spin: MeshBuilder, obj: PlacedObject) -> void:
	# Moinho de torre: base de pedra, torre octogonal de tábuas (faixas) afinando,
	# porta com batente, janelinha, capota de telhado com cumeeira; pás de treliça
	# com lona; caixa de engrenagem embaixo com a polia de latão (porta).
	_stone_ring(mb, Vector3.ZERO, 0.72, 10, Vector3(0.32, 0.22, 0.24), 41)
	for k in 9:
		var y0 := 0.2 + k * 0.38
		var r0 := 0.74 - k * 0.032
		var r1 := 0.74 - (k + 1) * 0.032
		mb.color(WOOD.darkened(0.06 * (k % 2)))
		mb.lathe(PackedVector2Array([Vector2(r0 + 0.02, y0), Vector2(r1, y0 + 0.38)]), 8) # tábuas sobrepostas
	mb.color(WOOD_DARK)
	mb.lathe(PackedVector2Array([Vector2(0.48, 3.62), Vector2(0.56, 3.66), Vector2(0.56, 3.72), Vector2(0.48, 3.72)]), 8)
	mb.color(Color(0.36, 0.22, 0.14))
	mb.lathe(PackedVector2Array([Vector2(0.64, 3.7), Vector2(0.5, 4.05), Vector2(0.2, 4.4), Vector2(0.002, 4.5)]), 8) # capota
	mb.color(Color(0.28, 0.17, 0.1))
	mb.box(Vector3(0, 4.15, 0), Vector3(0.06, 0.06, 1.1), Basis(Vector3.RIGHT, 0.0)) # cumeeira
	mb.color(WOOD_DARK)
	mb.box(Vector3(0, 0.62, 0.71), Vector3(0.56, 1.0, 0.06)) # batente
	_boards(mb, Vector3(0, 0.6, 0.735), Vector3(0.44, 0.92, 0.04), 4, false, WOOD.darkened(0.15)) # porta
	mb.color(IRON)
	for y in [0.35, 0.85]:
		mb.box(Vector3(-0.12, y, 0.76), Vector3(0.22, 0.03, 0.01))
	mb.color(SOOT)
	mb.box(Vector3(0, 2.3, 0.6), Vector3(0.2, 0.26, 0.04)) # janelinha
	mb.color(WOOD_DARK)
	mb.box(Vector3(0, 2.3, 0.62), Vector3(0.26, 0.03, 0.04))
	mb.box(Vector3(0, 2.3, 0.62), Vector3(0.03, 0.3, 0.04))
	mb.color(IRON)
	mb.box(Vector3(0, 0.6, 0.82), Vector3(0.28, 0.28, 0.18))
	for x in [-0.12, 0.12]:
		_nail(mb, Vector3(x, 0.72, 0.915), STEEL)
	_pulley(mb, Vector3(0, 0.6, 0.85), false)
	mb.color(WOOD_DARK)
	mb.lathe(PackedVector2Array([Vector2(0.08, 0.0), Vector2(0.08, 0.3)]), 8, AROUND_Z * Basis(Vector3.RIGHT, PI), Vector3(0, 3.62, 0.78)) # eixo das pás
	spin.color(IRON)
	spin.lathe(PackedVector2Array([Vector2(0.002, -0.12), Vector2(0.15, -0.1), Vector2(0.16, 0.08), Vector2(0.002, 0.16)]), 8, AROUND_Z)
	for k in 4:
		var a := TAU * k / 4.0
		var out := Vector3(cos(a), sin(a), 0)
		var side := Vector3(-sin(a), cos(a), 0)
		var along := Basis(Vector3.BACK, a - PI / 2)
		spin.color(WOOD_DARK)
		spin.box(out * 1.3, Vector3(0.07, 2.5, 0.07), along) # vara
		spin.color(WOOD)
		for r in 6:
			spin.box(out * (0.6 + r * 0.32) + side * 0.22, Vector3(0.45, 0.03, 0.03), Basis(Vector3.BACK, a)) # treliça
		spin.box(out * 1.45 + side * 0.44, Vector3(0.03, 1.8, 0.03), along)
		spin.color(CLOTH.darkened(0.04 * (k % 2)))
		spin.box(out * 1.5 + side * 0.22, Vector3(0.4, 1.6, 0.012), along * Basis(Vector3.UP, 0.12)) # lona
	obj._shape(Vector3(0, 2.0, 0), Vector3(1.4, 4.0, 1.4))


static func _sawmill(mb: MeshBuilder, spin: MeshBuilder, obj: PlacedObject) -> void:
	# Serraria: mesa de pranchas sobre cavaletes, trilhos com o carrinho e a tora,
	# serra circular (gira) com proteção de ferro, polia e correia até o eixo da
	# serra, pilha de tábuas cortadas e serragem.
	for x in [-0.9, 0.9]:
		for z in [-0.3, 0.3]:
			mb.color(WOOD_DARK)
			mb.box(Vector3(x, 0.4, z), Vector3(0.11, 0.8, 0.11))
		mb.color(WOOD)
		mb.box(Vector3(x, 0.18, 0), Vector3(0.08, 0.08, 0.62))
	mb.box(Vector3(0, 0.18, -0.3), Vector3(1.7, 0.08, 0.06))
	_boards(mb, Vector3(0, 0.82, 0), Vector3(2.1, 0.08, 0.75), 5, true, WOOD)
	mb.color(SOOT)
	mb.box(Vector3(0, 0.865, 0), Vector3(0.7, 0.01, 0.02)) # fenda
	mb.color(IRON)
	for z in [-0.25, 0.25]:
		mb.box(Vector3(-0.5, 0.875, z), Vector3(0.9, 0.02, 0.03)) # trilhos
	mb.color(WOOD_DARK)
	mb.box(Vector3(-0.5, 0.9, 0), Vector3(0.5, 0.05, 0.56)) # carrinho
	mb.color(Color(0.36, 0.24, 0.14))
	mb.lathe(PackedVector2Array([Vector2(0.002, -0.4), Vector2(0.15, -0.4), Vector2(0.16, 0.4), Vector2(0.002, 0.4)]), 8, Basis(Vector3.BACK, PI / 2), Vector3(-0.5, 1.07, 0.0)) # tora
	mb.color(WOOD_LIGHT.lightened(0.1))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.15, 0.0)]), 8, Basis(Vector3.BACK, -PI / 2), Vector3(-0.1, 1.07, 0.0))
	mb.color(IRON)
	mb.box(Vector3(0, 1.12, 0), Vector3(0.62, 0.04, 0.1)) # proteção da serra
	mb.box(Vector3(0.0, 1.0, -0.05), Vector3(0.04, 0.24, 0.02))
	for k in 5:
		mb.color(WOOD_LIGHT.darkened(0.04 * (k % 2)))
		mb.box(Vector3(0.72, 0.9 + k * 0.03, 0.0), Vector3(0.55, 0.025, 0.13)) # tábuas cortadas
	mb.color(IRON)
	mb.box(Vector3(-1.0, 0.6, 0), Vector3(0.22, 0.3, 0.3)) # caixa da polia
	for y in [0.5, 0.7]:
		_nail(mb, Vector3(-1.0, y, 0.155), STEEL)
	_pulley(mb, Vector3(-1.15, 0.6, 0), true)
	mb.color(Color(0.22, 0.14, 0.08))
	for z in [-0.04, 0.04]:
		mb.tube(PackedVector3Array([Vector3(-0.95, 0.66, z + 0.14), Vector3(-0.1, 0.88, z + 0.1)]), 0.012, 4) # correia
	mb.color(Color(0.72, 0.6, 0.4))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.12), Vector2(0.2, 0.06), Vector2(0.32, 0.0)]), 8, Basis.IDENTITY, Vector3(0.15, 0, 0.15)) # serragem
	spin.color(STEEL)
	spin.lathe(PackedVector2Array([Vector2(0.002, -0.006), Vector2(0.28, -0.004), Vector2(0.28, 0.004), Vector2(0.002, 0.006)]), 18, AROUND_Z)
	for k in 18:
		var a := TAU * k / 18.0
		spin.box(Vector3(cos(a), sin(a), 0) * 0.29, Vector3(0.035, 0.03, 0.01), Basis(Vector3.BACK, a + 0.4))
	spin.color(IRON)
	spin.lathe(PackedVector2Array([Vector2(0.002, -0.03), Vector2(0.05, -0.03), Vector2(0.05, 0.03), Vector2(0.002, 0.03)]), 8, AROUND_Z)
	obj._shape(Vector3(0, 0.45, 0), Vector3(2.1, 0.9, 0.75))


static func _ram_pump(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Carneiro hidráulico: base de pedra, corpo de ferro fundido com a válvula de
	# escape (batendo água), câmara de ar em domo rebitada, cano de entrada
	# vindo do rio, cano de saída subindo até o esguicho de latão (a porta do
	# cano de cobre fica do lado direito).
	_stone_ring(mb, Vector3.ZERO, 0.22, 7, Vector3(0.18, 0.12, 0.14), 51)
	mb.color(STONE.darkened(0.1))
	mb.box(Vector3(0, 0.08, 0), Vector3(0.5, 0.06, 0.5))
	mb.color(IRON)
	mb.box(Vector3(0, 0.2, 0), Vector3(0.36, 0.18, 0.22))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.28), Vector2(0.12, 0.28), Vector2(0.13, 0.6), Vector2(0.1, 0.72), Vector2(0.05, 0.78), Vector2(0.002, 0.79)]), 10) # câmara de ar
	mb.color(IRON.lightened(0.12))
	for y in [0.32, 0.55]:
		mb.lathe(PackedVector2Array([Vector2(0.125, y), Vector2(0.14, y + 0.01), Vector2(0.125, y + 0.02)]), 10)
		for k in 8:
			var a := TAU * k / 8.0
			_nail(mb, Vector3(cos(a) * 0.14, y + 0.01, sin(a) * 0.14), STEEL)
	mb.color(BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.29), Vector2(0.05, 0.29), Vector2(0.05, 0.33), Vector2(0.002, 0.34)]), 8, Basis.IDENTITY, Vector3(-0.12, 0, 0.0)) # válvula de escape
	mb.color(IRON.darkened(0.2))
	mb.tube(PackedVector3Array([Vector3(-0.18, 0.2, 0.0), Vector3(-0.45, 0.2, -0.1), Vector3(-0.9, 0.0, -0.4), Vector3(-1.2, -0.3, -0.6)]), 0.05, 6) # entrada
	mb.color(IRON.darkened(0.1))
	mb.tube(PackedVector3Array([Vector3(0.0, 0.7, 0.08), Vector3(0.0, 1.0, 0.25), Vector3(0.0, 1.6, 0.55), Vector3(0.0, 1.7, 0.72)]), 0.035, 6) # saída
	mb.color(BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.035, 0.0), Vector2(0.07, 0.08)]), 8, AROUND_Z, Vector3(0, 1.7, 0.75))
	mb.color(WOOD_DARK)
	mb.box(Vector3(0, 0.85, 0.35), Vector3(0.05, 1.7, 0.05)) # escora do cano
	mb.color(IRON)
	mb.box(Vector3(0, 1.4, 0.45), Vector3(0.08, 0.04, 0.12))
	_drops(obj, Vector3(0, 1.72, 0.8), Vector3(0, 0.4, 1), 30, 3.2, 25.0)
	_drops(obj, Vector3(-0.12, 0.36, 0.0), Vector3.UP, 8, 1.2, 40.0) # a válvula cuspindo
	obj._shape(Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.5))
