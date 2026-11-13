extends SceneTree
## Fotos do protótipo de voxels (SHOT=pasta): um pedaço de 64 m trocado por voxels (versão
## GDScript se a extensão C++ não estiver instalada): superfície (rampas iguais às de hoje),
## dentro de um salão de caverna com luz, um veio de minério, e a rede de cavernas vista de
## cima com a superfície escondida.

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
	light.global_position = from + Vector3.UP * 0.3


## Bloco (centro, em metros) da amostra i de uma seção.
func _pos(sec: Vector3i, i: int) -> Vector3:
	var x := i % VoxelRef.P
	var z := (i / VoxelRef.P) % VoxelRef.P
	var y := i / (VoxelRef.P * VoxelRef.P)
	return (Vector3(sec * VoxelRef.N) + Vector3(x - 1 + 0.5, y - 1 + 0.5, z - 1 + 0.5)) * VoxelRef.GRID


## Subsolo: sem neblina do bioma, sem sol e quase sem luz do céu (a atmosfera de caverna
## de verdade vem na fase 2; aqui é só para a foto mostrar a caverna como ela é).
func _underground(on: bool) -> void:
	var env: Environment = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.fog_enabled = not on
	env.ambient_light_energy = 0.06 if on else 0.7
	env.background_energy_multiplier = 0.2 if on else 1.0
	(main.get_node("Sun") as DirectionalLight3D).visible = not on
	main.get_node("Atmosphere").set_process(not on)
	DayNight.i.set_process(not on)


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 40:
		await process_frame
	main = current_scene
	player = main.player
	terrain = main.get_node("Terrain")
	Weather.i.target_rain = 0.0
	Weather.i.rain = 0.0
	DayNight.i.hour = 13.0
	DayNight.i._apply()
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	player.set_physics_process(false)
	light = OmniLight3D.new()
	light.omni_range = 22.0
	light.light_energy = 2.2
	light.light_color = Color(1.0, 0.94, 0.86)
	light.shadow_enabled = true
	main.add_child(light)
	var coord := Vector2i(2, 1)
	var center := (Vector2(coord) + Vector2(0.5, 0.5)) * terrain.chunk_size
	terrain.update_around(Vector3(center.x, 0, center.y), -1, 120.0)
	vw = VoxelWorld.new(terrain)
	main.add_child(vw)
	var surface := terrain.height_at(center.x, center.y)
	var top := floori((surface + 12.0) / VoxelWorld.SECTION)
	var info := vw.build_chunk(coord, -5, top)
	print("voxels (%s): %d seções com superfície, %d triângulos, %d ms" % ["C++" if vw.native else "GDScript", info.sections, info.triangles, info.ms])
	# Superfície vista de cima e de lado (as rampas são as mesmas do terreno de hoje).
	_view(Vector3(center.x - 30, surface + 14, center.y + 34), Vector3(center.x + 4, surface - 2, center.y - 6))
	light.visible = false
	await _shot("voxel_superficie", 40)
	# Salão de caverna: ar com mais espaço livre em volta, a 6 m ou mais abaixo do chão.
	var best := Vector3.ZERO
	var best_open := -1
	var ore_spot := Vector3.ZERO
	var ore_air := Vector3.ZERO
	for sec: Vector3i in vw.sections:
		var d: PackedByteArray = vw.sections[sec]
		for i in range(0, VoxelRef.P3, 7):
			var x := i % VoxelRef.P
			var z := (i / VoxelRef.P) % VoxelRef.P
			var y := i / (VoxelRef.P * VoxelRef.P)
			if x < 1 or y < 1 or z < 1 or x > VoxelRef.N or y > VoxelRef.N or z > VoxelRef.N:
				continue
			var p := _pos(sec, i)
			if VoxelRef.density(d, i) > 0 or p.y > terrain.height_at(p.x, p.z) - 6.0:
				continue
			var open := 0
			for dir in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
				for step in range(1, 12):
					var q: Vector3 = p + dir * step * VoxelRef.GRID
					if _solid(q):
						break
					open += 1
			if open > best_open and not _solid(p + Vector3.DOWN * 2.0):
				best_open = open
				best = p
	# Veio: bloco de minério com mais minério em volta e com ar na frente (parede de caverna).
	var best_ore := 0
	for sec: Vector3i in vw.sections:
		var d: PackedByteArray = vw.sections[sec]
		for i in VoxelRef.P3:
			var m := d[VoxelRef.P3 + i]
			if m < VoxelRef.COAL or m > VoxelRef.SULFUR:
				continue
			var x := i % VoxelRef.P
			var z := (i / VoxelRef.P) % VoxelRef.P
			var y := i / (VoxelRef.P * VoxelRef.P)
			if x < 2 or y < 2 or z < 2 or x > VoxelRef.N - 1 or y > VoxelRef.N - 1 or z > VoxelRef.N - 1:
				continue
			var near := 0
			for dz in range(-1, 2):
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var mm := d[VoxelRef.P3 + VoxelRef.idx(x + dx, y + dy, z + dz)]
						near += 1 if mm == m else 0
			if near <= best_ore:
				continue
			var p := _pos(sec, i)
			for dir in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.UP]:
				if not _solid(p + (dir as Vector3) * 0.8) and not _solid(p + (dir as Vector3) * 2.0) and p.y < terrain.height_at(p.x, p.z) - 5.0:
					ore_spot = p
					ore_air = p + (dir as Vector3) * 2.0
					best_ore = near
					break
	print("salão: %s (espaço livre %d), veio: %s (%d blocos iguais em volta)" % [best, best_open, ore_spot, best_ore])
	light.visible = true
	_underground(true)
	if best_open > 0:
		var far: Vector3 = best + Vector3.RIGHT * 6.0
		for dir in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var steps := 0
			while steps < 30 and not _solid(best + (dir as Vector3) * (steps + 1) * VoxelRef.GRID):
				steps += 1
			if steps * VoxelRef.GRID > far.distance_to(best) or far == best + Vector3.RIGHT * 6.0:
				far = best + (dir as Vector3) * steps * VoxelRef.GRID
		_view(best + Vector3.UP * 0.4, far + Vector3.DOWN * 0.6)
		await _shot("voxel_caverna", 30)
	if ore_spot != Vector3.ZERO:
		_view(ore_air, ore_spot)
		light.global_position = ore_air
		await _shot("voxel_minerio", 20)
	# Rede de cavernas: esconde as seções de cima (superfície) e olha de cima, com o material
	# de dois lados (vê as paredes por fora).
	var two_sided := Look.surface(true, 1.0, 0.95, 0.0, true)
	var cut := floori((surface - 8.0) / VoxelWorld.SECTION)
	for node in vw.get_children():
		var parts := String(node.name).split("_")
		var sy := int(parts[2])
		node.visible = sy < cut
		(node.get_child(0) as MeshInstance3D).material_override = two_sided
	terrain._chunks[coord].visible = false
	light.visible = false
	_underground(false)
	(main.get_node("WorldEnvironment") as WorldEnvironment).environment.fog_enabled = false
	_view(Vector3(center.x - 44, surface + 30, center.y + 44), Vector3(center.x, surface - 30, center.y))
	await _shot("voxel_rede_cavernas", 30)
	quit()


func _solid(p: Vector3) -> bool:
	var space := main.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.15
	q.shape = s
	q.transform = Transform3D(Basis(), p)
	return not space.intersect_shape(q, 1).is_empty() or _data_solid(p)


func _data_solid(p: Vector3) -> bool:
	var b := Vector3i(floori(p.x / VoxelRef.GRID), floori(p.y / VoxelRef.GRID), floori(p.z / VoxelRef.GRID))
	var sec := Vector3i(floori(b.x / 16.0), floori(b.y / 16.0), floori(b.z / 16.0))
	var d: PackedByteArray = vw.sections.get(sec, PackedByteArray())
	if d.is_empty():
		return p.y < terrain.height_at(p.x, p.z)
	var l := b - sec * 16 + Vector3i.ONE
	return VoxelRef.density(d, VoxelRef.idx(l.x, l.y, l.z)) > 0
