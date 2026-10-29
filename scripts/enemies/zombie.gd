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
##   CLIMB     -> escalando um obstáculo (quando dar a volta é longe demais)
##   DEAD      -> ragdoll permanente
##
## Membros (cabeça, braços, pernas) têm vida própria. Quando a vida do membro
## acaba: golpe de corte (espada) arranca; golpe de impacto (taco, chute, tiro)
## quebra — o membro fica mole. Sem uma perna (ou com ela quebrada) o zumbi
## cai e passa a rastejar. Cabeça destruída mata.

signal died(zombie: Zombie)

enum State { IDLE, CHASE, ATTACK, STAGGER, STUMBLE, DOWN, GETTING_UP, DEAD, IMPALED, CLIMB }
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
@export var broken_limb_damage := 0.15 ## bater num membro já quebrado quase não dói
@export var weapon_chance := 0.3 ## chance de nascer com arma corpo a corpo
@export var weapon_id: StringName = &"" ## força uma arma (vazio = sorteio)
@export var weapon_damage_multiplier := 1.6

@export_group("Navegação")
## Desvia de obstáculos pelo NavigationMesh. Só escala quando o caminho em volta
## é mais que climb_detour_ratio vezes a distância em linha reta (ou não existe).
@export var climb_max_height := 2.3
@export var climb_detour_ratio := 2.0
@export var climb_speed := 0.7 ## segundos por metro de altura (+ base)

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
var _alerted := false # viu a lanterna: persegue de qualquer distância
var _bumped: Array = [] # quem já levou encontrão neste tranco
var _held_weapon: Node3D
var _impale_from_back := false
var _agent: NavigationAgent3D
var _repath_timer := 0.0
var _climb_mode := false # vai em linha reta e escala o que estiver no caminho
var _climb_points: Array[Vector3] = []
var _climb_duration := 1.0

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
	if weapon_id == &"" and randf() < weapon_chance:
		weapon_id = ItemDB.ZOMBIE_WEAPONS.pick_random()
	if weapon_id != &"":
		_equip_weapon.call_deferred(weapon_id)
	_setup_navigation()


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
		State.CLIMB:
			_update_climb(delta)
		State.DEAD, State.IMPALED:
			pass
	if state in [State.IDLE, State.CHASE, State.ATTACK, State.STAGGER, State.STUMBLE]:
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
	_update_balance(delta)
	_update_body_pose(delta)
	_bump_others()


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
	var direction := _chase_direction(to_target, delta)
	# Longe: olha para onde anda (contorna obstáculos). Perto: olha para o player.
	_face(direction if to_target.length() > 3.0 else to_target, delta, turn_speed * (0.5 if crawler else 1.0))
	var reach := attack_range * (0.8 if crawler else 1.0)
	if to_target.length() <= reach and _cooldown <= 0.0:
		_set_state(State.ATTACK)
		return
	if _climb_mode and _try_start_climb(direction):
		return
	var desired := direction * (crawl_speed if crawler else move_speed)
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
	if state == State.CLIMB:
		# Apanhou escalando: despenca.
		health -= hit.damage * BONE_DAMAGE.get(hit.bone, 1.0)
		if health <= 0.0:
			_die(hit.bone, hit.point, hit.direction * hit.force)
		else:
			_knock_down(hit.bone, hit.point, hit.direction * hit.force)
		return
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
	var body_damage: float = hit.damage * BONE_DAMAGE.get(hit.bone, 1.0)
	if limb != &"" and _limb_state[limb] == LimbState.BROKEN:
		body_damage *= broken_limb_damage # osso já quebrado: quase não dói mais
	health -= body_damage
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
			_drop_weapon()
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
	_drop_weapon()
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


## from_direction: direção da lâmina (do player para o zumbi). De lado não espeta;
## de frente ou de costas sim.
func can_be_impaled(from_direction := Vector3.ZERO) -> bool:
	if state in [State.IMPALED, State.DEAD, State.DOWN, State.GETTING_UP] or crawler:
		return false
	if from_direction == Vector3.ZERO:
		return true
	var facing := -global_basis.z
	var to_player := -Vector3(from_direction.x, 0, from_direction.z).normalized()
	var dot := facing.dot(to_player)
	if absf(dot) < 0.5:
		return false
	_impale_from_back = dot < 0.0
	return true


## A espada atravessou o zumbi: vira ragdoll preso pela lâmina.
func impale(damage: float, point: Vector3, direction: Vector3) -> void:
	_end_attack()
	_enter_ragdoll()
	_set_state(State.IMPALED)
	_impale_died = false
	_hurt(damage)
	ImpactFX.burst(get_parent(), point, -direction + Vector3.UP * 0.5, ImpactFX.BLOOD, 24, 3.0)


## Chamado a cada frame de física pelo player: puxa o peito até a lâmina.
func hold_impaled(target_point: Vector3, carrier_velocity: Vector3, blade_direction := Vector3.ZERO) -> void:
	var chest := ragdoll.get_bone_body(&"Chest")
	if chest == null:
		return
	var pull := (target_point - chest.global_position) * 18.0
	chest.linear_velocity = (pull + carrier_velocity).limit_length(14.0)
	if blade_direction == Vector3.ZERO:
		chest.angular_velocity *= 0.8
		return
	# Alinha o tronco com a lâmina: peito (ou costas) virado para o player, em pé.
	var front := -blade_direction if not _impale_from_back else blade_direction
	front.y = 0.0
	var wanted := Basis.looking_at(front.normalized(), Vector3.UP)
	var error := (wanted * chest.global_basis.orthonormalized().inverse()).get_rotation_quaternion()
	var angle := error.get_angle()
	if angle > PI:
		angle -= TAU
	chest.angular_velocity = (error.get_axis() * angle * 10.0).limit_length(12.0)


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
		_drop_weapon()
		died.emit(self)


# --- Reações extras ---------------------------------------------------------

## Player deslizou por baixo: as pernas vão para frente e o zumbi cai.
func trip(direction: Vector3, force: float) -> void:
	if state in [State.DOWN, State.DEAD, State.IMPALED, State.GETTING_UP] or crawler:
		return
	_end_attack()
	_enter_ragdoll()
	_set_state(State.DOWN)
	var flat := Vector3(direction.x, 0, direction.z).normalized()
	for bone in [&"LowerLeg.L", &"LowerLeg.R"]:
		var body := ragdoll.get_bone_body(bone)
		if body:
			ragdoll.apply_hit(bone, (flat + Vector3.UP * 0.6) * force * 0.25, body.global_position)
	ragdoll.apply_hit(&"Chest", -flat * force * 0.3, global_position + Vector3.UP * 1.3)


## O player bloqueou o golpe. Parry (na hora certa) desequilibra muito.
func on_blocked(parry: bool, push_direction: Vector3) -> void:
	if state in [State.DOWN, State.DEAD, State.IMPALED]:
		return
	_end_attack()
	_cooldown = attack_cooldown * (1.5 if parry else 1.0)
	_lean_velocity += _to_local_flat(push_direction) * (4.0 if parry else 2.0)
	if parry:
		balance += stumble_at + 0.1
		_stumble(push_direction, 40.0)
	else:
		_stagger(push_direction, 25.0)


## Lanterna na cara: vem atrás do player de qualquer distância.
func alert(who: Node3D) -> void:
	target = who
	_alerted = true
	if state == State.IDLE:
		_set_state(State.CHASE)


## Zumbi cambaleando (ou voando em ragdoll) esbarra nos outros e empurra um pouco.
func _bump_others() -> void:
	var moving := Vector3(velocity.x, 0, velocity.z)
	var center := global_position
	var push := 0.0
	if state in [State.STUMBLE, State.STAGGER] and moving.length() > 1.0:
		push = 1.0
	elif state in [State.DOWN, State.DEAD] and ragdoll.is_ragdolling():
		var hips := ragdoll.get_bone_body(&"Hips")
		if hips and hips.linear_velocity.length() > 3.0:
			moving = hips.linear_velocity
			moving.y = 0.0
			center = hips.global_position
			push = 1.6
	if push == 0.0:
		_bumped.clear()
		return
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self or other in _bumped or not other.has_method("bumped"):
			continue
		var offset: Vector3 = other.global_position - center
		offset.y = 0.0
		if offset.length() < 0.9 and offset.normalized().dot(moving.normalized()) > 0.2:
			_bumped.append(other)
			other.bumped(moving.normalized(), push)


func bumped(direction: Vector3, strength: float) -> void:
	if state not in [State.IDLE, State.CHASE, State.ATTACK]:
		return
	hit_reaction.add_hit(&"Chest", direction, 0.5 * strength)
	_lean_velocity += _to_local_flat(direction) * 1.5 * strength
	balance += 0.15 * strength
	_stagger(direction, 18.0 * strength)


# --- Navegação e escalada -----------------------------------------------------

func _setup_navigation() -> void:
	_agent = NavigationAgent3D.new()
	_agent.radius = 0.4
	_agent.height = 1.8
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 1.0
	add_child(_agent)


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


## Direção para andar: segue o caminho do NavigationMesh (ou reto, se não houver).
func _chase_direction(to_target: Vector3, delta: float) -> Vector3:
	_repath_timer -= delta
	var repath := _repath_timer <= 0.0
	if repath:
		_repath_timer = 0.4
		_agent.target_position = target.global_position
	if not _nav_ready():
		return to_target.normalized()
	var next := _agent.get_next_path_position() # recalcula o caminho se mudou o alvo
	if repath:
		_decide_climb(to_target)
	if _climb_mode:
		return to_target.normalized()
	var direction := next - global_position
	direction.y = 0.0
	if _agent.is_navigation_finished() or direction.length() < 0.05:
		return to_target.normalized()
	return direction.normalized()


## Escala só se dar a volta for longe demais (ou impossível) e houver algo
## escalável no caminho reto.
func _decide_climb(to_target: Vector3) -> void:
	_climb_mode = false
	if crawler or not _nav_ready():
		return
	var path := _agent.get_current_navigation_path()
	if path.size() < 2:
		return
	var length := 0.0
	for i in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	var unreachable := path[path.size() - 1].distance_to(target.global_position) > 1.5
	if (length > to_target.length() * climb_detour_ratio or unreachable) and _obstacle_height(to_target.normalized(), to_target.length()) <= climb_max_height:
		_climb_mode = true


## Altura do primeiro obstáculo no caminho reto (0 = nada; INF = alto demais).
func _obstacle_height(direction: Vector3, distance: float) -> float:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * distance, 1, [get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	var probe: Vector3 = hit.position + direction * 0.05 # dentro da parede (cerca fina)
	var top_query := PhysicsRayQueryParameters3D.create(Vector3(probe.x, global_position.y + climb_max_height + 0.3, probe.z),
			Vector3(probe.x, global_position.y - 0.1, probe.z), 1)
	var top := space.intersect_ray(top_query)
	return top.position.y - global_position.y if top else INF


func _try_start_climb(direction: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.5
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + direction * 0.7, 1, [get_rid()]))
	if hit.is_empty():
		return false
	var height := _obstacle_height(direction, 0.8)
	if height < 0.4 or height > climb_max_height:
		return false
	var wall: Vector3 = hit.position
	var top_y := global_position.y + height
	var feet := global_position
	_climb_points = [feet, Vector3(wall.x, top_y, wall.z) - direction * 0.25, Vector3(wall.x, top_y, wall.z) + direction * 0.35]
	# Obstáculo fino (cerca/muro): desce do outro lado.
	var beyond: Vector3 = wall + direction * 0.8
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(beyond.x, top_y + 0.3, beyond.z),
			Vector3(beyond.x, feet.y - 1.0, beyond.z), 1))
	if down and down.position.y < top_y - 0.4:
		_climb_points.append(down.position + direction * 0.3)
	_climb_duration = 0.6 + height * climb_speed + (0.4 if _climb_points.size() > 3 else 0.0)
	rotation.y = atan2(-direction.x, -direction.z)
	velocity = Vector3.ZERO
	collision.set_deferred("disabled", true)
	_set_state(State.CLIMB)
	return true


func _update_climb(_delta: float) -> void:
	var k := clampf(_state_time / _climb_duration, 0.0, 1.0)
	var segments := _climb_points.size() - 1
	var f := k * segments
	var i := mini(int(f), segments - 1)
	global_position = _climb_points[i].lerp(_climb_points[i + 1], smoothstep(0.0, 1.0, f - i))
	# Braços para cima agarrando, corpo encolhido.
	locomotion.attack = 1.0 - absf(k - 0.4)
	if k >= 1.0:
		locomotion.attack = 0.0
		collision.set_deferred("disabled", false)
		_climb_mode = false
		_repath_timer = 0.0
		_set_state(State.CHASE)


# --- Arma na mão ------------------------------------------------------------

func _equip_weapon(id: StringName) -> void:
	var hand := skeleton.get_node_or_null(HumanoidRig.attachment_name("LowerArm.R")) as Node3D
	if hand == null:
		return
	_held_weapon = ItemDB.make_mesh(id)
	hand.add_child(_held_weapon)
	_held_weapon.position = Vector3(0, -0.3, 0)
	weapon_id = id


## Solta a arma no chão (morreu, ou o braço direito quebrou/saiu).
func _drop_weapon() -> void:
	if _held_weapon == null:
		return
	var item: PickupItem = load("res://scenes/props/pickup_item.tscn").instantiate()
	item.item_id = weapon_id
	get_parent().add_child(item)
	item.global_transform = _held_weapon.global_transform
	_held_weapon.queue_free()
	_held_weapon = null


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
	if limb == &"ArmR":
		_drop_weapon()
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
			if _held_weapon:
				damage *= weapon_damage_multiplier
			target.take_damage(damage * (0.7 if crawler else 1.0), to_target.normalized(), self)


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
	return is_instance_valid(target) and (_alerted or _flat_to_target().length() < detect_range)


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
