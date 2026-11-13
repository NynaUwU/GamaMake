extends SceneTree
## Fotos do golpe da picareta em 1ª pessoa (SHOT=pasta): levantando, no alto, descendo e
## cravada no chão. O tempo do jogo anda devagar para pegar cada fase.
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	var main := current_scene
	var player: Player = main.player
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	player.set_physics_process(false)
	player.inventory.add(&"picareta")
	player.equip_item(&"picareta")
	player._equip = 1.0
	player.head.rotation.x = -0.55
	for k in 30:
		await process_frame
	Engine.time_scale = 0.1
	player._melee_attack()
	var phases := []
	var shots := 0
	var last := ""
	while player._swing_phase != Player.SwingPhase.NONE and shots < 12:
		await RenderingServer.frame_post_draw
		var name := "picareta_%02d_%s" % [shots, ["parada", "levantando", "golpe", "volta"][player._swing_phase]]
		get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/" + name + ".png")
		phases.append("%s ângulo %.2f" % [name, player._swing_angle])
		shots += 1
		for k in 2:
			await process_frame
	print("\n".join(phases))
	Engine.time_scale = 1.0
	quit()
