class_name ElectricFence
extends Node3D
## Cerca elétrica: filho do PlacedObject "electric_fence". Ligada e com energia, o
## zumbi que encosta nos fios (até ~0,6 m da cerca) leva choque: dano, fica tonto
## um pouco e é jogado para trás, com faísca e estalo. Cada zumbi no máximo 1 choque
## por segundo. Roda só no host (os zumbis são dele); a faísca aparece para todos
## pelo som/efeito local de cada um (o host manda "zap").

const HALF := 1.25 ## meia largura (2,4 m + folga)
const REACH := 0.6
const DAMAGE := 16.0
const STUN := 1.2

var _tick := 0.0
var _cooldown := {} # zumbi -> hora do próximo choque


func _physics_process(delta: float) -> void:
	if not Net.i.is_host():
		return
	var obj := get_parent() as PlacedObject
	if obj == null or not Electric.powered(obj):
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.15
	var now := Time.get_ticks_msec() / 1000.0
	for zombie in get_tree().get_nodes_in_group("enemy"):
		if not zombie is Zombie or zombie.state == Zombie.State.DEAD:
			continue
		var local: Vector3 = obj.to_local(zombie.global_position)
		if absf(local.x) > HALF or absf(local.z) > REACH or local.y < -0.6 or local.y > 1.6:
			continue
		if _cooldown.get(zombie, 0.0) > now:
			continue
		_cooldown[zombie] = now + 1.0
		var away: Vector3 = obj.global_basis.z * signf(local.z if absf(local.z) > 0.01 else 1.0)
		var at: Vector3 = zombie.global_position + Vector3.UP * 1.0
		zombie.take_hit(HitInfo.make(DAMAGE, &"Spine", at, away, 9.0, HitInfo.Type.BLUNT))
		if zombie.state != Zombie.State.DEAD:
			zombie.stun(STUN)
		(obj.get_parent() as PlacedManager).request("zap", [obj.net_id, obj.to_local(at)])


## Faísca e estalo (todos os jogadores).
static func spark(obj: PlacedObject, local: Vector3) -> void:
	var at := obj.to_global(Vector3(clampf(local.x, -1.2, 1.2), clampf(local.y, 0.3, 1.2), 0.07))
	ImpactFX.burst(obj.get_parent(), at, obj.global_basis.z, Color(0.75, 0.85, 1.0), 14, 3.5, 0.03)
	Sfx.play_at("zap", at, 4.0, randf_range(0.9, 1.1))
