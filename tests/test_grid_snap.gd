extends SceneTree
## Grade: trechos de cano/eixo só nas 6 direções (passos de 0,4 m), tripé nas pontas soltas
## dos canos no ar (como os eixos), eixo/cano em pé sem tripé, tripés saem junto ao desmontar,
## e objetos do martelo sempre na grade (0,4 m e 90°).

func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await process_frame
	var main: Node3D = current_scene
	var placed: PlacedManager = main.get_node("Placed")
	var terrain: TerrainWorld = main.get_node("Terrain")
	# 1) Direção pela mira.
	var a := Vector3(10.0, 1.0, 10.0)
	var cases := [
		["olhando para +X", Vector3(8.0, 2.6, 13.0), Vector3(12.3, 1.0, 10.1)],
		["olhando para -Z", Vector3(11.0, 2.6, 12.0), Vector3(10.1, 1.0, 7.0)],
		["olhando para cima", Vector3(10.6, 1.6, 12.0), Vector3(10.0, 3.2, 10.0)],
	]
	for c in cases:
		var origin: Vector3 = c[1]
		var seg := GridSnap.segment(a, origin, (c[2] - origin).normalized(), 6.0)
		print("%s: eixo %s, comprimento %.1f (múltiplo de 0,4? %s)" % [c[0], seg.get("axis"), seg.get("len", 0.0),
			is_equal_approx(fmod(seg.get("len", 0.0) + 0.0001, 0.4), 0.0001) or fmod(seg.get("len", 0.0) + 0.0001, 0.4) < 0.001])
	print("linha da grade: (10,1,12) na mesma linha de (10,1,10)? %s; (11,1,12)? %s" % [GridSnap.on_axis(a, Vector3(10, 1, 12)), GridSnap.on_axis(a, Vector3(11, 1, 12))])
	# 2) Cano deitado a 1,2 m do chão: 2 tripés. Cano em pé: nenhum.
	var p := Vector3(20.0, 0, 20.0)
	p.y = terrain.height_at(p.x, p.z) + 1.2
	var flat := placed.host_apply("pipe", [Transform3D(Basis.looking_at(Vector3.LEFT, Vector3.UP), p), 2.0])
	var up_pipe := placed.host_apply("pipe", [Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), p + Vector3(0, 0, 3)), 2.0])
	print("cano deitado: %d tripés (esperado 2); cano em pé: %d (esperado 0)" % [flat[3].size(), up_pipe[3].size()])
	var stands := placed.objects.values().filter(func(o): return o.kind == "pipe_stand").size()
	# 3) Eixo em pé: sem tripé; deitado: 2.
	var q := p + Vector3(6, 0, 0)
	var axle_up := placed.host_apply("axle", [Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), q), 1.6])
	var axle_flat := placed.host_apply("axle", [Transform3D(Basis.looking_at(Vector3.FORWARD, Vector3.UP), q + Vector3(3, 0, 0)), 1.6])
	print("eixo em pé: %d tripés (esperado 0); deitado: %d (esperado 2)" % [axle_up[3].size(), axle_flat[3].size()])
	# 4) Desmontar o cano leva os tripés dele.
	Net.i.request_peer = Net.i.my_id()
	var removed := placed.host_apply("remove", [flat[0]])
	var left := placed.objects.values().filter(func(o): return o.kind == "pipe_stand").size()
	print("desmontou o cano: saíram %d objetos (cano + tripés); tripés de cano antes %d, depois %d" % [removed.size(), stands, left])
	var removed2 := placed.host_apply("remove", [axle_flat[0]])
	print("desmontou o eixo deitado: saíram %d objetos (esperado 3)" % removed2.size())
	# 5) Objeto do martelo: grade sempre (posição em 0,4 m e giro em 90°).
	var x := Builder.grid_snap("chest", Transform3D(Basis(Vector3.UP, 0.83), Vector3(3.17, 1.0, -2.93)))
	print("baú posto torto em (3.17, -2.93) a 0.83 rad: vai para (%.2f, %.2f) a %.2f rad" % [x.origin.x, x.origin.z, x.basis.get_euler().y])
	quit()
