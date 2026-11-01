extends SceneTree
## Estúdio de fotos: folhas de contato de todos os modelos (STUDIO=items|placed|furniture|cars|loot).
## SHOT=pasta onde salvar. Uso: xvfb-run ... godot --rendering-driver opengl3 -s res://tests/studio.gd

const COLS := 6
var stage_root: Node3D
var cam: Camera3D


func _init() -> void:
	await process_frame
	var mode := OS.get_environment("STUDIO")
	var out := OS.get_environment("SHOT")
	stage_root = Node3D.new()
	get_root().add_child(stage_root)
	_stage()
	match mode:
		"items":
			var ids: Array = ItemDB.ITEMS.keys()
			var page := 0
			while page * 24 < ids.size():
				_clear()
				var chunk := ids.slice(page * 24, page * 24 + 24)
				for i in chunk.size():
					var node := ItemModels.build(chunk[i])
					var size: Vector3 = ItemDB.def(chunk[i]).size
					var s := 0.85 / maxf(size[size.max_axis_index()], 0.05)
					node.scale = Vector3.ONE * s
					_put(node, i, chunk.size(), ItemDB.display_name(chunk[i]), 1.25, 0.45)
				_frame(chunk.size(), 1.25, 30.0)
				await _save(out + "/itens_%d.png" % (page + 1))
				page += 1
		"placed", "fornos":
			# Objetos do martelo anteriores ao Tier 3, em páginas por tamanho (fornalhas acesas).
			var pages := [[2.6, ["furnace", "oven", "stone_furnace", "smoker", "campfire", "grindstone"]],
				[3.4, ["blast_furnace", "boiler", "distillery"]]] if mode == "fornos" else [
				[2.4, ["pot_small", "pot_wide", "ground", "flag", "chest", "drawboard"]],
				[3.6, ["bed", "workbench", "campfire"]],
				[3.0, ["furnace", "oven", "stone_furnace", "smoker", "compost", "rain_collector"]],
				[2.6, ["dryer", "grindstone", "quern", "pump", "filter", "sieve"]],
				[3.2, ["spinning", "loom", "shaft", "sawmill", "ram_pump", "stairs"]],
				[5.5, ["water_wheel", "windmill"]],
				[2.8, ["spikes", "beartrap", "barbed", "mine", "airdrop"]],
			]
			var manager := PlacedManager.new()
			manager.name = "Placed"
			stage_root.add_child(manager)
			for page in pages.size():
				_clear([manager])
				for child in manager.get_children():
					child.free()
				manager.objects.clear()
				var spacing: float = pages[page][0]
				var chunk: Array = pages[page][1]
				for i in chunk.size():
					var at := _slot_pos3(i, chunk.size(), spacing)
					var place := at
					if chunk[i] == "bed":
						place -= Vector3(1.4, 0, 1.4) # o canteiro tem a origem no canto
					manager._spawn(page * 100 + i + 1, chunk[i], Transform3D(Basis(Vector3.UP, 0.5) if chunk[i] != "bed" else Basis(), place), true)
					var obj: PlacedObject = manager.objects[page * 100 + i + 1]
					if chunk[i] in PlacedObject.LIT_KINDS:
						StationModels.set_lit(obj, true)
					if chunk[i] == "airdrop":
						for fx in obj.get_children():
							if fx is AirdropFX:
								fx.land_now()
					if chunk[i] == "rain_collector":
						obj.extra.water = 6.0
						obj.refresh(0.0)
					_label(chunk[i], at + Vector3(0, -0.15, spacing * 0.42))
				_frame3(chunk.size(), spacing, 32.0)
				await _save(out + ("/fornos_%d.png" if mode == "fornos" else "/objetos_%d.png") % (page + 1))
		"pecas":
			# Peças do martelo: parede, parede com janela, parede com porta, piso, teto e pilar.
			var entries := [Builder.ENTRIES["Estrutura"][0], Builder.ENTRIES["Aberturas"][0], Builder.ENTRIES["Aberturas"][1],
				Builder.ENTRIES["Estrutura"][1], Builder.ENTRIES["Estrutura"][2], Builder.ENTRIES["Estrutura"][3]]
			var names := ["parede", "janela", "porta", "piso", "teto", "pilar"]
			for i in entries.size():
				var piece: Node3D = Builder.preview_model(entries[i])
				stage_root.add_child(piece)
				var at := _slot_pos3(i, entries.size(), 3.6)
				piece.position = at + (Vector3(-1.4, 0, 0) if i < 3 else (Vector3(-1.4, 0.21, -1.4) if i < 5 else Vector3.ZERO))
				piece.rotation.y = 0.0
				_label(names[i], at + Vector3(0, -0.15, 1.7))
			_frame3(6, 3.6, 36.0)
			await _save(out + "/pecas.png")
		"janelas":
			# Janelas de formatos e posições diferentes: as travessas seguem a própria janela.
			var shapes := [
				["3x3 à esquerda", func(i, j, q): return i >= 1 and i <= 3 and j >= 2 and j <= 4],
				["3x3 à direita", func(i, j, q): return i >= 3 and i <= 5 and j >= 2 and j <= 4],
				["larga 5x2", func(i, j, q): return i >= 1 and i <= 5 and j >= 3 and j <= 4],
				["estreita 1x4", func(i, j, q): return i == 3 and j >= 1 and j <= 4],
				["em L", func(i, j, q): return (i >= 1 and i <= 4 and j >= 2 and j <= 3) or (i >= 1 and i <= 2 and j >= 4 and j <= 5)],
				["losango", func(i, j, q): return absf(i + 0.5 - 3.5) + absf(j + 0.5 - 3.5) <= 2.0],
			]
			for k in shapes.size():
				var piece := BuildPiece.new()
				piece.setup(BuildPiece.Kind.WALL, Vector3i.ZERO, 0)
				var parts := PackedInt32Array()
				for j in BuildPiece.N:
					for i in BuildPiece.N:
						for q in 4:
							if shapes[k][1].call(i, j, q):
								parts.append((j * BuildPiece.N + i) * 4 + q)
				for t in parts:
					piece.removed[t] = 1
				piece.add_fill("window", parts)
				stage_root.add_child(piece)
				var at := Vector3((k - 2.5) * 3.2, 0, 0)
				piece.position = at + Vector3(-1.4, 0, 0)
				_label(shapes[k][0], at + Vector3(0, 0.05, 0.6))
			var beam := BuildPiece.new()
			beam.setup(BuildPiece.Kind.PILLAR, Vector3i.ZERO, 1)
			stage_root.add_child(beam)
			beam.global_transform = Transform3D(beam.transform.basis, Vector3(-2.5 * 3.2 - 1.4, BuildPiece.SIZE + 0.2, 0))
			cam.fov = 40.0
			cam.position = Vector3(0, 3.0, 15.5)
			cam.look_at(Vector3(0, 1.4, 0))
			await _save(out + "/janelas.png")
		"casas":
			# Casas da cidade: vila (térreo de madeira), sobrado de pedra, torre torta e ruína.
			var lots := [
				{"w": 9.0, "d": 9.0, "floors": 1, "ruin": false, "village": true, "seed": 11},
				{"w": 10.0, "d": 9.0, "floors": 2, "ruin": false, "village": false, "seed": 23},
				{"w": 8.0, "d": 8.0, "floors": 4, "ruin": false, "village": false, "seed": 57},
				{"w": 9.0, "d": 10.0, "floors": 3, "ruin": false, "village": false, "seed": 91},
				{"w": 9.0, "d": 9.0, "floors": 1, "ruin": true, "village": true, "seed": 5},
				{"w": 10.0, "d": 10.0, "floors": 2, "ruin": false, "village": true, "seed": 404},
			]
			for i in lots.size():
				var house := CityGen.build_house(lots[i])
				stage_root.add_child(house)
				house.position = _slot_pos3(i, lots.size(), 16.0)
				house.rotation.y = PI + 0.5 # a frente (-Z) virada para a câmera
			_frame3(6, 16.0, 40.0)
			cam.position = cam.position * Vector3(1.0, 0.6, 1.0)
			cam.look_at(Vector3(0, 4.0, 0))
			await _save(out + "/casas.png")
		"tier3":
			# Máquinas do Tier 3, duas páginas; o alto-forno já montado (base + 2 anéis) e um cano.
			var manager := PlacedManager.new()
			manager.name = "Placed"
			stage_root.add_child(manager)
			var pages := [["boiler", "steam_engine", "blast_furnace", "water_tank", "distillery", "sprinkler"], ["lathe", "press", "pipe"]]
			for page in pages.size():
				_clear([manager])
				for child in manager.get_children():
					child.free()
				manager.objects.clear()
				var chunk: Array = pages[page]
				for i in chunk.size():
					var at := _slot_pos3(i, chunk.size(), 3.4)
					var id := page * 100 + i * 5 + 1
					var basis := Basis(Vector3.UP, 0.5)
					if chunk[i] == "pipe":
						manager._spawn(id, "pipe", Transform3D(Basis(Vector3.UP, -0.9), at + Vector3(-1.0, 0.4, 0.5)), true)
						manager.objects[id].extra.len = 2.4
						manager.objects[id].refresh(0.0)
					else:
						manager._spawn(id, chunk[i], Transform3D(basis, at), true)
					var obj: PlacedObject = manager.objects[id]
					if chunk[i] in ["boiler", "blast_furnace", "distillery"]:
						obj.extra.burn = 10.0
						StationModels.set_lit(obj, true)
					if chunk[i] == "boiler":
						obj.extra.merge({"pressure": 1.0, "water": 14.0}, true)
					if chunk[i] == "water_tank":
						obj.extra.water = 45.0
					if chunk[i] == "sprinkler":
						obj.extra.wet = true
					if chunk[i] == "blast_furnace":
						manager._spawn(id + 1, "blast_stack", Transform3D(basis, at + Vector3.UP * Fluids.BLAST_BASE_H), true)
						manager._spawn(id + 2, "blast_stack", Transform3D(basis, at + Vector3.UP * (Fluids.BLAST_BASE_H + Fluids.BLAST_RING_H)), true)
					obj.refresh(0.0)
					_label(SteamModels.NAMES[chunk[i]], at + Vector3(0, -0.15, 1.5))
				_frame3(6, 3.4, 34.0)
				await _save(out + "/tier3_%d.png" % (page + 1))
		"items3":
			var ids := [&"barra_aco", &"parafuso", &"engrenagem", &"eixo_aco", &"cano", &"suco", &"oleo", &"alcool", &"bandagem_esteril"]
			for i in ids.size():
				var node := ItemModels.build(ids[i])
				var size: Vector3 = ItemDB.def(ids[i]).size
				node.scale = Vector3.ONE * 0.85 / maxf(size[size.max_axis_index()], 0.05)
				_put(node, i, ids.size(), ItemDB.display_name(ids[i]), 1.25, 0.45)
			_frame(ids.size(), 1.25, 30.0)
			await _save(out + "/itens_tier3.png")
		"build":
			# Escada colocada + fantasmas (válido e inválido) do construtor.
			var manager := PlacedManager.new()
			manager.name = "Placed"
			stage_root.add_child(manager)
			manager._spawn(1, "stairs", Transform3D(Basis(Vector3.UP, 0.6), _slot_pos3(0, 3, 2.8) + Vector3(0, 0, 1.0)), true)
			_label("escada", _slot_pos3(0, 3, 2.8) + Vector3(0, -0.15, 1.6))
			for k in 2:
				var b := Builder.new()
				stage_root.add_child(b)
				b._apply_ghost(Builder.entry_for("place", ["chest", "stone_furnace"][k]))
				b._tint(k == 0)
				b._ghost.visible = true
				b._ghost.global_transform = Transform3D(Basis(Vector3.UP, 0.5), _slot_pos3(k + 1, 3, 2.8))
				_label(["fantasma ok", "fantasma bloqueado"][k], _slot_pos3(k + 1, 3, 2.8) + Vector3(0, -0.15, 1.2))
			_frame3(3, 2.8, 32.0)
			await _save(out + "/construcao.png")
		"furniture":
			var kinds: Array = Furniture.HP.keys()
			for i in kinds.size():
				var f := Furniture.new()
				f.setup("studio_%d" % i, kinds[i], CityGen.material())
				f.position = _slot_pos(i, kinds.size(), 2.6)
				f.rotation.y = 0.5
				stage_root.add_child(f)
				_label(kinds[i], f.position + Vector3(0, -0.15, 1.2))
			var styles := LootBox.STYLES
			for k in styles.size():
				var box := LootBox.new()
				stage_root.add_child(box)
				box.setup("studio_loot_%d" % k, styles[k], "casa")
				box.position = _slot_pos(kinds.size() + k, kinds.size() + styles.size(), 2.6)
				box.rotation.y = 0.5
				_label(styles[k], box.position + Vector3(0, -0.15, 1.2))
			_frame(kinds.size() + styles.size(), 2.6, 34.0)
			await _save(out + "/moveis.png")
		"cars":
			var models := [load("res://scenes/vehicles/vintage_car.tscn"), AeroV12Car, BrutusCar, DarracqV8Car, HallScottCar]
			for i in models.size():
				_clear()
				var car: VintageCar = models[i].instantiate() if models[i] is PackedScene else models[i].new()
				car.freeze = true
				stage_root.add_child(car)
				car.position = Vector3(0, 0.0, 0)
				for view in 3:
					var ang: float = [0.6, PI + 0.6, PI * 0.5][view]
					cam.position = Vector3(sin(ang) * 5.6, 1.8 if view < 2 else 1.1, cos(ang) * 5.6)
					cam.look_at(Vector3(0, 0.55, 0))
					cam.fov = 45.0
					await _save(out + "/carro_%d_%s.png" % [i + 1, ["frente", "tras", "lado"][view]])
				car.free()
	quit()


func _stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.58, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.environment.ambient_light_energy = 0.55
	get_root().add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	get_root().add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.42, 0.4)
	plane.material = mat
	floor.mesh = plane
	get_root().add_child(floor)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	get_root().add_child(body)
	cam = Camera3D.new()
	get_root().add_child(cam)
	cam.current = true


func _clear(keep := []) -> void:
	for child in stage_root.get_children():
		if child not in keep:
			child.free()


func _slot_pos(i: int, count: int, spacing: float) -> Vector3:
	var cols := mini(COLS, count)
	var rows := ceili(float(count) / cols)
	var x := (i % cols - (cols - 1) * 0.5) * spacing
	var z := (i / cols - (rows - 1) * 0.5) * spacing * 1.15
	return Vector3(x, 0, z)


func _slot_pos3(i: int, count: int, spacing: float) -> Vector3:
	var cols := 3
	var rows := ceili(float(count) / cols)
	return Vector3((i % cols - 1) * spacing, 0, (i / cols - (rows - 1) * 0.5) * spacing * 1.15)


func _frame3(count: int, spacing: float, fov: float) -> void:
	var rows := ceili(float(count) / 3)
	var t := tan(deg_to_rad(fov * 0.5))
	var dist := maxf(3 * spacing / (2.0 * t * 1.6), rows * spacing * 1.15 / (2.0 * t)) * 1.1
	cam.fov = fov
	cam.position = Vector3(0, dist * 0.62, dist * 0.8)
	cam.look_at(Vector3(0, 0.5, 0))


func _put(node: Node3D, i: int, count: int, text: String, spacing: float, lift: float) -> void:
	var holder := Node3D.new()
	holder.position = _slot_pos(i, count, spacing) + Vector3(0, lift, 0)
	holder.rotation = Vector3(0.0, 0.6, 0.0)
	holder.add_child(node)
	stage_root.add_child(holder)
	var aabb := _aabb(node)
	node.position -= aabb.get_center() * node.scale.x if false else Vector3.ZERO
	_label(text, holder.position + Vector3(0, -lift + 0.02, 0.55))


func _aabb(node: Node) -> AABB:
	return AABB()


func _label(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 28
	label.pixel_size = 0.004
	label.rotation = Vector3(-PI / 2 + 0.5, 0, 0)
	label.modulate = Color(0.08, 0.08, 0.08)
	label.outline_size = 0
	label.position = at
	stage_root.add_child(label)


func _frame(count: int, spacing: float, fov: float) -> void:
	var cols := mini(COLS, count)
	var rows := ceili(float(count) / cols)
	var width := cols * spacing
	var depth := rows * spacing * 1.15
	cam.fov = fov
	var aspect := 1.6
	var t := tan(deg_to_rad(fov * 0.5))
	var dist := maxf(width / (2.0 * t * aspect), depth * 0.95 / (2.0 * t)) * 1.08
	cam.position = Vector3(0, dist * 0.7, dist * 0.72)
	cam.look_at(Vector3(0, 0.2, 0.05 * depth))


func _save(path: String) -> void:
	for k in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_viewport().get_texture().get_image().save_png(path)
