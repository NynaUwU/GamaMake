class_name Player
extends CharacterBody3D
## Player em primeira pessoa: movimento, armas, chute e interação.
## Sem ragdoll — a física dele é só a do CharacterBody3D.
## Armas: espada (corta membros), taco (desequilibra), cajado (mísseis
## explosivos) e pistola. Atacar não gasta stamina; stamina é só para correr.

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal interact_prompt_changed(text: String) ## "" = nada para interagir
signal notify(text: String) ## mensagens curtas no HUD
signal item_picked_up(item_id: StringName, amount: int) ## gancho para o inventário futuro
signal died
signal weapon_changed(weapon_text: String) ## nome da arma (+ munição)

enum WeaponType { SWORD, BAT, STAFF, PISTOL }
const WEAPON_ORDER := [WeaponType.SWORD, WeaponType.BAT, WeaponType.STAFF, WeaponType.PISTOL]
const WEAPON_NAMES := {
	WeaponType.SWORD: "Espada", WeaponType.BAT: "Taco",
	WeaponType.STAFF: "Cajado", WeaponType.PISTOL: "Pistola",
}
const MISSILE_SCENE := preload("res://scenes/weapons/magic_missile.tscn")

const MASK_HIT := 1 | (1 << 3) | (1 << 4) # mundo, ragdoll, hitbox
const MASK_AIM := 1 | (1 << 2) | (1 << 4) # mundo, inimigo, hitbox
const MASK_INTERACT := 1 | (1 << 5) # mundo, interagível
const MASK_PROPS := 1 | (1 << 5)

## Combo corpo a corpo (espada e taco usam os mesmos arcos). Cada golpe gira a
## arma em volta de "axis" (espaço da câmera), centrado em "pivot", do ângulo
## "from" ao "to". damage/force multiplicam os valores da arma. "bias" multiplica
## o dano no membro: golpes horizontais decepam cabeça/pernas (depende de onde
## pegam), o golpe de cima arranca braços.
const SWINGS := [
	{"axis": Vector3(0.1, 1.0, 0.2), "pivot": Vector3(0.1, -0.1, -0.22),
		"from": -1.5, "to": 1.5, "damage": 1.0, "force": 1.0,
		"bias": {"head": 2.0, "leg": 1.8, "arm": 0.8}}, # direita -> esquerda, descendo um pouco
	{"axis": Vector3(-0.15, 1.0, -0.2), "pivot": Vector3(-0.05, -0.16, -0.22),
		"from": 1.5, "to": -1.5, "damage": 1.0, "force": 1.0,
		"bias": {"head": 1.8, "leg": 1.6, "arm": 0.9}}, # esquerda -> direita, subindo
	{"axis": Vector3(1.0, 0.1, 0.0), "pivot": Vector3(0.12, -0.2, -0.25),
		"from": 1.8, "to": -1.0, "damage": 1.5, "force": 1.5,
		"bias": {"head": 0.7, "leg": 0.3, "arm": 2.4}}, # de cima para baixo
]
const ARM_LENGTH := 0.45
const TRAIL_LIFETIME := 0.1 ## quanto tempo o rastro do golpe fica na tela
const GUARD_HAND := Vector3(0.32, -0.34, -0.45) ## posição da mão em guarda
const GUARD_DIR := Vector3(0.2, 0.75, -0.6) ## para onde a arma aponta em guarda
const STAFF_REST := Vector3(0.34, -0.5, -0.55)
const PISTOL_REST := Vector3(0.2, -0.21, -0.42)

enum SwingPhase { NONE, WINDUP, SLASH, RECOVER }

@export_group("Movimento")
@export var walk_speed := 4.0
@export var sprint_speed := 6.5
@export var jump_velocity := 4.6
@export var acceleration := 12.0
@export var air_control := 0.3
@export var mouse_sensitivity := 0.0025
@export var push_force := 1.5 ## empurrar caixas e objetos físicos

@export_group("Espada")
@export var melee_damage := 34.0
@export var melee_force := 30.0
@export var melee_range := 2.4
@export var windup_time := 0.12 ## preparação: a arma vai para trás
@export var slash_time := 0.13 ## o golpe em si (é quando acerta)
@export var recover_time := 0.22 ## volta para a guarda
@export var combo_window := 0.4 ## tempo após o golpe em que o próximo clique continua o combo
@export var max_targets := 2 ## quantos inimigos um golpe atravessa

@export_group("Taco")
@export var bat_damage := 24.0
@export var bat_force := 58.0 ## força alta: desequilibra e empurra bem mais que a espada
@export var bat_speed := 0.8 ## multiplicador de velocidade do golpe (mais pesado)

@export_group("Chute")
@export var kick_damage := 6.0
@export var kick_force := 140.0
@export var kick_range := 2.4 ## alcance do chute (pega todos no cone à frente)
@export var kick_cone := 0.35 ## dot mínimo: 0.35 ≈ 70° para cada lado

@export_group("Cajado")
@export var cast_cooldown := 0.4 ## segure o clique para disparar sem parar
@export var equip_time := 0.25

@export_group("Pistola")
@export var pistol_damage := 40.0 ## na cabeça (x2.5) mata com um tiro
@export var pistol_force := 20.0
@export var pistol_range := 80.0
@export var pistol_fire_rate := 0.16 ## tempo mínimo entre tiros
@export var magazine_size := 12
@export var reload_time := 1.1
@export var pistol_spread := 0.006

@export_group("Status")
@export var max_health := 100.0
@export var max_stamina := 100.0
@export var stamina_regen := 25.0
@export var sprint_drain := 14.0
@export var interact_range := 2.5

var health := max_health
var stamina := max_stamina

var _busy := false # chutando
var _regen_delay := 0.0
var _shake := 0.0
var _interact_target: Node
var _hitstops := 0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon: Node3D = $Head/Camera3D/Weapon
@onready var bat: Node3D = $Head/Camera3D/Bat
@onready var staff: Node3D = $Head/Camera3D/Staff
@onready var staff_tip: Node3D = $Head/Camera3D/Staff/Tip
@onready var staff_light: OmniLight3D = $Head/Camera3D/Staff/Tip/Light
@onready var pistol: Node3D = $Head/Camera3D/Pistol
@onready var muzzle: Node3D = $Head/Camera3D/Pistol/Muzzle
@onready var muzzle_flash: Node3D = $Head/Camera3D/Pistol/Muzzle/Flash
@onready var foot: Node3D = $Head/Camera3D/Foot
@onready var _foot_rest := foot.transform

var _weapon_type := WeaponType.SWORD
var _equip := 1.0 # 0 = arma abaixada (trocando), 1 = pronta
var _melee := {} # stats da arma corpo a corpo (montado no _ready)

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
var _trail_color := Color.WHITE

var _cast_timer := 0.0
var _staff_kick := 0.0 # recuo do cajado ao disparar

var _ammo := 0
var _fire_timer := 0.0
var _reload_timer := 0.0
var _pistol_kick := 0.0


func _ready() -> void:
	health = max_health
	stamina = max_stamina
	_ammo = magazine_size
	_melee = {
		WeaponType.SWORD: {"node": weapon, "damage": melee_damage, "force": melee_force, "speed": 1.0,
			"cut": true, "length": 0.98, "trail": Color(1.0, 1.0, 0.95), "hitstop": 0.06},
		WeaponType.BAT: {"node": bat, "damage": bat_damage, "force": bat_force, "speed": bat_speed,
			"cut": false, "length": 0.9, "trail": Color(0.85, 0.75, 0.6), "hitstop": 0.09},
	}
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	foot.visible = false
	muzzle_flash.visible = false
	_setup_trail()
	_show_weapon(_weapon_type)
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
			if _is_melee():
				_melee_attack()
			elif _weapon_type == WeaponType.PISTOL:
				_fire_pistol()
		elif event.is_action_pressed("reload"):
			_start_reload()
		elif event.is_action_pressed("weapon_1"):
			_switch_weapon(WeaponType.SWORD)
		elif event.is_action_pressed("weapon_2"):
			_switch_weapon(WeaponType.BAT)
		elif event.is_action_pressed("weapon_3"):
			_switch_weapon(WeaponType.STAFF)
		elif event.is_action_pressed("weapon_4"):
			_switch_weapon(WeaponType.PISTOL)
		elif event.is_action_pressed("weapon_next"):
			var next: int = (WEAPON_ORDER.find(_weapon_type) + 1) % WEAPON_ORDER.size()
			_switch_weapon(WEAPON_ORDER[next])
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
	_equip = minf(_equip + delta / equip_time, 1.0)
	var moving := Vector2(velocity.x, velocity.z).length() / walk_speed
	_bob += delta * (2.0 + moving * 7.0)
	_update_swing(delta)
	_update_staff(delta)
	_update_pistol(delta)


# Troca de arma ----------------------------------------------------------------

func _switch_weapon(type: WeaponType) -> void:
	if type == _weapon_type or _swing_phase != SwingPhase.NONE or _busy:
		return
	_weapon_type = type
	_equip = 0.0
	_reload_timer = 0.0
	_show_weapon(type)


func _show_weapon(type: WeaponType) -> void:
	weapon.visible = type == WeaponType.SWORD
	bat.visible = type == WeaponType.BAT
	staff.visible = type == WeaponType.STAFF
	pistol.visible = type == WeaponType.PISTOL
	_emit_weapon_text()


func _emit_weapon_text() -> void:
	var text: String = WEAPON_NAMES[_weapon_type]
	if _weapon_type == WeaponType.PISTOL:
		text += "  recarregando..." if _reload_timer > 0.0 else "  %d/%d" % [_ammo, magazine_size]
	weapon_changed.emit(text)


func _is_melee() -> bool:
	return _melee.has(_weapon_type)


## Arma "sobe" da parte de baixo da tela ao ser equipada.
func _equip_offset() -> Vector3:
	return Vector3(0, -0.45, 0.1) * (1.0 - ease(_equip, 0.4))


func _bob_offset(scale: float) -> Vector3:
	var moving := Vector2(velocity.x, velocity.z).length() / walk_speed
	return Vector3(cos(_bob) * 0.01, absf(sin(_bob)) * 0.015, 0) * (0.3 + moving) * scale


# Espada e taco ----------------------------------------------------------------

func _melee_attack() -> void:
	if _busy or _equip < 1.0:
		return
	match _swing_phase:
		SwingPhase.WINDUP, SwingPhase.SLASH:
			_swing_queued = true # clique adiantado: emenda o próximo golpe
		SwingPhase.RECOVER:
			_start_swing(_swing_index + 1)
		SwingPhase.NONE:
			_start_swing(_swing_index + 1 if _since_swing < combo_window else 0)


func _start_swing(index: int) -> void:
	var stats: Dictionary = _melee[_weapon_type]
	_swing_index = index % SWINGS.size()
	_swing_phase = SwingPhase.WINDUP
	_swing_time = 0.0
	_swing_start = stats.node.transform
	_swing_queued = false
	_swing_hits.clear()
	_swing_angle = SWINGS[_swing_index].from
	_swing_prev_angle = _swing_angle
	_trail_color = stats.trail


func _update_swing(delta: float) -> void:
	_since_swing += delta
	_update_trail(delta)
	if not _is_melee():
		return
	var stats: Dictionary = _melee[_weapon_type]
	var node: Node3D = stats.node
	if _swing_phase == SwingPhase.NONE:
		node.transform = _guard_pose().translated(_bob_offset(1.0) + _equip_offset())
		_roll = 0.0
		return

	var swing: Dictionary = SWINGS[_swing_index]
	_swing_time += delta * stats.speed
	match _swing_phase:
		SwingPhase.WINDUP:
			var k := clampf(_swing_time / windup_time, 0.0, 1.0)
			node.transform = _swing_start.interpolate_with(_arc_pose(swing, swing.from), ease(k, 0.4))
			if k >= 1.0:
				_swing_phase = SwingPhase.SLASH
				_swing_time = 0.0
		SwingPhase.SLASH:
			var k := clampf(_swing_time / slash_time, 0.0, 1.0)
			# Arranque, golpe rápido no meio e desaceleração no fim (follow-through).
			var t := ease(k, -1.6)
			_swing_angle = lerpf(swing.from, swing.to, t)
			node.transform = _arc_pose(swing, _swing_angle)
			var dir := -node.transform.basis.z
			_trail_points.append([node.position + dir * 0.35, node.position + dir * stats.length, 0.0])
			_roll = -signf(swing.to - swing.from) * 0.06 * absf(swing.axis.normalized().y)
			if k >= 1.0:
				_swing_phase = SwingPhase.RECOVER
				_swing_time = 0.0
				_swing_start = node.transform
				if _swing_queued:
					_start_swing(_swing_index + 1)
		SwingPhase.RECOVER:
			var k := clampf(_swing_time / recover_time, 0.0, 1.0)
			node.transform = _swing_start.interpolate_with(_guard_pose(), smoothstep(0.0, 1.0, k))
			_roll = 0.0
			if k >= 1.0:
				_swing_phase = SwingPhase.NONE
				_since_swing = 0.0


## Rastro do golpe: uma faixa translúcida entre a base e a ponta da arma.
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
		_trail_mesh.surface_set_color(Color(_trail_color, alpha * 0.3))
		_trail_mesh.surface_add_vertex(point[0])
		_trail_mesh.surface_set_color(Color(_trail_color, alpha))
		_trail_mesh.surface_add_vertex(point[1])
	_trail_mesh.surface_end()


## Pose da arma num ponto do arco (espaço da câmera).
func _arc_pose(swing: Dictionary, angle: float) -> Transform3D:
	var axis: Vector3 = swing.axis.normalized()
	var dir := Basis(axis, angle) * Vector3.FORWARD
	return Transform3D(_blade_basis(dir, axis), swing.pivot + dir * ARM_LENGTH)


func _guard_pose() -> Transform3D:
	return Transform3D(_blade_basis(GUARD_DIR, Vector3(1, -0.2, 0.3)), GUARD_HAND)


## Basis com -Z apontando para a arma e Y = lado fino (o fio corta no plano do arco).
func _blade_basis(dir: Vector3, thin: Vector3) -> Basis:
	var z := -dir.normalized()
	var x := thin.cross(z).normalized()
	return Basis(x, z.cross(x), z)


## Durante o golpe, lança raios ao longo da arma, cobrindo o trecho do arco
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
		var through: Vector3 = swing.pivot + dir * (ARM_LENGTH + 0.6) # meio da arma
		var ray_dir := (cam_basis * through).normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + ray_dir * melee_range, MASK_HIT, [get_rid()])
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		# Direção do golpe = para onde a arma está se movendo (+ um pouco para frente).
		var tangent := cam_basis * (axis.cross(dir) * swing_sign)
		var push := (tangent.normalized() * 0.8 + ray_dir * 0.4).normalized()
		_apply_swing_hit(hit, push, swing)
	_swing_prev_angle = _swing_angle


func _apply_swing_hit(hit: Dictionary, direction: Vector3, swing: Dictionary) -> void:
	var stats: Dictionary = _melee[_weapon_type]
	var collider: Object = hit.collider
	var key: Object = collider.get_meta("enemy") if collider.has_meta("enemy") else collider
	if key in _swing_hits or _swing_hits.size() >= max_targets:
		return
	if collider.has_meta("enemy"):
		if is_instance_valid(key) and key.has_method("take_hit"):
			_swing_hits.append(key)
			var info := HitInfo.make(stats.damage * swing.damage, collider.get_meta("bone"), hit.position,
					direction, stats.force * swing.force, HitInfo.Type.CUT if stats.cut else HitInfo.Type.BLUNT)
			info.limb_bias = swing.bias
			key.take_hit(info)
			_hitstop(stats.hitstop)
			_shake = 0.12
	elif collider is RigidBody3D:
		_swing_hits.append(key)
		collider.apply_impulse(direction * stats.force * 0.4, hit.position - collider.global_position)
		_shake = 0.05


# Cajado -----------------------------------------------------------------------

func _update_staff(delta: float) -> void:
	_cast_timer -= delta
	_staff_kick = move_toward(_staff_kick, 0.0, delta * 5.0)
	staff_light.light_energy = lerpf(staff_light.light_energy, 1.2, 1.0 - exp(-8.0 * delta))
	if _weapon_type != WeaponType.STAFF:
		return
	staff.position = STAFF_REST + _bob_offset(1.3) + _equip_offset() + Vector3(0, 0.03, -0.18) * _staff_kick
	staff.rotation = Vector3(-0.35 - 0.25 * _staff_kick, 0.0, 0.12)
	if health > 0.0 and _equip >= 1.0 and _cast_timer <= 0.0 and Input.is_action_pressed("attack") \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_cast_missile()


func _cast_missile() -> void:
	_cast_timer = cast_cooldown
	_staff_kick = 1.0
	staff_light.light_energy = 6.0
	_shake = maxf(_shake, 0.04)
	# Mira: o que estiver no centro da tela; o míssil sai da ponta do cajado.
	var aim_point := _aim_point(100.0)
	var start := staff_tip.global_position
	# Se a ponta estiver dentro de uma parede (encostado), dispara da câmera.
	if start.distance_to(aim_point) < 0.6:
		start = camera.global_position
	var missile: MagicMissile = MISSILE_SCENE.instantiate()
	get_parent().add_child(missile)
	missile.global_position = start
	missile.launch(aim_point - start, self)


## Ponto no centro da tela (o que a mira está apontando).
func _aim_point(reach: float) -> Vector3:
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * reach, MASK_AIM, [get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else origin + forward * reach


## Chamado pela explosão: treme a tela e empurra se estiver perto.
func explosion_feedback(center: Vector3, radius: float) -> void:
	var distance := global_position.distance_to(center)
	_shake = maxf(_shake, clampf(0.35 - distance * 0.02, 0.05, 0.35))
	if distance < radius:
		var away := (global_position - center).normalized()
		velocity += (away + Vector3.UP * 0.3) * 6.0 * (1.0 - distance / radius)


# Pistola ----------------------------------------------------------------------

func _update_pistol(delta: float) -> void:
	_fire_timer -= delta
	_pistol_kick = move_toward(_pistol_kick, 0.0, delta * 7.0)
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_ammo = magazine_size
			_emit_weapon_text()
	if _weapon_type != WeaponType.PISTOL:
		return
	# Recarregando: a arma abaixa e gira um pouco.
	var reload_dip := sin(clampf(1.0 - _reload_timer / reload_time, 0.0, 1.0) * PI) if _reload_timer > 0.0 else 0.0
	pistol.position = PISTOL_REST + _bob_offset(0.8) + _equip_offset() \
			+ Vector3(0, 0.02, 0.07) * _pistol_kick + Vector3(0, -0.12, 0) * reload_dip
	pistol.rotation = Vector3(0.25 * _pistol_kick - 0.5 * reload_dip, 0.0, 0.6 * reload_dip)


func _fire_pistol() -> void:
	if _equip < 1.0 or _fire_timer > 0.0 or _reload_timer > 0.0:
		return
	if _ammo <= 0:
		_start_reload()
		return
	_ammo -= 1
	_fire_timer = pistol_fire_rate
	_pistol_kick = 1.0
	head.rotation.x = minf(head.rotation.x + 0.012, deg_to_rad(85)) # recuo sobe a mira
	_shake = maxf(_shake, 0.05)
	_flash_muzzle()

	var origin := camera.global_position
	var spread := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * pistol_spread
	var direction := (camera.global_basis * (Vector3.FORWARD + spread)).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * pistol_range, MASK_HIT, [get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.position if hit else origin + direction * pistol_range
	ImpactFX.tracer(get_parent(), muzzle.global_position, end)
	if hit:
		var collider: Object = hit.collider
		if collider.has_meta("enemy"):
			var enemy = collider.get_meta("enemy")
			if is_instance_valid(enemy) and enemy.has_method("take_hit"):
				enemy.take_hit(HitInfo.make(pistol_damage, collider.get_meta("bone"), hit.position,
						direction, pistol_force, HitInfo.Type.PIERCE))
				ImpactFX.burst(get_parent(), hit.position, -direction + hit.normal, ImpactFX.BLOOD, 14, 2.5)
		else:
			if collider is RigidBody3D:
				collider.apply_impulse(direction * pistol_force * 0.5, hit.position - collider.global_position)
			ImpactFX.burst(get_parent(), hit.position, hit.normal, ImpactFX.SPARK, 8, 4.0, 0.03)
	_emit_weapon_text()
	if _ammo == 0:
		_start_reload()


func _start_reload() -> void:
	if _reload_timer > 0.0 or _ammo == magazine_size:
		return
	_reload_timer = reload_time
	_emit_weapon_text()


func _flash_muzzle() -> void:
	muzzle_flash.visible = true
	muzzle_flash.rotation.z = randf() * TAU
	get_tree().create_timer(0.04).timeout.connect(func(): muzzle_flash.visible = false)


# Chute ------------------------------------------------------------------------

func _kick() -> void:
	if _busy or _swing_phase != SwingPhase.NONE:
		return
	_busy = true
	foot.visible = true
	foot.transform = _foot_rest
	var out := _foot_rest.translated_local(Vector3(0, 0.25, -0.6))
	var tween := create_tween()
	tween.tween_property(foot, "transform", out, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_do_kick)
	tween.tween_property(foot, "transform", _foot_rest, 0.25)
	tween.tween_callback(func():
		foot.visible = false
		_busy = false)


## Chute em área: acerta todos os zumbis (e objetos) num cone à frente.
func _do_kick() -> void:
	var origin := global_position + Vector3.UP
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var hit_any := false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.has_method("take_hit"):
			continue
		var point: Vector3 = enemy.global_position + Vector3.UP * 1.2
		if enemy.ragdoll.is_ragdolling():
			point = enemy.ragdoll.get_root_position()
		var to_enemy := point - origin
		var flat := Vector3(to_enemy.x, 0, to_enemy.z)
		if flat.length() > kick_range or absf(to_enemy.y) > 1.6:
			continue
		if flat.length() > 0.3 and forward.dot(flat.normalized()) < kick_cone:
			continue
		var dir := (forward * 0.6 + flat.normalized() * 0.4 + Vector3.UP * 0.25).normalized()
		var info := HitInfo.make(kick_damage, &"Chest", point, dir, kick_force, HitInfo.Type.BLUNT)
		info.knockdown = true
		enemy.take_hit(info)
		hit_any = true
	# Caixas e itens na frente também voam.
	var shape := SphereShape3D.new()
	shape.radius = 1.2
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), origin + forward * 1.1)
	query.collision_mask = MASK_PROPS
	for result in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var body := result.collider as RigidBody3D
		if body:
			body.apply_central_impulse((forward + Vector3.UP * 0.3).normalized() * kick_force * 0.12)
			hit_any = true
	if hit_any:
		_hitstop(0.07)
		_shake = 0.14


func take_damage(amount: float, from_direction := Vector3.ZERO) -> void:
	if health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	_shake = 0.2
	velocity += from_direction * 3.0
	if health <= 0.0:
		notify.emit("Você morreu - aperte Backspace para recomeçar")
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
