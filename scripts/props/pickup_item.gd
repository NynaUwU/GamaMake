class_name PickupItem
extends RigidBody3D
## Item físico no chão que o player pode pegar com [E].
## Por enquanto só avisa o player (sinal item_picked_up); quando o inventário
## existir, ele escuta esse sinal e guarda o item.

@export var item_id: StringName = &"sucata"
@export var display_name := "Sucata"
@export var amount := 1


func _ready() -> void:
	add_to_group("interactable")


func get_interact_text() -> String:
	return "[E] Pegar %s" % display_name


func interact(player: Node) -> void:
	if player.has_method("pick_up"):
		player.pick_up(item_id, display_name, amount)
	# Sai da física na hora (o queue_free só remove no fim do frame).
	collision_layer = 0
	remove_from_group("interactable")
	queue_free()
