class_name PickupItem
extends RigidBody3D
## Item físico no chão que o player pode pegar com [E] (vai para o inventário).
## O modelo e a colisão vêm do ItemDB pelo item_id.

@export var item_id: StringName = &"sucata"
@export var display_name := "" ## vazio = nome do ItemDB
@export var amount := 1
## Nome do item na rede (igual em todos os jogadores) para todos verem quando
## alguém pega. Itens da fase usam o caminho na cena; frutas, o chunk.
var net_key := ""
var dur := 1.0 ## durabilidade (0..1) de arma/ferramenta/roupa gasta


func _ready() -> void:
	add_to_group("interactable")
	if net_key == "" and owner != null:
		net_key = "s:" + str(owner.get_path_to(self))
	Net.i.register_pickup(self)
	if display_name == "":
		display_name = ItemDB.display_name(item_id)
	if ItemDB.has(item_id):
		_build_from_db()


func _build_from_db() -> void:
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			child.queue_free()
	add_child(ItemDB.make_mesh(item_id))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ItemDB.def(item_id).size
	shape.shape = box
	shape.position = ItemDB.shape_center(item_id)
	add_child(shape)


func get_interact_text() -> String:
	return "[E] Pegar %s%s" % [display_name, " x%d" % amount if amount > 1 else ""]


func interact(_player: Node) -> void:
	Net.i.request_pickup(self) # online o host decide quem pegou primeiro


func _exit_tree() -> void:
	Net.i.unregister_pickup(self)


func take_locally(player: Node) -> void:
	if player == null or not player.has_method("pick_up"):
		return
	var left: int = player.pick_up(item_id, display_name, amount, dur)
	if left > 0:
		amount = left # não coube tudo: o resto fica no chão
		return
	# Sai da física na hora (o queue_free só remove no fim do frame).
	collision_layer = 0
	remove_from_group("interactable")
	queue_free()
