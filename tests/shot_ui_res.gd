extends SceneTree
## Fotos (SHOT=pasta) da interface na resolução da janela com o 3D em 540 linhas:
## jogo com HUD, diário (receitas com ingredientes e NOVA), inventário e pausa.

var main: Node3D
var player: Player
var placed: PlacedManager


func _shot(name: String, frames := 30) -> void:
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
	placed = main.get_node("Placed")
	for e in main.get_node("Enemies").get_children():
		e.free()
	Weather.i.target_rain = 0.0
	Weather.i.rain = 0.0
	DayNight.i.hour = 10.0
	DayNight.i._apply()
	for item in [[&"tabua", 30], [&"pedra", 12], [&"sucata", 8], [&"machado", 1], [&"carne_crua", 4], [&"batata", 6]]:
		player.inventory.add(item[0], item[1])
	print("janela %s, 3D %s, base da interface %s" % [get_root().size, Vector2(get_root().size) * get_root().scaling_3d_scale, get_root().get_visible_rect().size])
	await _shot("jogo_hud", 40)
	for kind in ["campfire", "furnace", "dryer"]:
		var id: int = placed._next_id
		placed._spawn(id, kind, Transform3D(Basis(), player.global_position + Vector3(3 + id, 0, -4)))
		Progress.event("place", kind)
	Progress.i._queue.clear()
	JournalUI.tab = "Receitas"
	JournalUI.open_for(player)
	await _shot("diario_receitas", 20)
	for node in main.get_children():
		if node is JournalUI:
			node.close()
	await process_frame
	var inv: InventoryUI = main.get_node("HUD").find_children("*", "InventoryUI", true, false)[0]
	inv._set_open(true)
	await _shot("inventario", 15)
	inv._set_open(false)
	var pause: PauseMenu = main.get_node("PauseMenu")
	pause.open()
	await _shot("pausa", 15)
	quit()
