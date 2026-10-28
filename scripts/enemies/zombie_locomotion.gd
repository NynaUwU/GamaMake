class_name ZombieLocomotion
extends Node
## Animação procedural do zumbi (andar arrastado, braços esticados, ataque).
## Faz o papel que um AnimationPlayer faria: escreve a pose base de cada frame.
## Com um modelo real, você pode trocar isto por animações e manter o resto.

@export var stride_frequency := 2.2
@export var stride_angle := 0.45
@export var knee_angle := 0.7
@export var lean := 0.3

var speed := 0.0 ## velocidade atual (m/s), definida pelo Zombie
var attack := 0.0 ## 0 = normal, 1 = braços erguidos no ataque
var swing := 0.0 ## 0..1 golpe do ataque descendo

var _phase := 0.0
var _time := 0.0
var _limp := randf_range(0.0, 0.3) # cada zumbi manca um pouco diferente
var _skeleton: Skeleton3D
var _b := {}


func _ready() -> void:
	_skeleton = get_parent() as Skeleton3D
	for bone_name in ["Hips", "Spine", "Chest", "Head", "UpperArm.L", "LowerArm.L",
			"UpperArm.R", "LowerArm.R", "UpperLeg.L", "LowerLeg.L", "UpperLeg.R", "LowerLeg.R"]:
		_b[bone_name] = _skeleton.find_bone(bone_name)
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	var move := clampf(speed / 2.0, 0.0, 1.0)
	_phase += delta * stride_frequency * (0.4 + speed * 0.9) * TAU / 2.0
	var s := sin(_phase)
	var breathe := sin(_time * 1.7) * 0.03

	# Quadril: sobe e desce a cada passo e balança para os lados.
	var hips_rest := _skeleton.get_bone_rest(_b["Hips"]).origin
	_skeleton.set_bone_pose_position(_b["Hips"], hips_rest + Vector3(0, -absf(s) * 0.05 * move - 0.03, 0))
	_set_rot("Hips", Vector3(0, s * 0.12 * move, s * 0.06 * move + _limp * 0.1))

	# Tronco curvado para frente, cabeça pendendo.
	_set_rot("Spine", Vector3(-lean * 0.5 - breathe, 0, -_limp * 0.1))
	_set_rot("Chest", Vector3(-lean * 0.4 + attack * 0.25 - swing * 0.6, -s * 0.1 * move, 0))
	_set_rot("Head", Vector3(-0.25 + sin(_time * 0.9) * 0.1, sin(_time * 0.6) * 0.3, 0.2 + _limp))

	# Pernas: passada com joelho dobrando quando a perna volta.
	for side in ["L", "R"]:
		var p := _phase if side == "L" else _phase + PI
		var leg_swing := sin(p) * stride_angle * move
		var knee := maxf(0.0, cos(p)) * knee_angle * move + 0.1
		if side == "R":
			leg_swing *= 1.0 - _limp
		_set_rot("UpperLeg." + side, Vector3(leg_swing + 0.1, 0, 0))
		_set_rot("LowerLeg." + side, Vector3(-knee, 0, 0))

	# Braços: esticados para frente; no ataque sobem e descem com força.
	for side in ["L", "R"]:
		var sign := -1.0 if side == "L" else 1.0
		var sway := sin(_time * 2.0 + (0.0 if side == "L" else 1.3)) * 0.12
		var reach := 1.15 + sway + attack * 0.9 - swing * 1.6
		_set_rot("UpperArm." + side, Vector3(reach, 0, sign * (0.12 + attack * 0.15)))
		_set_rot("LowerArm." + side, Vector3(0.25 + attack * 0.3, 0, 0))


func _set_rot(bone_name: String, euler: Vector3) -> void:
	_skeleton.set_bone_pose_rotation(_b[bone_name], Quaternion.from_euler(euler))
