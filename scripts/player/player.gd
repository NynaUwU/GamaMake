class_name Player
extends CharacterBody3D
## Player em primeira pessoa: movimento, golpe corpo a corpo, chute e interação.
## Sem ragdoll — a física dele é só a do CharacterBody3D.

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal interact_prompt_changed(text: String) ## "" = nada para interagir
signal notify(text: String) ## mensagens curtas no HUD
signal item_picked_up(item_id: StringName, amount: int) ## gancho para o inventário futuro
signal died

const MASK_HIT := 1 | (1 << 3) | (1 << 4) # mundo, ragdoll, hitbox
const MASK_INTERACT := 1 | (1 << 5) # mundo, interagível

@export_group("Movimento")
@export var walk_speed := 4.0
@export var sprint_speed := 6.5
@export var jump_velocity := 4.6
@export var acceleration := 12.0
@export var air_control := 0.3
@export var mouse_sensitivity := 0.0025
@export var push_force := 1.5 ## empurrar caixas e objetos físicos

@export_group("Combate")
@export var melee_damage := 34.0
@export var melee_force := 32.0
@export var melee_range := 2.3
@export var melee_cost := 12.0
@export var kick_damage := 6.0
@export var kick_force := 95.0
@export var kick_range := 1.9
@export var kick_cost := 22.0

@export_group("Status")
@export var max_health := 100.0
@export var max_stamina := 100.0
@export var stamina_regen := 25.0
@export var sprint_drain := 14.0
@export var interact_range := 2.5

var health := max_health
var stamina := max_stamina

var _busy := false
var _regen_delay := 0.0
var _shake := 0.0
var _interact_target: Node
var _hitstops := 0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon: Node3D = $Head/Camera3D/Weapon
@onready var foot: Node3D = $Head/Camera3D/Foot
@onready var _weapon_rest := weapon.transform
@onready var _foot_rest := foot.transform


func _ready() -> void:
	health = max_health
	stamina = max_stamina
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	foot.visible = false
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif health > 0.0:
		if event.is_action_pressed("attack"):
			_melee()
		elif event.is_action_pressed("kick"):
			_kick()
		elif event.is_action_pressed("interact") and _interact_target:
			_interact_target.interact(self)


func _physics_process(delta: float) -> void:
	if health <= 0.0:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (global_basis * Vector3(input.x, 0, input.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint") and input.y < 0.0 and stamina > 1.0
	var target := direction * (sprint_speed if sprinting else walk_speed)
	var accel := acceleration if is_on_floor() else acceleration * air_control
	var t := 1.0 - exp(-accel * delta)
	velocity.x = lerpf(velocity.x, target.x, t)
	velocity.z = lerpf(velocity.z, target.z, t)
	move_and_slide()
	_push_rigid_bodies()

	if sprinting and direction != Vector3.ZERO:
		_use_stamina(sprint_drain * delta, 0.4)
	_update_stamina(delta)
	_update_interact()
	_update_camera_shake(delta)


# --- Combate ---------------------------------------------------------------

func _melee() -> void:
	if _busy or stamina < melee_cost:
		return
	_busy = true
	_use_stamina(melee_cost)
	var windup := _weapon_rest.translated_local(Vector3(0.15, 0.12, 0.1)).rotated_local(Vector3.FORWARD, -0.6).rotated_local(Vector3.RIGHT, 0.5)
	var strike := _weapon_rest.translated_local(Vector3(-0.35, -0.12, -0.25)).rotated_local(Vector3.FORWARD, 0.9).rotated_local(Vector3.RIGHT, -0.9)
	var tween := create_tween()
	tween.tween_property(weapon, "transform", windup, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(weapon, "transform", strike, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_callback(_do_hit.bind(melee_range, melee_damage, melee_force, false))
	tween.tween_property(weapon, "transform", _weapon_rest, 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): _busy = false)


func _kick() -> void:
	if _busy or stamina < kick_cost:
		return
	_busy = true
	_use_stamina(kick_cost)
	foot.visible = true
	foot.transform = _foot_rest
	var out := _foot_rest.translated_local(Vector3(0, 0.25, -0.6))
	var tween := create_tween()
	tween.tween_property(foot, "transform", out, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_do_hit.bind(kick_range, kick_damage, kick_force, true))
	tween.tween_property(foot, "transform", _foot_rest, 0.25)
	tween.tween_callback(func():
		foot.visible = false
		_busy = false)


func _do_hit(reach: float, damage: float, force: float, knockdown: bool) -> void:
	var hit := _cast_melee(reach)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	var direction := -camera.global_basis.z
	if knockdown:
		direction = (Vector3(direction.x, 0, direction.z).normalized() + Vector3.UP * 0.25).normalized()

	if collider.has_meta("enemy"):
		var enemy = collider.get_meta("enemy")
		if is_instance_valid(enemy) and enemy.has_method("take_hit"):
			enemy.take_hit(damage, collider.get_meta("bone"), hit.position, direction, force, knockdown)
			_hitstop(0.07 if knockdown else 0.05)
			_shake = 0.12
	elif collider is RigidBody3D:
		collider.apply_impulse(direction * force * 0.4, hit.position - collider.global_position)
		_shake = 0.06
	else:
		_shake = 0.05 # bateu na parede


## Vários raios em leque: golpe corpo a corpo não precisa de mira perfeita.
func _cast_melee(reach: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var origin := camera.global_position
	var basis := camera.global_basis
	var best := {}
	var best_dist := INF
	for offset in [Vector2.ZERO, Vector2(-0.15, 0), Vector2(0.15, 0), Vector2(0, -0.12), Vector2(0, 0.12)]:
		var dir: Vector3 = (-basis.z + basis.x * offset.x + basis.y * offset.y).normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, MASK_HIT, [get_rid()])
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var dist := origin.distance_to(hit.position)
		# Prefere acertar inimigo a acertar parede quando os dois estão no leque.
		if hit.collider.has_meta("enemy"):
			dist -= 0.5
		if dist < best_dist:
			best_dist = dist
			best = hit
	return best


func take_damage(amount: float, from_direction := Vector3.ZERO) -> void:
	if health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	_shake = 0.2
	velocity += from_direction * 3.0
	if health <= 0.0:
		notify.emit("Você morreu - aperte R para recomeçar")
		died.emit()


func heal(amount: float) -> void:
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)


## Congela o jogo por um instante no impacto: dá peso ao golpe.
func _hitstop(duration: float) -> void:
	_hitstops += 1
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	_hitstops -= 1
	if _hitstops == 0:
		Engine.time_scale = 1.0


# --- Interação (base para o inventário) -----------------------------------

func _update_interact() -> void:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * interact_range, MASK_INTERACT, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var found: Node = null
	if hit and hit.collider.is_in_group("interactable"):
		found = hit.collider
	if found != _interact_target:
		_interact_target = found
		interact_prompt_changed.emit(found.get_interact_text() if found else "")


func pick_up(item_id: StringName, display_name: String, amount: int) -> void:
	item_picked_up.emit(item_id, amount)
	notify.emit("Pegou: %s x%d" % [display_name, amount])


# --- Utilidades ------------------------------------------------------------

func _use_stamina(amount: float, delay := 0.8) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_regen_delay = delay
	stamina_changed.emit(stamina, max_stamina)


func _update_stamina(delta: float) -> void:
	_regen_delay -= delta
	if _regen_delay <= 0.0 and stamina < max_stamina:
		stamina = minf(stamina + stamina_regen * delta, max_stamina)
		stamina_changed.emit(stamina, max_stamina)


func _push_rigid_bodies() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as RigidBody3D
		if body:
			var push := -collision.get_normal()
			push.y = 0.0
			body.apply_central_impulse(push * push_force)


func _update_camera_shake(delta: float) -> void:
	_shake = maxf(_shake - delta, 0.0)
	var amount := _shake * 0.15
	camera.h_offset = randf_range(-amount, amount)
	camera.v_offset = randf_range(-amount, amount)
