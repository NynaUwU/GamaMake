extends SceneTree
## Fotos da fase 1 das eras (SHOT=pasta): forja e trefiladora no mundo, janela da
## forja, minigame (no fogo e na bigorna, com a tabela de cores), diário e aviso de era.

var main: Node3D
var player: Player
var placed: PlacedManager
var terrain: TerrainWorld


func _shot(name: String, frames := 30) -> void:
	for k in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/" + name + ".png")


func _look(from: Vector3, at: Vector3) -> void:
	player.global_position = from - Vector3(0, 1.6, 0)
	player.velocity = Vector3.ZERO
	await process_frame
	var to := at - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _put(kind: String, pos: Vector3, yaw := 0.0) -> PlacedObject:
	var id: int = placed._next_id
	placed._spawn(id, kind, Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, terrain.height_at(pos.x, pos.z), pos.z)), true)
	return placed.objects[id]


func _close_ui() -> void:
	for node in main.get_children():
		if node is StorageUI or node is JournalUI or node is Minigame:
			node.queue_free()
	player.ui_blocked = false
	await process_frame


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	main = current_scene
	player = main.player
	placed = main.get_node("Placed")
	terrain = main.get_node("Terrain")
	for e in main.get_node("Enemies").get_children():
		e.free()
	var hud := main.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	Weather.i.target_rain = 0.0
	Weather.i.rain = 0.0
	Weather.i._timer = 99999.0
	DayNight.i.hour = 17.2
	DayNight.i._apply()
	var o := player.global_position + Vector3(-36, 0, 26)
	var forge := _put("forge", o)
	forge.extra.hot_until = placed.clock + 30.0
	var drawer := _put("wire_drawer", o + Vector3(3.2, 0, 0.6))
	drawer.extra.speed = 1.0
	var wheel_motor := _put("electric_motor", Vector3.ZERO)
	var port: Array = Power.world_ports(drawer)[0]
	wheel_motor.global_transform = Transform3D(Basis(port[1], Vector3.UP, port[1].cross(Vector3.UP)), port[0])
	for obj in placed.objects.values():
		obj.refresh(placed.clock)
	await _look(o + Vector3(1.6, 1.7, 3.6), o + Vector3(0.6, 0.7, 0.2))
	await _shot("forja_mundo", 40)
	await _look(o + Vector3(4.6, 1.5, 2.6), o + Vector3(3.1, 0.6, 0.5))
	await _shot("trefiladora", 20)
	# Janela da forja com metal e carvão.
	Progress.i.manuals[&"manual_ferreiro"] = true
	var key := Smelting.key_of(forge)
	ContainerManager.i.host_apply("open", [key, ""])
	var slots: Array = ContainerManager.i.contents[key]
	slots[Smelting.INPUT] = {"id": &"barra_ferro", "amount": 5}
	slots[Smelting.FUEL] = {"id": &"carvao", "amount": 4}
	player.inventory.add(&"barra_aco", 2)
	StorageUI.open_for(player, key, forge)
	await _shot("forja_janela", 30)
	await _close_ui()
	# Minigame: no fogo com o fole, e na bigorna no meio do trabalho.
	var game := Minigame.play(player, "forge", {"item": &"espada", "metal": &"barra_ferro", "hits": 12, "chart": true}, func(_q): pass) as ForgeMinigame
	game.manual_input = false
	game.bellows = true
	for k in 25: # a renderização por software é lenta: segura a temperatura no laranja
		game.temp = 0.56
		await process_frame
	await _shot("minigame_fogo", 1)
	game.bellows = false
	game._msg_time = 0.0
	game.in_fire = false
	game._piece.position = ForgeMinigame.ANVIL_AT
	game.temp = 0.72
	game.hits = 7
	game.cracks = 1
	game.score = 6.4
	game._swing = 0.9
	game._burst(16, Color(1.0, 0.75, 0.3), 1.0)
	for k in 3:
		game.temp = 0.72
		game._swing = 0.9
		await process_frame
	await _shot("minigame_bigorna", 1)
	game.temp = 0.3
	game._say("Frio demais: rachou!", 3.0)
	await _shot("minigame_frio", 6)
	game.queue_free()
	await _close_ui()
	# Diário: eras e receitas (algumas conquistas feitas).
	for e in ["get:sucata", "craft:machado_simples", "place:campfire", "get:agua", "place:forge", "get:barra_ferro"]:
		var parts: PackedStringArray = e.split(":")
		Progress.event(parts[0], parts[1])
	for id in [&"tabua", &"graveto", &"machado", &"picareta", &"barra_ferro", &"vidro", &"espada", &"tocha", &"cabo", &"bandagem"]:
		Progress.i.recipes[id] = true
	Progress.add_clue("Rádio: horda grande vindo do norte nesta noite.")
	Progress.i._queue.clear()
	Progress.i._toast.visible = false
	JournalUI.tab = "Eras"
	JournalUI.open_for(player)
	await _shot("diario_eras", 20)
	await _close_ui()
	JournalUI.tab = "Receitas"
	JournalUI.open_for(player)
	await _shot("diario_receitas", 20)
	await _close_ui()
	# Aviso de era nova (o banner do meio) por cima do jogo.
	await _look(o + Vector3(1.6, 1.7, 3.6), o + Vector3(0.6, 0.7, 0.2))
	Progress.event("forge", "espada")
	await _shot("aviso_conquista", 8)
	Progress.i._next_toast() # pula para o aviso da era nova
	await _shot("aviso_era", 8)
	quit()
