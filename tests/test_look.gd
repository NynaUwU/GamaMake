extends SceneTree
## Visual: qualidade gráfica, materiais PS2, grama densa, abrigo da chuva,
## distância de desenho pela neblina e sombra pintada nas malhas.

func _init() -> void:
	var before := Look.quality()
	Look.set_quality(Look.Q.MEDIUM)
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	var bm: BuildingManager = main.get_node("Building")
	var env: Environment = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sun: DirectionalLight3D = main.get_node("Sun")
	print("qualidade %s: ssao=%s glow=%s tonemap=%d sombras %d divisões até %.0f m, céu=%s" % [Look.NAMES[Look.quality()], env.ssao_enabled,
		env.glow_enabled, env.tonemap_mode, 4 if sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS else 2,
		sun.directional_shadow_max_distance, env.sky.sky_material is ShaderMaterial])
	# --- Materiais
	var r := bm.host_apply("place", [BuildPiece.Kind.PILLAR, Vector3i(400, 40, 400), 0])
	var pillar: BuildPiece = bm.pieces[r[0]]
	var chunk_mesh: MeshInstance3D = null
	for c in terrain.get_children():
		for n in c.get_children():
			if n is MeshInstance3D:
				chunk_mesh = n
				break
		if chunk_mesh:
			break
	print("materiais: construção=%s terreno=%s máquina=%s pilar em pé veio vertical=%s" % [pillar._mesh.material_override is ShaderMaterial,
		chunk_mesh.material_override is ShaderMaterial, PlacedObject._mat() is ShaderMaterial, pillar._mesh.material_override.get_shader_parameter("grain_up")])
	# --- Sombra pintada: face de baixo mais escura que a de cima (mesma cor).
	var mb := MeshBuilder.new()
	mb.color(Color(0.6, 0.6, 0.6))
	mb.quad(Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)) # virada para baixo
	mb.quad(Vector3(0, 2, 0), Vector3(0, 2, 1), Vector3(1, 2, 1), Vector3(1, 2, 0)) # virada para cima
	var arrays := mb.finish(null, false).surface_get_arrays(0)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var down := 0.0
	var up := 0.0
	for i in cols.size():
		if nrm[i].y < 0.0:
			down = cols[i].r
		else:
			up = cols[i].r
	print("sombra pintada: face de baixo %.2f, face de cima %.2f" % [down, up])
	# --- Grama densa num campo aberto.
	var field := Vector3.ZERO
	for rr: float in [200.0, 300.0, 420.0, 560.0]:
		for k in 24:
			var a := TAU * k / 24.0
			var x := cos(a) * rr
			var z := sin(a) * rr
			var b: Dictionary = terrain.biome_at(x, z)
			if b.plains > 0.85 and terrain.city_mask(x, z) <= 0.0 and terrain.road_at(x, z).is_empty() and not TerrainProps._in_lake(terrain, x, z, 1.3):
				field = Vector3(x, terrain.height_at(x, z), z)
				break
		if field != Vector3.ZERO:
			break
	terrain.update_around(field)
	player.global_position = field + Vector3(0, 0.5, 0)
	var grass: GrassField = main.get_node("Grass")
	for k in 90:
		await process_frame
	var blades := 0
	var tiles := 0
	for t in grass._tiles.values():
		if t is MultiMeshInstance3D:
			tiles += 1
			blades += t.multimesh.instance_count
	print("grama densa (Média) no campo: %d quadrados, %d moitinhas" % [tiles, blades])
	# Piso em cima tira a grama de baixo.
	var cell := Vector3i(floori(field.x / BuildPiece.SEG), floori(field.y / BuildPiece.SEG), floori(field.z / BuildPiece.SEG))
	bm.host_apply("place", [BuildPiece.Kind.FLOOR, cell, 0])
	grass._timer = 0.0
	for k in 4:
		await process_frame
	var under := 0
	var o := Vector3(cell) * BuildPiece.SEG
	for coord in grass._tiles:
		var t = grass._tiles[coord]
		if not (t is MultiMeshInstance3D):
			continue
		for n in t.multimesh.instance_count:
			var p: Vector3 = t.position + t.multimesh.get_instance_transform(n).origin
			if p.x > o.x + 0.2 and p.x < o.x + BuildPiece.SIZE - 0.2 and p.z > o.z + 0.2 and p.z < o.z + BuildPiece.SIZE - 0.2:
				under += 1
	print("grama embaixo do piso novo: %d" % under)
	Look.set_quality(Look.Q.LOW)
	for k in 30:
		await process_frame
	var low := 0
	for t in grass._tiles.values():
		if t is MultiMeshInstance3D:
			low += t.multimesh.instance_count
	print("qualidade Baixa: grama densa=%d, ssao=%s glow=%s sombras até %.0f m" % [low, env.ssao_enabled, env.glow_enabled, sun.directional_shadow_max_distance])
	Look.set_quality(Look.Q.MEDIUM)
	# --- Abrigo: teto em cima da cabeça = chuva some em volta.
	Weather.i.rain = 1.0
	Weather.i.target_rain = 1.0
	var fx: AmbientFX = main.get_node("AmbientFX")
	player.global_position = field + Vector3(6, 0.3, 6)
	for k in 30:
		await physics_frame
	var open_sky := fx.sheltered
	var roof := Vector3i(floori((field.x + 6.0) / BuildPiece.SEG) - 3, floori((field.y + 3.4) / BuildPiece.SEG), floori((field.z + 6.0) / BuildPiece.SEG) - 3)
	bm.host_apply("place", [BuildPiece.Kind.FLOOR, roof, 0])
	for k in 30:
		await physics_frame
	print("abrigo: céu aberto=%s, debaixo do teto=%s, gotas caindo em volta=%s" % [open_sky, fx.sheltered, Weather.i._drops.emitting])
	Weather.i.rain = 0.0
	Weather.i.target_rain = 0.0
	# --- Distância de desenho acompanha a neblina.
	var cam: Camera3D = player.camera
	print("câmera desenha até %.0f m (neblina termina em %.0f m)" % [cam.far, env.fog_depth_end])
	Look.set_quality(before)
	quit()
