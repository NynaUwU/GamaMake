extends SceneTree
## Comparação: gerar os modelos por código (MeshBuilder) x salvar como modelo 3D
## e carregar do disco. Mede, para itens, objetos do martelo, móveis e casas:
##   código     montar a malha agora (o que o jogo faz hoje)
##   .res       malha nativa do Godot em binário (igual a um modelo importado), sem cache
##   .glb       modelo 3D padrão (glTF), lido em tempo de jogo pelo GLTFDocument
##   memória    a mesma malha já carregada antes (cache, como os móveis agora)
## Uso: godot --headless -s res://tests/bench_baked.gd

const DIR := "user://bench_baked"


func _meshes_of(node: Node) -> Array:
	var list := []
	for child in node.find_children("*", "MeshInstance3D", true, false):
		if child.mesh:
			list.append(child.mesh)
	if node is MeshInstance3D and node.mesh:
		list.append(node.mesh)
	return list


func _bytes(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else 0


func _bench(label: String, makers: Array) -> void:
	# 1) Código.
	var t0 := Time.get_ticks_usec()
	var nodes := []
	for make: Callable in makers:
		nodes.append(make.call())
	var code_ms := (Time.get_ticks_usec() - t0) / 1000.0
	# Junta as malhas de cada modelo numa cena só (para salvar como um arquivo por modelo).
	var res_paths := []
	var glb_paths := []
	var res_size := 0
	var glb_size := 0
	var tris := 0
	for i in nodes.size():
		var meshes := _meshes_of(nodes[i])
		var root := Node3D.new()
		for m: Mesh in meshes:
			var mi := MeshInstance3D.new()
			mi.mesh = m
			root.add_child(mi)
			mi.owner = root
			tris += m.get_faces().size() / 3
		var scene := PackedScene.new()
		scene.pack(root)
		var res_path := "%s/%s_%d.scn" % [DIR, label, i]
		ResourceSaver.save(scene, res_path, ResourceSaver.FLAG_COMPRESS)
		res_paths.append(res_path)
		res_size += _bytes(res_path)
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		doc.append_from_scene(root, state)
		var glb_path := "%s/%s_%d.glb" % [DIR, label, i]
		doc.write_to_filesystem(state, ProjectSettings.globalize_path(glb_path))
		glb_paths.append(glb_path)
		glb_size += _bytes(glb_path)
		root.free()
	for n in nodes:
		if is_instance_valid(n):
			n.free()
	# 2) Modelo nativo (.scn binário) do disco, sem cache.
	t0 = Time.get_ticks_usec()
	var loaded := []
	for path in res_paths:
		var packed: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		loaded.append(packed.instantiate())
	var res_ms := (Time.get_ticks_usec() - t0) / 1000.0
	# 3) Mesma coisa já em memória (cache): só instanciar.
	var cached := []
	for path in res_paths:
		cached.append(ResourceLoader.load(path))
	t0 = Time.get_ticks_usec()
	for packed: PackedScene in cached:
		loaded.append(packed.instantiate())
	var mem_ms := (Time.get_ticks_usec() - t0) / 1000.0
	# 4) glTF lido em tempo de jogo.
	t0 = Time.get_ticks_usec()
	for path in glb_paths:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		doc.append_from_file(ProjectSettings.globalize_path(path), state)
		loaded.append(doc.generate_scene(state))
	var glb_ms := (Time.get_ticks_usec() - t0) / 1000.0
	for n in loaded:
		if is_instance_valid(n):
			n.free()
	print("%-16s %3d modelos %7d tri | código %7.1f ms | .scn %7.1f ms (%5d KB) | .glb %7.1f ms (%5d KB) | memória %5.1f ms" % [label, makers.size(), tris,
		code_ms, res_ms, res_size / 1024, glb_ms, glb_size / 1024, mem_ms])


func _init() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var items := []
	for id in ItemDB.ITEMS.keys():
		items.append(func(): return ItemModels.build(id))
	var placed := []
	for kind in ObjectModels.KINDS + SteamModels.KINDS:
		if kind == "pipe":
			continue
		placed.append(func():
			var obj := PlacedObject.new()
			obj.setup(kind)
			Cooking.fires.erase(obj)
			return obj)
	var furniture := []
	for kind in Furniture.HP.keys():
		furniture.append(func():
			Furniture._cache.clear() # sem o cache novo: mede montar de verdade
			var f := Furniture.new()
			f.setup("bench", kind, CityGen.material())
			return f)
	var houses := []
	for k in 40:
		var lot := {"w": 8.0 + (k % 3), "d": 8.0 + (k % 2) * 2.0, "floors": 1 + k % 5, "ruin": k % 9 == 0, "village": k % 4 == 0, "seed": 1000 + k * 37}
		houses.append(func(): return CityGen.build_house(lot))
	print("--- gerar por código x carregar modelo salvo (tempo total do grupo) ---")
	_bench("itens", items)
	_bench("objetos", placed)
	_bench("moveis", furniture)
	_bench("casas", houses)
	quit()
