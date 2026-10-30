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


func _set_rot(bone_name: String, euler: Vector3) -> void:
	_skeleton.set_bone_pose_rotation(_b[bone_name], Quaternion.from_euler(euler))
