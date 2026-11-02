class_name PowerSpin
extends Node
## Gira o nó "Spin" do objeto pai quando a rede tem força (extra.speed = 1), no
## sentido extra.dir; só no visual de cada jogador.

const RATE := 4.0 ## radianos por segundo a 100%
var axis := Vector3.RIGHT
var crank := false ## máquina de manivela (moinho, roca, tear): com força e trabalho, a manivela anda sozinha


func _process(delta: float) -> void:
	var obj := get_parent() as PlacedObject
	if obj == null:
		return
	if crank:
		if obj.extra.get("pstate", "") == "ok" and Power.busy(obj):
			Machines._spin(obj, delta) # mesmo movimento (e rangido) de quem gira na mão
		return
	var part := obj.get_node_or_null("Spin") as Node3D
	var speed: float = obj.extra.get("speed", 0.0)
	if part and speed > 0.0:
		# dir: engrenagens engatadas giram ao contrário uma da outra (Power.build).
		var dir: float = obj.extra.get("dir", 1)
		var rate := RATE * (0.5 if obj.kind == "windmill" else 1.0)
		part.rotate_object_local(axis, delta * rate * speed * dir)
