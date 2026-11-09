extends SceneTree
## Fase 1 das eras: conquistas e eras, manuais travando receitas, forja (minigame de
## temperatura jogado por um "ferreiro" automático), qualidade viajando com o item
## (baú, chão), trefiladora, diário e save do progresso.

var main: Node3D
var player: Player
var placed: PlacedManager


func _spawn(kind: String, pos: Vector3) -> PlacedObject:
	var id: int = placed._next_id
	placed._spawn(id, kind, Transform3D(Basis(), pos))
	return placed.objects[id]


## Ferreiro automático: esquenta com o fole até passar do meio da faixa, leva para a
## bigorna, bate enquanto está na faixa e volta para o fogo quando esfria.
## sloppy = bate frio de propósito (para rachar).
func _smith(game: ForgeMinigame, sloppy := false) -> void:
	game.manual_input = false
	var band: Vector2 = game.metal.band
	var mid := (band.x + band.y) * 0.5
	var guard := 0
	while not game._done and game._result <= -2.0 and guard < 20000:
		guard += 1
		if game.in_fire:
			game.bellows = true
			game.step(0.05)
			if game.temp >= mid + 0.08 or (sloppy and game.temp >= 0.3):
				game.toggle()
		else:
			game.step(0.05)
			if (game.temp >= band.x and game.temp <= band.y) or sloppy:
				if game._cooldown <= 0.0:
					game.strike()
			elif game.temp < band.x:
				game.toggle()


## Espera (no máximo 5 s de verdade) a condição: a mensagem do fim do minigame dura 1,6 s.
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
	var p := Progress.i
	print("progresso: era %d (%s), conquistas %d, manuais %d" % [p.era, Progress.ERAS[p.era].name, p.done.size(), p.manuals.size()])
	# --- Era 0 -> 1: sucata, ferramenta e fogueira.
	player.inventory.add(&"sucata", 2)
	player.inventory.add(&"graveto", 2)
	player.inventory.add(&"pedra", 2)
	var made := CraftingUI.craft(player, CraftingUI.recipes_for("mao").filter(func(r): return r.id == &"machado_simples")[0])
	Progress.event("place", "campfire")
	print("era 0: sucata=%s ferramenta=%s (fez %d) fogueira=%s -> era %d; avisos na fila %d" % [p.done.has("sucata"), p.done.has("ferramenta"), made,
		p.done.has("fogueira"), p.era, p._queue.size() + (1 if p._toast.visible else 0)])
	# --- Manuais travam receitas.
	var espada: Dictionary = CraftingUI.RECIPES.filter(func(r): return r.station == "forja" and r.id == &"espada")[0]
	var cabo_fio: Dictionary = CraftingUI.RECIPES.filter(func(r): return r.get("note", "") == "fio" and r.id == &"cabo")[0]
	player.inventory.add(&"fio_cobre", 4)
	player.inventory.add(&"pano", 2)
	print("sem manual: espada na forja '%s', cabo com fio fabricável=%s, trefiladora liberada=%s" % [Smithing.missing(espada, []),
		CraftingUI.can_craft(player.inventory, cabo_fio), Progress.knows(&"manual_eletricista")])
	player.inventory.add(&"manual_ferreiro", 1)
	player.inventory.add(&"manual_eletricista", 1)
	Progress.read(player, &"manual_ferreiro")
	Progress.read(player, &"manual_eletricista")
	print("leu os 2 manuais: conhece ferreiro=%s eletricista=%s, cabo com fio fabricável=%s, livros ainda na mochila: %d, pistas %d" % [
		Progress.knows(&"manual_ferreiro"), Progress.knows(&"manual_eletricista"), CraftingUI.can_craft(player.inventory, cabo_fio),
		player.inventory.count(&"manual_ferreiro") + player.inventory.count(&"manual_eletricista"), p.clues.size()])
	# --- Forja: lugares e minigame.
	var at := player.global_position + Vector3(4, 0, -4)
	var forge := _spawn("forge", at)
	var key := Smelting.key_of(forge)
	ContainerManager.i.host_apply("open", [key, ""])
	var slots: Array = ContainerManager.i.contents[key]
	print("forja aceita: ferro=%s aço=%s cobre=%s carvão no fogo=%s tronco no fogo=%s" % [Smelting.accepts(0, &"barra_ferro", "forge"),
		Smelting.accepts(0, &"barra_aco", "forge"), Smelting.accepts(0, &"barra_cobre", "forge"), Smelting.accepts(1, &"carvao", "forge"), Smelting.accepts(1, &"tronco", "forge")])
	slots[Smelting.INPUT] = {"id": &"barra_ferro", "amount": 6}
	slots[Smelting.FUEL] = {"id": &"carvao", "amount": 3}
	var index := CraftingUI.RECIPES.find(espada)
	print("pode forjar espada: '%s'" % Smithing.missing(espada, slots, forge))
	var results := []
	var game := Minigame.play(player, "forge", {"item": &"espada", "metal": &"barra_ferro", "hits": 12, "chart": true}, func(q: float): results.append(q)) as ForgeMinigame
	await process_frame
	print("minigame aberto: jogador travado=%s, golpes pedidos %d, faixa do ferro %s" % [player.ui_blocked, game.need, game.metal.band])
	_smith(game)
	print("ferreiro bom: golpes %d, rachaduras %d, queima %.1f s, qualidade %.2f" % [game.hits, game.cracks, game.burn, game.quality()])
	await _until(func(): return not results.is_empty())
	print("minigame fechou: qualidade devolvida %s, jogador solto=%s" % [results, not player.ui_blocked])
	placed.host_apply("smith_done", [forge.net_id, index, results[0]])
	print("forjou: lugares agora metal %s, carvão %s, peça %s, forja acesa=%s" % [slots[0].get("amount", 0), slots[1].get("amount", 0), slots[2], forge.is_lit(placed.clock)])
	# Rachar: ferreiro afobado bate frio.
	var results2 := []
	var game2 := Minigame.play(player, "forge", {"item": &"machado", "metal": &"barra_ferro", "hits": 8}, func(q: float): results2.append(q)) as ForgeMinigame
	await process_frame
	_smith(game2, true)
	var cracks2 := game2.cracks
	await _until(func(): return not results2.is_empty())
	var machado: Dictionary = CraftingUI.RECIPES.filter(func(r): return r.station == "forja" and r.id == &"machado")[0]
	ContainerManager.i.host_apply("take", [key, Smelting.OUTPUT]) # tira a espada antes
	placed.host_apply("smith_done", [forge.net_id, CraftingUI.RECIPES.find(machado), results2[0]])
	print("ferreiro afobado: rachaduras %d, qualidade %s -> peça %s" % [cracks2, results2, slots[2]])
	# Desistir antes do primeiro golpe: -1 (nada gasto).
	var results3 := []
	var game3 := Minigame.play(player, "forge", {"item": &"pa", "metal": &"barra_ferro", "hits": 6}, func(q: float): results3.append(q)) as ForgeMinigame
	await process_frame
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	game3._input(esc)
	print("desistiu antes de bater: %s" % [results3])
	# --- Qualidade na mão, no chão e no baú.
	var sword_slot := -1
	for i in player.inventory.slots.size():
		var s: Dictionary = player.inventory.slots[i]
		if not s.is_empty() and s.id == &"espada" and s.has("q"):
			sword_slot = i
	var q: float = player.inventory.slots[sword_slot].q if sword_slot >= 0 else -1.0
	player.inventory.select(sword_slot)
	print("espada forjada na mochila: q=%.2f, dano x%.2f (q=0: x%.2f, q=1: x%.2f), desgaste x%.2f" % [q, player._sharp_mult(),
		ItemDB.quality_damage({"q": 0.0}), ItemDB.quality_damage({"q": 1.0}), ItemDB.quality_wear(player.inventory.slots[sword_slot])])
	var taken := player.inventory.take(sword_slot, 1)
	Net.i.drop_item(taken.id, 1, player.global_transform.translated(Vector3(0, 1, -1)), Vector3.ZERO, taken.get("dur", 1.0), ItemDB.extras(taken))
	await process_frame
	var dropped: PickupItem = null
	for node in get_nodes_in_group("interactable"):
		if node is PickupItem and node.item_id == &"espada":
			dropped = node
	print("no chão: extra=%s" % [dropped.extra if dropped else "?"])
	dropped.take_locally(player)
	var back := -1
	for i in player.inventory.slots.size():
		if not player.inventory.slots[i].is_empty() and player.inventory.slots[i].id == &"espada":
			back = i
	print("pegou de volta: q=%s" % player.inventory.slots[back].get("q"))
	var chest := _spawn("chest", at + Vector3(3, 0, 0))
	var chest_key := "placed_%d" % chest.net_id
	ContainerManager.i.host_apply("open", [chest_key, ""])
	var moved := player.inventory.take(back, 1)
	ContainerManager.i.host_apply("put_at", [chest_key, 0, String(moved.id), 1, moved.get("dur", 1.0), ItemDB.extras(moved)])
	print("no baú: %s" % ContainerManager.i.contents[chest_key][0])
	ContainerManager.i.host_apply("take", [chest_key, 0])
	await process_frame
	print("tirou do baú: q=%s" % [player.inventory.slots.filter(func(s): return not s.is_empty() and s.id == &"espada")[0].get("q")])
	# --- Trefiladora.
	var drawer := _spawn("wire_drawer", at + Vector3(0, 0, 4))
	var dkey := Smelting.key_of(drawer)
	ContainerManager.i.host_apply("open", [dkey, ""])
	var dslots: Array = ContainerManager.i.contents[dkey]
	dslots[Smelting.INPUT] = {"id": &"barra_cobre", "amount": 2}
	print("trefiladora: aceita cobre=%s, carvão no fogo=%s, porta %s, carga %s" % [Smelting.accepts(0, &"barra_cobre", "wire_drawer"),
		Smelting.accepts(1, &"carvao", "wire_drawer"), Power.PORTS["wire_drawer"][0][0], Power.DEMAND["wire_drawer"]])
	for k in 5:
		Smelting.host_tick(drawer, placed.clock)
	var stopped: Array = dslots[Smelting.OUTPUT].duplicate() if dslots[Smelting.OUTPUT] is Array else [dslots[Smelting.OUTPUT].duplicate()]
	drawer.extra.speed = 1.0
	for k in 5:
		Smelting.host_tick(drawer, placed.clock)
	print("parada 5 s: %s; girando 5 s: %s (cobre sobrando %s), ocupada=%s" % [stopped, dslots[Smelting.OUTPUT], dslots[Smelting.INPUT].get("amount", 0), Power.busy(drawer)])
	# --- Eras seguintes por eventos.
	for e in ["place:forge", "get:barra_ferro", "forge:espada", "place:water_wheel", "place:sawmill", "place:dynamo", "place:battery"]:
		var parts: PackedStringArray = e.split(":")
		Progress.event(parts[0], parts[1])
	print("depois de forja, roda d'água, serraria, dínamo e bateria: era %d (%s), conquistas %d de %d" % [p.era, Progress.ERAS[p.era].name, p.done.size(), Progress.ACHIEVEMENTS.size()])
	# --- Diário: as 4 abas abrem.
	JournalUI.open_for(player)
	await process_frame
	var journal: JournalUI = null
	for node in main.get_children():
		if node is JournalUI:
			journal = node
	var counts := []
	for t in JournalUI.TABS:
		JournalUI.tab = t
		journal._refresh()
		await process_frame
		counts.append("%s=%d" % [t, journal._body.get_child_count()])
	print("diário: %s; título '%s'" % [", ".join(counts), journal._title.text])
	journal.close()
	await process_frame
	# --- Save/load do progresso (junto do jogador).
	var data := player.save_extra()
	var era_before := p.era
	p.load_data({})
	print("progresso apagado: era %d, manuais %d" % [p.era, p.manuals.size()])
	player.load_extra(data)
	print("save/load: era %d (antes %d), manuais %d, receitas descobertas %d, pistas %d" % [p.era, era_before, p.manuals.size(), p.recipes.size(), p.clues.size()])
	print("saque: casa tem manual=%s, ruína=%s, airdrop=%s" % [Loot.TABLES.casa.any(func(r): return String(r[0]).begins_with("manual")),
		Loot.TABLES.ruina.any(func(r): return String(r[0]).begins_with("manual")), Loot.TABLES.airdrop.any(func(r): return String(r[0]).begins_with("manual"))])
	quit()
