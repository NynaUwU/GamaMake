class_name Electric
extends RefCounted
## Eletricidade (Tier 4). Peças ligadas por CABOS (item "cabo": clique num borne e
## depois no outro, até 12 m; 1 cabo a cada 4 m). O cabo pendura em catenária.
##   Geram:    dínamo (6, com o eixo girando na porta de latão; pede carga 2 do eixo)
##             painel solar (até 3 ao meio-dia; nublado/chuva rende menos; noite 0)
##   Guardam:  bateria (600; carrega/descarrega até 5 por segundo)
##   Gastam:   lâmpada 0,5 · rádio 0,5 · cerca elétrica 1 · geladeira 1,5 · bomba elétrica 2
##   Passam:   conector (poste ou na parede) só emenda cabos
## O host recalcula 1x por segundo por rede ligada: sobra carrega as baterias; falta
## descarrega; se nem assim dá, a rede liga o que couber por prioridade (luz, rádio,
## geladeira, cerca, bomba) e o resto fica sem energia.
## [E] liga/desliga lâmpada, rádio, cerca, bomba e geladeira (o "interruptor").

const CABLE_RANGE := 12.0
const CABLE_PER_ITEM := 4.0
const CABLE_ITEM := &"cabo"
const DYNAMO_OUT := 6.0
const DYNAMO_LOAD := 2.0 ## carga no eixo enquanto gera
const SOLAR_OUT := 3.0
const BATTERY_CAP := 600.0
const BATTERY_RATE := 15.0
## Quem liga primeiro quando falta energia.
const PRIORITY := ["lamp", "lamp_wall", "radio", "fridge", "electric_fence", "electric_pump"]
const DEMAND := {"lamp": 0.5, "lamp_wall": 0.5, "radio": 0.5, "electric_fence": 1.0, "fridge": 1.5, "electric_pump": 2.0}
const KINDS := ["connector", "connector_wall", "dynamo", "solar_panel", "battery",
	"lamp", "lamp_wall", "radio", "electric_fence", "fridge", "electric_pump"]
## Peças que vão na parede (o martelo troca sozinho mirando uma parede).
const WALL_VARIANT := {"connector": "connector_wall", "lamp": "lamp_wall"}
## Borne (onde o cabo prende), em espaço local.
const TERMINAL := {
	"connector": Vector3(0, 1.27, 0), "connector_wall": Vector3(0, 0.02, 0.16),
	"dynamo": Vector3(0.18, 0.86, 0), "solar_panel": Vector3(0, 0.62, -0.1), "battery": Vector3(0.36, 0.78, 0),
	"lamp": Vector3(0, 0.22, -0.16), "lamp_wall": Vector3(0, -0.14, 0.06),
	"radio": Vector3(0.28, 0.62, -0.16), "electric_fence": Vector3(-1.2, 1.36, 0),
	"fridge": Vector3(0, 1.72, -0.2), "electric_pump": Vector3(0, 0.92, 0),
}
const NAMES := {"connector": "Conector", "connector_wall": "Conector", "dynamo": "Dínamo", "solar_panel": "Painel solar",
	"battery": "Bateria", "lamp": "Lâmpada", "lamp_wall": "Lâmpada", "radio": "Rádio", "electric_fence": "Cerca elétrica",
	"fridge": "Geladeira", "electric_pump": "Bomba elétrica"}

static var dirty := true
static var _groups: Array = [] # [[net_id, ...], ...]


static func has(kind: String) -> bool:
	return kind in KINDS


static func is_consumer(kind: String) -> bool:
	return DEMAND.has(kind)


static func terminal(obj: PlacedObject) -> Vector3:
	return obj.global_transform * TERMINAL.get(obj.kind, Vector3.UP * 0.5)


static func cable_cost(length: float) -> int:
	return maxi(1, ceili(length / CABLE_PER_ITEM - 0.01))


## Dá para ligar um cabo entre as duas? (perto o bastante, peças elétricas diferentes)
static func cable_ok(a: PlacedObject, b: PlacedObject) -> bool:
	return a != b and has(a.kind) and has(b.kind) and terminal(a).distance_to(terminal(b)) <= CABLE_RANGE


static func linked(a: PlacedObject, b: PlacedObject) -> bool:
	return b.net_id in a.extra.get("cables", []) or a.net_id in b.extra.get("cables", [])


## Ligado (interruptor). Tudo começa ligado.
static func switched_on(obj: PlacedObject) -> bool:
	return obj.extra.get("on", true)


## Está recebendo energia agora? (estado mandado pelo host)
static func powered(obj: PlacedObject) -> bool:
	return obj.extra.get("ep", false)


# --- Rede ---------------------------------------------------------------------------

static func build(objects: Dictionary) -> void:
	dirty = false
	_groups.clear()
	var links := {} # id -> [ids]
	for value in objects.values():
		if not is_instance_valid(value) or not has(value.kind):
			continue
		var obj: PlacedObject = value
		if not links.has(obj.net_id):
			links[obj.net_id] = []
		for other_id in obj.extra.get("cables", []):
			var other: PlacedObject = objects.get(other_id)
			if other == null or not is_instance_valid(other) or not has(other.kind):
				continue
			links[obj.net_id].append(other_id)
			if not links.has(other_id):
				links[other_id] = []
			links[other_id].append(obj.net_id)
	var seen := {}
	for start in links:
		if seen.has(start):
			continue
		var group := [start]
		seen[start] = true
		var k := 0
		while k < group.size():
			for n in links[group[k]]:
				if not seen.has(n):
					seen[n] = true
					group.append(n)
			k += 1
		_groups.append(group)


static func group_of(net_id: int) -> Array:
	for g in _groups:
		if net_id in g:
			return g
	return []


## Quanto gera agora.
static func output(obj: PlacedObject) -> float:
	match obj.kind:
		"dynamo":
			return DYNAMO_OUT if obj.extra.get("pstate", "") == "ok" and obj.extra.get("speed", 0.0) > 0.5 else 0.0
		"solar_panel":
			var sun: float = DayNight.i.sun_factor if DayNight.i else 1.0
			var rain: float = Weather.i.rain if Weather.i else 0.0
			return SOLAR_OUT * clampf(sun, 0.0, 1.0) * (1.0 - 0.6 * rain)
	return 0.0


## Host, 1x por segundo. Devolve {net_id: extra mudado} para mandar a todos.
static func tick(objects: Dictionary, _clock: float) -> Dictionary:
	if dirty:
		build(objects)
	var changed := {}
	for group in _groups:
		var members: Array[PlacedObject] = []
		for id in group:
			var obj: PlacedObject = objects.get(id)
			if obj != null and is_instance_valid(obj):
				members.append(obj)
		var supply := 0.0
		var solar := 0.0
		var demand := 0.0
		var batteries: Array[PlacedObject] = []
		for obj in members:
			var out := output(obj)
			supply += out
			if obj.kind == "solar_panel":
				solar += out
			if obj.kind == "battery":
				batteries.append(obj)
			if is_consumer(obj.kind) and switched_on(obj):
				demand += DEMAND[obj.kind]
		# Quem pede, em ordem de prioridade; liga quem couber no que tem (geração + baterias).
		var can := 0.0
		for bat in batteries:
			can += minf(bat.extra.get("charge", 0.0), BATTERY_RATE)
		var wanting: Array[PlacedObject] = []
		for obj in members:
			if is_consumer(obj.kind) and switched_on(obj):
				wanting.append(obj)
		wanting.sort_custom(func(a, b): return PRIORITY.find(a.kind) < PRIORITY.find(b.kind))
		var left := supply + can
		var served := {}
		var used := 0.0
		for obj in wanting:
			var need: float = DEMAND[obj.kind]
			if need <= left + 0.001:
				served[obj.net_id] = true
				left -= need
				used += need
		var on := served.size() == wanting.size()
		if supply + 0.001 >= used:
			# Sobra: carrega as baterias.
			var surplus := supply - used
			for bat in batteries:
				var put := minf(minf(surplus, BATTERY_RATE), BATTERY_CAP - bat.extra.get("charge", 0.0))
				if put > 0.0:
					bat.extra.charge = bat.extra.get("charge", 0.0) + put
					surplus -= put
		else:
			# Falta: as baterias completam.
			var short := used - supply
			for bat in batteries:
				var give := minf(minf(bat.extra.get("charge", 0.0), BATTERY_RATE), short)
				bat.extra.charge = bat.extra.get("charge", 0.0) - give
				short -= give
		var stored := 0.0
		for bat in batteries:
			stored += bat.extra.get("charge", 0.0)
		var state := "ok" if on else "low"
		if served.is_empty() and demand > 0.0 and supply <= 0.001 and stored <= 0.5:
			state = "none"
		# Dínamo só pesa no eixo quando a rede precisa (consumo ou bateria para encher).
		var wants_dynamo := demand > solar + 0.01 or batteries.any(func(b): return b.extra.get("charge", 0.0) < BATTERY_CAP - 0.5)
		var load := [snappedf(demand, 0.1), snappedf(supply, 0.1), snappedf(stored, 1.0), batteries.size() * int(BATTERY_CAP)]
		for obj in members:
			var update := {}
			if obj.extra.get("estate", "") != state:
				update.estate = state
			if obj.extra.get("eload", []) != load:
				update.eload = load
			if is_consumer(obj.kind):
				var ep := served.has(obj.net_id)
				if obj.extra.get("ep", false) != ep:
					update.ep = ep
			if obj.kind == "battery":
				var c := snappedf(obj.extra.get("charge", 0.0), 1.0)
				if not is_equal_approx(obj.get_meta("charge_sent", -1.0), c):
					obj.set_meta("charge_sent", c)
					update.charge = obj.extra.get("charge", 0.0)
			if obj.kind == "dynamo" and obj.extra.get("draw", false) != wants_dynamo:
				obj.extra.draw = wants_dynamo
				update.draw = wants_dynamo
			if not update.is_empty():
				obj.extra.merge(update, true)
				changed[obj.net_id] = update
	return changed


# --- Painel e interruptor -------------------------------------------------------------

static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v).replace(".", ",")


## Linha de estado da rede ("rede: consumo 2 de 6 · baterias 300 de 600").
static func net_line(obj: PlacedObject) -> String:
	var load: Array = obj.extra.get("eload", [0.0, 0.0, 0.0, 0])
	if obj.extra.get("cables", []).is_empty() and group_of(obj.net_id).size() <= 1 and load[1] <= 0.0 and obj.kind != "solar_panel" and obj.kind != "dynamo":
		return "sem cabo (ligue com o item cabo)"
	var line := "rede: consumo %s de %s" % [_num(load[0]), _num(load[1])]
	if int(load[3]) > 0:
		line += " · baterias %d de %d" % [int(load[2]), int(load[3])]
	match obj.extra.get("estate", "ok"):
		"low":
			line += " · falta energia para tudo!"
		"none":
			line += " · sem energia!"
	return line


static func text(obj: PlacedObject) -> String:
	var title: String = NAMES.get(obj.kind, "Elétrico")
	var parts: Array[String] = []
	match obj.kind:
		"dynamo":
			var out := output(obj)
			parts.append("gera %s" % _num(out) if out > 0.0 else "parado: ligue um eixo com força na porta de latão")
			parts.append(Power.status(obj))
		"solar_panel":
			parts.append("gera %s de %s" % [_num(output(obj)), _num(SOLAR_OUT)])
		"battery":
			parts.append("carga %d de %d" % [int(obj.extra.get("charge", 0.0)), int(BATTERY_CAP)])
		"radio":
			var msg: String = obj.extra.get("msg", "")
			if msg != "":
				parts.append(msg)
			var mission: Dictionary = obj.extra.get("mission", {})
			if not mission.is_empty():
				parts.append("pedido: " + Radio.mission_text(mission))
	parts.append(net_line(obj))
	var keys := ""
	if is_consumer(obj.kind):
		var state := "ligada" if obj.kind in ["lamp", "lamp_wall", "fridge", "electric_fence", "electric_pump"] else "ligado"
		if not switched_on(obj):
			state = state.replace("ligad", "desligad")
		parts.insert(0, state + ("" if powered(obj) or not switched_on(obj) else " (sem energia)"))
		keys = "  [E] " + ("desligar" if switched_on(obj) else "ligar")
		if obj.kind == "fridge":
			keys = "  [E] abrir  [Shift+E] " + ("desligar" if switched_on(obj) else "ligar")
		elif obj.kind == "radio":
			keys = "  [E] " + ("entregar pedido" if not obj.extra.get("mission", {}).is_empty() else "ouvir") + "  [Shift+E] " + ("desligar" if switched_on(obj) else "ligar")
	return "%s: %s%s" % [title, " · ".join(parts), keys]


## [E] (clique): interruptor; geladeira abre; rádio entrega o pedido / repete a mensagem.
## Shift+E na geladeira e no rádio: interruptor.
static func interact(player: Node, obj: PlacedObject) -> void:
	var manager := obj.get_parent() as PlacedManager
	if manager == null:
		return
	if obj.kind in ["fridge", "radio"] and Input.is_key_pressed(KEY_SHIFT):
		toggle(obj)
		return
	match obj.kind:
		"fridge":
			StorageUI.open_for(player, "placed_%d" % obj.net_id)
			return
		"radio":
			Radio.interact(player, obj)
			return
	if is_consumer(obj.kind):
		toggle(obj)
	else:
		Sfx.play("click", -6.0, 0.6)


static func toggle(obj: PlacedObject) -> void:
	var manager := obj.get_parent() as PlacedManager
	manager.request("extra", [obj.net_id, {"on": not switched_on(obj)}])
	Sfx.play_at("click", obj.global_position + Vector3.UP * 0.5, 2.0, 0.9)


# --- Cabos (desenho) ------------------------------------------------------------------

## Malha de todos os cabos: tubo fino em catenária (barriga proporcional ao comprimento).
static func cable_mesh(objects: Dictionary) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var done := {}
	for value in objects.values():
		if not is_instance_valid(value) or not has(value.kind):
			continue
		var obj: PlacedObject = value
		for other_id in obj.extra.get("cables", []):
			var other: PlacedObject = objects.get(other_id)
			if other == null or not is_instance_valid(other):
				continue
			var key := "%d_%d" % [mini(obj.net_id, other_id), maxi(obj.net_id, other_id)]
			if done.has(key):
				continue
			done[key] = true
			mb.color(Color(0.12, 0.1, 0.09))
			mb.tube(catenary(terminal(obj), terminal(other)), 0.014, 5)
	return mb.finish(PlacedObject._mat(), false)


## 12 pontos de A até B pendurados (y = a·cosh(x/a), aproximado por uma parábola).
static func catenary(a: Vector3, b: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	var length := a.distance_to(b)
	var sag := 0.04 + length * 0.055
	for k in 13:
		var t := k / 12.0
		var p := a.lerp(b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		points.append(p)
	return points
