extends SceneTree
## Fotos dos voxels no jogo (SHOT=pasta), com a extensão C++: superfície em voxel perto e
## chão de alturas longe (a emenda), um túnel cavado num morro, dentro de uma caverna (com
## a neblina e a luz de caverna do jogo) e a rede de túneis vista de cima.

var main: Node3D
var player: Player
var terrain: TerrainWorld
var vw: VoxelWorld
var light: OmniLight3D


func _shot(name: String, frames := 20) -> void:
	for k in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT") + "/" + name + ".png")


func _view(from: Vector3, at: Vector3) -> void:
	player.global_position = from - Vector3.UP * 1.6
	var flat := Vector3(at.x - from.x, 0, at.z - from.z)
	player.rotation.y = atan2(-flat.x, -flat.z)
	player.head.rotation.x = atan2(at.y - from.y, maxf(flat.length(), 0.001))
	light.global_position = from + Vector3.UP * 0.2


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	main = current_scene
	player = main.player
	terrain = main.get_node("Terrain")
	vw = main.get_node_or_null("Voxels")
	if vw == null:
		print("sem a extensão C++: sem voxels")
		quit()
		return
	Weather.i.target_rain = 0.0
	Weather.i.rain = 0.0
	DayNight.i.hour = 14.0
	DayNight.i._apply()
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	player.set_physics_process(false)
	light = OmniLight3D.new()
	light.omni_range = 16.0
	light.light_energy = 1.6
	light.light_color = Color(1.0, 0.92, 0.78)
	light.shadow_enabled = true
	light.visible = false
	main.add_child(light)
	# Um morro perto do começo (procura o ponto mais alto num círculo).
	var best := Vector3(150, 0, 100)
	var best_h := -INF
	for k in 48:
		var a := TAU * k / 48.0
		for r in [120.0, 170.0, 220.0]:
			var p := Vector3(cos(a) * r, 0, sin(a) * r)
			var h := terrain.height_at(p.x, p.z)
			if h > best_h and h < 40.0:
				best_h = h
				best = p
	best.y = best_h
	terrain.update_around(best, -1, 150.0)
	var t0 := Time.get_ticks_msec()
	vw.update_around(best, VoxelWorld.NEAR, -1)
	print("morro em %s: voxels em volta em %d ms (%d seções)" % [best, Time.get_ticks_msec() - t0, vw.sections.size()])
	# Túnel cavado na encosta: 3 blocos de largura, 5 de altura, 14 de fundo, descendo devagar.
	# Descida mais íngreme a partir do topo: a boca do túnel fica na encosta.
	var down_dir := Vector3.FORWARD
	var lowest := INF
	for k in 16:
		var dir := Vector3(cos(TAU * k / 16.0), 0, sin(TAU * k / 16.0))
		var h := terrain.height_at(best.x + dir.x * 10.0, best.z + dir.z * 10.0)
		if h < lowest:
			lowest = h
			down_dir = dir
	var side := down_dir.cross(Vector3.UP)
	var mouth := best + down_dir * 7.0
	mouth.y = terrain._base_at(mouth.x, mouth.z)
	for step in 14:
		var c := mouth - down_dir * step * 0.4 + Vector3.DOWN * step * 0.08
		for w in range(-1, 2):
			for hgt in 5:
				var b := VoxelWorld.block_of(c + side * w * 0.4 + Vector3.UP * (hgt * 0.4 + 0.2))
				if vw.material_at(b) > VoxelRef.AIR:
					vw.set_block(b, VoxelRef.AIR)
	_view(mouth + down_dir * 6.0 + Vector3.UP * 1.2, mouth + Vector3.UP * 0.6)
	await _shot("voxel_tunel_cavado", 40)
	# Emenda: de dentro da área de voxels olhando para o chão de alturas lá longe.
	_view(best + Vector3.UP * 1.8, best + down_dir * 80.0 + Vector3.DOWN * 6.0)
	await _shot("voxel_emenda_longe", 20)
	# Caverna: procura ar bem fundo com espaço em volta e põe o jogador lá.
	vw.update_around(best + Vector3.DOWN * 20.0, VoxelWorld.NEAR, -1)
	var cave := Vector3.INF
	var open_best := 0
	for sec: Vector3i in vw.sections:
		var d: PackedByteArray = vw.sections[sec]
		for k in range(0, VoxelRef.P3, 5):
			var x := k % VoxelRef.P
			var z := (k / VoxelRef.P) % VoxelRef.P
			var y := k / (VoxelRef.P * VoxelRef.P)
			if x < 2 or z < 2 or y < 2 or x > 15 or z > 15 or y > 15 or VoxelRef.density(d, k) > 0:
				continue
			var p := VoxelWorld.block_center(sec * 16 + Vector3i(x - 1, y - 1, z - 1))
			if p.y > terrain._base_at(p.x, p.z) - 8.0 or vw.solid_at(p + Vector3.DOWN * 0.8) != 1:
				continue
			if vw.solid_at(p + Vector3.UP * 0.8) != 0 or vw.solid_at(p + Vector3.UP * 1.6) != 0 or vw.solid_at(p + Vector3.UP * 2.4) != 0:
				continue # sem altura para ficar em pé
			var open := 0
			for dir in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.UP]:
				for st in range(1, 14):
					if vw.solid_at(p + (dir as Vector3) * st * 0.4) != 0:
						break
					open += 1
			if open > open_best:
				open_best = open
				cave = p
	print("caverna: %s (espaço %d)" % [cave, open_best])
	if cave != Vector3.INF:
		var far := cave
		var far_d := 0.0
		for dir in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var st := 1
			while st < 40 and vw.solid_at(cave + (dir as Vector3) * st * 0.4) == 0:
				st += 1
			if st * 0.4 > far_d:
				far_d = st * 0.4
				far = cave + (dir as Vector3) * st * 0.4
		light.visible = true
		_view(cave + Vector3.UP * 1.3, far + Vector3.DOWN * 0.3)
		# Espera as colunas em volta ficarem prontas e a neblina/luz de caverna entrarem.
		var col := Vector2i(floori(cave.x / VoxelWorld.SECTION), floori(cave.z / VoxelWorld.SECTION))
		for k in 600:
			await process_frame
			if vw._columns.has(col) and vw._columns[col].ready and vw.cave_factor > 0.95:
				break
		print("fator caverna %.2f" % vw.cave_factor)
		await _shot("voxel_caverna_jogo", 10)
		light.visible = false
	# Rede de túneis vista de cima: some com as seções de cima e com o chão de alturas ali.
	var two_sided := Look.surface(true, 1.0, 0.95, 0.0, true)
	var cut := floori((best_h - 9.0) / VoxelWorld.SECTION)
	for sec: Vector3i in vw._nodes:
		var node: Node3D = vw._nodes[sec]
		node.visible = sec.y < cut
		(node.get_node("Mesh") as MeshInstance3D).material_override = two_sided
	for c in terrain._chunks.values():
		c.visible = false
	(main.get_node("WorldEnvironment") as WorldEnvironment).environment.fog_enabled = false
	vw.cave_factor = 0.0
	vw.set_process(false)
	_view(best + Vector3(-36, 40, 36), best + Vector3(0, -24, 0))
	await _shot("voxel_rede_tuneis", 30)
	quit()
