class_name Trap
extends Node3D
## Armadilha colocada pelo martelo (aba Armadilhas). Filho de um PlacedObject.
##   spikes    estacas: machuca a perna de quem passa por cima (30 usos)
##   beartrap  armadilha de urso: prende o primeiro zumbi (atordoa e quebra a
##             perna). Depois fica fechada: [E] arma de novo.
##   barbed    cerca de espinhos: bloqueia; zumbi que bate nela se machuca;
##             aguenta 12 golpes
##   mine      mina de pressão: explode quando um zumbi chega perto (uma vez)
## A lógica roda só no host (os zumbis são dele); o estado vai em obj.extra.

const RADIUS := {"spikes": 0.75, "beartrap": 0.45, "barbed": 0.0, "mine": 1.3}
const START := {"spikes": {"uses": 30}, "beartrap": {"armed": true}, "barbed": {"hp": 12}, "mine": {}}

var obj: PlacedObject
var kind := "spikes"
var _tick := 0.0
var _jaws: Array[Node3D] = []
var _cooldown := {} # zumbi -> tempo até levar dano de novo (estacas)


func setup(obj_: PlacedObject) -> void:
	obj = obj_
	kind = obj.kind
	for k in START[kind]:
		if not obj.extra.has(k):
			obj.extra[k] = START[kind][k]
	_build()
	refresh()


func refresh() -> void:
	if kind == "beartrap":
		var armed: bool = obj.extra.get("armed", true)
		for i in _jaws.size():
			_jaws[i].rotation.x = (1.0 if i == 0 else -1.0) * (1.45 if armed else 0.05)


func get_text() -> String:
	match kind:
		"spikes":
			return "Estacas (%d usos)" % obj.extra.uses
		"beartrap":
			return "Armadilha de urso armada" if obj.extra.armed else "[E] Armar a armadilha de urso"
		"barbed":
			return "Cerca de espinhos (%d/12)" % obj.extra.hp
		"mine":
			return "Mina armada - zumbis explodem aqui"
	return ""


func interact(_player: Node) -> void:
	if kind == "beartrap" and not obj.extra.armed:
		_manager().request("extra", [obj.net_id, {"armed": true}])
		Sfx.play_at("click", global_position, 6.0, 0.7)


func _manager() -> PlacedManager:
	return obj.get_parent() as PlacedManager


func _physics_process(delta: float) -> void:
	if not Net.i.is_host() or RADIUS[kind] <= 0.0:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.15
	for zombie in get_tree().get_nodes_in_group("enemy"):
		if not zombie is Zombie or zombie.state == Zombie.State.DEAD:
			continue
		var to: Vector3 = zombie.global_position - global_position
		if absf(to.y) > 1.0 or Vector2(to.x, to.z).length() > RADIUS[kind]:
			continue
		_trigger(zombie)
		if kind != "spikes":
			return


func _trigger(zombie: Zombie) -> void:
	match kind:
		"spikes":
			var now := Time.get_ticks_msec() / 1000.0
			if _cooldown.get(zombie, 0.0) > now:
				return
			_cooldown[zombie] = now + 0.6
			var bone := &"LowerLeg.L" if randf() < 0.5 else &"LowerLeg.R"
			zombie.take_hit(HitInfo.make(9.0, bone, zombie.global_position + Vector3.UP * 0.3, Vector3.UP, 6.0, HitInfo.Type.CUT))
			obj.extra.uses -= 1
			if obj.extra.uses <= 0:
				_manager().request("remove", [obj.net_id])
		"beartrap":
			if not obj.extra.armed:
				return
			zombie.take_hit(HitInfo.make(45.0, &"LowerLeg.R", zombie.global_position + Vector3.UP * 0.25, Vector3.DOWN, 2.0, HitInfo.Type.BLUNT))
			if zombie.state != Zombie.State.DEAD:
				zombie.stun(5.0)
			Sfx.play_at("slap", global_position, 8.0, 0.5)
			Sfx.play_at("knock", global_position, 6.0, 1.4)
			_manager().request("extra", [obj.net_id, {"armed": false}])
		"mine":
			_manager().request("explode", [obj.net_id])


## Zumbi bateu na cerca (Zombie._damage_wall): perde vida e espeta o zumbi.
func hit_by(zombie: Zombie) -> void:
	if kind != "barbed":
		return
	zombie.take_hit(HitInfo.make(10.0, &"LowerArm.R", zombie.global_position + Vector3.UP * 1.2, zombie.global_basis.z, 4.0, HitInfo.Type.CUT))
	Sfx.play_at("knock", global_position + Vector3.UP * 0.6, 3.0, 0.9)
	var hp: int = obj.extra.hp - 1
	if hp <= 0:
		_manager().request("remove", [obj.net_id])
	else:
		_manager().request("extra", [obj.net_id, {"hp": hp}])


# --- Modelos ---------------------------------------------------------------------

func _build() -> void:
	var mb := MeshBuilder.new()
	var wood := Color(0.4, 0.27, 0.15)
	var iron := Color(0.3, 0.27, 0.25)
	match kind:
		"spikes":
			mb.color(wood.darkened(0.15))
			for z in [-0.5, 0.5]:
				mb.box(Vector3(0, 0.05, z), Vector3(1.2, 0.1, 0.1))
			for x in [-0.5, 0.5]:
				mb.box(Vector3(x, 0.05, 0), Vector3(0.1, 0.1, 1.0))
			for i in 4:
				for j in 4:
					var p := Vector3(-0.42 + i * 0.28, 0.05, -0.42 + j * 0.28)
					var lean := Vector3(0.12 * ((i + j) % 3 - 1), 0.32, 0.12 * ((i * 2 + j) % 3 - 1))
					mb.color(wood)
					mb.tube(PackedVector3Array([p, p + lean * 0.75]), 0.03, 4)
					mb.color(Color(0.75, 0.62, 0.45)) # ponta afiada (madeira clara)
					mb.tube(PackedVector3Array([p + lean * 0.75, p + lean]), 0.015, 4)
			obj._shape(Vector3(0, 0.05, 0), Vector3(1.2, 0.1, 1.2))
		"beartrap":
			mb.color(iron)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.26, 0.0), Vector2(0.26, 0.03), Vector2(0.002, 0.04)]), 10)
			mb.color(Color(0.55, 0.45, 0.3))
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.04), Vector2(0.08, 0.04), Vector2(0.08, 0.06), Vector2(0.002, 0.06)]), 8) # gatilho
			mb.color(iron.darkened(0.2))
			mb.tube(PackedVector3Array([Vector3(0.26, 0.02, 0), Vector3(0.5, 0.01, 0.1)]), 0.012, 4) # corrente
			for side in [-1.0, 1.0]:
				var pivot := Node3D.new()
				pivot.position = Vector3(0, 0.04, 0)
				add_child(pivot)
				var jaw := MeshBuilder.new()
				jaw.color(iron.lightened(0.1))
				for k in 7:
					var a := PI * k / 6.0
					var p := Vector3(cos(a) * 0.24, sin(a) * 0.24 * 0.9, 0) # meia-lua em pé
					jaw.box(p, Vector3(0.05, 0.03, 0.02), Basis(Vector3.BACK, a))
					jaw.box(p * 0.86, Vector3(0.015, 0.05, 0.015), Basis(Vector3.BACK, a)) # dente
				var jaw_mesh := MeshInstance3D.new()
				jaw_mesh.mesh = jaw.finish(PlacedObject._mat(), false)
				jaw_mesh.rotation.y = PI / 2 if side > 0 else -PI / 2
				pivot.add_child(jaw_mesh)
				_jaws.append(pivot)
			obj._shape(Vector3(0, 0.03, 0), Vector3(0.55, 0.06, 0.55))
		"barbed":
			mb.color(wood.darkened(0.1))
			for x in [-1.1, 1.1]:
				mb.box(Vector3(x, 0.55, 0), Vector3(0.12, 1.1, 0.12))
			mb.color(wood)
			for y in [0.3, 0.65, 1.0]:
				mb.box(Vector3(0, y, 0), Vector3(2.3, 0.12, 0.05))
			mb.color(iron)
			for y in [0.47, 0.82]:
				mb.box(Vector3(0, y, 0.04), Vector3(2.2, 0.012, 0.012))
				for k in 14:
					var x := -1.05 + k * 0.16
					mb.box(Vector3(x, y, 0.04), Vector3(0.012, 0.07, 0.012), Basis(Vector3.BACK, 0.7 * (1 if k % 2 == 0 else -1)))
					mb.box(Vector3(x, y, 0.04), Vector3(0.012, 0.012, 0.09))
			obj._shape(Vector3(0, 0.55, 0), Vector3(2.4, 1.1, 0.3))
		"mine":
			mb.color(Color(0.36, 0.32, 0.22))
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.17, 0.0), Vector2(0.18, 0.04), Vector2(0.14, 0.07), Vector2(0.002, 0.075)]), 10)
			mb.color(ItemModels.BRASS)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.075), Vector2(0.035, 0.075), Vector2(0.03, 0.1), Vector2(0.002, 0.1)]), 8)
			mb.color(Color(0.6, 0.1, 0.06))
			mb.box(Vector3(0.12, 0.05, 0), Vector3(0.04, 0.02, 0.04)) # luzinha
			obj._shape(Vector3(0, 0.04, 0), Vector3(0.36, 0.08, 0.36))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	add_child(mesh)
