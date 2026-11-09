class_name PlacedManager
extends Node3D
## Nó "Placed" da cena principal: potes, canteiros, covas e bancadas.
## Mesma ideia do BuildingManager: online o host valida e repassa a todos;
## quem entra depois recebe tudo (net_sync_to). Salvo pelo SaveGame (grupo
## "persist"). "clock" é o relógio das plantas (segundos de jogo).

var objects := {} ## net_id -> PlacedObject
var clock := 0.0
var _next_id := 1
var _refresh := 0.0


func _ready() -> void:
	add_to_group("persist")


## Relógio das plantas: anda junto com o relógio, mas a 20% de noite (Farming.growth_rate).
static var grow_clock := 0.0


func _process(delta: float) -> void:
	clock += delta
	grow_clock += delta * Farming.growth_rate()
	_refresh -= delta
	if _belts_dirty:
		_rebuild_belts()
	if _cables_dirty:
		_rebuild_cables()
	if _refresh <= 0.0:
		_refresh = 1.0
		_collect_rain()
		_fertilize_beds()
		_smelt()
		_fluids()
		_power()
		_electric()
		_expire_airdrops()
		_spoil_tick -= 1.0
		if _spoil_tick <= 0.0:
			_spoil_tick = SPOIL_EVERY
			_spoil_containers()
		for obj: PlacedObject in objects.values():
			obj.refresh(clock)


## Hora absoluta do jogo (dia*24 + hora) em que o próximo 8h da manhã chega.
static func airdrop_expiry() -> float:
	if DayNight.i == null:
		return INF
	var now: float = DayNight.i.day * 24.0 + DayNight.i.hour
	var eight: float = floorf((now - 8.0) / 24.0 + 1.0) * 24.0 + 8.0
	return eight


## Host: às 8h o airdrop some, com o que tiver dentro.
func _expire_airdrops() -> void:
	if not Net.i.is_host() or DayNight.i == null:
		return
	var now: float = DayNight.i.day * 24.0 + DayNight.i.hour
	for obj: PlacedObject in objects.values():
		if obj.kind == "airdrop" and now >= obj.extra.get("expire", INF):
			if ContainerManager.i:
				ContainerManager.i.contents.erase("placed_%d" % obj.net_id)
			_remove(obj.net_id)
			request("vanish", [obj.net_id]) # some para todos


## Host, 1x por segundo: canos levam água e vapor (Fluids), depois da caldeira ferver.
func _fluids() -> void:
	if not Net.i.is_host():
		return
	var changed := Fluids.tick(objects, clock)
	for id in changed:
		request("extra", [id, changed[id]])


## Host, 1x por segundo: a rede elétrica (Electric) divide a energia; o rádio transmite.
func _electric() -> void:
	if not Net.i.is_host():
		return
	var changed := Electric.tick(objects, clock)
	for id in changed:
		request("extra", [id, changed[id]])
	Radio.host_tick(self)


# --- Comida estragando nos baús e na geladeira -------------------------------------

const SPOIL_EVERY := 10.0
## Quanto mais devagar que na mochila: baú/cesto/cocho na metade; geladeira ligada quase parada.
const SPOIL_RATE := {"chest": 0.5, "bed": 0.5, "trough": 0.5, "airdrop": 0.5, "fridge": 0.5}
const FRIDGE_RATE := 0.08
var _spoil_tick := SPOIL_EVERY


## Host: comida guardada também estraga (mais devagar). Manda para todos só quando
## algo apodrece ou de minuto em minuto (o frescor anda devagar).
func _spoil_containers() -> void:
	if not Net.i.is_host() or ContainerManager.i == null:
		return
	var minute := int(clock / 60.0) != int((clock - SPOIL_EVERY) / 60.0)
	for obj: PlacedObject in objects.values():
		if not SPOIL_RATE.has(obj.kind):
			continue
		var rate: float = SPOIL_RATE[obj.kind]
		if obj.kind == "fridge" and Electric.powered(obj):
			rate = FRIDGE_RATE
		var key := "placed_%d" % obj.net_id
		var slots: Array = ContainerManager.i.contents.get(key, [])
		if slots.is_empty():
			continue
		var result := ItemDB.spoil_slots(slots, SPOIL_EVERY * rate)
		if result.rotted or (result.any and minute):
			ContainerManager.i.changed.emit(key)
			if Net.i.online():
				Net.i._system.rpc("Containers", "sync", [key, slots])


## Host, 1x por segundo: a rede de energia (Power) divide a força e avança as máquinas.
func _power() -> void:
	if not Net.i.is_host():
		return
	var changed := Power.tick(objects, clock)
	for id in changed:
		request("extra", [id, changed[id]])


# --- Correias, rio e irrigação -----------------------------------------------------

const IRRIGATION_RADIUS := 10.0
const IRRIGATION_BOOST := 1.5
var _belts_dirty := true
var _belt_node: MeshInstance3D


func _rebuild_belts() -> void:
	_belts_dirty = false
	if _belt_node == null:
		_belt_node = MeshInstance3D.new()
		_belt_node.name = "Belts"
		add_child(_belt_node)
	_belt_node.mesh = Power.belt_mesh(objects)


var _cables_dirty := true
var _cable_node: MeshInstance3D


func _rebuild_cables() -> void:
	_cables_dirty = false
	if _cable_node == null:
		_cable_node = MeshInstance3D.new()
		_cable_node.name = "Cables"
		_cable_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_cable_node)
	_cable_node.mesh = Electric.cable_mesh(objects)


## Altura do ponto até o chão logo abaixo (pernas do tripé).
func _ground_below(p: Vector3) -> float:
	var world := get_parent() as Node3D
	var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.05, p + Vector3.DOWN * 6.0, 1))
	if hit:
		return clampf(p.y - hit.position.y, 0.15, 6.0)
	var terrain := world.get_node_or_null("Terrain") as TerrainWorld
	return clampf(p.y - terrain.height_at(p.x, p.z), 0.15, 6.0) if terrain else 0.6


## Na margem de um rio (para a roda d'água e o carneiro).
func river_bank(at: Vector3) -> bool:
	var terrain := get_parent().get_node_or_null("Terrain") as TerrainWorld
	if terrain == null:
		return false
	var near := terrain.river_near(at.x, at.z)
	return not near.is_empty() and near.dist < near.half + 3.0


## Perto de um carneiro hidráulico ou de um aspersor com água (irrigado: planta cresce mais rápido).
func irrigated(at: Vector3) -> bool:
	for obj: PlacedObject in objects.values():
		if obj.kind == "ram_pump" and obj.global_position.distance_to(at) < IRRIGATION_RADIUS:
			return true
		if obj.kind == "sprinkler" and obj.extra.get("wet", false) and obj.global_position.distance_to(at) < Fluids.SPRINKLER_RADIUS:
			return true
	return false


## Host, 1x por segundo: as fornalhas fundem sozinhas e avisam todos do que mudou.
func _smelt() -> void:
	if not Net.i.is_host() or ContainerManager.i == null:
		return
	for obj: PlacedObject in objects.values():
		if obj.kind in Smelting.KINDS and Smelting.host_tick(obj, clock):
			var key := Smelting.key_of(obj)
			ContainerManager.i.changed.emit(key)
			Net.i.system_request("Containers", "sync", [key])
			request("extra", [obj.net_id, Smelting.sync_extra(obj)])
			if obj.extra.get("boom", false):
				request("boom", [obj.net_id]) # caldeira seca e quente: explode


## Host, 1x por segundo: adubo guardado no cesto do canteiro aduba a terra sozinho
## (1 adubo = 3 colheitas em dobro; só pega outro quando acabar o efeito).
func _fertilize_beds() -> void:
	if not Net.i.is_host() or ContainerManager.i == null:
		return
	for obj: PlacedObject in objects.values():
		if not obj.has_basket() or obj.extra.get("fert", 0) > 0:
			continue
		var key := obj.basket_key()
		var slots: Array = ContainerManager.i.contents.get(key, [])
		for k in slots.size():
			if not slots[k].is_empty() and slots[k].id == &"adubo":
				slots[k].amount -= 1
				if slots[k].amount <= 0:
					slots[k] = {}
				ContainerManager.i.changed.emit(key)
				if Net.i.online():
					Net.i._system.rpc("Containers", "sync", [key, slots])
				request("extra", [obj.net_id, {"fert": 3}])
				Sfx.play_at("step_soft", obj.slot_world(PlacedObject.BASKET_SLOT), 0.0, 0.8)
				break


## Host, 1x por segundo: chovendo, os coletores enchem (chuva forte: ~1 garrafa a cada 25 s).
## Manda o nível para os outros só quando muda uma garrafa inteira.
var _rain_sent := {}
func _collect_rain() -> void:
	if not Net.i.is_host() or Weather.i == null or Weather.i.rain < 0.05:
		return
	for obj: PlacedObject in objects.values():
		if obj.kind == "water_trough":
			# Bebedouro descoberto também junta chuva (devagar).
			var w: float = minf(obj.extra.get("water", 0.0) + Weather.i.rain * 0.02, Ranch.WATER_CAP)
			obj.extra.water = w
			if int(w) != _rain_sent.get(obj.net_id, -1):
				_rain_sent[obj.net_id] = int(w)
				request("extra", [obj.net_id, {"water": w}])
			continue
		if obj.kind != "rain_collector":
			continue
		var water: float = minf(obj.extra.get("water", 0.0) + Weather.i.rain * 0.015, PlacedObject.COLLECTOR_CAP)
		obj.extra.water = water
		if int(water) != _rain_sent.get(obj.net_id, -1):
			_rain_sent[obj.net_id] = int(water)
			request("extra", [obj.net_id, {"water": water}])


## Coisas que vão na parede (o martelo/tocha escolhe a variante mirando uma parede).
const WALL_KINDS := ["connector_wall", "lamp_wall", "torch_wall", "deco_painting", "deco_shelf", "deco_clock",
	"insulator", "switch", "switch_wall", "electric_motor"]


## Pedido de qualquer jogador (vai para o host).
func request(action: String, args: Array) -> void:
	Net.i.system_request(name, action, args)


## Tem alguma coisa a menos de "radius" de "point"? (não empilha potes)
func occupied(point: Vector3, radius: float) -> bool:
	for obj: PlacedObject in objects.values():
		if obj.kind == "bed":
			continue
		if Vector2(obj.global_position.x - point.x, obj.global_position.z - point.z).length() < radius \
				and absf(obj.global_position.y - point.y) < 1.0:
			return true
	return false


func bed_at(cell: Vector3i) -> bool:
	for obj: PlacedObject in objects.values():
		if obj.kind == "bed" and obj.get_meta("cell", Vector3i(-999, 0, 0)) == cell:
			return true
	return false


# --- Host -------------------------------------------------------------------------

func host_apply(action: String, args: Array) -> Array:
	match action:
		"place":
			var kind: String = args[0]
			var xform: Transform3D = args[1]
			if kind not in ["pot_small", "pot_wide", "bed", "ground", "bench", "workbench", "furnace", "campfire",
					"spikes", "beartrap", "barbed", "mine", "drawboard", "chest", "flag", "rain_collector", "dryer",
					"grindstone", "quern", "pump", "spinning", "loom", "stone_furnace", "oven", "filter", "smoker", "compost", "sieve",
					"shaft", "water_wheel", "windmill", "sawmill", "ram_pump", "stairs",
					"blast_furnace", "blast_stack", "boiler", "steam_engine", "water_tank", "sprinkler", "lathe", "press", "distillery",
					"trough", "water_trough", "fence", "gate", "rotisserie"] \
					and not Electric.has(kind) and not Decor.has(kind) and not PlacedTorch.has(kind) and not Smithing.has(kind):
				return []
			if kind in ["water_wheel", "ram_pump"] and not river_bank(xform.origin):
				return [] # só na beira de um rio
			if kind == "pump" and not Farming._shore(xform.origin):
				return [] # bomba só na beira do lago
			if kind == "bed":
				var cell := Vector3i((xform.origin / BuildPiece.SEG).round())
				if bed_at(cell):
					return []
			elif kind == "blast_stack":
				if not stack_spot_free(xform.origin):
					return [] # anel do alto-forno: empilhado em cima da base/de outro anel
			elif kind in ["fence", "gate", "electric_fence"]:
				if occupied(xform.origin, 0.15):
					return [] # cercas encostam umas nas outras (só não no mesmo lugar)
			elif kind in WALL_KINDS:
				if occupied(xform.origin, 0.12):
					return [] # coisas de parede: só não no mesmo ponto
			elif occupied(xform.origin, 0.3):
				return []
			var id := _next_id
			_next_id += 1
			_spawn(id, kind, xform)
			var start := {}
			if args.size() > 2 and args[2] is Dictionary and args[2].has("fuel"):
				start.fuel_until = clock + clampf(float(args[2].fuel), 0.0, PlacedTorch.MAX) # tocha: o que ela ainda tinha
			if not start.is_empty():
				objects[id].extra.merge(start, true)
				objects[id].refresh(clock)
			return [id, kind, xform, start]
		"cable":
			# Cabo entre dois bornes (os cabos já saíram da mochila de quem ligou). Ligar
			# de novo o mesmo par tira o cabo (e devolve os dois).
			var a: PlacedObject = objects.get(args[0])
			var b: PlacedObject = objects.get(args[1])
			if a == null or b == null or not Electric.cable_ok(a, b):
				if a and b:
					Net.i.give_to(Net.i.request_peer, Electric.CABLE_ITEM, Electric.cable_cost(Electric.terminal(a).distance_to(Electric.terminal(b))))
				return []
			var cost := Electric.cable_cost(Electric.terminal(a).distance_to(Electric.terminal(b)))
			var cables_a: Array = a.extra.get("cables", []).duplicate()
			var cables_b: Array = b.extra.get("cables", []).duplicate()
			if Electric.linked(a, b):
				cables_a.erase(b.net_id)
				cables_b.erase(a.net_id)
				Net.i.give_to(Net.i.request_peer, Electric.CABLE_ITEM, cost * 2)
			else:
				cables_a.append(b.net_id)
			a.extra.cables = cables_a
			b.extra.cables = cables_b
			_cables_dirty = true
			Electric.dirty = true
			Sfx.play_at("click", Electric.terminal(b), 0.0, 1.3)
			return [a.net_id, cables_a, b.net_id, cables_b]
		"grind_put":
			# Ferramenta deixada na pedra de amolar com força (já saiu da mochila de quem pôs).
			var obj: PlacedObject = objects.get(args[0])
			var tool: Dictionary = args[1] if args[1] is Dictionary else {}
			if obj == null or obj.kind != "grindstone" or not obj.extra.get("tool", {}).is_empty() or tool.is_empty():
				if not tool.is_empty():
					Net.i.give_to(Net.i.request_peer, StringName(tool.id), 1, -1, float(tool.get("dur", 1.0)), ItemDB.extras(tool))
				return []
			obj.extra.tool = {"id": String(tool.id), "dur": float(tool.get("dur", 1.0)), "sharp": float(tool.get("sharp", 0.0))}
			if tool.has("q"):
				obj.extra.tool.q = float(tool.q)
			obj.refresh(clock)
			return [args[0], {"tool": obj.extra.tool}]
		"grind_take":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or obj.kind != "grindstone" or obj.extra.get("tool", {}).is_empty():
				return []
			var tool: Dictionary = obj.extra.tool
			obj.extra.tool = {}
			obj.refresh(clock)
			if Net.i.request_peer == Net.i.my_id():
				AutoMachines.receive(self, tool) # quem pegou é o host
			return [args[0], {"tool": {}}, tool, Net.i.request_peer]
		"battery_cell":
			# Célula posta na estrutura da bateria (já saiu da mochila de quem pôs).
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or obj.kind != "battery" or Electric.cells(obj) >= Electric.CELLS:
				if obj:
					Net.i.give_to(Net.i.request_peer, Electric.CELL_ITEM, 1)
				return []
			obj.extra.cells = Electric.cells(obj) + 1
			obj.refresh(clock)
			return [args[0], {"cells": obj.extra.cells}]
		"zap":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or Net.i.request_peer != Net.i.my_id():
				return [] # só o host dá choque
			ElectricFence.spark(obj, args[1])
			return args
		"smith_done":
			# Fim do minigame da forja/fundição/solda: [id, receita, qualidade]. Gasta o
			# material dos lugares e põe a peça (ou a sucata, se perdeu) no lugar da peça pronta.
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or not Smithing.STATION.has(obj.kind):
				return []
			var update := Smithing.host_make(self, obj, int(args[1]), float(args[2]))
			return [] if update.is_empty() else [args[0], update]
		"radio_deliver":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or obj.kind != "radio":
				return []
			var update := Radio.host_deliver(self, obj)
			if update.is_empty():
				return []
			obj.extra.merge(update, true)
			obj.refresh(clock)
			return [args[0], update]
		"belt":
			# Esteira polia <-> polia ou polia <-> máquina (a esteira já saiu da mochila de quem
			# ligou). Ligar de novo o mesmo par tira a esteira (e devolve).
			var a: PlacedObject = objects.get(args[0])
			var b: PlacedObject = objects.get(args[1])
			if a == null or b == null or not Power.belt_ok(a, b):
				Net.i.give_to(Net.i.request_peer, &"correia", 1)
				return []
			var holder := a if a.kind == "pulley" else b
			var other := b if holder == a else a
			var belts: Array = holder.extra.get("belts", []).duplicate()
			var other_belts: Array = other.extra.get("belts", [])
			if other.net_id in belts or holder.net_id in other_belts:
				belts.erase(other.net_id)
				if holder.net_id in other_belts:
					other_belts = other_belts.duplicate()
					other_belts.erase(holder.net_id)
					other.extra.belts = other_belts
				Net.i.give_to(Net.i.request_peer, &"correia", 2) # a desta vez e a que estava
			else:
				belts.append(other.net_id)
			holder.extra.belts = belts
			_belts_dirty = true
			Power.dirty = true
			return [holder.net_id, belts, other.net_id, other.extra.get("belts", [])]
		"axle":
			# Eixo [xform, comprimento] (os eixos já saíram da mochila). Ponta solta vira tripé.
			var xform: Transform3D = args[0]
			var length := float(args[1])
			if length < 0.3 or length > PowerParts.MAX_AXLE + 0.01:
				Net.i.give_to(Net.i.request_peer, PowerParts.AXLE_ITEM, PowerParts.axle_cost(clampf(length, 0.3, PowerParts.MAX_AXLE)))
				return []
			var ends: Array[Vector3] = [xform.origin, xform * Vector3(0, 0, length)]
			var tripods := []
			for p in ends:
				if Power.snap_point(objects, p, Power.SNAP) == Vector3.INF:
					tripods.append([_next_id + 1 + tripods.size(), p, _ground_below(p)])
			var id := _next_id
			_next_id += 1 + tripods.size()
			_spawn(id, "axle", xform, true)
			objects[id].extra.len = length
			objects[id].refresh(clock)
			for t in tripods:
				_spawn(t[0], "tripod", Transform3D(Basis(), t[1]), true)
				objects[t[0]].extra.h = t[2]
				objects[t[0]].refresh(clock)
			Sfx.play_at("knock", xform.origin, -2.0, 1.2)
			return [id, xform, length, tripods]
		"mount":
			# Engrenagem/polia [tipo, xform] montada num eixo, tripé ou porta (o item já saiu).
			var kind: String = args[0]
			var xform: Transform3D = args[1]
			if not kind in PowerParts.ITEMS:
				return []
			for value in objects.values():
				if is_instance_valid(value) and value.kind in PowerParts.ITEMS and value.global_position.distance_to(xform.origin) < 0.2:
					Net.i.give_to(Net.i.request_peer, PowerParts.ITEMS[kind], 1) # já tem uma aí
					return []
			var id := _next_id
			_next_id += 1
			_spawn(id, kind, xform, true)
			Sfx.play_at("knock", xform.origin, -2.0, 1.5)
			return [id, kind, xform]
		"pipe":
			# Trecho de cano [xform, comprimento] (os canos já saíram da mochila de quem pôs).
			var xform: Transform3D = args[0]
			var length := float(args[1])
			if length < 0.25 or length > Fluids.MAX_PIPE + 0.01:
				Net.i.give_to(Net.i.request_peer, &"cano", Fluids.pipe_cost(clampf(length, 0.25, Fluids.MAX_PIPE)))
				return []
			var id := _next_id
			_next_id += 1
			_spawn(id, "pipe", xform, true)
			objects[id].extra.len = length
			objects[id].refresh(clock)
			Sfx.play_at("knock", xform.origin, -2.0, 1.4)
			return [id, xform, length]
		"pour":
			# Garrafa de água despejada na caldeira/destilaria/caixa d'água (a garrafa vazia já voltou).
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or not obj.kind in POUR_CAP:
				return []
			obj.extra.water = minf(obj.extra.get("water", 0.0) + 1.0, POUR_CAP[obj.kind])
			return [args[0], {"water": obj.extra.water}]
		"boom":
			if Net.i.request_peer != Net.i.my_id():
				return [] # só o host explode a caldeira
			var obj: PlacedObject = objects.get(args[0])
			if obj == null:
				return []
			if ContainerManager.i:
				ContainerManager.i.contents.erase(Smelting.key_of(obj)) # o carvão vai junto
			_boom(obj, false)
			return args
		"fuel":
			# Lenha na fogueira / forno aceso: [id, segundos, chave]. O host soma ao que já queima.
			var obj: PlacedObject = objects.get(args[0])
			var key: String = args[2] if args.size() > 2 else "fuel_until"
			if obj == null or key not in ["fuel_until", "lit_until"]:
				return []
			var until := minf(maxf(clock, obj.extra.get(key, 0.0)) + clampf(float(args[1]), 0.0, 3600.0), clock + 4.0 * 3600.0)
			obj.extra[key] = until
			obj.refresh(clock)
			return [args[0], until, key]
		"machine_put":
			# Material entrando numa máquina de manivela (já saiu da mochila de quem pôs).
			var obj: PlacedObject = objects.get(args[0])
			var amount: int = args[1]
			if obj == null or not Machines.PROCESS.has(obj.kind) or amount <= 0:
				return []
			var room: int = Machines.CAPACITY - obj.extra.get("in", 0)
			var put := mini(room, amount)
			if amount > put:
				Net.i.give_to(Net.i.request_peer, Machines.PROCESS[obj.kind][0], amount - put) # não coube: volta
			obj.extra["in"] = obj.extra.get("in", 0) + put
			return [args[0], obj.extra]
		"machine_take":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or not Machines.PROCESS.has(obj.kind) or obj.extra.get("out", 0) <= 0:
				return []
			Net.i.give_to(Net.i.request_peer, Machines.PROCESS[obj.kind][2], obj.extra.out)
			obj.extra.out = 0
			return [args[0], obj.extra]
		"crank":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or not Machines.is_crank(obj.kind):
				return []
			var extra := Machines.host_crank(obj, float(args[1]), clock)
			return [] if extra.is_empty() else [args[0], extra]
		"vanish":
			return args if Net.i.request_peer == Net.i.my_id() else [] # só o host manda (o objeto já saiu nele)
		"draw_water":
			# Encheu uma garrafa no coletor ou na caixa d'água (a garrafa vazia já saiu da mochila de quem pediu).
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or not obj.kind in ["rain_collector", "water_tank"] or obj.extra.get("water", 0.0) < 1.0:
				Net.i.give_to(Net.i.request_peer, &"garrafa", 1) # sem água: devolve a garrafa
				return []
			obj.extra.water = obj.extra.water - 1.0
			Net.i.give_to(Net.i.request_peer, &"agua" if obj.kind == "rain_collector" else &"agua_suja", 1)
			obj.refresh(clock)
			return [args[0], obj.extra.water]
		"airdrop":
			if Net.i.request_peer != Net.i.my_id():
				return [] # só o próprio host solta airdrop
			var id := _next_id
			_next_id += 1
			_spawn(id, "airdrop", args[0])
			objects[id].extra.expire = airdrop_expiry()
			if ContainerManager.i:
				var slots := ContainerManager.empty_slots(ContainerManager.STORAGE_SLOTS)
				for k in 2:
					for drop in Loot.roll("airdrop"):
						ContainerManager.add_to(slots, drop[0], drop[1])
				ContainerManager.i.contents["placed_%d" % id] = slots
			return [id, "airdrop", args[0]]
		"remove":
			if not objects.has(args[0]):
				return []
			var obj: PlacedObject = objects[args[0]]
			if obj.kind == "flag":
				Net.i.give_to(Net.i.request_peer, &"bandeira", 1) # recolheu: volta para a mochila
			if obj.kind == "grindstone" and not obj.extra.get("tool", {}).is_empty():
				Net.i.give_to(Net.i.request_peer, StringName(obj.extra.tool.id), 1, -1, float(obj.extra.tool.get("dur", 1.0))) # a ferramenta que estava amolando
			if PlacedTorch.has(obj.kind) and PlacedTorch.left(obj, clock) > 20.0:
				# A tocha volta com o que ainda tinha para queimar.
				Net.i.give_to(Net.i.request_peer, &"tocha", 1, -1, minf(PlacedTorch.left(obj, clock) / PlacedTorch.BURN, 1.0))
			if obj.kind in ["chest", "airdrop", "trough", "bed", "fridge"] and ContainerManager.i:
				ContainerManager.i.dump("placed_%d" % obj.net_id, obj.global_position) # o que tinha dentro cai
			if obj.kind in Smelting.SLOT_KINDS and ContainerManager.i:
				ContainerManager.i.dump(Smelting.key_of(obj), obj.global_position)
			_remove(args[0])
			return args
		"plant":
			var obj: PlacedObject = objects.get(args[0])
			var slot: int = args[1]
			var crop: String = args[2]
			if obj == null or slot < 0 or slot >= obj.crops.size() or not obj.crops[slot].is_empty() \
					or not Farming.CROPS.has(crop) or not obj.allows(crop) or not obj.plantable(slot):
				return []
			obj.crops[slot] = {"crop": crop, "t": grow_clock}
			if irrigated(obj.global_position):
				obj.crops[slot].boost = IRRIGATION_BOOST
			obj.refresh(clock)
			return [args[0], slot, crop, grow_clock, obj.crops[slot].get("boost", 1.0)]
		"cook":
			var obj: PlacedObject = objects.get(args[0])
			var slot: int = args[1]
			if obj == null or obj.kind not in Cooking.KINDS or slot < 0 or slot >= obj.crops.size() \
					or not obj.crops[slot].is_empty() or not Cooking.table(obj.kind).has(StringName(args[2])):
				return []
			if obj.kind == "smoker":
				# Precisa de carvão: quem pôs mandou junto (args[3]) quando acabou a carga.
				if args.size() > 3 and args[3]:
					obj.extra.charge = obj.extra.get("charge", 0) + Cooking.SMOKE_PER_COAL
				if obj.extra.get("charge", 0) <= 0:
					Net.i.give_to(Net.i.request_peer, StringName(args[2]), 1) # sem carvão: devolve
					return []
				obj.extra.charge = obj.extra.charge - 1
			obj.crops[slot] = Cooking.make_entry(obj.kind, StringName(args[2]), clock)
			obj.refresh(clock)
			return [args[0], slot, args[2], clock, obj.extra.get("charge", 0)]
		"take_cooked":
			var obj: PlacedObject = objects.get(args[0])
			var slot: int = args[1]
			if obj == null or obj.kind not in Cooking.KINDS or slot < 0 or slot >= obj.crops.size():
				return []
			var result := Cooking.result_of(obj.crops[slot], clock)
			if result == &"":
				return []
			Net.i.give_to(Net.i.request_peer, result, 1) # direto para a mochila (voa até quem pegou)
			obj.crops[slot] = {}
			obj.refresh(clock)
			return args
		"gate":
			# Porteira: abre/fecha para todos.
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or obj.kind != "gate":
				return []
			obj.extra.open = not obj.extra.get("open", false)
			obj.refresh(clock)
			return [args[0], {"open": obj.extra.open}]
		"fence_hit":
			# Zumbi batendo na cerca/porteira (só o host): cai depois de FENCE_HP golpes.
			if Net.i.request_peer != Net.i.my_id():
				return []
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or not obj.kind in ["fence", "gate"]:
				return []
			obj.extra.hits = obj.extra.get("hits", 0) + int(args[1])
			if obj.extra.hits >= Ranch.FENCE_HP:
				Sfx.play_at("crunch", obj.global_position + Vector3.UP * 0.5, 5.0, 0.7)
				_remove(args[0])
				return [args[0], {"gone": true}]
			return [args[0], {"hits": obj.extra.hits}]
		"extra":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or not args[1] is Dictionary:
				return []
			obj.extra.merge(args[1], true)
			if obj.kind in Electric.SWITCHES and args[1].has("closed"):
				Electric.dirty = true # interruptor mudou: a rede se divide/junta
			obj.refresh(clock)
			return args
		"plant_tree":
			var xform: Transform3D = args[0]
			var planter: PlacedObject = objects.get(args[1]) if args[1] >= 0 else null
			if args[1] >= 0 and (planter == null or planter.extra.has("tree")):
				return []
			if planter == null and occupied(xform.origin, 1.2):
				return []
			var id := _next_id
			_next_id += 1
			_plant_tree(id, xform, clock, args[1])
			return [id, xform, clock, args[1]]
		"chop":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or obj.kind != "tree":
				return []
			if obj.extra.get("deco", false):
				# Muda de decoração (vaso/floreira): um golpe arranca e devolve a muda.
				Net.i.give_to(Net.i.request_peer, &"muda", 1)
				_fell(obj)
				return [args[0]]
			if obj.tree_growth(clock) < 1.0:
				return []
			obj.extra.hp = obj.extra.get("hp", 90.0) - float(args[1])
			if obj.extra.hp > 0.0:
				return []
			# Derrubou: troncos, gravetos e SEMPRE uma muda (10% de chance de duas),
			# direto para a mochila de quem derrubou (o que não couber cai no chão).
			Net.i.give_to(Net.i.request_peer, &"tronco", randi_range(2, 3))
			Net.i.give_to(Net.i.request_peer, &"muda", 2 if randf() < 0.1 else 1)
			var sticks := randi_range(0, 2)
			if sticks > 0:
				Net.i.give_to(Net.i.request_peer, &"graveto", sticks)
			Sfx.play_at("thud", obj.global_position + Vector3.UP, 4.0, 0.6)
			_fell(obj)
			return [args[0]]
		"draw":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or obj.board == null or not args[1] is PackedVector2Array or args[1].size() > 400:
				return []
			obj.board.stroke(args[1], args[2], args[3])
			return args
		"clear_board":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or obj.board == null:
				return []
			obj.board.clear()
			return args
		"explode":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or obj.kind != "mine":
				return []
			_explode(obj, false)
			return args
		"harvest":
			var obj: PlacedObject = objects.get(args[0])
			var slot: int = args[1]
			if obj == null or slot < 0 or slot >= obj.crops.size() or PlacedObject.progress(obj.crops[slot], clock) < 1.0:
				return []
			_drop_harvest(obj, slot)
			obj.crops[slot] = {}
			obj.refresh(clock)
			return args
	return []


## A colheita pula da planta: comida + sementes para plantar de novo.
func _drop_harvest(obj: PlacedObject, slot: int) -> void:
	var def: Dictionary = Farming.CROPS[obj.crops[slot].crop]
	var where := Transform3D(Basis(), obj.slot_world(slot) + Vector3.UP * 0.3)
	var food := randi_range(def.yield[0], def.yield[1])
	if obj.extra.get("fert", 0) > 0: # adubado: rende o dobro (3 colheitas)
		food *= 2
		obj.extra.fert = obj.extra.fert - 1
	var seeds := randi_range(def.seeds[0], def.seeds[1])
	if obj.has_basket() and ContainerManager.i:
		# Canteiro: tudo vai para o cesto do meio (o que não couber cai do lado).
		var key := obj.basket_key()
		if not ContainerManager.i.contents.has(key):
			ContainerManager.i.contents[key] = ContainerManager.empty_slots(ContainerManager.STORAGE_SLOTS)
		var slots: Array = ContainerManager.i.contents[key]
		var basket := obj.slot_world(PlacedObject.BASKET_SLOT) + Vector3.UP * 0.5
		food = ContainerManager.add_to(slots, def.food, food)
		if seeds > 0:
			seeds = ContainerManager.add_to(slots, def.seed, seeds)
		ContainerManager.i.changed.emit(key)
		if Net.i.online():
			Net.i._system.rpc("Containers", "sync", [key, slots])
		ImpactFX.burst(self, basket, Vector3.UP, Color(0.6, 0.5, 0.3), 6, 1.2, 0.03)
		where.origin = basket
		obj.refresh(clock)
	if food > 0:
		Net.i.drop_item(def.food, food, where, Vector3(randf_range(-1, 1), 2.5, randf_range(-1, 1)))
	if seeds > 0:
		Net.i.drop_item(def.seed, seeds, where, Vector3(randf_range(-1, 1), 2.5, randf_range(-1, 1)))
	Sfx.play_at("pickup", where.origin, 0.0, 0.8)


func _plant_tree(id: int, xform: Transform3D, planted: float, planter_id: int) -> void:
	_spawn(id, "tree", xform, true)
	var obj: PlacedObject = objects[id]
	obj.extra.merge({"t": planted, "hp": 90.0, "planter": planter_id}, true)
	var planter: PlacedObject = objects.get(planter_id)
	if planter and planter.kind not in ["bed", "ground"]:
		obj.extra.deco = true # vaso/floreira não tem terra para virar árvore
	if planter:
		planter.extra.tree = id # floreira/canteiro fica todo ocupado
	obj.refresh(clock)


## Host: airdrop da onda vencida, já cheio (o conteúdo é de um baú "placed_<id>").
func drop_airdrop(xform: Transform3D) -> void:
	Net.i.system_request(name, "airdrop", [xform])


## Árvore derrubada: some e libera o plantador.
func _fell(obj: PlacedObject) -> void:
	var planter: PlacedObject = objects.get(obj.extra.get("planter", -1))
	if planter:
		planter.extra.erase("tree")
	_remove(obj.net_id)


## Onde dá para despejar garrafas de água, e quanto cabe.
const POUR_CAP := {"boiler": Fluids.BOILER_WATER, "distillery": Fluids.STILL_WATER, "water_tank": Fluids.TANK_CAP, "water_trough": Ranch.WATER_CAP}


## Lugar livre para um anel do alto-forno: em cima de uma base ou de outro anel, sem anel ali.
func stack_spot_free(at: Vector3) -> bool:
	var support := false
	for obj: PlacedObject in objects.values():
		if obj.kind == "blast_stack" and obj.global_position.distance_to(at) < 0.35:
			return false
		if obj.kind == "blast_furnace" and obj.global_position.distance_to(at - Vector3.UP * Fluids.BLAST_BASE_H) < 0.35:
			support = true
		if obj.kind == "blast_stack" and obj.global_position.distance_to(at - Vector3.UP * Fluids.BLAST_RING_H) < 0.35:
			support = true
	return support


## Caldeira estourando: estilhaços (dano em quem estiver perto, até o dono) e some.
func _boom(obj: PlacedObject, cosmetic: bool) -> void:
	var explosion := Explosion.new()
	explosion.cosmetic = cosmetic
	get_parent().add_child(explosion)
	explosion.global_position = obj.global_position + Vector3.UP * 1.0
	explosion.detonate(6.0, 140.0, 16.0, 2.2)
	Sfx.play_at("thud", obj.global_position + Vector3.UP, 8.0, 0.4)
	# Estilhaços também pegam o jogador daqui (cada um cuida do seu).
	var me := get_tree().get_first_node_in_group("player") as Player
	if me and not me.is_puppet():
		var d := me.global_position.distance_to(explosion.global_position)
		if d < 6.0:
			me.take_damage(90.0 * (1.0 - d / 6.0) + 10.0, (me.global_position - explosion.global_position).normalized())
	_remove(obj.net_id)


## Mina: explosão de verdade no host (dano nos zumbis), só o efeito nos clientes.
func _explode(obj: PlacedObject, cosmetic: bool) -> void:
	var explosion := Explosion.new()
	explosion.cosmetic = cosmetic
	get_parent().add_child(explosion)
	explosion.global_position = obj.global_position + Vector3.UP * 0.3
	explosion.detonate(5.0, 120.0, 14.0, 1.8)
	_remove(obj.net_id)


func apply_remote(action: String, args: Array) -> void:
	match action:
		"cook":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.crops[args[1]] = Cooking.make_entry(obj.kind, StringName(args[2]), args[3])
				if args.size() > 4:
					obj.extra.charge = args[4]
				obj.refresh(clock)
		"take_cooked":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.crops[args[1]] = {}
				obj.refresh(clock)
		"cable":
			for k in [0, 2]:
				var obj: PlacedObject = objects.get(args[k])
				if obj:
					obj.extra.cables = args[k + 1]
			_cables_dirty = true
			Electric.dirty = true
		"zap":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				ElectricFence.spark(obj, args[1])
		"grind_take":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.extra.tool = {}
				obj.refresh(clock)
			if args.size() > 3 and args[3] == Net.i.my_id():
				AutoMachines.receive(self, args[2]) # a ferramenta volta para quem pegou, com o fio
		"extra", "gate", "fence_hit", "radio_deliver", "battery_cell", "grind_put", "smith_done":
			var obj: PlacedObject = objects.get(args[0])
			if obj and obj.kind in Electric.SWITCHES:
				Electric.dirty = true
			if obj and args[1].get("gone", false):
				_remove(args[0])
			elif obj:
				obj.extra.merge(args[1], true)
				obj.refresh(clock)
		"explode":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				_explode(obj, true)
		"boom":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				_boom(obj, true)
		"pipe":
			if not objects.has(args[0]):
				_spawn(args[0], "pipe", args[1], true)
				objects[args[0]].extra.len = args[2]
				objects[args[0]].refresh(clock)
		"pour":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.extra.merge(args[1], true)
		"plant_tree":
			if not objects.has(args[0]):
				_plant_tree(args[0], args[1], args[2], args[3])
		"chop":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				_fell(obj)
		"draw":
			var obj: PlacedObject = objects.get(args[0])
			if obj and obj.board:
				obj.board.stroke(args[1], args[2], args[3])
		"clear_board":
			var obj: PlacedObject = objects.get(args[0])
			if obj and obj.board:
				obj.board.clear()
		"axle":
			if not objects.has(args[0]):
				_spawn(args[0], "axle", args[1], true)
				objects[args[0]].extra.len = args[2]
				objects[args[0]].refresh(clock)
				for t in args[3]:
					_spawn(t[0], "tripod", Transform3D(Basis(), t[1]), true)
					objects[t[0]].extra.h = t[2]
					objects[t[0]].refresh(clock)
		"mount":
			if not objects.has(args[0]):
				_spawn(args[0], args[1], args[2], true)
		"belt":
			if args.size() >= 4 and objects.has(args[2]):
				objects[args[2]].extra.belts = args[3]
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.extra.belts = args[1]
				_belts_dirty = true
		"fuel":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.extra[args[2]] = args[1]
				obj.refresh(clock)
		"machine_put", "machine_take", "crank":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.extra = args[1].duplicate()
		"vanish":
			if objects.has(args[0]):
				_remove(args[0])
		"draw_water":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.extra.water = args[1]
				obj.refresh(clock)
		"place", "airdrop":
			if not objects.has(args[0]):
				_spawn(args[0], args[1], args[2])
				if args.size() > 3 and args[3] is Dictionary and not args[3].is_empty():
					objects[args[0]].extra.merge(args[3], true)
					objects[args[0]].refresh(clock)
		"remove":
			_remove(args[0])
		"plant":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.crops[args[1]] = {"crop": args[2], "t": args[3]}
				if args.size() > 4 and args[4] > 1.0:
					obj.crops[args[1]].boost = args[4]
				obj.refresh(clock)
		"harvest":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.crops[args[1]] = {}
				obj.refresh(clock)


func _spawn(id: int, kind: String, xform: Transform3D, quiet := false) -> void:
	if Power.is_power(kind):
		Power.dirty = true # forma da rede de força mudou
	if Electric.has(kind):
		Electric.dirty = true
		_cables_dirty = true
	var obj := PlacedObject.new()
	obj.name = "Placed_%d" % id
	obj.net_id = id
	obj.setup(kind)
	if kind == "bed":
		obj.set_meta("cell", Vector3i((xform.origin / BuildPiece.SEG).round()))
	add_child(obj)
	obj.global_transform = xform
	objects[id] = obj
	_next_id = maxi(_next_id, id + 1)
	if not quiet:
		Sfx.play_at("knock" if kind != "ground" else "step_soft", xform.origin + Vector3.UP * 0.3, 0.0, 0.9)


func _remove(id: int) -> void:
	_belts_dirty = true
	Power.dirty = true
	Electric.dirty = true
	_cables_dirty = true
	var obj: PlacedObject = objects.get(id)
	objects.erase(id)
	if is_instance_valid(obj):
		obj.queue_free()


# --- Salvar / rede ---------------------------------------------------------------------

func persist_key() -> String:
	return "placed"


func save_data() -> Dictionary:
	var list := []
	for id in objects:
		var obj: PlacedObject = objects[id]
		if obj.board:
			obj.extra["pixels"] = obj.board.packed() # desenho da lousa vai junto
		list.append([id, obj.kind, obj.global_transform, obj.crops.duplicate(true), obj.extra.duplicate(true)])
	return {"clock": clock, "grow": grow_clock, "next": _next_id, "list": list}


func load_data(data: Dictionary) -> void:
	for id in objects.keys():
		_remove(id)
	clock = data.get("clock", 0.0)
	grow_clock = data.get("grow", clock) # save antigo: as plantas contavam pelo relógio normal
	_next_id = data.get("next", 1)
	for entry in data.get("list", []):
		_spawn(entry[0], entry[1], entry[2], true)
		var obj: PlacedObject = objects[entry[0]]
		for i in mini(entry[3].size(), obj.crops.size()):
			obj.crops[i] = entry[3][i]
		if entry.size() > 4:
			obj.extra.merge(entry[4], true)
			if obj.board and obj.extra.has("pixels"):
				obj.board.unpack(obj.extra.pixels)
		obj.refresh(clock)


## Quem acabou de entrar recebe tudo.
func net_sync_to(peer: int) -> void:
	Net.i.send_system_state(peer, name, save_data())
