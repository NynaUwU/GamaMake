class_name ResourceNode
extends StaticBody3D
## Árvore, rocha ou veio de minério do terreno que dá para derrubar/minerar.
## O desenho continua no MultiMesh do chunk (barato); este nó é só a colisão
## + a "vida". Machado derruba árvore (3 golpes), picareta quebra rocha/veio
## (4 golpes); outras armas quase não fazem efeito.
## Ao zerar: Net.loot_request (o host solta troncos/pedras/minério e marca a
## chave como usada: no save e para quem entrar depois, a árvore não volta).

const TREES := ["tree", "crooked_tree", "fruit_tree", "pine"]
const STONES := ["rock", "ore_iron", "ore_copper", "ore_coal"]
const TABLE := {"tree": "arvore", "crooked_tree": "arvore", "fruit_tree": "arvore_fruta", "pine": "arvore",
	"rock": "rocha", "ore_iron": "ferro", "ore_copper": "cobre", "ore_coal": "carvao"}
const HP := {"tree": 90.0, "crooked_tree": 70.0, "fruit_tree": 60.0, "pine": 80.0,
	"rock": 100.0, "ore_iron": 110.0, "ore_copper": 110.0, "ore_coal": 100.0}
const NAMES := {"rock": "Rocha", "ore_iron": "Veio de ferro", "ore_copper": "Veio de cobre", "ore_coal": "Veio de carvão"}

var key := ""
var kind := "tree"
var hp := 100.0
var multimesh: MultiMesh
var index := 0
var _warned := false
var _done := false


func setup(key_: String, kind_: String, mm: MultiMesh, index_: int, scale: float) -> void:
	key = key_
	kind = kind_
	multimesh = mm
	index = index_
	hp = HP.get(kind, 100.0)
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	if kind in TREES:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.24 * scale
		cylinder.height = 2.4 * scale
		shape.shape = cylinder
		shape.position = Vector3.UP * cylinder.height * 0.5
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 1.0, 1.6) * scale
		shape.shape = box
		shape.position = Vector3.UP * 0.4 * scale
	add_child(shape)
	Net.i.looted.connect(_on_looted)


func is_tree() -> bool:
	return kind in TREES


## Golpe corpo a corpo (Player._apply_swing_hit).
func tool_hit(player: Node, weapon_type: int, damage: float, point: Vector3) -> void:
	if _done:
		return
	var right_tool: bool = weapon_type == (Player.WeaponType.AXE if is_tree() else Player.WeaponType.PICKAXE)
	hp -= damage * (1.0 if right_tool else 0.2)
	var color := Color(0.5, 0.35, 0.2) if is_tree() else Color(0.55, 0.53, 0.5)
	ImpactFX.burst(get_parent(), point, (player.global_position - point).normalized(), color, 10, 2.5, 0.05)
	Sfx.play_at("knock" if is_tree() else "ping", point, 3.0, 0.6 if is_tree() else 0.5)
	if not right_tool and not _warned and player.has_signal("notify"):
		_warned = true
		pass # ferramenta errada: só o som "seco" do golpe
	if hp <= 0.0:
		_done = true
		# Cai sempre para o mesmo lado em todos os jogadores (sorteado pela chave).
		var fall := _fall_direction()
		var where := Transform3D(Basis.looking_at(fall), global_position + fall * (2.2 if is_tree() else 0.0) + Vector3.UP * 0.4)
		Net.i.loot_request(key, where, TABLE.get(kind, "rocha"))


func _fall_direction() -> Vector3:
	var a := float(hash(key) % 628) / 100.0
	return Vector3(cos(a), 0, sin(a))


func _on_looted(k: String) -> void:
	if k == key:
		gone(true)


## Some (derrubada/quebrada). animate = cai/esfarela; senão já some (save).
func gone(animate: bool) -> void:
	_done = true
	var xform := multimesh.get_instance_transform(index) if multimesh else Transform3D()
	if multimesh:
		multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), xform.origin))
	if not animate or not is_inside_tree():
		queue_free()
		return
	collision_layer = 0
	if is_tree():
		Sfx.play_at("creak", global_position + Vector3.UP * 2.0, 4.0, 0.6)
		_falling_tree(xform)
		# Frutas presas nos galhos caem junto.
		for child in get_parent().get_children():
			if child is PickupItem and child.freeze and child.global_position.distance_to(global_position) < 3.5:
				child.freeze = false
	else:
		Sfx.play_at("crunch", global_position + Vector3.UP * 0.5, 6.0, 0.5)
		ImpactFX.burst(get_parent(), global_position + Vector3.UP * 0.6, Vector3.UP, Color(0.5, 0.48, 0.45), 30, 4.0, 0.08)
		queue_free()


## Cópia da árvore que tomba (gira na base) e depois some no chão.
func _falling_tree(xform: Transform3D) -> void:
	var pivot := Node3D.new()
	get_parent().add_child(pivot)
	pivot.position = xform.origin
	var mesh := MeshInstance3D.new()
	mesh.mesh = TerrainProps._mesh(kind)
	mesh.basis = xform.basis
	pivot.add_child(mesh)
	var fall := _fall_direction()
	var axis := Vector3.UP.cross(fall).normalized()
	var tween := pivot.create_tween()
	tween.tween_property(pivot, "basis", Basis(axis, PI * 0.48), 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): Sfx.play_at("thud", pivot.global_position + fall * 3.0, 6.0, 0.5))
	tween.tween_interval(2.5)
	tween.tween_property(pivot, "position", pivot.position + Vector3.DOWN * 1.5, 1.5)
	tween.tween_callback(pivot.queue_free)
	queue_free()
