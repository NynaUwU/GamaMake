extends SceneTree
## Alcance das armas de fogo: zumbis parados a 15-120 m, mira no peito, 1 tiro de cada arma.
## (O recuo subia a mira antes de a bala sair: de ~30 m em diante o tiro passava por cima.)
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await process_frame
	var main: Node3D = current_scene
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	Cheats.ammo = true
	player.set_physics_process(false)
	var start := Vector3(60, 0, 60)
	start.y = terrain.height_at(start.x, start.z) + 0.05
	player.global_position = start
	terrain.update_around(start, -1, 200.0)
	for gun in [&"pistola", &"rifle", &"espingarda"]:
		player.inventory.add(gun)
		player.equip_item(gun)
		player._equip = 1.0
		for d in [15.0, 30.0, 50.0, 80.0, 120.0]:
			var z: Zombie = load("res://scenes/zombie.tscn").instantiate()
			var p := start + Vector3(0, 0, -d)
			p.y = terrain.height_at(p.x, p.z) + 0.05
			z.position = p
			main.get_node("Enemies").add_child(z)
			for k in 20:
				await physics_frame
			z.global_position = p
			z.velocity = Vector3.ZERO
			var chest := z.global_position + Vector3.UP * 1.3
			var eye := player.camera.global_position
			player.rotation.y = 0.0
			var look := chest - eye
			player.head.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
			await physics_frame
			player._fire_timer = 0.0
			player._reload_timer = 0.0
			player._ammo = 5
			player._aim = 1.0
			var before: float = z.health
			player._fire_pistol()
			await physics_frame
			print("%s a %3d m: vida %.0f -> %.0f %s (lod %d, hitboxes %s)" % [gun, d, before, z.health if is_instance_valid(z) else -1.0,
				"ACERTOU" if (not is_instance_valid(z) or z.health < before) else "errou", z._lod if is_instance_valid(z) else -1,
				z.hitboxes_active if is_instance_valid(z) else false])
			if is_instance_valid(z):
				z.queue_free()
			await physics_frame
	quit()
