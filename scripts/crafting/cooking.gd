class_name Cooking
extends RefCounted
## Grelha da fogueira (3 lugares) e varal do secador (4 lugares). Segure comida crua e aperte [E] para pôr na
## grelha; fica pronta em COOK_TIME segundos (a comida muda de cor). Esqueceu
## lá (BURN_TIME depois de pronta): vira carvão. [E] pega o que estiver pronto.
## A comida assada enche bem mais a fome.

const COOK := {&"batata": &"batata_assada", &"cenoura": &"cenoura_assada", &"abobora": &"abobora_assada",
	&"lata": &"lata_quente", &"pao": &"torrada", &"argila": &"tijolo",
	&"camarao": &"camarao_assado", &"lagosta": &"lagosta_assada", &"caranguejo": &"caranguejo_assado",
	&"caranguejo_aranha": &"caranguejo_aranha_assado", &"atum": &"atum_assado", &"baixo": &"baixo_assado"}
const COOK_TIME := 20.0
const BURN_TIME := 60.0
const NO_BURN := [&"argila"] ## tijolo não queima: pode esquecer no fogo
## Secador: peixe e frutos do lago viram peixe seco (enche bem e dura mais).
const DRY := {&"camarao": &"peixe_seco", &"lagosta": &"peixe_seco", &"caranguejo": &"peixe_seco",
	&"caranguejo_aranha": &"peixe_seco", &"atum": &"peixe_seco", &"baixo": &"peixe_seco"}
const DRY_TIME := 90.0

## Fogueiras acesas (os zumbis não chegam perto delas à noite).
static var fires: Array = []


static func table(kind: String) -> Dictionary:
	return DRY if kind == "dryer" else COOK


## O que vai na grelha/varal: cada entrada guarda o próprio tempo, se queima e no que vira.
static func make_entry(kind: String, food: StringName, clock: float) -> Dictionary:
	if kind == "dryer":
		return {"food": food, "t": clock, "cook": DRY_TIME, "burn": false, "into": DRY[food]}
	return {"food": food, "t": clock, "cook": COOK_TIME, "burn": food not in NO_BURN, "into": COOK[food]}


## Fogueira mais perto (até "radius") ou Vector3.INF.
static func nearest_fire(at: Vector3, radius: float) -> Vector3:
	var best := Vector3.INF
	for fire in fires:
		if is_instance_valid(fire) and fire.global_position.distance_to(at) < radius \
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
	return node


static func text(obj: PlacedObject, clock: float) -> String:
	var ready := 0
	var cooking := []
	var dryer := obj.kind == "dryer"
	for entry in obj.crops:
		var st := stage(entry, clock)
		if st >= 1:
			ready += 1
		elif st == 0:
			cooking.append("%s %d%%" % [ItemDB.display_name(entry.food), (clock - entry.t) / entry.get("cook", COOK_TIME) * 100.0])
	if ready > 0:
		return "[E] Tirar %s (%d pronto%s)" % ["do varal" if dryer else "da grelha", ready, "s" if ready > 1 else ""]
	if not cooking.is_empty():
		return ("Secando: " if dryer else "Assando: ") + " · ".join(cooking)
	return "Secador" if dryer else "Fogueira"


static func interact(player: Player, obj: PlacedObject) -> void:
	var manager := obj.get_parent() as PlacedManager
	var took := false
	for i in obj.crops.size():
		if stage(obj.crops[i], manager.clock) >= 1:
			manager.request("take_cooked", [obj.net_id, i])
			took = true
	if took:
		return
	var id := player.inventory.selected_id()
	if not table(obj.kind).has(id):
		Sfx.play("click", -6.0, 0.6)
		return
	for i in obj.crops.size():
		if obj.crops[i].is_empty():
			player.inventory.take(player.inventory.selected, 1)
			manager.request("cook", [obj.net_id, i, String(id)])
			Sfx.play_at("slap", obj.global_position + Vector3.UP * 0.6, -4.0, 0.6)
			return
	Sfx.play("click", -6.0, 0.6)
