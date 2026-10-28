class_name MagicMissile
extends Node3D
## Míssil mágico: voa reto, curva de leve na direção do zumbi mais próximo à
## frente e explode ao encostar em qualquer coisa (ou quando o tempo acaba).

const MASK := 1 | (1 << 2) | (1 << 3) | (1 << 4) # mundo, inimigo, ragdoll, hitbox

@export var speed := 24.0
@export var lifetime := 3.0
@export var homing_turn := 2.5 ## rad/s: quanto ele curva atrás do alvo
@export var homing_range := 30.0
@export var homing_cone := 0.85 ## só persegue alvos dentro deste cone (dot)
@export var explosion_radius := 3.5
@export var explosion_damage := 70.0
@export var explosion_force := 450.0
@export var explosion_kill_radius := 1.3 ## morte instantânea perto do impacto

var velocity := Vector3.ZERO
var shooter: CollisionObject3D

var _age := 0.0
var _target: Node3D
var _exploded := false


func launch(direction: Vector3, from: CollisionObject3D) -> void:
	velocity = direction.normalized() * speed
	shooter = from


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		_explode(global_position)
		return
	_steer(delta)
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, MASK)
	query.collide_with_areas = true
	if shooter:
		query.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		_explode(hit.position + hit.normal * 0.1)
	else:
		global_position = next


func _steer(delta: float) -> void:
	if not _is_valid_target(_target):
		_target = _find_target()
	if _target == null:
		return
	var to_target := (_target.global_position + Vector3.UP * 1.2) - global_position
	var current := velocity.normalized()
	var wanted := to_target.normalized()
	var angle := current.angle_to(wanted)
	if angle < 0.001:
		return
	var axis := current.cross(wanted).normalized()
	if axis.is_zero_approx():
		return
	velocity = current.rotated(axis, minf(angle, homing_turn * delta)) * speed


func _find_target() -> Node3D:
	var best: Node3D = null
	var best_dot := homing_cone
	var forward := velocity.normalized()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not _is_valid_target(enemy):
			continue
		var to_enemy: Vector3 = (enemy.global_position + Vector3.UP * 1.2) - global_position
		if to_enemy.length() > homing_range:
			continue
		var dot := forward.dot(to_enemy.normalized())
		if dot > best_dot:
			best_dot = dot
			best = enemy
	return best


func _is_valid_target(node: Node) -> bool:
	return is_instance_valid(node) and node is Zombie and node.state != Zombie.State.DEAD


func _explode(at: Vector3) -> void:
	if _exploded:
		return
	_exploded = true
	var explosion := Explosion.new()
	get_parent().add_child(explosion)
	explosion.global_position = at
	explosion.detonate(explosion_radius, explosion_damage, explosion_force, explosion_kill_radius)
	queue_free()
