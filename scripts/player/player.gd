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

## Combo de espada. Cada golpe é um arco: a lâmina gira em volta de "axis"
## (espaço da câmera), centrado em "pivot", do ângulo "from" ao "to". damage/force multiplicam os valores base.
const SWINGS := [
	{"axis": Vector3(0.1, 1.0, 0.2), "pivot": Vector3(0.1, -0.1, -0.22),
		"from": -1.5, "to": 1.5, "damage": 1.0, "force": 1.0}, # direita -> esquerda, descendo um pouco
	{"axis": Vector3(-0.15, 1.0, -0.2), "pivot": Vector3(-0.05, -0.16, -0.22),
		"from": 1.5, "to": -1.5, "damage": 1.0, "force": 1.0}, # esquerda -> direita, subindo
	{"axis": Vector3(1.0, 0.1, 0.0), "pivot": Vector3(0.12, -0.2, -0.25),
		"from": 1.8, "to": -1.0, "damage": 1.5, "force": 1.5}, # de cima para baixo
]
const ARM_LENGTH := 0.45
const BLADE_LENGTH := 0.98 ## da mão até a ponta
const TRAIL_LIFETIME := 0.1 ## quanto tempo o rastro do corte fica na tela
const GUARD_HAND := Vector3(0.32, -0.34, -0.45) ## posição da mão em guarda
const GUARD_DIR := Vector3(0.2, 0.75, -0.6) ## para onde a lâmina aponta em guarda

enum SwingPhase { NONE, WINDUP, SLASH, RECOVER }

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
@export var melee_force := 30.0
@export var melee_range := 2.4
@export var melee_cost := 10.0
@export var windup_time := 0.12 ## preparação: a lâmina vai para trás
@export var slash_time := 0.13 ## o corte em si (é quando acerta)
@export var recover_time := 0.22 ## volta para a guarda
@export var combo_window := 0.4 ## tempo após o golpe em que o próximo clique continua o combo
@export var max_targets := 2 ## quantos inimigos um corte atravessa
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
@onready var _foot_rest := foot.transform

var _swing_phase := SwingPhase.NONE
var _swing_index := 0
var _swing_time := 0.0
var _swing_angle := 0.0
var _swing_prev_angle := 0.0
var _swing_start := Transform3D()
var _swing_queued := false
var _swing_hits: Array = []
var _since_swing := 99.0
var _roll := 0.0
var _bob := 0.0
var _trail_points: Array = [] # [base, ponta, idade] no espaço da câmera
var _trail_mesh := ImmediateMesh.new()


func _ready() -> void:
	health = max_health
	stamina = max_stamina
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	foot.visible = false
	weapon.transform = _guard_pose()
	_setup_trail()
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
	if _swing_phase == SwingPhase.SLASH:
		_sweep_blade()


func _process(delta: float) -> void:
	_update_swing(delta)


# --- Combate ---------------------------------------------------------------

# Golpe de espada ------------------------------------------------------------

func _melee() -> void:
	if _busy:
		return
	match _swing_phase:
		SwingPhase.WINDUP, SwingPhase.SLASH:
			_swing_queued = true # clique adiantado: emenda o próximo golpe
		SwingPhase.RECOVER:
			_start_swing(_swing_index + 1)
		SwingPhase.NONE:
			_start_swing(_swing_index + 1 if _since_swing < combo_window else 0)


func _start_swing(index: int) -> void:
	if stamina < melee_cost:
		return
	_use_stamina(melee_cost)
	_swing_index = index % SWINGS.size()
	_swing_phase = SwingPhase.WINDUP
	_swing_time = 0.0
	_swing_start = weapon.transform
	_swing_queued = false
	_swing_hits.clear()
	_swing_angle = SWINGS[_swing_index].from
	_swing_prev_angle = _swing_angle


func _update_swing(delta: float) -> void:
	_since_swing += delta
	_update_trail(delta)
	if _swing_phase == SwingPhase.NONE:
		# Balanço leve da arma enquanto anda.
		var moving := Vector2(velocity.x, velocity.z).length() / walk_speed
		_bob += delta * (2.0 + moving * 7.0)
		var bob := Vector3(cos(_bob) * 0.01, absf(sin(_bob)) * 0.015, 0) * (0.3 + moving)
		weapon.transform = _guard_pose().translated(bob)
		_roll = 0.0
		return

	var swing: Dictionary = SWINGS[_swing_index]
	_swing_time += delta
	match _swing_phase:
		SwingPhase.WINDUP:
			var k := clampf(_swing_time / windup_time, 0.0, 1.0)
			weapon.transform = _swing_start.interpolate_with(_arc_pose(swing, swing.from), ease(k, 0.4))
			if k >= 1.0:
				_swing_phase = SwingPhase.SLASH
				_swing_time = 0.0
		SwingPhase.SLASH:
			var k := clampf(_swing_time / slash_time, 0.0, 1.0)
			# Arranque, corte rápido no meio e desaceleração no fim (follow-through).
			var t := ease(k, -1.6)
			_swing_angle = lerpf(swing.from, swing.to, t)
			weapon.transform = _arc_pose(swing, _swing_angle)
			var blade_dir := -weapon.transform.basis.z
			_trail_points.append([weapon.position + blade_dir * 0.35, weapon.position + blade_dir * BLADE_LENGTH, 0.0])
			_roll = -signf(swing.to - swing.from) * 0.06 * absf(swing.axis.normalized().y)
			if k >= 1.0:
				_swing_phase = SwingPhase.RECOVER
				_swing_time = 0.0
				_swing_start = weapon.transform
				if _swing_queued:
					_start_swing(_swing_index + 1)
		SwingPhase.RECOVER:
			var k := clampf(_swing_time / recover_time, 0.0, 1.0)
			weapon.transform = _swing_start.interpolate_with(_guard_pose(), smoothstep(0.0, 1.0, k))
			_roll = 0.0
			if k >= 1.0:
				_swing_phase = SwingPhase.NONE
				_since_swing = 0.0


## Rastro do corte: uma faixa translúcida entre a base e a ponta da lâmina.
func _setup_trail() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trail := MeshInstance3D.new()
	trail.name = "SwingTrail"
	trail.mesh = _trail_mesh
	trail.material_override = material
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(trail)


func _update_trail(delta: float) -> void:
	for point in _trail_points:
		point[2] += delta
	_trail_points = _trail_points.filter(func(p): return p[2] < TRAIL_LIFETIME)
	_trail_mesh.clear_surfaces()
	if _trail_points.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for point in _trail_points:
		var alpha: float = (1.0 - point[2] / TRAIL_LIFETIME) * 0.45
		_trail_mesh.surface_set_color(Color(0.85, 0.85, 0.8, alpha * 0.3))
		_trail_mesh.surface_add_vertex(point[0])
		_trail_mesh.surface_set_color(Color(1.0, 1.0, 0.95, alpha))
		_trail_mesh.surface_add_vertex(point[1])
	_trail_mesh.surface_end()


## Pose da espada num ponto do arco (espaço da câmera).
func _arc_pose(swing: Dictionary, angle: float) -> Transform3D:
	var axis: Vector3 = swing.axis.normalized()
	var dir := Basis(axis, angle) * Vector3.FORWARD
	return Transform3D(_blade_basis(dir, axis), swing.pivot + dir * ARM_LENGTH)


func _guard_pose() -> Transform3D:
	return Transform3D(_blade_basis(GUARD_DIR, Vector3(1, -0.2, 0.3)), GUARD_HAND)


## Basis com -Z apontando para a lâmina e Y = lado fino (o fio corta no plano do arco).
func _blade_basis(dir: Vector3, thin: Vector3) -> Basis:
	var z := -dir.normalized()
	var x := thin.cross(z).normalized()
	return Basis(x, z.cross(x), z)


## Durante o corte, lança raios ao longo da lâmina, cobrindo o trecho do arco
## percorrido desde o último frame (golpe rápido não "pula" o inimigo).
func _sweep_blade() -> void:
	var swing: Dictionary = SWINGS[_swing_index]
	var axis: Vector3 = swing.axis.normalized()
	var space := get_world_3d().direct_space_state
	var origin := camera.global_position
	var cam_basis := camera.global_basis
	var swing_sign := signf(swing.to - swing.from)
	for i in 3:
		var angle := lerpf(_swing_prev_angle, _swing_angle, (i + 1) / 3.0)
		var dir := Basis(axis, angle) * Vector3.FORWARD
		var through: Vector3 = swing.pivot + dir * (ARM_LENGTH + 0.6) # meio da lâmina
		var ray_dir := (cam_basis * through).normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + ray_dir * melee_range, MASK_HIT, [get_rid()])
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		# Direção do golpe = para onde a lâmina está se movendo (+ um pouco para frente).
		var tangent := cam_basis * (axis.cross(dir) * swing_sign)
		var push := (tangent.normalized() * 0.8 + ray_dir * 0.4).normalized()
		_apply_swing_hit(hit, push, swing)
	_swing_prev_angle = _swing_angle


func _apply_swing_hit(hit: Dictionary, direction: Vector3, swing: Dictionary) -> void:
	var collider: Object = hit.collider
	var key: Object = collider.get_meta("enemy") if collider.has_meta("enemy") else collider
	if key in _swing_hits or _swing_hits.size() >= max_targets:
		return
	if collider.has_meta("enemy"):
		if is_instance_valid(key) and key.has_method("take_hit"):
			_swing_hits.append(key)
			key.take_hit(melee_damage * swing.damage, collider.get_meta("bone"), hit.position,
					direction, melee_force * swing.force, false)
			_hitstop(0.06)
			_shake = 0.12
	elif collider is RigidBody3D:
		_swing_hits.append(key)
		collider.apply_impulse(direction * melee_force * 0.4, hit.position - collider.global_position)
		_shake = 0.05


func _kick() -> void:
	if _busy or _swing_phase != SwingPhase.NONE or stamina < kick_cost:
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
	camera.rotation.z = lerpf(camera.rotation.z, _roll, 1.0 - exp(-14.0 * delta))
