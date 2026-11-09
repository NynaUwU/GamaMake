extends SceneTree
## Fase 2 das eras: estanho no mundo, bronze na fundição (minigame de despejar jogado
## por "fundidores" automáticos: bom, afobado, lento e que desiste no meio), bancada
## de solda elétrica (minigame de seguir a junta: soldador bom, apressado e parado),
## armadura soldada com qualidade e a conquista do bronze.

var main: Node3D
var player: Player
var placed: PlacedManager


func _spawn(kind: String, pos: Vector3) -> PlacedObject:
	var id: int = placed._next_id
	placed._spawn(id, kind, Transform3D(Basis(), pos))
	return placed.objects[id]


## Fundidor: "good" segura a vazão no meio da faixa; "fast" vira tudo; "slow" fica na
## borda; "quit" para no meio e espera o metal endurecer.
func _cast(game: CastingMinigame, style: String) -> void:
	game.manual_input = false
	var dt := 1.0 / 30.0
	var guard := 0
	while game._result <= -2.0 and guard < 4000:
		guard += 1
		match style:
			"good":
				game.target_tilt = game.lip_angle() + 7.5 if game.fill < 0.975 else 0.0
			"fast":
				game.target_tilt = 120.0 if game.fill < 0.99 else 0.0
			"slow":
				game.target_tilt = game.lip_angle() + 1.2 if game.fill < 0.975 else 0.0
			"quit":
				game.target_tilt = game.lip_angle() + 7.5 if game.fill < 0.6 else 0.0
		game.step(dt)


## Soldador: anda pela junta a "speed" px/s; "wait" segundos parado no começo.
func _weld(game: WeldingMinigame, speed: float, wait := 0.0) -> void:
	game.manual_input = false
	var dt := 1.0 / 60.0
	var guard := 0
	while game._result <= -2.0 and guard < 20000:
		guard += 1
		if wait > 0.0:
			wait -= dt
			game.drive(game.point_at(game.front), true, dt)
			continue
		game.drive(game.point_at(game.front + speed * dt), true, dt)


func _until(done: Callable) -> void:
	var start := Time.get_ticks_msec()
	while not done.call() and Time.get_ticks_msec() - start < 5000:
		await process_frame


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	player = main.player
	placed = main.get_node("Placed")
	# --- Estanho no mundo.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tin_c := 0
	var tin_i := 0
	for k in 2000:
		var x := rng.randf_range(-3000, 3000)
		var z := rng.randf_range(-3000, 3000)
		tin_c += 1 if TerrainProps._tin("ore_copper", x, z) == "ore_tin" else 0
		tin_i += 1 if TerrainProps._tin("ore_iron", x, z) == "ore_tin" else 0
	print("estanho: %d%% dos veios de cobre, %d%% dos de ferro; árvore continua árvore=%s; veio dá %s; fornalha funde=%s" % [tin_c / 20, tin_i / 20,
		TerrainProps._tin("tree", 1, 2) == "tree", Loot.roll("estanho"), not Smelting.recipe("furnace", &"minerio_estanho").is_empty()])
	# --- Fundição: bronze.
	var at := player.global_position + Vector3(4, 0, -4)
	var foundry := _spawn("foundry", at)
	var key := Smelting.key_of(foundry)
	ContainerManager.i.host_apply("open", [key, ""])
	var slots: Array = ContainerManager.i.contents[key]
	print("fundição: %d lugares; aceita cobre=%s estanho na liga=%s ferro=%s carvão no fogo=%s" % [slots.size(), Smelting.accepts(0, &"barra_cobre", "foundry"),
		Smelting.accepts(3, &"barra_estanho", "foundry"), Smelting.accepts(0, &"barra_ferro", "foundry"), Smelting.accepts(1, &"carvao", "foundry")])
	var bronze: Dictionary = CraftingUI.RECIPES.filter(func(r): return r.id == &"barra_bronze")[0]
	var index := CraftingUI.RECIPES.find(bronze)
	print("bronze sem material: '%s'" % Smithing.missing(bronze, slots, foundry))
	var results := {}
	for style in ["good", "fast", "slow", "quit"]:
		slots[Smelting.INPUT] = {"id": &"barra_cobre", "amount": 3}
		slots[Smithing.ALLOY] = {"id": &"barra_estanho", "amount": 1}
		slots[Smelting.FUEL] = {"id": &"carvao", "amount": 1}
		slots[Smelting.OUTPUT] = {}
		var got := []
		var game := Minigame.play(player, "casting", {"item": &"barra_bronze", "metal": &"barra_bronze", "mold": "ingot"}, func(q: float): got.append(q)) as CastingMinigame
		await process_frame
		_cast(game, style)
		var info := "vazão boa %.0f%% do tempo, espirrou %.0f%%, transbordou %.0f%%, emendas frias %d, molde %.0f%%" % [
			100.0 * game.band_time / maxf(game.pour_time, 0.01), game.spill * 100.0, game.overflow * 100.0, game.cold_shuts, game.fill * 100.0]
		await _until(func(): return not got.is_empty())
		placed.host_apply("smith_done", [foundry.net_id, index, got[0]])
		results[style] = [got[0], slots[Smelting.OUTPUT].duplicate(), info]
	for style in results:
		print("fundidor %s: qualidade %.2f -> %s (%s)" % [style, results[style][0], results[style][1], results[style][2]])
	print("sobrou nos lugares: metal %s, liga %s, carvão %s" % [slots[0], slots[3], slots[1]])
	print("conquista do bronze: %s, era %d" % [Progress.i.done.has("bronze"), Progress.i.era])
	# --- Bancada de solda.
	var bench := _spawn("weld_bench", at + Vector3(4, 0, 0))
	var bkey := Smelting.key_of(bench)
	ContainerManager.i.host_apply("open", [bkey, ""])
	var bslots: Array = ContainerManager.i.contents[bkey]
	var couraca: Dictionary = CraftingUI.RECIPES.filter(func(r): return r.id == &"couraca")[0]
	var cindex := CraftingUI.RECIPES.find(couraca)
	bslots[Smelting.INPUT] = {"id": &"barra_aco", "amount": 12}
	bslots[Smelting.FUEL] = {"id": &"eletrodo", "amount": 9}
	print("solda sem manual: '%s'" % Smithing.missing(couraca, bslots, bench))
	Progress.i.manuals[&"manual_soldagem"] = true
	print("solda com manual, sem energia: '%s'; aceita aço=%s eletrodo no 2º=%s carvão=%s" % [Smithing.missing(couraca, bslots, bench),
		Smelting.accepts(0, &"barra_aco", "weld_bench"), Smelting.accepts(1, &"eletrodo", "weld_bench"), Smelting.accepts(1, &"carvao", "weld_bench")])
	var battery := _spawn("battery", at + Vector3(4, 0, 2))
	battery.extra.cells = 4
	battery.extra.charge = 800.0
	placed.host_apply("cable", [battery.net_id, bench.net_id])
	for k in 2:
		placed._electric()
	print("bancada na bateria: com energia=%s (consumo %d W), falta '%s'" % [Electric.powered(bench), int(Electric.DEMAND["weld_bench"]), Smithing.missing(couraca, bslots, bench)])
	for style in [["bom", 80.0, 0.0], ["apressado", 230.0, 0.0], ["parado", 80.0, 2.0]]:
		bslots[Smelting.OUTPUT] = {}
		var got := []
		var game := Minigame.play(player, "welding", {"item": &"couraca", "seams": 3}, func(q: float): got.append(q)) as WeldingMinigame
		await process_frame
		_weld(game, style[1], style[2])
		var info := "pedaços %d, furos %d" % [game.scores.size(), game.burns]
		await _until(func(): return not got.is_empty())
		placed.host_apply("smith_done", [bench.net_id, cindex, got[0]])
		print("soldador %s (%d px/s): qualidade %.2f (%s) -> %s" % [style[0], style[1], got[0], info, bslots[Smelting.OUTPUT]])
	print("sobrou: aço %s, eletrodos %s; bancada com faísca=%s" % [bslots[0].get("amount", 0), bslots[1].get("amount", 0), bench.is_lit(placed.clock)])
	# Proteção da couraça pela qualidade.
	for q in [0.3, 1.0]:
		player.inventory.equipment["body"] = {"id": &"couraca", "amount": 1, "q": q}
		print("couraça q=%.1f: proteção total %.0f%%" % [q, player.inventory.armor() * 100.0])
	player.inventory.equipment["body"] = {}
	print("conquistas: fundido=%s solda=%s; receitas da fundição %d, da solda %d" % [Progress.i.done.has("fundido"), Progress.i.done.has("solda"),
		Smithing.recipes("fundicao").size(), Smithing.recipes("solda").size()])
	quit()
