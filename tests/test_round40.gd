extends SceneTree
## Rodada 40: telhado inclinado (4 direções), plantas mais lentas e 20% à noite,
## adubo no cesto do canteiro, coletor guarda 5, mão secundária (tocha/lanterna),
## manivela anda sozinha com força, polia do torno no lugar, receitas na fornalha.

func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var player: Player = main.player
	var bm: BuildingManager = main.get_node("Building")
	var placed: PlacedManager = main.get_node("Placed")
	var space: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	# --- Telhado inclinado
	var base := Vector3i(100, 10, 100)
	var lines := []
	for rot in [2, 3, 4, 5]:
		var cell := base + Vector3i((rot - 2) * 10, 0, 0)
		var r := bm.host_apply("place", [BuildPiece.Kind.ROOF, cell, rot])
		await physics_frame
		var piece: BuildPiece = bm.pieces[r[0]]
		var o := Vector3(cell) * BuildPiece.SEG
		var s := BuildPiece.SIZE
		var heights := []
		var d: Vector3 = BuildPiece.slope_dir(rot)
		var center: Vector3 = o + Vector3(s * 0.5, 0, s * 0.5)
		for f: float in [0.1, 0.5, 0.9]:
			var start: Vector3 = center + d * s * (f - 0.5) # da borda de baixo (10%) até perto do alto (90%)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(start + Vector3.UP * 10.0, start + Vector3.DOWN * 5.0))
			heights.append(snappedf(hit.position.y - o.y, 0.01) if hit else -1.0)
		lines.append("rot %d (sobe para %s): altura a 10/50/90%% = %s" % [rot, BuildPiece.slope_dir(rot), heights])
	for l in lines:
		print("telhado ", l)
	var test_piece: BuildPiece = bm.pieces.values()[-1]
	var mid := test_piece.to_global(test_piece.uvw(1.4, 1.4, BuildPiece.THICK * 0.5))
	var hit_t := test_piece.ray_to_panel(mid + Vector3.UP * 2.0, mid + Vector3.DOWN * 2.0)
	print("talhadeira no telhado: triângulo=%s quadrado=%s" % [hit_t.get("triangle", -1), hit_t.get("square", "-")])
	var state := bm.state()
	bm.load_state(state)
	await physics_frame
	print("save/load: rot dos telhados = %s" % [bm.pieces.values().map(func(p): return p.rot)])
	# --- Plantas
	print("cenoura leva %.0f s do relógio das plantas (dia de %d min); de dia cresce %.1fx, de noite %.1fx" % [Farming.grow_time("cenoura"),
		WorldSettings.get_value("day_length"), 1.0, Farming.NIGHT_GROWTH])
	DayNight.i.hour = 12.0
	DayNight.i._apply()
	var g0 := PlacedManager.grow_clock
	for k in 60:
		await process_frame
	var day_rate := (PlacedManager.grow_clock - g0)
	DayNight.i.hour = 1.0
	DayNight.i._apply()
	g0 = PlacedManager.grow_clock
	for k in 60:
		await process_frame
	var night_rate := (PlacedManager.grow_clock - g0)
	print("relógio das plantas em 60 quadros: dia %.2f s, noite %.2f s (noite/dia = %.2f)" % [day_rate, night_rate, night_rate / maxf(day_rate, 0.001)])
	DayNight.i.hour = 12.0
	DayNight.i._apply()
	# --- Adubo no cesto
	var at := player.global_position + Vector3(4, 0, -4)
	var terrain: TerrainWorld = main.get_node("Terrain")
	at.y = terrain.height_at(at.x, at.z)
	var rb := placed.host_apply("place", ["bed", Transform3D(Basis(), at)])
	var bed: PlacedObject = placed.objects[rb[0]]
	var basket := ContainerManager.empty_slots(ContainerManager.STORAGE_SLOTS)
	ContainerManager.add_to(basket, &"adubo", 2)
	ContainerManager.i.contents[bed.basket_key()] = basket
	placed._fertilize_beds()
	var left := 0
	for sl in ContainerManager.i.slots_of(bed.basket_key()):
		if not sl.is_empty():
			left += sl.amount
	print("adubo no cesto: canteiro adubado=%d, adubo sobrando no cesto=%d" % [bed.extra.get("fert", 0), left])
	placed.host_apply("plant", [bed.net_id, 0, "trigo"])
	PlacedManager.grow_clock += 99999.0
	var before: int = ContainerManager.i.slots_of(bed.basket_key()).filter(func(sl): return not sl.is_empty() and sl.id == &"trigo").reduce(func(acc, sl): return acc + sl.amount, 0)
	placed.host_apply("harvest", [bed.net_id, 0])
	var after: int = ContainerManager.i.slots_of(bed.basket_key()).filter(func(sl): return not sl.is_empty() and sl.id == &"trigo").reduce(func(acc, sl): return acc + sl.amount, 0)
	print("colheita adubada no cesto: trigo %d -> %d (adubo agora %d)" % [before, after, bed.extra.get("fert", 0)])
	# --- Coletor
	var rc := placed.host_apply("place", ["rain_collector", Transform3D(Basis(), at + Vector3(4, 0, 0))])
	var col: PlacedObject = placed.objects[rc[0]]
	Weather.i.rain = 1.0
	for k in 2000:
		placed._collect_rain()
	print("coletor depois de muita chuva: %.1f (máx %d)" % [col.extra.get("water", 0.0), PlacedObject.COLLECTOR_CAP])
	Weather.i.rain = 0.0
	# --- Mão secundária
	player.inventory.add(&"tocha", 1)
	var ti := Cooking.find_any(player.inventory, {&"tocha": true})
	var ok := player.inventory.equip_from(ti, "offhand")
	player.inventory.selected = 8
	for k in 5:
		await process_frame
	print("tocha na mão secundária: equipou=%s acesa=%s (mão esquerda x=%.2f)" % [ok, player._torch != null and player._torch.visible, player._torch.position.x if player._torch else 0.0])
	player.inventory.equipment["offhand"] = {"id": &"lanterna", "amount": 1}
	for k in 5:
		await process_frame
	player._toggle_flashlight()
	print("lanterna na mão secundária: tocha apagou=%s, lanterna acende=%s, modelo na mão=%s" % [not player._torch.visible, player._flashlight.visible,
		player._off_lantern != null and player._off_lantern.visible])
	# --- Manivela anda sozinha com força
	var wheel_id := placed._next_id
	placed._spawn(wheel_id, "water_wheel", Transform3D(Basis(), at + Vector3(-8, 0, 6)))
	var wheel: PlacedObject = placed.objects[wheel_id]
	var quern_id := placed._next_id
	var qat: Vector3 = Power.world_ports(wheel)[0][0] + Vector3(0.55, -0.6, 0) + Vector3(0.0001, 0, 0)
	placed._spawn(quern_id, "quern", Transform3D(Basis(), qat))
	var quern: PlacedObject = placed.objects[quern_id]
	quern.extra["in"] = 10
	placed.clock += 1.0
	placed._power()
	var crank := quern.get_node("Crank") as Node3D
	var r0: Vector3 = crank.rotation
	for k in 30:
		await process_frame
	print("moinho ligado direto na roda: %s, manivela girou sozinha=%s" % [quern.extra.get("pstate", "-"), not crank.rotation.is_equal_approx(r0)])
	# --- Polia do torno
	var lathe_id := placed._next_id
	placed._spawn(lathe_id, "lathe", Transform3D(Basis(), at + Vector3(0, 0, 10)))
	var lathe: PlacedObject = placed.objects[lathe_id]
	print("porta do torno em x=%.2f (polia de latão do modelo em -0,98)" % Power.PORTS.lathe[0][0].x)
	# --- Receitas na fornalha
	var rf := placed.host_apply("place", ["furnace", Transform3D(Basis(), at + Vector3(-4, 0, 0))])
	player.inventory.add(&"areia", 4)
	player.ui_blocked = false
	StorageUI.open_for(player, Smelting.key_of(placed.objects[rf[0]]), placed.objects[rf[0]])
	for k in 3:
		await process_frame
	var ui: StorageUI = main.get_children().filter(func(n): return n is StorageUI)[0]
	print("receitas na fornalha: %d botões, claros (tem o material)=%d" % [ui._recipe_box.get_child_count(),
		ui._recipe_box.get_children().filter(func(b): return b.modulate.a > 0.9).size()])
	ui._use_recipe(&"areia")
	await process_frame
	print("clicou na receita do vidro: areia no lugar do material=%s" % [ContainerManager.i.slots_of(Smelting.key_of(placed.objects[rf[0]]))[0]])
	ui.close()
	quit()
