extends SceneTree
## Fotos (SHOT=pasta): menu de gráficos no ESC, a mesma cena em Média, Clássico (como
## antes), Alta, sem filtro retrô em 1080 linhas e com a grade do terreno.

var main: Node3D
var player: Player


func _shot(name: String, frames := 20) -> void:
	for k in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/" + name + ".png")


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	main = current_scene
	player = main.player
	var keep := {}
	for key in Look.DEFAULTS:
		keep[key] = Look.get_setting(key)
	Look.set_preset("medium")
	Weather.i.target_rain = 0.0
	Weather.i.rain = 0.0
	DayNight.i.hour = 16.0
	DayNight.i._apply()
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	var terrain: TerrainWorld = main.get_node("Terrain")
	player.set_physics_process(false)
	var at := Vector3(96, 0, 60)
	player.global_position = Vector3(at.x, terrain.height_at(at.x, at.z) + 0.3, at.z)
	player.rotation.y = 2.4
	player.head.rotation.x = -0.12
	terrain.update_around(player.global_position, -1, 160.0)
	await _shot("grafico_media", 60)
	var pause: PauseMenu = main.get_node("PauseMenu")
	pause.open()
	pause._open_graphics()
	await _shot("grafico_menu", 15)
	pause.close()
	Look.set_preset("classic")
	await _shot("grafico_classico", 25)
	Look.set_preset("high")
	await _shot("grafico_alta", 25)
	Look.set_preset("medium")
	Look.set_setting("lines", 1080)
	Look.set_setting("retro", false)
	await _shot("grafico_1080_sem_retro", 25)
	Look.set_setting("lines", 540)
	Look.set_setting("retro", true)
	Look.set_setting("grid", true)
	player.head.rotation.x = -0.55
	await _shot("grafico_grade_terreno", 25)
	for key in keep:
		Look._settings[key] = keep[key]
	Look._save_and_apply()
	quit()
