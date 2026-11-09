class_name Smelting
extends RefCounted
## Fornalhas estilo Minecraft: 3 lugares (material, combustível, resultado) num
## baú "furnace_<id>". O host funde sozinho, 1x por segundo, mesmo sem ninguém
## olhando: gasta combustível e vai soltando o resultado no 3º lugar.
## As receitas são as da fornalha na CraftingUI (um ingrediente só).
## Fornalha de pedra: ferro só funde com o fole quente (Machines.heat).
## Tier 3 (mesmo esquema de 3 lugares):
##   alto-forno  multibloco (base + 2 anéis): aço, só com carvão e com o fole girando (energia);
##   destilaria  trigo/fruta/batata -> álcool, gasta 1 de água por lote (cano ou garrafa);
##   caldeira    só o lugar do combustível: o fogo ferve a água em vapor (Fluids.boiler_step).

const INPUT := 0
const FUEL := 1
const OUTPUT := 2
const FUEL_TIME := {&"carvao": 40.0, &"tronco": 30.0, &"tabua": 12.0, &"graveto": 4.0}
const SMELT_TIME := {"furnace": 8.0, "stone_furnace": 5.0, "blast_furnace": 10.0, "distillery": 12.0, "wire_drawer": 4.0}
## Fundem sozinhas (host, 1x por segundo). A trefiladora é igual, só que gira em vez de queimar.
const KINDS := ["furnace", "stone_furnace", "blast_furnace", "distillery", "boiler", "wire_drawer"]
## Têm os 3 lugares (a forja também: metal, carvão e a peça do minigame).
## Têm os lugares (as estações de minigame também: Smithing).
const SLOT_KINDS := KINDS + ["forge", "foundry", "weld_bench"]
const STATIONS := {"stone_furnace": "fornalha_pedra", "blast_furnace": "alto_forno", "distillery": "destilaria", "wire_drawer": "trefiladora",
	"forge": "forja", "foundry": "fundicao", "weld_bench": "solda"}
## Sem fogo: o lugar do combustível fica de fora.
const NO_FUEL := ["wire_drawer"]


static func key_of(obj: PlacedObject) -> String:
	return "furnace_%d" % obj.net_id


static func station(kind: String) -> String:
	return STATIONS.get(kind, "fornalha")


## Tipo da fornalha dona da chave "furnace_<id>" ("" se não achar).
static func kind_of_key(key: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var world := tree.current_scene if tree else null
	var placed := world.get_node_or_null("Placed") as PlacedManager if world else null
	if placed == null:
		return ""
	var obj: PlacedObject = placed.objects.get(int(key.trim_prefix("furnace_")))
	return obj.kind if obj else ""


## Receita desta fornalha para o material "id" ({} se não funde).
static func recipe(kind: String, id: StringName) -> Dictionary:
	for r: Dictionary in CraftingUI.RECIPES:
		if r.station == station(kind) and r.cost.size() == 1 and r.cost.has(id):
			return r
	return {}


static func is_fuel(id: StringName) -> bool:
	return FUEL_TIME.has(id)


## Pode ir neste lugar? (o resultado não aceita nada de fora)
## Quantos lugares (a fundição tem um 4º: o segundo metal da liga).
static func slot_count(kind: String) -> int:
	return 4 if kind == "foundry" else 3


static func accepts(slot_index: int, id: StringName, kind := "") -> bool:
	if kind in ["forge", "foundry", "weld_bench"]:
		return Smithing.accepts(slot_index, id, kind)
	match slot_index:
		FUEL:
			if kind in NO_FUEL:
				return false
			if kind == "blast_furnace":
				return id == &"carvao" # alto-forno: só carvão esquenta o bastante
			return is_fuel(id)
		OUTPUT:
			return false
	if kind == "boiler":
		return false # caldeira: só combustível (a água vem pelo cano ou despejada)
	return true


## O que o host manda para os outros depois do tick (barras da janela, fogo, avisos).
static func sync_extra(obj: PlacedObject) -> Dictionary:
	var out := {"burn": obj.extra.get("burn", 0.0), "prog": obj.extra.get("prog", 0.0), "burn_max": obj.extra.get("burn_max", 1.0)}
	for key in ["heat", "water", "pressure", "dry"]:
		if obj.extra.has(key):
			out[key] = snappedf(obj.extra[key], 0.01)
	if obj.kind == "boiler":
		out.vent = obj.extra.get("vent", false)
	return out


## Host, 1x por segundo. true = mudou (o host manda para todos).
static func host_tick(obj: PlacedObject, clock: float) -> bool:
	var slots: Array = ContainerManager.i.contents.get(key_of(obj), [])
	if slots.size() < 3:
		return false
	var burn: float = obj.extra.get("burn", 0.0)
	var prog: float = obj.extra.get("prog", 0.0)
	var before := [burn, prog, str(slots)]
	if obj.kind == "boiler":
		return _boiler_tick(obj, slots, burn, before)
	var input: Dictionary = slots[INPUT]
	var r := {} if input.is_empty() else recipe(obj.kind, input.id)
	var need: int = r.cost.values()[0] if not r.is_empty() else 0
	var out_id: StringName = r.get("id", &"")
	var out_amount: int = r.get("amount", 1)
	var room: bool = not r.is_empty() and input.amount >= need and (slots[OUTPUT].is_empty() \
		or (slots[OUTPUT].id == out_id and slots[OUTPUT].amount + out_amount <= ItemDB.max_stack(out_id)))
	if room and r.get("heat", false) and Machines.heat(obj) < Machines.HEAT_NEEDED:
		room = false # ferro: precisa do fole
	if room and r.get("power", false) and (obj.extra.get("speed", 0.0) < 0.3 or (obj.kind == "blast_furnace" and not Fluids.blast_complete(obj))):
		room = false # alto-forno montado inteiro e com o fole girando; trefiladora com o eixo girando
	if room and obj.extra.get("water", 0.0) < r.get("water", 0):
		room = false # destilaria sem água
	var uses_fuel: bool = r.get("fuel", false) or obj.kind == "furnace"
	if room and burn <= 0.0 and uses_fuel and not slots[FUEL].is_empty():
		burn = FUEL_TIME.get(slots[FUEL].id, 0.0) # acende mais um combustível
		obj.extra.burn_max = burn
		slots[FUEL].amount -= 1
		if slots[FUEL].amount <= 0:
			slots[FUEL] = {}
	if room and (burn > 0.0 or not uses_fuel):
		prog += 1.0
		if prog >= SMELT_TIME.get(obj.kind, 8.0):
			prog = 0.0
			obj.extra.water = obj.extra.get("water", 0.0) - r.get("water", 0)
			input.amount -= need
			if input.amount <= 0:
				slots[INPUT] = {}
			if slots[OUTPUT].is_empty():
				slots[OUTPUT] = {"id": out_id, "amount": out_amount}
			else:
				slots[OUTPUT].amount += out_amount
	else:
		prog = 0.0
	burn = maxf(burn - 1.0, 0.0) # o fogo queima mesmo sem nada para fundir
	obj.extra.burn = burn
	obj.extra.prog = prog
	return before != [burn, prog, str(slots)]


## Caldeira: acende combustível sozinha (o fogo queima sempre que tiver lenha/carvão)
## e ferve a água. "boom" fica em obj.extra.boom para o PlacedManager explodir.
static func _boiler_tick(obj: PlacedObject, slots: Array, burn: float, before: Array) -> bool:
	if burn <= 0.0 and not slots[FUEL].is_empty():
		burn = FUEL_TIME.get(slots[FUEL].id, 0.0)
		obj.extra.burn_max = burn
		slots[FUEL].amount -= 1
		if slots[FUEL].amount <= 0:
			slots[FUEL] = {}
	var result := Fluids.boiler_step(obj, burn > 0.0)
	obj.extra.boom = result == "boom"
	obj.extra.vent = result == "vent"
	burn = maxf(burn - 1.0, 0.0)
	obj.extra.burn = burn
	return true # as barras (calor, água, pressão) mudam quase sempre
