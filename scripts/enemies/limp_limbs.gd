class_name LimpLimbs
extends SkeletonModifier3D
## Membros quebrados: o osso deixa de seguir a animação e fica pendurado,
## balançando com a gravidade e o movimento do corpo (como um ragdoll só
## naquele membro). Cada osso é um pêndulo: a ponta é simulada no mundo
## (Verlet) e o osso é girado para apontar para ela.

@export var gravity := 9.8
@export var damping := 0.86 ## quanto da velocidade sobra por frame (60 fps)
@export var floor_offset := 0.04 ## a ponta não atravessa o chão

var _limp := {} # índice do osso -> {"tip": Vector3, "prev": Vector3, "length": float, "ready": bool}


## Deixa os ossos moles (passe o osso do membro e os de baixo).
func make_limp(bones: Array[StringName]) -> void:
	var skeleton := get_skeleton()
	for bone in bones:
		var idx := skeleton.find_bone(bone)
		if idx >= 0 and not _limp.has(idx):
			_limp[idx] = {"tip": Vector3.ZERO, "prev": Vector3.ZERO, "length": _bone_length(skeleton, idx), "ready": false}


func is_limp(bone: StringName) -> bool:
	var skeleton := get_skeleton()
	return skeleton != null and _limp.has(skeleton.find_bone(bone))


## Recomeça a simulação a partir da pose atual (ex.: depois de sair do ragdoll).
func reset() -> void:
	for idx in _limp:
		_limp[idx].ready = false


func _process_modification_with_delta(delta: float) -> void:
	if _limp.is_empty() or delta <= 0.0:
		return
	var skeleton := get_skeleton()
	var to_world := skeleton.global_transform
	var to_skeleton := to_world.affine_inverse()
	var floor_y := skeleton.global_position.y + floor_offset
	var keep := pow(damping, delta * 60.0)
	var indices := _limp.keys()
	indices.sort() # pais antes dos filhos
	for idx in indices:
		var state: Dictionary = _limp[idx]
		var pose := skeleton.get_bone_global_pose(idx)
		var origin := to_world * pose.origin
		var current_dir := _tip_direction(skeleton, idx, pose)
		if not state.ready:
			state.tip = origin + to_world.basis * current_dir * state.length
			state.prev = state.tip
			state.ready = true
		# Verlet: inércia + gravidade, depois mantém o comprimento do osso.
		var velocity: Vector3 = (state.tip - state.prev) * keep
		state.prev = state.tip
		var tip: Vector3 = state.tip + velocity + Vector3.DOWN * gravity * delta * delta
		tip = origin + (tip - origin).normalized() * state.length
		if tip.y < floor_y:
			tip.y = floor_y
			tip = origin + (tip - origin).normalized() * state.length
		state.tip = tip

		var wanted := (to_skeleton.basis * (tip - origin)).normalized()
		if wanted.is_zero_approx() or current_dir.is_zero_approx():
			continue
		var rotation := Quaternion(current_dir, wanted)
		var parent := skeleton.get_bone_parent(idx)
		var parent_rot := Quaternion.IDENTITY
		if parent >= 0:
			parent_rot = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
		var local := skeleton.get_bone_pose_rotation(idx)
		skeleton.set_bone_pose_rotation(idx, parent_rot.inverse() * rotation * parent_rot * local)


## Para onde o osso aponta agora (espaço do esqueleto), pela direção de repouso.
func _tip_direction(skeleton: Skeleton3D, idx: int, pose: Transform3D) -> Vector3:
	var children := skeleton.get_bone_children(idx)
	var local_dir := Vector3.DOWN
	if children.size() > 0:
		local_dir = skeleton.get_bone_rest(children[0]).origin.normalized()
	else:
		local_dir = skeleton.get_bone_rest(idx).origin.normalized()
	return (pose.basis * local_dir).normalized()


func _bone_length(skeleton: Skeleton3D, idx: int) -> float:
	var children := skeleton.get_bone_children(idx)
	if children.size() > 0:
		return skeleton.get_bone_rest(children[0]).origin.length()
	return maxf(skeleton.get_bone_rest(idx).origin.length(), 0.2)
