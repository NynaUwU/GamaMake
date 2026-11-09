extends SceneTree
## Fotos das armas de fogo (SHOT=pasta): cada arma no quadril e mirando (mira de ferro),
## o rifle pela luneta e um zumbi na frente para dar a escala.

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
	var zombies := main.get_node("Enemies").get_children().filter(func(n): return n is Zombie)
	for k in zombies.size():
		var z: Zombie = zombies[k]
		z.detect_range = 0.0
		z.global_position = player.global_position + (Vector3(0.6, 0, -9.0) if k == 0 else Vector3(80 + k * 3, 0, 80))
		z.rotation.y = PI
		z.velocity = Vector3.ZERO
	Weather.i.target_rain = 0.0
	Weather.i.rain = 0.0
	Weather.i._timer = 99999.0
	DayNight.i.hour = 10.5
	DayNight.i._apply()
	player.set_physics_process(false)
	player.head.rotation.x = 0.02
	for item in [[&"cartucho", 12], [&"bala_rifle", 6], [&"cartucho_espingarda", 6]]:
		player.inventory.add(item[0], item[1])
	for id in [&"pistola", &"rifle", &"espingarda", &"rifle_luneta"]:
		player.inventory.add(id)
		player.equip_item(id)
		player._start_reload()
		for k in 30:
			player._update_pistol(0.1)
		Input.action_release("block")
		for k in 30:
			player._update_pistol(0.05)
		await _shot("arma_%s_quadril" % id, 25)
		Input.action_press("block")
		for k in 30:
			player._update_pistol(0.05)
		await _shot("arma_%s_mirando" % id, 10)
		Input.action_release("block")
		for k in 30:
			player._update_pistol(0.05)
	quit()
