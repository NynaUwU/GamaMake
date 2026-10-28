class_name ZombieLocomotion
extends Node
## Animação procedural do zumbi (andar arrastado, braços esticados, ataque,
## cambaleio). Faz o papel que um AnimationPlayer faria: escreve a pose base
## de cada frame. Com um modelo real, você pode trocar isto por animações.
##
## Pernas ficam firmes: o corpo se inclina e agacha dobrando os joelhos,
## e os pés só dão passos quando o zumbi se desloca (andando ou cambaleando).

const THIGH := 0.45
const SHIN := 0.47

@export var stride_frequency := 2.2
@export var stride_angle := 0.45
@export var knee_angle := 0.7
@export var hunch := 0.3

# Parâmetros controlados pelo Zombie ------------------------------------------
var speed := 0.0 ## velocidade de deslocamento (m/s)
var move_dir := Vector2(0, -1) ## direção do passo no espaço local (x = lado, y = frente(-)/trás(+))
var attack := 0.0 ## 0 = normal, 1 = braços erguidos no ataque
var swing := 0.0 ## 0..1 golpe do ataque descendo
var lean := Vector2.ZERO ## inclinação do tronco (rad) no espaço local: x = lado, y = frente(-)/trás(+)
var crouch := 0.0 ## quanto o quadril desce (m), dobrando os joelhos
var wobble := 0.0 ## 0..1 balanço de bêbado
var flail := 0.0 ## 0..1 braços abertos tentando se equilibrar
var buckle := Vector2.ZERO ## joelho cedendo: x = esquerdo, y = direito (0..1)

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

	# Balanço de bêbado: o tronco gira devagar em círculos.
	var sway := Vector2(sin(_time * 3.1), cos(_time * 2.3)) * 0.22 * wobble
	var tilt := lean + sway
	var dir := move_dir.normalized() if move_dir.length() > 0.01 else Vector2(0, -1)

	# Quadril: desce ao agachar (e quando um joelho cede), sobe e desce nos passos.
	var drop := crouch + (buckle.x + buckle.y) * 0.08 + absf(s) * 0.05 * move + 0.03
	var hips_rest := _skeleton.get_bone_rest(_b["Hips"]).origin
	_skeleton.set_bone_pose_position(_b["Hips"], hips_rest + Vector3(tilt.x * 0.06, -drop, tilt.y * 0.06))
	_set_rot("Hips", Vector3(0, s * 0.12 * move, s * 0.05 * move + _limp * 0.1))

	# Tronco: curvado para frente + inclinação (golpes/cambaleio). Rotação X positiva
	# joga o tronco para trás (+Z local); Z negativa joga para a direita (+X local).
	var spine_lean := Vector3(tilt.y, 0, -tilt.x)
	_set_rot("Spine", Vector3(-hunch * 0.5 - breathe, 0, -_limp * 0.1) + spine_lean * 0.5)
	_set_rot("Chest", Vector3(-hunch * 0.4 + attack * 0.25 - swing * 0.6, -s * 0.1 * move, 0) + spine_lean * 0.5)
	var head_wobble := Vector3(sin(_time * 4.0), sin(_time * 3.3), cos(_time * 3.7)) * 0.25 * wobble
	_set_rot("Head", Vector3(-0.25 + sin(_time * 0.9) * 0.1, sin(_time * 0.6) * 0.3, 0.2 + _limp)
			- spine_lean * 0.4 + head_wobble)

	# Pernas: agachar dobra os joelhos mantendo os pés no chão; os passos vão na
	# direção do deslocamento (para trás e para os lados quando cambaleia).
	for side in ["L", "R"]:
		var p := _phase if side == "L" else _phase + PI
		var step := sin(p) * stride_angle * move
		if side == "R":
			step *= 1.0 - _limp
		var knee_lift := maxf(0.0, cos(p)) * knee_angle * move
		var side_buckle := buckle.x if side == "L" else buckle.y
		var bend := _knee_bend_for_drop(drop) + side_buckle * 0.5
		# Passo: frente/trás em X, lateral em Z (sinais do espaço local do zumbi).
		var thigh := Vector3(-dir.y * step + bend + 0.05, 0, dir.x * step * 0.6)
		_set_rot("UpperLeg." + side, thigh)
		_set_rot("LowerLeg." + side, Vector3(-(bend * 2.0 + knee_lift + 0.05), 0, 0))

	# Braços: esticados para frente; no ataque sobem e descem; ao cambalear se abrem.
	for side in ["L", "R"]:
		var sign := -1.0 if side == "L" else 1.0
		var arm_sway := sin(_time * 2.0 + (0.0 if side == "L" else 1.3)) * 0.12
		var flap := sin(_time * 9.0 + (0.0 if side == "L" else 2.0)) * 0.35 * flail
		var reach := lerpf(1.15 + arm_sway + attack * 0.9 - swing * 1.6, 0.4 + flap, flail)
		var spread := sign * (0.12 + attack * 0.15 + flail * (1.0 + flap))
		_set_rot("UpperArm." + side, Vector3(reach, 0, spread))
		_set_rot("LowerArm." + side, Vector3(0.25 + attack * 0.3 + flail * 0.4, 0, 0))


## Ângulo de coxa para o quadril descer "drop" metros com os pés no lugar.
func _knee_bend_for_drop(drop: float) -> float:
	var leg := THIGH + SHIN
	return acos(clampf(1.0 - drop / leg, 0.0, 1.0))


func _set_rot(bone_name: String, euler: Vector3) -> void:
	_skeleton.set_bone_pose_rotation(_b[bone_name], Quaternion.from_euler(euler))
