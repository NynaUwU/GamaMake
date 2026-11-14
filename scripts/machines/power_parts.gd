class_name PowerParts
extends RefCounted
## Peças da força rotacional (Power) e o indicador das máquinas.
##   axle       eixo de madeira com cintas de ferro e luvas de latão nas pontas; gira
##   tripod     tripé de três pernas até o chão com mancal de ferro em cima
##   cog        engrenagem de madeira (dentes em bloco, cubo de ferro); gira. Só para
##              virar a força em 90° (eixos paralelos se ligam por polia + esteira)
##   pulley     polia (tambor com abas) onde a esteira passa; gira
## Indicador ("PowerLamp") em toda máquina/gerador, em cima da porta de latão:
##   verde = com força e trabalhando · âmbar = com força, parada (sem material)
##   vermelho piscando = sobrecarga · apagado = sem força
## Item na mão:
##   eixo        arrastar (AxleTool)
##   engrenagem_madeira / polia: clique num eixo, tripé ou porta
##   correia     clique numa polia e depois noutra polia ou máquina (esteira)

const WOOD := Color(0.5, 0.35, 0.2)
const WOOD_DARK := Color(0.34, 0.23, 0.13)
const IRON := Color(0.26, 0.25, 0.25)
const BRASS := Color(0.68, 0.54, 0.26)
const AROUND_Z := Basis(Vector3(1, 0, 0), PI / 2) # torno ao longo de +Z
const ITEMS := {"cog": &"engrenagem_madeira", "pulley": &"polia"}
const AXLE_ITEM := &"eixo"
const AXLE_PER_ITEM := 2.0 ## metros de eixo por item
const MAX_AXLE := 8.0
const LAMP_COLORS := {"work": Color(0.3, 1.0, 0.35), "idle": Color(1.0, 0.7, 0.2), "over": Color(1.0, 0.15, 0.1), "none": Color(0.12, 0.12, 0.12)}


static func has(kind: String) -> bool:
	return kind in Power.PARTS


static func axle_cost(length: float) -> int:
	return maxi(1, ceili(length / AXLE_PER_ITEM - 0.01))


static func mount_kind(item: StringName) -> String:
	for kind in ITEMS:
		if ITEMS[kind] == item:
			return kind
	return ""


# --- Modelos ----------------------------------------------------------------------------

## Monta (ou refaz, se o tamanho mudou) o modelo da peça.
static func build(obj: PlacedObject) -> void:
	for name in ["PartMesh", "Spin", "PartShape"]:
		var old := obj.get_node_or_null(name)
		if old:
			obj.remove_child(old)
			old.queue_free()
	var mb := MeshBuilder.new()
	var spin := MeshBuilder.new()
	var shape_size := Vector3(0.3, 0.3, 0.3)
	var shape_center := Vector3.ZERO
	match obj.kind:
		"axle":
			var length: float = obj.extra.get("len", 1.0)
			spin.color(WOOD)
			spin.lathe(PackedVector2Array([Vector2(0.05, 0.0), Vector2(0.05, length)]), 8, AROUND_Z)
			spin.color(IRON)
			var bands := maxi(1, int(length / 0.5))
			for k in bands:
				var z := (k + 0.5) * length / bands
				spin.lathe(PackedVector2Array([Vector2(0.056, z - 0.02), Vector2(0.056, z + 0.02)]), 8, AROUND_Z)
			spin.color(WOOD_DARK)
			for k in 4:
				var a := TAU * k / 4.0
				spin.box(Vector3(cos(a) * 0.048, sin(a) * 0.048, length * 0.5), Vector3(0.012, 0.012, length * 0.96)) # veio (dá para ver girando)
			spin.color(BRASS)
			for z in [0.04, length - 0.04]:
				spin.lathe(PackedVector2Array([Vector2(0.002, z - 0.04), Vector2(0.075, z - 0.04), Vector2(0.075, z + 0.04), Vector2(0.002, z + 0.04)]), 10, AROUND_Z) # luva
				for k in 4:
					var a := TAU * k / 4.0 + PI / 4.0
					spin.box(Vector3(cos(a) * 0.075, sin(a) * 0.075, z), Vector3(0.018, 0.018, 0.06)) # parafusos
			shape_size = Vector3(0.14, 0.14, length)
			shape_center = Vector3(0, 0, length * 0.5)
		"tripod":
			var h: float = obj.extra.get("h", 0.6)
			tripod_legs(mb, h)
			mb.color(IRON)
			mb.box(Vector3(0, -0.04, 0), Vector3(0.2, 0.12, 0.2)) # mancal
			mb.box(Vector3(0, 0.05, 0), Vector3(0.16, 0.06, 0.16)) # tampa
			mb.color(IRON.lightened(0.25))
			for x in [-0.06, 0.06]:
				for z in [-0.06, 0.06]:
					mb.box(Vector3(x, 0.085, z), Vector3(0.025, 0.012, 0.025)) # parafusos
			mb.color(BRASS)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.08), Vector2(0.02, 0.08), Vector2(0.025, 0.13), Vector2(0.002, 0.14)]), 6) # copo de graxa
			shape_size = Vector3(0.22, 0.2, 0.22)
		"cog":
			var r: float = Power.COG_RADIUS[obj.kind]
			var teeth := 12
			var t := 0.09
			spin.color(WOOD)
			spin.lathe(PackedVector2Array([Vector2(0.002, -t * 0.5), Vector2(r - 0.05, -t * 0.5), Vector2(r - 0.05, t * 0.5), Vector2(0.002, t * 0.5)]), teeth, AROUND_Z)
			for k in teeth:
				var a := TAU * k / teeth
				spin.color(WOOD.lightened(0.06 * (k % 2)))
				spin.box(Vector3(cos(a) * (r - 0.02), sin(a) * (r - 0.02), 0), Vector3(0.07, 0.08 * r / 0.3, t), Basis(Vector3.BACK, a)) # dente
			spin.color(IRON)
			spin.lathe(PackedVector2Array([Vector2(0.002, -t * 0.7), Vector2(0.09, -t * 0.7), Vector2(0.09, t * 0.7), Vector2(0.002, t * 0.7)]), 8, AROUND_Z) # cubo
			spin.color(IRON.lightened(0.3))
			for k in 4:
				var a := TAU * k / 4.0
				spin.box(Vector3(cos(a) * 0.06, sin(a) * 0.06, t * 0.72), Vector3(0.02, 0.02, 0.01))
			shape_size = Vector3(r * 2.0, r * 2.0, t + 0.04)
		"pulley":
			var r := Power.PULLEY_RADIUS
			spin.color(WOOD)
			spin.lathe(PackedVector2Array([Vector2(0.002, -0.07), Vector2(r + 0.03, -0.07), Vector2(r + 0.03, -0.05), Vector2(r, -0.045),
				Vector2(r, 0.045), Vector2(r + 0.03, 0.05), Vector2(r + 0.03, 0.07), Vector2(0.002, 0.07)]), 14, AROUND_Z)
			spin.color(IRON)
			spin.lathe(PackedVector2Array([Vector2(0.002, -0.09), Vector2(0.07, -0.09), Vector2(0.07, 0.09), Vector2(0.002, 0.09)]), 8, AROUND_Z) # cubo
			spin.color(WOOD_DARK)
			for k in 4:
				var a := TAU * k / 4.0
				spin.box(Vector3(cos(a), sin(a), 0) * r * 0.55, Vector3(0.04, r * 0.7, 0.03), Basis(Vector3.BACK, a - PI / 2)) # raios
			shape_size = Vector3(r * 2.0 + 0.06, r * 2.0 + 0.06, 0.16)
	if obj.kind == "tripod":
		var mesh := MeshInstance3D.new()
		mesh.name = "PartMesh"
		mesh.mesh = mb.finish(PlacedObject._mat(), false)
		obj.add_child(mesh)
	if obj.kind != "tripod":
		var node := MeshInstance3D.new()
		node.name = "Spin"
		node.mesh = spin.finish(PlacedObject._mat(), false)
		obj.add_child(node)
		if obj.get_node_or_null("PowerSpin") == null:
			var spinner := PowerSpin.new()
			spinner.name = "PowerSpin"
			spinner.axis = Vector3.BACK
			obj.add_child(spinner)
	var shape := CollisionShape3D.new()
	shape.name = "PartShape"
	var box := BoxShape3D.new()
	box.size = shape_size
	shape.shape = box
	shape.position = shape_center
	obj.add_child(shape)
	obj.set_meta("part_built", [obj.extra.get("len", 0.0), obj.extra.get("h", 0.0)])


## Três pernas de madeira (com travessas se for alto) do topo (0, -0,08) até o chão a "h"
## metros. Usado no tripé do eixo e no do cano (SteamModels).
static func tripod_legs(mb: MeshBuilder, h: float) -> void:
	for k in 3:
		var a := TAU * k / 3.0 + PI / 6.0
		var foot := Vector3(cos(a) * (0.22 + h * 0.25), -h, sin(a) * (0.22 + h * 0.25))
		mb.color(WOOD_DARK.lightened(0.04 * k))
		mb.tube(PackedVector3Array([Vector3(cos(a) * 0.05, -0.08, sin(a) * 0.05), foot]), 0.03, 5)
		mb.color(IRON)
		mb.box(foot + Vector3(0, 0.02, 0), Vector3(0.08, 0.04, 0.08)) # sapata
	if h > 0.45:
		mb.color(WOOD_DARK.darkened(0.1))
		var y := -h * 0.55
		for k in 3:
			var a0 := TAU * k / 3.0 + PI / 6.0
			var a1 := TAU * (k + 1) / 3.0 + PI / 6.0
			var r := 0.05 + (0.22 + h * 0.25 - 0.05) * 0.55
			mb.tube(PackedVector3Array([Vector3(cos(a0) * r, y, sin(a0) * r), Vector3(cos(a1) * r, y, sin(a1) * r)]), 0.018, 4) # travessa


## Refaz o modelo se o tamanho mudou (eixo/tripé chegam do host depois do spawn).
static func refresh(obj: PlacedObject) -> void:
	if obj.get_meta("part_built", []) != [obj.extra.get("len", 0.0), obj.extra.get("h", 0.0)]:
		build(obj)


static func text(obj: PlacedObject) -> String:
	var spinning: bool = obj.extra.get("speed", 0.0) > 0.0
	var state: String = {"ok": "girando", "over": "SOBRECARGA!", "none": "parado"}.get(obj.extra.get("pstate", "none"), "parado")
	match obj.kind:
		"axle":
			return "Eixo %.1f m · %s" % [obj.extra.get("len", 1.0), state if not spinning else "girando"]
		"tripod":
			return "Tripé · %s" % ("girando" if spinning else state)
		"cog":
			return "Engrenagem · %s" % state
		"pulley":
			var belts: int = obj.extra.get("belts", []).size()
			return "Polia · %s · %d esteira%s (clique com esteira na mão: liga a outra polia/máquina)" % [state, belts, "" if belts == 1 else "s"]
	return ""


# --- Indicador nas máquinas -----------------------------------------------------------------

## Lâmpada em cima da porta de latão (uma por máquina/gerador).
static func add_lamp(obj: PlacedObject) -> void:
	var ports: Array = Power.PORTS.get(obj.kind, [])
	if ports.is_empty() or obj.get_node_or_null("PowerLamp"):
		return
	var at: Vector3 = ports[0][0] + Vector3.UP * 0.2 - ports[0][1] * 0.08
	var mb := MeshBuilder.new()
	mb.color(BRASS.darkened(0.2))
	mb.box(Vector3(0, -0.09, 0), Vector3(0.02, 0.16, 0.02)) # haste
	mb.box(Vector3(0, -0.005, 0), Vector3(0.07, 0.02, 0.07)) # base
	mb.color(IRON)
	for x in [-0.03, 0.03]:
		mb.box(Vector3(x, 0.045, 0), Vector3(0.008, 0.08, 0.008)) # grade
	var holder := MeshInstance3D.new()
	holder.name = "PowerLampBase"
	holder.mesh = mb.finish(PlacedObject._mat(), false)
	holder.position = at
	obj.add_child(holder)
	var bulb := MeshInstance3D.new()
	bulb.name = "PowerLamp"
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	sphere.radial_segments = 8
	sphere.rings = 4
	bulb.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = LAMP_COLORS.none
	mat.emission_enabled = true
	mat.emission = Color.BLACK
	bulb.material_override = mat
	bulb.position = at + Vector3.UP * 0.045
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	obj.add_child(bulb)


## Estado do indicador: work / idle / over / none.
static func lamp_state(obj: PlacedObject) -> String:
	match obj.extra.get("pstate", "none"):
		"over":
			return "over"
		"ok":
			if Power.OUTPUT.has(obj.kind):
				return "work" if obj.extra.get("load", [0.0, 0.0])[0] > 0.0 else "idle"
			return "work" if Power.busy(obj) or obj.kind in Power.STATIONS else "idle"
	return "none"


static func refresh_lamp(obj: PlacedObject) -> void:
	var bulb := obj.get_node_or_null("PowerLamp") as MeshInstance3D
	if bulb == null:
		return
	var state := lamp_state(obj)
	var mat := bulb.material_override as StandardMaterial3D
	var c: Color = LAMP_COLORS[state]
	if state == "over" and int(Time.get_ticks_msec() / 500) % 2 == 0:
		c = LAMP_COLORS.none # pisca
	mat.albedo_color = c
	mat.emission = c if c != LAMP_COLORS.none else Color.BLACK
	mat.emission_energy_multiplier = 2.0
