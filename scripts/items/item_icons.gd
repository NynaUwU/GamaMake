extends Node
## Autoload "ItemIcons": ícone de cada item, fotografado do próprio modelo 3D.
##
## Na primeira vez que o jogo abre, cada item é renderizado num SubViewport
## (fundo transparente, câmera ortográfica) e salvo em user://icon_cache/.
## Nas próximas vezes os PNGs são só carregados. O cache é refeito sozinho
## quando o jogo é atualizado: a "assinatura" junta a versão do projeto, a
## versão do renderizador de ícones e o conteúdo do ItemDB.

signal icons_ready

const CACHE_DIR := "user://icon_cache"
const MANIFEST := CACHE_DIR + "/manifest.txt"
const RENDER_VERSION := 1 ## mude para forçar re-render (ex.: mudou ângulo/luz)
const ICON_SIZE := 64 ## pequeno de propósito: fica pixelado como o resto do jogo

var ready_done := false
var _icons := {}


func _ready() -> void:
	_load_or_render.call_deferred()


## Ícone do item (null enquanto ainda não ficou pronto).
func get_icon(id: StringName) -> Texture2D:
	return _icons.get(id)




func _load_or_render() -> void:
	var signature := _signature()
	if DisplayServer.get_name() == "headless":
		# Sem GPU não dá para fotografar: usa ícones simples e não mexe no cache.
		for id in ItemDB.ITEMS:
			_icons[id] = ImageTexture.create_from_image(_placeholder(id))
	elif _cache_valid(signature):
		for id in ItemDB.ITEMS:
			var image := Image.load_from_file(_icon_path(id))
			if image:
				_icons[id] = ImageTexture.create_from_image(image)
	else:
		await _render_all()
		_write_manifest(signature)
	ready_done = true
	icons_ready.emit()


func _signature() -> String:
	var version: String = ProjectSettings.get_setting("application/config/version", "0")
	var data := "%s|%d|%s" % [version, RENDER_VERSION, var_to_str(ItemDB.ITEMS)]
	return data.sha256_text()


func _cache_valid(signature: String) -> bool:
	if not FileAccess.file_exists(MANIFEST):
		return false
	if FileAccess.get_file_as_string(MANIFEST).strip_edges() != signature:
		return false
	for id in ItemDB.ITEMS:
		if not FileAccess.file_exists(_icon_path(id)):
			return false
	return true


func _write_manifest(signature: String) -> void:
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file:
		file.store_string(signature)


func _icon_path(id: StringName) -> String:
	return "%s/%s.png" % [CACHE_DIR, id]


# --- Render -------------------------------------------------------------------

func _render_all() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var studio := _make_studio()
	add_child(studio.viewport)
	for id in ItemDB.ITEMS:
		var model := ItemDB.make_mesh(id)
		studio.pivot.add_child(model)
		_frame(model, studio.camera)
		studio.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var image: Image = studio.viewport.get_texture().get_image()
		if image == null or image.is_empty():
			image = _placeholder(id)
		else:
			image.save_png(_icon_path(id))
		_icons[id] = ImageTexture.create_from_image(image)
		model.queue_free()
		await get_tree().process_frame
	studio.viewport.queue_free()


func _make_studio() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	environment.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	viewport.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.7, 0.6, 0)
	key.light_energy = 1.4
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.5, 0)
	rim.light_energy = 0.5
	viewport.add_child(rim)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)

	# O item fica deitado na diagonal da imagem (cabo embaixo à esquerda).
	var pivot := Node3D.new()
	pivot.rotation = Vector3(0.35, PI / 2, 0)
	pivot.rotate_z(-PI / 4)
	viewport.add_child(pivot)
	return {"viewport": viewport, "camera": camera, "pivot": pivot}


## Posiciona a câmera para o modelo caber inteiro na imagem.
func _frame(model: Node3D, camera: Camera3D) -> void:
	var box := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var world_box: AABB = mesh.global_transform * mesh.get_aabb()
		box = world_box if first else box.merge(world_box)
		first = false
	var center := box.get_center()
	camera.size = maxf(box.size.x, box.size.y) * 1.15 + 0.02
	camera.position = Vector3(center.x, center.y, center.z + 5.0)
	camera.look_at(center)


func _placeholder(id: StringName) -> Image:
	var image := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	var hue := float(String(id).hash() % 360) / 360.0
	image.fill_rect(Rect2i(16, 16, 32, 32), Color.from_hsv(hue, 0.4, 0.7))
	return image
