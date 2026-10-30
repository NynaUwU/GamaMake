class_name Boomerang
extends Node3D
## Bumerangue: vai até o zumbi mirado e RICOCHETEIA de zumbi em zumbi (até 5).
## A cada acerto ele sobe e voa em arco para o próximo zumbi mais perto; cada
## acerto tem chance de atordoar. No fim volta para a mão de quem jogou.

const SPEED := 20.0
const MAX_HITS := 5
const CHAIN_RANGE := 14.0
const DAMAGE := 18.0
const FORCE := 28.0
const STUN_CHANCE := 0.4
const STUN_TIME := 2.2

var cosmetic := false
var thrower: Node3D ## para onde volta (Player)
var hits: Array = []
var _target: Node3D
var _from := Vector3.ZERO
var _height := 0.6
var _t := 0.0
var _duration := 1.0
var _returning := false
var _model: Node3D
var _life := 0.0


func launch(start: Vector3, aim: Vector3, first: Zombie, from: Node3D) -> void:
	_model = ItemModels.build(&"bumerangue")
	add_child(_model)
	thrower = from
	global_position = start
	if first:
		_go(first, 0.6)
	else:
		# Ninguém na mira: vai reto uns 14 m e volta.
		var probe := Node3D.new()
		probe.top_level = true
		add_child(probe)
		probe.global_position = start + aim.normalized() * 14.0
		_go(probe, 1.2)


func _go(target: Node3D, height: float) -> void:
	_from = global_position
	_target = target
	_height = height
	_t = 0.0
	_duration = clampf(_from.distance_to(_point(target)) / SPEED, 0.15, 2.0)


func _point(target: Node3D) -> Vector3:
	if target is Zombie:
		return ThrownSlipper.head_of(target) - Vector3.UP * 0.25
	if target is Player:
		return target.camera.global_position - Vector3.UP * 0.3
	return target.global_position


func _physics_process(delta: float) -> void:
	_life += delta
	_model.rotate_y(delta * 26.0)
	if not is_instance_valid(_target) or _life > 10.0:
		if _returning or not is_instance_valid(thrower):
			_finish()
			return
		_come_back()
		return
	var end := _point(_target)
	_t = minf(_t + delta / _duration, 1.0)
	global_position = _from.lerp(end, _t) + Vector3.UP * sin(_t * PI) * _height
	if _t < 1.0:
		return
	if _returning:
		_finish()
		return
	if _target is Zombie:
		_hit(_target)
	var next := _next_target()
	if next and hits.size() < MAX_HITS:
		_go(next, 1.6) # bate, sobe e vai para o próximo
	else:
		_come_back()


func _hit(zombie: Zombie) -> void:
	hits.append(zombie)
	if cosmetic:
		return
	var direction := (_point(zombie) - _from).normalized()
	zombie.take_hit(HitInfo.make(DAMAGE, &"Head", _point(zombie), direction, FORCE, HitInfo.Type.BLUNT))
	if randf() < STUN_CHANCE:
		zombie.stun(STUN_TIME)
	ImpactFX.burst(get_parent(), global_position, Vector3.UP, ImpactFX.SPARK, 6, 2.0, 0.03)


func _next_target() -> Zombie:
	var best: Zombie = null
	var best_d := CHAIN_RANGE
	for zombie in get_tree().get_nodes_in_group("enemy"):
		if not zombie is Zombie or zombie in hits or zombie.state == Zombie.State.DEAD:
			continue
		var d: float = global_position.distance_to(_point(zombie))
		if d < best_d:
			best_d = d
			best = zombie
	return best


func _come_back() -> void:
	if not is_instance_valid(thrower):
		_finish()
		return
	_returning = true
	_go(thrower, 1.0)


func _finish() -> void:
	if is_instance_valid(thrower) and thrower.has_method("catch_boomerang"):
		thrower.catch_boomerang()
	queue_free()
