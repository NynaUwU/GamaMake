class_name RecipeBook
extends RefCounted
## Livro de receitas do diário: tudo que dá para fazer em cada estação num formato só
##   {"key", "station", "out", "amount", "cost": {item: quantidade}, "note", "manual"}
## juntando a mesa e as fornalhas (CraftingUI), a fogueira/assador, secador, defumador,
## filtro e composteira (Cooking) e as máquinas de manivela/eixo (Machines.PROCESS).
##
## Uma receita aparece quando:
##   - a estação dela já foi construída (a mochila e a mesa de trabalho padrão valem
##     desde o começo); e
##   - todo ingrediente é alcançável: vem do mundo (não é feito em lugar nenhum), o
##     jogador já teve o item, ou alguma estação construída faz o item;
##   - receita de manual: só depois de ler o manual.

## [id, nome, objetos que liberam (vazio = desde o começo)]
const SECTIONS := [
	["mao", "Fabricar (mochila)", []],
	["mesa", "Mesa de trabalho", []],
	["campfire", "Fogueira", ["campfire"]],
	["rotisserie", "Assador giratório", ["rotisserie"]],
	["dryer", "Secador", ["dryer"]],
	["smoker", "Defumador", ["smoker"]],
	["filter", "Filtro", ["filter"]],
	["compost", "Composteira", ["compost"]],
	["quern", "Moinho manual", ["quern"]],
	["sieve", "Peneira", ["sieve"]],
	["spinning", "Roca", ["spinning"]],
	["loom", "Tear", ["loom"]],
	["fornalha", "Fornalha", ["furnace"]],
	["fornalha_pedra", "Fornalha de pedra", ["stone_furnace"]],
	["forno", "Forno de tijolo", ["oven"]],
	["forja", "Forja e bigorna", ["forge"]],
	["fundicao", "Fundição", ["foundry"]],
	["sawmill", "Serraria", ["sawmill"]],
	["alto_forno", "Alto-forno", ["blast_furnace"]],
	["torno", "Torno", ["lathe"]],
	["prensa", "Prensa", ["press"]],
	["trefiladora", "Trefiladora", ["wire_drawer"]],
	["destilaria", "Destilaria", ["distillery"]],
	["solda", "Bancada de solda", ["weld_bench"]],
	["macarico", "Bancada de maçarico", ["torch_bench"]],
	["quimica", "Bancada química", ["chem_bench"]],
]

static var _all: Array = []
static var _world: Dictionary = {}
## Vêm do mundo além das máquinas: coletor de chuva, lago/bomba.
const WORLD_EXTRA := [&"agua", &"agua_suja"]


## Todas as receitas (montado uma vez).
static func all() -> Array:
	if not _all.is_empty():
		return _all
	for r: Dictionary in CraftingUI.RECIPES:
		var notes: Array[String] = []
		if r.has("note"):
			notes.append(r.note)
		if r.get("fuel", false):
			notes.append("+ combustível")
		if r.get("heat", false):
			notes.append("fole quente")
		if r.get("power", false):
			notes.append("eixo girando")
		if r.has("water"):
			notes.append("+ água")
		if r.station == "forja" or r.station == "fundicao":
			notes.append("+ carvão")
		if r.station == "quimica":
			notes.append("+ combustível")
			match r.get("chem", {}).get("risk", ""):
				"boom":
					notes.append("explode se esquentar")
				"leak":
					notes.append("pressão demais vaza gás")
		_add(r.station, r.id, r.get("amount", 1), r.cost, ", ".join(notes), r.get("manual", ""))
		if r.has("chem"):
			_all.back().chem = r.chem # faixas do minigame da química (catálogo)
	for food in Cooking.COOK:
		_add("campfire", Cooking.COOK[food], 1, {food: 1}, "+ lenha")
		_add("rotisserie", Cooking.COOK[food], 1, {food: 1}, "+ lenha, eixo")
	for food in Cooking.DRY:
		_add("dryer", Cooking.DRY[food], 1, {food: 1}, "")
	for food in Cooking.SMOKE:
		_add("smoker", Cooking.SMOKE[food], 1, {food: 1}, "+ carvão")
	for item in Cooking.FILTER:
		_add("filter", Cooking.FILTER[item], 1, {item: 1}, "")
	for item in Cooking.COMPOST:
		_add("compost", Cooking.COMPOST[item], 1, {item: 1}, "")
	for kind in Machines.PROCESS:
		var p: Array = Machines.PROCESS[kind]
		var note := "%d%% de chance" % int(p[4] * 100.0) if p.size() > 4 and p[4] < 1.0 else ("eixo girando" if kind == "sawmill" else "")
		_add(kind, p[2], p[5] if p.size() > 5 else 1, {p[0]: p[1]}, note)
		if Machines.ALT_INPUT.has(kind):
			var alt: Array = Machines.ALT_INPUT[kind]
			_add(kind, p[2], 1, {alt[0]: maxi(1, p[1] / alt[1])}, "")
	return _all


static func _add(station: String, out: StringName, amount: int, cost: Dictionary, note: String, manual: Variant = "") -> void:
	var keys := cost.keys().map(func(k): return String(k))
	keys.sort()
	_all.append({"key": "%s|%s|%s" % [station, out, ",".join(keys)], "station": station, "out": out, "amount": amount,
		"cost": cost, "note": note, "manual": manual})


static func section_name(station: String) -> String:
	for s in SECTIONS:
		if s[0] == station:
			return s[1]
	return station


## A estação já existe? (construída por mim alguma vez ou de pé no mundo)
static func station_built(station: String, built: Dictionary) -> bool:
	for s in SECTIONS:
		if s[0] == station:
			if s[2].is_empty():
				return true
			for kind in s[2]:
				if built.has(kind):
					return true
			return false
	return false


## Tipos de objeto que contam como construídos: os que eu já pus + os que estão no mundo.
static func built_kinds() -> Dictionary:
	var built := {}
	if Progress.i:
		built.merge(Progress.i.built)
	var tree := Engine.get_main_loop() as SceneTree
	var world := tree.current_scene if tree else null
	var placed := world.get_node_or_null("Placed") as PlacedManager if world else null
	if placed:
		for obj: PlacedObject in placed.objects.values():
			if is_instance_valid(obj):
				built[obj.kind] = true
	return built


## Quem faz cada item: item -> [estações].
static func producers() -> Dictionary:
	var map := {}
	for r: Dictionary in all():
		if not map.has(r.out):
			map[r.out] = []
		if not r.station in map[r.out]:
			map[r.out].append(r.station)
	return map


## Itens que se acham no mundo (saque, recursos, caixote inicial e WORLD_EXTRA).
static func world_items() -> Dictionary:
	if _world.is_empty():
		for table in Loot.TABLES.values():
			for row in table:
				_world[row[0]] = true
		for rows in Loot.FIXED.values():
			for row in rows:
				_world[row[0]] = true
		for row in Loot.START:
			_world[row[0]] = true
		for id in WORLD_EXTRA:
			_world[id] = true
	return _world


## O ingrediente dá para conseguir? (do mundo, já teve, ou uma estação construída faz)
static func reachable(item: StringName, built: Dictionary, seen: Dictionary, makers: Dictionary) -> bool:
	if seen.has(item) or not makers.has(item) or world_items().has(item):
		return true
	for station in makers[item]:
		if station_built(station, built):
			return true
	return false


## Receitas que o diário mostra agora.
static func visible() -> Array:
	var built := built_kinds()
	var seen: Dictionary = Progress.i.recipes if Progress.i else {}
	var makers := producers()
	var list := []
	for r: Dictionary in all():
		if not station_built(r.station, built) or not Progress.knows(r.manual):
			continue
		var ok := true
		for item in r.cost:
			if not reachable(item, built, seen, makers):
				ok = false
				break
		if ok:
			list.append(r)
	return list
