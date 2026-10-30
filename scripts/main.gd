extends Node3D
## Cena principal: atalhos de teste (novo zumbi, recomeçar).

const ZOMBIE_SCENE := preload("res://scenes/zombie.tscn")

@onready var player: Player = $Player
@onready var enemies: Node3D = $Enemies


func _ready() -> void:
	var pause := PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	# O CSG monta a geometria só depois do primeiro frame: espera para gerar a navegação.
	await get_tree().process_frame
	await get_tree().physics_frame
	_bake_navigation()


## Gera o NavigationMesh a partir da fase (CSG do nó Level) para os zumbis
## contornarem obstáculos. Mudou a fase? É recalculado sozinho ao iniciar.
func _bake_navigation() -> void:
	var level := $Level
	level.add_to_group("navigation_source")
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.5 # múltiplos de cell_size/cell_height (evita aviso de precisão)
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = &"navigation_source"
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = mesh
	add_child(region)
	region.bake_navigation_mesh(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("spawn_zombie"):
		_spawn_zombie_in_front()
	elif event.is_action_pressed("spawn_horde"):
		_spawn_horde(100)
	elif event.is_action_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()


## Teste: muitos zumbis em volta do player (anel de 12 a 45 m).
func _spawn_horde(count: int) -> void:
	var terrain := get_node_or_null("Terrain") as TerrainWorld
	for i in count:
		var a := randf() * TAU
		var r := randf_range(12.0, 45.0)
		var pos := player.global_position + Vector3(cos(a) * r, 0, sin(a) * r)
		if terrain:
			pos.y = terrain.height_at(pos.x, pos.z) + 0.3
		var zombie: Zombie = ZOMBIE_SCENE.instantiate()
		zombie.position = pos
		zombie.target = player
		enemies.add_child(zombie)


func _spawn_zombie_in_front() -> void:
	var forward := -player.global_basis.z
	var zombie: Zombie = ZOMBIE_SCENE.instantiate()
	zombie.position = player.global_position + forward * 6.0
	zombie.target = player
	enemies.add_child(zombie)
