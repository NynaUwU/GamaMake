class_name CharacterPreview
extends SubViewportContainer
## O personagem (em blocos, com as mesmas cores do jogador) girando devagar na
## mochila, com a roupa/armadura vestida presa nos ossos (cabeça, peito,
## quadril, pés).

const RIG := preload("res://scripts/enemies/humanoid_rig.gd")
## slot -> [osso, deslocamento, escala] do modelo do item no boneco.
const MOUNT := {"head": [&"Head", Vector3(0, 0.12, 0), 1.15], "body": [&"Chest", Vector3(0, -0.24, 0), 0.95],
	"legs": [&"Hips", Vector3(0, -0.62, 0), 1.0], "feet": [&"Hips", Vector3(0, -0.98, 0), 1.0]}

var _viewport: SubViewport
var _pivot: Node3D
var _rig: Skeleton3D
var _worn := {} # slot -> [id, nó]


func _init() -> void:
	custom_minimum_size = Vector2(92, 150)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(184, 300)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.58)
	_viewport.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.6, 0.5, 0)
	_viewport.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, 1.0, 4.0)
	_viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.05, 4.0), Vector3(0, 0.95, 0))
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_rig = Skeleton3D.new()
	_rig.set_script(RIG)
	_rig.set("skin_color", Color(0.85, 0.66, 0.52))
	_rig.set("shirt_color", Color(0.22, 0.3, 0.2))
	_rig.set("pants_color", Color(0.2, 0.24, 0.35))
	_rig.set("build_hitboxes", false)
	_rig.set("glowing_eyes", false)
	_pivot.add_child(_rig)


## Mostra o que está vestido (chamado quando o inventário muda).
func show_equipment(equipment: Dictionary) -> void:
	for slot in MOUNT:
		var id: StringName = equipment.get(slot, {}).get("id", &"")
		var current: Array = _worn.get(slot, [&"", null])
		if current[0] == id:
			continue
		if is_instance_valid(current[1]):
			current[1].queue_free()
		_worn.erase(slot)
		if id == &"":
			continue
		var bone := _rig.find_bone(MOUNT[slot][0])
		if bone < 0:
			continue
		var attach := BoneAttachment3D.new()
		attach.bone_idx = bone
		_rig.add_child(attach)
		var model := ItemModels.build(id)
		model.position = MOUNT[slot][1]
		model.scale = Vector3.ONE * MOUNT[slot][2]
		attach.add_child(model)
		_worn[slot] = [id, attach]


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_pivot.rotation.y += delta * 0.8
