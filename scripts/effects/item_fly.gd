class_name ItemFly
extends Node3D
## Efeito: o item sai da máquina e voa até a câmera de quem pegou (o item de
## verdade já vai direto para a mochila; isto é só para ver de onde veio).

var _from := Vector3.ZERO
var _camera: Camera3D
var _t := 0.0


static func play(id: StringName, from: Vector3, player: Node) -> void:
	if player == null or not player.get("camera"):
		return
	var fx := ItemFly.new()
	fx._from = from
	fx._camera = player.camera
	fx.add_child(ItemModels.build(id))
	player.get_parent().add_child(fx)
	fx.global_position = from


func _process(delta: float) -> void:
	_t += delta / 0.4
	if _t >= 1.0 or not is_instance_valid(_camera):
		queue_free()
		return
	var to := _camera.global_position - _camera.global_basis.z * 0.4 - _camera.global_basis.y * 0.25
	var p := _from.lerp(to, _t * _t)
	p.y += sin(_t * PI) * 0.6 # arco
	global_position = p
	scale = Vector3.ONE * lerpf(1.0, 0.4, _t)
	rotate_y(delta * 8.0)
