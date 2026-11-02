class_name SteamModels
extends RefCounted
## Tier 3: modelos, textos e [E] das máquinas a vapor e de metal. A lógica de
## verdade fica em Fluids (canos, caldeira, alto-forno), Smelting (fornalhas) e
## Power (energia). Estilo PS2: poucos polígonos, cores foscas, rebites e
## flanges de latão nas portas (onde o cano encaixa).
##   pipe          trecho reto de cano de cobre (extra.len)
##   blast_furnace base do alto-forno (fornalha + fole); blast_stack = anel de tijolo
##   boiler        caldeira: fornalha de tijolo + tambor rebitado, manômetro, visor de nível
##   steam_engine  motor a vapor horizontal com volante (gera força para os eixos)
##   water_tank    caixa d'água de aduelas, 4 portas
##   sprinkler     aspersor: molha as plantações em volta quando tem água no cano
##   lathe, press  torno e prensa (bancadas que precisam do eixo girando)
##   distillery    alambique de cobre com serpentina na tina d'água

const KINDS := ["pipe", "blast_furnace", "blast_stack", "boiler", "steam_engine", "water_tank", "sprinkler", "lathe", "press", "distillery"]
const NAMES := {"pipe": "Cano", "blast_furnace": "Alto-forno", "blast_stack": "Anel do alto-forno", "boiler": "Caldeira",
	"steam_engine": "Motor a vapor", "water_tank": "Caixa d'água", "sprinkler": "Aspersor", "lathe": "Torno", "press": "Prensa",
	"distillery": "Destilaria"}

const BRICK := Color(0.6, 0.3, 0.2)
const BRICK_DARK := Color(0.45, 0.22, 0.15)
const IRON := Color(0.22, 0.21, 0.21)
const STEEL := Color(0.5, 0.51, 0.53)
const COPPER := Color(0.72, 0.42, 0.25)
const BRASS := Color(0.62, 0.5, 0.26)
const WOOD := Color(0.4, 0.26, 0.15)
const WATER := Color(0.3, 0.48, 0.62)


# --- Texto e [E] ---------------------------------------------------------------------

static func text(obj: PlacedObject) -> String:
	var name: String = NAMES.get(obj.kind, obj.kind)
	var water: float = obj.extra.get("water", 0.0)
	var pour := _holding_water() and PlacedManager.POUR_CAP.has(obj.kind)
	var hint := "  · clique: despeja a garrafa" if pour else ""
	match obj.kind:
		"pipe":
			var flow: float = obj.extra.get("flow", 0.0)
			var vapor: float = obj.extra.get("vapor", 0.0)
			if vapor > 0.05:
				return "Cano: vapor %.1f/s" % vapor
			if flow > 0.05:
				return "Cano: água %.1f/s" % flow
			return "Cano (parado)"
		"blast_furnace":
			var rings := Fluids.blast_rings(obj)
			if rings < Fluids.BLAST_RINGS:
				return "[E] %s (incompleto: falta%s %d anel%s em cima)" % [name, "m" if Fluids.BLAST_RINGS - rings > 1 else "",
					Fluids.BLAST_RINGS - rings, "" if Fluids.BLAST_RINGS - rings == 1 else "s"]
			return "[E] %s · %s" % [name, Power.status(obj)]
		"blast_stack":
			return name
		"boiler":
			if obj.extra.get("dry", 0.0) > 0.0:
				return "[E] CALDEIRA SECA E QUENTE! Ponha água ou apague o fogo"
			return "[E] %s · água %d/%d · pressão %d%%%s" % [name, int(water), int(Fluids.BOILER_WATER),
				int(obj.extra.get("pressure", 0.0) / Fluids.PRESSURE_MAX * 100.0), hint]
		"steam_engine":
			var steam: float = obj.extra.get("steam", 0.0)
			return "%s: gera %s de força · %s" % [name, Power._num(snappedf(Power.output(obj), 0.1)), Power.status(obj)] if steam > 0.02 else name + ": sem vapor (cano da caldeira)"
		"water_tank":
			return "%s: %d de %d%s%s" % [name, int(water), int(Fluids.TANK_CAP), "  [E] encher garrafa" if water >= 1.0 else "", hint]
		"sprinkler":
			return name + (": molhando (plantas a 8 m crescem mais rápido)" if obj.extra.get("wet", false) else ": sem água no cano")
		"lathe", "press":
			return "[E] %s · %s" % [name, Power.status(obj)]
		"distillery":
			return "[E] %s · água %d/%d%s" % [name, int(water), int(Fluids.STILL_WATER), hint]
	return name


static func _holding_water() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var player := tree.get_first_node_in_group("player") as Player if tree else null
	return player != null and player.inventory.selected_id() in [&"agua", &"agua_suja"]


static func interact(player: Player, obj: PlacedObject) -> void:
	match obj.kind:
		"blast_furnace", "boiler", "distillery":
			StorageUI.open_for(player, Smelting.key_of(obj), obj)
		"lathe":
			CraftingUI.open_for(player, "torno", obj)
		"press":
			CraftingUI.open_for(player, "prensa", obj)
		"water_tank":
			var bottle := Cooking.find_any(player.inventory, {&"garrafa": true})
			if bottle < 0 or obj.extra.get("water", 0.0) < 1.0:
				Sfx.play("click", -6.0, 0.6)
				return
			player.inventory.take(bottle, 1)
			ItemFly.play(&"agua_suja", obj.global_position + Vector3.UP * 0.8, player)
			(obj.get_parent() as PlacedManager).request("draw_water", [obj.net_id])
			Sfx.play_at("slap", obj.global_position + Vector3.UP, -6.0, 1.3)
		_:
			Sfx.play("click", -6.0, 0.6)


## Garrafa de água na mão + clique: despeja na caldeira/destilaria/caixa. true = despejou.
static func pour(player: Player, obj: PlacedObject) -> bool:
	if not PlacedManager.POUR_CAP.has(obj.kind) or obj.extra.get("water", 0.0) > PlacedManager.POUR_CAP[obj.kind] - 1.0:
		return false
	player.inventory.take(player.inventory.selected, 1)
	player.inventory.add(&"garrafa", 1)
	(obj.get_parent() as PlacedManager).request("pour", [obj.net_id]) # o host soma e avisa todos
	Sfx.play_at("slap", obj.global_position + Vector3.UP, -2.0, 0.8)
	return true


# --- Atualização visual (1x por segundo e quando o host manda) ------------------------

static func refresh(obj: PlacedObject) -> void:
	match obj.kind:
		"pipe":
			if obj.get_meta("built_len", -1.0) != obj.extra.get("len", 1.0):
				_build_pipe(obj)
		"sprinkler":
			var wet: bool = obj.extra.get("wet", false)
			obj.extra.speed = 1.0 if wet else 0.0 # cabeça girando (só visual)
			var spray := obj.get_node_or_null("Spray") as CPUParticles3D
			if spray:
				spray.emitting = wet
		"steam_engine":
			var puff := obj.get_node_or_null("Puff") as CPUParticles3D
			if puff:
				puff.emitting = obj.extra.get("speed", 0.0) > 0.05
		"boiler":
			var needle := obj.get_node_or_null("Needle") as Node3D
			if needle:
				needle.rotation.z = lerpf(2.2, -2.2, clampf(obj.extra.get("pressure", 0.0) / Fluids.PRESSURE_MAX, 0.0, 1.0))
			var level := obj.get_node_or_null("Level") as Node3D
			if level:
				level.scale.y = maxf(clampf(obj.extra.get("water", 0.0) / Fluids.BOILER_WATER, 0.0, 1.0), 0.02)
			var valve := obj.get_node_or_null("Valve") as CPUParticles3D
			var t := Time.get_ticks_msec()
			if obj.extra.get("vent", false):
				if valve:
					valve.emitting = true
				if t - int(obj.get_meta("vent_t", 0)) > 2500:
					obj.set_meta("vent_t", t)
					Sfx.play_at("hiss", obj.global_position + Vector3.UP * 2.0, -2.0, 1.0)
			elif valve:
				valve.emitting = false
			if obj.extra.get("dry", 0.0) > 0.0 and t - int(obj.get_meta("alarm_t", 0)) > 1200:
				obj.set_meta("alarm_t", t)
				Sfx.play_at("whistle", obj.global_position + Vector3.UP * 2.0, 4.0, 1.0 + obj.extra.get("dry", 0.0) * 0.03) # apito de perigo
		"water_tank":
			var surface := obj.get_node_or_null("Level") as Node3D
			if surface:
				var fill := clampf(obj.extra.get("water", 0.0) / Fluids.TANK_CAP, 0.0, 1.0)
				surface.visible = fill > 0.01
				surface.position.y = 0.4 + fill * 0.95
		"blast_furnace":
			var smoke := obj.get_node_or_null("Smoke") as CPUParticles3D
			if smoke:
				smoke.emitting = obj.is_lit() and Fluids.blast_complete(obj)


# --- Modelos ---------------------------------------------------------------------------

static func build(kind: String, obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	var spin := MeshBuilder.new()
	var spin_at := Vector3.ZERO
	var spin_axis := Vector3.RIGHT
	match kind:
		"pipe":
			_build_pipe(obj)
			return
		"blast_furnace":
			_blast_base(mb, obj)
			spin_at = Vector3(-1.0, 0.6, 0)
			spin.color(BRASS)
			spin.lathe(PackedVector2Array([Vector2(0.002, -0.05), Vector2(0.14, -0.05), Vector2(0.14, 0.05), Vector2(0.002, 0.05)]), 10, Basis(Vector3.BACK, PI / 2))
			spin.color(IRON)
			for k in 4:
				spin.box(Vector3.ZERO, Vector3(0.02, 0.24, 0.03), Basis(Vector3.RIGHT, k * PI / 4)) # raios da polia
		"blast_stack":
			_blast_ring(mb, obj)
		"boiler":
			_boiler(mb, obj)
		"steam_engine":
			_steam_engine(mb, spin, obj)
			spin_at = Vector3(0, 0.6, 0)
		"water_tank":
			_water_tank(mb, obj)
		"sprinkler":
			_sprinkler(mb, spin, obj)
			spin_at = Vector3(0, 0.72, 0)
			spin_axis = Vector3.UP
		"lathe":
			_lathe(mb, spin, obj)
			spin_at = Vector3(-0.45, 0.98, 0)
		"press":
			_press(mb, spin, obj)
			spin_at = Vector3(0, 1.55, 0)
			spin_axis = Vector3.UP
		"distillery":
			_distillery(mb, obj)
	add_ports(obj, mb)
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


## Flange de latão com um toco de cano em cada porta de fluido (onde o cano encaixa).
## Também usado no carneiro e no coletor de chuva (modelos antigos).
static func add_ports(obj: PlacedObject, mb: MeshBuilder = null) -> void:
	var own := mb == null
	if own:
		mb = MeshBuilder.new()
	for port in Fluids.PORTS.get(obj.kind, []):
		var at: Vector3 = port[0]
		var out := Vector3(at.x, 0.0, at.z)
		var dir := out.normalized() if out.length() > 0.08 else Vector3.UP
		if obj.kind == "boiler" and at.y > 1.5 or obj.kind == "steam_engine":
			dir = Vector3.UP # saída de vapor no alto do domo / entrada em cima do cilindro
		var basis := _basis_y_to(dir)
		mb.color(COPPER.darkened(0.1))
		mb.lathe(PackedVector2Array([Vector2(0.05, -0.16), Vector2(0.05, -0.02)]), 8, basis, at)
		mb.color(BRASS if port[1] == "water" else STEEL.lightened(0.2))
		mb.lathe(PackedVector2Array([Vector2(0.002, -0.02), Vector2(0.085, -0.02), Vector2(0.085, 0.01), Vector2(0.05, 0.01), Vector2(0.05, 0.0), Vector2(0.002, 0.0)]), 10, basis, at)
	if own:
		var mesh := MeshInstance3D.new()
		mesh.mesh = mb.finish(PlacedObject._mat(), false)
		obj.add_child(mesh)


static func _basis_y_to(dir: Vector3) -> Basis:
	if dir.is_equal_approx(Vector3.UP):
		return Basis.IDENTITY
	if dir.is_equal_approx(Vector3.DOWN):
		return Basis(Vector3.RIGHT, PI)
	var axis := Vector3.UP.cross(dir).normalized()
	return Basis(axis, Vector3.UP.angle_to(dir))


# --- Cano ------------------------------------------------------------------------------

## Trecho de cano: tubo de cobre em +Z com flanges nas pontas e braçadeiras.
static func _build_pipe(obj: PlacedObject) -> void:
	var length: float = obj.extra.get("len", 1.0)
	obj.set_meta("built_len", length)
	for child in obj.get_children():
		if child.name in ["PipeMesh", "PipeShape"]:
			obj.remove_child(child)
			child.queue_free()
	var mb := MeshBuilder.new()
	var along := Basis(Vector3.RIGHT, PI / 2) # eixo do torno (Y) -> +Z
	mb.color(COPPER)
	mb.lathe(PackedVector2Array([Vector2(0.055, 0.02), Vector2(0.055, length - 0.02)]), 8, along)
	mb.color(COPPER.darkened(0.2))
	for z in [0.0, length - 0.05]:
		mb.lathe(PackedVector2Array([Vector2(0.002, z), Vector2(0.08, z), Vector2(0.08, z + 0.05), Vector2(0.002, z + 0.05)]), 8, along)
	mb.color(IRON)
	var clamps := maxi(int(length / 1.5), 0)
	for k in clamps:
		var z := length * (k + 1) / (clamps + 1)
		mb.lathe(PackedVector2Array([Vector2(0.06, z - 0.02), Vector2(0.065, z - 0.02), Vector2(0.065, z + 0.02), Vector2(0.06, z + 0.02)]), 8, along)
	var mesh := MeshInstance3D.new()
	mesh.name = "PipeMesh"
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.name = "PipeShape"
	var box := BoxShape3D.new()
	box.size = Vector3(0.16, 0.16, maxf(length, 0.1))
	shape.shape = box
	shape.position = Vector3(0, 0, length * 0.5)
	obj.add_child(shape)


# --- Alto-forno --------------------------------------------------------------------------

static func _blast_base(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Bloco de tijolo com boca em arco na frente (+Z), cintas de ferro, fole e algaraviz (tubo de ar) do lado.
	var h := Fluids.BLAST_BASE_H
	for row in 6:
		mb.color(BRICK if row % 2 == 0 else BRICK.darkened(0.08))
		mb.box(Vector3(0, row * h / 6.0 + h / 12.0, 0), Vector3(1.6, h / 6.0 - 0.01, 1.6))
	ObjectModels.mouth(mb, Vector3(0, 0.45, 0.8), 0.5, 0.42)
	mb.color(BRICK_DARK)
	for k in 7:
		var a := PI * k / 6.0
		mb.box(Vector3(cos(a) * 0.3, 0.7 + sin(a) * 0.12, 0.815), Vector3(0.11, 0.08, 0.03), Basis(Vector3.BACK, a)) # arco
	mb.color(IRON)
	for y in [0.15, h - 0.08]:
		mb.box(Vector3(0, y, 0.0), Vector3(1.64, 0.05, 1.64)) # cintas
	for x in [-0.78, 0.78]:
		for z in [-0.78, 0.78]:
			mb.box(Vector3(x, h * 0.5, z), Vector3(0.07, h, 0.07)) # cantoneiras
	mb.box(Vector3(0, 0.2, 0.83), Vector3(0.62, 0.04, 0.08)) # soleira de ferro
	# Fole de couro e madeira do lado esquerdo, soprando pelo tubo.
	mb.color(WOOD)
	mb.box(Vector3(-1.0, 0.25, 0), Vector3(0.32, 0.5, 0.5)) # caixa do mancal
	mb.color(Color(0.36, 0.24, 0.15))
	mb.box(Vector3(-0.95, 0.85, 0), Vector3(0.4, 0.28, 0.55), Basis(Vector3.BACK, 0.15)) # fole
	mb.color(WOOD.darkened(0.2))
	mb.box(Vector3(-0.95, 1.0, 0), Vector3(0.44, 0.04, 0.6), Basis(Vector3.BACK, 0.25))
	mb.color(IRON.lightened(0.1))
	mb.tube(PackedVector3Array([Vector3(-0.78, 0.85, 0), Vector3(-0.5, 0.7, 0), Vector3(-0.2, 0.35, 0.2)]), 0.05, 6) # tubo de ar
	mb.tube(PackedVector3Array([Vector3(-1.0, 0.6, 0), Vector3(-0.98, 0.75, 0)]), 0.02, 4) # biela do fole
	StationModels._fire(obj, Vector3(0, 0.4, 0.74), 0.1, 1.0)
	var smoke := _smoke(Vector3(0, h + Fluids.BLAST_RING_H * Fluids.BLAST_RINGS + 0.1, 0), 0.35)
	smoke.name = "Smoke"
	obj.add_child(smoke)
	obj._shape(Vector3(0, h * 0.5, 0), Vector3(1.6, h, 1.6))


static func _blast_ring(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Seção octogonal de tijolo afinando, com fiadas e cintas de ferro (empilha em cima da base).
	var h := Fluids.BLAST_RING_H
	for row in 5:
		mb.color(BRICK if row % 2 == 0 else BRICK.darkened(0.08))
		var y0 := row * h / 5.0
		var y1 := y0 + h / 5.0 - 0.01
		mb.lathe(PackedVector2Array([Vector2(0.5, y0), Vector2(0.74 - row * 0.012, y0), Vector2(0.73 - row * 0.012, y1), Vector2(0.5, y1)]), 8)
	mb.color(IRON)
	mb.lathe(PackedVector2Array([Vector2(0.74, 0.1), Vector2(0.76, 0.1), Vector2(0.76, 0.16), Vector2(0.74, 0.16)]), 8)
	mb.lathe(PackedVector2Array([Vector2(0.69, h - 0.12), Vector2(0.71, h - 0.12), Vector2(0.71, h - 0.06), Vector2(0.69, h - 0.06)]), 8)
	mb.color(Color(0.1, 0.07, 0.05))
	mb.lathe(PackedVector2Array([Vector2(0.002, h - 0.15), Vector2(0.5, h - 0.15)]), 8) # fundo escuro (olhando de cima)
	obj._shape(Vector3(0, h * 0.5, 0), Vector3(1.3, h, 1.3))


# --- Caldeira ----------------------------------------------------------------------------

static func _boiler(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Fornalha de tijolo embaixo (porta de ferro na frente), tambor de aço rebitado
	# deitado em cima, domo de vapor, chaminé, manômetro, visor de nível e válvula.
	for row in 4:
		mb.color(BRICK if row % 2 == 0 else BRICK.darkened(0.08))
		mb.box(Vector3(0, row * 0.2 + 0.1, 0), Vector3(2.2, 0.19, 1.1))
	ObjectModels.mouth(mb, Vector3(0, 0.38, 0.55), 0.44, 0.34)
	mb.color(STEEL)
	var drum := Basis(Vector3.BACK, PI / 2) # torno em X
	mb.lathe(PackedVector2Array([Vector2(0.002, -1.0), Vector2(0.4, -1.02), Vector2(0.5, -0.95), Vector2(0.52, -0.85),
		Vector2(0.52, 0.85), Vector2(0.5, 0.95), Vector2(0.4, 1.02), Vector2(0.002, 1.0)]), 14, drum, Vector3(0, 1.3, 0))
	mb.color(IRON)
	for x in [-0.7, -0.25, 0.25, 0.7]:
		mb.lathe(PackedVector2Array([Vector2(0.525, -0.03), Vector2(0.54, -0.03), Vector2(0.54, 0.03), Vector2(0.525, 0.03)]), 14, drum, Vector3(x, 1.3, 0)) # emendas
		for k in 10:
			var a := TAU * k / 10.0
			mb.box(Vector3(x + 0.05, 1.3 + sin(a) * 0.535, cos(a) * 0.535), Vector3(0.025, 0.025, 0.025)) # rebites
	for x in [-0.8, 0.8]:
		mb.box(Vector3(x, 0.88, 0), Vector3(0.12, 0.12, 0.9)) # berço
	mb.color(STEEL.darkened(0.1))
	mb.lathe(PackedVector2Array([Vector2(0.2, 1.75), Vector2(0.2, 1.85), Vector2(0.16, 1.92), Vector2(0.05, 1.95), Vector2(0.002, 1.95)]), 10, Basis.IDENTITY, Vector3(0.55, 0, 0)) # domo
	mb.color(IRON.darkened(0.2))
	mb.lathe(PackedVector2Array([Vector2(0.12, 0.8), Vector2(0.12, 2.75), Vector2(0.16, 2.8), Vector2(0.16, 2.9), Vector2(0.11, 2.9)]), 8, Basis.IDENTITY, Vector3(-0.85, 0, 0)) # chaminé
	# Válvula de segurança com alavanca e peso.
	mb.color(BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.04, 1.8), Vector2(0.04, 1.95), Vector2(0.06, 1.98)]), 8, Basis.IDENTITY, Vector3(-0.2, 0, 0))
	mb.color(IRON)
	mb.box(Vector3(-0.05, 1.99, 0), Vector3(0.4, 0.02, 0.03))
	mb.box(Vector3(0.14, 1.95, 0), Vector3(0.07, 0.07, 0.07))
	# Manômetro (mostrador branco; o ponteiro é o nó Needle) e visor de nível (vidro + água = Level).
	mb.color(BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.12, 0.0), Vector2(0.12, 0.04), Vector2(0.002, 0.04)]), 12, Basis(Vector3.RIGHT, PI / 2), Vector3(0.75, 1.45, 0.5))
	mb.color(Color(0.92, 0.9, 0.82))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.041), Vector2(0.1, 0.041)]), 12, Basis(Vector3.RIGHT, PI / 2), Vector3(0.75, 1.45, 0.5))
	mb.color(Color(0.8, 0.15, 0.1))
	mb.box(Vector3(0.75 + 0.07, 1.45 + 0.07, 0.546), Vector3(0.03, 0.01, 0.005), Basis(Vector3.BACK, -0.8)) # faixa vermelha
	mb.color(BRASS)
	mb.box(Vector3(-0.45, 1.05, 0.56), Vector3(0.06, 0.04, 0.06))
	mb.box(Vector3(-0.45, 1.55, 0.56), Vector3(0.06, 0.04, 0.06))
	mb.color(Color(0.7, 0.8, 0.8))
	mb.box(Vector3(-0.45, 1.3, 0.56), Vector3(0.035, 0.46, 0.035)) # tubo de vidro
	var needle := MeshBuilder.new()
	needle.color(Color(0.1, 0.1, 0.1))
	needle.box(Vector3(0, 0.045, 0), Vector3(0.012, 0.09, 0.006))
	var needle_node := MeshInstance3D.new()
	needle_node.name = "Needle"
	needle_node.mesh = needle.finish(PlacedObject._mat(), false)
	needle_node.position = Vector3(0.75, 1.45, 0.548)
	needle_node.rotation.z = 2.2
	obj.add_child(needle_node)
	var level := MeshBuilder.new()
	level.color(WATER)
	level.box(Vector3(0, 0.22, 0), Vector3(0.04, 0.44, 0.04))
	var level_node := MeshInstance3D.new()
	level_node.name = "Level"
	level_node.mesh = level.finish(PlacedObject._mat(), false)
	level_node.position = Vector3(-0.45, 1.08, 0.565)
	level_node.scale.y = 0.02
	obj.add_child(level_node)
	StationModels._fire(obj, Vector3(0, 0.36, 0.48), 0.1, 0.9)
	var smoke := _smoke(Vector3(-0.85, 2.95, 0), 0.2)
	obj.add_child(smoke)
	StationModels._register_fire(obj, smoke) # fumaça só com fogo aceso
	var valve := _steam_puff(Vector3(-0.2, 2.0, 0), Vector3.UP, 30)
	valve.name = "Valve"
	obj.add_child(valve)
	obj._shape(Vector3(0, 1.0, 0), Vector3(2.3, 2.0, 1.15))


# --- Motor a vapor --------------------------------------------------------------------------

static func _steam_engine(mb: MeshBuilder, spin: MeshBuilder, obj: PlacedObject) -> void:
	# Base de ferro fundido; cilindro deitado (eixo Z) atrás, haste até a cruzeta; virabrequim
	# em X com volante (gira: Spin) e a polia/porta de latão na ponta direita.
	mb.color(IRON)
	mb.box(Vector3(0.45, 0.08, -0.3), Vector3(1.6, 0.16, 1.4)) # base
	mb.color(IRON.lightened(0.08))
	for x in [0.15, 1.0]:
		mb.box(Vector3(x, 0.36, 0), Vector3(0.14, 0.42, 0.22)) # mancais
		mb.box(Vector3(x, 0.6, 0), Vector3(0.18, 0.08, 0.26))
	# Cilindro e caixa de vapor.
	mb.color(STEEL.darkened(0.15))
	var cyl := Basis(Vector3.RIGHT, PI / 2) # torno em Z
	mb.lathe(PackedVector2Array([Vector2(0.002, -1.0), Vector2(0.26, -1.0), Vector2(0.28, -0.96), Vector2(0.28, -0.44), Vector2(0.26, -0.4), Vector2(0.002, -0.4)]), 12, cyl, Vector3(-0.15, 0.6, 0))
	mb.color(BRASS)
	for z in [-0.98, -0.42]:
		mb.lathe(PackedVector2Array([Vector2(0.27, z - 0.02), Vector2(0.3, z - 0.02), Vector2(0.3, z + 0.02), Vector2(0.27, z + 0.02)]), 12, cyl, Vector3(-0.15, 0.6, 0))
	mb.color(STEEL.darkened(0.25))
	mb.box(Vector3(-0.15, 0.95, -0.7), Vector3(0.24, 0.2, 0.5)) # caixa de vapor
	mb.color(IRON.darkened(0.2))
	mb.tube(PackedVector3Array([Vector3(-0.15, 0.95, -0.95), Vector3(-0.15, 1.1, -1.0), Vector3(-0.15, 1.4, -1.0)]), 0.05, 6) # escape
	# Haste do pistão, guia da cruzeta e biela até o virabrequim.
	mb.color(STEEL.lightened(0.2))
	mb.tube(PackedVector3Array([Vector3(-0.15, 0.6, -0.4), Vector3(-0.15, 0.6, -0.1)]), 0.03, 6)
	mb.color(IRON)
	mb.box(Vector3(-0.15, 0.48, -0.2), Vector3(0.2, 0.04, 0.36)) # guia
	mb.box(Vector3(-0.15, 0.6, -0.08), Vector3(0.12, 0.12, 0.08)) # cruzeta
	mb.color(STEEL)
	mb.tube(PackedVector3Array([Vector3(-0.15, 0.6, -0.08), Vector3(-0.15, 0.68, 0.0)]), 0.025, 6)
	# Governador de bolas (enfeite) e lubrificador de latão.
	mb.color(BRASS)
	mb.tube(PackedVector3Array([Vector3(0.15, 0.64, 0), Vector3(0.15, 1.05, 0)]), 0.015, 4)
	for side in [-1.0, 1.0]:
		mb.lathe(PackedVector2Array([Vector2(0.002, -0.05), Vector2(0.05, -0.03), Vector2(0.05, 0.03), Vector2(0.002, 0.05)]), 8, Basis.IDENTITY, Vector3(0.15 + side * 0.12, 0.98, 0))
		mb.tube(PackedVector3Array([Vector3(0.15, 1.05, 0), Vector3(0.15 + side * 0.12, 0.98, 0)]), 0.01, 4)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.05, 0.0), Vector2(0.06, 0.1), Vector2(0.02, 0.14), Vector2(0.002, 0.15)]), 8, Basis.IDENTITY, Vector3(-0.3, 1.05, -0.7))
	# Parte que gira (pivô no virabrequim, y = 0.6): eixo, manivela e volante raiado.
	var around_x := Basis(Vector3.BACK, PI / 2) # torno em X
	spin.color(STEEL.lightened(0.1))
	spin.lathe(PackedVector2Array([Vector2(0.04, 0.25), Vector2(0.04, -1.15)]), 8, around_x) # (o torno em X cresce para -X)
	spin.color(IRON)
	spin.box(Vector3(-0.15, 0.06, 0), Vector3(0.06, 0.2, 0.1)) # manivela
	spin.lathe(PackedVector2Array([Vector2(0.45, -0.07), Vector2(0.55, -0.06), Vector2(0.55, 0.06), Vector2(0.45, 0.07)]), 16, around_x, Vector3(0.65, 0, 0)) # aro
	spin.lathe(PackedVector2Array([Vector2(0.002, -0.08), Vector2(0.09, -0.08), Vector2(0.09, 0.08), Vector2(0.002, 0.08)]), 10, around_x, Vector3(0.65, 0, 0)) # cubo
	for k in 6:
		spin.box(Vector3(0.65, 0, 0), Vector3(0.04, 0.92, 0.05), Basis(Vector3.RIGHT, k * PI / 6.0)) # raios
	spin.color(BRASS)
	spin.lathe(PackedVector2Array([Vector2(0.002, -0.05), Vector2(0.13, -0.05), Vector2(0.13, 0.05), Vector2(0.002, 0.05)]), 10, around_x, Vector3(1.08, 0, 0)) # polia
	var puff := _steam_puff(Vector3(-0.15, 1.42, -1.0), Vector3.UP, 16)
	puff.name = "Puff"
	obj.add_child(puff)
	var chug := SteamChug.new()
	obj.add_child(chug)
	obj._shape(Vector3(0.45, 0.6, -0.3), Vector3(1.6, 1.2, 1.4))


# --- Caixa d'água, aspersor -------------------------------------------------------------------

static func _water_tank(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Estrado de madeira baixo, tina de aduelas com cintas de ferro e tampa meio aberta.
	mb.color(WOOD.darkened(0.2))
	for x in [-0.4, 0.4]:
		for z in [-0.4, 0.4]:
			mb.box(Vector3(x, 0.12, z), Vector3(0.12, 0.24, 0.12))
	mb.box(Vector3(0, 0.27, 0), Vector3(1.1, 0.06, 1.1))
	for k in 16:
		var a := TAU * k / 16.0
		mb.color(WOOD.lightened(0.04 * (k % 3)))
		mb.box(Vector3(cos(a) * 0.52, 0.85, sin(a) * 0.52), Vector3(0.05, 1.1, 0.21), Basis(Vector3.UP, -a)) # aduelas
	mb.color(WOOD.darkened(0.1))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.31), Vector2(0.5, 0.31), Vector2(0.5, 0.34), Vector2(0.002, 0.34)]), 16) # fundo
	mb.color(IRON)
	for y in [0.45, 0.85, 1.3]:
		mb.lathe(PackedVector2Array([Vector2(0.55, y - 0.03), Vector2(0.565, y - 0.03), Vector2(0.565, y + 0.03), Vector2(0.55, y + 0.03)]), 16)
	mb.color(WOOD)
	mb.box(Vector3(0.25, 1.42, 0), Vector3(0.55, 0.04, 1.05)) # meia tampa
	var level := MeshBuilder.new()
	level.color(WATER)
	level.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.49, 0.0)]), 16)
	var surface := MeshInstance3D.new()
	surface.name = "Level"
	surface.mesh = level.finish(PlacedObject._mat(), false)
	surface.visible = false
	obj.add_child(surface)
	obj._shape(Vector3(0, 0.72, 0), Vector3(1.1, 1.45, 1.1))


static func _sprinkler(mb: MeshBuilder, spin: MeshBuilder, obj: PlacedObject) -> void:
	# Pé de ferro, cano subindo e cabeça de latão com dois braços que gira com a água.
	mb.color(IRON)
	mb.box(Vector3(0, 0.03, 0), Vector3(0.36, 0.06, 0.36))
	mb.color(COPPER)
	mb.tube(PackedVector3Array([Vector3(0, 0.1, 0.18), Vector3(0, 0.1, 0.02), Vector3(0, 0.15, 0), Vector3(0, 0.7, 0)]), 0.03, 6)
	spin.color(BRASS)
	spin.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.05, 0.0), Vector2(0.04, 0.06), Vector2(0.002, 0.07)]), 8)
	for side in [-1.0, 1.0]:
		spin.tube(PackedVector3Array([Vector3(0, 0.03, 0), Vector3(side * 0.2, 0.05, 0), Vector3(side * 0.24, 0.05, side * 0.05)]), 0.015, 4)
	var spray := CPUParticles3D.new()
	spray.name = "Spray"
	spray.amount = 50
	spray.lifetime = 1.2
	spray.position = Vector3(0, 0.78, 0)
	spray.direction = Vector3(0, 1, 0)
	spray.spread = 75.0
	spray.gravity = Vector3(0, -7, 0)
	spray.initial_velocity_min = 2.5
	spray.initial_velocity_max = 4.0
	spray.emitting = false
	var drop := BoxMesh.new()
	drop.size = Vector3.ONE * 0.03
	var drop_mat := StandardMaterial3D.new()
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.albedo_color = Color(0.6, 0.75, 0.9, 0.6)
	drop.material = drop_mat
	spray.mesh = drop
	obj.add_child(spray)
	obj._shape(Vector3(0, 0.35, 0), Vector3(0.3, 0.7, 0.3))


# --- Torno, prensa --------------------------------------------------------------------------

static func _lathe(mb: MeshBuilder, spin: MeshBuilder, obj: PlacedObject) -> void:
	# Barramento de ferro sobre pés, cabeçote com placa (gira) e a peça presa até o
	# contraponto, porta-ferramenta, polia/porta embaixo à esquerda e cavacos no chão.
	mb.color(IRON)
	for x in [-0.8, 0.8]:
		mb.box(Vector3(x, 0.38, 0), Vector3(0.16, 0.76, 0.5))
	mb.color(IRON.lightened(0.1))
	for z in [-0.12, 0.12]:
		mb.box(Vector3(0, 0.8, z), Vector3(1.9, 0.08, 0.1)) # barramento
	mb.color(STEEL.darkened(0.2))
	mb.box(Vector3(-0.72, 1.0, 0), Vector3(0.36, 0.34, 0.4)) # cabeçote
	mb.box(Vector3(0.55, 0.95, 0), Vector3(0.2, 0.24, 0.24)) # contraponto
	mb.color(STEEL)
	mb.tube(PackedVector3Array([Vector3(0.45, 0.98, 0), Vector3(0.3, 0.98, 0)]), 0.025, 6) # ponta
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.02)]), 8, Basis(Vector3.BACK, -PI / 2), Vector3(0.66, 0.98, 0)) # manípulo
	mb.color(IRON)
	mb.box(Vector3(0.05, 0.88, 0.12), Vector3(0.18, 0.1, 0.18)) # carro
	mb.box(Vector3(0.05, 0.95, 0.1), Vector3(0.05, 0.06, 0.14)) # porta-ferramenta
	mb.color(STEEL.lightened(0.3))
	mb.box(Vector3(0.05, 0.97, 0.03), Vector3(0.02, 0.02, 0.06)) # bit
	# Polia de latão com correia subindo para o cabeçote.
	mb.color(BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.002, -0.05), Vector2(0.15, -0.05), Vector2(0.15, 0.05), Vector2(0.002, 0.05)]), 12, Basis(Vector3.BACK, PI / 2), Vector3(-0.98, 0.6, 0))
	mb.color(Color(0.22, 0.14, 0.08))
	for z in [-0.03, 0.03]:
		mb.tube(PackedVector3Array([Vector3(-0.98, 0.6, 0.15 + z), Vector3(-0.85, 0.98, 0.12 + z)]), 0.012, 4)
	mb.color(Color(0.75, 0.75, 0.72))
	for k in 6:
		mb.box(Vector3(-0.2 + k * 0.09, 0.02, 0.15 + sin(k * 2.0) * 0.08), Vector3(0.05, 0.01, 0.02), Basis(Vector3.UP, k)) # cavacos
	spin.color(IRON.lightened(0.1))
	var around_x := Basis(Vector3.BACK, PI / 2)
	spin.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.13, 0.0), Vector2(0.13, 0.08), Vector2(0.002, 0.08)]), 10, around_x, Vector3(0.15, 0, 0)) # placa
	for k in 3:
		spin.box(Vector3(0.26, 0, 0), Vector3(0.05, 0.05, 0.2), Basis(Vector3.RIGHT, k * TAU / 3.0)) # castanhas
	spin.color(Color(0.6, 0.45, 0.3))
	spin.lathe(PackedVector2Array([Vector2(0.002, -0.75), Vector2(0.04, -0.75), Vector2(0.06, -0.6), Vector2(0.05, -0.45), Vector2(0.06, -0.23), Vector2(0.002, -0.23)]), 8, around_x) # peça sendo torneada (vai até o contraponto)
	obj._shape(Vector3(0, 0.55, 0), Vector3(2.0, 1.1, 0.6))


static func _press(mb: MeshBuilder, spin: MeshBuilder, obj: PlacedObject) -> void:
	# Pórtico de madeira grossa, fuso de ferro com volante (gira), prato, cesto de ripas
	# com fruta, bacia com suco, bica e garrafa; caixa de engrenagens com polia à esquerda.
	mb.color(WOOD.darkened(0.1))
	for x in [-0.5, 0.5]:
		mb.box(Vector3(x, 0.8, 0), Vector3(0.16, 1.6, 0.2))
	mb.box(Vector3(0, 1.5, 0), Vector3(1.2, 0.18, 0.24)) # travessa
	mb.box(Vector3(0, 0.2, 0), Vector3(1.2, 0.12, 0.7)) # base
	mb.color(WOOD)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.26), Vector2(0.34, 0.26), Vector2(0.36, 0.34), Vector2(0.32, 0.34), Vector2(0.3, 0.3), Vector2(0.002, 0.3)]), 12) # bacia
	mb.color(Color(0.75, 0.45, 0.15))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.31), Vector2(0.3, 0.31)]), 12) # suco
	for k in 10:
		var a := TAU * k / 10.0
		mb.color(WOOD.lightened(0.05 * (k % 2)))
		mb.box(Vector3(cos(a) * 0.24, 0.5, sin(a) * 0.24), Vector3(0.05, 0.36, 0.03), Basis(Vector3.UP, -a)) # ripas do cesto
	mb.color(IRON)
	for y in [0.38, 0.62]:
		mb.lathe(PackedVector2Array([Vector2(0.25, y - 0.015), Vector2(0.27, y - 0.015), Vector2(0.27, y + 0.015), Vector2(0.25, y + 0.015)]), 10)
	mb.color(Color(0.75, 0.15, 0.1))
	for k in 6:
		mb.box(Vector3(cos(k) * 0.12, 0.66, sin(k) * 0.12), Vector3(0.1, 0.1, 0.1), Basis(Vector3.UP, k)) # frutas
	mb.color(WOOD.darkened(0.25))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.7), Vector2(0.24, 0.7), Vector2(0.24, 0.78), Vector2(0.002, 0.78)]), 10) # prato
	mb.color(IRON)
	mb.box(Vector3(0, 0.2, 0.42), Vector3(0.08, 0.04, 0.2), Basis(Vector3.RIGHT, 0.3)) # bica
	mb.color(Color(0.55, 0.68, 0.62))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.045, 0.0), Vector2(0.045, 0.17), Vector2(0.02, 0.22), Vector2(0.002, 0.22)]), 8, Basis.IDENTITY, Vector3(0, 0.0, 0.6))
	# Caixa de engrenagens com polia (porta de energia à esquerda).
	mb.color(IRON.lightened(0.05))
	mb.box(Vector3(-0.68, 0.6, 0), Vector3(0.2, 0.36, 0.3))
	mb.color(BRASS) # polia da porta de energia (onde encaixa eixo/esteira)
	mb.lathe(PackedVector2Array([Vector2(0.002, -0.04), Vector2(0.1, -0.04), Vector2(0.1, 0.04), Vector2(0.002, 0.04)]), 10, Basis(Vector3.BACK, PI / 2), Vector3(-0.82, 0.6, 0))
	mb.color(BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.002, -0.04), Vector2(0.12, -0.04), Vector2(0.12, 0.04), Vector2(0.002, 0.04)]), 10, Basis(Vector3.BACK, PI / 2), Vector3(-0.66, 1.2, 0))
	mb.color(STEEL)
	mb.tube(PackedVector3Array([Vector3(-0.68, 0.78, 0), Vector3(-0.66, 1.2, 0), Vector3(-0.05, 1.42, 0)]), 0.02, 4) # transmissão até o fuso
	# Parte que gira (pivô em cima da travessa): fuso, volante de 4 braços.
	spin.color(STEEL.darkened(0.1))
	spin.lathe(PackedVector2Array([Vector2(0.045, -0.8), Vector2(0.045, 0.15)]), 8)
	for k in 8:
		spin.box(Vector3(0, -0.75 + k * 0.1, 0), Vector3(0.11, 0.015, 0.03), Basis(Vector3.UP, k * 0.8)) # rosca
	spin.color(IRON)
	spin.torus(0.26, 0.02, 12, 4, Basis.IDENTITY, Vector3(0, 0.15, 0))
	for k in 4:
		spin.box(Vector3(0, 0.15, 0), Vector3(0.52, 0.025, 0.025), Basis(Vector3.UP, k * PI / 4.0))
	obj._shape(Vector3(0, 0.8, 0), Vector3(1.3, 1.6, 0.8))


# --- Destilaria -----------------------------------------------------------------------------

static func _distillery(mb: MeshBuilder, obj: PlacedObject) -> void:
	# Fornalha de tijolo, alambique de cobre (barriga + capitel), pescoço de cisne até a
	# serpentina dentro da tina d'água (barril) e a bica pingando num jarro.
	for row in 3:
		mb.color(BRICK if row % 2 == 0 else BRICK.darkened(0.08))
		mb.box(Vector3(-0.3, row * 0.17 + 0.085, 0), Vector3(0.8, 0.16, 0.8))
	ObjectModels.mouth(mb, Vector3(-0.3, 0.24, 0.4), 0.28, 0.22)
	mb.color(COPPER)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.5), Vector2(0.3, 0.52), Vector2(0.38, 0.65), Vector2(0.36, 0.85), Vector2(0.2, 0.98),
		Vector2(0.12, 1.02), Vector2(0.12, 1.06)]), 14, Basis.IDENTITY, Vector3(-0.3, 0, 0)) # barriga
	mb.color(COPPER.lightened(0.08))
	mb.lathe(PackedVector2Array([Vector2(0.12, 1.06), Vector2(0.18, 1.12), Vector2(0.2, 1.25), Vector2(0.14, 1.35), Vector2(0.06, 1.4), Vector2(0.002, 1.41)]), 12, Basis.IDENTITY, Vector3(-0.3, 0, 0)) # capitel
	mb.color(COPPER.darkened(0.1))
	mb.tube(PackedVector3Array([Vector3(-0.2, 1.33, 0), Vector3(0.05, 1.38, 0), Vector3(0.3, 1.22, 0), Vector3(0.52, 1.0, 0)]), 0.035, 6) # pescoço de cisne
	# Tina d'água (barril) com a serpentina aparecendo em cima.
	mb.color(WOOD)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.02), Vector2(0.3, 0.02), Vector2(0.34, 0.45), Vector2(0.31, 0.95)]), 12, Basis.IDENTITY, Vector3(0.55, 0, 0))
	mb.color(IRON)
	for y in [0.2, 0.6, 0.88]:
		mb.lathe(PackedVector2Array([Vector2(0.33, y - 0.025), Vector2(0.345, y - 0.025), Vector2(0.345, y + 0.025), Vector2(0.33, y + 0.025)]), 12, Basis.IDENTITY, Vector3(0.55, 0, 0))
	mb.color(WATER)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.9), Vector2(0.3, 0.9)]), 12, Basis.IDENTITY, Vector3(0.55, 0, 0))
	mb.color(COPPER.darkened(0.15))
	var coil := PackedVector3Array()
	for k in 25:
		var a := k * 0.6
		coil.append(Vector3(0.55 + cos(a) * 0.18, 1.0 - k * 0.035, sin(a) * 0.18))
	mb.tube(coil, 0.02, 4)
	mb.tube(PackedVector3Array([Vector3(0.55, 0.15, -0.3), Vector3(0.95, 0.15, -0.3), Vector3(0.98, 0.1, -0.3)]), 0.02, 4) # bica de saída
	mb.color(Color(0.55, 0.42, 0.3))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.08, 0.0), Vector2(0.1, 0.08), Vector2(0.07, 0.14), Vector2(0.03, 0.15), Vector2(0.03, 0.19)]), 8, Basis.IDENTITY, Vector3(0.98, 0, -0.3)) # jarro
	StationModels._fire(obj, Vector3(-0.3, 0.22, 0.34), 0.07, 0.7)
	var drip := _steam_puff(Vector3(-0.3, 1.45, 0), Vector3.UP, 5)
	drip.initial_velocity_min = 0.3
	drip.initial_velocity_max = 0.6
	drip.lifetime = 1.0
	drip.mesh.size = Vector3.ONE * 0.1
	obj.add_child(drip)
	StationModels._register_fire(obj, drip) # vapor saindo quando aceso
	obj._shape(Vector3(0.15, 0.7, 0), Vector3(1.7, 1.4, 0.9))


# --- Efeitos ---------------------------------------------------------------------------------

static func _smoke(at: Vector3, width: float) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.amount = 24
	smoke.lifetime = 3.0
	smoke.position = at
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.3, 0.6, 0)
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.1
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = width
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.4
	var puff := BoxMesh.new()
	puff.size = Vector3.ONE * 0.3
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.3, 0.3, 0.45)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = mat
	smoke.mesh = puff
	smoke.emitting = false
	return smoke


static func _steam_puff(at: Vector3, dir: Vector3, amount: int) -> CPUParticles3D:
	var puff := _smoke(at, 0.05)
	puff.amount = amount
	puff.lifetime = 1.2
	puff.direction = dir
	puff.initial_velocity_min = 1.0
	puff.initial_velocity_max = 2.0
	(puff.mesh.material as StandardMaterial3D).albedo_color = Color(0.92, 0.92, 0.92, 0.55)
	puff.mesh.size = Vector3.ONE * 0.18
	return puff


## Baforadas do motor a vapor ("tchuc") no ritmo do volante, só no visual de cada um.
class SteamChug extends Node:
	var _t := 0.0

	func _process(delta: float) -> void:
		var obj := get_parent() as PlacedObject
		var speed: float = obj.extra.get("speed", 0.0) if obj else 0.0
		if speed <= 0.05:
			return
		_t -= delta * speed
		if _t <= 0.0:
			_t = 0.45
			Sfx.play_at("chug", obj.global_position + Vector3.UP, -4.0, 0.8 + speed * 0.3)
