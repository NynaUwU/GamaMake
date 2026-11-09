class_name Electric
extends RefCounted
## Eletricidade (Tier 4). Peças ligadas por CABOS (item "cabo": clique num borne e
## depois no outro, até 12 m; 1 cabo a cada 4 m). O cabo pendura em catenária
## (entre isoladores de cerâmica fica esticado, rente à parede).
##   Geram:    dínamo (6, com o eixo girando na porta de latão; pesa 2 no eixo)
##             painel solar (até 3 ao meio-dia; nublado/chuva rende menos; noite 0)
##   Guardam:  bateria modular: a estrutura recebe até 6 células (cada uma 150 e
##             5 por segundo de carga/descarga)
##   Gastam:   lâmpada 0,5 · rádio 0,5 · cerca elétrica 1 · geladeira 1,5 ·
##             bomba elétrica 2 · motor elétrico 3 (só com a máquina trabalhando)
##   Passam:   conector (poste ou parede), isolador de cerâmica (organiza os cabos)
##   Cortam:   interruptor (no chão ou na parede) com 2 bornes, entrada e saída: cada
##             lado recebe um cabo; desligado, a energia não passa de um lado para o outro
## O host recalcula 1x por segundo por rede ligada: sobra carrega as baterias; falta
## descarrega; se nem assim dá, liga o que couber por prioridade (luz, rádio,
## geladeira, cerca, bomba, motor). Nada mostra consumo ao olhar: só o ponteiro do
## dínamo (quanto da geração está sendo usado, contando carregar bateria) e o da
## bateria (carga). Os números ficam na descrição do martelo.

const CABLE_RANGE := 12.0
const CABLE_PER_ITEM := 4.0
const CABLE_ITEM := &"cabo"
const CELL_ITEM := &"celula"
const DYNAMO_OUT := 6.0
const DYNAMO_LOAD := 2.0 ## carga no eixo enquanto gera
const SOLAR_OUT := 3.0
const CELLS := 6 ## vagas da estrutura da bateria
const CELL_CAP := 150.0
const CELL_RATE := 5.0
const MOTOR_OUT := 4.0 ## força que o motor dá no eixo da máquina
## Quem liga primeiro quando falta energia.
const PRIORITY := ["lamp", "lamp_wall", "radio", "fridge", "electric_fence", "electric_pump", "electric_motor"]
const DEMAND := {"lamp": 0.5, "lamp_wall": 0.5, "radio": 0.5, "electric_fence": 1.0, "fridge": 1.5, "electric_pump": 2.0,
	"electric_motor": 3.0}
const KINDS := ["connector", "connector_wall", "insulator", "switch", "switch_wall", "dynamo", "solar_panel", "battery",
	"lamp", "lamp_wall", "radio", "electric_fence", "fridge", "electric_pump", "electric_motor"]
const SWITCHES := ["switch", "switch_wall"]
## Peças que vão na parede (o martelo troca sozinho mirando uma parede).
const WALL_VARIANT := {"connector": "connector_wall", "lamp": "lamp_wall", "switch": "switch_wall"}
## Vão em qualquer superfície (chão, parede, teto), viradas para fora dela.
const ANY_SURFACE := ["insulator"]
## Interruptor: os dois bornes (esquerda = entrada, direita = saída), em espaço local.
const SWITCH_TERMINALS := {"switch": [Vector3(-0.09, 1.0, 0.04), Vector3(0.09, 1.0, 0.04)],
	"switch_wall": [Vector3(-0.09, 0.07, 0.05), Vector3(0.09, 0.07, 0.05)]}
## Borne (onde o cabo prende), em espaço local.
const TERMINAL := {
	"connector": Vector3(0, 1.27, 0), "connector_wall": Vector3(0, 0.02, 0.16), "insulator": Vector3(0, 0, 0.06),
	"switch": Vector3(0, 1.0, 0.04), "switch_wall": Vector3(0, 0.07, 0.05),
	"dynamo": Vector3(0.18, 0.86, 0), "solar_panel": Vector3(0, 0.62, -0.1), "battery": Vector3(0.36, 0.86, 0),
	"lamp": Vector3(0, 0.22, -0.16), "lamp_wall": Vector3(0, -0.14, 0.06),
	"radio": Vector3(0.28, 0.62, -0.16), "electric_fence": Vector3(-1.2, 1.36, 0),
	"fridge": Vector3(0, 1.72, -0.2), "electric_pump": Vector3(0, 0.92, 0), "electric_motor": Vector3(0.36, 0.22, 0),
}
const NAMES := {"connector": "Conector", "connector_wall": "Conector", "insulator": "Isolador de cerâmica",
	"switch": "Interruptor", "switch_wall": "Interruptor", "dynamo": "Dínamo", "solar_panel": "Painel solar",
	"battery": "Bateria", "lamp": "Lâmpada", "lamp_wall": "Lâmpada", "radio": "Rádio", "electric_fence": "Cerca elétrica",
	"fridge": "Geladeira", "electric_pump": "Bomba elétrica", "electric_motor": "Motor elétrico"}

static var dirty := true
static var _groups: Array = [] # [[net_id, ...], ...]


static func has(kind: String) -> bool:
	return kind in KINDS


static func is_consumer(kind: String) -> bool:
	return DEMAND.has(kind)


static func terminal(obj: PlacedObject) -> Vector3:
	return obj.global_transform * TERMINAL.get(obj.kind, Vector3.UP * 0.5)


## Ponta do cabo que vai de "obj" até "other". No interruptor: o borne do lado que
## sobrou (o primeiro cabo pega o mais perto; o segundo, o outro).
static func end_point(obj: PlacedObject, other: PlacedObject) -> Vector3:
	if not obj.kind in SWITCHES:
		return terminal(obj)
	var pair: Array = SWITCH_TERMINALS[obj.kind]
	var ends := [obj.global_transform * pair[0], obj.global_transform * pair[1]]
	var links := _links_of(obj, other)
	var side := 0 if other.global_position.distance_to(ends[0]) <= other.global_position.distance_to(ends[1]) else 1
	var manager := obj.get_parent() as PlacedManager
	if links.size() >= 2 and manager and links.has(other.net_id):
		# Os dois bornes ocupados: cada cabo no lado que não cruza.
		var o0: PlacedObject = manager.objects.get(links[0])
		var o1: PlacedObject = manager.objects.get(links[1])
		if o0 and o1:
			var straight := o0.global_position.distance_to(ends[0]) + o1.global_position.distance_to(ends[1])
			var crossed := o0.global_position.distance_to(ends[1]) + o1.global_position.distance_to(ends[0])
			var first := 0 if straight <= crossed else 1
			side = first if other.net_id == links[0] else 1 - first
	elif links.size() == 1 and links[0] != other.net_id:
		side = 1 - _side_of(obj, links[0]) # o outro borne está livre
	return ends[side]


## Lados já usados no interruptor: ids ligados a ele, em ordem (o 1º fica no borne mais perto dele).
static func _links_of(obj: PlacedObject, _other: PlacedObject) -> Array:
	var manager := obj.get_parent() as PlacedManager
	var list: Array = obj.extra.get("cables", []).duplicate()
	if manager:
		for value in manager.objects.values():
			if is_instance_valid(value) and value != obj and obj.net_id in value.extra.get("cables", []) and not value.net_id in list:
				list.append(value.net_id)
	return list


static func _side_of(obj: PlacedObject, other_id: int) -> int:
	var manager := obj.get_parent() as PlacedManager
	var other: PlacedObject = manager.objects.get(other_id) if manager else null
	if other == null:
		return 0
	var pair: Array = SWITCH_TERMINALS[obj.kind]
	var a: Vector3 = obj.global_transform * pair[0]
	var b: Vector3 = obj.global_transform * pair[1]
	return 0 if other.global_position.distance_to(a) <= other.global_position.distance_to(b) else 1


static func cable_cost(length: float) -> int:
	return maxi(1, ceili(length / CABLE_PER_ITEM - 0.01))


## Dá para ligar um cabo entre as duas? (perto o bastante, peças elétricas diferentes)
## Interruptor só tem 2 bornes (entrada e saída): no máximo 2 cabos.
static func cable_ok(a: PlacedObject, b: PlacedObject) -> bool:
	if a == b or not has(a.kind) or not has(b.kind) or terminal(a).distance_to(terminal(b)) > CABLE_RANGE:
		return false
	for s in [a, b]:
		var other: PlacedObject = b if s == a else a
		if s.kind in SWITCHES and not linked(a, b) and _links_of(s, other).size() >= 2:
			return false
	return true


static func linked(a: PlacedObject, b: PlacedObject) -> bool:
	return b.net_id in a.extra.get("cables", []) or a.net_id in b.extra.get("cables", [])


## Interruptor fechado (passa energia)? Tudo que não é interruptor passa.
static func closed(obj: PlacedObject) -> bool:
	return not obj.kind in SWITCHES or obj.extra.get("closed", true)


## Está recebendo energia agora? (estado mandado pelo host)
static func powered(obj: PlacedObject) -> bool:
	return obj.extra.get("ep", false)


static func cells(obj: PlacedObject) -> int:
	return clampi(int(obj.extra.get("cells", 0)), 0, CELLS)


static func capacity(obj: PlacedObject) -> float:
	return cells(obj) * CELL_CAP


# --- Rede ---------------------------------------------------------------------------

## Grupos ligados por cabo. Interruptor desligado não liga nada (corta a rede ali).
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
			if not closed(obj) or not closed(other):
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


## Quer energia agora? O motor só quando a máquina dele (rede de eixo) tem trabalho.
static func wants(objects: Dictionary, obj: PlacedObject) -> bool:
	if not is_consumer(obj.kind):
		return false
	if obj.kind == "electric_motor":
		for id in Power.group_of(obj.net_id):
			var other: PlacedObject = objects.get(id)
			if other != null and other != obj and is_instance_valid(other) and Power.busy(other):
				return true
		return false
	return true


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
		var batteries: Array[PlacedObject] = []
		var wanting: Array[PlacedObject] = []
		for obj in members:
			var out := output(obj)
			supply += out
			if obj.kind == "solar_panel":
				solar += out
			if obj.kind == "battery" and cells(obj) > 0:
				batteries.append(obj)
			if wants(objects, obj):
				wanting.append(obj)
		# Liga quem couber no que tem (geração + baterias), por prioridade.
		var can := 0.0
		for bat in batteries:
			can += minf(bat.extra.get("charge", 0.0), cells(bat) * CELL_RATE)
		wanting.sort_custom(func(a, b): return PRIORITY.find(a.kind) < PRIORITY.find(b.kind))
		var left := supply + can
		var served := {}
		var used := 0.0
		var demand := 0.0
		for obj in wanting:
			var need: float = DEMAND[obj.kind]
			demand += need
			if need <= left + 0.001:
				served[obj.net_id] = true
				left -= need
				used += need
		var charged := 0.0
		if supply + 0.001 >= used:
			# Sobra: carrega as baterias.
			var surplus := supply - used
			for bat in batteries:
				var put := minf(minf(surplus, cells(bat) * CELL_RATE), capacity(bat) - bat.extra.get("charge", 0.0))
				if put > 0.0:
					bat.extra.charge = bat.extra.get("charge", 0.0) + put
					surplus -= put
					charged += put
		else:
			# Falta: as baterias completam.
			var short := used - supply
			for bat in batteries:
				var give := minf(minf(bat.extra.get("charge", 0.0), cells(bat) * CELL_RATE), short)
				bat.extra.charge = bat.extra.get("charge", 0.0) - give
				short -= give
		# Ponteiro do dínamo: quanto da geração está indo embora (consumo + carregar bateria).
		var gauge := 0.0 if supply <= 0.001 else clampf((minf(used, supply) + charged) / supply, 0.0, 1.0)
		# Dínamo só pesa no eixo quando a rede precisa (consumo ou bateria para encher).
		var wants_dynamo := demand > solar + 0.01 or batteries.any(func(b): return b.extra.get("charge", 0.0) < capacity(b) - 0.5)
		for obj in members:
			var update := {}
			if is_consumer(obj.kind):
				var ep := served.has(obj.net_id)
				if obj.extra.get("ep", false) != ep:
					update.ep = ep
			match obj.kind:
				"battery":
					var c := snappedf(obj.extra.get("charge", 0.0), 1.0)
					if not is_equal_approx(obj.get_meta("charge_sent", -1.0), c):
						obj.set_meta("charge_sent", c)
						update.charge = obj.extra.get("charge", 0.0)
				"dynamo":
					var g := snappedf(gauge if output(obj) > 0.0 else 0.0, 0.05)
					if not is_equal_approx(obj.extra.get("gauge", -1.0), g):
						update.gauge = g
					if obj.extra.get("draw", false) != wants_dynamo:
						obj.extra.draw = wants_dynamo
						update.draw = wants_dynamo
			if not update.is_empty():
				obj.extra.merge(update, true)
				changed[obj.net_id] = update
	# Peças fora de qualquer rede ligada (ex.: atrás de um interruptor desligado sozinhas)
	# já caem num grupo de 1 e apagam acima.
	return changed


# --- Painel (sem números de consumo: ficam na descrição do martelo) ---------------------

static func text(obj: PlacedObject) -> String:
	var title: String = NAMES.get(obj.kind, "Elétrico")
	match obj.kind:
		"switch", "switch_wall":
			var on := closed(obj)
			return "%s: %s  [E] %s" % [title, "ligado" if on else "desligado", "desligar" if on else "ligar"]
		"battery":
			var n := cells(obj)
			return "%s: %d de %d células  [E] pôr célula" % [title, n, CELLS] if n < CELLS else "%s: %d de %d células" % [title, n, CELLS]
		"fridge":
			return "[E] " + title
		"radio":
			var parts: Array[String] = []
			var msg: String = obj.extra.get("msg", "")
			if msg != "":
				parts.append(msg)
			var mission: Dictionary = obj.extra.get("mission", {})
			if not mission.is_empty():
				parts.append("pedido: " + Radio.mission_text(mission))
			var key := "  [E] " + ("entregar pedido" if not mission.is_empty() else "ouvir")
			return title + (": " + " · ".join(parts) if not parts.is_empty() else "") + key
	return title


## [E]: interruptor liga/desliga; bateria recebe célula; geladeira abre; rádio entrega/repete.
static func interact(player: Node, obj: PlacedObject) -> void:
	var manager := obj.get_parent() as PlacedManager
	if manager == null:
		return
	match obj.kind:
		"switch", "switch_wall":
			manager.request("extra", [obj.net_id, {"closed": not closed(obj)}])
			Sfx.play_at("click", obj.global_position, 4.0, 0.7 if closed(obj) else 1.0)
		"battery":
			var index := Cooking.find_any(player.inventory, {CELL_ITEM: true})
			if index < 0 or cells(obj) >= CELLS:
				Sfx.play("click", -6.0, 0.6)
				return
			player.inventory.take(index, 1)
			manager.request("battery_cell", [obj.net_id])
			Sfx.play_at("knock", obj.global_position + Vector3.UP * 0.5, -2.0, 1.4)
		"fridge":
			StorageUI.open_for(player, "placed_%d" % obj.net_id)
		"radio":
			Radio.interact(player, obj)
		_:
			Sfx.play("click", -6.0, 0.6)


# --- Cabos (desenho) ------------------------------------------------------------------

## Malha de todos os cabos: tubo fino em catenária (barriga proporcional ao comprimento;
## esticado quando uma das pontas é isolador de cerâmica).
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
			mb.tube(catenary(end_point(obj, other), end_point(other, obj), taut(obj) or taut(other)), 0.014, 5)
	return mb.finish(PlacedObject._mat(), false)


static func taut(obj: PlacedObject) -> bool:
	return obj.kind == "insulator"


## 12 pontos de A até B pendurados (y = a·cosh(x/a), aproximado por uma parábola).
static func catenary(a: Vector3, b: Vector3, tight := false) -> PackedVector3Array:
	var points := PackedVector3Array()
	var length := a.distance_to(b)
	var sag := (0.004 + length * 0.008) if tight else (0.04 + length * 0.055)
	for k in 13:
		var t := k / 12.0
		var p := a.lerp(b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		points.append(p)
	return points
