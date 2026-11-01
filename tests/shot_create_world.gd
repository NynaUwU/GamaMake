extends SceneTree
## Foto da tela "Criar mundo" (SHOT=pasta). Uso: xvfb-run ... -s res://tests/shot_create_world.gd
func _init() -> void:
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	for k in 10:
		await process_frame
	WorldSettings.values = {"mountains": 160.0, "island": 78.0, "temperature": -30.0}
	var t0 := Time.get_ticks_msec()
	current_scene._show_create(false)
	while current_scene._preview_busy or current_scene._preview.texture == null:
		await process_frame
	print("prévia em %d ms: %s" % [Time.get_ticks_msec() - t0, current_scene._preview_info.text])
	for k in 5:
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/criar_mundo.png")
	quit()
