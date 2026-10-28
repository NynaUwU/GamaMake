extends Node3D
## Cena principal: atalhos de teste (novo zumbi, recomeçar).

const ZOMBIE_SCENE := preload("res://scenes/zombie.tscn")

@onready var player: Player = $Player
@onready var enemies: Node3D = $Enemies


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("spawn_zombie"):
		_spawn_zombie_in_front()
	elif event.is_action_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()


func _spawn_zombie_in_front() -> void:
	var forward := -player.global_basis.z
	var zombie: Zombie = ZOMBIE_SCENE.instantiate()
	zombie.position = player.global_position + forward * 6.0
	zombie.target = player
	enemies.add_child(zombie)
