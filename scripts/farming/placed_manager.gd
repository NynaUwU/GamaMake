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


func _process(delta: float) -> void:
	clock += delta
	_refresh -= delta
	if _belts_dirty:
		_rebuild_belts()
	if _refresh <= 0.0:
		_refresh = 1.0
		_collect_rain()
		_smelt()
		_fluids()
		_power()
		_expire_airdrops()
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
		var water: float = minf(obj.extra.get("water", 0.0) + Weather.i.rain * 0.04, PlacedObject.COLLECTOR_CAP)
		obj.extra.water = water
		if int(water) != _rain_sent.get(obj.net_id, -1):
			_rain_sent[obj.net_id] = int(water)
			request("extra", [obj.net_id, {"water": water}])


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
					"trough", "water_trough", "fence", "gate"]:
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
			elif kind in ["fence", "gate"]:
				if occupied(xform.origin, 0.15):
					return [] # cercas encostam umas nas outras (só não no mesmo lugar)
			elif occupied(xform.origin, 0.3):
				return []
			var id := _next_id
			_next_id += 1
			_spawn(id, kind, xform)
			return [id, kind, xform]
		"belt":
			# Correia entre duas peças de energia (a correia já saiu da mochila de quem ligou).
			var a: PlacedObject = objects.get(args[0])
			var b: PlacedObject = objects.get(args[1])
			if a == null or b == null or a == b or not Power.is_power(a.kind) or not Power.is_power(b.kind) \
					or a.global_position.distance_to(b.global_position) > Power.BELT_RANGE:
				Net.i.give_to(Net.i.request_peer, &"correia", 1)
				return []
			var belts: Array = a.extra.get("belts", []).duplicate()
			if b.net_id not in belts:
				belts.append(b.net_id)
			a.extra.belts = belts
			_belts_dirty = true
			return [args[0], belts]
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
			if obj.kind in ["chest", "airdrop", "trough"] and ContainerManager.i:
				ContainerManager.i.dump("placed_%d" % obj.net_id, obj.global_position) # o que tinha dentro cai
			if obj.kind in Smelting.KINDS and ContainerManager.i:
				ContainerManager.i.dump(Smelting.key_of(obj), obj.global_position)
			_remove(args[0])
			return args
		"plant":
			var obj: PlacedObject = objects.get(args[0])
			var slot: int = args[1]
			var crop: String = args[2]
			if obj == null or slot < 0 or slot >= obj.crops.size() or not obj.crops[slot].is_empty() \
					or not Farming.CROPS.has(crop) or not obj.allows(crop):
				return []
			obj.crops[slot] = {"crop": crop, "t": clock}
			if irrigated(obj.global_position):
				obj.crops[slot].boost = IRRIGATION_BOOST
			obj.refresh(clock)
			return [args[0], slot, crop, clock, obj.crops[slot].get("boost", 1.0)]
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
		"extra", "gate", "fence_hit":
			var obj: PlacedObject = objects.get(args[0])
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
		"belt":
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
	return {"clock": clock, "next": _next_id, "list": list}


func load_data(data: Dictionary) -> void:
	for id in objects.keys():
		_remove(id)
	clock = data.get("clock", 0.0)
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
