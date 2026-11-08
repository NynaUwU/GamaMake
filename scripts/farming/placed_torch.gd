class_name PlacedTorch
extends RefCounted
## Tocha posta no chão (estaca) ou na parede (argola de ferro): clique com a tocha
## na mão mirando o chão ou uma parede. Continua queimando o que a tocha tinha
## (até 20 min) e apaga no fim. [E] reabastece: outra tocha da mochila (soma o que
## ela tinha) ou 1 pano + 1 graveto (+10 min). Desmontar (Shift + botão direito com
## o martelo) devolve a tocha com o que sobrou.

const KINDS := ["torch", "torch_wall"]
const BURN := 600.0 ## segundos de uma tocha nova (= durabilidade do item)
const MAX := 1200.0


static func has(kind: String) -> bool:
	return kind in KINDS


static func left(obj: PlacedObject, clock: float) -> float:
	return maxf(obj.extra.get("fuel_until", 0.0) - clock, 0.0)


static func build(kind: String, obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	var torch := ItemModels.build(&"tocha")
	var flame: Vector3
	if kind == "torch":
		# Estaca de ferro fincada com um anel segurando a tocha em pé.
		mb.color(ItemModels.IRON)
		mb.tube(PackedVector3Array([Vector3(0, -0.15, 0), Vector3(0, 0.55, 0)]), 0.014, 5)
		mb.torus(0.035, 0.008, 8, 4, Basis.IDENTITY, Vector3(0, 0.55, 0))
		mb.torus(0.03, 0.008, 8, 4, Basis.IDENTITY, Vector3(0, 0.36, 0))
		torch.position = Vector3(0, 0.38, 0)
		flame = Vector3(0, 0.64, 0)
		obj._shape(Vector3(0, 0.4, 0), Vector3(0.14, 0.8, 0.14))
	else:
		# Argola de parede: placa, braço e anel; a tocha sai inclinada para fora.
		mb.color(ItemModels.IRON)
		mb.box(Vector3(0, 0, 0.01), Vector3(0.08, 0.16, 0.02))
		mb.tube(PackedVector3Array([Vector3(0, -0.04, 0.02), Vector3(0, -0.02, 0.1)]), 0.01, 4)
		mb.torus(0.035, 0.008, 8, 4, Basis(Vector3.RIGHT, 0.35), Vector3(0, -0.02, 0.12))
		torch.position = Vector3(0, -0.2, 0.06)
		torch.rotation = Vector3(0.35, 0, 0)
		flame = Vector3(0, 0.07, 0.16)
		obj._shape(Vector3(0, -0.05, 0.1), Vector3(0.14, 0.35, 0.2))
	obj.add_child(torch)
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	StationModels._fire(obj, flame, 0.025, 0.42)
	for child in obj.get_children():
		if child is StationModels.Flicker:
			child.omni_range = 8.0 # ilumina como a tocha na mão
			child.base_energy = 1.4
			child.light_color = Color(1.0, 0.62, 0.3)
	StationModels.set_lit(obj, false)


static func text(obj: PlacedObject, clock: float) -> String:
	var secs := left(obj, clock)
	if secs <= 0.0:
		return "Tocha apagada  [E] reacender (outra tocha, ou 1 pano + 1 graveto)"
	var t := "Tocha: queimando · %d de %d min" % [ceili(secs / 60.0), int(MAX / 60.0)]
	if secs < MAX - 60.0:
		t += "  [E] pôr mais (tocha, ou pano + graveto)"
	return t


static func interact(player: Node, obj: PlacedObject) -> void:
	var manager := obj.get_parent() as PlacedManager
	var room := MAX - left(obj, manager.clock)
	if room < 30.0:
		Sfx.play("click", -6.0, 0.6)
		return
	var add := 0.0
	var index := Cooking.find_any(player.inventory, {&"tocha": true})
	if index >= 0:
		add = BURN * float(player.inventory.slots[index].get("dur", 1.0))
		player.inventory.take(index, 1)
	elif Builder.can_afford(player.inventory, {&"pano": 1, &"graveto": 1}):
		Builder.pay(player.inventory, {&"pano": 1, &"graveto": 1})
		add = BURN
	else:
		Sfx.play("click", -6.0, 0.6)
		return
	manager.request("fuel", [obj.net_id, minf(add, room), "fuel_until"])
	Sfx.play_at("whirr", obj.global_position + Vector3.UP * 0.4, -6.0, 1.6)


## Transform para pôr a tocha onde a mira bateu: chão (estaca em pé, virada para o
## jogador) ou parede (de frente para fora). {} se não dá.
static func spot(hit: Dictionary, yaw: float) -> Dictionary:
	if hit.is_empty():
		return {}
	var n: Vector3 = hit.normal
	if n.y > 0.6:
		return {"kind": "torch", "xform": Transform3D(Basis(Vector3.UP, yaw), hit.position)}
	if absf(n.y) < 0.35:
		var flat := Vector3(n.x, 0, n.z).normalized()
		return {"kind": "torch_wall", "xform": Transform3D(Basis.looking_at(-flat, Vector3.UP), hit.position + flat * 0.005)}
	return {}
