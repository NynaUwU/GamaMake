class_name Creature
extends StaticBody3D
## Um bicho da água (Creatures). Nadadores (atum, peixe-baixo) passeiam no meio
## da água; os do fundo (camarão, lagosta, caranguejos) andam no chão e alguns
## caranguejos ficam na margem. Fogem de quem chega perto.
## Pegar: lança (estocada) pega qualquer um; os do fundo também dá para pegar
## com a mão ([E]). A IA roda no LakeLife (todos de uma vez).

var id: StringName
var swimmer := false
var target := Vector3.ZERO
var speed := 1.0
var think := 0.0
var bob := randf() * TAU
var life: LakeLife
var _model: Node3D


func setup(id_: StringName, life_: LakeLife) -> void:
	id = id_
	life = life_
	swimmer = id in Creatures.SWIMMERS
	# Camada "hitbox" (a lança acerta) e, no fundo, "interagível" ([E] pega).
	collision_layer = (1 << 4) | (0 if swimmer else 1 << 5)
	collision_mask = 0
	if not swimmer:
		add_to_group("interactable")
	_model = Creatures.node(id)
	add_child(_model)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = {&"atum": Vector3(0.3, 0.35, 0.95), &"baixo": Vector3(0.12, 0.32, 0.8), &"lagosta": Vector3(0.2, 0.1, 0.45),
		&"caranguejo_aranha": Vector3(0.5, 0.25, 0.5), &"caranguejo": Vector3(0.28, 0.1, 0.22)}.get(id, Vector3(0.15, 0.08, 0.15))
	shape.shape = box
	shape.position.y = box.size.y * 0.5 if not swimmer else 0.0
	add_child(shape)


func get_interact_text() -> String:
	return "[E] Pegar %s" % ItemDB.display_name(id)


func interact(player: Node) -> void:
	caught(player)


## Lança (Player._apply_swing_hit).
func tool_hit(player: Node, weapon_type: int, _damage: float, point: Vector3) -> void:
	if weapon_type == Player.WeaponType.SPEAR or not swimmer:
		ImpactFX.burst(get_parent(), point, Vector3.UP, Color(0.6, 0.15, 0.1), 8, 1.5, 0.03)
		caught(player)
	else:
		target = global_position + (global_position - player.global_position).normalized() * 6.0 # assustou
		speed = 2.8
		think = 2.0


func caught(player: Node) -> void:
	if is_queued_for_deletion():
		return
	var amount := randi_range(2, 4) if id == &"camarao" else 1
	if player.has_method("pick_up"):
		var left: int = player.pick_up(id, ItemDB.display_name(id), amount)
		if left > 0:
			Net.i.drop_item(id, left, player.global_transform.translated(Vector3.UP), Vector3.ZERO)
	Sfx.play_at("slap", global_position, 0.0, 0.8)
	if life:
		life.on_caught(self)
	queue_free()


func animate(delta: float, moving: bool) -> void:
	bob += delta * (9.0 if swimmer else 14.0) * (1.0 if moving else 0.3)
	if swimmer:
		_model.rotation.y = sin(bob) * 0.18 # rabo balançando
	else:
		_model.position.y = absf(sin(bob)) * 0.01 # passinhos
