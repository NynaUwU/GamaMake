class_name HitReaction
extends SkeletonModifier3D
## Reação procedural a golpes: o osso atingido (e os pais dele) "tomba" na
## direção do golpe e volta como uma mola. Roda depois da animação, então
## funciona em cima de qualquer animação (procedural ou do AnimationPlayer).

@export var stiffness := 140.0 ## força da mola que volta para a pose
@export var damping := 13.0 ## quanto a mola perde energia
@export var max_angle := 1.0 ## limite de inclinação em radianos
@export var chain_falloff := 0.5 ## quanto do golpe passa para o osso pai
@export var impulse_scale := 9.0

var _springs := {} # índice do osso -> [deslocamento: Vector3, velocidade: Vector3]


## direction: direção do golpe no mundo. strength: ~0.3 (leve) a ~2 (forte).
func add_hit(bone: StringName, direction: Vector3, strength: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var idx := skeleton.find_bone(bone)
	var local_dir := (skeleton.global_basis.inverse() * direction).normalized()
	while idx >= 0 and strength > 0.05:
		var axis := _bone_tip_direction(skeleton, idx).cross(local_dir)
		if axis.length() > 0.01:
			var spring: Array = _springs.get(idx, [Vector3.ZERO, Vector3.ZERO])
			spring[1] += axis.normalized() * strength * impulse_scale
			_springs[idx] = spring
		idx = skeleton.get_bone_parent(idx)
		strength *= chain_falloff


func _process_modification_with_delta(delta: float) -> void:
	if _springs.is_empty():
		return
	var skeleton := get_skeleton()
	var indices := _springs.keys()
	indices.sort() # pais antes dos filhos
	for idx in indices:
		var spring: Array = _springs[idx]
		var offset: Vector3 = spring[0]
		var velocity: Vector3 = spring[1]
		velocity += (-offset * stiffness - velocity * damping) * delta
		offset += velocity * delta
		if offset.length() > max_angle:
			offset = offset.normalized() * max_angle
		if offset.length() < 0.001 and velocity.length() < 0.01:
			_springs.erase(idx)
			continue
		_springs[idx] = [offset, velocity]

		# Converte a rotação (espaço do esqueleto) para o espaço local do osso.
		var rotation := Quaternion(offset.normalized(), offset.length())
		var parent := skeleton.get_bone_parent(idx)
		var parent_rot := Quaternion.IDENTITY
		if parent >= 0:
			parent_rot = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
		var local := skeleton.get_bone_pose_rotation(idx)
		skeleton.set_bone_pose_rotation(idx, parent_rot.inverse() * rotation * parent_rot * local)


## Direção em que o osso "aponta" (para o filho), no espaço do esqueleto.
func _bone_tip_direction(skeleton: Skeleton3D, idx: int) -> Vector3:
	var origin := skeleton.get_bone_global_pose(idx).origin
	var children := skeleton.get_bone_children(idx)
	if children.size() > 0:
		return (skeleton.get_bone_global_pose(children[0]).origin - origin).normalized()
	var parent := skeleton.get_bone_parent(idx)
	if parent >= 0:
		return (origin - skeleton.get_bone_global_pose(parent).origin).normalized()
	return Vector3.UP
