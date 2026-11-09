class_name Cooking
extends RefCounted
## Grelha da fogueira (3 lugares) e varal do secador (4 lugares). Segure comida crua e aperte [E] para pôr na
## grelha; fica pronta em COOK_TIME segundos (a comida muda de cor). Esqueceu
## lá (BURN_TIME depois de pronta): vira carvão. [E] pega o que estiver pronto.
## A comida assada enche bem mais a fome.

const COOK := {&"batata": &"batata_assada", &"cenoura": &"cenoura_assada", &"abobora": &"abobora_assada",
	&"lata": &"lata_quente", &"pao": &"torrada", &"argila": &"tijolo", &"carne_crua": &"carne_assada",
	&"camarao": &"camarao_assado", &"lagosta": &"lagosta_assada", &"caranguejo": &"caranguejo_assado",
	&"caranguejo_aranha": &"caranguejo_aranha_assado", &"atum": &"atum_assado", &"baixo": &"baixo_assado",
	&"ovo": &"ovo_frito"}
const COOK_TIME := 20.0
const BURN_TIME := 60.0
const NO_BURN := [&"argila"] ## tijolo não queima: pode esquecer no fogo
## Secador: peixe e frutos do lago viram peixe seco (enche bem e dura mais).
const DRY := {&"camarao": &"peixe_seco", &"lagosta": &"peixe_seco", &"caranguejo": &"peixe_seco",
	&"caranguejo_aranha": &"peixe_seco", &"atum": &"peixe_seco", &"baixo": &"peixe_seco",
	&"carne_crua": &"carne_seca", &"pele": &"couro"}
const DRY_TIME := 90.0
## Filtro de areia e carvão: água suja vira potável.
const FILTER := {&"agua_suja": &"agua"}
## Defumador: peixe cru vira defumado (nunca estraga).
const SMOKE := {&"camarao": &"peixe_defumado", &"lagosta": &"peixe_defumado", &"caranguejo": &"peixe_defumado",
	&"caranguejo_aranha": &"peixe_defumado", &"atum": &"peixe_defumado", &"baixo": &"peixe_defumado",
	&"carne_crua": &"carne_seca"}
## Composteira: restos e comida estragada viram adubo.
const COMPOST := {&"comida_estragada": &"adubo", &"cenoura": &"adubo", &"batata": &"adubo", &"abobora": &"adubo",
	&"fruta": &"adubo", &"trigo": &"adubo"}
const KINDS := ["campfire", "dryer", "filter", "smoker", "compost", "rotisserie"]
const WAIT_TIME := {"dryer": DRY_TIME, "filter": 20.0, "smoker": 60.0, "compost": 120.0}
## Defumador: 1 carvão defuma 4 peças (3 carvões = 2 rodadas de 6).
const SMOKE_PER_COAL := 4
const LABELS := {"campfire": ["Assando", "da grelha", "Fogueira"], "dryer": ["Secando", "do varal", "Secador"],
	"filter": ["Filtrando", "do filtro", "Filtro de água"], "smoker": ["Defumando", "do defumador", "Defumador"],
	"compost": ["Compostando", "da composteira", "Composteira"], "rotisserie": ["Assando", "do espeto", "Assador giratório"]}
## Queimam lenha (a fogueira e o assador giratório, que é uma fogueira com espeto no eixo).
const FIRES := ["campfire", "rotisserie"]

## Fogueiras (os zumbis não chegam perto das acesas à noite).
static var fires: Array = []
## Lenha da fogueira: segundos de fogo por item (1 tronco = 15 min).
const FIREWOOD := {&"tronco": 900.0, &"carvao": 600.0, &"tabua": 240.0, &"gordura": 180.0, &"graveto": 60.0}


static func table(kind: String) -> Dictionary:
	return {"dryer": DRY, "filter": FILTER, "smoker": SMOKE, "compost": COMPOST}.get(kind, COOK)


## O que vai na grelha/varal: cada entrada guarda o próprio tempo, se queima e no que vira.
static func make_entry(kind: String, food: StringName, clock: float) -> Dictionary:
	if WAIT_TIME.has(kind):
		return {"food": food, "t": clock, "cook": WAIT_TIME[kind], "burn": false, "into": table(kind)[food],
			"hang": kind in ["dryer", "smoker"], "small": kind == "smoker"}
	# Assador giratório: o espeto fica girando a comida pronta, então não queima.
	return {"food": food, "t": clock, "cook": COOK_TIME, "burn": food not in NO_BURN and kind != "rotisserie", "into": COOK[food]}


## Fogueira mais perto (até "radius") ou Vector3.INF.
static func nearest_fire(at: Vector3, radius: float) -> Vector3:
	var best := Vector3.INF
	for fire in fires:
		if is_instance_valid(fire) and fire.is_lit() and fire.global_position.distance_to(at) < radius \
				and (best == Vector3.INF or fire.global_position.distance_to(at) < best.distance_to(at)):
			best = fire.global_position
	return best


## 0 = cru, 1 = pronto, 2 = queimado, -1 = vazio.
static func stage(entry: Dictionary, clock: float) -> int:
	if entry.is_empty():
		return -1
	var t: float = clock - entry.t
	var cook: float = entry.get("cook", COOK_TIME)
	if entry.get("burn", true) and t >= cook + BURN_TIME:
		return 2
	return 1 if t >= cook else 0


static func result_of(entry: Dictionary, clock: float) -> StringName:
	match stage(entry, clock):
		1:
			return entry.get("into", COOK.get(entry.food, &"carvao"))
		2:
			return &"carvao"
	return &""


static func model(entry: Dictionary, clock: float) -> Node3D:
	var st := stage(entry, clock)
	var id: StringName = entry.food if st == 0 else result_of(entry, clock)
	var node := ItemModels.build(id)
	node.rotation.y = PI / 2
	if entry.get("hang", false):
		node.rotation = Vector3(PI / 2, 0, 0) # pendurado (secador, defumador)
		# Cabe dentro do armário do defumador: no máximo ~25 cm, pendurado pela ponta.
		var reach: float = ItemDB.def(id).size.z
		var fit := minf(1.0, 0.25 / maxf(reach, 0.01)) if entry.get("small", false) else 1.0
		node.scale = Vector3.ONE * fit
		node.position.y = -reach * fit * 0.5
	return node


static func text(obj: PlacedObject, clock: float) -> String:
	var ready := 0
	var cooking := []
	var label: Array = LABELS.get(obj.kind, LABELS.campfire)
	for entry in obj.crops:
		var st := stage(entry, clock)
		if st >= 1:
			ready += 1
		elif st == 0:
			cooking.append("%s %d%%" % [ItemDB.display_name(entry.food), (clock - entry.t) / entry.get("cook", COOK_TIME) * 100.0])
	if obj.kind in FIRES:
		var left: float = obj.extra.get("fuel_until", 0.0) - clock
		var name := "Fogueira" if obj.kind == "campfire" else "Assador giratório"
		if left <= 0.0:
			return "%s apagad%s  [E] acender (lenha)" % [name, "a" if obj.kind == "campfire" else "o"]
		label = [label[0], label[1], "%s aces%s (%d min)" % [name, "a" if obj.kind == "campfire" else "o", ceili(left / 60.0)]]
		if obj.kind == "rotisserie" and obj.extra.get("pstate", "") != "ok":
			label[2] += " · espeto parado (precisa de força no eixo para assar sem queimar)"
	if ready > 0:
		return "[E] Tirar %s (%d pronto%s)" % [label[1], ready, "s" if ready > 1 else ""]
	if not cooking.is_empty():
		return label[0] + ": " + " · ".join(cooking)
	return label[2]


static func interact(player: Player, obj: PlacedObject) -> void:
	var manager := obj.get_parent() as PlacedManager
	var took := false
	for i in obj.crops.size():
		if stage(obj.crops[i], manager.clock) >= 1:
			ItemFly.play(result_of(obj.crops[i], manager.clock), obj.slot_world(i), player)
			manager.request("take_cooked", [obj.net_id, i])
			took = true
	if took:
		return
	# Fogueira: lenha na mão (ou, apagada, de qualquer lugar da mochila) alimenta o fogo.
	if obj.kind in FIRES:
		var held := player.inventory.selected_id()
		var wood_index := player.inventory.selected if FIREWOOD.has(held) else -1
		if wood_index < 0 and not obj.is_lit():
			for wood in [&"tronco", &"carvao", &"tabua", &"graveto"]:
				wood_index = find_any(player.inventory, {wood: true})
				if wood_index >= 0:
					break
		if wood_index >= 0:
			var wood_id: StringName = player.inventory.slots[wood_index].id
			player.inventory.take(wood_index, 1)
			manager.request("fuel", [obj.net_id, FIREWOOD[wood_id], "fuel_until"])
			Sfx.play_at("knock", obj.global_position + Vector3.UP * 0.3, 0.0, 0.7)
			return
		if not obj.is_lit():
			Sfx.play("click", -6.0, 0.6) # apagada e sem lenha
			return
	# Grelha: o que está na mão. As outras (filtro, secador, defumador, composteira)
	# puxam o que servir de qualquer lugar da mochila e enchem todos os lugares livres.
	var accepted := table(obj.kind)
	if obj.kind == "rotisserie" and obj.extra.get("pstate", "") != "ok":
		Sfx.play("click", -6.0, 0.6) # espeto sem força: não gira, não assa
		return
	var put := 0
	var charge: int = obj.extra.get("charge", 0)
	for i in obj.crops.size():
		if not obj.crops[i].is_empty():
			continue
		var index := player.inventory.selected
		if not obj.kind in FIRES and not accepted.has(player.inventory.selected_id()):
			index = find_any(player.inventory, accepted)
		if index < 0 or player.inventory.slots[index].is_empty() or not accepted.has(player.inventory.slots[index].id):
			break
		var coal := false
		if obj.kind == "smoker" and charge <= 0:
			var coal_index := find_any(player.inventory, {&"carvao": true})
			if coal_index < 0:
				break # defumador sem carvão
			player.inventory.take(coal_index, 1)
			charge += SMOKE_PER_COAL
			coal = true
		var id: StringName = player.inventory.slots[index].id
		player.inventory.take(index, 1)
		manager.request("cook", [obj.net_id, i, String(id), coal])
		charge -= 1 if obj.kind == "smoker" else 0
		put += 1
		if obj.kind in FIRES:
			break # grelha/espeto: um por toque, como antes
	if put > 0:
		Sfx.play_at("slap", obj.global_position + Vector3.UP * 0.6, -4.0, 0.6)
	else:
		Sfx.play("click", -6.0, 0.6)


## Primeiro slot da mochila com algum item de "ids" (dicionário id -> qualquer coisa). -1 = nenhum.
static func find_any(inventory: Inventory, ids: Dictionary) -> int:
	for i in inventory.slots.size():
		if not inventory.slots[i].is_empty() and ids.has(inventory.slots[i].id):
			return i
	return -1
