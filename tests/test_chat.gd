extends SceneTree
## Fase 5: chat (mensagem, comandos do host) e ping.
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 20:
		await process_frame
	var main := current_scene
	var chat: Chat = Chat.i
	chat._submit("olá mundo")
	chat._submit("/noite")
	chat._submit("/hora 13")
	chat._submit("/xyz")
	var lines := chat._log.get_children().map(func(l): return l.text)
	print("chat: ", lines)
	print("hora agora: ", DayNight.i.clock_text())
	var player: Player = main.player
	player.head.rotation.x = -0.6
	await physics_frame
	PingMarkers.ping_from(player)
	await process_frame
	print("pings=", PingMarkers.i.list.size(), " tipo=", PingMarkers.i.list[0].kind if PingMarkers.i.list.size() > 0 else "-")
	quit()
