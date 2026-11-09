extends SceneTree
## Botão de qualidade do menu de pausa: troca Baixa/Média/Alta várias vezes (com o jogo
## pausado, como no menu) e mostra o que mudou; erros aparecem no log.

func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var pause: PauseMenu = main.get_node("PauseMenu")
	pause.open() if pause.has_method("open") else null
	await process_frame
	var env: Environment = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sun := main.get_node("Sun") as DirectionalLight3D
	var grass := main.get_node("Grass")
	var button: Button = null
	for node in pause.find_children("*", "Button", true, false):
		if (node as Button).text.begins_with("Gráficos"):
			button = node
	for k in 4:
		var before := Look.quality()
		button.pressed.emit() # o clique de verdade no botão do menu de pausa
		for f in 10:
			await process_frame
		print("qualidade %s -> %s: glow %s, ssao %s, sombra %.0f m, grama raio %.0f, texto do botão '%s'" % [Look.NAMES[before], Look.NAMES[Look.quality()],
			env.glow_enabled, env.ssao_enabled, sun.directional_shadow_max_distance, grass._radius, button.text])
	quit()
