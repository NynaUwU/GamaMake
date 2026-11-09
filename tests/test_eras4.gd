extends SceneTree
## Fase 4 (química e refino): itens e receitas, bancada química (lugares, combustível,
## garrafa que volta, qualidade), minigame das válvulas (controle bom = qualidade alta;
## pólvora quente explode; ácido com pressão vaza gás), revólver gastando cartuchos,
## ácido renovando a bateria, biodiesel no carro, enxofre no terreno, zonas contaminadas
## (gás, intoxicação, máscara com filtro e troca de filtro) e save/load.

var main: Node3D
var player: Player
var placed: PlacedManager


func _spawn(kind: String, pos: Vector3) -> PlacedObject:
	var id: int = placed._next_id
	placed._spawn(id, kind, Transform3D(Basis(), pos))
	return placed.objects[id]


func _recipe(id: StringName, station := "quimica") -> Dictionary:
	return CraftingUI.RECIPES.filter(func(r): return r.id == id and r.station == station)[0]


## Joga o minigame com um controle proporcional simples nas três válvulas.
func _play_chem(recipe: Dictionary, calm := true, greedy := false) -> Array:
	var game: ChemistryMinigame = load("res://scenes/minigames/chemistry.tscn").instantiate()
	game.context = {"item": recipe.id, "chem": recipe.chem, "amount": recipe.get("amount", 1)}
	game.manual_input = false
	game.calm = calm
	get_root().add_child(game)
	var dt := 1.0 / 30.0
	var mids := []
	for k in 3:
		mids.append((game.bands[k].x + game.bands[k].y) * 0.5)
	var guard := 0
	while game._result <= -2.0 and guard < 30 * 120:
		guard += 1
		if greedy:
			game.valves = [1.0, 0.0, 0.3] # chama no máximo, sem alívio
		else:
			game.turn(0, (mids[0] - game.values[0]) * 1.2 * dt)
			game.turn(1, (game.values[1] - mids[1]) * 1.5 * dt) # pressão alta: abre o alívio
			game.turn(2, (mids[2] - game.values[2]) * 1.5 * dt)
		game.step(dt)
	var result := [game._result, game.progress, game.stress, guard * dt]
	game.queue_free()
	return result


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	player = main.player
	placed = main.get_node("Placed")
	for e in main.get_node("Enemies").get_children():
		e.free()
	# --- Catálogo.
	var news := [&"enxofre", &"salitre", &"polvora", &"cartucho", &"combustivel", &"plastico", &"acido", &"carvao_ativado", &"filtro", &"mascara_gas", &"manual_quimico"]
	var models := news.filter(func(id): var n := ItemModels.build(id); var ok := n.get_child_count() > 0; n.free(); return ok)
	print("itens novos: %d (com modelo: %d) %s" % [news.filter(func(id): return ItemDB.has(id)).size(), models.size(), news])
	var chem := CraftingUI.RECIPES.filter(func(r): return r.station == "quimica")
	print("receitas da bancada química: %s" % [chem.map(func(r): return "%s x%d" % [r.id, r.get("amount", 1)])])
	print("mesa (manual de química): %s" % [CraftingUI.RECIPES.filter(func(r): return r.get("manual", "") == &"manual_quimico" and r.station == "mesa").map(func(r): return String(r.id))])
	print("diário: seção '%s', estação construída antes? %s" % [RecipeBook.section_name("quimica"), RecipeBook.station_built("quimica", RecipeBook.built_kinds())])
	# --- Minigame: controle bom em todas as receitas; e com imprevistos.
	var lines := []
	for r in chem:
		var res := _play_chem(r)
		lines.append("%s %.2f (%.0f s)" % [r.id, res[0], res[3]])
	print("minigame com controle (sem imprevistos): %s" % ", ".join(lines))
	var bumpy := _play_chem(_recipe(&"combustivel"), false)
	print("minigame com imprevistos (biodiesel): qualidade %.2f em %.0f s" % [bumpy[0], bumpy[3]])
	var hot := _play_chem(_recipe(&"polvora"), true, true)
	print("pólvora com a chama no máximo: resultado %.2f (acidente? %s)" % [hot[0], hot[0] == 0.0])
	# --- Bancada química: lugares, combustível, garrafa que volta, qualidade e quantidade.
	Progress.i.manuals[&"manual_quimico"] = true
	var at := player.global_position + Vector3(4, 0, -4)
	var bench := _spawn("chem_bench", at)
	var key := Smelting.key_of(bench)
	ContainerManager.i.host_apply("open", [key, ""])
	var slots: Array = ContainerManager.i.contents[key]
	print("bancada: %d lugares; aceita adubo=%s água=%s carvão no queimador=%s botijão=%s biodiesel=%s vidro=%s" % [slots.size(),
		Smelting.accepts(Smelting.INPUT, &"adubo", "chem_bench"), Smelting.accepts(Smithing.ALLOY, &"agua", "chem_bench"),
		Smelting.accepts(Smelting.FUEL, &"carvao", "chem_bench"), Smelting.accepts(Smelting.FUEL, &"botijao", "chem_bench"),
		Smelting.accepts(Smelting.FUEL, &"combustivel", "chem_bench"), Smelting.accepts(Smelting.INPUT, &"vidro", "chem_bench")])
	var salitre := _recipe(&"salitre")
	slots[Smelting.INPUT] = {"id": &"adubo", "amount": 3}
	slots[Smithing.ALLOY] = {"id": &"agua", "amount": 1}
	print("salitre sem combustível: '%s'" % Smithing.missing(salitre, slots, bench))
	slots[Smelting.FUEL] = {"id": &"botijao", "amount": 1}
	print("salitre com botijão: '%s'" % Smithing.missing(salitre, slots, bench))
	var bottles := player.inventory.count(&"garrafa")
	placed.host_apply("smith_done", [bench.net_id, CraftingUI.RECIPES.find(salitre), 0.9])
	await process_frame
	print("salitre 90%%: produto %s, sobrou adubo %s água %s, gás para %d lotes, garrafa voltou: %d -> %d, texto '%s'" % [slots[Smelting.OUTPUT],
		slots[Smelting.INPUT], slots[Smithing.ALLOY], int(bench.extra.get("gas", 0.0)), bottles, player.inventory.count(&"garrafa"), Smithing.text(bench)])
	var acid := _recipe(&"acido")
	slots[Smelting.INPUT] = {"id": &"enxofre", "amount": 2}
	slots[Smithing.ALLOY] = {"id": &"agua", "amount": 1}
	slots[Smelting.OUTPUT] = {}
	bottles = player.inventory.count(&"garrafa")
	placed.host_apply("smith_done", [bench.net_id, CraftingUI.RECIPES.find(acid), 0.0])
	await process_frame
	print("ácido perdido (qualidade 0): produto %s, enxofre %s, garrafa ficou no ácido: %d -> %d" % [slots[Smelting.OUTPUT], slots[Smelting.INPUT], bottles, player.inventory.count(&"garrafa")])
	# --- Acidentes.
	placed.host_apply("chem_accident", [bench.net_id, "leak"])
	print("vazamento: gás na bancada %.2f, a 10 m %.2f" % [Contamination.level_at(bench.global_position + Vector3.UP * 1.1), Contamination.level_at(bench.global_position + Vector3(10, 1.1, 0))])
	Contamination.clouds.clear()
	var hp := player.health
	player.global_position = bench.global_position + Vector3(1.5, 0, 0)
	placed.host_apply("chem_accident", [bench.net_id, "boom"])
	print("pólvora explodiu do lado: vida %.0f -> %.0f, bancada continua: %s" % [hp, player.health, placed.objects.has(bench.net_id)])
	player.health = player.max_health
	# --- Revólver gasta balas de revólver (o que está carregado fica na arma).
	player.equip_item(&"pistola")
	player._sync_equipped()
	player._start_reload()
	print("revólver sem balas: recarregando=%s" % (player._reload_timer > 0.0))
	player.inventory.add(&"cartucho", 20)
	player._start_reload()
	player._update_pistol(3.0)
	print("com 20 balas: tambor %d, mochila %d" % [player._ammo, player.inventory.count(&"cartucho")])
	# --- Ácido renova a bateria.
	var battery := _spawn("battery", at + Vector3(3, 0, 0))
	battery.extra.cells = 4
	battery.extra.health = 0.45
	player.inventory.slots[player.inventory.selected] = {"id": &"acido", "amount": 1}
	bottles = player.inventory.count(&"garrafa")
	Electric.interact(player, battery)
	print("ácido na bateria: saúde 45%% -> %d%%, garrafa volta: %d -> %d, texto '%s'" % [int(Electric.health(battery) * 100.0), bottles,
		player.inventory.count(&"garrafa"), Electric.text(battery)])
	print("biodiesel no carro: +%d%% (álcool +%d%%); maçarico rende %d, queimador %d" % [int(VintageCar.FUEL_ITEMS[&"combustivel"] * 100.0),
		int(VintageCar.FUEL_ITEMS[&"alcool"] * 100.0), Smithing.TORCH_FUEL[&"combustivel"], Smithing.CHEM_FUEL[&"combustivel"]])
	# --- Enxofre no terreno.
	var sulfur := 0
	var coal := 0
	for k in 4000:
		var kind := TerrainProps._sulfur("ore_coal", k * 7.3, k * 3.1, {"desert": 0.0})
		coal += 1
		if kind == "ore_sulfur":
			sulfur += 1
	var desert := 0
	for k in 4000:
		if TerrainProps._sulfur("rock", k * 5.7, -k * 2.9, {"desert": 1.0}) == "ore_sulfur":
			desert += 1
	print("enxofre: %.0f%% dos veios de carvão, %.0f%% das rochas do deserto; saque do veio: %s" % [100.0 * sulfur / coal, 100.0 * desert / 4000.0, Loot.FIXED.enxofre])
	# --- Zonas contaminadas.
	var terrain: TerrainWorld = main.get_node("Terrain")
	var kinds := {}
	for z in terrain.zones:
		kinds[z.kind] = kinds.get(z.kind, 0) + 1
	print("zonas: %d %s; cidades grandes %d" % [terrain.zones.size(), kinds, terrain.cities.filter(func(c): return c.size == "large").size()])
	var zone: Dictionary = terrain.zones.filter(func(z): return z.kind == "plant")[0] if kinds.has("plant") else terrain.zones[0]
	var ground := Vector3(zone.center.x, zone.base + 0.5, zone.center.y)
	print("gás: centro %.2f, borda+5 m %.2f, 30 m acima %.2f, fora %.2f" % [Contamination.level_at(ground),
		Contamination.level_at(ground + Vector3(zone.radius - 5.0, 0, 0)), Contamination.level_at(ground + Vector3(0, 30, 0)),
		Contamination.level_at(ground + Vector3(zone.radius + 5.0, 0, 0))])
	print("saque contaminado: %s" % [Loot.roll("contaminado")])
	# Sem máscara.
	player.global_position = ground
	player.health = player.max_health
	player.toxic = 0.0
	var events := []
	player.toxic_changed.connect(func(t, g, f): events.append([t, g, f]))
	for k in 30:
		player._update_toxic(0.5)
	print("15 s no gás sem máscara: intoxicação %.0f, vida %.0f, doente %s, último aviso %s" % [player.toxic, player.health, player.sick_time > 0.0, events.back()])
	# De máscara (filtro novo) + 1 filtro na mochila.
	player.health = player.max_health
	player.toxic = 0.0
	player.sick_time = 0.0
	player.inventory.equipment.head = {"id": &"mascara_gas", "amount": 1}
	player.inventory.add(&"filtro", 1)
	for k in 60:
		player._update_toxic(0.5)
	print("30 s de máscara: intoxicação %.0f, filtro %.0f%%, vida %.0f" % [player.toxic, player.inventory.equipment.head.get("filter", 1.0) * 100.0, player.health])
	for k in 340:
		player._update_toxic(0.5)
	print("mais 170 s: filtro trocou? mochila tem %d filtro(s), filtro na máscara %.0f%%, intoxicação %.0f, conquista zona: %s" % [player.inventory.count(&"filtro"),
		player.inventory.equipment.head.get("filter", 1.0) * 100.0, player.toxic, Progress.i.done.has("zona")])
	# Save/load: intoxicação, munição e filtro da máscara.
	var saved := player.save_extra()
	player.toxic = 0.0
	player.inventory.equipment.head = {}
	player.load_extra(saved)
	print("save/load: intoxicação %.0f, tambor (no slot) %d, máscara %s filtro %.0f%%" % [player.toxic, player._ammo, player.inventory.equipment.head.get("id", ""),
		player.inventory.equipment.head.get("filter", 1.0) * 100.0])
	print("conquistas da era 4: %s" % [Progress.ACHIEVEMENTS.keys().filter(func(k): return Progress.ACHIEVEMENTS[k].era == 4)])
	quit()
