extends SceneTree
## Diagnóstico: a mesma caixa colorida, montada de jeitos diferentes, com o
## material PS2 (Look.surface), sob sol. Mostra a cor que sai na tela.

func _st_box(generate: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	TerrainProps._box(st, Vector3.ZERO, Vector3.ONE, Color(0.5, 0.35, 0.2))
	if generate:
		st.generate_normals()
	return st.commit()


func _mb_box() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.color(Color(0.5, 0.35, 0.2))
	var h := 0.5
	mb.quad(Vector3(-h, -h, h), Vector3(h, -h, h), Vector3(h, h, h), Vector3(-h, h, h))
	mb.quad(Vector3(-h, -h, -h), Vector3(-h, h, -h), Vector3(h, h, -h), Vector3(h, -h, -h))
	return mb.finish(null, false)


func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.3, 0.3, 0.3)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.3, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 4)
	root.add_child(cam)
	cam.make_current()
	var meshes := [_mb_box(), _st_box(true), _st_box(false)]
	var names := ["MeshBuilder", "SurfaceTool+normais", "SurfaceTool"]
	for k in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[k]
		mi.material_override = Look.surface(true, 1.0)
		mi.position = Vector3((k - 1) * 1.4, 0, 0)
		root.add_child(mi)
	for k in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	for k in 3:
		var px := img.get_pixel(int(w * (0.5 + (k - 1) * 0.171)), h / 2)
		var arrays: Array = meshes[k].surface_get_arrays(0)
		var n = arrays[Mesh.ARRAY_NORMAL]
		print("SURF %s: %.3f %.3f %.3f  (normais: %s, formato %d)" % [names[k], px.r, px.g, px.b, "sim" if n != null and n.size() > 0 else "não",
			meshes[k].surface_get_format(0)])
	quit()
