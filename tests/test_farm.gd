extends SceneTree
## Fazenda de animais e bichos novos:
##   todas as espécies montam; galinha selvagem segue quem segura sementes e fica
##   mansa com [E]; mansas comem no cocho e bebem no bebedouro; com comida + água
##   nascem filhotes; ovo, leite e lã; cerca segura e porteira abre; pássaro voa e
##   pousa; pato boia; lobo ataca; save/load dos mansos; plantar sem mirar na vaga;
##   lã na roca.

var main: Node
var player: Player
var animals: AnimalManager
var placed: PlacedManager
var o := Vector3.ZERO


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	player = main.player
	animals = main.get_node("Animals")
	placed = main.get_node("Placed")
	animals.set_process(false) # nada nascendo sozinho no meio do teste
	main.get_node("ZombieSpawner").process_mode = Node.PROCESS_MODE_DISABLED
	for e in main.get_node("Enemies").get_children():
		e.free()
	for a in animals.animals.values():
		a.free()
	animals.animals.clear()
	if DayNight.i:
		DayNight.i.hour = 12.0
	player.max_health = 10000.0
	player.health = 10000.0
	o = player.global_position
	await _kinds()
	await _taming()
	await _farm_cycle()
	await _products()
	await _fence()
	await _birds()
	await _wolf()
	await _save_load()
	await _planting()
	quit()


func _wait(frames: int) -> void:
	for k in frames:
		await physics_frame


func _hold(id: StringName, amount: int) -> void:
	player.inventory.add(id, amount)
	for i in player.inventory.slots.size():
		var s: Dictionary = player.inventory.slots[i]
		if not s.is_empty() and s.id == id:
			player.inventory.selected = i
			return


func _clear_animals() -> void:
	for a in animals.animals.values():
		if is_instance_valid(a):
			a.free()
	animals.animals.clear()


func _kinds() -> void:
	var parts := []
	for kind in Animal.KINDS:
		var a := animals.spawn(kind, o + Vector3(40, 0.5, 40))
		parts.append("%s=%d" % [kind, a.get_node("Model").get_child_count()])
	await _wait(3)
	print("espécies (%d): %s" % [Animal.KINDS.size(), " ".join(parts)])
	_clear_animals()


func _taming() -> void:
	var hen := animals.spawn("galinha", o + Vector3(7, 0.3, 0))
	await _wait(10)
	var d0 := hen.global_position.distance_to(player.global_position)
	await _wait(60)
	var flee := hen.global_position.distance_to(player.global_position)
	hen.global_position = o + Vector3(7, 0.3, 0)
	_hold(&"semente_trigo", 10)
	await _wait(150)
	var lured := hen.global_position.distance_to(player.global_position)
	print("galinha selvagem: sem semente %.1f -> %.1f m (foge) | segurando semente: %.1f m (vem atrás)" % [d0, flee, lured])
	print("texto: ", hen.get_interact_text())
	hen.interact(player)
	await _wait(2)
	print("depois de [E]: mansa=%s alimentada=%s sementes na mão=%d  texto: %s" % [hen.tame, hen.is_fed(), player.inventory.count(&"semente_trigo"), hen.get_interact_text()])
	_clear_animals()


func _place(kind: String, at: Vector3, basis := Basis()) -> PlacedObject:
	var r := placed.host_apply("place", [kind, Transform3D(basis, at)])
	return placed.objects.get(r[0]) if not r.is_empty() else null


func _farm_cycle() -> void:
	player.inventory.selected = 8
	var base := o + Vector3(-15, 0, 12)
	var terrain: TerrainWorld = main.get_node("Terrain")
	base.y = terrain.height_at(base.x, base.z)
	var trough := _place("trough", base + Vector3(3, 0, 0))
	var water := _place("water_trough", base + Vector3(-3, 0, 0))
	ContainerManager.i.contents[Ranch.key_of(trough)] = ContainerManager.empty_slots(ContainerManager.STORAGE_SLOTS)
	ContainerManager.add_to(ContainerManager.i.contents[Ranch.key_of(trough)], &"semente_trigo", 10)
	for k in 4:
		placed.host_apply("pour", [water.net_id])
	print("bebedouro com 4 garrafas: água=%.0f  texto: %s | cocho: %s" % [water.extra.get("water", 0.0), water.get_interact_text(), trough.get_interact_text()])
	var hens := []
	for k in 2:
		var h := animals.spawn("galinha", base + Vector3(k * 1.0, 0.3, 2))
		h.tame = true
		h.home = base
		hens.append(h)
	for f in 60 * 20:
		await physics_frame
		if hens.all(func(h): return h.is_fed() and h.is_watered()):
			print("galinhas foram ao cocho e ao bebedouro em %.1f s" % (f / 60.0))
			break
	var left := 0
	for s in ContainerManager.i.contents[Ranch.key_of(trough)]:
		if not s.is_empty():
			left += s.amount
	print("alimentadas=%s com água=%s  sementes no cocho %d (de 10), água %.0f (de 4)" % [hens.map(func(h): return h.is_fed()),
		hens.map(func(h): return h.is_watered()), left, water.extra.get("water", 0.0)])
	for h in hens:
		h.next_breed = 0.0
	var before := animals.animals.size()
	animals._farm()
	var babies: Array = animals.animals.values().filter(func(a): return a.tame and a.is_baby())
	print("cria: bichos %d -> %d, filhotes=%d, filhote escala=%.2f" % [before, animals.animals.size(), babies.size(),
		babies[0].get_node("Model").scale.x if not babies.is_empty() else 0.0])
	await _wait(2)
	if not babies.is_empty():
		print("filhote texto: ", babies[0].get_interact_text())
	# Sem água: não cria.
	for h in hens:
		h.next_breed = 0.0
		h.water_until = 0.0
	var n := animals.animals.size()
	animals._farm()
	print("sem água: bichos %d -> %d (não cria)" % [n, animals.animals.size()])
	# Ovo
	hens[0].next_product = 0.0
	animals._farm()
	await _wait(3)
	var eggs := get_nodes_in_group("interactable").filter(func(i): return i is PickupItem and i.item_id == &"ovo")
	print("ovo no chão: %d" % eggs.size())
	_clear_animals()


func _products() -> void:
	var cow := animals.spawn("vaca", o + Vector3(4, 0.5, -4))
	cow.tame = true
	cow.fed_until = placed.clock + 600.0
	cow.next_product = 0.0
	player.inventory.add(&"garrafa", 2)
	player.inventory.selected = 8
	await _wait(2)
	print("vaca: ", cow.get_interact_text())
	cow.interact(player)
	await _wait(3)
	print("ordenhou: leite na mochila=%d  pronta de novo=%s" % [player.inventory.count(&"leite"), cow.product_ready()])
	var sheep := animals.spawn("ovelha", o + Vector3(-4, 0.5, -4))
	sheep.tame = true
	await _wait(2)
	print("ovelha: ", sheep.get_interact_text())
	sheep.interact(player)
	await _wait(3)
	print("tosquiou: lã=%d  lã visível=%s" % [player.inventory.count(&"la"), sheep.get_node("Model/Wool").visible])
	sheep.fed_until = placed.clock + 600.0
	placed.clock += 700.0
	sheep.fed_until = placed.clock + 600.0
	animals._farm()
	await _wait(2)
	print("depois de 700 s alimentada: lã cresceu=%s" % sheep.get_node("Model/Wool").visible)
	_clear_animals()


func _fence() -> void:
	var at := o + Vector3(0, 0, 6)
	var terrain: TerrainWorld = main.get_node("Terrain")
	at.y = terrain.height_at(at.x, at.z)
	var fence := _place("fence", at)
	var gate := _place("gate", at + Vector3(2.4, 0, 0))
	await _wait(3)
	var space: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	var ray := func(x: float) -> bool:
		var q := PhysicsRayQueryParameters3D.create(at + Vector3(x, 0.6, -1.0), at + Vector3(x, 0.6, 1.0))
		return not space.intersect_ray(q).is_empty()
	var fence_blocks: bool = ray.call(0.3)
	var gate_closed: bool = ray.call(2.4)
	gate.interact(player)
	await _wait(3)
	var gate_open: bool = ray.call(2.4)
	print("cerca bloqueia=%s porteira fechada bloqueia=%s aberta bloqueia=%s (texto: %s)" % [fence_blocks, gate_closed, gate_open, gate.get_interact_text()])
	# Zumbi trata a cerca como construção e consegue quebrar.
	for k in Ranch.FENCE_HP:
		placed.host_apply("fence_hit", [fence.net_id, 1])
	print("cerca depois de %d golpes de zumbi: existe=%s, zumbi vê como construção=%s" % [Ranch.FENCE_HP, placed.objects.has(fence.net_id), Zombie.is_build(gate)])


func _birds() -> void:
	var pigeon := animals.spawn("pombo", o + Vector3(3, 0.3, 3))
	await _wait(5)
	var flew := false
	var top := 0.0
	var landed_at := -1.0
	for f in 60 * 25:
		await physics_frame
		if pigeon._flying:
			flew = true
		top = maxf(top, pigeon.global_position.y - o.y)
		if flew and not pigeon._flying and landed_at < 0.0:
			landed_at = f / 60.0
			break
	print("pombo: voou=%s altura máx %.1f m, pousou em %.1f s a %.0f m do jogador" % [flew, top, landed_at, pigeon.global_position.distance_to(player.global_position)])
	var lake := {}
	for l in WaterManager.i.lakes():
		if not l.frozen:
			lake = l
			break
	if not lake.is_empty():
		var duck := animals.spawn("pato", Vector3(lake.center.x, lake.level, lake.center.y))
		duck.home = duck.global_position
		await _wait(120)
		print("pato no lago: altura em relação à água %.2f m, nadando=%s" % [duck.global_position.y - lake.level, duck._swimming])
	_clear_animals()


func _wolf() -> void:
	var wolves := [animals.spawn("lobo", o + Vector3(9, 0.5, 0)), animals.spawn("lobo", o + Vector3(10, 0.5, 2))]
	var hp0 := player.health
	for f in 60 * 6:
		await physics_frame
		player.global_position = o
		player.velocity = Vector3.ZERO
	print("lobos: bravos=%s dano no jogador %.0f" % [wolves.map(func(w): return w._angry > 0.0), hp0 - player.health])
	_clear_animals()


func _save_load() -> void:
	for kind in ["galinha", "vaca", "porco"]:
		var a := animals.spawn(kind, o + Vector3(randf_range(-5, 5), 0.5, randf_range(-5, 5)))
		a.tame = true
		a.fed_until = 123.0
	animals.spawn("cervo", o + Vector3(20, 0.5, 0))
	var data := animals.save_data()
	_clear_animals()
	animals.load_data(data)
	await _wait(2)
	print("save/load: mansos salvos=%d carregados=%s" % [data.tame.size(), animals.animals.values().map(func(a): return "%s(fed %.0f)" % [a.kind, a.fed_until])])
	_clear_animals()


func _planting() -> void:
	var at := o + Vector3(0, 0, -3)
	var terrain: TerrainWorld = main.get_node("Terrain")
	at.y = terrain.height_at(at.x, at.z)
	var pot := _place("pot_wide", at, Basis(Vector3.UP, player.rotation.y))
	await _wait(3)
	_hold(&"semente_trigo", 5)
	# Mira na ponta esquerda da floreira o tempo todo.
	var aim: Vector3 = pot.to_global(Vector3(-0.55, 0.36, 0))
	var eye := player.camera.global_position
	var to := aim - eye
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await _wait(2)
	var planted := 0
	for k in 3:
		if Farming.use(player, "trigo"):
			planted += 1
		await _wait(2)
	print("floreira mirando sempre a mesma ponta: plantou %d de 3 vagas (%s)" % [planted, pot.crops.map(func(c): return c.get("crop", "-"))])
	# Roca aceita lã.
	var wheel := _place("spinning", at + Vector3(3, 0, 0))
	player.inventory.add(&"la", 3)
	Machines.tap(player, wheel)
	await _wait(2)
	print("roca com 3 lãs: entrada=%d (2 por lã), lã na mochila=%d" % [wheel.extra.get("in", 0), player.inventory.count(&"la")])
