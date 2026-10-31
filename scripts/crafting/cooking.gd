class_name Cooking
extends RefCounted
## Grelha da fogueira: 3 lugares. Segure comida crua e aperte [E] para pôr na
## grelha; fica pronta em COOK_TIME segundos (a comida muda de cor). Esqueceu
## lá (BURN_TIME depois de pronta): vira carvão. [E] pega o que estiver pronto.
## A comida assada enche bem mais a fome.

const COOK := {&"batata": &"batata_assada", &"cenoura": &"cenoura_assada", &"abobora": &"abobora_assada",
	&"lata": &"lata_quente", &"pao": &"torrada"}
const COOK_TIME := 20.0
const BURN_TIME := 60.0


## 0 = cru, 1 = pronto, 2 = queimado, -1 = vazio.
static func stage(entry: Dictionary, clock: float) -> int:
	if entry.is_empty():
		return -1
	var t: float = clock - entry.t
	return 2 if t >= COOK_TIME + BURN_TIME else (1 if t >= COOK_TIME else 0)


static func result_of(entry: Dictionary, clock: float) -> StringName:
	match stage(entry, clock):
		1:
			return COOK[entry.food]
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
	for entry in obj.crops:
		var st := stage(entry, clock)
		if st >= 1:
			ready += 1
		elif st == 0:
			cooking.append("%s %d%%" % [ItemDB.display_name(entry.food), (clock - entry.t) / COOK_TIME * 100.0])
	if ready > 0:
		return "[E] Tirar da grelha (%d pronto%s)" % [ready, "s" if ready > 1 else ""]
	if not cooking.is_empty():
		return "Assando: " + " · ".join(cooking) + "   [E] pôr mais"
	return "[E] Pôr na grelha (segure batata, cenoura, abóbora, enlatado ou pão)"


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
	if not COOK.has(id):
		player.notify.emit("Segure comida crua na mão (batata, cenoura, abóbora, enlatado, pão)")
		return
	for i in obj.crops.size():
		if obj.crops[i].is_empty():
			player.inventory.take(player.inventory.selected, 1)
			manager.request("cook", [obj.net_id, i, String(id)])
			Sfx.play_at("slap", obj.global_position + Vector3.UP * 0.6, -4.0, 0.6)
			return
	player.notify.emit("A grelha está cheia")
