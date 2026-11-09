class_name Electric
extends RefCounted
## Eletricidade (Tier 4). Peças ligadas por CABOS (item "cabo": clique num borne e
## depois no outro, até 12 m; 1 cabo a cada 4 m). O cabo pendura em catenária
## (entre isoladores de cerâmica fica esticado, rente à parede).
## Medidas: potência em watts (W); carga guardada em watt-hora (Wh), contando as
## horas do jogo (1 h de jogo = duração do dia / 24; padrão 50 s).
##   Geram:    dínamo (600 W, com o eixo girando na porta de latão; pesa 2 no eixo)
##             painel solar (até 300 W ao meio-dia; nublado/chuva rende menos; noite 0)
##   Guardam:  bateria modular de 12 V: até 6 células (cada uma 300 Wh e até 500 W de
##             carga/descarga; 750 W esquentando); banco de baterias de 110 V: 9 células
##             em série (só funciona completo). As células gastam com os ciclos.
##   Convertem: carregador (110 -> 12 V, 400 W) e inversor (12 -> 110 V, 600 W), dois
##             bornes; sobrecarga na saída esquenta e queima
##   Gastam:   lâmpada 50 W · rádio 50 W · cerca elétrica 100 W · geladeira 150 W ·
##             bomba elétrica 200 W · motor elétrico 300 W (só com a máquina trabalhando)
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
const ACID_ITEM := &"acido" ## ácido de bateria: [E] com ele na mão renova as células
const ACID_GAIN := 0.5 ## +50% de saúde por garrafa na bateria de 12 V
const ACID_GAIN_BANK := 0.2 ## no banco de 110 V (9 células)
const DYNAMO_OUT := 600.0 ## W
const DYNAMO_LOAD := 2.0 ## carga no eixo (força) enquanto gera
const SOLAR_OUT := 300.0 ## W ao meio-dia de céu limpo
const CELLS := 6 ## vagas da estrutura da bateria
const CELL_CAP := 300.0 ## Wh por célula
const CELL_RATE := 500.0 ## W de carga/descarga por célula
## Tensão (Fase 3 das eras): fontes de 12 V (painel, bateria, dínamo regulado em 12)
## e de 110 V (dínamo regulado em 110, banco de baterias com as 9 células em série).
## Numa rede com fonte de 110 V ela vira 110 V: painel de 12 V fica bloqueado e
## bateria de 12 V queima o fusível. Quase tudo é bivolt; ONLY_110 só liga em 110 V.
## 12 V perde mais nos cabos (LOSS_12 por metro) que 110 V.
const V12 := 12
const V110 := 110
const BANK_CELLS := 9 ## banco de baterias: 9 células em série dão os 110 V
const ONLY_110 := ["weld_bench"]
const LOSS_12 := 0.004 ## perda por metro de cabo na rede de 12 V (25 m = 10%)
const LOSS_110 := 0.0004
## Carregador (110 -> 12 V, carrega bateria pelo dínamo) e inversor (12 -> 110 V):
## dois bornes (entrada à esquerda, saída à direita), máximo na saída e eficiência.
const CONVERTERS := {"charger": {"in": 110, "out": 12, "max": 400.0, "eff": 0.9},
	"inverter": {"in": 12, "out": 110, "max": 600.0, "eff": 0.85}}
## Baterias: tirar até OVERDRAW vezes o normal (esquenta; demais, uma célula estoura);
## cada ciclo inteiro gasta CYCLE_WEAR da saúde; esvaziar com consumo, DEEP_WEAR por segundo.
const OVERDRAW := 1.5
const CYCLE_WEAR := 0.004
const DEEP_WEAR := 0.003
const MIN_HEALTH := 0.3
## Quem liga primeiro quando falta energia.
const PRIORITY := ["lamp", "lamp_wall", "radio", "fridge", "electric_fence", "electric_pump", "electric_motor", "weld_bench"]
## Consumo em W.
const DEMAND := {"lamp": 50.0, "lamp_wall": 50.0, "radio": 50.0, "electric_fence": 100.0, "fridge": 150.0, "electric_pump": 200.0, "weld_bench": 300.0,
	"electric_motor": 300.0}
const KINDS := ["connector", "connector_wall", "insulator", "switch", "switch_wall", "dynamo", "solar_panel", "battery",
	"lamp", "lamp_wall", "radio", "electric_fence", "fridge", "electric_pump", "electric_motor", "weld_bench", "battery_bank", "charger", "inverter"]
const SWITCHES := ["switch", "switch_wall"]
## Peças com 2 bornes (um cabo em cada): interruptores e conversores.
const TWO_TERMINALS := ["switch", "switch_wall", "charger", "inverter"]
## Peças que vão na parede (o martelo troca sozinho mirando uma parede).
const WALL_VARIANT := {"connector": "connector_wall", "lamp": "lamp_wall", "switch": "switch_wall"}
## Vão em qualquer superfície (chão, parede, teto), viradas para fora dela.
const ANY_SURFACE := ["insulator"]
## Interruptor: os dois bornes (esquerda = entrada, direita = saída), em espaço local.
const SWITCH_TERMINALS := {"switch": [Vector3(-0.09, 1.0, 0.04), Vector3(0.09, 1.0, 0.04)],
	"switch_wall": [Vector3(-0.09, 0.07, 0.05), Vector3(0.09, 0.07, 0.05)],
	"charger": [Vector3(-0.17, 0.62, 0.0), Vector3(0.17, 0.62, 0.0)], "inverter": [Vector3(-0.17, 0.62, 0.0), Vector3(0.17, 0.62, 0.0)]}
## Borne (onde o cabo prende), em espaço local.
const TERMINAL := {
	"connector": Vector3(0, 1.27, 0), "connector_wall": Vector3(0, 0.02, 0.16), "insulator": Vector3(0, 0, 0.06),
	"switch": Vector3(0, 1.0, 0.04), "switch_wall": Vector3(0, 0.07, 0.05),
	"dynamo": Vector3(0.18, 0.86, 0), "solar_panel": Vector3(0, 0.62, -0.1), "battery": Vector3(0.36, 0.86, 0),
	"lamp": Vector3(0, 0.22, -0.16), "lamp_wall": Vector3(0, -0.14, 0.06),
	"radio": Vector3(0.28, 0.62, -0.16), "electric_fence": Vector3(-1.2, 1.36, 0),
	"fridge": Vector3(0, 1.72, -0.2), "electric_pump": Vector3(0, 0.92, 0), "electric_motor": Vector3(0.36, 0.22, 0), "weld_bench": Vector3(-0.66, 1.19, -0.2),
	"battery_bank": Vector3(0.62, 0.86, 0), "charger": Vector3(0, 0.62, 0), "inverter": Vector3(0, 0.62, 0),
}
const NAMES := {"connector": "Conector", "connector_wall": "Conector", "insulator": "Isolador de cerâmica",
	"switch": "Interruptor", "switch_wall": "Interruptor", "dynamo": "Dínamo", "solar_panel": "Painel solar",
	"battery": "Bateria", "lamp": "Lâmpada", "lamp_wall": "Lâmpada", "radio": "Rádio", "electric_fence": "Cerca elétrica",
	"fridge": "Geladeira", "electric_pump": "Bomba elétrica", "electric_motor": "Motor elétrico", "weld_bench": "Bancada de solda",
	"battery_bank": "Banco de baterias", "charger": "Carregador de baterias", "inverter": "Inversor"}

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
	if not obj.kind in TWO_TERMINALS:
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
		if s.kind in TWO_TERMINALS and not linked(a, b) and _links_of(s, other).size() >= 2:
			return false
	return true


static func linked(a: PlacedObject, b: PlacedObject) -> bool:
	return b.net_id in a.extra.get("cables", []) or a.net_id in b.extra.get("cables", [])


## Interruptor fechado (passa energia)? Tudo que não é interruptor passa.
static func closed(obj: PlacedObject) -> bool:
	if CONVERTERS.has(obj.kind):
		return false # conversor separa as duas redes (passa energia pelo tick)
	return not obj.kind in SWITCHES or obj.extra.get("closed", true)


## Está recebendo energia agora? (estado mandado pelo host)
static func powered(obj: PlacedObject) -> bool:
	return obj.extra.get("ep", false)


static func is_battery(kind: String) -> bool:
	return kind == "battery" or kind == "battery_bank"


## Vagas de célula: bateria de 12 V 6, banco de 110 V 9.
static func max_cells(kind: String) -> int:
	return BANK_CELLS if kind == "battery_bank" else CELLS


static func cells(obj: PlacedObject) -> int:
	return clampi(int(obj.extra.get("cells", 0)), 0, max_cells(obj.kind))


## Wh que a bateria aguenta (gasta com a saúde das células).
static func capacity(obj: PlacedObject) -> float:
	return cells(obj) * CELL_CAP * health(obj)


static func health(obj: PlacedObject) -> float:
	return clampf(float(obj.extra.get("health", 1.0)), MIN_HEALTH, 1.0)


## W de carga/descarga normal.
static func rate(obj: PlacedObject) -> float:
	return cells(obj) * CELL_RATE


## Segundos reais de 1 hora do jogo (converte W x segundo em Wh).
static func seconds_per_hour() -> float:
	return maxf(WorldSettings.get_value("day_length") * 60.0 / 24.0, 1.0)


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
## 1) cada rede (grupo ligado por cabo): tensão, fontes, baterias, perda nos cabos;
## 2) carregadores/inversores passam energia de uma rede para a outra;
## 3) cada rede liga o que couber por prioridade e carrega/descarrega as baterias.
static func tick(objects: Dictionary, _clock: float) -> Dictionary:
	if dirty:
		build(objects)
	var changed := {}
	var sph := seconds_per_hour()
	var nets: Array = []
	var net_of := {}
	for group in _groups:
		for id in group:
			net_of[id] = nets.size()
		nets.append(_survey(objects, group))
	for net in nets:
		for conv in net.converters:
			_convert(objects, conv, nets, net_of, sph, changed)
	for net in nets:
		_serve(objects, net, sph, changed)
	return changed


static func _note(changed: Dictionary, obj: PlacedObject, update: Dictionary) -> void:
	if update.is_empty():
		return
	obj.extra.merge(update, true)
	if changed.has(obj.net_id):
		changed[obj.net_id].merge(update, true)
	else:
		changed[obj.net_id] = update


## Rede: membros, tensão das fontes (110 V ganha), geração e perda nos cabos.
static func _survey(objects: Dictionary, group: Array) -> Dictionary:
	var net := {"members": [], "converters": [], "volts": 0, "supply": 0.0, "solar": 0.0, "batteries": [],
		"extra_supply": 0.0, "extra_demand": 0.0, "cable": 0.0}
	var high := false
	var low := false
	for id in group:
		var obj: PlacedObject = objects.get(id)
		if obj == null or not is_instance_valid(obj):
			continue
		if CONVERTERS.has(obj.kind):
			net.converters.append(obj)
			continue
		net.members.append(obj)
		var v := source_volts(obj)
		high = high or v == V110
		low = low or v == V12
		if is_battery(obj.kind):
			net.batteries.append(obj)
		for other_id in obj.extra.get("cables", []):
			var other: PlacedObject = objects.get(other_id)
			if other and is_instance_valid(other) and other_id in group:
				net.cable += terminal(obj).distance_to(terminal(other))
	net.volts = V110 if high else (V12 if low else 0)
	return net


## Tensão que a peça impõe na rede agora (0 = não é fonte / parada).
static func source_volts(obj: PlacedObject) -> int:
	match obj.kind:
		"dynamo":
			return int(obj.extra.get("v", V12)) if output(obj) > 0.0 else 0
		"solar_panel":
			return V12 if output(obj) > 0.0 else 0
		"battery":
			return V12 if cells(obj) > 0 and not obj.extra.get("fuse", false) else 0
		"battery_bank":
			return V110 if cells(obj) >= BANK_CELLS and not obj.extra.get("fuse", false) else 0
	return 0


## Tensão de trabalho da bateria (0 = banco incompleto: sem as 9 células em série).
static func battery_volts(obj: PlacedObject) -> int:
	if obj.kind == "battery_bank":
		return V110 if cells(obj) >= BANK_CELLS else 0
	return V12 if cells(obj) > 0 else 0


## Perda nos cabos da rede (fração): 12 V perde bem mais que 110 V.
static func cable_loss(net: Dictionary) -> float:
	return clampf(net.cable * (LOSS_12 if net.volts == V12 else LOSS_110), 0.0, 0.4)


## Consumo dos aparelhos que querem energia e aceitam a tensão da rede.
static func _demand(objects: Dictionary, net: Dictionary, volts: int) -> float:
	var total := 0.0
	for obj in net.members:
		if wants(objects, obj) and volts_ok(obj.kind, volts):
			total += DEMAND[obj.kind]
	return total


static func volts_ok(kind: String, volts: int) -> bool:
	return volts > 0 and (not kind in ONLY_110 or volts == V110)


## Quanto as baterias da rede conseguem soltar agora (W), na tensão dela.
static func _battery_can(net: Dictionary, volts: int, sph: float) -> float:
	var can := 0.0
	for bat in net.batteries:
		if battery_volts(bat) == volts and not bat.extra.get("fuse", false):
			can += minf(bat.extra.get("charge", 0.0) * sph, rate(bat) * OVERDRAW)
	return can


## Geração aproveitável da rede (fontes na tensão dela, menos a perda nos cabos).
static func _supply(net: Dictionary) -> float:
	var total := 0.0
	var solar := 0.0
	for obj in net.members:
		var v := source_volts(obj)
		if v == 0 or v != net.volts or is_battery(obj.kind):
			continue # painel de 12 V numa rede de 110 V: o diodo bloqueia
		total += output(obj)
		if obj.kind == "solar_panel":
			solar += output(obj)
	var keep := 1.0 - cable_loss(net)
	net.solar = solar * keep
	return total * keep


## Carregador (110 V -> 12 V) / inversor (12 V -> 110 V): pega a sobra da rede da
## entrada e entrega na da saída (com perda). Consumo maior que o máximo na saída
## esquenta; esquentou demais, queima (troca a bobina com [E]).
static func _convert(objects: Dictionary, conv: PlacedObject, nets: Array, net_of: Dictionary, sph: float, changed: Dictionary) -> void:
	var spec: Dictionary = CONVERTERS[conv.kind]
	var update := {}
	var sides := converter_sides(conv)
	var status := ""
	var load := 0.0
	var heat: float = conv.extra.get("heat", 0.0)
	if conv.extra.get("burnt", false):
		status = "burnt"
	elif sides[0] < 0 or sides[1] < 0 or not net_of.has(sides[0]) or not net_of.has(sides[1]):
		status = "loose"
	else:
		var in_net: Dictionary = nets[net_of[sides[0]]]
		var out_net: Dictionary = nets[net_of[sides[1]]]
		if in_net.volts != spec["in"]:
			status = "no_input"
		elif out_net.volts != 0 and out_net.volts != spec["out"]:
			status = "clash"
		else:
			out_net.volts = spec["out"] # a saída define a tensão do outro lado
			in_net.supply = _supply(in_net)
			out_net.supply = _supply(out_net)
			var need: float = _demand(objects, out_net, out_net.volts) - out_net.supply - out_net.extra_supply - _battery_can(out_net, out_net.volts, sph)
			var room := 0.0
			for bat in out_net.batteries:
				if battery_volts(bat) == out_net.volts and not bat.extra.get("fuse", false):
					room += minf(rate(bat), maxf(capacity(bat) - bat.extra.get("charge", 0.0), 0.0) * sph)
			var avail := maxf(in_net.supply + in_net.extra_supply + _battery_can(in_net, in_net.volts, sph)
				- _demand(objects, in_net, in_net.volts) - in_net.extra_demand, 0.0)
			var give := minf(minf(maxf(need, 0.0) + room, spec["max"]), avail * spec["eff"])
			in_net.extra_demand += give / spec["eff"]
			out_net.extra_supply += give
			load = give / spec["max"]
			status = "ok"
			if need > spec["max"]:
				heat += (need / spec["max"] - 1.0) * 0.15 + 0.02 # sobrecarga: pedem mais do que ele aguenta
			else:
				heat -= 0.03
	heat = clampf(heat, 0.0, 1.0)
	if heat >= 1.0 and not conv.extra.get("burnt", false):
		update.burnt = true
		update.pop = Time.get_ticks_msec() # faísca e estalo (refresh)
		status = "burnt"
	if not is_equal_approx(conv.extra.get("heat", 0.0), snappedf(heat, 0.05)):
		update.heat = snappedf(heat, 0.05)
	if conv.extra.get("status", "") != status:
		update.status = status
	if not is_equal_approx(conv.extra.get("gauge", -1.0), snappedf(load, 0.05)):
		update.gauge = snappedf(load, 0.05)
	_note(changed, conv, update)


## Lados do conversor: [id ligado na entrada, id ligado na saída] (-1 = solto).
static func converter_sides(conv: PlacedObject) -> Array:
	var sides := [-1, -1]
	var manager := conv.get_parent() as PlacedManager
	if manager == null:
		return sides
	var pair: Array = SWITCH_TERMINALS[conv.kind]
	var input: Vector3 = conv.global_transform * pair[0]
	for id in _links_of(conv, null):
		var other: PlacedObject = manager.objects.get(id)
		if other == null:
			continue
		var at := end_point(conv, other)
		sides[0 if at.distance_to(input) < 0.01 else 1] = id
	return sides


## Liga por prioridade o que couber; sobra carrega as baterias, falta descarrega.
## Bateria de 12 V numa rede de 110 V queima o fusível. Tirar mais que o normal da
## bateria esquenta; esquentou demais, uma célula estoura. Cada ciclo gasta a saúde.
static func _serve(objects: Dictionary, net: Dictionary, sph: float, changed: Dictionary) -> void:
	var volts: int = net.volts
	var batteries: Array[PlacedObject] = []
	for bat in net.batteries:
		var bv := battery_volts(bat)
		if bv == 0 or bat.extra.get("fuse", false):
			continue
		if volts == V110 and bv == V12:
			_note(changed, bat, {"fuse": true, "pop": Time.get_ticks_msec()}) # 12 V na rede de 110 V
			continue
		if bv == volts:
			batteries.append(bat)
	var supply: float = _supply(net) + net.extra_supply
	var wanting: Array[PlacedObject] = []
	for obj in net.members:
		if wants(objects, obj):
			wanting.append(obj)
	var can := 0.0
	for bat in batteries:
		can += minf(bat.extra.get("charge", 0.0) * sph, rate(bat) * OVERDRAW)
	wanting.sort_custom(func(a, b): return PRIORITY.find(a.kind) < PRIORITY.find(b.kind))
	var left := supply + can
	var served := {}
	var used := 0.0
	var demand := 0.0
	var low := {}
	for obj in wanting:
		if not volts_ok(obj.kind, volts):
			low[obj.net_id] = volts > 0 # aparelho de 110 V numa rede de 12 V
			continue
		var need: float = DEMAND[obj.kind]
		demand += need
		if need <= left + 0.001:
			served[obj.net_id] = true
			left -= need
			used += need
	used += net.extra_demand # o que o carregador/inversor leva para a outra rede
	var charged := 0.0
	var draws := {}
	if supply + 0.001 >= used:
		var surplus := supply - used
		for bat in batteries:
			var put := minf(minf(surplus, rate(bat)), (capacity(bat) - bat.extra.get("charge", 0.0)) * sph)
			if put > 0.0:
				bat.extra.charge = bat.extra.get("charge", 0.0) + put / sph
				surplus -= put
				charged += put
	else:
		var short := used - supply
		for bat in batteries:
			var give := minf(minf(bat.extra.get("charge", 0.0) * sph, rate(bat) * OVERDRAW), short)
			bat.extra.charge = maxf(bat.extra.get("charge", 0.0) - give / sph, 0.0)
			short -= give
			draws[bat.net_id] = give
			# Desgaste: um ciclo inteiro tira CYCLE_WEAR da saúde; esvaziar com consumo, mais.
			var health: float = bat.extra.get("health", 1.0) - give / sph / maxf(cells(bat) * CELL_CAP, 1.0) * CYCLE_WEAR
			bat.extra.health = maxf(health, MIN_HEALTH)
	var starving: bool = demand > used - net.extra_demand + 0.5 # tem aparelho pedindo e não deu
	for bat in batteries:
		var update := {}
		if starving and bat.extra.get("charge", 0.0) <= 0.01:
			bat.extra.health = maxf(float(bat.extra.get("health", 1.0)) - DEEP_WEAR, MIN_HEALTH) # descarga funda
			update.health = bat.extra.health
		var heat: float = bat.extra.get("heat", 0.0)
		var draw: float = draws.get(bat.net_id, 0.0)
		if draw > rate(bat) + 0.5:
			heat += (draw / rate(bat) - 1.0) * 0.6 # tirando mais que o normal: esquenta
		else:
			heat -= 0.04
		heat = clampf(heat, 0.0, 1.0)
		if heat >= 1.0:
			update.cells = cells(bat) - 1 # uma célula estufou e estourou
			update.pop = Time.get_ticks_msec()
			heat = 0.4
		if not is_equal_approx(bat.extra.get("heat", 0.0), snappedf(heat, 0.05)):
			update.heat = snappedf(heat, 0.05)
		var c := snappedf(bat.extra.get("charge", 0.0), 1.0)
		if not is_equal_approx(bat.get_meta("charge_sent", -1.0), c):
			bat.set_meta("charge_sent", c)
			update.charge = bat.extra.get("charge", 0.0)
			update.health = bat.extra.get("health", 1.0) # exato: o desgaste por segundo é pequeno
		_note(changed, bat, update)
	# Ponteiro do dínamo: quanto da geração está indo embora (consumo + carregar bateria).
	var gauge := 0.0 if supply <= 0.1 else clampf((minf(used, supply) + charged) / supply, 0.0, 1.0)
	# Dínamo só pesa no eixo quando a rede precisa (consumo ou bateria para encher).
	var wants_dynamo: bool = demand + net.extra_demand > net.solar + 0.01 or batteries.any(func(b): return b.extra.get("charge", 0.0) < capacity(b) - 0.5)
	for obj in net.members:
		var update := {}
		if is_consumer(obj.kind):
			var ep := served.has(obj.net_id)
			if obj.extra.get("ep", false) != ep:
				update.ep = ep
			var lowv: bool = low.get(obj.net_id, false)
			if obj.extra.get("lowv", false) != lowv:
				update.lowv = lowv
		if obj.kind == "dynamo":
			var g := snappedf(gauge if output(obj) > 0.0 and source_volts(obj) == volts else 0.0, 0.05)
			if not is_equal_approx(obj.extra.get("gauge", -1.0), g):
				update.gauge = g
			if obj.extra.get("draw", false) != wants_dynamo:
				obj.extra.draw = wants_dynamo
				update.draw = wants_dynamo
		_note(changed, obj, update)


# --- Painel (sem números de consumo: ficam na descrição do martelo) ---------------------

static func text(obj: PlacedObject) -> String:
	var title: String = NAMES.get(obj.kind, "Elétrico")
	match obj.kind:
		"switch", "switch_wall":
			var on := closed(obj)
			return "%s: %s  [E] %s" % [title, "ligado" if on else "desligado", "desligar" if on else "ligar"]
		"battery", "battery_bank":
			var n := cells(obj)
			var most := max_cells(obj.kind)
			var volts := "110 V em série: precisa das 9" if obj.kind == "battery_bank" else "12 V"
			var line := "%s (%s): %d de %d células · saúde %d%%" % [title, volts, n, most, int(health(obj) * 100.0)]
			if obj.extra.get("fuse", false):
				return line + " · FUSÍVEL QUEIMADO (bateria de 12 V numa rede de 110 V: use o carregador)  [E] trocar fusível"
			if obj.extra.get("heat", 0.0) > 0.45:
				line += " · ESQUENTANDO: consumo demais!"
			if n > 0 and health(obj) < 0.9:
				line += " · ácido na mão + [E]: renova"
			return line + ("  [E] pôr célula" if n < most else "")
		"dynamo":
			var v := int(obj.extra.get("v", V12))
			return "%s: regulado em %d V  [E] mudar para %d V" % [title, v, V110 if v == V12 else V12]
		"charger", "inverter":
			var spec: Dictionary = CONVERTERS[obj.kind]
			var line := "%s: %d V -> %d V (entrada à esquerda, saída à direita)" % [title, spec["in"], spec["out"]]
			match obj.extra.get("status", ""):
				"burnt":
					return line + " · QUEIMOU de sobrecarga  [E] trocar a bobina"
				"no_input":
					return line + " · sem %d V na entrada" % spec["in"]
				"clash":
					return line + " · a saída está numa rede de outra tensão"
				"loose":
					return line + " · ligue um cabo em cada borne"
			if obj.extra.get("heat", 0.0) > 0.4:
				line += " · ESQUENTANDO: consumo demais na saída!"
			return line
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
	if obj.extra.get("lowv", false):
		return "%s: precisa de 110 V (esta rede é de 12 V: use um inversor ou o banco)" % title
	return title


## [E]: interruptor liga/desliga; bateria recebe célula (ou troca o fusível); dínamo muda
## a tensão; conversor queimado troca a bobina; geladeira abre; rádio entrega/repete.
static func interact(player: Node, obj: PlacedObject) -> void:
	var manager := obj.get_parent() as PlacedManager
	if manager == null:
		return
	match obj.kind:
		"switch", "switch_wall":
			manager.request("extra", [obj.net_id, {"closed": not closed(obj)}])
			Sfx.play_at("click", obj.global_position, 4.0, 0.7 if closed(obj) else 1.0)
		"battery", "battery_bank":
			if obj.extra.get("fuse", false):
				manager.request("extra", [obj.net_id, {"fuse": false}]) # fusível novo
				Sfx.play_at("click", obj.global_position, 2.0, 1.2)
				return
			if player.inventory.selected_id() == ACID_ITEM:
				_refill_acid(player, obj)
				return
			var index := Cooking.find_any(player.inventory, {CELL_ITEM: true})
			if index < 0 or cells(obj) >= max_cells(obj.kind):
				Sfx.play("click", -6.0, 0.6)
				return
			player.inventory.take(index, 1)
			manager.request("battery_cell", [obj.net_id])
			Sfx.play_at("knock", obj.global_position + Vector3.UP * 0.5, -2.0, 1.4)
		"dynamo":
			var v := V110 if int(obj.extra.get("v", V12)) == V12 else V12
			manager.request("extra", [obj.net_id, {"v": v}])
			Sfx.play_at("click", obj.global_position, 3.0, 0.8 if v == V110 else 1.1)
		"charger", "inverter":
			if not obj.extra.get("burnt", false):
				Sfx.play("click", -6.0, 0.6)
				return
			var coil := Cooking.find_any(player.inventory, {&"bobina": true})
			if coil < 0:
				player.notify.emit("Precisa de uma bobina de cobre para consertar")
				Sfx.play("click", -6.0, 0.6)
				return
			player.inventory.take(coil, 1)
			manager.request("extra", [obj.net_id, {"burnt": false, "heat": 0.0, "status": ""}])
			Sfx.play_at("knock", obj.global_position + Vector3.UP * 0.5, -2.0, 1.2)
		"fridge":
			StorageUI.open_for(player, "placed_%d" % obj.net_id)
		"radio":
			Radio.interact(player, obj)
		_:
			Sfx.play("click", -6.0, 0.6)


## Ácido de bateria na mão + [E] na bateria: troca o eletrólito (a saúde das células sobe;
## o banco de 110 V tem mais células, então cada garrafa rende menos). A garrafa volta.
static func _refill_acid(player: Node, obj: PlacedObject) -> void:
	var manager := obj.get_parent() as PlacedManager
	if cells(obj) <= 0 or health(obj) >= 0.999:
		player.notify.emit("Bateria sem células" if cells(obj) <= 0 else "As células já estão novas")
		Sfx.play("click", -6.0, 0.6)
		return
	var gain := ACID_GAIN_BANK if obj.kind == "battery_bank" else ACID_GAIN
	var after := minf(health(obj) + gain, 1.0)
	player.inventory.take(player.inventory.selected, 1)
	player.pick_up(&"garrafa", ItemDB.display_name(&"garrafa"), 1)
	manager.request("extra", [obj.net_id, {"health": after}])
	player.notify.emit("Eletrólito novo: saúde das células %d%%" % int(after * 100.0))
	Progress.event("acid", "battery")
	Sfx.play_at("splash", obj.global_position + Vector3.UP * 0.5, -6.0, 1.6)


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
