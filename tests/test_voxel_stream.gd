extends SceneTree

## Mede as fases do quadro: scripts de física, passo do Jolt e _process (todos os nós).
class Probe extends Node:
	var kind := 0 # 0 começo da física, 1 fim da física, 2 começo do process, 3 fim do process
	var clock: Dictionary
	func _physics_process(_d: float) -> void:
		if kind == 0:
			clock.phys_start = Time.get_ticks_usec()
		elif kind == 1:
			clock.phys_end = Time.get_ticks_usec()
			clock.scripts += (clock.phys_end - clock.phys_start) / 1000.0
	func _process(_d: float) -> void:
		if kind == 2:
			clock.proc_start = Time.get_ticks_usec()
			if clock.phys_end > clock.last_proc:
				clock.step = (clock.proc_start - clock.phys_end) / 1000.0
		elif kind == 3:
			clock.proc = (Time.get_ticks_usec() - clock.proc_start) / 1000.0
			clock.last_proc = Time.get_ticks_usec()


func _init() -> void:
	Engine.max_fps = 60 # tempo real (sem tela o Godot rodaria os quadros bem mais rápido)
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await process_frame
	var main: Node3D = current_scene
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	var vw: VoxelWorld = main.get_node_or_null("Voxels")
	if vw == null:
		print("sem voxels")
		quit()
		return
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	player.set_physics_process(false)
	var clock := {"phys_start": 0, "phys_end": 0, "proc_start": 0, "last_proc": 0, "scripts": 0.0, "step": 0.0, "proc": 0.0}
	for k in 4:
		var probe := Probe.new()
		probe.kind = k
		probe.clock = clock
		if k < 2:
			probe.process_physics_priority = -100000 if k == 0 else 100000
		else:
			probe.process_priority = -100000 if k == 2 else 100000
		root.add_child(probe)
	var worst_phase := {"scripts": 0.0, "step": 0.0, "proc": 0.0}
	# Espera o entorno do começo ficar pronto (como na tela de carregamento).
	for k in 120:
		await process_frame
	var start := Vector3(100, 0, 40)
	var speed := 20.0
	var worst := 0.0
	var total := 0.0
	var frames := 0
	var slow := 0
	var last := Time.get_ticks_usec()
	var made_cols := {}
	var counts := {}
	var frame_ms := PackedFloat32Array() # gravado em FRAMES_CSV (gráfico de antes/depois)
	var missing := 0
	var voxel_late := 0
	var late_why := {"with_heights": 0, "pending_max": 0, "not_wanted": 0, "waiting_max": 0, "show_max": 0}
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for k in 600: # 10 s a 60 quadros
		var p := start + Vector3(1, 0, 0.35).normalized() * speed * k / 60.0
		p.y = terrain.height_at(p.x, p.z) + 1.0
		player.global_position = p
		player.velocity = Vector3(1, 0, 0.35).normalized() * speed # o buffer à frente usa a velocidade
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		if k > 5:
			if ms > 30.0:
				# Quem pesou no quadro (do quadro anterior, medido pelo próprio sistema).
				print("  quadro %d: %.1f ms | voxels %.1f, chão de alturas %.1f, grama %.1f, process %.1f, física %.1f" % [k, ms, vw.last_ms,
					terrain.last_ms, main.get_node("Grass").last_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
				# O que nasceu no mundo nesse quadro (filhos novos de cada sistema).
				var grew := []
				for child in main.get_children():
					var d: int = child.get_child_count() - counts.get(child.name, child.get_child_count())
					if d != 0:
						grew.append("%s %+d" % [child.name, d])
				print("    fases: física (scripts) %.1f, passo do Jolt %.1f, _process %.1f ms" % [clock.scripts, clock.step, clock.proc])
				print("    nós %+d | %s" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodes_before, ", ".join(grew)])
			frame_ms.append(ms)
			worst = maxf(worst, ms)
			for key in worst_phase:
				worst_phase[key] = maxf(worst_phase[key], clock[key])
			total += ms
			frames += 1
			slow += 1 if ms > 33.0 else 0
		for col in vw._columns:
			made_cols[col] = true
		# O chão ficou pronto a tempo? (embaixo do jogador e 64 m à frente)
		var ahead_p := p + Vector3(1, 0, 0.35).normalized() * 64.0
		for q in [p, ahead_p]:
			if not terrain._chunks.has(Vector2i(floori(q.x / terrain.chunk_size), floori(q.z / terrain.chunk_size))):
				missing += 1
		var here_col := Vector2i(floori(p.x / VoxelWorld.SECTION), floori(p.z / VoxelWorld.SECTION))
		if vw._columns.has(here_col) and not vw._columns[here_col].ready:
			voxel_late += 1
			if not vw._columns[here_col].cols.is_empty():
				late_why.with_heights += 1
			late_why.pending_max = maxi(late_why.pending_max, vw._columns[here_col].pending)
		elif not vw._columns.has(here_col):
			late_why.not_wanted += 1
		late_why.waiting_max = maxi(late_why.waiting_max, vw._waiting.size())
		late_why.show_max = maxi(late_why.show_max, vw._to_show.size())
		clock.scripts = 0.0
		clock.step = 0.0
		nodes_before = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		for child in main.get_children():
			counts[child.name] = child.get_child_count()
	var csv := OS.get_environment("FRAMES_CSV")
	if csv != "":
		var f := FileAccess.open(csv, FileAccess.WRITE)
		for v in frame_ms:
			f.store_line("%.2f" % v)
	print("10 s andando a %.0f m/s: quadro médio %.1f ms, pior %.1f ms, quadros acima de 33 ms: %d de %d" % [speed, total / frames, worst, slow, frames])
	print("pior por fase (ms): física (scripts) %.1f, passo do Jolt %.1f, _process %.1f" % [worst_phase.scripts, worst_phase.step, worst_phase.proc])
	print("chão faltando (embaixo ou 64 m à frente): %d vezes; coluna de voxel embaixo ainda montando: %d quadros" % [missing, voxel_late])
	print("    por quê: %s" % late_why)
	var n_done: int = vw.stats.get("columns_done", 1)
	print("    coluna de voxel: thread média %.1f ms (pior %.1f), espera na fila média %.0f ms (pior %.0f), %d colunas" % [vw.stats.thread_sum / n_done,
		vw.stats.thread_max, vw.stats.queue_sum / n_done, vw.stats.queue_max, n_done])
	print("vida do lago, pior passo: %s %.1f ms" % [LakeLife.worst_step_name, LakeLife.worst_step_ms])
	print("plantas de chunk ainda montando: %d" % terrain._prop_jobs.size())
	print("chão de alturas, pior por parte (ms): %s" % terrain.prof)
	print("voxels, pior por parte (ms): %s" % vw.stats)
	print("pior tempo por parte (ms): uma coluna nova %.1f, recolher seções %.1f, buraco no chão %.1f, soltar coluna %.1f" % [vw.stats.add, vw.stats.collect, vw.stats.holes, vw.stats.drop])
	print("colunas de voxel geradas %d, carregadas agora %d, seções %d, tarefas na fila %d" % [made_cols.size(), vw._columns.size(), vw.sections.size(), vw._tasks.size()])
	# O chão embaixo do jogador é voxel (o buraco no chão de alturas acompanhou)?
	for k in 60:
		await process_frame
	var p := player.global_position
	var hit := main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2, p + Vector3.DOWN * 6, 1, [player.get_rid()]))
	print("no fim: chão embaixo é voxel? %s; chunks com buraco no chão de alturas: %d" % [VoxelWorld.is_voxel_body(hit.get("collider")), terrain._holes.size()])
	quit()
