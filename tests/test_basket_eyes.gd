extends SceneTree
## Canteiro com cesto no meio (colheita vai para o cesto), olhos do zumbi apagando
## ao morrer, zumbis 1,25x mais rápidos, tela da lousa reta dentro da moldura e
## painel das máquinas no lugar do texto.

func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	var terrain: TerrainWorld = main.get_node("Terrain")
	main.get_node("ZombieSpawner").process_mode = Node.PROCESS_MODE_DISABLED
	for e in main.get_node("Enemies").get_children():
		e.free()
	# --- Canteiro e cesto
	var at := player.global_position + Vector3(-1.4, 0, -4.5)
	at.y = terrain.height_at(at.x, at.z)
	var r := placed.host_apply("place", ["bed", Transform3D(Basis(), at)])
	var bed: PlacedObject = placed.objects[r[0]]
	for k in 12:
		bed.crops[k % 9] = bed.crops[k % 9] # nada
	var planted := []
	for slot in 9:
		var res := placed.host_apply("plant", [bed.net_id, slot, "cenoura"])
		planted.append(not res.is_empty())
	print("plantar nas 9 vagas: %s (a do meio é o cesto)" % [planted])
	placed.clock += 400.0
	var inv0 := player.inventory.count(&"cenoura")
	var ground0 := root.get_tree().get_nodes_in_group("interactable").filter(func(i): return i is PickupItem and i.item_id == &"cenoura").size()
	for slot in 9:
		placed.host_apply("harvest", [bed.net_id, slot])
	await physics_frame
	var basket: Array = ContainerManager.i.slots_of(bed.basket_key())
	var inside := basket.filter(func(s): return not s.is_empty()).map(func(s): return "%s x%d" % [s.id, s.amount])
	var ground1 := root.get_tree().get_nodes_in_group("interactable").filter(func(i): return i is PickupItem and i.item_id == &"cenoura").size()
	print("colheu 8: cesto=%s | mochila +%d | no chão +%d | cesto aparece cheio=%s" % [inside, player.inventory.count(&"cenoura") - inv0,
		ground1 - ground0, bed.get_node("Fill").visible])
	# [E] no canteiro sem nada pronto abre o cesto.
	player.ui_blocked = false
	bed.interact(player)
	await process_frame
	await process_frame
	var ui := main.get_children().filter(func(n): return n is StorageUI)
	print("[E] no canteiro (nada pronto) abre o cesto: %s" % (not ui.is_empty()))
	for u in ui:
		u.close()
	# Desmontar o canteiro: o que estava no cesto cai no chão.
	placed.host_apply("remove", [bed.net_id])
	await physics_frame
	print("desmontou: cesto apagado=%s" % (not ContainerManager.i.contents.has("placed_%d" % r[0])))
	# --- Zumbis: velocidade e olhos
	var speeds := []
	var zs := []
	for k in 6:
		var z: Zombie = load("res://scenes/zombie.tscn").instantiate()
		z.position = player.global_position + Vector3(k * 2.0 - 5.0, 0.3, 12)
		main.get_node("Enemies").add_child(z)
		zs.append(z)
		speeds.append(snappedf(z.move_speed, 0.01))
	print("velocidades (base 1,6 x0,85..1,25 x1,25 = 1,70..2,50): %s" % [speeds])
	await physics_frame
	var z0: Zombie = zs[0]
	var rig: HumanoidRig = z0.skeleton
	var before: Material = rig.skin_mesh.get_surface_override_material(1)
	z0.take_hit(HitInfo.make(500.0, &"Chest", z0.global_position + Vector3.UP, Vector3.FORWARD, 30.0))
	await physics_frame
	var mid: StandardMaterial3D = rig.skin_mesh.get_surface_override_material(1)
	for k in 40:
		await physics_frame
	var after: StandardMaterial3D = rig.skin_mesh.get_surface_override_material(1)
	print("olhos: vivo override=%s | morreu: apagados=%s, logo depois brilho=%.2f, 0,7 s depois brilho=%s cor=%s" % [before,
		rig.eyes_dead, mid.emission_energy_multiplier if mid else -1.0, after.emission_enabled and after.emission_energy_multiplier > 0.01 if after else "?",
		after.albedo_color if after else Color()])
	var z1: Zombie = zs[1]
	z1.take_hit(HitInfo.make(15.0, &"Chest", z1.global_position + Vector3.UP, Vector3.FORWARD, 400.0))
	await physics_frame
	print("zumbi derrubado (vivo, estado %s): olhos acesos=%s" % [Zombie.State.keys()[z1.state], not z1.skeleton.eyes_dead])
	# --- Lousa
	var r2 := placed.host_apply("place", ["drawboard", Transform3D(Basis(), at)])
	var board: PlacedObject = placed.objects[r2[0]]
	await physics_frame
	var canvas: MeshInstance3D = null
	for c in board.find_children("*", "MeshInstance3D", true, false):
		if c.mesh is QuadMesh:
			canvas = c
	print("lousa: tela em z=%.3f inclinação=%.2f (fundo termina em -0,010, ripas em +0,025)" % [canvas.position.z, canvas.rotation.x])
	# --- Painel das máquinas
	var hud := main.get_node("HUD")
	var panel: MachinePanel = hud.get_node("Root/MachinePanel")
	var qat := at + Vector3(6, 0, 0)
	qat.y = terrain.height_at(qat.x, qat.z)
	var r3 := placed.host_apply("place", ["quern", Transform3D(Basis(), qat)])
	var quern: PlacedObject = placed.objects[r3[0]]
	player.global_position = qat + Vector3(0, 0, 2.0)
	await physics_frame
	var aim := quern.global_position + Vector3.UP * 0.6
	var to := aim - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	for k in 20:
		await process_frame
	print("mirando: %s" % player._interact_target)
	print("painel da máquina visível=%s, texto embaixo da mira escondido=%s" % [panel.visible, not hud.prompt_label.visible])
	player.head.rotation.x = 1.2 # olha para o céu
	for k in 20:
		await process_frame
	print("sem mirar: painel visível=%s, texto volta=%s" % [panel.visible, hud.prompt_label.visible])
	quit()
