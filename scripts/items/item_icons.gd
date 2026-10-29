extends Node
## Autoload "ItemIcons": ícone de cada item, fotografado do próprio modelo 3D.
## Ninguém precisa desenhar ícone: criou um item no ItemDB, o ícone aparece.
##
## Os PNGs ficam NA PASTA DO JOGO (res://assets/icons/) e vão junto no
## repositório e no jogo exportado. Rodando pelo editor, o jogo confere a
## "assinatura" (versão do projeto + RENDER_VERSION + conteúdo do ItemDB):
## se algo mudou, fotografa de novo e regrava os PNGs. A GPU só é usada para
## desenhar a foto uma vez; nada fica guardado nela.
##
## No jogo exportado a pasta do jogo é só leitura: os PNGs são só carregados.
## Se faltar algum (esqueceu de rodar pelo editor antes de exportar), ele é
## gerado em user://icon_cache/ como reserva.

signal icons_ready

const ICON_DIR := "res://assets/icons"
const MANIFEST := ICON_DIR + "/manifest.txt"
const FALLBACK_DIR := "user://icon_cache"
const RENDER_VERSION := 7 ## mude para forçar re-render (ex.: mudou ângulo/luz)
const ICON_SIZE := 64 ## pequeno de propósito: fica pixelado como o resto do jogo

var ready_done := false
var _icons := {}


func _ready() -> void:
	_load_or_render.call_deferred()


## Ícone do item (null enquanto ainda não ficou pronto).
func get_icon(id: StringName) -> Texture2D:
	return _icons.get(id)


func _load_or_render() -> void:
	var headless := DisplayServer.get_name() == "headless"
	var in_editor := OS.has_feature("editor")
	var missing: Array[StringName] = []
	if in_editor and not headless and not _manifest_matches():
		missing.assign(ItemDB.ITEMS.keys()) # mudou algo: refaz todos na pasta do jogo
	else:
		for id in ItemDB.ITEMS:
			var texture := _load_icon(id)
			if texture:
				_icons[id] = texture
			else:
				missing.append(id)
	if not missing.is_empty():
		if headless:
			# Sem GPU não dá para fotografar: ícones simples, sem gravar nada.
			for id in missing:
				_icons[id] = ImageTexture.create_from_image(_placeholder(id))
		else:
			var folder := ICON_DIR if in_editor else FALLBACK_DIR
			await _render(missing, folder)
			if in_editor:
				_write_manifest(_signature())
	ready_done = true
	icons_ready.emit()


## Carrega da pasta do jogo (importado) ou, se ainda não importado, direto do PNG.
func _load_icon(id: StringName) -> Texture2D:
	for folder in [ICON_DIR, FALLBACK_DIR]:
		var path := "%s/%s.png" % [folder, id]
		if folder == ICON_DIR and ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			if texture:
				return texture
		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			if image:
				return ImageTexture.create_from_image(image)
	return null


func _signature() -> String:
	var version: String = ProjectSettings.get_setting("application/config/version", "0")
	var data := "%s|%d|%s" % [version, RENDER_VERSION, var_to_str(ItemDB.ITEMS)]
	return data.sha256_text()


func _manifest_matches() -> bool:
	if not FileAccess.file_exists(MANIFEST):
		return false
	if FileAccess.get_file_as_string(MANIFEST).strip_edges() != _signature():
		return false
	for id in ItemDB.ITEMS:
		if not FileAccess.file_exists("%s/%s.png" % [ICON_DIR, id]):
			return false
	return true


func _write_manifest(signature: String) -> void:
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file:
		file.store_string(signature)


# --- Render -------------------------------------------------------------------

func _render(ids: Array[StringName], folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var studio := _make_studio()
	add_child(studio.viewport)
	for id in ids:
		var model := ItemDB.make_mesh(id)
		studio.pivot.add_child(model)
		_frame(model, studio.camera)
		studio.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var image: Image = studio.viewport.get_texture().get_image()
		if image == null or image.is_empty():
			image = _placeholder(id)
		else:
			image.save_png("%s/%s.png" % [folder, id])
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
