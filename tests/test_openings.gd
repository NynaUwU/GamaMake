extends SceneTree
## Talhadeira arrastando (área), janela preenchendo um buraco, porta (só em
## buraco encostado no chão) abrindo com E.
var main: Node
var player: Player
var manager: BuildingManager
var wall: BuildPiece
var frame := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _aim(point: Vector3) -> void:
	var eye := player.camera.global_position
	var to := point - eye
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())

func _square_center(i: int, j: int) -> Vector3:
	return wall.to_global(Vector3((i + 0.5) * BuildPiece.SEG, (j + 0.5) * BuildPiece.SEG, 0))

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		player = main.get_node("Player")
		manager = main.get_node("Building")
		for e in main.get_node("Enemies").get_children():
			e.queue_free()
		manager.request_place(BuildPiece.Kind.WALL, Vector3i(-5, 0, 40), 0) # parede em z = 16, x de -2 a 0.8
		wall = manager.pieces.values()[0]
		player.global_position = Vector3(-0.6, 0.3, 19.0)
		player.equip_item(&"talhadeira")
		for id in [&"tabua", &"pedra", &"sucata"]:
			player.inventory.add(id, 60) # construir gasta material
	if frame == 20:
		_aim(_square_center(3, 3))
	if frame == 24:
		Input.action_press("attack")
		player._use_tool() # começa a arrastar no quadrado (3, 3)
	if frame == 26:
		_aim(_square_center(5, 4)) # arrasta até (5, 4)
	if frame == 32:
		print("selecionados arrastando=", player.builder.cut_selection.size())
		Input.action_release("attack")
	if frame == 36:
		print("tirados depois de soltar=", wall.removed.count(1), " (esperado 24: 3x2 quadrados x 4 quartos)")
		player.equip_item(&"martelo")
		player.builder.select(Builder.ENTRIES["Aberturas"][1]) # porta no buraco solto: não pode
		_aim(_square_center(4, 3))
	if frame == 60:
		print("porta no buraco do meio: válido=", player.builder.fill_target.get("valid"))
		player.builder.select(Builder.ENTRIES["Aberturas"][0]) # janela
	if frame == 64:
		print("janela: alvo com ", player.builder.fill_target.get("tris", []).size(), " triângulos, válido=", player.builder.fill_target.get("valid"))
		player._use_tool()
	if frame == 70:
		print("janelas/portas na parede=", wall.fills.size(), " tipo=", wall.fills[0].type if wall.fills.size() > 0 else "-")
		var c := _square_center(4, 3)
		var q := PhysicsRayQueryParameters3D.create(c + wall.global_basis.z, c - wall.global_basis.z)
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		print("raio pelo vidro bate na janela? ", hit.collider is BuildFill if hit else false)
		# Buraco de porta: quadrados 0..1 na base (j 0..4).
		var door := PackedInt32Array()
		for j in 5:
			for i in 2:
				for part in 4:
					door.append((j * BuildPiece.N + i) * 4 + part)
		manager.request_cut_many(wall, door)
		player.builder.select(Builder.ENTRIES["Aberturas"][1])
		_aim(_square_center(1, 1))
	if frame == 80:
		print("DBG ray hole: ", wall.ray_to_panel(player.camera.global_position, player.camera.global_position - player.camera.global_basis.z * 7.0), " hit=", player.builder._ray().get("collider"))
		print("porta no buraco do chão: ", player.builder.fill_target.get("tris", []).size(), " triângulos, válido=", player.builder.fill_target.get("valid"))
		player._use_tool()
	if frame == 86:
		print("janelas/portas=", wall.fills.size(), " tipos=", wall.fills.map(func(f): return f.type))
		var door_node: BuildFill = null
		for child in wall.get_children():
			if child is BuildFill and child.type == "door":
				door_node = child
		print("texto da porta: ", door_node.get_interact_text())
		door_node.interact(player)
	if frame == 124:
		var door_node: BuildFill = null
		for child in wall.get_children():
			if child is BuildFill and child.type == "door":
				door_node = child
		print("porta aberta=", wall.fills[1].open, " giro=", snappedf(door_node.rotation.y, 0.01), " texto: ", door_node.get_interact_text())
		quit()
	return false
