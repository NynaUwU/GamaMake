class_name HitReaction
extends SkeletonModifier3D
## Reação procedural a golpes: o osso atingido (e os pais dele) "tomba" na
## direção do golpe e volta como uma mola, balançando algumas vezes.
## Os ossos filhos (braços, cabeça) atrasam e chicoteiam, e o quadril afunda.
## Roda depois da animação, então funciona em cima de qualquer animação.

@export var stiffness := 230.0 ## força da mola que volta para a pose
@export var damping := 7.5 ## baixo = mais elástico (balança mais vezes)
@export var max_angle := 0.9 ## limite de inclinação em radianos
@export var chain_falloff := 0.5 ## quanto do golpe passa para o osso pai
@export var whip := 0.55 ## quanto os ossos filhos atrasam (efeito chicote)
@export var impulse_scale := 13.0
@export var hips_drop := 0.9 ## quanto o quadril afunda no golpe (m/s)
@export var hips_stiffness := 300.0
@export var hips_damping := 12.0

var _springs := {} # índice do osso -> [deslocamento: Vector3, velocidade: Vector3]
var _hips_offset := Vector3.ZERO
var _hips_velocity := Vector3.ZERO


## direction: direção do golpe no mundo. strength: ~0.3 (leve) a ~2 (forte).
func add_hit(bone: StringName, direction: Vector3, strength: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var idx := skeleton.find_bone(bone)
	if idx < 0:
		return
	var local_dir := (skeleton.global_basis.inverse() * direction).normalized()
	var axis := _bone_tip_direction(skeleton, idx).cross(local_dir)
	if axis.length() > 0.01:
		# Filhos do osso atingido giram ao contrário por inércia e voltam chicoteando.
		_add_whip(skeleton, idx, -axis.normalized() * strength * whip)

	var s := strength
	while idx >= 0 and s > 0.05:
		axis = _bone_tip_direction(skeleton, idx).cross(local_dir)
		if axis.length() > 0.01:
			_add_spring(idx, axis.normalized() * s)
		idx = skeleton.get_bone_parent(idx)
		s *= chain_falloff

	# O corpo inteiro cede: quadril desce e é empurrado na direção do golpe.
	_hips_velocity += (Vector3.DOWN * 0.7 + Vector3(local_dir.x, 0, local_dir.z) * 0.5) * hips_drop * strength


func _add_whip(skeleton: Skeleton3D, idx: int, impulse: Vector3) -> void:
	for child in skeleton.get_bone_children(idx):
		_add_spring(child, impulse)
		_add_whip(skeleton, child, impulse * 0.6)


func _add_spring(idx: int, impulse: Vector3) -> void:
	var spring: Array = _springs.get(idx, [Vector3.ZERO, Vector3.ZERO])
	spring[1] += impulse * impulse_scale
	_springs[idx] = spring


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	_update_hips(skeleton, delta)
	if _springs.is_empty():
		return
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
			velocity *= 0.5 # bateu no limite: perde energia
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


func _update_hips(skeleton: Skeleton3D, delta: float) -> void:
	if _hips_offset.length() < 0.0005 and _hips_velocity.length() < 0.005:
		return
	_hips_velocity += (-_hips_offset * hips_stiffness - _hips_velocity * hips_damping) * delta
	_hips_offset += _hips_velocity * delta
	_hips_offset = _hips_offset.limit_length(0.25)
	var root := 0
	skeleton.set_bone_pose_position(root, skeleton.get_bone_pose_position(root) + _hips_offset)


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
