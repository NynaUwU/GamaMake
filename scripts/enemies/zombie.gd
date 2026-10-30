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
const LAYER_ENEMY := 1 << 2
const SEPARATION_RADIUS := 0.75

# Grade de vizinhança (montada uma vez por tick de física, para todos os zumbis).
static var _grid := {}
static var _grid_frame := -1

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

# Multiplayer: no host o zumbi pensa; nos clientes é uma marionete que segue o host.
var net_id := 0
var puppet := false ## true = cópia de um zumbi do host (sem IA)
var _snap_pos := Vector3.ZERO
var _snap_yaw := 0.0
var _snap_attack := 0.0
var _snap_swing := 0.0
var _snap_getup := 0.0
var _has_snap := false
var _state_hold := 0.0 # marionete: ignora o estado do host por um instante (empalou agora)
var _retarget := 0.0
var _net_spawn := {}
# Nível de detalhe pela distância até o jogador mais perto (0 perto, 1 médio, 2 longe).
var _lod := 0
var hitboxes_active := true ## false = longe; golpes à distância usam a cápsula
var _lod_distance := 0.0
var _tick := 0
var _step := 1

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var locomotion: ZombieLocomotion = $Skeleton3D/Locomotion
@onready var hit_reaction: HitReaction = $Skeleton3D/HitReaction
@onready var limp_limbs: LimpLimbs = $Skeleton3D/LimpLimbs
@onready var ragdoll: Ragdoll = $Skeleton3D/PhysicalBoneSimulator3D


func _ready() -> void:
	if not puppet and not Net.i.is_host():
		queue_free() # online, os zumbis do cliente vêm todos do host
		return
	health = max_health
	if _net_spawn.is_empty():
		move_speed *= randf_range(0.85, 1.25)
	for limb in LIMBS:
		_limb_state[limb] = LimbState.OK
		_limb_hp[limb] = {"head": head_health, "arm": arm_health, "leg": leg_health}[LIMBS[limb].kind]
	# Zumbis não colidem fisicamente entre si (cápsula contra cápsula numa
	# multidão custa muito); eles se afastam com _separation() no lugar.
	collision_mask &= ~LAYER_ENEMY
	_standing_shape = collision.shape
	_standing_shape_transform = collision.transform
	ragdoll.blend_finished.connect(_on_ragdoll_blended_out)
	if target == null:
		target = _nearest_player()
	if not puppet and weapon_id == &"" and randf() < weapon_chance:
		weapon_id = ItemDB.ZOMBIE_WEAPONS.pick_random()
	if weapon_id != &"":
		_equip_weapon.call_deferred(weapon_id)
	_setup_navigation()
	Net.i.register_zombie(self)
	if puppet:
		_apply_spawn_state.call_deferred()


func _exit_tree() -> void:
	Net.i.unregister_zombie(self)


func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_physics(delta)
		return
	# Longe e só andando/parado: pensa a cada 2 ticks (com o passo dobrado).
	_tick += 1
	_step = 2 if _lod >= 2 and state in [State.IDLE, State.CHASE] else 1
	if _tick % _step != 0:
		return
	delta *= _step
	_state_time += delta
	_cooldown -= delta
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.5
		var nearest := _nearest_player()
		if not _alerted or _target_dead():
			target = nearest # online: persegue o jogador mais perto
		_update_lod()
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
		velocity *= _step # pulou ticks: move_and_slide usa o tick normal, então anda o dobro
		move_and_slide()
		velocity /= _step
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
	var desired := direction * (crawl_speed if crawler else move_speed) + _separation() * 2.5
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
	if puppet:
		Net.i.zombie_call(self, "take_hit", [hit.to_dict()])
		return
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
		_rag_hit(hit.bone, hit.direction * hit.force, hit.point)
		return
	if state == State.DEAD:
		if hit.type == HitInfo.Type.CUT and limb != &"":
			_damage_limb(limb, hit) # dá para arrancar pedaços do corpo caído
		_rag_hit(hit.bone, hit.direction * hit.force, hit.point)
		return
	var body_damage: float = hit.damage * BONE_DAMAGE.get(hit.bone, 1.0)
	if limb != &"" and _limb_state[limb] == LimbState.BROKEN:
		body_damage *= broken_limb_damage # osso já quebrado: quase não dói mais
	health -= body_damage
	if limb != &"":
		_damage_limb(limb, hit)
	if hit.launch > 0.0:
		_launch(hit)
		return
	if health <= 0.0:
		_die(hit.bone, hit.point, hit.direction * hit.force * 1.3)
		return
	if state == State.DOWN or state == State.GETTING_UP:
		# Bateu no zumbi caído: ele volta (ou continua) no chão.
		_knock_down(hit.bone, hit.point, hit.direction * hit.force)
		return
	_flinch(hit.bone, hit.direction, clampf(hit.force / 25.0, 0.4, 2.5))

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
	if puppet:
		Net.i.zombie_call(self, "take_explosion", [center, damage, force])
		return
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
	_rag_explode(center, force)


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
	_rag_hit(bone, impulse, point)
	_set_state(State.DOWN)


func _die(bone: StringName, point: Vector3, impulse: Vector3) -> void:
	_drop_weapon()
	_end_attack()
	_enter_ragdoll()
	_rag_hit(bone, impulse, point)
	_set_state(State.DEAD)
	died.emit(self)


func _enter_ragdoll() -> void:
	_rep("enter_ragdoll", [Vector3(velocity.x, 0, velocity.z)])
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
	if puppet:
		state = State.IMPALED # já fica espetado aqui (o host confirma em seguida)
		_state_hold = 0.4
		Net.i.zombie_call(self, "impale", [damage, point, direction, _impale_from_back])
		return
	_end_attack()
	_enter_ragdoll()
	_set_state(State.IMPALED)
	_impale_died = false
	_hurt(damage)
	_burst(point, -direction + Vector3.UP * 0.5, ImpactFX.BLOOD, 24, 3.0)


## Chamado a cada frame de física pelo player: puxa o peito até a lâmina.
func hold_impaled(target_point: Vector3, carrier_velocity: Vector3, blade_direction := Vector3.ZERO) -> void:
	if puppet:
		# Segura a cópia aqui (para quem empala ver na hora) e manda o host segurar o de verdade.
		_state_hold = 0.4
		Net.i.zombie_call(self, "hold_impaled", [target_point, carrier_velocity, blade_direction], false)
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
	if puppet:
		_state_hold = 0.0
		Net.i.zombie_call(self, "release_impaled", [impulse])
		return
	if state != State.IMPALED:
		return
	_set_state(State.DEAD if _impale_died else State.DOWN)
	var chest := ragdoll.get_bone_body(&"Chest")
	_rag_hit(&"Chest", impulse, chest.global_position if chest else global_position)


func _hurt(amount: float) -> void:
	if _impale_died:
		return
	health -= amount
	if health <= 0.0:
		_impale_died = true
		_drop_weapon()
		died.emit(self)


# --- Reações extras ---------------------------------------------------------

## Atropelado: voa na direção do carro. Rápido o bastante, morre (e pode perder pedaços).
func hit_by_vehicle(car_velocity: Vector3, _car_position: Vector3) -> void:
	if puppet:
		Net.i.zombie_call(self, "hit_by_vehicle", [car_velocity, _car_position])
		return
	var speed := car_velocity.length()
	var direction := car_velocity.normalized()
	var center := global_position + Vector3.UP * 0.9 - direction * 1.0
	if state == State.DEAD:
		_rag_explode(center, speed * 20.0)
		return
	if state == State.IMPALED:
		return
	health -= speed * 7.0
	_end_attack()
	_enter_ragdoll()
	if health <= 0.0:
		_set_state(State.DEAD)
		_drop_weapon()
		died.emit(self)
		if speed > 15.0:
			for limb in [&"LowerArm.L", &"LowerArm.R", &"LowerLeg.L", &"LowerLeg.R"]:
				if randf() < 0.25:
					_cut(limb, direction * speed * 0.4 + Vector3.UP * 2.0)
	else:
		_set_state(State.DOWN)
	_rag_explode(center, speed * 22.0)


## Arremessado (colherona): voa longe, girando, em ragdoll.
func _launch(hit: HitInfo) -> void:
	_end_attack()
	_enter_ragdoll()
	if health <= 0.0:
		_set_state(State.DEAD)
		_drop_weapon()
		died.emit(self)
	else:
		_set_state(State.DOWN)
	var dir := Vector3(hit.direction.x, 0, hit.direction.z).normalized()
	# Centro da "explosão" atrás e abaixo do zumbi: empurra para frente e para cima.
	_rag_explode(global_position + Vector3.UP * 0.4 - dir * 1.0, hit.launch)
	_rag_hit(&"Chest", Vector3.UP * hit.launch * 0.15, global_position + Vector3.UP * 1.3)


## Player deslizou por baixo: as pernas vão para frente e o zumbi cai.
func trip(direction: Vector3, force: float) -> void:
	if puppet:
		Net.i.zombie_call(self, "trip", [direction, force])
		return
	if state in [State.DOWN, State.DEAD, State.IMPALED, State.GETTING_UP] or crawler:
		return
	_end_attack()
	_enter_ragdoll()
	_set_state(State.DOWN)
	var flat := Vector3(direction.x, 0, direction.z).normalized()
	for bone in [&"LowerLeg.L", &"LowerLeg.R"]:
		var body := ragdoll.get_bone_body(bone)
		if body:
			_rag_hit(bone, (flat + Vector3.UP * 0.6) * force * 0.25, body.global_position)
	_rag_hit(&"Chest", -flat * force * 0.3, global_position + Vector3.UP * 1.3)


## O player bloqueou o golpe. Parry (na hora certa) desequilibra muito.
func on_blocked(parry: bool, push_direction: Vector3) -> void:
	if puppet:
		Net.i.zombie_call(self, "on_blocked", [parry, push_direction])
		return
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
	if puppet:
		Net.i.zombie_call(self, "alert", [])
		return
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
	_flinch(&"Chest", direction, 0.5 * strength)
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


## Está em cima (ou perto) da malha de navegação? Fora dela o caminho levaria à cidade.
func _on_navmesh() -> bool:
	var closest := NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), global_position)
	return closest.distance_to(global_position) < 2.0


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


## Direção para andar: segue o caminho do NavigationMesh (ou reto, se não houver).
func _chase_direction(to_target: Vector3, delta: float) -> Vector3:
	_repath_timer -= delta
	var repath := _repath_timer <= 0.0
	if repath:
		_repath_timer = 0.4
		_agent.target_position = target.global_position
	if not _nav_ready() or not _on_navmesh():
		return to_target.normalized() # fora da cidade (mapa aberto): vai reto
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
	_rep("equip", [id])
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
	_rep("unequip", [])
	if not puppet:
		Net.i.drop_item(weapon_id, 1, _held_weapon.global_transform, Vector3.ZERO)
	_held_weapon.queue_free()
	_held_weapon = null
	weapon_id = &""


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
	_rep("getup", [global_position, rotation.y, face_down, crawler])
	_begin_getup_visual(face_down)


func _begin_getup_visual(face_down: bool) -> void:
	_getup_progress = 0.0
	if crawler:
		locomotion.mode = ZombieLocomotion.Mode.CRAWL
	else:
		locomotion.begin_getup(face_down)
	_limp_reset()
	ragdoll.blend_out(getup_blend_time)


func _on_ragdoll_blended_out() -> void:
	if state == State.GETTING_UP:
		_set_hitboxes_enabled(true) # pode apanhar enquanto levanta


func _finish_get_up() -> void:
	_rep("stand", [crawler])
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
		_limp(bones)
		_limb_state[limb] = LimbState.BROKEN
		_burst(hit.point, -hit.direction + Vector3.UP, ImpactFX.BLOOD, 8, 1.5)
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
	_rep("cut", [bone, impulse])
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
	_burst(skeleton.global_position + Vector3.UP, Vector3.UP, ImpactFX.BLOOD, 40, 5.0, 0.07)


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


# --- Multiplayer ---------------------------------------------------------------

func _target_dead() -> bool:
	if not is_instance_valid(target):
		return true
	var hp = target.get("health")
	return hp != null and hp <= 0.0


## Osso aproximado de um ponto na cápsula (tiro em zumbi longe, sem hitboxes).
func hit_bone_at(point: Vector3) -> StringName:
	var h := point.y - global_position.y
	if crawler:
		return &"Chest"
	if h > 1.5:
		return &"Head"
	if h > 1.0:
		return &"Chest"
	if h > 0.85:
		return &"Hips"
	return &"UpperLeg.L" if to_local(point).x < 0.0 else &"UpperLeg.R"


## Empurrão para longe dos zumbis muito perto (no lugar da colisão entre eles).
func _separation() -> Vector3:
	var frame := Engine.get_physics_frames()
	if frame != _grid_frame:
		_grid_frame = frame
		_grid.clear()
		for z in get_tree().get_nodes_in_group("enemy"):
			var key := Vector2i(floori(z.global_position.x / SEPARATION_RADIUS), floori(z.global_position.z / SEPARATION_RADIUS))
			if not _grid.has(key):
				_grid[key] = []
			_grid[key].append(z)
	var here := Vector2i(floori(global_position.x / SEPARATION_RADIUS), floori(global_position.z / SEPARATION_RADIUS))
	var push := Vector3.ZERO
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for other in _grid.get(here + Vector2i(dx, dz), []):
				if other == self or other.state in [State.DOWN, State.DEAD, State.IMPALED]:
					continue
				var offset: Vector3 = global_position - other.global_position
				offset.y = 0.0
				var d := offset.length()
				if d < SEPARATION_RADIUS and d > 0.001:
					push += offset / d * (SEPARATION_RADIUS - d) / SEPARATION_RADIUS
	return push


## Detalhe pela distância: sombra só perto; animação e IA mais espaçadas longe.
func _update_lod() -> void:
	var level := 0 if _lod_distance < 30.0 else (1 if _lod_distance < 70.0 else 2)
	if level == _lod:
		return
	_lod = level
	locomotion.frame_skip = [0, 1, 3][level]
	# Longe: as hitboxes saem da física (o tiro de longe acerta a cápsula; ver hit_bone_at).
	hitboxes_active = level == 0
	for area in find_children("Hitbox", "Area3D", true, false):
		area.process_mode = Node.PROCESS_MODE_INHERIT if hitboxes_active else Node.PROCESS_MODE_DISABLED
	var body: MeshInstance3D = skeleton.get("skin_mesh")
	if body:
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if level == 0 \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Jogador mais perto (vivo) entre o local e os bonecos dos outros.
func _nearest_player() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for group in [&"player", &"remote_player"]:
		for p in get_tree().get_nodes_in_group(group):
			if p.get("health") != null and p.health <= 0.0:
				continue
			var d: float = global_position.distance_squared_to(p.global_position)
			if d < best_d:
				best_d = d
				best = p
	_lod_distance = sqrt(best_d) if best else 0.0
	return best if best else target


## Host: conta para os clientes um evento visual (ragdoll, membro, levantar...).
func _rep(event: String, args: Array) -> void:
	if not puppet:
		Net.i.zombie_event(self, event, args)


func _rag_hit(bone: StringName, impulse: Vector3, point: Vector3) -> void:
	_rep("rag_hit", [bone, impulse, point])
	ragdoll.apply_hit(bone, impulse, point)


func _rag_explode(center: Vector3, force: float) -> void:
	_rep("rag_explode", [center, force])
	ragdoll.apply_explosion(center, force)


func _flinch(bone: StringName, direction: Vector3, strength: float) -> void:
	_rep("flinch", [bone, direction, strength])
	hit_reaction.add_hit(bone, direction, strength)


func _limp(bones: Array[StringName]) -> void:
	_rep("limp", [bones])
	limp_limbs.make_limp(bones)


func _limp_reset() -> void:
	limp_limbs.reset()


func _burst(position: Vector3, normal: Vector3, color: Color, amount := 16, speed := 3.0, size := 0.05) -> void:
	_rep("burst", [position, normal, color, amount, speed, size])
	ImpactFX.burst(get_parent(), position, normal, color, amount, speed, size)


# Eventos recebidos pela marionete (mesmos nomes de _rep, com "_ev_" na frente).
func _ev_enter_ragdoll(inherited: Vector3) -> void:
	velocity = inherited
	_enter_ragdoll()


func _ev_rag_hit(bone: StringName, impulse: Vector3, point: Vector3) -> void:
	ragdoll.apply_hit(bone, impulse, point)


func _ev_rag_explode(center: Vector3, force: float) -> void:
	ragdoll.apply_explosion(center, force)


func _ev_flinch(bone: StringName, direction: Vector3, strength: float) -> void:
	hit_reaction.add_hit(bone, direction, strength)


func _ev_limp(bones: Array) -> void:
	var list: Array[StringName] = []
	list.assign(bones)
	limp_limbs.make_limp(list)


func _ev_burst(position: Vector3, normal: Vector3, color: Color, amount: int, speed: float, size: float) -> void:
	ImpactFX.burst(get_parent(), position, normal, color, amount, speed, size)


func _ev_cut(bone: StringName, impulse: Vector3) -> void:
	_cut(bone, impulse)


func _ev_getup(pos: Vector3, yaw: float, face_down: bool, is_crawler: bool) -> void:
	crawler = is_crawler
	state = State.GETTING_UP
	global_position = pos
	rotation.y = yaw
	_snap_pos = pos
	_snap_yaw = yaw
	_begin_getup_visual(face_down)


func _ev_stand(is_crawler: bool) -> void:
	crawler = is_crawler
	_finish_get_up()


func _ev_equip(id: StringName) -> void:
	if _held_weapon == null:
		_equip_weapon(id)


func _ev_unequip() -> void:
	if _held_weapon:
		_held_weapon.queue_free()
		_held_weapon = null


## Host: um cliente bateu/empurrou a cópia dele deste zumbi.
func call_from_peer(peer: int, method: String, args: Array) -> void:
	match method:
		"take_hit":
			take_hit(HitInfo.from_dict(args[0]))
		"take_explosion":
			take_explosion(args[0], args[1], args[2])
		"impale":
			if can_be_impaled():
				_impale_from_back = args[3]
				impale(args[0], args[1], args[2])
		"hold_impaled":
			if state == State.IMPALED:
				hold_impaled(args[0], args[1], args[2])
		"release_impaled":
			release_impaled(args[0])
		"hit_by_vehicle":
			hit_by_vehicle(args[0], args[1])
		"trip":
			trip(args[0], args[1])
		"on_blocked":
			on_blocked(args[0], args[1])
		"alert":
			var who: Node3D = Net.i.world.puppets.get(peer) if Net.i.world else null
			if who:
				alert(who)


## Host: estado compacto mandado ~15x por segundo para quem está perto.
func snapshot() -> Array:
	return [net_id, global_position, rotation.y, state, crawler, locomotion.attack, locomotion.swing,
		_getup_progress, _lean, balance]


func apply_snapshot(entry: Array) -> void:
	_snap_pos = entry[1]
	_snap_yaw = entry[2]
	if _state_hold <= 0.0:
		state = entry[3]
	crawler = entry[4]
	_snap_attack = entry[5]
	_snap_swing = entry[6]
	_snap_getup = entry[7]
	_lean = entry[8]
	balance = entry[9]
	if not _has_snap:
		_has_snap = true
		global_position = _snap_pos
		rotation.y = _snap_yaw


## Host: tudo para criar a cópia (inclusive para quem entra no meio da partida).
func spawn_data() -> Dictionary:
	return {"pos": global_position, "yaw": rotation.y, "weapon": weapon_id,
		"speed": move_speed, "state": state, "crawler": crawler, "cut": _cut_bones.duplicate(),
		"ragdoll": ragdoll.is_ragdolling() if ragdoll else false}


func setup_from_net(data: Dictionary) -> void:
	_net_spawn = data
	position = data.pos
	rotation.y = data.yaw
	weapon_id = data.weapon
	move_speed = data.speed
	crawler = data.crawler
	state = data.state
	_snap_pos = data.pos
	_snap_yaw = data.yaw


## Cópia criada no meio da partida: membros já arrancados, já caído...
func _apply_spawn_state() -> void:
	if _net_spawn.is_empty():
		return
	for bone in _net_spawn.cut:
		_cut(bone, Vector3.ZERO)
	if crawler:
		locomotion.mode = ZombieLocomotion.Mode.CRAWL
		_apply_body_shape()
	if _net_spawn.ragdoll:
		_enter_ragdoll()


## Marionete: segue a posição/estado do host e anima com isso (sem IA).
func _puppet_physics(delta: float) -> void:
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.5
		var local := get_tree().get_first_node_in_group("player") as Node3D
		if local:
			_lod_distance = global_position.distance_to(local.global_position)
			_update_lod()
	_state_time += delta
	_state_hold -= delta
	var ragdolled := ragdoll.is_ragdolling() and ragdoll.influence >= 1.0
	if not ragdolled and _has_snap:
		var t := 1.0 - exp(-12.0 * delta)
		var before := global_position
		if global_position.distance_to(_snap_pos) > 4.0:
			global_position = _snap_pos
		else:
			global_position = global_position.lerp(_snap_pos, t)
		rotation.y = lerp_angle(rotation.y, _snap_yaw, t)
		velocity = (global_position - before) / maxf(delta, 0.001)
	else:
		velocity = Vector3.ZERO
	locomotion.attack = _snap_attack
	locomotion.swing = _snap_swing
	if state == State.GETTING_UP and not crawler:
		_getup_progress = _snap_getup
		locomotion.getup_t = _snap_getup
	_update_body_pose(delta)