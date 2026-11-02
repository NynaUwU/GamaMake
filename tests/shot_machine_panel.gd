extends SceneTree
## Fotos do painel pequeno das máquinas (mirando caldeira, moinho, fornalha de
## pedra, bebedouro) e do canteiro com o cesto (SHOT=pasta).
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	var main := current_scene
	var placed: PlacedManager = main.get_node("Placed")
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	for e in main.get_node("Enemies").get_children():
		e.free()
	var out := OS.get_environment("SHOT")
	var shots := [["boiler", Vector3(0, 1.2, 0)], ["quern", Vector3(0, 0.6, 0)], ["stone_furnace", Vector3(0, 0.8, 0)], ["water_trough", Vector3(0, 0.3, 0)], ["bed", Vector3(1.4, 0.4, 1.4)]]
	var i := 0
	for shot in shots:
		var kind: String = shot[0]
		var at := player.global_position - player.global_basis.z * 3.2 + Vector3(i * 9.0, 0, 0)
		at.y = terrain.height_at(at.x, at.z)
		var r := placed.host_apply("place", [kind, Transform3D(Basis(Vector3.UP, player.rotation.y), at)])
		var obj: PlacedObject = placed.objects[r[0]]
		match kind:
			"boiler":
				ContainerManager.i.contents[Smelting.key_of(obj)] = [{}, {"id": &"carvao", "amount": 12}, {}]
				obj.extra.merge({"burn": 25.0, "burn_max": 40.0, "heat": 0.85, "water": 12.0, "pressure": 1.1}, true)
			"quern":
				obj.extra.merge({"in": 3, "out": 1}, true)
			"stone_furnace":
				obj.extra.merge({"heat": 0.6, "ht": placed.clock}, true)
			"water_trough":
				obj.extra.water = 5.0
			"bed":
				for s in [0, 1, 2, 3, 5]:
					placed.host_apply("plant", [obj.net_id, s, ["trigo", "cenoura", "batata", "trigo", "abobora"][s % 5]])
				var basket := ContainerManager.empty_slots(ContainerManager.STORAGE_SLOTS)
				ContainerManager.add_to(basket, &"cenoura", 5)
				ContainerManager.add_to(basket, &"semente_cenoura", 2)
				ContainerManager.i.contents[obj.basket_key()] = basket
				placed.clock += 140.0
				PlacedManager.grow_clock += 700.0
		obj.refresh(placed.clock)
		var aim: Vector3 = obj.to_global(shot[1])
		player.global_position = aim + (player.global_basis.z * (2.6 if shot[1].y > 0.5 else 1.7)) + Vector3(0, -aim.y + at.y, 0)
		await process_frame
		var eye := player.camera.global_position
		var to := aim - eye
		player.rotation.y = atan2(-to.x, -to.z)
		player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
		for k in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(out + "/painel_%s.png" % kind)
		i += 1
	quit()
