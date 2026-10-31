class_name ItemSpinner
extends SubViewportContainer
## Modelo 3D de um item girando devagar num quadradinho (mundo 3D próprio, fundo
## transparente). Usado na janela de detalhes do inventário e nos baús.

var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _id: StringName = &""


func _init(size_px := 56) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(size_px * 2, size_px * 2)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.62)
	_viewport.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8, 0.6, 0)
	_viewport.add_child(light)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)


## Troca o item mostrado (enquadra pelo tamanho do modelo).
func show_item(id: StringName) -> void:
	if id == _id:
		return
	_id = id
	for child in _pivot.get_children():
		child.queue_free()
	if id == &"":
		return
	var model := ItemModels.build(id)
	_pivot.add_child(model)
	var box := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = mesh.transform * mesh.mesh.get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	model.position = -box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.05)
	_camera.position = Vector3(0, radius * 0.6, radius * 3.6)
	_camera.look_at(Vector3.ZERO)
	_pivot.rotation = Vector3(0.0, 0.0, 0.0)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_pivot.rotation.y += delta * 1.2
