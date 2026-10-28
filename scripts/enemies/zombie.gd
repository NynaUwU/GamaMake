class_name Zombie
extends CharacterBody3D
## IA simples do zumbi + vida + ligação entre golpe, reação, queda e morte.
##
## Estados:
##   IDLE      -> parado até ver o player
##   CHASE     -> anda (ou rasteja) até o player
##   ATTACK    -> ergue os braços e golpeia
##   STAGGER   -> tranco: tronco balança e dá um ou dois passos para trás
##   STUMBLE   -> perdeu o equilíbrio: cambaleia como bêbado, quase cai
##   DOWN      -> caído em ragdoll (perdeu o equilíbrio de vez, perna, explosão)
##   GETTING_UP-> levanta em etapas (ou volta a rastejar)
##   IMPALED   -> espetado na espada do player (ragdoll preso pelo peito)
##   DEAD      -> ragdoll permanente
##
## Membros (cabeça, braços, pernas) têm vida própria. Quando a vida do membro
## acaba: golpe de corte (espada) arranca; golpe de impacto (taco, chute, tiro)
## quebra — o membro fica mole. Sem uma perna (ou com ela quebrada) o zumbi
## cai e passa a rastejar. Cabeça destruída mata.

signal died(zombie: Zombie)

enum State { IDLE, CHASE, ATTACK, STAGGER, STUMBLE, DOWN, GETTING_UP, DEAD, IMPALED }
enum LimbState { OK, BROKEN, CUT }

const LAYER_HITBOX := 1 << 4

## Multiplicador de dano no corpo por osso (cabeça dói mais).
const BONE_DAMAGE := {
	&"Head": 2.5, &"Chest": 1.0, &"Spine": 1.0, &"Hips": 0.9,
	&"UpperArm.L": 0.6, &"LowerArm.L": 0.5, &"UpperArm.R": 0.6, &"LowerArm.R": 0.5,
	&"UpperLeg.L": 0.7, &"LowerLeg.L": 0.6, &"UpperLeg.R": 0.7, &"LowerLeg.R": 0.6,
}
const LEG_BONES := [&"UpperLeg.L", &"LowerLeg.L", &"UpperLeg.R", &"LowerLeg.R"]

## Membros com vida própria. "kind" casa com HitInfo.limb_bias.
const LIMBS := {
	&"Head": {"kind": "head", "bones": [&"Head"]},
	&"ArmL": {"kind": "arm", "bones": [&"UpperArm.L", &"LowerArm.L"]},
	&"ArmR": {"kind": "arm", "bones": [&"UpperArm.R", &"LowerArm.R"]},
	&"LegL": {"kind": "leg", "bones": [&"UpperLeg.L", &"LowerLeg.L"]},
	&"LegR": {"kind": "leg", "bones": [&"UpperLeg.R", &"LowerLeg.R"]},
}

@export var max_health := 100.0
@export var move_speed := 1.6
@export var crawl_speed := 0.6
@export var detect_range := 22.0
@export var attack_range := 1.6
@export var attack_damage := 12.0
@export var attack_windup := 0.55
@export var attack_cooldown := 1.2
@export var down_time := 2.2 ## tempo mínimo caído antes de levantar
@export var getup_blend_time := 0.35 ## do ragdoll para a primeira pose de levantar
@export var getup_step_time := 0.45 ## duração de cada etapa de levantar
@export var step_time := 0.3 ## duração de cada passo do tranco (1 ou 2 passos)
@export var step_speed := 1.5
@export var turn_speed := 7.0

@export_group("Membros")
@export var head_health := 70.0
@export var arm_health := 35.0
@export var leg_health := 50.0

@export_group("Equilíbrio")
## Cada golpe tira equilíbrio (balance sobe). Passou de stumble_at: cambaleia.
## Passou de fall_at: cai em ragdoll. O equilíbrio volta sozinho com o tempo.
@export var stumble_at := 0.55
@export var fall_at := 1.1
@export var balance_per_force := 0.012 ## força do golpe -> perda de equilíbrio
@export var blunt_balance_multiplier := 1.45 ## taco/chute derrubam mais
@export var pierce_balance_multiplier := 0.5 ## tiro quase não desequilibra
@export var leg_hit_multiplier := 1.5 ## golpe na perna desequilibra mais
@export var balance_recovery := 0.45 ## por segundo
@export var stumble_speed := 2.0
@export var torso_stiffness := 55.0 ## mola que traz o tronco de volta para cima
@export var torso_damping := 6.0

var state := State.IDLE
var health := max_health
var target: Node3D
var balance := 0.0 ## 0 = firme
var crawler := false ## sem perna: rasteja

var _state_time := 0.0
var _attack_hit_done := false
var _cooldown := 0.0
var _stagger_velocity := Vector3.ZERO
var _stagger_duration := 0.3
var _stumble_dir := Vector3.ZERO
var _stumble_duration := 1.0
var _stumble_power := 1.0
var _lean := Vector2.ZERO # inclinação do tronco (mola), espaço local
var _lean_velocity := Vector2.ZERO
var _buckle := Vector2.ZERO
var _limb_hp := {}
var _limb_state := {}
var _cut_bones: Array[StringName] = []
var _fall_pending := false
var _getup_progress := 0.0
var _standing_shape: Shape3D
var _standing_shape_transform: Transform3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var locomotion: ZombieLocomotion = $Skeleton3D/Locomotion
@onready var hit_reaction: HitReaction = $Skeleton3D/HitReaction
@onready var limp_limbs: LimpLimbs = $Skeleton3D/LimpLimbs
@onready var ragdoll: Ragdoll = $Skeleton3D/PhysicalBoneSimulator3D


func _ready() -> void:
	health = max_health
	move_speed *= randf_range(0.85, 1.25)
	for limb in LIMBS:
		_limb_state[limb] = LimbState.OK
		_limb_hp[limb] = {"head": head_health, "arm": arm_health, "leg": leg_health}[LIMBS[limb].kind]
	_standing_shape = collision.shape
	_standing_shape_transform = collision.transform
	ragdoll.blend_finished.connect(_on_ragdoll_blended_out)
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
		State.GETTING_UP:
			_update_getting_up(delta)
		State.DEAD, State.IMPALED:
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
	_face(to_target, delta, turn_speed * (0.5 if crawler else 1.0))
	var reach := attack_range * (0.8 if crawler else 1.0)
	if to_target.length() <= reach and _cooldown <= 0.0:
		_set_state(State.ATTACK)
		return
	var desired := to_target.normalized() * (crawl_speed if crawler else move_speed)
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
	# Passos para trás em velocidade constante, freando só no fim do último.
	var fade := 1.0 - smoothstep(_stagger_duration - 0.12, _stagger_duration, _state_time)
	var target_velocity := _stagger_velocity * fade
	velocity.x = lerpf(velocity.x, target_velocity.x, 1.0 - exp(-14.0 * delta))
	velocity.z = lerpf(velocity.z, target_velocity.z, 1.0 - exp(-14.0 * delta))
	if _state_time > _stagger_duration:
		_set_state(State.CHASE)


func _update_stumble(delta: float) -> void:
	# Andar de bêbado: vai na direção do empurrão, ziguezagueando e perdendo força.
	var k := clampf(_state_time / _stumble_duration, 0.0, 1.0)
	var zigzag := _stumble_dir.rotated(Vector3.UP, sin(_state_time * 6.0) * 0.8)
	var desired := zigzag * stumble_speed * _stumble_power * (1.0 - k) * (0.6 + balance)
	velocity.x = lerpf(velocity.x, desired.x, 1.0 - exp(-6.0 * delta))
	velocity.z = lerpf(velocity.z, desired.z, 1.0 - exp(-6.0 * delta))
	if _state_time >= _stumble_duration:
		_set_state(State.CHASE)


func _update_down() -> void:
	var settled := ragdoll.get_average_speed() < 0.4
	if _state_time > down_time and (settled or _state_time > down_time + 2.0):
		_get_up()


func _update_getting_up(delta: float) -> void:
	if ragdoll.is_ragdolling():
		return # ainda misturando do ragdoll para a primeira pose
	if crawler:
		_finish_get_up()
		return
	_getup_progress += delta / getup_step_time
	locomotion.getup_t = _getup_progress
	if _getup_progress >= 3.0:
		_finish_get_up()


# --- Dano ------------------------------------------------------------------

## Chamado pelas armas do player.
func take_hit(hit: HitInfo) -> void:
	if hit.bone in _cut_bones:
		return
	var limb := _limb_of(hit.bone)
	if state == State.IMPALED:
		# Espetado: apanha, mas continua na lâmina até o player soltar.
		_hurt(hit.damage * BONE_DAMAGE.get(hit.bone, 1.0))
		ragdoll.apply_hit(hit.bone, hit.direction * hit.force, hit.point)
		return
	if state == State.DEAD:
		if hit.type == HitInfo.Type.CUT and limb != &"":
			_damage_limb(limb, hit) # dá para arrancar pedaços do corpo caído
		ragdoll.apply_hit(hit.bone, hit.direction * hit.force, hit.point)
		return
	health -= hit.damage * BONE_DAMAGE.get(hit.bone, 1.0)
	if limb != &"":
		_damage_limb(limb, hit)
	if health <= 0.0:
		_die(hit.bone, hit.point, hit.direction * hit.force * 1.3)
		return
	if state == State.DOWN or state == State.GETTING_UP:
		# Bateu no zumbi caído: ele volta (ou continua) no chão.
		_knock_down(hit.bone, hit.point, hit.direction * hit.force)
		return
	hit_reaction.add_hit(hit.bone, hit.direction, clampf(hit.force / 25.0, 0.4, 2.5))

	# Tronco é jogado na direção do golpe e volta como mola (pés ficam no lugar).
	_lean_velocity += _to_local_flat(hit.direction) * hit.force * 0.09
	balance += _balance_loss(hit)

	if _fall_pending or balance >= fall_at:
		_fall_pending = false
		_knock_down(hit.bone, hit.point, hit.direction * hit.force)
	elif not crawler and (balance >= stumble_at or state == State.STUMBLE):
		_stumble(hit.direction, hit.force)
	else:
		_stagger(hit.direction, hit.force)


## Equilíbrio perdido no golpe; golpe na perna faz o joelho ceder.
func _balance_loss(hit: HitInfo) -> float:
	var loss := hit.force * balance_per_force * randf_range(0.75, 1.3)
	match hit.type:
		HitInfo.Type.BLUNT:
			loss *= blunt_balance_multiplier
		HitInfo.Type.PIERCE:
			loss *= pierce_balance_multiplier
	if hit.knockdown:
		loss = maxf(loss, 0.8 * randf_range(0.9, 1.15)) # chute: cambaleia feio; cai se já estava tonto
	if hit.bone in LEG_BONES:
		loss *= leg_hit_multiplier
		if String(hit.bone).ends_with(".L"):
			_buckle.x = 1.0
		else:
			_buckle.y = 1.0
	return loss


## Explosão: joga o zumbi longe (ragdoll). Se matar, despedaça o corpo inteiro.
func take_explosion(center: Vector3, damage: float, force: float) -> void:
	if state == State.IMPALED and _impale_died:
		_set_state(State.DEAD)
	if state != State.DEAD:
		health -= damage
		_end_attack()
		_enter_ragdoll()
		if health <= 0.0:
			_set_state(State.DEAD)
			died.emit(self)
			_dismember_all(center, force)
		else:
			_set_state(State.DOWN)
	ragdoll.apply_explosion(center, force)


func _stagger(direction: Vector3, force: float) -> void:
	_end_attack()
	var flat := Vector3(direction.x, 0, direction.z).normalized()
	if crawler:
		# Rastejando não dá passos: só é arrastado um pouco.
		_stagger_duration = 0.25
		_stagger_velocity = flat * 0.4
	else:
		# Um passo para trás; golpe mais forte (ou sorte) = dois passos.
		var steps := 2 if force > 40.0 or randf() < 0.35 else 1
		_stagger_duration = step_time * steps
		_stagger_velocity = flat * step_speed * clampf(force / 30.0, 0.8, 1.6)
	_set_state(State.STAGGER)


func _stumble(direction: Vector3, force: float) -> void:
	_end_attack()
	_stumble_power = clampf(force / 50.0, 1.0, 2.6) # chute e taco empurram mais longe
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
	balance = 0.0
	if locomotion.mode == ZombieLocomotion.Mode.GETUP:
		locomotion.mode = ZombieLocomotion.Mode.CRAWL if crawler else ZombieLocomotion.Mode.WALK
	collision.set_deferred("disabled", true)
	_set_hitboxes_enabled(false)


# --- Empalado --------------------------------------------------------------

var _impale_died := false


func can_be_impaled() -> bool:
	return state not in [State.IMPALED, State.DEAD, State.DOWN, State.GETTING_UP]


## A espada atravessou o zumbi: vira ragdoll preso pela lâmina.
func impale(damage: float, point: Vector3, direction: Vector3) -> void:
	_end_attack()
	_enter_ragdoll()
	_set_state(State.IMPALED)
	_impale_died = false
	_hurt(damage)
	ImpactFX.burst(get_parent(), point, -direction + Vector3.UP * 0.5, ImpactFX.BLOOD, 24, 3.0)


## Chamado a cada frame de física pelo player: puxa o peito até a lâmina.
func hold_impaled(target_point: Vector3, carrier_velocity: Vector3) -> void:
	var chest := ragdoll.get_bone_body(&"Chest")
	if chest == null:
		return
	var pull := (target_point - chest.global_position) * 18.0
	chest.linear_velocity = (pull + carrier_velocity).limit_length(14.0)
	chest.angular_velocity *= 0.8


## Chutado para fora da lâmina.
func release_impaled(impulse: Vector3) -> void:
	if state != State.IMPALED:
		return
	_set_state(State.DEAD if _impale_died else State.DOWN)
	var chest := ragdoll.get_bone_body(&"Chest")
	ragdoll.apply_hit(&"Chest", impulse, chest.global_position if chest else global_position)


func _hurt(amount: float) -> void:
	if _impale_died:
		return
	health -= amount
	if health <= 0.0:
		_impale_died = true
		died.emit(self)


# --- Levantar --------------------------------------------------------------

func _get_up() -> void:
	_set_state(State.GETTING_UP)
	# De bruços ou de costas? (frente do quadril apontando para o chão = de bruços)
	var hips := ragdoll.get_bone_body(&"Hips")
	var chest := ragdoll.get_bone_body(&"Chest")
	var face_down := (-hips.global_basis.z).dot(Vector3.DOWN) > 0.0 or crawler
	# Raiz vai para onde o quadril caiu, virada para onde a cabeça está:
	# de bruços a cabeça fica na frente (-Z), de costas fica atrás (+Z).
	var root := hips.global_position
	global_position = Vector3(root.x, _find_floor_height(root), root.z)
	var torso := chest.global_position - hips.global_position
	torso.y = 0.0
	if torso.length() > 0.05:
		rotation.y = atan2(-torso.x, -torso.z) if face_down else atan2(torso.x, torso.z)
	_getup_progress = 0.0
	if crawler:
		locomotion.mode = ZombieLocomotion.Mode.CRAWL
	else:
		locomotion.begin_getup(face_down)
	limp_limbs.reset()
	ragdoll.blend_out(getup_blend_time)


func _on_ragdoll_blended_out() -> void:
	if state == State.GETTING_UP:
		_set_hitboxes_enabled(true) # pode apanhar enquanto levanta


func _finish_get_up() -> void:
	locomotion.mode = ZombieLocomotion.Mode.CRAWL if crawler else ZombieLocomotion.Mode.WALK
	_apply_body_shape()
	collision.set_deferred("disabled", false)
	_set_state(State.CHASE)


## Cápsula em pé ou deitada (rastejando).
func _apply_body_shape() -> void:
	if crawler:
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.25
		capsule.height = 1.5
		collision.shape = capsule
		collision.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.25, 0))
	else:
		collision.shape = _standing_shape
		collision.transform = _standing_shape_transform


# --- Membros ---------------------------------------------------------------

func _limb_of(bone: StringName) -> StringName:
	for limb in LIMBS:
		if bone in LIMBS[limb].bones:
			return limb
	return &""


func _damage_limb(limb: StringName, hit: HitInfo) -> void:
	if _limb_state[limb] != LimbState.OK:
		return
	var kind: String = LIMBS[limb].kind
	var amount := hit.damage * hit.bias_for(kind) * randf_range(0.8, 1.25)
	if hit.type == HitInfo.Type.PIERCE:
		amount *= 0.6
	_limb_hp[limb] -= amount
	if _limb_hp[limb] > 0.0:
		return
	if hit.type == HitInfo.Type.CUT:
		# Arranca a partir do osso atingido (no antebraço, só o antebraço sai).
		_cut(hit.bone, hit.direction * hit.force * 0.06 + Vector3.UP * 1.5)
		_limb_state[limb] = LimbState.CUT
	else:
		# Osso quebrado: o membro inteiro fica mole, balançando.
		var bones: Array[StringName] = []
		bones.assign(LIMBS[limb].bones)
		limp_limbs.make_limp(bones)
		_limb_state[limb] = LimbState.BROKEN
		ImpactFX.burst(get_parent(), hit.point, -hit.direction + Vector3.UP, ImpactFX.BLOOD, 8, 1.5)
	match kind:
		"head":
			health = 0.0
		"leg":
			if not crawler and state != State.DEAD:
				crawler = true
				_fall_pending = true


func _cut(bone: StringName, impulse: Vector3) -> void:
	if bone in _cut_bones or not skeleton.has_method("detach_limb"):
		return
	var removed: Array[StringName] = skeleton.detach_limb(bone, impulse)
	_cut_bones.append_array(removed)
	ragdoll.remove_bones(removed)


## Explosão que mata: cabeça, braços e pernas saem voando para longe do centro.
func _dismember_all(center: Vector3, force: float) -> void:
	for bone in [&"Head", &"UpperArm.L", &"UpperArm.R", &"UpperLeg.L", &"UpperLeg.R"]:
		var limb := _limb_of(bone)
		if _limb_state[limb] == LimbState.CUT:
			continue
		var bone_pos := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
		var away := (bone_pos - center).normalized() + Vector3.UP * 0.8
		_cut(bone, away.normalized() * force * 0.03)
		_limb_state[limb] = LimbState.CUT
	ImpactFX.burst(get_parent(), skeleton.global_position + Vector3.UP, Vector3.UP, ImpactFX.BLOOD, 40, 5.0, 0.07)


## Braços que ainda funcionam (sem braços o zumbi ainda morde, mas fraco).
func _arm_count() -> int:
	var arms := 0
	for limb in [&"ArmL", &"ArmR"]:
		if _limb_state[limb] == LimbState.OK:
			arms += 1
	return arms


# --- Utilidades ------------------------------------------------------------

func _try_damage_target() -> void:
	if not is_instance_valid(target):
		return
	var to_target := _flat_to_target()
	var facing := -global_basis.z
	if to_target.length() <= attack_range + 0.4 and facing.dot(to_target.normalized()) > 0.4:
		if target.has_method("take_damage"):
			var damage := attack_damage * maxf(_arm_count(), 1.0) / 2.0
			target.take_damage(damage * (0.7 if crawler else 1.0), to_target.normalized())


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
		var cut: bool = area.get_meta("bone") in _cut_bones
		area.collision_layer = LAYER_HITBOX if enabled and not cut else 0


func _find_floor_height(from: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.5, from + Vector3.DOWN * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if hit else from.y - 0.2
