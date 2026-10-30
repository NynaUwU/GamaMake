class_name HitInfo
extends RefCounted
## Tudo o que um golpe carrega: quanto dano, onde, de que direção, com que
## força e de que tipo. O tipo decide o que acontece com um membro que
## "morre": CUT arranca, BLUNT/PIERCE quebram (o membro fica mole).

enum Type { BLUNT, CUT, PIERCE }

var damage := 0.0
var bone: StringName
var point := Vector3.ZERO
var direction := Vector3.FORWARD
var force := 0.0
var type := Type.BLUNT
var knockdown := false ## golpe que desequilibra muito (chute)
var launch := 0.0 ## > 0: arremessa o zumbi longe (impulso total, N·s) — colherona
## Multiplicador de dano em membros por tipo: {"head": x, "arm": x, "leg": x}.
## Ex.: o golpe de cima da espada tem "arm" alto (arranca braços com facilidade).
var limb_bias := {}


static func make(damage_: float, bone_: StringName, point_: Vector3, direction_: Vector3,
		force_: float, type_ := Type.BLUNT) -> HitInfo:
	var hit := HitInfo.new()
	hit.damage = damage_
	hit.bone = bone_
	hit.point = point_
	hit.direction = direction_
	hit.force = force_
	hit.type = type_
	return hit


func bias_for(kind: String) -> float:
	return limb_bias.get(kind, 1.0)


## Para mandar pela rede (o host aplica golpes de outros jogadores).
func to_dict() -> Dictionary:
	return {"damage": damage, "bone": bone, "point": point, "direction": direction, "force": force,
		"type": type, "knockdown": knockdown, "launch": launch, "bias": limb_bias}


static func from_dict(d: Dictionary) -> HitInfo:
	var hit := make(d.damage, d.bone, d.point, d.direction, d.force, d.type)
	hit.knockdown = d.knockdown
	hit.launch = d.launch
	hit.limb_bias = d.bias
	return hit
