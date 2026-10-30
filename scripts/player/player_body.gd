class_name PlayerBody
extends Node
## Anima o corpo do player (visto ao olhar para baixo e na sombra):
## pernas andam/correm na direção do movimento, tronco inclina ao correr,
## braços seguram uma pose de "segurando arma" (aparecem só na sombra).

@export var player_path: NodePath = ^"../../.."

var _player: Player
var _skeleton: Skeleton3D
var _b := {}
var _phase := 0.0
var _move := Vector2.ZERO # suavizado, espaço local (x = lado, y = frente(-)/trás(+))
# Ação em andamento (golpe, soco, chute...): os outros jogadores veem pelo boneco.
var _action := ""
var _action_arg := 0
var _action_t := 1.0
var _action_len := 0.4
## Pose contínua dos braços: "aim" (pistola/cajado/gancho apontados), "block", "" (normal).
var hold := ""
var aim_pitch := 0.0 ## inclinação do olhar (rad, + = para cima) para apontar o braço

const ACTION_TIME := {"throw": 0.4, "swing": 0.42, "punch": 0.25, "kick": 0.4, "shoot": 0.18, "cast": 0.3, "tool": 0.35, "crank": 0.2}


## Toca uma ação no corpo (o Player chama quando chega pela rede).
func play(action: String, arg := 0) -> void:
	_action = action
	_action_arg = arg
	_action_t = 0.0
	_action_len = ACTION_TIME.get(action, 0.35)


func _ready() -> void:
	_skeleton = get_parent() as Skeleton3D
	_player = get_node(player_path) as Player
	for bone_name in ["Hips", "Spine", "Chest", "Head", "UpperArm.L", "LowerArm.L",
			"UpperArm.R", "LowerArm.R", "UpperLeg.L", "LowerLeg.L", "UpperLeg.R", "LowerLeg.R"]:
		_b[bone_name] = _skeleton.find_bone(bone_name)


func _process(delta: float) -> void:
	var local := _player.global_basis.inverse() * _player.velocity
	_move = _move.lerp(Vector2(local.x, local.z), 1.0 - exp(-10.0 * delta))
	var speed := _move.length()
	var amount := clampf(speed / 4.0, 0.0, 1.5)
	var airborne := not _player.grounded()
	# Ritmo limitado (não "pedala" voando de gancho ou caindo).
	_phase += delta * (2.0 + minf(speed, 6.5) * 2.2) if _player.grounded() else delta * 1.5
	var s := sin(_phase)
	var dir := _move.normalized() if speed > 0.1 else Vector2(0, -1)

	var hips_rest := _skeleton.get_bone_rest(_b["Hips"]).origin
	_skeleton.set_bone_pose_position(_b["Hips"], hips_rest + Vector3(0, -absf(s) * 0.04 * amount - 0.02, 0))
	_set_rot("Hips", Vector3(0, s * 0.1 * amount, 0))
	# Corre inclinado para frente (lean negativo em X).
	_set_rot("Spine", Vector3(-0.15 * amount, 0, 0))
	_set_rot("Chest", Vector3(-0.05 * amount, -s * 0.12 * amount, 0))
	_set_rot("Head", Vector3.ZERO)

	for side in ["L", "R"]:
		var p := _phase if side == "L" else _phase + PI
		var step := sin(p) * 0.6 * amount
		var knee := maxf(0.0, cos(p)) * 1.0 * amount + 0.05
		if airborne:
			step = 0.4 if side == "L" else -0.2
			knee = 0.9
		_set_rot("UpperLeg." + side, Vector3(-dir.y * step, 0, dir.x * step * 0.5))
		_set_rot("LowerLeg." + side, Vector3(-knee, 0, 0))

	# Agachado / deslizando: quadril desce e as pernas dobram (ou vão para frente).
	var parkour: Parkour = _player.get("parkour")
	if _player.get("vehicle"):
		# Sentado no carro: pernas esticadas para os pedais, mãos no volante.
		_skeleton.set_bone_pose_position(_b["Hips"], hips_rest + Vector3(0, -0.62, 0))
		_set_rot("Hips", Vector3.ZERO)
		_set_rot("Spine", Vector3(0.15, 0, 0))
		_set_rot("Chest", Vector3.ZERO)
		for side in ["L", "R"]:
			_set_rot("UpperLeg." + side, Vector3(1.45, 0, 0))
			_set_rot("LowerLeg." + side, Vector3(-0.6, 0, 0))
			_set_rot("UpperArm." + side, Vector3(1.0, 0, 0.15 if side == "R" else -0.15))
			_set_rot("LowerArm." + side, Vector3(0.6, 0, 0))
		return
	if parkour and parkour.move in [Parkour.Move.VAULT, Parkour.Move.MANTLE, Parkour.Move.CLIMB_OVER]:
		# Pernas encolhidas passando por cima (vault: de lado; subir: um joelho na frente).
		_skeleton.set_bone_pose_position(_b["Hips"], hips_rest + Vector3(0, -0.15, 0))
		var vault := parkour.move == Parkour.Move.VAULT
		_set_rot("UpperLeg.L", Vector3(1.3 if vault else 1.5, 0, 0.5 if vault else 0.0))
		_set_rot("LowerLeg.L", Vector3(-1.5, 0, 0))
		_set_rot("UpperLeg.R", Vector3(1.0 if vault else 0.3, 0, 0.5 if vault else 0.0))
		_set_rot("LowerLeg.R", Vector3(-1.2 if vault else -0.6, 0, 0))
		_set_rot("Spine", Vector3(-0.35, 0, 0))
	elif parkour and parkour.move == Parkour.Move.SLIDE:
		_skeleton.set_bone_pose_position(_b["Hips"], hips_rest + Vector3(0, -0.72, 0.1))
		_set_rot("Hips", Vector3(1.0, 0, 0))
		_set_rot("Spine", Vector3(-0.3, 0, 0))
		_set_rot("UpperLeg.L", Vector3(0.45, 0, 0))
		_set_rot("LowerLeg.L", Vector3(-0.1, 0, 0))
		_set_rot("UpperLeg.R", Vector3(0.9, 0, 0))
		_set_rot("LowerLeg.R", Vector3(-1.2, 0, 0))
	elif parkour and parkour.crouching:
		_skeleton.set_bone_pose_position(_b["Hips"], hips_rest + Vector3(0, -0.42, 0))
		_set_rot("Spine", Vector3(-0.35, 0, 0))
		for side in ["L", "R"]:
			var p := _phase if side == "L" else _phase + PI
			var step := sin(p) * 0.35 * amount
			_set_rot("UpperLeg." + side, Vector3(1.05 - dir.y * step, 0, 0))
			_set_rot("LowerLeg." + side, Vector3(-1.9 + maxf(0.0, cos(p)) * 0.3 * amount, 0, 0))

	# Braços (só sombra): direito estendido segurando a arma, esquerdo balançando.
	_set_rot("UpperArm.R", Vector3(1.1, 0, 0.1))
	_set_rot("LowerArm.R", Vector3(0.5, 0, 0))
	_set_rot("UpperArm.L", Vector3(-sin(_phase) * 0.5 * amount + 0.1, 0, -0.1))
	_set_rot("LowerArm.L", Vector3(0.4, 0, 0))
	match hold:
		"aim": # braço reto para onde está olhando
			_set_rot("UpperArm.R", Vector3(PI / 2 + aim_pitch, 0, 0.05))
			_set_rot("LowerArm.R", Vector3(0.05, 0, 0))
		"block": # arma atravessada na frente do peito
			_set_rot("UpperArm.R", Vector3(1.5, 0, 0.7))
			_set_rot("LowerArm.R", Vector3(1.3, 0, 0))
			_set_rot("UpperArm.L", Vector3(1.2, 0, -0.5))
			_set_rot("LowerArm.L", Vector3(1.0, 0, 0))
	_play_action(delta)


## Golpes por cima da pose: arcos parecidos com os da primeira pessoa.
func _play_action(delta: float) -> void:
	if _action == "" or _action_t >= 1.0:
		return
	_action_t = minf(_action_t + delta / _action_len, 1.0)
	var t := _action_t
	var windup := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.3, 0.55, t)) # recolhe antes
	var strike := smoothstep(0.3, 0.6, t) * (1.0 - smoothstep(0.75, 1.0, t)) # golpe e volta
	match _action:
		"swing":
			match _action_arg % 3:
				0: # da direita para a esquerda
					_set_rot("UpperArm.R", Vector3(1.4, 0, lerpf(0.1, -1.3, windup) + strike * 2.2))
					_set_rot("Chest", Vector3(0, -0.5 * windup + 0.6 * strike, 0))
				1: # da esquerda para a direita
					_set_rot("UpperArm.R", Vector3(1.4, 0, lerpf(0.1, 1.0, windup) - strike * 1.9))
					_set_rot("Chest", Vector3(0, 0.4 * windup - 0.6 * strike, 0))
				_: # de cima para baixo
					_set_rot("UpperArm.R", Vector3(lerpf(1.1, 3.0, windup) - strike * 2.2, 0, 0.1))
					_set_rot("Spine", Vector3(-0.1 - 0.35 * strike, 0, 0))
			_set_rot("LowerArm.R", Vector3(0.6 * windup + 0.1, 0, 0))
		"punch":
			var arm := "R" if _action_arg == 0 else "L"
			var jab := smoothstep(0.0, 0.4, t) * (1.0 - smoothstep(0.5, 1.0, t))
			_set_rot("UpperArm." + arm, Vector3(1.0 + jab * 0.6, 0, 0))
			_set_rot("LowerArm." + arm, Vector3(1.4 * (1.0 - jab), 0, 0))
			_set_rot("Chest", Vector3(0, (-0.35 if arm == "R" else 0.35) * jab, 0))
		"kick":
			var up := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(0.6, 1.0, t))
			_set_rot("UpperLeg.R", Vector3(1.5 * up, 0, 0))
			_set_rot("LowerLeg.R", Vector3(-0.3 * up, 0, 0))
			_set_rot("Spine", Vector3(0.25 * up, 0, 0))
		"shoot":
			_set_rot("UpperArm.R", Vector3(PI / 2 + aim_pitch + 0.35 * (1.0 - t), 0, 0.05))
		"cast":
			var thrust := sin(t * PI)
			_set_rot("UpperArm.R", Vector3(PI / 2 + aim_pitch + 0.2 * thrust, 0, 0.05))
			_set_rot("LowerArm.R", Vector3(0.6 * (1.0 - thrust), 0, 0))
		"throw": # arremesso por cima do ombro
			var back := 1.0 - smoothstep(0.25, 0.5, t)
			_set_rot("UpperArm.R", Vector3(lerpf(2.9, 1.0, smoothstep(0.25, 0.6, t)), 0, 0.2 * back))
			_set_rot("LowerArm.R", Vector3(1.2 * back, 0, 0))
			_set_rot("Chest", Vector3(0, -0.4 * back + 0.3 * strike, 0))
		"tool", "crank": # martelada / talhadeira / dínamo: antebraço sobe e desce
			_set_rot("UpperArm.R", Vector3(1.2 + windup * 0.9 - strike * 0.5, 0, 0.1))
			_set_rot("LowerArm.R", Vector3(1.4 * windup + 0.2, 0, 0))


func _set_rot(bone_name: String, euler: Vector3) -> void:
	_skeleton.set_bone_pose_rotation(_b[bone_name], Quaternion.from_euler(euler))
