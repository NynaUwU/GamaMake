extends SceneTree
## Fotos do Tier 4 (SHOT=pasta): rede elétrica de dia e de noite (postes com cabos
## pendurados, painel solar, bateria, dínamo, bomba, cerca, lampadários), casa
## decorada por dentro com arandelas acesas, tocha na parede e o menu do martelo.

var main: Node3D
var player: Player
var placed: PlacedManager
var terrain: TerrainWorld


func _shot(name: String, frames := 25) -> void:
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


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, terrain.height_at(p.x, p.z), p.z)


func _put(kind: String, pos: Vector3, yaw := 0.0) -> PlacedObject:
	var id: int = placed._next_id
	placed._spawn(id, kind, Transform3D(Basis(Vector3.UP, yaw), pos), true)
	return placed.objects[id]


## Na parede: raio de "from" na direção "dir"; o objeto fica de frente para fora dela.
func _on_wall(kind: String, from: Vector3, dir: Vector3) -> PlacedObject:
	var hit := main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 6.0, 1))
	if hit.is_empty():
		push_warning("sem parede para " + kind)
		return null
	var n: Vector3 = hit.normal
	var flat := Vector3(n.x, 0, n.z).normalized()
	var id: int = placed._next_id
	placed._spawn(id, kind, Transform3D(Basis.looking_at(-flat, Vector3.UP), hit.position + flat * 0.005), true)
	return placed.objects[id]


func _wire(a: PlacedObject, b: PlacedObject) -> void:
	placed.host_apply("cable", [a.net_id, b.net_id])


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
	var bm: BuildingManager = main.get_node("Building")
	# Casa 2x2 (5,6 m) com teto, porta virada para -Z (sem a parede da frente da esquerda).
	var cx := 55
	var cz := 30
	var cy := floori(terrain.height_at(cx * 0.4 + 2.8, cz * 0.4 + 2.8) / 0.4)
	for k in 2:
		if k == 1:
			bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx + 7 * k, cy, cz), 0])
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx + 7 * k, cy, cz + 14), 0])
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx, cy, cz + 7 * k), 1])
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx + 14, cy, cz + 7 * k), 1])
		for j in 2:
			bm.host_apply("place", [BuildPiece.Kind.FLOOR, Vector3i(cx + 7 * k, cy, cz + 7 * j), 0])
			bm.host_apply("place", [BuildPiece.Kind.ROOF, Vector3i(cx + 7 * k, cy + 7, cz + 7 * j), 0])
	var floor_y := (cy + 1) * 0.4
	var house := Vector3((cx + 7) * 0.4, floor_y, (cz + 7) * 0.4)
	# Dentro: decoração + arandelas.
	var inside := house + Vector3(0, 1.4, 0)
	var painting := _on_wall("deco_painting", inside + Vector3(-1.0, 0.3, 0), Vector3.BACK)
	_on_wall("deco_clock", inside + Vector3(1.2, 0.5, 0), Vector3.BACK)
	_on_wall("deco_shelf", inside + Vector3(0, 0.1, 1.0), Vector3.RIGHT)
	var lamp_in := _on_wall("lamp_wall", inside + Vector3(0.2, 0.6, 0), Vector3.BACK)
	var lamp_in2 := _on_wall("lamp_wall", inside + Vector3(0, 0.6, -1.0), Vector3.LEFT)
	_put("deco_rug", house + Vector3(0, 0, 0.3))
	_put("deco_table", house + Vector3(0.2, 0, 0.6))
	_put("deco_chair", house + Vector3(-0.55, 0, 0.6), PI / 2)
	_put("deco_chair", house + Vector3(0.95, 0, 0.6), -PI / 2)
	_put("deco_vase", house + Vector3(0.3, 0.78, 0.6))
	_put("deco_plant", house + Vector3(2.1, 0, 2.1))
	_put("deco_barrel", house + Vector3(-2.1, 0, 2.1))
	_put("deco_crates", house + Vector3(-1.9, 0, -1.6), 0.3)
	_put("deco_stool", house + Vector3(1.6, 0, -1.2))
	var fridge := _put("fridge", house + Vector3(2.1, 0, -0.4), -PI / 2)
	var radio := _put("radio", house + Vector3(1.9, 0, 1.2), -PI / 2)
	# Fora: rede elétrica (painel, bateria, dínamo, bomba, postes, cerca, lampadários).
	var yard := _ground(house + Vector3(0, 0, -7.0))
	var solar := _put("solar_panel", _ground(yard + Vector3(-4.5, 0, -1.0)), PI)
	var battery := _put("battery", _ground(yard + Vector3(-2.6, 0, 0.4)))
	var dynamo := _put("dynamo", _ground(yard + Vector3(4.6, 0, 0.2)))
	var pump := _put("electric_pump", _ground(yard + Vector3(6.4, 0, -2.0)))
	var post_a := _put("connector", _ground(yard + Vector3(-0.8, 0, 1.5)))
	var post_b := _put("connector", _ground(yard + Vector3(2.6, 0, -3.5)))
	var fence := _put("electric_fence", _ground(yard + Vector3(-1.5, 0, -5.5)))
	var fence2 := _put("electric_fence", _ground(yard + Vector3(1.0, 0, -5.5)))
	var lamp_a := _put("lamp", _ground(yard + Vector3(0.8, 0, -1.2)))
	var lamp_b := _put("lamp", _ground(yard + Vector3(-3.4, 0, -3.6)))
	var wall_box := _on_wall("connector_wall", Vector3(house.x + 0.5, floor_y + 2.2, yard.z), Vector3.BACK)
	# Dentro: interruptor na parede e isoladores de cerâmica levando o fio rente à parede.
	var sw := _on_wall("switch_wall", inside + Vector3(1.2, -0.2, -2.0), Vector3.FORWARD)
	var ins := []
	for k in 3:
		ins.append(_on_wall("insulator", inside + Vector3(1.2 - k * 0.8, 0.9, 0), Vector3.BACK))
	var torch := _on_wall("torch_wall", Vector3(house.x + 2.2, floor_y + 1.5, yard.z), Vector3.BACK)
	if torch:
		torch.extra.fuel_until = placed.clock + 900.0
		torch.refresh(placed.clock)
	for pair in [[solar, battery], [battery, post_a], [post_a, lamp_a], [post_a, post_b], [post_b, dynamo], [post_b, pump],
			[post_b, fence2], [fence2, fence], [battery, lamp_b], [post_a, wall_box], [wall_box, sw], [sw, ins[0]], [ins[0], ins[1]],
			[ins[1], ins[2]], [ins[2], lamp_in], [lamp_in, lamp_in2], [lamp_in, fridge], [lamp_in2, radio]]:
		if pair[0] and pair[1]:
			_wire(pair[0], pair[1])
	battery.extra.cells = 5
	battery.extra.charge = Electric.capacity(battery) * 0.7
	# Máquinas automáticas no quintal: assador com motor (carne no espeto), moinho com motor,
	# pedra de amolar com motor e um machado afiando.
	var shop := _ground(house + Vector3(9.0, 0, -2.0))
	var autos := {}
	for k in ["rotisserie", "quern", "grindstone", "sieve"].size():
		var kind: String = ["rotisserie", "quern", "grindstone", "sieve"][k]
		var m := _put(kind, _ground(shop + Vector3(0, 0, k * 2.2)))
		var p: Array = Power.world_ports(m)[0]
		var mo := _put("electric_motor", p[0])
		mo.global_basis = Basis(p[1], Vector3.UP, p[1].cross(Vector3.UP))
		_wire(mo, battery) if mo.global_position.distance_to(battery.global_position) < 11.0 else _wire(mo, post_b)
		autos[kind] = m
	autos.rotisserie.extra.fuel_until = placed.clock + 9999.0
	for k in 4:
		autos.rotisserie.crops[k] = Cooking.make_entry("rotisserie", [&"carne_crua", &"batata", &"carne_crua", &"cenoura"][k], placed.clock - 30.0 * (k % 2))
	autos.quern.extra["in"] = 20
	autos.sieve.extra["in"] = 20
	autos.grindstone.extra.tool = {"id": "machado", "dur": 0.6, "sharp": 0.2}
	Power.dirty = true
	for k in 3:
		placed._power()
		placed._electric()
		placed._power()
	for k in 3:
		placed._electric()
	placed._process(0.0)
	# --- Dia: a rede vista do quintal.
	DayNight.i.hour = 10.5
	DayNight.i._apply()
	await _look(yard + Vector3(-2.5, 2.3, -7.5), yard + Vector3(0.8, 0.7, -0.5))
	await _shot("eletrica_dia", 40)
	# --- Noite: lampadários e tocha acesos.
	DayNight.i.hour = 22.0
	DayNight.i._apply()
	for k in 2:
		placed._electric()
	await _look(yard + Vector3(-2.5, 2.3, -7.5), yard + Vector3(0.8, 0.7, -0.5))
	await _shot("eletrica_noite", 30)
	# --- Dentro de casa, de noite, com as arandelas acesas.
	await _look(house + Vector3(-1.6, 1.65, -2.2), house + Vector3(0.6, 1.0, 1.6))
	await _shot("casa_decorada", 30)
	# --- De dia, dentro (sem as luzes), para ver as cores.
	DayNight.i.hour = 13.0
	DayNight.i._apply()
	await _look(house + Vector3(2.0, 1.65, -2.0), house + Vector3(-1.0, 1.0, 1.4))
	await _shot("casa_dia", 30)
	# --- Máquinas automáticas com motor elétrico, de perto.
	DayNight.i.hour = 17.0
	DayNight.i._apply()
	for k in 2:
		placed._power()
		placed._electric()
	for obj in autos.values():
		obj.refresh(placed.clock)
	await _look(shop + Vector3(-3.4, 1.8, -1.6), shop + Vector3(0.3, 0.5, 2.2))
	await _shot("maquinas_auto", 40)
	# --- Fileira de modelos de perto (estúdio no quintal).
	var row := _ground(house + Vector3(12.0, 0, -6.0))
	var kinds := ["connector", "switch", "dynamo", "solar_panel", "battery", "lamp", "electric_pump", "fridge", "radio"]
	for k in kinds.size():
		var o := _put(kinds[k], _ground(row + Vector3(k * 1.4, 0, 0)))
		if kinds[k] == "battery":
			o.extra.cells = 4
			o.extra.charge = 300.0
			o.refresh(placed.clock)
		if kinds[k] == "dynamo":
			o.extra.gauge = 0.6
			o.refresh(placed.clock)
	await _look(row + Vector3(5.2, 1.9, 4.4), row + Vector3(5.2, 0.6, 0.0))
	await _shot("modelos_eletricos", 30)
	# --- Menu do martelo na aba Elétrica.
	player.inventory.add(&"martelo", 1)
	player.inventory.selected = player.inventory.slots.find(player.inventory.slots.filter(func(s): return not s.is_empty() and s.id == &"martelo")[0])
	for k in 5:
		await process_frame
	if player.builder:
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.pressed = true
		Input.parse_input_event(right) # o menu fica aberto enquanto o botão direito está apertado
		player.builder.open_menu()
		player.builder._menu._set_tab("Elétrica")
	await _shot("menu_martelo", 10)
	quit()
