class_name Ragdoll
extends PhysicalBoneSimulator3D
## Liga/desliga o ragdoll e aplica impulsos nos ossos físicos.
## Funciona com qualquer Skeleton3D que tenha PhysicalBone3D (inclusive
## modelos importados com "Create Physical Skeleton").

signal blend_finished

const LAYER_RAGDOLL := 1 << 3
const MASK_RAGDOLL := 1 | (1 << 3) # mundo + outros ragdolls

var _bones: Array[PhysicalBone3D] = []
var _by_name := {}
var _pending_hits: Array = []
var _active := false
var _blend_tween: Tween


func _ready() -> void:
	# Para esqueletos montados no editor; o HumanoidRig chama setup() depois de criar os ossos.
	if _bones.is_empty():
		setup()


func setup() -> void:
	_bones.clear()
	_by_name.clear()
	for child in get_children():
		if child is PhysicalBone3D:
			_bones.append(child)
			_by_name[StringName(child.get("bone_name"))] = child
			child.collision_layer = 0
			child.collision_mask = MASK_RAGDOLL


func is_ragdolling() -> bool:
	return _active


## Liga a física em todos os ossos, partindo da pose atual da animação.
func start(inherited_velocity := Vector3.ZERO) -> void:
	if _blend_tween:
		_blend_tween.kill()
	influence = 1.0
	if _active:
		return # já está em ragdoll (ex.: apanhou enquanto levantava)
	physical_bones_start_simulation()
	_active = true
	var skeleton := get_skeleton()
	for pb in _bones:
		# top_level: os corpos não são arrastados quando o nó raiz do inimigo se move.
		pb.top_level = true
		pb.collision_layer = LAYER_RAGDOLL
		pb.global_transform = skeleton.global_transform \
				* skeleton.get_bone_global_pose(pb.get_bone_id()) * pb.body_offset
		pb.linear_velocity = inherited_velocity
		pb.angular_velocity = Vector3.ZERO


## Impulso aplicado no próximo frame de física (dá tempo do corpo virar rígido).
func apply_hit(bone: StringName, impulse: Vector3, world_point: Vector3) -> void:
	var pb: PhysicalBone3D = _by_name.get(bone)
	if pb == null and not _bones.is_empty():
		pb = _bones[0]
	if pb:
		_pending_hits.append([pb, impulse, world_point])


## Volta para a animação misturando aos poucos (usado para levantar).
func blend_out(duration: float) -> void:
	if not _active:
		return
	if _blend_tween:
		_blend_tween.kill()
	_blend_tween = create_tween()
	_blend_tween.tween_property(self, "influence", 0.0, duration)
	_blend_tween.tween_callback(stop)


func stop() -> void:
	physical_bones_stop_simulation()
	_active = false
	influence = 1.0
	for pb in _bones:
		pb.collision_layer = 0
		pb.top_level = false
	blend_finished.emit()


func get_bone_body(bone: StringName) -> PhysicalBone3D:
	return _by_name.get(bone)


## Posição do quadril no mundo (para reposicionar o inimigo ao levantar).
func get_root_position() -> Vector3:
	return _bones[0].global_position if not _bones.is_empty() else global_position


func get_average_speed() -> float:
	if _bones.is_empty():
		return 0.0
	var total := 0.0
	for pb in _bones:
		total += pb.linear_velocity.length()
	return total / _bones.size()


func _physics_process(_delta: float) -> void:
	if _pending_hits.is_empty() or not _active:
		return
	for hit in _pending_hits:
		var pb: PhysicalBone3D = hit[0]
		pb.apply_impulse(hit[1], hit[2] - pb.global_position)
	_pending_hits.clear()


## Explosão: empurra cada osso para longe do centro (e para cima), proporcional à massa.
func apply_explosion(center: Vector3, force: float) -> void:
	var total_mass := 0.0
	for pb in _bones:
		total_mass += pb.mass
	for pb in _bones:
		var away := pb.global_position - center
		var dir := (away.normalized() + Vector3.UP * 0.7).normalized()
		_pending_hits.append([pb, dir * force * pb.mass / total_mass, pb.global_position])


## Remove os corpos físicos de ossos que foram arrancados (desmembramento).
func remove_bones(bone_names: Array[StringName]) -> void:
	for bone in bone_names:
		var pb: PhysicalBone3D = _by_name.get(bone)
		if pb == null:
			continue
		_by_name.erase(bone)
		_bones.erase(pb)
		_pending_hits = _pending_hits.filter(func(hit): return hit[0] != pb)
		pb.queue_free()
