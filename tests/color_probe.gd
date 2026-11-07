extends SceneTree
## Mede como a cor por vértice aparece na tela (sem luz) em cada renderizador:
## caixa A = cor por vértice, B = cor por vértice marcada como sRGB, C = albedo_color.

func _box(color: Color, srgb: bool, vertex: bool, x: float) -> MeshInstance3D:
	var mb := MeshBuilder.new()
	mb.color(color)
	var h := 0.5
	mb.quad(Vector3(-h, -h, 0), Vector3(-h, h, 0), Vector3(h, h, 0), Vector3(h, -h, 0))
	mb.quad(Vector3(-h, -h, 0), Vector3(h, -h, 0), Vector3(h, h, 0), Vector3(-h, h, 0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if vertex:
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = srgb
	else:
		m.albedo_color = color
	var mi := MeshInstance3D.new()
	mi.mesh = mb.finish(m, false)
	mi.position = Vector3(x, 0, 0)
	return mi


func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	root.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 3)
	root.add_child(cam)
	cam.make_current()
	var c := Color(0.5, 0.35, 0.2)
	root.add_child(_box(c, false, true, -1.2))
	root.add_child(_box(c, true, true, 0.0))
	root.add_child(_box(c, false, false, 1.2))
	for k in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	for k in 3:
		var px := img.get_pixel(int(w * (0.5 + (k - 1) * 0.147)), h / 2)
		print("PROBE %s: %.3f %.3f %.3f" % [["vertice", "vertice_srgb", "albedo"][k], px.r, px.g, px.b])
	quit()
