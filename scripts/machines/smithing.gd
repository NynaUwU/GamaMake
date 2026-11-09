class_name Smithing
extends RefCounted
## Estações de oficina com minigame (Eras 1-3) e a trefiladora:
##   forge        forja de tijolo com coifa, fole e bigorna (Era 1). Lugares: metal,
##                carvão, peça. Minigame "forge": cor por temperatura.
##   foundry      fundição (Era 2): fornalhinha com cadinho basculante e caixa de areia
##                com o molde. Lugares: metal, liga (2º metal), carvão, peça. Faz bronze
##                (cobre + estanho) e peças fundidas. Minigame "casting": despejar com a
##                inclinação certa (3D).
##   weld_bench   bancada de solda elétrica (Era 3, Manual de soldagem; 300 W ligada).
##                Lugares: chapas de aço, eletrodos, peça. Só armaduras. Minigame
##                "welding": seguir a junta com velocidade constante.
##   torch_bench  bancada de maçarico (Manual de soldagem): solda cobre com estanho
##                (brasagem). Lugares: cobre, solda (estanho), outro (vidro), combustível
##                (álcool, óleo ou botijão de gás), peça. Minigame "welding" no modo
##                "brazing": chama em vez de arco, mais devagar, sem máscara.
##   wire_drawer  trefiladora: com eixo/motor, barra de cobre vira fio (sem minigame;
##                funde sozinha como as fornalhas: Smelting).
## A peça sai com qualidade ("q" no item: dano/proteção e desgaste); pilhas (barras,
## engrenagens) saem em menor quantidade quando a qualidade é baixa. Peça perdida
## (qualidade 0) vira 1 sucata. Os lugares são o "baú" furnace_<id> (Smelting).

const KINDS := ["forge", "wire_drawer", "foundry", "weld_bench", "torch_bench"]
const STATION := {"forge": "forja", "foundry": "fundicao", "weld_bench": "solda", "torch_bench": "macarico"}
const MINIGAME := {"forja": "forge", "fundicao": "casting", "solda": "welding", "macarico": "welding"}
## Evento das conquistas ao terminar (Progress): forge:<item>, cast:<item>, weld:<item>, braze:<item>.
const EVENT := {"forja": "forge", "fundicao": "cast", "solda": "weld", "macarico": "braze"}
## Maçarico: quantas soldas cada combustível rende.
const TORCH_FUEL := {&"alcool": 1, &"oleo": 1, &"botijao": 8}
const EXTRA_SLOT := 4 ## 5º lugar do maçarico (vidro e outros)
## Combustível gasto por peça (a solda gasta eletrodo, que já está no custo).
const FUEL_COST := {"forja": 1, "fundicao": 1}
const ALLOY := 3 ## 4º lugar da fundição: o segundo metal (liga)
const HOT_TIME := 45.0 ## segundos que a forja/fundição fica acesa depois de usar
const STEEL_BONUS := 0.1 ## aço na forja: peça um pouco melhor
const SCRAP_BACK := 1 ## peça perdida: sobra isso de sucata
const WELD_POWER := 300.0 ## W da bancada de solda (Electric.DEMAND)


static func has(kind: String) -> bool:
	return kind in KINDS


## Receitas da estação ("forja", "fundicao", "solda"): [índice em CraftingUI.RECIPES, receita].
static func recipes(station: String) -> Array:
	var list := []
	for k in CraftingUI.RECIPES.size():
		if CraftingUI.RECIPES[k].station == station:
			list.append([k, CraftingUI.RECIPES[k]])
	return list


## Lugares de material da estação (onde o custo da receita fica).
static func input_slots(kind: String) -> Array:
	match kind:
		"foundry":
			return [Smelting.INPUT, ALLOY]
		"weld_bench":
			return [Smelting.INPUT, Smelting.FUEL] # aço + eletrodos
		"torch_bench":
			return [Smelting.INPUT, ALLOY, EXTRA_SLOT] # cobre, estanho, vidro
	return [Smelting.INPUT]


## Pode ir neste lugar? (Smelting.accepts chama para as estações daqui)
static func accepts(slot_index: int, id: StringName, kind: String) -> bool:
	var station: String = STATION.get(kind, "")
	if slot_index == Smelting.OUTPUT:
		return false
	if kind == "weld_bench":
		if slot_index == Smelting.FUEL:
			return id == &"eletrodo"
		return id != &"eletrodo" and _used_by(station, id)
	if kind == "torch_bench":
		if slot_index == Smelting.FUEL:
			return TORCH_FUEL.has(id)
		if slot_index == ALLOY:
			return id == &"barra_estanho" # a solda
		return id != &"barra_estanho" and _used_by(station, id)
	if slot_index == Smelting.FUEL:
		return id == &"carvao"
	return _used_by(station, id)


static func _used_by(station: String, id: StringName) -> bool:
	for entry in recipes(station):
		if entry[1].cost.has(id):
			return true
	return false


## Quanto de cada item há nos lugares de material.
static func _stock(kind: String, slots: Array) -> Dictionary:
	var have := {}
	for k in input_slots(kind):
		if k < slots.size() and not slots[k].is_empty():
			have[slots[k].id] = have.get(slots[k].id, 0) + int(slots[k].amount)
	return have


## O que falta para fazer a receita ("" = pode).
static func missing(recipe: Dictionary, slots: Array, obj: PlacedObject = null) -> String:
	if not Progress.knows(recipe.get("manual", "")):
		return "Precisa ler: %s" % Progress.MANUALS[StringName(recipe.manual)].title
	var kind: String = obj.kind if obj else STATION.find_key(recipe.station)
	var have := _stock(kind, slots)
	for id in recipe.cost:
		if have.get(id, 0) < recipe.cost[id]:
			return "Ponha %d %s nos lugares" % [recipe.cost[id], ItemDB.display_name(id)]
	var fuel: int = FUEL_COST.get(recipe.station, 0)
	if fuel > 0 and (slots.size() <= Smelting.FUEL or slots[Smelting.FUEL].is_empty() or slots[Smelting.FUEL].amount < fuel):
		return "Ponha carvão no lugar do fogo"
	if kind == "torch_bench" and not torch_ready(obj, slots):
		return "Ponha combustível: álcool, óleo ou botijão de gás"
	if slots.size() > Smelting.OUTPUT and not slots[Smelting.OUTPUT].is_empty():
		return "Tire a peça pronta primeiro"
	if kind == "weld_bench" and obj and not Electric.powered(obj):
		if obj.extra.get("lowv", false):
			return "Precisa de 110 V: dínamo regulado em 110 V, banco de baterias ou inversor"
		return "Sem energia: ligue a bancada numa rede de 110 V (%d W)" % int(WELD_POWER)
	return ""


## Maçarico tem chama para mais uma solda? (gás que sobrou do botijão, ou combustível no lugar)
static func torch_ready(obj: PlacedObject, slots: Array) -> bool:
	if obj and float(obj.extra.get("gas", 0.0)) >= 1.0:
		return true
	return slots.size() > Smelting.FUEL and not slots[Smelting.FUEL].is_empty() and TORCH_FUEL.has(slots[Smelting.FUEL].id)


## Host: gasta uma solda de combustível (abre outro álcool/óleo/botijão se precisar).
static func _burn_torch(obj: PlacedObject, slots: Array) -> void:
	var gas: float = obj.extra.get("gas", 0.0)
	if gas < 1.0 and not slots[Smelting.FUEL].is_empty():
		gas += TORCH_FUEL.get(slots[Smelting.FUEL].id, 0)
		_use(slots, Smelting.FUEL, 1)
	obj.extra.gas = maxf(gas - 1.0, 0.0)


## Metal principal da receita (o que dá a cor/temperatura no minigame).
static func metal_of(recipe: Dictionary) -> StringName:
	for id in recipe.cost:
		if id != &"eletrodo":
			return id
	return recipe.cost.keys()[0]


# --- Fazer (cliente que clicou) ------------------------------------------------------

## Escolheu a peça na janela: abre o minigame da estação; no fim o host gasta o
## material e põe a peça (com a qualidade) no lugar da peça pronta.
static func start(player: Player, obj: PlacedObject, index: int) -> bool:
	var recipe: Dictionary = CraftingUI.RECIPES[index]
	if missing(recipe, ContainerManager.i.slots_of(Smelting.key_of(obj)), obj) != "":
		Sfx.play("click", -6.0, 0.6)
		return false
	var context := {"item": recipe.id, "metal": metal_of(recipe), "hits": recipe.get("hits", 8), "seams": recipe.get("seams", 2),
		"mold": recipe.get("mold", "ingot"), "chart": Progress.knows(&"manual_ferreiro") and Progress.i != null,
		"mode": "brazing" if recipe.station == "macarico" else "arc"}
	var manager := obj.get_parent() as PlacedManager
	var net_id := obj.net_id
	var event: String = EVENT[recipe.station]
	Minigame.play(player, MINIGAME[recipe.station], context, func(quality: float):
		if quality < 0.0 or not is_instance_valid(manager):
			return # desistiu antes de começar: nada é gasto
		manager.request("smith_done", [net_id, index, quality])
		if quality > 0.0:
			Progress.event(event, String(recipe.id))
			if quality >= 0.9:
				Progress.event(event + "_master", String(recipe.id))
		var again: PlacedObject = manager.objects.get(net_id)
		if again and is_instance_valid(player):
			StorageUI.open_for.call_deferred(player, Smelting.key_of(again), again))
	return true


# --- Host ---------------------------------------------------------------------------

## Peça pronta: gasta o custo (+ carvão) e põe a peça (ou a sucata) no lugar da peça
## pronta. Devolve o que vai para os outros ({} = recusado).
static func host_make(manager: PlacedManager, obj: PlacedObject, index: int, quality: float) -> Dictionary:
	if index < 0 or index >= CraftingUI.RECIPES.size() or ContainerManager.i == null:
		return {}
	var recipe: Dictionary = CraftingUI.RECIPES[index]
	if recipe.station != STATION.get(obj.kind, ""):
		return {}
	var key := Smelting.key_of(obj)
	var slots: Array = ContainerManager.i.contents.get(key, [])
	if slots.size() < Smelting.slot_count(obj.kind):
		return {}
	var have := _stock(obj.kind, slots)
	for id in recipe.cost:
		if have.get(id, 0) < recipe.cost[id]:
			return {} # alguém tirou o material no meio do caminho
	var fuel: int = FUEL_COST.get(recipe.station, 0)
	if fuel > 0 and (slots[Smelting.FUEL].is_empty() or slots[Smelting.FUEL].amount < fuel):
		return {}
	if obj.kind == "torch_bench" and not torch_ready(obj, slots):
		return {}
	for id in recipe.cost:
		var need: int = recipe.cost[id]
		for k in input_slots(obj.kind):
			if need > 0 and not slots[k].is_empty() and slots[k].id == id:
				var take := mini(need, slots[k].amount)
				_use(slots, k, take)
				need -= take
	if fuel > 0:
		_use(slots, Smelting.FUEL, fuel)
	if obj.kind == "torch_bench":
		_burn_torch(obj, slots)
	var piece := piece_for(recipe, quality)
	if slots[Smelting.OUTPUT].is_empty():
		slots[Smelting.OUTPUT] = piece
	else:
		Net.i.give_to(Net.i.request_peer, piece.id, piece.amount, -1, 1.0, ItemDB.extras(piece))
	ContainerManager.i.changed.emit(key)
	Net.i.system_request("Containers", "sync", [key])
	obj.extra.hot_until = manager.clock + HOT_TIME
	obj.refresh(manager.clock)
	return {"hot_until": obj.extra.hot_until, "gas": obj.extra.get("gas", 0.0)}


## O que sai: peça única com qualidade "q"; pilha (barras, engrenagens) com menos
## unidades quanto pior; qualidade 0 = perdeu (sucata).
static func piece_for(recipe: Dictionary, quality: float) -> Dictionary:
	if quality <= 0.0:
		return {"id": &"sucata", "amount": SCRAP_BACK}
	var amount: int = recipe.get("amount", 1)
	if ItemDB.max_stack(recipe.id) > 1:
		return {"id": recipe.id, "amount": maxi(1, roundi(amount * (0.5 + 0.5 * quality)))}
	var bonus := STEEL_BONUS if recipe.station == "forja" and metal_of(recipe) == &"barra_aco" else 0.0
	return {"id": recipe.id, "amount": 1, "q": snappedf(clampf(quality + bonus, 0.05, 1.0), 0.01)}


static func _use(slots: Array, index: int, amount: int) -> void:
	slots[index].amount -= amount
	if slots[index].amount <= 0:
		slots[index] = {}


# --- Objeto no mundo ----------------------------------------------------------------

static func text(obj: PlacedObject) -> String:
	match obj.kind:
		"forge":
			return "[E] Forja e bigorna (metal + carvão: forjar peças)"
		"foundry":
			return "[E] Fundição (metais + carvão: bronze e peças fundidas)"
		"weld_bench":
			return "[E] Bancada de solda%s" % ("" if Electric.powered(obj) else " (sem energia)")
		"torch_bench":
			var gas := int(obj.extra.get("gas", 0.0))
			return "[E] Bancada de maçarico (cobre + estanho)%s" % (" · gás para %d solda%s" % [gas, "s" if gas > 1 else ""] if gas > 0 else "")
		"wire_drawer":
			if obj.extra.get("pstate", "") != "ok":
				return "[E] Trefiladora (precisa de eixo ou motor na porta de latão)"
			return "[E] Trefiladora (barra de cobre vira fio)"
	return ""


static func interact(player: Node, obj: PlacedObject) -> void:
	StorageUI.open_for(player, Smelting.key_of(obj), obj)


static func is_lit(obj: PlacedObject, clock: float) -> bool:
	return obj.kind in ["forge", "foundry", "weld_bench", "torch_bench"] and obj.extra.get("hot_until", 0.0) > clock


## Peça em brasa na bigorna / metal no molde: esfria pela cor (mesmo shader do minigame).
static func refresh(obj: PlacedObject, clock: float) -> void:
	var bar := obj.get_node_or_null("HotBar") as MeshInstance3D
	if bar == null:
		return
	var left := clampf((obj.extra.get("hot_until", 0.0) - clock) / HOT_TIME, 0.0, 1.0)
	bar.visible = left > 0.0
	(bar.material_override as ShaderMaterial).set_shader_parameter("temperature", 0.2 + left * 0.55)
