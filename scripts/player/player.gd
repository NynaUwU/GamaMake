class_name Player
extends CharacterBody3D
## Player em primeira pessoa: movimento, armas, chute, soco, bloqueio,
## lanterna, inventário e interação. Movimentos especiais (agachar, deslizar,
## pular obstáculos, escalar) ficam no nó Parkour.
## Armas (pegas no mapa, ficam na hotbar): espada (corta membros), taco
## (desequilibra), cajado (mísseis explosivos) e pistola. Sem arma: soco.
## Atacar não gasta stamina; stamina é só para correr.

signal health_changed(current: float, maximum: float)
signal hunger_changed(current: float, maximum: float)
signal thirst_changed(current: float, maximum: float)
signal sick_changed(sick: bool)
signal cold_changed(heat: float, temperature: float)
signal stamina_changed(current: float, maximum: float)
signal interact_prompt_changed(text: String) ## "" = nada para interagir
signal notify(text: String) ## mensagens curtas no HUD
signal item_picked_up(item_id: StringName, amount: int) ## gancho para o inventário futuro
signal died
signal weapon_changed(weapon_text: String) ## nome da arma (+ munição)

enum WeaponType { FISTS, SWORD, BAT, STAFF, PISTOL, CHARGER, SPOON, GRAPPLE, HAMMER, CHISEL, SLIPPER, BOOMERANG, SHOVEL, AXE, PICKAXE, SPEAR, ROD }
const WEAPON_NAMES := {
	WeaponType.FISTS: "Mãos", WeaponType.SWORD: "Espada", WeaponType.BAT: "Taco",
	WeaponType.STAFF: "Cajado", WeaponType.PISTOL: "Pistola", WeaponType.CHARGER: "Carregador", WeaponType.SPOON: "Colherona", WeaponType.GRAPPLE: "Gancho",
	WeaponType.HAMMER: "Martelo", WeaponType.CHISEL: "Talhadeira",
	WeaponType.SLIPPER: "Chinelo", WeaponType.BOOMERANG: "Bumerangue", WeaponType.SHOVEL: "Pá", WeaponType.AXE: "Machado", WeaponType.PICKAXE: "Picareta", WeaponType.SPEAR: "Lança", WeaponType.ROD: "Vara de pesca",
}
## ItemDB "weapon" -> tipo de arma do player.
const WEAPON_FROM_ITEM := {"sword": WeaponType.SWORD, "bat": WeaponType.BAT,
	"staff": WeaponType.STAFF, "pistol": WeaponType.PISTOL, "charger": WeaponType.CHARGER, "spoon": WeaponType.SPOON, "grapple": WeaponType.GRAPPLE,
	"hammer": WeaponType.HAMMER, "chisel": WeaponType.CHISEL,
	"slipper": WeaponType.SLIPPER, "boomerang": WeaponType.BOOMERANG, "shovel": WeaponType.SHOVEL, "axe": WeaponType.AXE, "pickaxe": WeaponType.PICKAXE, "spear": WeaponType.SPEAR, "rod": WeaponType.ROD}
const SLIPPER_REST := Vector3(0.2, -0.24, -0.4)
const BOOMERANG_REST := Vector3(0.2, -0.22, -0.42)
const HAMMER_REST := Vector3(0.24, -0.26, -0.44)
const CHISEL_REST := Vector3(0.2, -0.22, -0.4)
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
const CHARGER_REST := Vector3(0.2, -0.2, -0.34)

enum SwingPhase { NONE, WINDUP, SLASH, RECOVER }

@export_group("Movimento")
@export var walk_speed := 4.0
@export var sprint_speed := 6.5
@export var jump_velocity := 5.0
@export var acceleration := 7.0 ## mais baixo = mais pesado para ganhar velocidade
@export var deceleration := 9.0 ## para de andar (sem input)
@export var fall_gravity := 1.6 ## caindo, a gravidade pesa mais (pulo menos "flutuante")
@export var head_bob := 0.035 ## sobe e desce da cabeça a cada passo
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

@export_group("Colherona")
@export var spoon_damage := 20.0
@export var spoon_force := 95.0 ## empurrão enorme: arremessa zumbis
@export var spoon_speed := 0.6 ## pesadona: golpe lento
@export var spoon_launch := 750.0 ## impulso do arremesso (zumbi voa ~10 m)

@export_group("Gancho")
## Clique para disparar e SEGURE para ficar preso balançando; soltou = solta a
## corda e mantém o impulso. A corda se recolhe sozinha quando você chega perto
## do gancho (nunca fica frouxa). WASD = controle no ar.
@export var grapple_range := 45.0
@export var grapple_air_control := 9.0 ## m/s² de empurrão com WASD balançando
@export var grapple_pull := 4.0 ## puxão inicial na direção do gancho
@export var grapple_lift := 4.5 ## impulso inicial para cima ao prender
@export var grapple_charges := 5 ## disparos antes de precisar recarregar
@export var grapple_recharge := 6.0 ## s sem usar até recarregar todas (usar de novo reinicia o tempo)

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
@export var battery_duration := 150.0 ## segundos de luz com a bateria cheia
@export var crank_per_click := 0.5 ## giro do dínamo por clique
@export var crank_decay := 1.0 ## quanto o giro perde por segundo
@export var crank_min := 0.25 ## giro mínimo para começar a carregar (clicar muito devagar não carrega)
@export var charge_rate := 0.06 ## carga por segundo por unidade de giro acima do mínimo

var flashlight_charge := 0.5 ## bateria da lanterna (0..1)

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
@export var max_stamina := 400.0 ## 4x o original: corre bem mais antes de cansar
@export var stamina_regen := 100.0 ## enche no mesmo tempo de antes
@export var sprint_drain := 14.0
@export var interact_range := 2.5

var health := max_health
var stamina := max_stamina

var _busy := false # chutando
var _regen_delay := 0.0
var _shake := 0.0
var bile_time := 0.0 ## bile do inchado na cara: tela verde (segundos que faltam)
var _interact_target: Node
var _hitstops := 0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _step_offset := 0.0 ## degrau recém-subido (desconta da câmera e some aos poucos)
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
var _arm_materials: Array = [] # manga e pele (ficam translúcidas dirigindo)
var _fp_hand_left: Node3D
const FP_SHOULDER_LEFT := Vector3(-0.34, -0.55, 0.22)

var vehicle: VintageCar ## carro que está dirigindo (null = a pé)
var _vehicle_yaw := 0.0 # olhar para os lados dentro do carro
var _vehicle_pitch := 0.0
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

var spoon: Node3D ## colherona na mão
var shovel: Node3D ## pá na mão
var axe: Node3D ## machado na mão
var pickaxe: Node3D ## picareta na mão
var spear: Node3D ## lança na mão
var rod: Node3D ## vara de pesca na mão
var fishing: Fishing
var swimming := false ## dentro d'água funda (nada em vez de andar)

## Fome: cai devagar (mais rápido correndo). Cheia (> 80) recupera vida aos
## pouquinhos; zerada, a vida vai caindo. Comida enche ("hunger" no ItemDB).
const MAX_HUNGER := 100.0
const HUNGER_RATE := 100.0 / (22.0 * 60.0) ## por segundo: ~22 min de cheia a zero
## Sede: esvazia mais rápido que a fome (~15 min); zerada, a vida cai mais rápido.
const MAX_THIRST := 100.0
const THIRST_RATE := 100.0 / (15.0 * 60.0)
## Doença (água suja): por SICK_TIME segundos a vida cai devagar, a stamina enche
## pela metade e fome/sede gastam 60% mais rápido.
const SICK_TIME := 180.0
var thirst := MAX_THIRST
var sick_time := 0.0
## Frio: "heat" é o calor do corpo (100 = quentinho, 0 = hipotermia). A
## temperatura sentida vem do bioma/altitude/noite/chuva/água, mais fogueira
## acesa perto, teto em cima e o isolamento das roupas ("warm" no ItemDB).
const MAX_HEAT := 100.0
var heat := MAX_HEAT
var temperature := 18.0 ## sentida, em graus (já com roupa e fogo)
var _cold_timer := 0.0
var _sheltered := false
var _thirst_warned := false
var hunger := MAX_HUNGER
var _hunger_warned := false
var _last_repair: Node
var _swing_wore := false
var _swing_wear := 0.0 # quanto este golpe já gastou da arma
var grapple: Node3D ## lançador do gancho na mão
var _grapple_active := false
var _anchor := Vector3.ZERO
var _rope_length := 0.0
var _rope: MeshInstance3D
var _grapple_left := 5
var _grapple_idle := 0.0
var slipper: Node3D ## chinelo na mão (some por um instante quando é jogado)
var boomerang: Node3D ## bumerangue na mão (some até voltar)
var _boomerang_out := false
var _slippers_out := 0 ## chinelos no ar (no máximo 2; voltam para a mão)
const MAX_SLIPPERS := 2
var _throw_anim := 0.0 # 1 = acabou de arremessar
var _throw_cooldown := 0.0
var hammer: Node3D ## martelo de construção na mão
var chisel: Node3D ## talhadeira na mão
var builder: Builder ## fantasma da peça / triângulo mirado (só o jogador local)
var pipe_tool: PipeTool ## cano na mão: arrasta e solta para pôr um trecho
var power_tool: PowerTool ## eixo/engrenagem/polia/esteira na mão
var _tool_hit := 0.0 # 1 = acabou de bater com o martelo/talhadeira
var charger: Node3D # carregador a dínamo na mão (modelo com Lever/Rotor/Needle)
var _crank_rate := 0.0
var _lever := 0.0

# Multiplayer: este mesmo script também é o boneco dos outros jogadores.
var remote_peer := 0 ## != 0: boneco de outro jogador (só segue o que chega pela rede)
var display_name := ""
var spawn_point := Vector3.INF ## onde renasce (online)
var _net_timer := 0.0
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _net_floor := true
var _net_vehicle := ""
var _net_item: StringName = &""
var _net_light_on := false
var _net_has := false
var _net_held: Node3D
var _net_light: SpotLight3D

var _charging := false # correndo com a espada para frente
var _charge_time := 0.0
var _impaled: Array = []


func _ready() -> void:
	health = max_health
	stamina = max_stamina
	_grapple_left = grapple_charges
	_ammo = magazine_size
	spoon = Node3D.new()
	spoon.name = "Spoon"
	camera.add_child(spoon)
	grapple = Node3D.new()
	grapple.name = "Grapple"
	grapple.position = Vector3(0.22, -0.24, -0.42)
	camera.add_child(grapple)
	hammer = Node3D.new()
	hammer.name = "Hammer"
	camera.add_child(hammer)
	slipper = Node3D.new()
	slipper.name = "Slipper"
	camera.add_child(slipper)
	boomerang = Node3D.new()
	boomerang.name = "Boomerang"
	camera.add_child(boomerang)
	chisel = Node3D.new()
	chisel.name = "Chisel"
	camera.add_child(chisel)
	shovel = Node3D.new()
	shovel.name = "Shovel"
	camera.add_child(shovel)
	axe = Node3D.new()
	axe.name = "Axe"
	camera.add_child(axe)
	pickaxe = Node3D.new()
	pickaxe.name = "Pickaxe"
	camera.add_child(pickaxe)
	spear = Node3D.new()
	spear.name = "Spear"
	camera.add_child(spear)
	rod = Node3D.new()
	rod.name = "Rod"
	camera.add_child(rod)
	_melee = {
		WeaponType.SWORD: {"node": weapon, "damage": melee_damage, "force": melee_force, "speed": 1.0,
			"cut": true, "length": 0.98, "trail": Color(1.0, 1.0, 0.95), "hitstop": 0.06},
		WeaponType.BAT: {"node": bat, "damage": bat_damage, "force": bat_force, "speed": bat_speed,
			"cut": false, "length": 0.9, "trail": Color(0.85, 0.75, 0.6), "hitstop": 0.09},
		WeaponType.SPOON: {"node": spoon, "damage": spoon_damage, "force": spoon_force, "speed": spoon_speed,
			"cut": false, "length": 1.5, "trail": Color(0.9, 0.9, 0.95), "hitstop": 0.12},
		WeaponType.SHOVEL: {"node": shovel, "damage": 26.0, "force": 50.0, "speed": 0.85,
			"cut": false, "length": 1.1, "trail": Color(0.75, 0.7, 0.6), "hitstop": 0.08},
		WeaponType.AXE: {"node": axe, "damage": 32.0, "force": 34.0, "speed": 0.9,
			"cut": true, "length": 0.8, "trail": Color(0.9, 0.9, 0.85), "hitstop": 0.08},
		WeaponType.PICKAXE: {"node": pickaxe, "damage": 28.0, "force": 30.0, "speed": 0.85,
			"cut": false, "length": 0.8, "trail": Color(0.8, 0.8, 0.8), "hitstop": 0.08},
		WeaponType.SPEAR: {"node": spear, "damage": 30.0, "force": 22.0, "speed": 1.1,
			"cut": false, "length": 1.7, "trail": Color(0.85, 0.85, 0.8), "hitstop": 0.05},
	}
	if not is_puppet():
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
	if is_puppet():
		_setup_puppet()
	else:
		builder = Builder.new()
		builder.name = "Builder"
		builder.player = self
		add_child(builder)
		pipe_tool = PipeTool.new()
		pipe_tool.name = "PipeTool"
		pipe_tool.player = self
		add_child(pipe_tool)
		power_tool = PowerTool.new()
		power_tool.name = "PowerTool"
		power_tool.player = self
		add_child(power_tool)


func _unhandled_input(event: InputEvent) -> void:
	if vehicle:
		# Dirigindo (primeira pessoa): o carro lê WASD/Espaço; o mouse olha em volta.
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_vehicle_yaw = clampf(_vehicle_yaw - event.relative.x * mouse_sensitivity, -1.9, 1.9)
			_vehicle_pitch = clampf(_vehicle_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-70), deg_to_rad(60))
		elif event.is_action_pressed("interact"):
			exit_vehicle()
		elif event.is_action_pressed("flashlight"):
			vehicle.toggle_headlights()
		elif _should_recapture(event):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	elif _should_recapture(event):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif health > 0.0 and not ui_blocked:
		if event.is_action_pressed("attack") and inventory.selected_id() in [&"agua", &"agua_suja"] and _aimed_placed(PlacedManager.POUR_CAP.keys()) != null:
			SteamModels.pour(self, _aimed_placed(PlacedManager.POUR_CAP.keys())) # despeja na caldeira/destilaria/caixa
		elif event.is_action_pressed("attack") and inventory.selected_id() == &"cano":
			pipe_tool.press()
		elif event.is_action_pressed("attack") and PowerTool.handles(inventory.selected_id()):
			power_tool.press() # eixo (arrastar), engrenagem/polia (montar), esteira (ligar)
		elif event.is_action_pressed("attack") and inventory.selected_id() in [&"alcool", &"oleo"] and _aimed_car() != null:
			_refuel(_aimed_car())
		elif event.is_action_pressed("attack") and ItemDB.def(inventory.selected_id()).kind == "food":
			_eat_selected()
		elif event.is_action_pressed("attack") and ItemDB.def(inventory.selected_id()).kind == "seed":
			Farming.use(self, String(ItemDB.def(inventory.selected_id()).crop))
		elif event.is_action_pressed("attack") and inventory.selected_id() == &"garrafa":
			_fill_bottle()
		elif event.is_action_pressed("attack") and ItemDB.def(inventory.selected_id()).kind == "placeable":
			_place_selected()
		elif event.is_action_pressed("attack"):
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
			elif _weapon_type == WeaponType.CHARGER:
				_crank()
			elif _weapon_type == WeaponType.GRAPPLE:
				_fire_grapple()
			elif _weapon_type in [WeaponType.HAMMER, WeaponType.CHISEL]:
				_use_tool()
			elif _weapon_type == WeaponType.SLIPPER:
				_throw_slipper()
			elif _weapon_type == WeaponType.BOOMERANG:
				_throw_boomerang()
			elif _weapon_type == WeaponType.ROD:
				_fishing().click()
		elif event.is_action_pressed("block") and _weapon_type == WeaponType.ROD:
			_fishing().cancel()
		elif event.is_action_pressed("block") and _weapon_type == WeaponType.SHOVEL:
			if Time.get_ticks_msec() < _shovel_ready:
				return # a pá tem 1 s entre uma cavada e outra
			if Farming.use(self, ""):
				_shovel_ready = Time.get_ticks_msec() + 1000
				_start_swing_visual_only()
				_wear_selected(0.75) # cavar: serviço certo da pá
		elif event.is_action_pressed("block") and _weapon_type == WeaponType.HAMMER:
			if Input.is_key_pressed(KEY_SHIFT):
				# Segurando Shift, o clique direito desmonta o que está mirado (fica vermelho).
				if _equip >= 1.0 and builder.dismantle():
					_tool_hit = 1.0
					Net.i.send_player_action("tool", 0)
			else:
				builder.open_menu() # segurando: menu de construção; soltando: escolhe
		elif event.is_action_pressed("reload") and _weapon_type == WeaponType.HAMMER:
			builder.rotate()
			_emit_weapon_text()
		elif event.is_action_pressed("reload") and _weapon_type == WeaponType.CHISEL:
			builder.toggle_diagonal()
			_emit_weapon_text()
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
		elif event.is_action_pressed("ping"):
			PingMarkers.ping_from(self)
		elif event.is_action_pressed("interact") and _interact_target is PlacedObject and Machines.is_crank(_interact_target.kind):
			# Máquina de manivela: toque = abrir/pôr/tirar; segurando = girar (ver _update_crank).
			_crank_target = _interact_target
			_crank_hold = 0.0
		elif event.is_action_pressed("attack") and inventory.selected_id() == &"adubo":
			_fertilize()
		elif event.is_action_pressed("interact") and is_instance_valid(_interact_target):
			_interact_target.interact(self)
			# O item some ao ser pego: limpa o aviso na hora.
			_interact_target = null
			interact_prompt_changed.emit("")


func _physics_process(delta: float) -> void:
	_net_send(delta)
	if health <= 0.0:
		return
	_update_crank(delta)
	if not is_puppet():
		_update_hunger(delta)
		bile_time = maxf(bile_time - delta, 0.0)
	if vehicle:
		# Sentado no banco: acompanha o carro (o mouse gira só a cabeça).
		# Sentado: o corpo fica preso ao banco; o mouse gira só a cabeça (pernas não seguem a câmera).
		global_transform = vehicle.seat.global_transform
		velocity = Vector3.ZERO
		return
	if parkour.physics(delta):
		# Deslizando / pulando obstáculo / escalando: o Parkour move o player.
		_update_interact()
		_update_camera_shake(delta)
		_update_charge(delta)
		return
	if _grapple_active:
		_update_grapple(delta)
		_update_interact()
		_update_camera_shake(delta)
		return
	var sprinting := _is_sprinting()
	var water_depth := WaterManager.i.depth_at(global_position) if WaterManager.i else -INF
	swimming = water_depth > 1.15
	if swimming:
		_swim(delta, water_depth)
	elif not is_on_floor():
		velocity.y -= _gravity * delta * (fall_gravity if velocity.y < 0.0 else 1.0)
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
	if swimming:
		speed *= 0.55 # nadando é mais devagar
	elif water_depth > 0.4:
		speed *= 0.75 # andando com água pela cintura
	var target := direction * speed
	var accel := (acceleration if direction != Vector3.ZERO else deceleration) if is_on_floor() or swimming else acceleration * air_control
	var t := 1.0 - exp(-accel * delta)
	var flat := Vector2(velocity.x, velocity.z)
	if not is_on_floor() and flat.length() > speed:
		# No ar mais rápido que a corrida (soltou o gancho, pulou de um telhado):
		# mantém o impulso; WASD só curva um pouco.
		if direction != Vector3.ZERO:
			flat = flat.lerp(Vector2(direction.x, direction.z) * flat.length(), t * 0.5)
		velocity.x = flat.x
		velocity.z = flat.y
	else:
		velocity.x = lerpf(velocity.x, target.x, t)
		velocity.z = lerpf(velocity.z, target.z, t)
	var fall_speed := velocity.y
	var was_on_floor := is_on_floor()
	if not swimming:
		_step_offset += StepClimb.step(self, delta) # câmera sobe suave, não dá tranco
	move_and_slide()
	if not was_on_floor and is_on_floor() and fall_speed < -2.5:
		parkour.land(-fall_speed) # cabeça "afunda" ao aterrissar
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


## Nadar: sem gravidade; Espaço sobe, C desce, olhar para baixo andando
## para frente mergulha. Parado, boia devagar até a cabeça sair da água.
func _swim(delta: float, depth: float) -> void:
	var up := 0.0
	if Input.is_action_pressed("jump") and not ui_blocked:
		up = 2.4
	elif Input.is_action_pressed("crouch") and not ui_blocked:
		up = -2.4
	else:
		var forward := Input.get_axis("move_back", "move_forward")
		up = sin(head.rotation.x) * forward * 2.6 # mergulha para onde olha
		if absf(up) < 0.2:
			up = 0.5 if depth > 1.55 else 0.0 # boia até a cabeça ficar fora
	velocity.y = lerpf(velocity.y, up, 1.0 - exp(-4.0 * delta))
	# Pulo saindo da água pela margem.
	if is_on_wall() and Input.is_action_pressed("jump") and depth < 1.7:
		velocity.y = 4.0


func _fishing() -> Fishing:
	if fishing == null:
		fishing = Fishing.new()
		fishing.player = self
		add_child(fishing)
	return fishing


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
	if is_puppet():
		_puppet_process(delta)
		return
	_update_torch(delta)
	_update_held()
	if vehicle:
		head.position.y = vehicle.eye_height
		global_transform = vehicle.seat.global_transform
		# Guinada e arfagem montadas juntas (YXZ): girar o rotate_x depois da guinada torcia a câmera.
		head.rotation = Vector3(_vehicle_pitch, _vehicle_yaw, 0.0)
		_update_driving_hands()
		_update_camera_shake(delta)
		return
	head.position.y = parkour.eye_height(delta) - _step_offset
	_step_offset = move_toward(_step_offset, 0.0, delta * maxf(2.5, _step_offset * 12.0))
	_sync_equipped()
	_update_block(delta)
	_punch_timer -= delta
	for i in 2:
		_punch_anim[i] = move_toward(_punch_anim[i], 0.0, delta * 6.0)
	_equip = minf(_equip + delta / equip_time, 1.0)
	# Ritmo dos passos com limite: voando de gancho/caindo rápido não "pedala" o braço.
	var moving := minf(Vector2(velocity.x, velocity.z).length() / walk_speed, 1.6) if is_on_floor() else 0.2
	_bob += delta * (2.0 + moving * 6.0)
	_footsteps()
	# Peso: a cabeça sobe e desce e balança de leve a cada passo.
	var step := minf(Vector2(velocity.x, velocity.z).length() / walk_speed, 1.6) if is_on_floor() else 0.0
	head.position.y += absf(sin(_bob)) * head_bob * step - head_bob * 0.5 * step
	head.rotation.z = sin(_bob) * 0.006 * step
	_update_swing(delta)
	_update_staff(delta)
	_update_pistol(delta)
	_update_charger(delta)
	_update_tools(delta)
	_update_fp_arm()
	_update_parkour_hands()
	_update_rope()
	# Gancho: recarrega todas as cargas depois de um tempo sem usar.
	if _grapple_left < grapple_charges:
		_grapple_idle += delta
		if _grapple_idle >= grapple_recharge:
			_grapple_left = grapple_charges
			_emit_weapon_text()
	if _weapon_type == WeaponType.GRAPPLE:
		grapple.position = Vector3(0.22, -0.24, -0.42) + _bob_offset(0.8) + _equip_offset()


## Modelos das armas na mão: os mesmos do chão/ícones (ItemModels).
func _install_weapon_models() -> void:
	weapon.add_child(ItemModels.build(&"espada"))
	bat.add_child(ItemModels.build(&"taco"))
	var staff_model := ItemModels.build(&"cajado")
	staff_model.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, -0.41, 0)) # em pé, orbe na ponta (Tip)
	staff.add_child(staff_model)
	pistol.add_child(ItemModels.build(&"pistola"))
	spoon.add_child(ItemModels.build(&"colher"))
	shovel.add_child(ItemModels.build(&"pa"))
	axe.add_child(ItemModels.build(&"machado"))
	pickaxe.add_child(ItemModels.build(&"picareta"))
	spear.add_child(ItemModels.build(&"lanca"))
	var rod_model := ItemModels.build(&"vara")
	rod_model.rotation.x = 0.22 # vara um pouco levantada, apontando para a frente
	rod.add_child(rod_model)
	rod.position = Vector3(0.24, -0.3, -0.4)
	grapple.add_child(ItemModels.build(&"gancho"))
	hammer.add_child(ItemModels.build(&"martelo"))
	slipper.add_child(ItemModels.build(&"chinelo"))
	boomerang.add_child(ItemModels.build(&"bumerangue"))
	chisel.add_child(ItemModels.build(&"talhadeira"))
	_rope = MeshInstance3D.new()
	_rope.name = "Rope"
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.012
	rope_mesh.bottom_radius = 0.012
	rope_mesh.height = 1.0
	rope_mesh.radial_segments = 5
	rope_mesh.rings = 1
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(0.3, 0.22, 0.14)
	rope_mat.roughness = 0.95
	rope_mesh.material = rope_mat
	_rope.mesh = rope_mesh
	_rope.top_level = true
	_rope.visible = false
	add_child(_rope)
	charger = Node3D.new()
	charger.name = "Charger"
	charger.position = CHARGER_REST
	charger.add_child(ItemModels.build_charger())
	camera.add_child(charger)


# Braço em primeira pessoa -----------------------------------------------------

func _setup_fp_arm() -> void:
	var sleeve := StandardMaterial3D.new()
	_arm_materials = [sleeve]
	sleeve.albedo_color = Color(0.22, 0.3, 0.2)
	sleeve.roughness = 0.9
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.85, 0.66, 0.52)
	skin.roughness = 0.8
	_arm_materials.append(skin)
	_fp_arm = MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.074, 0.074, 1.0) # um pouco mais fino
	_fp_arm.mesh = arm_mesh
	_fp_arm.material_override = sleeve
	_fp_arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(_fp_arm)
	_fp_hand = _cube_hand(skin) # mão = um cubo simples (como no começo)
	camera.add_child(_fp_hand)
	_fp_arm_left = _fp_arm.duplicate()
	camera.add_child(_fp_arm_left)
	_fp_hand_left = _cube_hand(skin)
	camera.add_child(_fp_hand_left)


const HAND_SIZE := 0.068 ## lado do cubo da mão em primeira pessoa


## Mão em primeira pessoa: um cubo de pele (o item segurado passa por dentro dele).
func _cube_hand(material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Hand"
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * HAND_SIZE # cubo perfeito
	mesh.mesh = box
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	return root


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
		# O item segurado (e a tocha) acompanha a mão direita, inclusive no soco.
		if _held and _held.visible:
			_held.position = right + offset # o modelo já vem posicionado (em pé no punho ou em cima dele)
		if _torch and _torch.visible:
			if inventory.selected_id() == &"tocha":
				_torch.position = right + offset + Vector3(0.0, 0.02, -0.02)
			else:
				_torch.position = left + offset + Vector3(-0.1, -0.08, -0.06) # mão secundária: na esquerda, mais baixa e para o canto
		_place_arm(_fp_arm, _fp_hand, FP_SHOULDER, grip)
		return
	match _weapon_type:
		WeaponType.SWORD:
			grip = weapon.transform.translated_local(Vector3(0, 0, 0.04))
		WeaponType.BAT:
			grip = bat.transform.translated_local(Vector3(0, 0, -0.05))
		WeaponType.SPOON:
			grip = spoon.transform.translated_local(Vector3(0, 0, 0.0))
		WeaponType.SHOVEL:
			grip = shovel.transform.translated_local(Vector3(0, 0, -0.05))
		WeaponType.AXE:
			grip = axe.transform.translated_local(Vector3(0, 0, -0.03))
		WeaponType.PICKAXE:
			grip = pickaxe.transform.translated_local(Vector3(0, 0, -0.03))
		WeaponType.SPEAR:
			grip = spear.transform.translated_local(Vector3(0, 0, -0.35))
		WeaponType.ROD:
			grip = rod.transform.translated_local(Vector3(0, 0, 0.02))
		WeaponType.GRAPPLE:
			grip = grapple.transform.translated_local(Vector3(0, -0.05, 0.03))
		WeaponType.STAFF:
			grip = staff.transform.translated_local(Vector3(0, -0.12, 0))
		WeaponType.PISTOL:
			grip = pistol.transform.translated_local(Vector3(0, -0.05, 0.03))
		WeaponType.CHARGER:
			grip = charger.transform.translated_local(Vector3(0, -0.05, 0.02))
		WeaponType.HAMMER:
			grip = hammer.transform.translated_local(Vector3(0, 0, 0.02))
		WeaponType.SLIPPER:
			grip = slipper.transform.translated_local(Vector3(0, 0, -0.06))
		WeaponType.BOOMERANG:
			grip = boomerang.transform.translated_local(Vector3(0, 0, -0.02))
		WeaponType.CHISEL:
			grip = chisel.transform.translated_local(Vector3(0, 0, 0.02))
	_place_arm(_fp_arm, _fp_hand, FP_SHOULDER, grip)


## Parkour: mãos apoiadas no obstáculo (ou arrastando no chão no deslize).
## Com as duas mãos no obstáculo, a arma some por um instante.
var _hands_busy := false


func _update_parkour_hands() -> void:
	var w := parkour.hand_weight
	var both := parkour.hand_targets[1] != Vector3.INF
	if w < 0.02:
		if _hands_busy:
			_hands_busy = false
			_show_weapon(_weapon_type)
		return
	var to_camera := camera.global_transform.affine_inverse()
	var palm_down := Basis(Vector3.RIGHT, -PI / 2) # punho virado para baixo, apoiando
	# O apoio real fica abaixo do campo de visão: traz a mão para a borda de baixo da tela,
	# na direção do ponto (dá a sensação de empurrar o obstáculo).
	var visible_point := func(p: Vector3) -> Vector3:
		return Vector3(clampf(p.x, -0.32, 0.32), maxf(p.y, -0.27), minf(p.z, -0.42))
	if parkour.hand_targets[0] != Vector3.INF:
		var rest := Vector3(-0.2, -0.26, -0.38)
		var planted: Vector3 = visible_point.call(to_camera * parkour.hand_targets[0])
		_fp_arm_left.visible = true
		_fp_hand_left.visible = true
		_place_arm(_fp_arm_left, _fp_hand_left, FP_SHOULDER_LEFT, Transform3D(palm_down, rest.lerp(planted, w)))
	if both:
		if not _hands_busy and w > 0.3:
			_hands_busy = true
			for node in [weapon, bat, staff, pistol, charger, spoon, grapple, hammer, chisel, slipper, boomerang, shovel, axe, pickaxe, spear, rod]:
				node.visible = false
		var rest_r := Vector3(0.2, -0.26, -0.38)
		var planted_r: Vector3 = visible_point.call(to_camera * parkour.hand_targets[1])
		_place_arm(_fp_arm, _fp_hand, FP_SHOULDER, Transform3D(palm_down, rest_r.lerp(planted_r, w)))


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
	spoon.visible = type == WeaponType.SPOON
	if shovel:
		shovel.visible = type == WeaponType.SHOVEL
		axe.visible = type == WeaponType.AXE
		pickaxe.visible = type == WeaponType.PICKAXE
		spear.visible = type == WeaponType.SPEAR
		rod.visible = type == WeaponType.ROD
	if grapple:
		grapple.visible = type == WeaponType.GRAPPLE
	if type != WeaponType.GRAPPLE:
		_release_grapple()
	if charger:
		charger.visible = type == WeaponType.CHARGER
	if hammer:
		hammer.visible = type == WeaponType.HAMMER
		chisel.visible = type == WeaponType.CHISEL
		slipper.visible = type == WeaponType.SLIPPER and _slippers_out < MAX_SLIPPERS
		boomerang.visible = type == WeaponType.BOOMERANG and not _boomerang_out
	_emit_weapon_text()


func _emit_weapon_text() -> void:
	var text: String = WEAPON_NAMES[_weapon_type]
	if inventory and inventory.selected_id() != &"":
		text = ItemDB.display_name(inventory.selected_id())
	if _weapon_type == WeaponType.PISTOL:
		text += "  recarregando..." if _reload_timer > 0.0 else "  %d/%d" % [_ammo, magazine_size]
	elif _weapon_type == WeaponType.GRAPPLE:
		text += "  %d/%d" % [_grapple_left, grapple_charges] if _grapple_left > 0 else "  recarregando..."
	elif _weapon_type == WeaponType.SLIPPER:
		text += "  %d/%d" % [MAX_SLIPPERS - _slippers_out, MAX_SLIPPERS]
	elif _weapon_type == WeaponType.BOOMERANG and _boomerang_out:
		text += "  (voltando...)"
	elif _weapon_type == WeaponType.HAMMER and builder:
		text += ": %s" % builder.tool_name()
	elif _weapon_type == WeaponType.CHISEL and builder:
		text += ": diagonal %s  (R troca)" % builder.diag
	weapon_changed.emit(text)


func _is_melee() -> bool:
	return _melee.has(_weapon_type)


## Arma "sobe" da parte de baixo da tela ao ser equipada.
func _equip_offset() -> Vector3:
	return Vector3(0, -0.45, 0.1) * (1.0 - ease(_equip, 0.4))


func _bob_offset(scale: float) -> Vector3:
	var moving := minf(Vector2(velocity.x, velocity.z).length() / walk_speed, 1.6) if is_on_floor() else 0.2
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
	Net.i.send_player_action("swing", _swing_index)
	Sfx.play_at("swing", camera.global_position - camera.global_basis.z * 0.6, 0.0, 1.2 / stats.speed)
	_swing_phase = SwingPhase.WINDUP
	_swing_time = 0.0
	_swing_start = stats.node.transform
	_swing_queued = false
	_swing_hits.clear()
	_swing_wore = false
	_swing_wear = 0.0
	# Um golpe atravessa de 2 a 5 inimigos (sorteado a cada golpe): horda não é mais fácil.
	max_targets = randi_range(2, 5)
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
	material.vertex_color_is_srgb = true
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
		var reach := melee_range * (1.6 if _weapon_type == WeaponType.SPEAR else 1.0) # lança alcança longe
		var query := PhysicsRayQueryParameters3D.create(origin, origin + ray_dir * reach, MASK_HIT, [get_rid()])
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
	var hits_before := _swing_hits.size()
	_apply_swing_hit_inner(hit, direction, swing)
	# Acertou alguma coisa: a arma/ferramenta gasta (uma vez por golpe; se o mesmo
	# golpe pegar algo que gasta mais, cobra só a diferença).
	if _swing_hits.size() > hits_before:
		var cost := _wear_cost(hit.collider)
		if cost > _swing_wear:
			_wear_selected(cost - _swing_wear)
			_swing_wear = cost


## Quanto o golpe gasta: atacar = 100%; ferramenta no serviço certo = 75%;
## no serviço errado (espada na árvore, machado na pedra) = 200%. A maça gasta
## sempre 100%.
func _wear_cost(collider: Object) -> float:
	if inventory.selected_id() == &"taco" or collider.has_meta("enemy"):
		return 1.0
	var right := false
	if collider is ResourceNode:
		right = (collider.kind in ResourceNode.TREES and _weapon_type == WeaponType.AXE) \
			or (collider.kind in ResourceNode.STONES and _weapon_type == WeaponType.PICKAXE)
	elif collider is PlacedObject or collider is PickupItem: # árvore plantada, tronco no chão
		right = _weapon_type == WeaponType.AXE
	elif collider is Furniture:
		right = _weapon_type in [WeaponType.AXE, WeaponType.HAMMER]
	else:
		return 1.0
	return 0.75 if right else 2.0


## Gasta usos do item da mão; quebrou: some com um estalo e volta para os punhos.
func _wear_selected(uses := 1.0) -> void:
	if inventory.wear(inventory.selected, uses):
		Sfx.play("crunch", 0.0, 0.6)
		_sync_equipped()


func _apply_swing_hit_inner(hit: Dictionary, direction: Vector3, swing: Dictionary) -> void:
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
			if _weapon_type == WeaponType.SPOON:
				info.launch = spoon_launch # efeito cômico: o zumbi vai longe
			key.take_hit(info)
			_hitstop(stats.hitstop)
			_shake = 0.12
	elif collider.has_method("tool_hit"):
		# Árvore / rocha / veio de minério: o machado e a picareta rendem muito mais.
		_swing_hits.append(key)
		# Ferramenta simples (de pedra) rende menos ("power" no ItemDB).
		var power: float = ItemDB.def(inventory.selected_id()).get("power", 1.0)
		collider.tool_hit(self, _weapon_type, stats.damage * swing.damage * power, hit.position)
		_shake = 0.08
	elif collider is PickupItem and collider.item_id in [&"tronco", &"tabua"] and _weapon_type == WeaponType.AXE:
		_swing_hits.append(key)
		# Cortado ali mesmo com o machado: tronco -> 2 tábuas; tábua -> 2 gravetos.
		var into := &"tabua" if collider.item_id == &"tronco" else &"graveto"
		Net.i.convert_pickup(collider, into, 2 * collider.amount)
		Sfx.play_at("knock", hit.position, 4.0, 0.7)
		_shake = 0.08
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
	Net.i.send_player_action("cast", 0)
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
	Net.i.fx("missile", [start, aim_point - start])


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
	Net.i.send_player_action("shoot", 0)
	Sfx.play_at("shot", muzzle.global_position)
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
	# Zumbi longe fica sem hitboxes (desempenho): o tiro acerta a cápsula dele.
	var far := PhysicsRayQueryParameters3D.create(origin, origin + direction * pistol_range, 1 << 2, [get_rid()])
	var far_hit := get_world_3d().direct_space_state.intersect_ray(far)
	if far_hit and far_hit.collider is Zombie and not far_hit.collider.hitboxes_active \
			and (hit.is_empty() or origin.distance_to(far_hit.position) < origin.distance_to(hit.position)):
		hit = far_hit
	var end: Vector3 = hit.position if hit else origin + direction * pistol_range
	ImpactFX.tracer(get_parent(), muzzle.global_position, end)
	Net.i.fx("tracer", [muzzle.global_position, end])
	if hit:
		var collider: Object = hit.collider
		if collider is Zombie:
			collider.set_meta("enemy", collider)
			collider.set_meta("bone", collider.hit_bone_at(hit.position))
		if collider.has_meta("enemy"):
			var enemy = collider.get_meta("enemy")
			if is_instance_valid(enemy) and enemy.has_method("take_hit"):
				enemy.take_hit(HitInfo.make(pistol_damage, collider.get_meta("bone"), hit.position,
						direction, pistol_force, HitInfo.Type.PIERCE))
				ImpactFX.burst(get_parent(), hit.position, -direction + hit.normal, ImpactFX.BLOOD, 14, 2.5)
				Net.i.fx("burst", [hit.position, -direction + hit.normal, ImpactFX.BLOOD, 14, 2.5])
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
	Net.i.send_player_action("kick", 0)
	Sfx.play_at("swing", global_position + Vector3.UP * 0.6, -4.0, 0.9)
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
	if is_puppet():
		Net.i.damage_player(remote_peer, amount, from_direction, attacker) # quem decide o bloqueio é o dono
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
	amount *= 1.0 - inventory.armor() # roupa/armadura vestida segura parte do golpe
	if amount > 0.0 and inventory.wear_equipment():
		Sfx.play("crunch", -2.0, 0.7) # uma peça de roupa rasgou/quebrou
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	_shake = 0.2
	velocity += from_direction * 3.0
	if health <= 0.0:
		notify.emit("Você morreu - aperte Backspace para %s" % ("renascer" if Net.i.online() else "recomeçar"))
		died.emit()


## Efeito de zumbi especial: "bile" (segundos de tela verde) ou "knock" (empurrão
## forte do bote/investida). Boneco de outro jogador: quem aplica é o dono.
func apply_special(what: String, value: float, direction := Vector3.ZERO) -> void:
	if health <= 0.0:
		return
	if is_puppet():
		Net.i.player_special(remote_peer, what, value, direction)
		return
	match what:
		"bile":
			bile_time = maxf(bile_time, value)
			Sfx.play("slap", 0.0, 0.6)
			_shake = maxf(_shake, 0.15)
		"knock":
			if vehicle:
				return
			velocity += Vector3(direction.x, 0.0, direction.z) * value + Vector3.UP * value * 0.4
			_shake = maxf(_shake, 0.35)


func heal(amount: float) -> void:
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)


## Congela o jogo por um instante no impacto: dá peso ao golpe.
func _hitstop(duration: float) -> void:
	if Net.i.online():
		return # online o tempo não pode parar (ele é de todo mundo)
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
	query.collide_with_areas = true # área de mira maior dos itens pequenos (PickupItem "Grab")
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider is Area3D:
		if hit.collider.has_meta("pickup") and is_instance_valid(hit.collider.get_meta("pickup")):
			hit.collider = hit.collider.get_meta("pickup")
		else:
			query.collide_with_areas = false # outra área qualquer: ignora
			hit = get_world_3d().direct_space_state.intersect_ray(query)
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
	car.discovered = true # passa a aparecer no mapa
	$CollisionShape3D.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	head.rotation.x = 0.0
	_flashlight.visible = false
	car.set_driver(self)
	_vehicle_yaw = 0.0
	_vehicle_pitch = 0.0
	# Primeira pessoa: guarda a arma; as mãos vão para o volante.
	_release_grapple()
	for node in [weapon, bat, staff, pistol, charger, spoon, grapple, hammer, chisel, slipper, boomerang, shovel, axe, pickaxe, spear, rod, foot]:
		node.visible = false
	_fp_arm_left.visible = true
	_fp_hand_left.visible = true
	_set_arms_see_through(true)
	interact_prompt_changed.emit("")
	weapon_changed.emit("Carro")


## Dirigindo: braços e mãos semitransparentes para enxergar a estrada.
func _set_arms_see_through(enabled: bool) -> void:
	for material: StandardMaterial3D in _arm_materials:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color.a = 0.45 if enabled else 1.0


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
	var exit := _safe_exit(car)
	car.set_driver(null)
	Net.i.leave_car(car)
	vehicle = null
	global_position = exit
	velocity = Vector3.ZERO
	var forward := car.global_basis.z
	forward.y = 0.0
	rotation = Vector3(0, (atan2(forward.x, forward.z) if forward.length() > 0.1 else rotation.y) + PI, 0)
	$CollisionShape3D.set_deferred("disabled", false)
	head.rotation = Vector3.ZERO
	_set_arms_see_through(false)
	_show_weapon(_weapon_type)
	_emit_weapon_text()


## Onde descer do carro sem cair pelo mundo: em pé, a porta do motorista; tombado,
## virado ou com o lado bloqueado, tenta o outro lado, atrás, na frente, mais longe
## e por cima. Sempre em cima do chão (raio de cima para baixo, nunca abaixo do
## terreno) e só onde o corpo cabe.
func _safe_exit(car: VintageCar) -> Vector3:
	var space := get_world_3d().direct_space_state
	var center := car.global_position
	var forward := car.global_basis.z
	forward.y = 0.0
	if forward.length() < 0.1:
		forward = car.global_basis.y # de nariz para cima/baixo: usa o teto como "frente"
		forward.y = 0.0
	var yaw := Basis(Vector3.UP, atan2(forward.x, forward.z)) if forward.length() > 0.01 else Basis()
	var candidates: Array[Vector3] = []
	if car.global_basis.y.y > 0.75:
		candidates.append(car.exit_point()) # em pé: a porta de sempre
	for off in [Vector3(-1.6, 0, 0), Vector3(1.6, 0, 0), Vector3(0, 0, -3.0), Vector3(0, 0, 3.0),
			Vector3(-2.6, 0, 0), Vector3(2.6, 0, 0), Vector3(-2.2, 0, -2.6), Vector3(2.2, 0, 2.6)]:
		candidates.append(center + yaw * off)
	candidates.append(center + Vector3.UP * 1.5) # em cima do carro
	var shape: CapsuleShape3D = $CollisionShape3D.shape
	var terrain := get_parent().get_node_or_null("Terrain") as TerrainWorld
	for c in candidates:
		var from := Vector3(c.x, maxf(c.y, center.y) + 3.0, c.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 12.0, 1, [get_rid(), car.get_rid()]))
		var p := Vector3(c.x, c.y, c.z)
		if hit:
			p.y = hit.position.y + 0.05
		if terrain:
			p.y = maxf(p.y, terrain.height_at(p.x, p.z) + 0.05)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(), p + Vector3.UP * (shape.height * 0.5 + 0.05))
		query.collision_mask = 1
		query.exclude = [get_rid()]
		if space.intersect_shape(query, 1).is_empty():
			return p
	# Nada livre (preso no meio de coisas): em cima do carro, acima do chão.
	var top := center + Vector3.UP * 2.2
	if terrain:
		top.y = maxf(top.y, terrain.height_at(top.x, top.z) + 1.0)
	return top


## Come o item de comida do slot selecionado: enche a fome e/ou recupera vida.
func _eat_selected() -> void:
	var id := inventory.selected_id()
	var heal_amount: float = ItemDB.def(id).get("heal", 0)
	var food: float = ItemDB.def(id).get("hunger", 0)
	var water: float = ItemDB.def(id).get("thirst", 0)
	var fresh: float = inventory.slots[inventory.selected].get("dur", 1.0)
	var cures: bool = ItemDB.def(id).get("cure", false)
	var useful := (heal_amount > 0.0 and health < max_health) or (food > 0.0 and hunger < MAX_HUNGER - 2.0) \
		or (water > 0.0 and thirst < MAX_THIRST - 2.0) or (cures and sick_time > 0.0)
	if not useful:
		Sfx.play("click", -6.0, 0.6)
		return
	inventory.take(inventory.selected, 1)
	heal(heal_amount)
	eat(food)
	if cures and sick_time > 0.0:
		sick_time = 0.0 # álcool limpou a infecção
		sick_changed.emit(false)
	if water > 0.0:
		drink(water)
	# Quase estragada (menos de 25% de frescor) também pode fazer mal.
	if randf() < ItemDB.def(id).get("sick", 0.0) or (ItemDB.spoils(id) and fresh < 0.25 and randf() < 0.3):
		get_sick()
	var returns: StringName = ItemDB.def(id).get("returns", &"")
	if returns != &"":
		pick_up(returns, ItemDB.display_name(returns), 1) # garrafa vazia volta
	Sfx.play("slap" if water > 0.0 and food <= 0.0 else "crunch", -6.0 if water > 0.0 else 0.0, 0.7 if water > 0.0 else 1.0)
	var parts := []
	if food > 0.0:
		parts.append("+%d fome" % food)
	if heal_amount > 0.0:
		parts.append("+%d vida" % heal_amount)
	pass


func eat(amount: float) -> void:
	hunger = clampf(hunger + amount, 0.0, MAX_HUNGER)
	if hunger > 25.0:
		_hunger_warned = false
	hunger_changed.emit(hunger, MAX_HUNGER)


func _update_thirst(delta: float) -> void:
	var rate := THIRST_RATE * (1.6 if _is_sprinting() else 1.0) * (1.6 if sick_time > 0.0 else 1.0)
	var before := int(thirst)
	thirst = maxf(thirst - rate * delta, 0.0)
	if thirst <= 0.0:
		health = maxf(health - 1.0 * delta, 0.0) # desidratado: perde vida
		health_changed.emit(health, max_health)
		if health <= 0.0:
			notify.emit("Você morreu de sede - aperte Backspace para %s" % ("renascer" if Net.i.online() else "recomeçar"))
			died.emit()
	if thirst < 25.0 and not _thirst_warned:
		_thirst_warned = true
		Sfx.play("crunch", -16.0, 0.4) # garganta seca (som, sem aviso escrito)
	if int(thirst) != before:
		thirst_changed.emit(thirst, MAX_THIRST)
	if sick_time > 0.0:
		sick_time = maxf(sick_time - delta, 0.0)
		if health > 15.0:
			health -= 0.12 * delta
			health_changed.emit(health, max_health)
		if sick_time == 0.0:
			sick_changed.emit(false)


func drink(amount: float) -> void:
	thirst = clampf(thirst + amount, 0.0, MAX_THIRST)
	if thirst > 25.0:
		_thirst_warned = false
	thirst_changed.emit(thirst, MAX_THIRST)


func get_sick(seconds := SICK_TIME) -> void:
	var was := sick_time > 0.0
	sick_time = maxf(sick_time, seconds)
	if not was:
		sick_changed.emit(true)
		Sfx.play("growl", -10.0, 0.4) # barriga revirando


## Garrafa vazia na mão: clique na água do lago (água suja) ou num coletor de chuva (potável).
func _fill_bottle() -> void:
	var origin := camera.global_position
	var to := origin - camera.global_basis.z * 4.0
	var query := PhysicsRayQueryParameters3D.create(origin, to, MASK_INTERACT, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider is PlacedObject and hit.collider.kind == "rain_collector":
		if hit.collider.extra.get("water", 0.0) < 1.0:
			Sfx.play("click", -6.0, 0.6)
			return
		inventory.take(inventory.selected, 1)
		(get_parent().get_node("Placed") as PlacedManager).request("draw_water", [hit.collider.net_id])
		Sfx.play_at("slap", hit.position, -6.0, 1.4)
		return
	# Lago: a mira bate abaixo do nível da água, ou o jogador está dentro d'água.
	var end: Vector3 = hit.position if hit else to
	var wet := WaterManager.i != null and (WaterManager.i.depth_at(end) > 0.0 or WaterManager.i.depth_at(global_position) > 0.2)
	if not wet:
		Sfx.play("click", -6.0, 0.6)
		return
	inventory.take(inventory.selected, 1)
	pick_up(&"agua_suja", ItemDB.display_name(&"agua_suja"), 1)
	Sfx.play_at("slap", end, -4.0, 1.2)


## Temperatura do lugar (sem a roupa).
func ambient_temperature() -> float:
	var terrain := get_parent().get_node_or_null("Terrain") as TerrainWorld
	var t := 16.0
	var desert := 0.0
	if terrain:
		var biome := terrain.biome_at(global_position.x, global_position.z)
		desert = biome.desert
		t = 16.0 * biome.plains + 30.0 * biome.desert - 8.0 * biome.winter + 12.0 * biome.mountain
		t -= maxf(global_position.y - 30.0, 0.0) * 0.15 # altitude esfria
	var night := DayNight.i.night if DayNight.i else 0.0
	t -= night * (8.0 + 14.0 * desert) # deserto gela à noite
	if Weather.i:
		t -= Weather.i.rain * 5.0
	if WaterManager.i and WaterManager.i.depth_at(global_position + Vector3.UP * 0.5) > 0.0:
		t -= 7.0 # molhado
	for fire in Cooking.fires:
		if is_instance_valid(fire) and fire.is_lit():
			var d: float = fire.global_position.distance_to(global_position)
			if d < 7.0:
				t += 18.0 * (1.0 - d / 7.0) # calor da fogueira acesa
	if _sheltered:
		t += 5.0
	return t


## Isolamento das roupas vestidas (0 a ~1,4).
func insulation() -> float:
	var total := 0.0
	for slot in inventory.equipment:
		if not inventory.equipment[slot].is_empty():
			total += ItemDB.def(inventory.equipment[slot].id).get("warm", 0.0)
	return minf(total, 1.4)


func _update_cold(delta: float) -> void:
	_cold_timer -= delta
	if _cold_timer > 0.0:
		return
	var step := 0.5 - _cold_timer
	_cold_timer = 0.5
	# Teto em cima (casa, construção): protege do vento e da chuva.
	var up := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.9, global_position + Vector3.UP * 7.0, 1, [get_rid()])
	_sheltered = not get_world_3d().direct_space_state.intersect_ray(up).is_empty()
	temperature = ambient_temperature() + insulation() * 14.0
	if temperature < 10.0:
		heat = maxf(heat - (10.0 - temperature) * 0.06 * step, 0.0)
	elif temperature > 14.0:
		heat = minf(heat + 1.2 * step, MAX_HEAT)
	if heat <= 0.0 and health > 0.0:
		health = maxf(health - 0.6 * step, 0.0) # hipotermia
		health_changed.emit(health, max_health)
		if health <= 0.0:
			notify.emit("Você morreu de frio - aperte Backspace para %s" % ("renascer" if Net.i.online() else "recomeçar"))
			died.emit()
	cold_changed.emit(heat, temperature)


var _spoil_timer := 5.0
var _shovel_ready := 0
func _update_hunger(delta: float) -> void:
	_update_thirst(delta)
	_update_cold(delta)
	_spoil_timer -= delta
	if _spoil_timer <= 0.0:
		_spoil_timer = 5.0
		inventory.spoil(5.0) # comida na mochila estraga aos poucos
	var rate := HUNGER_RATE * (1.8 if _is_sprinting() else 1.0) * (1.6 if sick_time > 0.0 else 1.0)
	var before := int(hunger)
	hunger = maxf(hunger - rate * delta, 0.0)
	if hunger <= 0.0:
		health = maxf(health - 0.6 * delta, 0.0) # passando fome: perde vida devagar
		health_changed.emit(health, max_health)
		if health <= 0.0:
			notify.emit("Você morreu de fome - aperte Backspace para %s" % ("renascer" if Net.i.online() else "recomeçar"))
			died.emit()
	elif hunger > 80.0 and thirst > 30.0 and sick_time <= 0.0 and health < max_health:
		heal(0.25 * delta)
	if hunger < 25.0 and not _hunger_warned:
		_hunger_warned = true
		Sfx.play("growl", -14.0, 0.5) # barriga roncando
	if int(hunger) != before:
		hunger_changed.emit(hunger, MAX_HUNGER)


## Pá cavando/plantando: só o movimento da pá (sem acertar ninguém).
func _start_swing_visual_only() -> void:
	_shake = maxf(_shake, 0.05)
	Sfx.play_at("step_soft", global_position + Vector3.UP * 0.3, 4.0, 0.7)


## Salvo junto com o jogador (SaveGame).
func save_extra() -> Dictionary:
	return {"hunger": hunger, "thirst": thirst, "sick": sick_time, "heat": heat, "equipment": inventory.equipment.duplicate(true)}


func load_extra(data: Dictionary) -> void:
	hunger = data.get("hunger", MAX_HUNGER)
	thirst = data.get("thirst", MAX_THIRST)
	heat = data.get("heat", MAX_HEAT)
	sick_time = data.get("sick", 0.0)
	thirst_changed.emit(thirst, MAX_THIRST)
	sick_changed.emit(sick_time > 0.0)
	var worn: Dictionary = data.get("equipment", {})
	for slot in worn:
		if inventory.equipment.has(slot):
			inventory.equipment[slot] = worn[slot]
	inventory.changed.emit()
	hunger_changed.emit(hunger, MAX_HUNGER)


## Coloca o item no inventário. Devolve quanto NÃO coube.
func pick_up(item_id: StringName, display_name: String, amount: int, dur := 1.0) -> int:
	var left := inventory.add(item_id, amount, dur)
	if left == amount:
		Sfx.play("click", -6.0, 0.6)
		return left
	item_picked_up.emit(item_id, amount - left)
	Sfx.play("pickup")
	pass
	return left


## Solta o item do slot selecionado na frente do player (G).
func _drop_selected() -> void:
	if inventory.selected_id() == &"" or _swing_phase != SwingPhase.NONE or _charging:
		return
	var dur: float = inventory.slots[inventory.selected].get("dur", 1.0)
	var taken := inventory.take(inventory.selected, 999)
	var where := Transform3D(global_basis, camera.global_position - camera.global_basis.z * 0.7)
	Net.i.drop_item(taken.id, taken.amount, where, -camera.global_basis.z * 2.0 + Vector3.UP, dur)
	pass


func _is_facing_attack(from_direction: Vector3) -> bool:
	var forward := -camera.global_basis.z
	forward.y = 0.0
	var incoming := -from_direction
	incoming.y = 0.0
	return forward.normalized().dot(incoming.normalized()) > 0.3


# Bloqueio ---------------------------------------------------------------------

func _update_block(delta: float) -> void:
	var want := Input.is_action_pressed("block") and _is_melee() and _weapon_type != WeaponType.SHOVEL and not ui_blocked and health > 0.0 \
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
	Net.i.send_player_action("punch", _punch_side)
	Sfx.play_at("punch", camera.global_position - camera.global_basis.z * 0.5, -3.0, 1.0)
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
	elif collider.has_method("tool_hit"):
		collider.tool_hit(self, WeaponType.FISTS, punch_damage, hit.position) # soco desmonta móvel (e machuca árvore)
		_shake = 0.06
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
	if vehicle:
		vehicle.toggle_headlights() # no carro, L liga/desliga os faróis
		return
	if not _has_lantern():
		notify.emit("Você não tem uma lanterna")
		return
	if not _flashlight.visible and flashlight_charge < 0.02:
		return # sem bateria: não acende (só o carregador mostra a carga)
	_flashlight.visible = not _flashlight.visible


# Gancho -----------------------------------------------------------------------

func _fire_grapple() -> void:
	if _equip < 1.0 or _grapple_active:
		return
	if _grapple_left <= 0:
		_shake = 0.02 # sem carga: espere recarregar
		return
	_grapple_left -= 1
	_grapple_idle = 0.0
	_emit_weapon_text()
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * grapple_range, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_shake = 0.03 # errou: só o tranco
		return
	_anchor = hit.position
	_grapple_active = true
	_rope_length = maxf(_chest().distance_to(_anchor) * 0.92, 2.0)
	velocity += (_anchor - _chest()).normalized() * grapple_pull + Vector3.UP * grapple_lift
	_shake = 0.08


func _release_grapple() -> void:
	_grapple_active = false
	if _rope:
		_rope.visible = false


func _chest() -> Vector3:
	return global_position + Vector3.UP * 1.2


## Pêndulo: gravidade + WASD, e a corda não deixa passar do comprimento.
func _update_grapple(delta: float) -> void:
	if not Input.is_action_pressed("attack") or health <= 0.0:
		_release_grapple()
		return
	velocity.y -= _gravity * delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	velocity += (global_basis * Vector3(input.x, 0, input.y)) * grapple_air_control * delta
	var to := _chest() - _anchor
	_rope_length = maxf(minf(_rope_length, to.length()), 1.5) # chegou mais perto: recolhe
	if to.length() >= _rope_length:
		var n := to.normalized()
		var outward := velocity.dot(n)
		if outward > 0.0:
			velocity -= n * outward # tira a velocidade que esticaria a corda
	move_and_slide()
	to = _chest() - _anchor
	if to.length() > _rope_length + 0.02:
		global_position = _anchor + to.normalized() * _rope_length - Vector3.UP * 1.2
	parkour.camera_roll = clampf(-velocity.dot(global_basis.x) * 0.012, -0.12, 0.12)


func _update_rope() -> void:
	if not _grapple_active:
		return
	var from := grapple.global_transform * Vector3(0, 0.02, -0.25)
	var span := _anchor - from
	if span.length() < 0.05:
		return
	_rope.visible = true
	var up := span.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	# Estica só o eixo Y local do cilindro (a corda) até o gancho.
	_rope.global_transform = Transform3D(Basis(side, up * span.length(), side.cross(up)), from + span * 0.5)


# Carregador ------------------------------------------------------------------

## Cada clique aperta a alavanca e gira o dínamo; só carrega girando rápido.
func _crank() -> void:
	if _equip < 1.0:
		return
	_crank_rate = minf(_crank_rate + crank_per_click, 2.5)
	_lever = 1.0
	Net.i.send_player_action("crank", 0)


func _update_charger(delta: float) -> void:
	_crank_rate = move_toward(_crank_rate, 0.0, crank_decay * delta)
	_lever = move_toward(_lever, 0.0, delta * 7.0)
	if _crank_rate > crank_min:
		flashlight_charge = minf(flashlight_charge + (_crank_rate - crank_min) * charge_rate * delta, 1.0)
	if _weapon_type != WeaponType.CHARGER or charger == null:
		return
	charger.position = CHARGER_REST + _bob_offset(0.8) + _equip_offset() + Vector3(0, 0.01, 0.015) * _lever
	charger.rotation = Vector3(0.05 * _lever, -0.25, 0.0) # motor apontando para o centro da tela
	var model := charger.get_child(0)
	model.get_node("Lever").rotation.x = -0.3 * ease(_lever, 0.5) # alavanca encosta no cabo
	model.get_node("Rotor").rotation.x += _crank_rate * 25.0 * delta
	var needle: Node3D = model.get_node("Needle")
	var wanted := lerpf(0.9, -0.9, flashlight_charge) + sin(Time.get_ticks_msec() * 0.03) * 0.03 * _crank_rate
	needle.rotation.z = lerpf(needle.rotation.z, wanted, 1.0 - exp(-10.0 * delta))


# Construção ---------------------------------------------------------------------

func _tool_kind() -> String:
	match _weapon_type:
		WeaponType.HAMMER:
			return "hammer"
		WeaponType.CHISEL:
			return "chisel"
	return ""


# Item na mão ---------------------------------------------------------------------

var _held: Node3D
var _held_id := &""


## Qualquer item sem modelo de arma próprio (comida, material, semente, garrafa,
## roupa, bandeira...) aparece segurado na mão direita.
func _update_held() -> void:
	var id := inventory.selected_id()
	var show := id != &"" and _weapon_type == WeaponType.FISTS and id != &"tocha" and vehicle == null
	if not show:
		if _held:
			_held.visible = false
		return
	if _held == null or id != _held_id:
		if _held:
			_held.queue_free()
		_held = Node3D.new()
		var model := ItemModels.build(id)
		var bounds := AABB()
		var first := true
		for part in model.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = part.mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var size := bounds.size
		var axis := size.max_axis_index()
		var dims := [size.x, size.y, size.z]
		dims.sort()
		var long: bool = dims[2] >= dims[1] * 2.0 # garrafa, tábua, graveto, cenoura...
		var basis := Basis()
		if long:
			# Em pé na mão: o eixo mais comprido vira o vertical, atravessando o punho pelo meio.
			if axis == Vector3.AXIS_X:
				basis = Basis(Vector3.BACK, PI / 2)
			elif axis == Vector3.AXIS_Z:
				basis = Basis(Vector3.RIGHT, PI / 2)
			basis = Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, -0.15) * basis
			var scale_long := clampf(0.24 / maxf(dims[2], 0.01), 0.2, 1.2)
			basis = basis.scaled(Vector3.ONE * scale_long)
			model.transform = Transform3D(basis, -(basis * bounds.get_center()))
		else:
			# Pequeno/chato: em cima da mão.
			basis = Basis(Vector3.UP, 0.6) * Basis(Vector3.RIGHT, 0.2)
			var scale_small := clampf(0.095 / maxf(dims[2], 0.01), 0.25, 1.2)
			basis = basis.scaled(Vector3.ONE * scale_small)
			var lift := HAND_SIZE * 0.5 + size.y * scale_small * 0.5
			model.transform = Transform3D(basis, -(basis * bounds.get_center()) + Vector3(0, lift, 0))
		_held.add_child(model)
		camera.add_child(_held)
		_held_id = id
	_held.visible = true


# Tocha ---------------------------------------------------------------------------

var _torch: Node3D
var _torch_light: OmniLight3D
var _torch_burn := 0.0


## Tocha na mão (ou na mão secundária, à esquerda): aparece acesa (luz que tremula)
## e queima por meio dia. Lanterna na mão secundária aparece na mão esquerda.
func _update_torch(delta: float) -> void:
	var off: Dictionary = inventory.equipment.get("offhand", {})
	var in_main := inventory.selected_id() == &"tocha"
	var in_off: bool = not off.is_empty() and off.id == &"tocha" and not in_main
	var holding := in_main or in_off
	_update_offhand_lantern(not off.is_empty() and off.id == &"lanterna")
	if holding and _torch == null:
		_torch = Node3D.new()
		_torch.add_child(ItemModels.build(&"tocha"))
		_torch.position = Vector3(0.28, -0.3, -0.45)
		_torch.rotation = Vector3(0.2, 0, -0.15)
		camera.add_child(_torch)
		StationModels._fire(_torch, Vector3(0, 0.26, 0), 0.03, 0.45)
		_torch_light = OmniLight3D.new()
		_torch_light.light_color = Color(1.0, 0.62, 0.3)
		_torch_light.omni_range = 9.0
		_torch_light.position = Vector3(0, 0.3, 0)
		_torch.add_child(_torch_light)
	if _torch:
		_torch.visible = holding and vehicle == null
		_torch.position = Vector3(0.28, -0.3, -0.45) if in_main else Vector3(-0.34, -0.36, -0.46)
		_torch.rotation = Vector3(0.2, 0, -0.15) if in_main else Vector3(0.2, 0, 0.18)
	if not holding:
		return
	_torch_light.light_energy = 1.6 + 0.35 * sin(Time.get_ticks_msec() * 0.013) + randf_range(-0.1, 0.1)
	_torch_burn += delta
	if _torch_burn >= 1.0:
		_torch_burn -= 1.0
		var slot: Dictionary = inventory.slots[inventory.selected] if in_main else off
		slot.dur = slot.get("dur", 1.0) - 1.0 / ItemDB.max_durability(&"tocha")
		if slot.dur <= 0.0:
			if in_main:
				inventory.slots[inventory.selected] = {} # apagou: acabou a tocha
			else:
				inventory.equipment["offhand"] = {}
			Sfx.play("creak", -10.0, 1.6)
		inventory.changed.emit()


## Lanterna na mão secundária: o modelo aparece na mão esquerda (a luz é a de sempre, L).
var _off_lantern: Node3D
func _update_offhand_lantern(show: bool) -> void:
	if show and _off_lantern == null:
		_off_lantern = Node3D.new()
		_off_lantern.add_child(ItemModels.build(&"lanterna"))
		_off_lantern.position = Vector3(-0.22, -0.16, -0.3)
		_off_lantern.rotation = Vector3(0.05, 0.0, 0.0)
		camera.add_child(_off_lantern)
	if _off_lantern:
		_off_lantern.visible = show and vehicle == null


func _has_lantern() -> bool:
	var off: Dictionary = inventory.equipment.get("offhand", {})
	return inventory.has(&"lanterna") or (not off.is_empty() and off.id == &"lanterna")


# Máquinas de manivela (Tier 1) ------------------------------------------------

const CRANK_HOLD := 0.25 ## segurar mais que isso = girar (menos = toque)
var _crank_target: PlacedObject
var _crank_hold := 0.0
var _crank_send := 0.0


func _update_crank(delta: float) -> void:
	if _crank_target == null:
		return
	if not is_instance_valid(_crank_target):
		_crank_target = null
		return
	if not Input.is_action_pressed("interact") or ui_blocked:
		if _crank_hold < CRANK_HOLD and not ui_blocked:
			Machines.tap(self, _crank_target) # foi só um toque
		_flush_crank()
		_crank_target = null
		return
	_crank_hold += delta
	if _crank_hold < CRANK_HOLD:
		return
	if _crank_target.global_position.distance_to(global_position) > interact_range + 1.5:
		_flush_crank()
		_crank_target = null
		return
	if Machines.crank_local(self, _crank_target, delta):
		_regen_delay = 0.6 # girando: a stamina não enche
		_crank_send += delta
		if _crank_send >= 0.3:
			_flush_crank()


func _flush_crank() -> void:
	if _crank_send > 0.0 and is_instance_valid(_crank_target) and _crank_target.kind != "grindstone" and _crank_target.kind != "pump":
		(get_parent().get_node("Placed") as PlacedManager).request("crank", [_crank_target.net_id, _crank_send])
	_crank_send = 0.0


## Clicou no jogo com o mouse solto (ex.: depois de alt-tab): prende de novo.
## Nunca com um menu aberto, e nunca pela rodinha (rolar a lista de um menu
## mandava o evento para cá e prendia o mouse com o menu ainda na frente).
func _should_recapture(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton and event.pressed) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return false
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		return false
	return not ui_blocked and not (builder and builder.menu_open())


## Objeto colocado mirado (de um destes tipos) ou null.
func _aimed_placed(kinds: Array) -> PlacedObject:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * interact_range * 1.4, MASK_INTERACT, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is PlacedObject or not hit.collider.kind in kinds:
		return null
	return hit.collider


## Carro mirado (de fora) ou null.
func _aimed_car() -> VintageCar:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * interact_range * 1.6, 0xFFFFFFFF, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var node: Node = hit.collider
	while node and not node is VintageCar:
		node = node.get_parent()
	return node as VintageCar


## Álcool/óleo na mão + clique no carro: abastece.
func _refuel(car: VintageCar) -> void:
	if car.fuel >= 0.99:
		Sfx.play("click", -6.0, 0.6) # tanque cheio
		return
	var id := inventory.selected_id()
	inventory.take(inventory.selected, 1)
	Net.i.refuel_car(car, VintageCar.FUEL_ITEMS[id])
	Sfx.play_at("slap", car.global_position + Vector3.UP * 0.8, -2.0, 0.6)


## Adubo na mão: clique num plantador (as próximas 3 colheitas dele rendem o dobro).
func _fertilize() -> void:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * interact_range, MASK_INTERACT, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is PlacedObject or not hit.collider.is_farm():
		Sfx.play("click", -6.0, 0.6)
		return
	inventory.take(inventory.selected, 1)
	(get_parent().get_node("Placed") as PlacedManager).request("extra", [hit.collider.net_id, {"fert": 3}])
	Sfx.play_at("step_soft", hit.position, 2.0, 0.9)


## Bandeira (e o que mais for "placeable"): finca onde a mira bate no chão.
func _place_selected() -> void:
	var def := ItemDB.def(inventory.selected_id())
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * 4.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var placed: PlacedManager = get_parent().get_node_or_null("Placed")
	if hit.is_empty() or hit.normal.y < 0.6 or placed == null or placed.occupied(hit.position, 0.5):
		Sfx.play("click", -6.0, 0.6)
		return
	var facing := Basis(Vector3.UP, rotation.y)
	placed.request("place", [def.place, Transform3D(facing, hit.position)])
	inventory.take(inventory.selected, 1)
	Sfx.play_at("step_soft", hit.position, 2.0, 1.2)


## Clique com o martelo ou a talhadeira: a ferramenta bate e o Builder age.
func _use_tool() -> void:
	if _equip < 1.0 or _tool_hit > 0.4:
		return
	_tool_hit = 1.0
	Net.i.send_player_action("tool", 0)
	if builder.use(_tool_kind()):
		_shake = maxf(_shake, 0.05)
		_wear_selected(0.75) # construir/talhar: serviço certo


# Arremessos ---------------------------------------------------------------------

## Chinelo: sempre na cabeça do zumbi mais perto do centro da mira. Volta para
## a mão; com os 2 no ar, só joga de novo quando um voltar.
func _throw_slipper() -> void:
	if _equip < 1.0 or _throw_cooldown > 0.0 or _slippers_out >= MAX_SLIPPERS:
		return
	_slippers_out += 1
	_throw_cooldown = 0.3
	_throw_anim = 1.0
	Net.i.send_player_action("throw", 0)
	var aim := -camera.global_basis.z
	var target := ThrownSlipper.pick_target(get_tree(), camera.global_position, aim)
	var projectile := ThrownSlipper.new()
	get_parent().add_child(projectile)
	projectile.launch(slipper.global_position, aim, target, self)
	slipper.visible = false
	_emit_weapon_text()
	Net.i.fx("slipper", [slipper.global_position, aim, target.net_id if target else 0])


## Bumerangue: só um por vez (volta para a mão).
func _throw_boomerang() -> void:
	if _equip < 1.0 or _boomerang_out:
		return
	_boomerang_out = true
	_emit_weapon_text()
	_throw_anim = 1.0
	Net.i.send_player_action("throw", 0)
	var aim := -camera.global_basis.z
	var target := ThrownSlipper.pick_target(get_tree(), camera.global_position, aim)
	var projectile := Boomerang.new()
	get_parent().add_child(projectile)
	projectile.launch(boomerang.global_position, aim, target, self)
	boomerang.visible = false
	Net.i.fx("boomerang", [boomerang.global_position, aim, target.net_id if target else 0])


## Um chinelo voltou para a mão.
func catch_slipper() -> void:
	_slippers_out = maxi(_slippers_out - 1, 0)
	_emit_weapon_text()


## O bumerangue voltou (ou se perdeu): de novo na mão.
func catch_boomerang() -> void:
	_boomerang_out = false
	_emit_weapon_text()
	if _weapon_type == WeaponType.BOOMERANG:
		boomerang.visible = true


func _update_throwables(delta: float) -> void:
	_throw_anim = move_toward(_throw_anim, 0.0, delta * 3.5)
	_throw_cooldown -= delta
	var swing := sin(_throw_anim * PI)
	if _weapon_type == WeaponType.SLIPPER:
		var has_one := _slippers_out < MAX_SLIPPERS
		slipper.visible = has_one and _throw_cooldown <= 0.15 # outro chinelo na mão (se sobrou)
		slipper.position = SLIPPER_REST + _bob_offset(0.8) + _equip_offset() + Vector3(0, 0.12, 0.08) * swing
		slipper.rotation = Vector3(0.5 + 0.8 * swing, 0.2, 0.1)
	elif _weapon_type == WeaponType.BOOMERANG:
		boomerang.position = BOOMERANG_REST + _bob_offset(0.8) + _equip_offset() + Vector3(0.05, 0.1, 0.06) * swing
		boomerang.rotation = Vector3(0.3, 0.6 + 1.2 * swing, 0.2)


func _update_tools(delta: float) -> void:
	_update_throwables(delta)
	_tool_hit = move_toward(_tool_hit, 0.0, delta * 4.0)
	if builder:
		builder.update(_tool_kind() if health > 0.0 and not ui_blocked else "")
		if builder.repair_target != _last_repair:
			_last_repair = builder.repair_target
			_emit_weapon_text() # "Consertar [custo]" aparece/some
	# Batida: a ferramenta sobe e desce rápido para frente.
	var swing := sin(_tool_hit * PI)
	if _weapon_type == WeaponType.HAMMER:
		hammer.position = HAMMER_REST + _bob_offset(0.8) + _equip_offset() + Vector3(0, 0.05, -0.05) * swing
		hammer.rotation = Vector3(1.1 - 1.0 * swing, 0.15, 0) # de pé (cabeça para cima), desce batendo
	elif _weapon_type == WeaponType.CHISEL:
		chisel.position = CHISEL_REST + _bob_offset(0.8) + _equip_offset() + Vector3(0, 0, -0.12) * swing
		chisel.rotation = Vector3(-0.1, 0.1, 0)


func is_flashlight_on() -> bool:
	return _flashlight.visible


## Luz na cara de um zumbi que está olhando para você: ele vem de longe.
func _update_flashlight(delta: float) -> void:
	if _flashlight.visible and not _has_lantern():
		_flashlight.visible = false # soltou a lanterna
	if not _flashlight.visible:
		return
	# Bateria: a luz enfraquece devagar e suave conforme a carga cai (dá para
	# notar só prestando atenção); quase no fim dá umas piscadas leves.
	flashlight_charge = maxf(flashlight_charge - delta / battery_duration, 0.0)
	var strength := 0.35 + 0.65 * sqrt(flashlight_charge)
	if flashlight_charge < 0.04 and randf() < 0.05:
		strength *= 0.7
	_flashlight.light_energy = lerpf(_flashlight.light_energy, 2.5 * strength, 1.0 - exp(-6.0 * delta))
	_flashlight.spot_range = flashlight_range * (0.75 + 0.25 * strength)
	if flashlight_charge <= 0.0:
		_flashlight.visible = false
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
		stamina = minf(stamina + stamina_regen * delta * (0.5 if sick_time > 0.0 else 1.0) * (0.6 if heat < 30.0 else 1.0), max_stamina)
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
	camera.rotation.x = lerpf(camera.rotation.x, parkour.camera_pitch, 1.0 - exp(-14.0 * delta))


# --- Multiplayer ----------------------------------------------------------------

## Passo a cada meia volta do balanço da cabeça (no chão e andando). Construção
## e pedra soam "duro"; terra, grama e areia, "fofo".
var _last_step := 0


func _footsteps() -> void:
	var step := int(_bob / PI)
	if step == _last_step:
		return
	_last_step = step
	var speed := Vector2(velocity.x, velocity.z).length()
	if not grounded() or speed < 0.8 or vehicle:
		return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 0.4, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# Terreno (chão do chunk) é fofo; construção, rua, pedra e carro são duros.
	var hard: bool = hit and not (hit.collider.get_parent() and hit.collider.get_parent().get_parent() is TerrainWorld)
	Sfx.play_at("step_hard" if hard else "step_soft", global_position, minf(speed - 4.0, 4.0), 1.0 if speed < 5.0 else 1.15)


func is_puppet() -> bool:
	return remote_peer != 0


## No chão? (o boneco remoto usa o que o dono mandou).
func grounded() -> bool:
	return _net_floor if is_puppet() else is_on_floor()


## Renasce no ponto de início com a vida cheia (online, depois de morrer).
func respawn() -> void:
	if vehicle:
		exit_vehicle()
	health = max_health
	stamina = max_stamina
	hunger = maxf(hunger, 70.0)
	hunger_changed.emit(hunger, MAX_HUNGER)
	thirst = maxf(thirst, 70.0)
	thirst_changed.emit(thirst, MAX_THIRST)
	sick_time = 0.0
	sick_changed.emit(false)
	heat = MAX_HEAT
	velocity = Vector3.ZERO
	if spawn_point != Vector3.INF:
		global_position = spawn_point
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	notify.emit("Você renasceu")


## Manda o estado do próprio boneco para os outros (~20x por segundo).
func _net_send(delta: float) -> void:
	if is_puppet() or not Net.i.online():
		return
	_net_timer -= delta
	if _net_timer > 0.0:
		return
	_net_timer = 1.0 / 20.0
	Net.i.send_player_state([global_position, rotation.y, head.rotation.x, velocity, is_on_floor() or vehicle != null,
		parkour.crouching, int(parkour.move), String(vehicle.name) if vehicle else "", inventory.selected_id(),
		is_flashlight_on(), health, _arm_hold()])


## Pose contínua dos braços que os outros veem: apontando a arma ou bloqueando.
func _arm_hold() -> String:
	if _blocking:
		return "block"
	if _weapon_type in [WeaponType.PISTOL, WeaponType.STAFF, WeaponType.GRAPPLE]:
		return "aim"
	return ""


## Boneco remoto: o dono fez um golpe/soco/chute/tiro -> o corpo mostra.
func play_net_action(action: String, arg: int) -> void:
	var animator := $Body/Skeleton3D/Animator as PlayerBody
	if animator:
		animator.play(action, arg)
	if action in ["swing", "punch", "kick", "throw"]:
		Sfx.play_at("swing", global_position + Vector3.UP * 1.3, -2.0 if action == "swing" else -6.0)


func apply_net_state(state: Array) -> void:
	_net_pos = state[0]
	_net_yaw = state[1]
	_net_pitch = state[2]
	velocity = state[3]
	_net_floor = state[4]
	parkour.crouching = state[5]
	parkour.move = state[6]
	_net_vehicle = state[7]
	_net_light_on = state[9]
	health = state[10]
	var animator := $Body/Skeleton3D/Animator as PlayerBody
	if animator and state.size() > 11:
		animator.hold = state[11]
		animator.aim_pitch = _net_pitch
	if not _net_has:
		_net_has = true
		global_position = _net_pos
		rotation.y = _net_yaw
	if state[8] != _net_item:
		_net_item = state[8]
		_set_held_item(_net_item)


func _setup_puppet() -> void:
	remove_from_group("player")
	add_to_group("remote_player")
	set_physics_process(false)
	set_process_unhandled_input(false)
	camera.current = false
	camera.visible = false # armas e braços de primeira pessoa são só do dono
	var rig := $Body/Skeleton3D
	if rig.has_method("set_shadow_only"):
		rig.set_shadow_only(false) # os outros veem o corpo inteiro
	var tag := Label3D.new()
	tag.text = display_name
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 2.15, 0)
	tag.font_size = 48
	tag.pixel_size = 0.004
	tag.outline_size = 10
	tag.modulate = Color(1.0, 0.95, 0.8)
	add_child(tag)
	_net_light = SpotLight3D.new()
	_net_light.light_color = Color(1.0, 0.95, 0.8)
	_net_light.light_energy = 2.0
	_net_light.spot_range = flashlight_range
	_net_light.spot_angle = 22.0
	_net_light.position = Vector3(-0.18, -0.12, -0.1)
	_net_light.visible = false
	head.add_child(_net_light)


func _puppet_process(delta: float) -> void:
	var main := get_parent().get_parent()
	var car := main.get_node_or_null(_net_vehicle) as VintageCar if _net_vehicle != "" else null
	vehicle = car
	var t := 1.0 - exp(-14.0 * delta)
	if car:
		global_transform = car.seat.global_transform
	elif global_position.distance_to(_net_pos) > 6.0:
		global_position = _net_pos
	else:
		global_position = global_position.lerp(_net_pos, t)
		rotation = Vector3(0, lerp_angle(rotation.y, _net_yaw, t), 0)
	head.rotation.x = lerpf(head.rotation.x, _net_pitch, t)
	_bob += delta * (2.0 + minf(Vector2(velocity.x, velocity.z).length() / walk_speed, 1.6) * 6.0)
	_footsteps()
	head.position.y = 1.0 if parkour.crouching else (0.65 if parkour.move == Parkour.Move.SLIDE else 1.6)
	_net_light.visible = _net_light_on and health > 0.0
	# Morto: corpo deitado no chão.
	var body := $Body as Node3D
	body.rotation.x = -PI / 2 if health <= 0.0 else 0.0
	body.position.y = 0.15 if health <= 0.0 else 0.0
	$CollisionShape3D.disabled = health <= 0.0 or car != null


## Arma/item na mão do boneco remoto (o mesmo modelo do chão).
func _set_held_item(id: StringName) -> void:
	if _net_held:
		_net_held.queue_free()
		_net_held = null
	if id == &"" or not ItemDB.has(id):
		return
	var hand := $Body/Skeleton3D.get_node_or_null(HumanoidRig.attachment_name("LowerArm.R")) as Node3D
	if hand == null:
		return
	_net_held = ItemDB.make_mesh(id)
	hand.add_child(_net_held)
	_net_held.position = Vector3(0, -0.3, 0)
	_net_held.rotation.x = -PI / 2 # a arma (montada em -Z) segue o antebraço
