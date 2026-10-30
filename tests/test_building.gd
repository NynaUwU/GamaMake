extends SceneTree
## Construção: martelo constrói na grade (parede, piso, encaixe na borda do
## piso, teto em cima da parede), talhadeira tira triângulos (o buraco deixa
## passar), Shift + clique desmonta.
var main: Node
var player: Player
var frame := 0
var manager: BuildingManager

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _aim(point: Vector3) -> void:
	var eye := player.camera.global_position
	var to := point - eye
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		player = main.get_node("Player")
		manager = main.get_node("Building")
		for e in main.get_node("Enemies").get_children():
			e.queue_free()
		player.global_position = Vector3(-10, 0.1, 14)
		player.equip_item(&"martelo")
	if frame == 20:
		_aim(Vector3(-10, 0, 10.5))
	if frame == 24:
		print("alvo parede: ", player.builder.target)
		player._use_tool()
	if frame == 40:
		var piece: BuildPiece = manager.pieces.values()[0] if manager.pieces.size() > 0 else null
		print("peças=", manager.pieces.size(), " tipo=", BuildPiece.NAMES[piece.kind] if piece else "-", " cell=", piece.cell if piece else null,
			" mundo=", piece.global_position.snapped(Vector3.ONE * 0.01) if piece else null)
		player.builder.select(Builder.ENTRIES["Estrutura"][1]) # -> piso
		_aim(Vector3(-14, 0, 14))
	if frame == 44:
		print("alvo piso: ", player.builder.target)
		player._use_tool()
	if frame == 60:
		player.builder.select(Builder.ENTRIES["Estrutura"][0]) # -> parede de novo
		var floor_piece: BuildPiece = manager.pieces.values()[1]
		# Mira perto da borda de cima (z menor) do piso.
		_aim(floor_piece.global_position + Vector3(1.4, 0, 0.3))
	if frame == 64:
		var floor_piece: BuildPiece = manager.pieces.values()[1]
		print("parede no piso: alvo=", player.builder.target, " (piso em ", floor_piece.cell, ")")
		player._use_tool()
	if frame == 80:
		var wall: BuildPiece = manager.pieces.values()[2]
		player.builder.select(Builder.ENTRIES["Estrutura"][2]) # -> teto
		_aim(wall.to_global(Vector3(1.4, BuildPiece.SIZE, 0)))
	if frame == 84:
		print("teto na parede: alvo=", player.builder.target)
		var p := player.global_position
		player.global_position = Vector3(p.x, 3.3, p.z) # sobe para enxergar o topo
	if frame == 86:
		var wall: BuildPiece = manager.pieces.values()[2]
		_aim(wall.to_global(Vector3(1.4, BuildPiece.SIZE, 0)))
	if frame == 90:
		var dbg := player.builder._ray()
		print("DBG hit=", dbg.collider.name if dbg else null, " normal=", dbg.normal if dbg else null, " pos=", dbg.position if dbg else null, " eye=", player.camera.global_position)
		print("teto na parede (de cima): alvo=", player.builder.target)
		player._use_tool()
		player.global_position = Vector3(-10, 0.1, 14)
	if frame == 106:
		print("peças agora=", manager.pieces.size(), " tipos=", manager.pieces.values().map(func(p): return BuildPiece.NAMES[p.kind]))
		player.equip_item(&"talhadeira")
		_aim(Vector3(-10 + 0.0, 1.5, 10.4))
	if frame == 130:
		print("talhadeira mira (/): ", player.builder.cut_target.get("quarters", []))
		player._use_tool()
	if frame == 145:
		var wall: BuildPiece = manager.pieces.values()[0]
		print("triângulos tirados=", wall.removed.count(1))
		# Raio atravessando o meio do triângulo tirado.
		var tri := wall.removed.find(1)
		var c := BuildPiece.triangle_uv(tri)
		var mid := (c[0] + c[1] + c[2]) / 3.0
		var center := wall.to_global(wall.uvw(mid.x, mid.y, 0.0))
		var normal := wall.global_basis.z
		var q := PhysicsRayQueryParameters3D.create(center + normal, center - normal)
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		print("raio pelo buraco bate na parede? ", not hit.is_empty() and hit.collider == wall)
		var mid2 := Vector2(1.4, 2.5)
		var other := wall.to_global(wall.uvw(mid2.x, mid2.y, 0.0))
		q = PhysicsRayQueryParameters3D.create(other + normal, other - normal)
		hit = player.get_world_3d().direct_space_state.intersect_ray(q)
		print("raio na parte inteira bate? ", not hit.is_empty() and hit.collider == wall)
		# Tira mais 13 (um quadrado de janela 2x... direto pelo manager).
		for k in 14:
			manager.request_cut(wall, 4 * (2 * BuildPiece.N + 2) + k)
	if frame == 150:
		var wall: BuildPiece = manager.pieces.values()[0]
		print("depois da janela: tirados=", wall.removed.count(1), " vértices da malha=", wall._mesh.mesh.get_faces().size())
		player.equip_item(&"martelo")
		_aim(Vector3(-10, 0.8, 10.4))
	if frame == 160:
		Input.action_press("sprint") # só para não interferir; Shift é tecla física
		var hit := player.builder._ray()
		print("desmontar mira: ", hit.collider.name if hit else null)
		if hit and hit.collider is BuildPiece:
			manager.request_remove(hit.collider)
	if frame == 170:
		print("peças no fim=", manager.pieces.size())
		quit()
	return false
