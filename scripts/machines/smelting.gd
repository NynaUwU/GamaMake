class_name Smelting
extends RefCounted
## Fornalhas estilo Minecraft: 3 lugares (material, combustível, resultado) num
## baú "furnace_<id>". O host funde sozinho, 1x por segundo, mesmo sem ninguém
## olhando: gasta combustível e vai soltando o resultado no 3º lugar.
## As receitas são as da fornalha na CraftingUI (um ingrediente só).
## Fornalha de pedra: ferro só funde com o fole quente (Machines.heat).

const INPUT := 0
const FUEL := 1
const OUTPUT := 2
const FUEL_TIME := {&"carvao": 40.0, &"tronco": 30.0, &"tabua": 12.0, &"graveto": 4.0}
const SMELT_TIME := {"furnace": 8.0, "stone_furnace": 5.0}
const KINDS := ["furnace", "stone_furnace"]


static func key_of(obj: PlacedObject) -> String:
	return "furnace_%d" % obj.net_id


static func station(kind: String) -> String:
	return "fornalha_pedra" if kind == "stone_furnace" else "fornalha"


## Receita desta fornalha para o material "id" ({} se não funde).
static func recipe(kind: String, id: StringName) -> Dictionary:
	for r: Dictionary in CraftingUI.RECIPES:
		if r.station == station(kind) and r.cost.size() == 1 and r.cost.has(id):
			return r
	return {}


static func is_fuel(id: StringName) -> bool:
	return FUEL_TIME.has(id)


## Pode ir neste lugar? (o resultado não aceita nada de fora)
static func accepts(slot_index: int, id: StringName) -> bool:
	match slot_index:
		FUEL:
			return is_fuel(id)
		OUTPUT:
			return false
	return true


## Host, 1x por segundo. true = mudou (o host manda para todos).
static func host_tick(obj: PlacedObject, clock: float) -> bool:
	var slots: Array = ContainerManager.i.contents.get(key_of(obj), [])
	if slots.size() < 3:
		return false
	var burn: float = obj.extra.get("burn", 0.0)
	var prog: float = obj.extra.get("prog", 0.0)
	var before := [burn, prog, str(slots)]
	var input: Dictionary = slots[INPUT]
	var r := {} if input.is_empty() else recipe(obj.kind, input.id)
	var need: int = r.cost.values()[0] if not r.is_empty() else 0
	var out_id: StringName = r.get("id", &"")
	var out_amount: int = r.get("amount", 1)
	var room: bool = not r.is_empty() and input.amount >= need and (slots[OUTPUT].is_empty() \
		or (slots[OUTPUT].id == out_id and slots[OUTPUT].amount + out_amount <= ItemDB.max_stack(out_id)))
	if room and r.get("heat", false) and Machines.heat(obj) < Machines.HEAT_NEEDED:
		room = false # ferro: precisa do fole
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
