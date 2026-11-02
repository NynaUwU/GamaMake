extends SceneTree
func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var player: Player = main.player
	var placed: PlacedManager = main.get_node("Placed")
	var terrain: TerrainWorld = main.get_node("Terrain")
	var river: Dictionary = terrain.rivers[0]
	var i: int = river.points.size() / 2
	var a: Vector2 = river.points[i]
	var b: Vector2 = river.points[i + 1]
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	var bank2: Vector2 = a + side * (river.width * 0.5 + 1.0)
	var bank := Vector3(bank2.x, terrain.height_at(bank2.x, bank2.y), bank2.y)
	print("água do rio: profundidade no meio=%.2f" % WaterManager.i.depth_at(Vector3(a.x, terrain.height_at(a.x, a.y) + 0.2, a.y)))
	# Roda d'água: só na beira (de frente para a água: -Z local aponta para o rio)
	var face := Basis.looking_at(Vector3(-side.x, 0, -side.y) * -1.0, Vector3.UP)
	face = Basis.looking_at(Vector3(a.x - bank.x, 0, a.y - bank.z), Vector3.UP)
	var far := placed.host_apply("place", ["water_wheel", Transform3D(face, player.global_position + Vector3(6, 0, 6))])
	var wr := placed.host_apply("place", ["water_wheel", Transform3D(face, bank)])
	print("roda longe do rio aceita=", not far.is_empty(), " na beira=", not wr.is_empty())
	var wheel: PlacedObject = placed.objects[wr[0]]
	var port: Vector3 = Power.world_ports(wheel)[0][0]
	var shaft_xf: Transform3D = player.builder._snap_shaft(placed, port + Vector3(0.3, 0, 0.2))
	var sh := placed.host_apply("place", ["shaft", shaft_xf])
	var shaft: PlacedObject = placed.objects[sh[0]]
	var far_end: Vector3 = shaft.global_transform * Vector3(1.0, 0.6, 0)
	var near_end: Vector3 = shaft.global_transform * Vector3(-1.0, 0.6, 0)
	var end := far_end if far_end.distance_to(port) > near_end.distance_to(port) else near_end
	var out_dir := (end - port).normalized()
	out_dir.y = 0
	out_dir = out_dir.normalized()
	var saw_basis := Basis(out_dir, Vector3.UP, out_dir.cross(Vector3.UP))
	var sw := placed.host_apply("place", ["sawmill", Transform3D(saw_basis, end + out_dir * 1.15 - Vector3.UP * 0.6)])
	print("serraria colocada=", not sw.is_empty())
	var saw: PlacedObject = placed.objects[sw[0]] if not sw.is_empty() else null
	if saw:
		print("encostados: roda-eixo=", Power.touching(wheel, shaft), " eixo-serraria=", Power.touching(shaft, saw))
		placed.host_apply("machine_put", [saw.net_id, 3])
		for k in 14:
			placed._power()
		print("serraria 14 s: ", saw.get_interact_text(), "  eixo: ", shaft.get_interact_text())
	# Moinho de vento + correia até o moinho manual
	Weather.i.wind = 1.0
	var o := player.global_position
	var wm := placed.host_apply("place", ["windmill", Transform3D(Basis(), o + Vector3(10, 0, 0))])
	var qn := placed.host_apply("place", ["quern", Transform3D(Basis(Vector3.UP, PI / 2), o + Vector3(14, 0, 3))]) # porta virada para a polia (paralelas)
	placed.host_apply("machine_put", [qn[0], 4])
	placed._power()
	var q_before: int = placed.objects[qn[0]].extra.get("out", 0)
	# Esteira: polia montada na porta do moinho de vento -> polia de latão do moinho manual.
	var wport: Array = Power.world_ports(placed.objects[wm[0]])[0]
	var pul := placed.host_apply("mount", ["pulley", Transform3D(Basis.looking_at(-wport[1], Vector3.UP), wport[0])])
	print("esteira (polia na porta do moinho de vento): ", not placed.host_apply("belt", [pul[0], qn[0]]).is_empty())
	for k in 6:
		placed._power()
	print("moinho manual por correia (vento 100%%): farinha %d -> %d, %s" % [q_before, placed.objects[qn[0]].extra.get("out", 0), placed.objects[wm[0]].get_interact_text()])
	placed._rebuild_belts()
	print("correia desenhada: ", placed._belt_node.mesh.get_surface_count() > 0)
	# Carneiro: irrigação
	var bank_b: Vector2 = river.points[i + 3] + side * (river.width * 0.5 + 1.0)
	var rp := placed.host_apply("place", ["ram_pump", Transform3D(face, Vector3(bank_b.x, terrain.height_at(bank_b.x, bank_b.y), bank_b.y))])
	var pot_pos: Vector3 = placed.objects[rp[0]].global_position + Vector3(3, 0, 3) if not rp.is_empty() else o
	var pt := placed.host_apply("place", ["pot_small", Transform3D(Basis(), pot_pos)])
	var res := placed.host_apply("plant", [pt[0], 0, "cenoura"])
	print("carneiro colocado=", not rp.is_empty(), " cenoura irrigada (boost)=", placed.objects[pt[0]].crops[0].get("boost", 1.0))
	quit()
