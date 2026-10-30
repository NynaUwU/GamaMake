class_name ThrownSlipper
extends Node3D
## Chinelo arremessado: faz uma curvinha girando e SEMPRE acerta a cabeça do
## zumbi mirado (headshot): ele cai duro para trás. Sem zumbi na mira, voa
## reto e cai no chão.

const SPEED := 22.0
const AIM_RANGE := 40.0
const AIM_CONE := 0.9 ## dot mínimo entre a mira e a cabeça do zumbi

var cosmetic := false ## cópia de outro jogador: só o visual
var _target: Zombie
var _start := Vector3.ZERO
var _end := Vector3.ZERO
var _t := 0.0
var _duration := 1.0
var _model: Node3D
var _falling := false
var _velocity := Vector3.ZERO
var _life := 0.0


## Escolhe o zumbi mais perto do centro da mira (cabeça dentro do cone).
static func pick_target(tree: SceneTree, origin: Vector3, aim: Vector3) -> Zombie:
	# Dentro do cone, o que estiver mais perto da mira ganha; a distância pesa um
	# pouco (o zumbi da frente ganha do que está quase atrás dele).
	var best: Zombie = null
	var best_score := INF
	for zombie in tree.get_nodes_in_group("enemy"):
		if not zombie is Zombie or zombie.state == Zombie.State.DEAD:
			continue
		var to: Vector3 = head_of(zombie) - origin
		if to.length() > AIM_RANGE:
			continue
		var dot := aim.dot(to.normalized())
		if dot < AIM_CONE:
			continue
		var score := acos(clampf(dot, -1.0, 1.0)) + to.length() * 0.008
		if score < best_score:
			best_score = score
			best = zombie
	return best


static func head_of(zombie: Zombie) -> Vector3:
	var bone := zombie.skeleton.find_bone("Head")
	if bone < 0:
		return zombie.global_position + Vector3.UP * 1.65
	return zombie.skeleton.global_transform * zombie.skeleton.get_bone_global_pose(bone).origin + Vector3.UP * 0.12


func launch(start: Vector3, aim: Vector3, target: Zombie) -> void:
	_model = ItemModels.build(&"chinelo")
	add_child(_model)
	_start = start
	_target = target
	global_position = start
	if target:
		_end = head_of(target)
	else:
		_falling = true
		_velocity = aim.normalized() * SPEED + Vector3.UP * 2.0
	_duration = clampf(_start.distance_to(_end) / SPEED, 0.12, 1.6)


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > 4.0:
		queue_free()
		return
	_model.rotate_y(delta * 22.0) # gira no ar
	if _falling:
		_velocity.y -= 9.8 * delta
		var next := global_position + _velocity * delta
		var query := PhysicsRayQueryParameters3D.create(global_position, next, 1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			queue_free()
			return
		global_position = next
		return
	if is_instance_valid(_target):
		_end = head_of(_target) # a cabeça anda: o chinelo segue
	_t = minf(_t + delta / _duration, 1.0)
	global_position = _start.lerp(_end, _t) + Vector3.UP * sin(_t * PI) * 0.35 * _duration
	if _t >= 1.0:
		var direction := (_end - _start).normalized()
		if not cosmetic and is_instance_valid(_target):
			_target.slipper_hit(direction)
		# Quica para trás e cai.
		_falling = true
		_velocity = -direction * 3.0 + Vector3.UP * 3.5
		_life = 3.0
