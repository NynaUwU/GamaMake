class_name ThrownSlipper
extends Node3D
## Chinelo arremessado: faz uma curvinha girando e SEMPRE acerta a cabeça do
## zumbi mirado (headshot): ele cai duro para trás. Depois VOLTA para a mão de
## quem jogou, como o bumerangue (dá para ter até 2 no ar). Sem zumbi na mira,
## vai reto uns 12 m e volta.

const SPEED := 16.0
const AIM_RANGE := 40.0
const AIM_CONE := 0.9 ## dot mínimo entre a mira e a cabeça do zumbi

var cosmetic := false ## cópia de outro jogador: só o visual
var thrower: Node3D ## para onde volta (Player)
var _target: Zombie
var _start := Vector3.ZERO
var _end := Vector3.ZERO
var _t := 0.0
var _duration := 1.0
var _height := 0.35
var _model: Node3D
var _returning := false
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


func launch(start: Vector3, aim: Vector3, target: Zombie, from: Node3D = null) -> void:
	_model = ItemModels.build(&"chinelo")
	_model.scale = Vector3.ONE * 1.3
	add_child(_model)
	thrower = from
	_start = start
	_target = target
	global_position = start
	_end = head_of(target) if target else start + aim.normalized() * 12.0
	_duration = clampf(_start.distance_to(_end) / SPEED, 0.15, 2.0)


func _physics_process(delta: float) -> void:
	_life += delta
	_model.rotate_y(delta * 16.0) # gira no ar
	if _life > 8.0:
		_finish()
		return
	if _returning:
		if not is_instance_valid(thrower):
			_finish()
			return
		_end = _hand_point()
	elif is_instance_valid(_target):
		_end = head_of(_target) # a cabeça anda: o chinelo segue
	_t = minf(_t + delta / _duration, 1.0)
	global_position = _start.lerp(_end, _t) + Vector3.UP * sin(_t * PI) * _height * _duration
	if _t < 1.0:
		return
	if _returning:
		_finish()
		return
	if not cosmetic and is_instance_valid(_target):
		_target.slipper_hit((_end - _start).normalized())
	# Volta para a mão (a cópia de outro jogador some aqui).
	if not is_instance_valid(thrower):
		_finish()
		return
	_returning = true
	_start = global_position
	_end = _hand_point()
	_height = 0.8
	_t = 0.0
	_duration = clampf(_start.distance_to(_end) / SPEED, 0.15, 2.5)


func _hand_point() -> Vector3:
	if thrower is Player:
		return thrower.camera.global_position - Vector3.UP * 0.3
	return thrower.global_position + Vector3.UP * 1.3


func _finish() -> void:
	if is_instance_valid(thrower) and thrower.has_method("catch_slipper"):
		thrower.catch_slipper()
	queue_free()
