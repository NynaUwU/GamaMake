class_name Player
extends CharacterBody3D
## Player em primeira pessoa: movimento, armas, chute, soco, bloqueio,
## lanterna, inventário e interação. Movimentos especiais (agachar, deslizar,
## pular obstáculos, escalar) ficam no nó Parkour.
## Armas (pegas no mapa, ficam na hotbar): espada (corta membros), taco
## (desequilibra), cajado (mísseis explosivos) e pistola. Sem arma: soco.
## Atacar não gasta stamina; stamina é só para correr.

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal interact_prompt_changed(text: String) ## "" = nada para interagir
signal notify(text: String) ## mensagens curtas no HUD
signal item_picked_up(item_id: StringName, amount: int) ## gancho para o inventário futuro
signal died
signal weapon_changed(weapon_text: String) ## nome da arma (+ munição)

enum WeaponType { FISTS, SWORD, BAT, STAFF, PISTOL }
const WEAPON_NAMES := {
	WeaponType.FISTS: "Mãos", WeaponType.SWORD: "Espada", WeaponType.BAT: "Taco",
	WeaponType.STAFF: "Cajado", WeaponType.PISTOL: "Pistola",
}
## ItemDB "weapon" -> tipo de arma do player.
const WEAPON_FROM_ITEM := {"sword": WeaponType.SWORD, "bat": WeaponType.BAT,
	"staff": WeaponType.STAFF, "pistol": WeaponType.PISTOL}
const PICKUP_SCENE := preload("res://scenes/props/pickup_item.tscn")
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

@export_group("Empalar")
## Correndo com a espada, segure o ataque: a lâmina vai para frente e espeta
## quem estiver no caminho (até max_impaled). Parou de correr ou soltou o
## botão: chuta todos para fora da lâmina.
@export var impale_damage := 25.0
@export var impale_range := 1.6
@export var max_impaled := 3
@export var impale_release_force := 160.0
@export var impale_slowdown := 0.12 ## cada zumbi espetado tira 12% da velocidade

@export_group("Chute")
@export var kick_damage := 6.0
@export var kick_force := 140.0
@export var kick_range := 2.4 ## alcance do chute (pega todos no cone à frente)
@export var kick_cone := 0.35 ## dot mínimo: 0.35 ≈ 70° para cada lado

@export_group("Soco")
@export var punch_damage := 12.0
@export var punch_force := 26.0
@export var punch_range := 1.7
@export var punch_rate := 0.32

@export_group("Bloqueio")
## Segure o botão direito com espada ou taco: golpes de frente quase não doem.
## Bloquear logo antes do golpe (parry_window) desequilibra o zumbi.
@export var block_damage_factor := 0.1
@export var parry_window := 0.3
@export var block_speed_factor := 0.6

@export_group("Lanterna")
@export var flashlight_range := 28.0
@export var attract_range := 45.0 ## zumbis de frente na luz vêm de longe
@export var attract_cone := 0.975 ## dot entre a mira e o zumbi

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

var _weapon_type := WeaponType.FISTS
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

var _fp_arm: MeshInstance3D # antebraço em primeira pessoa (do ombro até a mão)
var _fp_hand: Node3D
const FP_SHOULDER := Vector3(0.34, -0.55, 0.22) ## de onde o braço sai (fora da tela)

var _fp_arm_left: MeshInstance3D
var _fp_hand_left: Node3D
const FP_SHOULDER_LEFT := Vector3(-0.34, -0.55, 0.22)

var vehicle: VintageCar ## carro que está dirigindo (null = a pé)
var _vehicle_yaw := 0.0 # olhar para os lados dentro do carro
var inventory: Inventory
var parkour: Parkour
var ui_blocked := false ## inventário aberto: o player não age
var _flashlight: SpotLight3D
var _attract_timer := 0.0
var _blocking := false
var _block_time := 0.0
var _punch_timer := 0.0
var _punch_side := 0
var _punch_anim := [0.0, 0.0] # direita, esquerda (1 = braço esticado)

var _charging := false # correndo com a espada para frente
var _charge_time := 0.0
var _impaled: Array = []


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
	inventory = Inventory.new()
	inventory.name = "Inventory"
	add_child(inventory)
	parkour = Parkour.new()
	parkour.name = "Parkour"
	add_child(parkour)
	parkour.setup(self, $CollisionShape3D)
	inventory.changed.connect(_emit_weapon_text)
	inventory.selection_changed.connect(func(_i): _emit_weapon_text())
	_install_weapon_models()
	_setup_trail()
	_setup_fp_arm()
	_setup_flashlight()
	_show_weapon(_weapon_type)
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)


func _unhandled_input(event: InputEvent) -> void:
	if vehicle:
		# Dirigindo (primeira pessoa): o carro lê WASD/Espaço; o mouse olha em volta.
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_vehicle_yaw = clampf(_vehicle_yaw - event.relative.x * mouse_sensitivity, -1.9, 1.9)
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-70), deg_to_rad(60))
		elif event.is_action_pressed("interact"):
			exit_vehicle()
		elif event.is_action_pressed("ui_cancel"):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif health > 0.0 and not ui_blocked:
		if event.is_action_pressed("attack"):
			if _blocking:
				pass
			elif _weapon_type == WeaponType.SWORD and _is_sprinting() and _swing_phase == SwingPhase.NONE and not _busy:
				_charging = true
				_charge_time = 0.0
			elif _is_melee():
				_melee_attack()
			elif _weapon_type == WeaponType.PISTOL:
				_fire_pistol()
			elif _weapon_type == WeaponType.FISTS:
				_punch()
		elif event.is_action_pressed("reload"):
			_start_reload()
		elif event.is_action_pressed("weapon_next"):
			inventory.select((inventory.selected + 1) % Inventory.HOTBAR_SIZE)
		elif event.is_action_pressed("crouch"):
			parkour.on_crouch_pressed(_is_sprinting())
		elif event.is_action_pressed("flashlight"):
			_toggle_flashlight()
		elif event.is_action_pressed("drop"):
			_drop_selected()
		elif event.is_action_pressed("kick"):
			_kick()
		elif _hotbar_key(event) >= 0:
			inventory.select(_hotbar_key(event))
		elif event.is_action_pressed("interact") and is_instance_valid(_interact_target):
			_interact_target.interact(self)
			# O item some ao ser pego: limpa o aviso na hora.
			_interact_target = null
			interact_prompt_changed.emit("")


func _physics_process(delta: float) -> void:
	if health <= 0.0:
		return
	if vehicle:
		# Sentado no banco: acompanha o carro (o mouse gira só a cabeça).
		global_transform = vehicle.seat.global_transform * Transform3D(Basis(Vector3.UP, _vehicle_yaw), Vector3.ZERO)
		velocity = Vector3.ZERO
		return
	if parkour.physics(delta):
		# Deslizando / pulando obstáculo / escalando: o Parkour move o player.
		_update_interact()
		_update_camera_shake(delta)
		_update_charge(delta)
		return
	var sprinting := _is_sprinting()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump") and not ui_blocked:
		if not parkour.try_traverse(sprinting):
			velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if ui_blocked:
		input = Vector2.ZERO
	var direction := (global_basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := sprint_speed if sprinting else walk_speed
	speed *= 1.0 - impale_slowdown * _impaled.size()
	speed *= parkour.speed_factor(walk_speed)
	if _blocking:
		speed *= block_speed_factor
	var target := direction * speed
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
	_update_charge(delta)
	_update_flashlight(delta)


func _is_sprinting() -> bool:
	if ui_blocked or _blocking or (parkour and parkour.crouching):
		return false
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return Input.is_action_pressed("sprint") and input.y < 0.0 and stamina > 1.0


## Teclas 1-5 -> índice do slot da hotbar (-1 se não for uma delas).
func _hotbar_key(event: InputEvent) -> int:
	for i in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("weapon_%d" % (i + 1)):
			return i
	return -1


# Empalar ----------------------------------------------------------------------

func _update_charge(delta: float) -> void:
	if not _charging:
		return
	_charge_time += delta
	_impaled = _impaled.filter(func(z): return is_instance_valid(z) and z.state == Zombie.State.IMPALED)
	var holding := Input.is_action_pressed("attack") and _weapon_type == WeaponType.SWORD and health > 0.0
	if not holding or not _is_sprinting():
		_charging = false
		if not _impaled.is_empty():
			_kick_animation(_release_impaled)
		elif not holding and _charge_time < 0.25:
			_melee_attack() # foi só um clique: golpe normal
		return
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	# Segura cada zumbi num ponto da lâmina (um atrás do outro).
	for i in _impaled.size():
		var point := camera.global_position + forward * (1.05 + i * 0.45) + Vector3.DOWN * 0.35
		_impaled[i].hold_impaled(point, Vector3(velocity.x, 0, velocity.z), forward)
	if _impaled.size() >= max_impaled:
		return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy in _impaled or not enemy.has_method("can_be_impaled") or not enemy.can_be_impaled(forward):
			continue
		var to_enemy: Vector3 = (enemy.global_position + Vector3.UP * 1.2) - camera.global_position
		var flat := Vector3(to_enemy.x, 0, to_enemy.z)
		if flat.length() > impale_range + _impaled.size() * 0.45 or forward.dot(flat.normalized()) < 0.75:
			continue
		enemy.impale(impale_damage, enemy.global_position + Vector3.UP * 1.2, forward)
		_impaled.append(enemy)
		_hitstop(0.06)
		_shake = 0.15
		if _impaled.size() >= max_impaled:
			break


func _release_impaled() -> void:
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	for z in _impaled:
		if is_instance_valid(z):
			z.release_impaled((forward + Vector3.UP * 0.35).normalized() * impale_release_force)
	_impaled.clear()
	_hitstop(0.08)
	_shake = 0.2


func _process(delta: float) -> void:
	if vehicle:
		head.position.y = vehicle.eye_height
		global_transform = vehicle.seat.global_transform * Transform3D(Basis(Vector3.UP, _vehicle_yaw), Vector3.ZERO)
		_update_driving_hands()
		_update_camera_shake(delta)
		return
	head.position.y = parkour.eye_height(delta)
	_sync_equipped()
	_update_block(delta)
	_punch_timer -= delta
	for i in 2:
		_punch_anim[i] = move_toward(_punch_anim[i], 0.0, delta * 6.0)
	_equip = minf(_equip + delta / equip_time, 1.0)
	var moving := Vector2(velocity.x, velocity.z).length() / walk_speed
	_bob += delta * (2.0 + moving * 7.0)
	_update_swing(delta)
	_update_staff(delta)
	_update_pistol(delta)
	_update_fp_arm()


## Modelos das armas na mão: os mesmos do chão/ícones (ItemModels).
func _install_weapon_models() -> void:
	weapon.add_child(ItemModels.build(&"espada"))
	bat.add_child(ItemModels.build(&"taco"))
	var staff_model := ItemModels.build(&"cajado")
	staff_model.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, -0.41, 0)) # em pé, orbe na ponta (Tip)
	staff.add_child(staff_model)
	pistol.add_child(ItemModels.build(&"pistola"))


# Braço em primeira pessoa -----------------------------------------------------

func _setup_fp_arm() -> void:
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Color(0.22, 0.3, 0.2)
	sleeve.roughness = 0.9
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.85, 0.66, 0.52)
	skin.roughness = 0.8
	_fp_arm = MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.085, 0.085, 1.0)
	_fp_arm.mesh = arm_mesh
	_fp_arm.material_override = sleeve
	_fp_arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(_fp_arm)
	_fp_hand = BlockyHand.fist(skin) # mão em blocos com dedos (segura o cabo ao longo de Z)
	camera.add_child(_fp_hand)
	_fp_arm_left = _fp_arm.duplicate()
	camera.add_child(_fp_arm_left)
	_fp_hand_left = BlockyHand.fist(_fp_hand.get_child(0).material_override, false, true)
	camera.add_child(_fp_hand_left)


## A mão fica na empunhadura da arma atual; o antebraço liga o ombro até ela.
func _update_fp_arm() -> void:
	var grip: Transform3D
	var fists := _weapon_type == WeaponType.FISTS
	_fp_arm_left.visible = fists
	_fp_hand_left.visible = fists
	if fists:
		# Punhos em guarda; o soco estica o braço para frente.
		var offset := _bob_offset(0.8) + _equip_offset()
		var right := Vector3(0.2, -0.24, -0.36).lerp(Vector3(0.06, -0.12, -0.62), ease(_punch_anim[0], 0.5))
		var left := Vector3(-0.2, -0.26, -0.38).lerp(Vector3(-0.06, -0.12, -0.62), ease(_punch_anim[1], 0.5))
		_place_arm(_fp_arm_left, _fp_hand_left, FP_SHOULDER_LEFT, Transform3D(Basis(), left + offset))
		grip = Transform3D(Basis(), right + offset)
		_place_arm(_fp_arm, _fp_hand, FP_SHOULDER, grip)
		return
	match _weapon_type:
		WeaponType.SWORD:
			grip = weapon.transform.translated_local(Vector3(0, 0, 0.04))
		WeaponType.BAT:
			grip = bat.transform.translated_local(Vector3(0, 0, -0.05))
		WeaponType.STAFF:
			grip = staff.transform.translated_local(Vector3(0, -0.12, 0))
		WeaponType.PISTOL:
			grip = pistol.transform.translated_local(Vector3(0, -0.05, 0.03))
	_place_arm(_fp_arm, _fp_hand, FP_SHOULDER, grip)


func _place_arm(arm: MeshInstance3D, hand: Node3D, shoulder: Vector3, grip: Transform3D) -> void:
	hand.transform = grip
	var to_hand := grip.origin - shoulder
	if to_hand.length() < 0.05:
		return
	var basis := Basis.looking_at(to_hand) * Basis.from_scale(Vector3(1, 1, to_hand.length()))
	arm.transform = Transform3D(basis, shoulder + to_hand * 0.5)


# Troca de arma ----------------------------------------------------------------

func _switch_weapon(type: WeaponType) -> void:
	if type == _weapon_type or _swing_phase != SwingPhase.NONE or _busy or _charging:
		return
	_weapon_type = type
	_equip = 0.0
	_reload_timer = 0.0
	_show_weapon(type)


## Garante o item no inventário e seleciona o slot dele na hotbar (testes, cheats).
func equip_item(id: StringName) -> void:
	if not inventory.has(id):
		inventory.add(id)
	for i in Inventory.HOTBAR_SIZE:
		if not inventory.slots[i].is_empty() and inventory.slots[i].id == id:
			inventory.select(i)
			break
	_sync_equipped()


## A arma na mão segue o slot selecionado da hotbar (slot sem arma = soco).
func _sync_equipped() -> void:
	var wanted: WeaponType = WEAPON_FROM_ITEM.get(ItemDB.weapon_of(inventory.selected_id()), WeaponType.FISTS)
	if wanted != _weapon_type:
		_switch_weapon(wanted)


func _show_weapon(type: WeaponType) -> void:
	weapon.visible = type == WeaponType.SWORD
	bat.visible = type == WeaponType.BAT
	staff.visible = type == WeaponType.STAFF
	pistol.visible = type == WeaponType.PISTOL
	_emit_weapon_text()


func _emit_weapon_text() -> void:
	var text: String = WEAPON_NAMES[_weapon_type]
	if inventory and inventory.selected_id() != &"":
		text = ItemDB.display_name(inventory.selected_id())
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
	if _busy or _equip < 1.0 or not _is_melee():
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
	if _swing_phase == SwingPhase.NONE and _blocking:
		# Arma atravessada na frente do rosto.
		var guard := Transform3D(_blade_basis(Vector3(-1.0, 0.3, -0.25), Vector3(0, 0.3, 1)), Vector3(0.3, -0.2, -0.52))
		node.transform = node.transform.interpolate_with(guard, 1.0 - exp(-20.0 * delta))
		_roll = 0.0
		return
	if _swing_phase == SwingPhase.NONE and _charging:
		# Lâmina apontada para frente, na altura da cintura (para espetar).
		var thrust := Transform3D(_blade_basis(Vector3(0.0, 0.06, -1.0), Vector3(1, 0, 0)), Vector3(0.14, -0.3, -0.38))
		node.transform = node.transform.interpolate_with(thrust.translated(_bob_offset(0.6)), 1.0 - exp(-14.0 * delta))
		_roll = 0.0
		return
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
	if _busy or _swing_phase != SwingPhase.NONE or _charging or parkour.is_busy():
		return
	_kick_animation(_do_kick)


## Perna sobe, "on_hit" roda no momento do impacto, perna volta.
func _kick_animation(on_hit: Callable) -> void:
	_busy = true
	foot.visible = true
	foot.transform = _foot_rest
	var out := _foot_rest.translated_local(Vector3(0, 0.25, -0.6))
	var tween := create_tween()
	tween.tween_property(foot, "transform", out, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_callback(on_hit)
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


func take_damage(amount: float, from_direction := Vector3.ZERO, attacker: Node = null) -> void:
	if health <= 0.0:
		return
	if _blocking and _is_facing_attack(from_direction):
		var parry := _block_time <= parry_window
		amount *= 0.0 if parry else block_damage_factor
		if attacker and attacker.has_method("on_blocked"):
			attacker.on_blocked(parry, -from_direction)
		var node: Node3D = _melee[_weapon_type].node
		ImpactFX.burst(get_parent(), node.global_position - camera.global_basis.z * 0.4, -from_direction, ImpactFX.SPARK, 12, 3.0, 0.03)
		_shake = 0.1 if parry else 0.16
		if parry:
			_hitstop(0.08)
		if amount <= 0.0:
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
	if hit and hit.collider.is_in_group("interactable") and not hit.collider.is_queued_for_deletion():
		found = hit.collider
	if not is_instance_valid(_interact_target):
		_interact_target = null
	if found != _interact_target:
		_interact_target = found
		interact_prompt_changed.emit(found.get_interact_text() if found else "")


# Carro ------------------------------------------------------------------------

func enter_vehicle(car: VintageCar) -> void:
	if vehicle or _charging or _busy or parkour.is_busy() or _swing_phase != SwingPhase.NONE:
		return
	vehicle = car
	$CollisionShape3D.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	head.rotation.x = 0.0
	_flashlight.visible = false
	car.set_driver(self)
	_vehicle_yaw = 0.0
	# Primeira pessoa: guarda a arma; as mãos vão para o volante.
	for node in [weapon, bat, staff, pistol, foot]:
		node.visible = false
	_fp_arm_left.visible = true
	_fp_hand_left.visible = true
	interact_prompt_changed.emit("")
	weapon_changed.emit("Carro")
	notify.emit("W/S acelerar e ré · A/D virar · Espaço freio de mão · E sair")


## Mãos no aro do volante (seguem o giro); antebraços saem dos ombros.
func _update_driving_hands() -> void:
	var points: Array = vehicle.hand_points()
	var to_camera := camera.global_transform.affine_inverse()
	var wheel_basis := to_camera.basis * vehicle.steering_wheel.global_basis
	# Ombros baixos e para os lados: os braços entram pelos cantos de baixo da tela.
	_place_arm(_fp_arm_left, _fp_hand_left, Vector3(-0.3, -0.5, 0.1), Transform3D(wheel_basis, to_camera * points[0]))
	_place_arm(_fp_arm, _fp_hand, Vector3(0.28, -0.5, 0.1), Transform3D(wheel_basis, to_camera * points[1]))


func exit_vehicle() -> void:
	if vehicle == null:
		return
	var car := vehicle
	var exit := car.exit_point()
	car.set_driver(null)
	vehicle = null
	global_position = exit
	rotation = Vector3(0, car.rotation.y + PI, 0)
	$CollisionShape3D.set_deferred("disabled", false)
	head.rotation.x = 0.0
	_show_weapon(_weapon_type)
	_emit_weapon_text()


## Coloca o item no inventário. Devolve quanto NÃO coube.
func pick_up(item_id: StringName, display_name: String, amount: int) -> int:
	var left := inventory.add(item_id, amount)
	if left == amount:
		notify.emit("Inventário cheio")
		return left
	item_picked_up.emit(item_id, amount - left)
	notify.emit("Pegou: %s x%d" % [display_name, amount - left])
	return left


## Solta o item do slot selecionado na frente do player (G).
func _drop_selected() -> void:
	if inventory.selected_id() == &"" or _swing_phase != SwingPhase.NONE or _charging:
		return
	var taken := inventory.take(inventory.selected, 999)
	var item: PickupItem = PICKUP_SCENE.instantiate()
	item.item_id = taken.id
	item.amount = taken.amount
	get_parent().add_child(item)
	item.global_position = camera.global_position - camera.global_basis.z * 0.7
	item.apply_central_impulse(-camera.global_basis.z * 2.0 + Vector3.UP)
	notify.emit("Soltou: %s" % ItemDB.display_name(taken.id))


func _is_facing_attack(from_direction: Vector3) -> bool:
	var forward := -camera.global_basis.z
	forward.y = 0.0
	var incoming := -from_direction
	incoming.y = 0.0
	return forward.normalized().dot(incoming.normalized()) > 0.3


# Bloqueio ---------------------------------------------------------------------

func _update_block(delta: float) -> void:
	var want := Input.is_action_pressed("block") and _is_melee() and not ui_blocked and health > 0.0 \
			and _swing_phase == SwingPhase.NONE and not _charging and not _busy and _equip >= 1.0
	if want and not _blocking:
		_block_time = 0.0
	_blocking = want
	if _blocking:
		_block_time += delta


# Soco -------------------------------------------------------------------------

func _punch() -> void:
	if _punch_timer > 0.0 or _busy or _equip < 1.0:
		return
	_punch_timer = punch_rate
	_punch_anim[_punch_side] = 1.0
	_punch_side = 1 - _punch_side
	get_tree().create_timer(0.07).timeout.connect(_do_punch_hit)


func _do_punch_hit() -> void:
	var hit := _cast_fan(punch_range)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	var direction := -camera.global_basis.z
	if collider.has_meta("enemy"):
		var enemy = collider.get_meta("enemy")
		if is_instance_valid(enemy) and enemy.has_method("take_hit"):
			enemy.take_hit(HitInfo.make(punch_damage, collider.get_meta("bone"), hit.position,
					direction, punch_force, HitInfo.Type.BLUNT))
			_hitstop(0.04)
			_shake = 0.08
	elif collider is RigidBody3D:
		collider.apply_impulse(direction * punch_force * 0.3, hit.position - collider.global_position)


## Raios em leque a partir da câmera: o golpe não precisa de mira perfeita.
func _cast_fan(reach: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var origin := camera.global_position
	var cam_basis := camera.global_basis
	var best := {}
	var best_dist := INF
	for offset in [Vector2.ZERO, Vector2(-0.15, 0), Vector2(0.15, 0), Vector2(0, -0.12), Vector2(0, 0.12)]:
		var dir: Vector3 = (-cam_basis.z + cam_basis.x * offset.x + cam_basis.y * offset.y).normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, MASK_HIT, [get_rid()])
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var dist := origin.distance_to(hit.position) - (0.5 if hit.collider.has_meta("enemy") else 0.0)
		if dist < best_dist:
			best_dist = dist
			best = hit
	return best


# Lanterna ---------------------------------------------------------------------

func _setup_flashlight() -> void:
	_flashlight = SpotLight3D.new()
	_flashlight.name = "Flashlight"
	_flashlight.light_color = Color(1.0, 0.95, 0.8)
	_flashlight.light_energy = 2.5
	_flashlight.spot_range = flashlight_range
	_flashlight.spot_angle = 22.0
	_flashlight.spot_attenuation = 0.8
	_flashlight.shadow_enabled = true
	_flashlight.position = Vector3(-0.18, -0.12, -0.1)
	_flashlight.visible = false
	camera.add_child(_flashlight)


func _toggle_flashlight() -> void:
	if not inventory.has(&"lanterna"):
		notify.emit("Você não tem uma lanterna")
		return
	_flashlight.visible = not _flashlight.visible


func is_flashlight_on() -> bool:
	return _flashlight.visible


## Luz na cara de um zumbi que está olhando para você: ele vem de longe.
func _update_flashlight(delta: float) -> void:
	if _flashlight.visible and not inventory.has(&"lanterna"):
		_flashlight.visible = false # soltou a lanterna
	if not _flashlight.visible:
		return
	_attract_timer -= delta
	if _attract_timer > 0.0:
		return
	_attract_timer = 0.25
	var origin := camera.global_position
	var aim := -camera.global_basis.z
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.has_method("alert") or enemy.state == Zombie.State.DEAD:
			continue
		var to_enemy: Vector3 = (enemy.global_position + Vector3.UP * 1.4) - origin
		if to_enemy.length() > attract_range or aim.dot(to_enemy.normalized()) < attract_cone:
			continue
		var facing: Vector3 = -enemy.global_basis.z
		if facing.dot(-Vector3(to_enemy.x, 0, to_enemy.z).normalized()) < 0.3:
			continue # de costas: não vê a luz
		var query := PhysicsRayQueryParameters3D.create(origin, origin + to_enemy, 1, [get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			enemy.alert(self)


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
	camera.rotation.z = lerpf(camera.rotation.z, _roll + parkour.camera_roll, 1.0 - exp(-14.0 * delta))
