extends SceneTree
## Fotos (SHOT=pasta): HUD sem a lista de teclas, menu do ESC, controles, admin com
## algumas trapaças ligadas, "dar itens" e a mochila com um item pego seguindo o mouse.

var main: Node3D
var player: Player


func _shot(name: String, frames := 15) -> void:
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
	Weather.i.target_rain = 0.0
	Weather.i.rain = 0.0
	DayNight.i.hour = 10.0
	DayNight.i._apply()
	for item in [[&"tabua", 30], [&"pedra", 12], [&"machado", 1], [&"pistola", 1], [&"cartucho", 18], [&"batata", 6], [&"barra_ferro", 8]]:
		player.inventory.add(item[0], item[1])
	await _shot("hud_limpo", 30)
	var pause: PauseMenu = main.get_node("PauseMenu")
	pause.open()
	await _shot("esc_menu")
	pause._show(pause._controls_box)
	await _shot("esc_controles")
	pause._open_admin()
	for flag in ["god", "ammo", "invisible"]:
		pause._admin._toggle(flag)
	pause._admin._say("Vida infinita, munição infinita e invisível ligadas")
	await _shot("esc_admin")
	pause._admin.box.visible = false
	pause._admin.items_box.visible = true
	pause._admin._fill_items()
	await _shot("esc_admin_itens", 25)
	pause.close()
	Cheats.reset()
	var inv: InventoryUI = main.get_node("HUD").find_children("*", "InventoryUI", true, false)[0]
	inv._set_open(true)
	await process_frame
	var size := get_root().get_visible_rect().size
	Input.warp_mouse(Vector2(size.x * 0.5 + 40, size.y * 0.5 + 120))
	inv._click_slot(Inventory.HOTBAR_SIZE) # pega a primeira pilha da mochila
	await _shot("mochila_item_pego", 10)
	quit()
