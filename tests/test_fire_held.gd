extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	var inv := player.inventory
	var o := player.global_position
	var cf := placed.host_apply("place", ["campfire", Transform3D(Basis(), o - player.global_basis.z * 3.0)])
	var fire: PlacedObject = placed.objects[cf[0]]
	fire.refresh(placed.clock)
	print("fogueira nova acesa? ", fire.is_lit(), " texto=", fire.get_interact_text(), " luz visível=", fire.get_meta("lit"))
	inv.select(0)
	inv.slots[0] = {"id": &"batata", "amount": 2}
	Cooking.interact(player, fire)
	print("apagada e sem lenha: batata entrou? ", fire.crops.any(func(c): return not c.is_empty()))
	inv.slots[30] = {"id": &"tronco", "amount": 2}
	Cooking.interact(player, fire)
	fire.refresh(placed.clock)
	print("com 1 tronco: acesa=", fire.is_lit(), " texto=", fire.get_interact_text(), " troncos=", inv.count(&"tronco"))
	Cooking.interact(player, fire)
	print("acesa: batata entrou? ", fire.crops.any(func(c): return not c.is_empty()))
	placed.clock += 901.0
	fire.refresh(placed.clock)
	print("15 min depois: acesa=", fire.is_lit(), " luz=", fire.get_meta("lit"))
	# Fornalha só acesa queimando
	var fr := placed.host_apply("place", ["furnace", Transform3D(Basis(), o + Vector3(5, 0, 0))])
	var furnace: PlacedObject = placed.objects[fr[0]]
	furnace.refresh(placed.clock)
	var lit_before = furnace.get_meta("lit")
	ContainerManager.i.host_apply("open", [Smelting.key_of(furnace), ""])
	ContainerManager.i.host_apply("put_at", [Smelting.key_of(furnace), 0, "minerio_cobre", 2, 1.0])
	ContainerManager.i.host_apply("put_at", [Smelting.key_of(furnace), 1, "graveto", 1, 1.0])
	placed._smelt()
	furnace.refresh(placed.clock)
	var lit_mid = furnace.get_meta("lit")
	for k in 8:
		placed._smelt()
	furnace.refresh(placed.clock)
	print("fornalha: antes=", lit_before, " queimando=", lit_mid, " acabou=", furnace.get_meta("lit"))
	# Item na mão
	inv.slots[0] = {"id": &"cenoura", "amount": 1}
	inv.select(0)
	player._sync_equipped()
	player._update_held()
	print("cenoura na mão visível: ", player._held != null and player._held.visible)
	quit()
