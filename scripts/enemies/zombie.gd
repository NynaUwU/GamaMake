class_name Zombie
extends CharacterBody3D
## IA simples do zumbi + vida + ligação entre golpe, reação, queda e morte.
##
## Estados:
##   IDLE      -> parado até ver o player
##   CHASE     -> anda até o player
##   ATTACK    -> ergue os braços e golpeia
##   STAGGER   -> cambaleia depois de apanhar
##   DOWN      -> caído em ragdoll (chute, golpe na perna)
##   GETTING_UP-> volta da física para a animação
##   DEAD      -> ragdoll permanente

signal died(zombie: Zombie)

enum State { IDLE, CHASE, ATTACK, STAGGER, DOWN, GETTING_UP, DEAD }

const LAYER_HITBOX := 1 << 4

## Multiplicador de dano por osso (cabeça dói mais).
const BONE_DAMAGE := {
	&"Head": 2.5, &"Chest": 1.0, &"Spine": 1.0, &"Hips": 0.9,
	&"UpperArm.L": 0.6, &"LowerArm.L": 0.5, &"UpperArm.R": 0.6, &"LowerArm.R": 0.5,
	&"UpperLeg.L": 0.7, &"LowerLeg.L": 0.6, &"UpperLeg.R": 0.7, &"LowerLeg.R": 0.6,
}
const LEG_BONES := [&"UpperLeg.L", &"LowerLeg.L", &"UpperLeg.R", &"LowerLeg.R"]

@export var max_health := 100.0
@export var move_speed := 1.6
@export var detect_range := 22.0
@export var attack_range := 1.6
@export var attack_damage := 12.0
@export var attack_windup := 0.55
@export var attack_cooldown := 1.2
@export var down_time := 2.2 ## tempo mínimo caído antes de levantar
@export var get_up_time := 0.9
@export var leg_knockdown_chance := 0.35
@export var stagger_time := 0.35 ## curto = volta a atacar rápido
@export var turn_speed := 7.0

var state := State.IDLE
var health := max_health
var target: Node3D

var _state_time := 0.0
var _attack_hit_done := false
var _cooldown := 0.0
var _stagger_velocity := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var locomotion: ZombieLocomotion = $Skeleton3D/Locomotion
@onready var hit_reaction: HitReaction = $Skeleton3D/HitReaction
@onready var ragdoll: Ragdoll = $Skeleton3D/PhysicalBoneSimulator3D


func _ready() -> void:
	health = max_health
	move_speed *= randf_range(0.85, 1.25)
	ragdoll.blend_finished.connect(_on_get_up_finished)
	if target == null:
		target = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_state_time += delta
	_cooldown -= delta
	match state:
		State.IDLE:
			_update_idle(delta)
		State.CHASE:
			_update_chase(delta)
		State.ATTACK:
			_update_attack(delta)
		State.STAGGER:
			_update_stagger(delta)
		State.DOWN:
			_update_down()
		State.GETTING_UP, State.DEAD:
			pass
	if state in [State.IDLE, State.CHASE, State.ATTACK, State.STAGGER]:
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
	locomotion.speed = Vector2(velocity.x, velocity.z).length() if state != State.DOWN else 0.0


# --- Estados ---------------------------------------------------------------

func _update_idle(delta: float) -> void:
	_brake(delta)
	if _can_see_target():
		_set_state(State.CHASE)


func _update_chase(delta: float) -> void:
	if not is_instance_valid(target) or not _can_see_target():
		_set_state(State.IDLE)
		return
	var to_target := _flat_to_target()
	_face(to_target, delta, turn_speed)
	if to_target.length() <= attack_range and _cooldown <= 0.0:
		_set_state(State.ATTACK)
		return
	var desired := to_target.normalized() * move_speed
	velocity.x = lerpf(velocity.x, desired.x, 1.0 - exp(-5.0 * delta))
	velocity.z = lerpf(velocity.z, desired.z, 1.0 - exp(-5.0 * delta))


func _update_attack(delta: float) -> void:
	_brake(delta)
	_face(_flat_to_target(), delta, turn_speed * 0.4)
	var windup := clampf(_state_time / attack_windup, 0.0, 1.0)
	locomotion.attack = windup
	if _state_time >= attack_windup:
		locomotion.swing = clampf((_state_time - attack_windup) / 0.15, 0.0, 1.0)
		if not _attack_hit_done:
			_attack_hit_done = true
			_try_damage_target()
	if _state_time >= attack_windup + 0.45:
		_end_attack()
		_cooldown = attack_cooldown
		_set_state(State.CHASE)


func _update_stagger(delta: float) -> void:
	velocity.x = _stagger_velocity.x
	velocity.z = _stagger_velocity.z
	_stagger_velocity = _stagger_velocity.lerp(Vector3.ZERO, 1.0 - exp(-9.0 * delta))
	if _state_time > stagger_time:
		_set_state(State.CHASE)


func _update_down() -> void:
	var settled := ragdoll.get_average_speed() < 0.4
	if _state_time > down_time and (settled or _state_time > down_time + 2.0):
		_get_up()


# --- Dano ------------------------------------------------------------------

## Chamado pelo player. direction = direção do golpe (normalizada).
func take_hit(damage: float, bone: StringName, point: Vector3, direction: Vector3,
		force: float, knockdown := false) -> void:
	if state == State.DEAD:
		ragdoll.apply_hit(bone, direction * force, point)
		return
	health -= damage * BONE_DAMAGE.get(bone, 1.0)
	if health <= 0.0:
		_die(bone, point, direction * force * 1.3)
		return
	if state == State.DOWN or state == State.GETTING_UP:
		# Bateu no zumbi caído: ele volta (ou continua) no chão.
		_knock_down(bone, point, direction * force)
		return
	hit_reaction.add_hit(bone, direction, clampf(force / 25.0, 0.4, 2.5))
	var leg_hit := bone in LEG_BONES and randf() < leg_knockdown_chance
	if knockdown or leg_hit:
		_knock_down(bone, point, direction * force)
	else:
		_stagger(direction, force)


func _stagger(direction: Vector3, force: float) -> void:
	_end_attack()
	# Empurrão forte e curto: o zumbi é jogado para trás e logo volta para cima do player.
	_stagger_velocity = Vector3(direction.x, 0, direction.z) * clampf(force * 0.1, 1.0, 4.5)
	_set_state(State.STAGGER)


func _knock_down(bone: StringName, point: Vector3, impulse: Vector3) -> void:
	_end_attack()
	_enter_ragdoll()
	ragdoll.apply_hit(bone, impulse, point)
	_set_state(State.DOWN)


func _die(bone: StringName, point: Vector3, impulse: Vector3) -> void:
	_end_attack()
	_enter_ragdoll()
	ragdoll.apply_hit(bone, impulse, point)
	_set_state(State.DEAD)
	died.emit(self)


func _enter_ragdoll() -> void:
	ragdoll.start(Vector3(velocity.x, 0, velocity.z))
	velocity = Vector3.ZERO
	collision.set_deferred("disabled", true)
	_set_hitboxes_enabled(false)


func _get_up() -> void:
	_set_state(State.GETTING_UP)
	# Leva o nó raiz para onde o corpo caiu e vira para o player.
	var hips := ragdoll.get_root_position()
	global_position = Vector3(hips.x, _find_floor_height(hips), hips.z)
	if is_instance_valid(target):
		var to_target := _flat_to_target()
		if to_target.length() > 0.01:
			rotation.y = atan2(-to_target.x, -to_target.z)
	ragdoll.blend_out(get_up_time)


func _on_get_up_finished() -> void:
	if state != State.GETTING_UP:
		return
	collision.set_deferred("disabled", false)
	_set_hitboxes_enabled(true)
	_set_state(State.CHASE)


# --- Utilidades ------------------------------------------------------------

func _try_damage_target() -> void:
	if not is_instance_valid(target):
		return
	var to_target := _flat_to_target()
	var facing := -global_basis.z
	if to_target.length() <= attack_range + 0.4 and facing.dot(to_target.normalized()) > 0.4:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage, to_target.normalized())


func _end_attack() -> void:
	_attack_hit_done = false
	locomotion.attack = 0.0
	locomotion.swing = 0.0


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	if new_state == State.ATTACK:
		_attack_hit_done = false


func _can_see_target() -> bool:
	return is_instance_valid(target) and _flat_to_target().length() < detect_range


func _flat_to_target() -> Vector3:
	var v := target.global_position - global_position
	v.y = 0.0
	return v


func _face(direction: Vector3, delta: float, turn_speed: float) -> void:
	if direction.length() < 0.01:
		return
	var wanted := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, wanted, 1.0 - exp(-turn_speed * delta))


func _brake(delta: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-8.0 * delta))
	velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-8.0 * delta))


func _set_hitboxes_enabled(enabled: bool) -> void:
	for area in find_children("Hitbox", "Area3D", true, false):
		area.collision_layer = LAYER_HITBOX if enabled else 0


func _find_floor_height(from: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.5, from + Vector3.DOWN * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if hit else from.y - 0.2
