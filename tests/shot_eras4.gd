extends SceneTree
## Fotos da fase 4 (SHOT=pasta): bancada química no mundo e a janela dela, minigame das
## válvulas (na faixa e com alarme), fábrica química contaminada de fora e de dentro (com
## o HUD: sem máscara e de máscara), cidade contaminada e o mapa com as zonas.

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


## Leva o jogador até lá e espera o terreno, a zona e as casas aparecerem.
func _travel(to: Vector3) -> void:
	player.global_position = to
	player.velocity = Vector3.ZERO
	terrain.update_around(to, -1, 200.0)
	var cities: CityManager = main.get_node_or_null("Cities")
	if cities:
		cities._update_cities(true)
	for k in 40:
		await process_frame


func _hold(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO


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
	var hud: CanvasLayer = main.get_node_or_null("HUD")
	hud.visible = false
	Weather.i.target_rain = 0.0
	Weather.i.rain = 0.0
	Weather.i._timer = 99999.0
	DayNight.i.hour = 15.5
	DayNight.i._apply()
	Progress.i.manuals[&"manual_quimico"] = true
	# --- Bancada química no mundo (acesa) e a janela com os reagentes.
	var o := player.global_position + Vector3(-36, 0, 26)
	var bench := _put("chem_bench", o)
	bench.extra.hot_until = placed.clock + 60.0
	bench.refresh(placed.clock)
	await _look(o + Vector3(0.6, 1.75, 2.3), o + Vector3(-0.1, 1.0, 0))
	await _shot("quimica_mundo", 40)
	var key := Smelting.key_of(bench)
	ContainerManager.i.host_apply("open", [key, ""])
	var slots: Array = ContainerManager.i.contents[key]
	slots[Smelting.INPUT] = {"id": &"salitre", "amount": 4}
	slots[Smithing.ALLOY] = {"id": &"enxofre", "amount": 3}
	slots[Smithing.EXTRA_SLOT] = {"id": &"carvao", "amount": 5}
	slots[Smelting.FUEL] = {"id": &"botijao", "amount": 1}
	for item in [[&"adubo", 9], [&"agua", 3], [&"oleo", 4], [&"alcool", 2], [&"farinha", 4]]:
		player.inventory.add(item[0], item[1])
	StorageUI.open_for(player, key, bench)
	await _shot("quimica_janela", 30)
	await _close_ui()
	# --- Minigame: reação no meio com os ponteiros na faixa; depois o alarme.
	var recipe: Dictionary = CraftingUI.RECIPES.filter(func(r): return r.id == &"acido")[0]
	var game := Minigame.play(player, "chemistry", {"item": recipe.id, "chem": recipe.chem, "amount": 1}, func(_q): pass) as ChemistryMinigame
	game.manual_input = false
	game.calm = true
	var mids := []
	for k in 3:
		mids.append((game.bands[k].x + game.bands[k].y) * 0.5)
	var dt := 1.0 / 30.0
	for k in 330:
		game.turn(0, (mids[0] - game.values[0]) * 1.2 * dt)
		game.turn(1, (game.values[1] - mids[1]) * 1.5 * dt)
		game.turn(2, (mids[2] - game.values[2]) * 1.5 * dt)
		game.step(dt)
	game._hover = 1
	await _shot("minigame_quimica", 6)
	game.valves = [1.0, 0.0, 0.2]
	for k in 120:
		game.step(dt)
		if game.stress > 0.55:
			break
	await _shot("minigame_quimica_alarme", 3)
	game.queue_free()
	await _close_ui()
	# --- Fábrica química: de fora (morro) e de dentro com o HUD.
	var plants := terrain.zones.filter(func(z): return z.kind == "plant")
	if not plants.is_empty():
		var zone: Dictionary = plants[0]
		var c := Vector3(zone.center.x, zone.base, zone.center.y)
		await _travel(c + Vector3(0, 2, 70))
		await _look(c + Vector3(-18, 16, 72), c + Vector3(0, 4, 0))
		await _shot("fabrica_quimica_fora", 60)
		# Dentro, sem máscara: tosse, tela verde e o medidor.
		hud.visible = true
		await _look(c + Vector3(-4, 1.7, 15), c + Vector3(-2, 4, -10))
		player.toxic = 0.0
		for k in 14:
			player._update_toxic(0.5)
		player.health = player.max_health
		await _shot("fabrica_dentro_sem_mascara", 20)
		# De máscara: as lentes e o filtro.
		player.toxic = 0.0
		player.sick_time = 0.0
		player.inventory.equipment.head = {"id": &"mascara_gas", "amount": 1, "filter": 0.62}
		player.inventory.changed.emit()
		player._update_toxic(0.5)
		await _look(c + Vector3(6, 1.7, 9), c + Vector3(4.5, 0.6, 6.5))
		await _shot("fabrica_dentro_mascara", 20)
		hud.visible = false
		player.inventory.equipment.head = {}
		player.toxic = 0.0
	# --- Cidade contaminada (de cima da borda).
	var cities := terrain.zones.filter(func(z): return z.kind == "city")
	if not cities.is_empty():
		var zone: Dictionary = cities[0]
		var c := Vector3(zone.center.x, zone.base, zone.center.y)
		var edge := c + Vector3(zone.radius + 25.0, 0, 0)
		await _travel(edge)
		await _look(edge + Vector3(10, 28, 6), c + Vector3(0, 4, 0))
		await _shot("cidade_contaminada", 90)
	# --- Mapa com as zonas.
	hud.visible = true
	await _travel(o)
	player.toxic = 0.0
	var map := main.find_children("*", "WorldMap", true, false)
	if not map.is_empty():
		map[0]._big_open = true
		map[0]._big.visible = true
		await _shot("mapa_zonas", 90)
	quit()
