extends SceneTree
## Chapas da bancada de solda e construção de chapa (parede, porta, save, conserto),
## bancada de maçarico (combustível: álcool/óleo/botijão; solda de cobre com estanho).

var main: Node3D
var player: Player
var placed: PlacedManager
var building: BuildingManager


func _spawn(kind: String, pos: Vector3) -> PlacedObject:
	var id: int = placed._next_id
	placed._spawn(id, kind, Transform3D(Basis(), pos))
	return placed.objects[id]


func _weld(game: WeldingMinigame, speed: float) -> void:
	game.manual_input = false
	var dt := 1.0 / 60.0
	var guard := 0
	while game._result <= -2.0 and guard < 20000:
		guard += 1
		game.drive(game.point_at(game.front + speed * dt), true, dt)


func _until(done: Callable) -> void:
	var start := Time.get_ticks_msec()
	while not done.call() and Time.get_ticks_msec() - start < 5000:
		await process_frame


func _make(obj: PlacedObject, recipe: Dictionary, mode: String, speed: float) -> float:
	var got := []
	var game := Minigame.play(player, "welding", {"item": recipe.id, "seams": recipe.get("seams", 1), "mode": mode}, func(q: float): got.append(q)) as WeldingMinigame
	await process_frame
	_weld(game, speed)
	await _until(func(): return not got.is_empty())
	placed.host_apply("smith_done", [obj.net_id, CraftingUI.RECIPES.find(recipe), got[0]])
	return got[0]


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	player = main.player
	placed = main.get_node("Placed")
	building = main.get_node("Building")
	Progress.i.manuals[&"manual_soldagem"] = true
	var at := player.global_position + Vector3(4, 0, -4)
	# --- Chapas na bancada de solda.
	var bench := _spawn("weld_bench", at)
	var battery := _spawn("battery", at + Vector3(0, 0, 2))
	battery.extra.cells = 4
	battery.extra.charge = 800.0
	placed.host_apply("cable", [battery.net_id, bench.net_id])
	placed._electric()
	var key := Smelting.key_of(bench)
	ContainerManager.i.host_apply("open", [key, ""])
	var slots: Array = ContainerManager.i.contents[key]
	slots[Smelting.INPUT] = {"id": &"barra_ferro", "amount": 3}
	slots[Smelting.FUEL] = {"id": &"eletrodo", "amount": 1}
	var chapa: Dictionary = CraftingUI.RECIPES.filter(func(r): return r.id == &"chapa")[0]
	print("chapa: falta '%s'" % Smithing.missing(chapa, slots, bench))
	var q := await _make(bench, chapa, "arc", 80.0)
	print("chapa soldada: qualidade %.2f -> %s; sobrou ferro %s eletrodo %s" % [q, slots[Smelting.OUTPUT], slots[0], slots[1]])
	# --- Construção de chapa.
	var cell := Vector3i(40, 0, 40)
	var wood := building.host_apply("place", [BuildPiece.Kind.WALL, cell, 0])
	var steel := building.host_apply("place", [BuildPiece.Kind.WALL, cell + Vector3i(7, 0, 0), 0, true])
	var roof := building.host_apply("place", [BuildPiece.Kind.ROOF, cell + Vector3i(7, 7, 0), 0, true])
	var wall: BuildPiece = building.pieces[steel[0]]
	print("parede de madeira metal=%s; de chapa metal=%s (resposta %s); telhado de chapa metal=%s" % [building.pieces[wood[0]].metal, wall.metal, steel, building.pieces[roof[0]].metal])
	print("golpes de zumbi por quadrado: madeira %d, chapa %d; custo: parede de chapa %s, porta de chapa %s; conserto de 10 pedaços: madeira %s, chapa %s" % [
		BuildPiece.HITS, BuildPiece.METAL_HITS, Builder.entry_for_kind(BuildPiece.Kind.WALL, true).cost, Builder.entry_for_fill("door", true).cost,
		Builder.repair_cost(_damaged(building.pieces[wood[0]], 10)), Builder.repair_cost(_damaged(wall, 10))])
	# Porta de chapa num buraco que encosta no chão.
	var tris := PackedInt32Array()
	for j in range(0, 5):
		for i in range(2, 4):
			for qq in 4:
				tris.append((j * BuildPiece.N + i) * 4 + qq)
	building.host_apply("cut_many", [steel[0], tris])
	var fill := building.host_apply("fill", [steel[0], "door", tris, true])
	await process_frame
	var node: BuildFill = null
	for child in wall.get_children():
		if child is BuildFill:
			node = child
	print("porta de chapa: aceita=%s, metal=%s, texto '%s'" % [not fill.is_empty(), node.metal if node else "?", node.get_interact_text() if node else "?"])
	# Save: a peça e a porta voltam de chapa.
	var state := building.state()
	var entry: Array = state.filter(func(e): return e[0] == steel[0])[0]
	for id in building.pieces.keys():
		building._remove(id)
	building.load_state(state)
	var back: BuildPiece = building.pieces[steel[0]]
	print("save/load: parede metal=%s, porta metal=%s (estado guarda metal=%s)" % [back.metal, back.fills[0].get("metal", false), entry[7]])
	# --- Bancada de maçarico.
	var torch := _spawn("torch_bench", at + Vector3(4, 0, 0))
	var tkey := Smelting.key_of(torch)
	ContainerManager.i.host_apply("open", [tkey, ""])
	var tslots: Array = ContainerManager.i.contents[tkey]
	print("maçarico: %d lugares; aceita cobre=%s cano=%s estanho na solda=%s cobre na solda=%s vidro no 5º=%s álcool=%s óleo=%s botijão=%s carvão=%s" % [
		tslots.size(), Smelting.accepts(0, &"barra_cobre", "torch_bench"), Smelting.accepts(0, &"cano", "torch_bench"),
		Smelting.accepts(3, &"barra_estanho", "torch_bench"), Smelting.accepts(3, &"barra_cobre", "torch_bench"), Smelting.accepts(4, &"vidro", "torch_bench"),
		Smelting.accepts(1, &"alcool", "torch_bench"), Smelting.accepts(1, &"oleo", "torch_bench"), Smelting.accepts(1, &"botijao", "torch_bench"),
		Smelting.accepts(1, &"carvao", "torch_bench")])
	var serp: Dictionary = CraftingUI.RECIPES.filter(func(r): return r.id == &"serpentina")[0]
	tslots[Smelting.INPUT] = {"id": &"cano", "amount": 6}
	tslots[Smithing.ALLOY] = {"id": &"barra_estanho", "amount": 2}
	print("serpentina sem combustível: '%s'" % Smithing.missing(serp, tslots, torch))
	tslots[Smelting.FUEL] = {"id": &"botijao", "amount": 1}
	q = await _make(torch, serp, "brazing", 60.0)
	print("serpentina (60 px/s): qualidade %.2f -> %s; botijão %s, gás sobrando para %d soldas" % [q, tslots[Smelting.OUTPUT], tslots[1], int(torch.extra.get("gas", 0))])
	tslots[Smelting.OUTPUT] = {}
	q = await _make(torch, serp, "brazing", 130.0)
	print("serpentina com pressa (130 px/s): qualidade %.2f -> %s; gás para %d soldas; texto '%s'" % [q, tslots[Smelting.OUTPUT], int(torch.extra.get("gas", 0)), Smithing.text(torch)])
	# Célula com álcool: 1 solda por álcool.
	var cel: Dictionary = CraftingUI.RECIPES.filter(func(r): return r.id == &"celula" and r.station == "macarico")[0]
	torch.extra.gas = 0.0
	tslots[Smelting.OUTPUT] = {}
	tslots[Smelting.INPUT] = {"id": &"barra_cobre", "amount": 1}
	tslots[Smithing.ALLOY] = {"id": &"barra_estanho", "amount": 1}
	tslots[Smithing.EXTRA_SLOT] = {"id": &"vidro", "amount": 2}
	tslots[Smelting.FUEL] = {"id": &"alcool", "amount": 1}
	print("célula: falta '%s'" % Smithing.missing(cel, tslots, torch))
	q = await _make(torch, cel, "brazing", 60.0)
	print("célula a álcool: qualidade %.2f -> %s; álcool sobrando %s" % [q, tslots[Smelting.OUTPUT], tslots[1]])
	print("receitas do maçarico: %s" % [Smithing.recipes("macarico").map(func(e): return String(e[1].id))])
	quit()


func _damaged(piece: BuildPiece, count: int) -> BuildPiece:
	piece.damaged.clear()
	for k in count:
		piece.damaged[k] = true
	return piece
