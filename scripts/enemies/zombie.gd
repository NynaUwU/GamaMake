class_name Zombie
extends CharacterBody3D
## IA simples do zumbi + vida + ligação entre golpe, reação, queda e morte.
##
## Estados:
##   IDLE      -> parado até ver o player
##   CHASE     -> anda até o player
##   ATTACK    -> ergue os braços e golpeia
##   STAGGER   -> tranco curto: tronco balança, pés firmes
##   STUMBLE   -> perdeu o equilíbrio: cambaleia como bêbado, quase cai
##   DOWN      -> caído em ragdoll (perdeu o equilíbrio de vez, explosão)
##   GETTING_UP-> volta da física para a animação
##   DEAD      -> ragdoll permanente

signal died(zombie: Zombie)

enum State { IDLE, CHASE, ATTACK, STAGGER, STUMBLE, DOWN, GETTING_UP, DEAD }

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
@export var stagger_time := 0.3 ## curto = volta a atacar rápido
@export var turn_speed := 7.0

@export_group("Equilíbrio")
## Cada golpe tira equilíbrio (balance sobe). Passou de stumble_at: cambaleia.
## Passou de fall_at: cai em ragdoll. O equilíbrio volta sozinho com o tempo.
@export var stumble_at := 0.55
@export var fall_at := 1.1
@export var balance_per_force := 0.012 ## força do golpe -> perda de equilíbrio
@export var leg_hit_multiplier := 1.5 ## golpe na perna desequilibra mais
@export var balance_recovery := 0.45 ## por segundo
@export var stumble_speed := 2.0
@export var torso_stiffness := 55.0 ## mola que traz o tronco de volta para cima
@export var torso_damping := 6.0

var state := State.IDLE
var health := max_health
var target: Node3D

var _state_time := 0.0
var _attack_hit_done := false
var _cooldown := 0.0
var _stagger_velocity := Vector3.ZERO
var balance := 0.0 ## 0 = firme
var _stumble_dir := Vector3.ZERO
var _stumble_duration := 1.0
var _lean := Vector2.ZERO # inclinação do tronco (mola), espaço local
var _lean_velocity := Vector2.ZERO
var _buckle := Vector2.ZERO
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
		State.STUMBLE:
			_update_stumble(delta)
		State.DOWN:
			_update_down()
		State.GETTING_UP, State.DEAD:
			pass
	if state in [State.IDLE, State.CHASE, State.ATTACK, State.STAGGER, State.STUMBLE]:
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
	_update_balance(delta)
	_update_body_pose(delta)


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


func _update_stumble(delta: float) -> void:
	# Andar de bêbado: vai na direção do empurrão, ziguezagueando e perdendo força.
	var k := clampf(_state_time / _stumble_duration, 0.0, 1.0)
	var zigzag := _stumble_dir.rotated(Vector3.UP, sin(_state_time * 6.0) * 0.8)
	var desired := zigzag * stumble_speed * (1.0 - k) * (0.6 + balance)
	velocity.x = lerpf(velocity.x, desired.x, 1.0 - exp(-6.0 * delta))
	velocity.z = lerpf(velocity.z, desired.z, 1.0 - exp(-6.0 * delta))
	if _state_time >= _stumble_duration:
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

	# Tronco é jogado na direção do golpe e volta como mola (pés ficam no lugar).
	var push := _to_local_flat(direction)
	_lean_velocity += push * force * 0.09

	# Equilíbrio: golpes seguidos acumulam; na perna o joelho cede.
	var loss := force * balance_per_force * randf_range(0.75, 1.3)
	if knockdown:
		loss = 0.8 * randf_range(0.9, 1.15) # chute: cambaleia feio; cai se já estava tonto
	if bone in LEG_BONES:
		loss *= leg_hit_multiplier
		if String(bone).ends_with(".L"):
			_buckle.x = 1.0
		else:
			_buckle.y = 1.0
	balance += loss

	if balance >= fall_at:
		_knock_down(bone, point, direction * force)
	elif balance >= stumble_at or state == State.STUMBLE:
		_stumble(direction)
	else:
		_stagger(direction, force)


## Explosão: joga o zumbi longe (ragdoll) e espalha a força por todos os ossos.
func take_explosion(center: Vector3, damage: float, force: float) -> void:
	if state != State.DEAD:
		health -= damage
		_end_attack()
		_enter_ragdoll()
		_set_state(State.DEAD if health <= 0.0 else State.DOWN)
		if state == State.DEAD:
			died.emit(self)
	ragdoll.apply_explosion(center, force)


func _stagger(direction: Vector3, force: float) -> void:
	_end_attack()
	# Tranco curto: meio passo para trás e já volta para cima do player.
	_stagger_velocity = Vector3(direction.x, 0, direction.z) * clampf(force * 0.04, 0.4, 1.5)
	_set_state(State.STAGGER)


func _stumble(direction: Vector3) -> void:
	_end_attack()
	_stumble_dir = Vector3(direction.x, 0, direction.z).normalized()
	_stumble_duration = randf_range(0.9, 1.5) + balance * 0.4
	_set_state(State.STUMBLE)


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


func _face(direction: Vector3, delta: float, rate: float) -> void:
	if direction.length() < 0.01:
		return
	var wanted := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, wanted, 1.0 - exp(-rate * delta))


func _brake(delta: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-8.0 * delta))
	velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-8.0 * delta))


func _update_balance(delta: float) -> void:
	var recovery := balance_recovery * (0.35 if state == State.STUMBLE else 1.0)
	balance = maxf(balance - recovery * delta, 0.0)
	_buckle = _buckle.move_toward(Vector2.ZERO, delta * 1.8)
	# Mola do tronco: alvo é ficar de pé (ou inclinado, se estiver cambaleando).
	var target_lean := Vector2.ZERO
	if state == State.STUMBLE:
		target_lean = _to_local_flat(_stumble_dir) * (0.25 + balance * 0.5)
	_lean_velocity += ((target_lean - _lean) * torso_stiffness - _lean_velocity * torso_damping) * delta
	_lean = (_lean + _lean_velocity * delta).limit_length(0.9)


## Passa o estado do corpo para a animação procedural.
func _update_body_pose(delta: float) -> void:
	var flat := Vector3(velocity.x, 0, velocity.z)
	locomotion.speed = flat.length() if state != State.DOWN else 0.0
	if flat.length() > 0.05:
		locomotion.move_dir = _to_local_flat(flat)
	locomotion.lean = _lean
	locomotion.buckle = _buckle
	var stumbling := 1.0 if state == State.STUMBLE else 0.0
	var dizzy := clampf(balance / stumble_at, 0.0, 1.0)
	var t := 1.0 - exp(-8.0 * delta)
	locomotion.wobble = lerpf(locomotion.wobble, maxf(stumbling, dizzy * 0.4), t)
	locomotion.flail = lerpf(locomotion.flail, stumbling * clampf(balance + 0.4, 0.0, 1.0), t)
	locomotion.crouch = lerpf(locomotion.crouch, stumbling * (0.05 + balance * 0.15) + dizzy * 0.03, t)


## Direção do mundo -> (lado, frente/trás) no espaço local do zumbi.
func _to_local_flat(direction: Vector3) -> Vector2:
	var local := global_basis.inverse() * direction
	return Vector2(local.x, local.z)


func _set_hitboxes_enabled(enabled: bool) -> void:
	for area in find_children("Hitbox", "Area3D", true, false):
		area.collision_layer = LAYER_HITBOX if enabled else 0


func _find_floor_height(from: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.5, from + Vector3.DOWN * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if hit else from.y - 0.2
