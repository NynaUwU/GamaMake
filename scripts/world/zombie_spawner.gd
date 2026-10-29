class_name ZombieSpawner
extends Node
## Mantém zumbis espalhados pelo mapa aberto em volta do player: nascem entre
## spawn_min e spawn_max metros (dentro da neblina, sem "pipocar" na frente) e
## somem quando ficam longe demais. No inverno aparecem mais.

const ZOMBIE_SCENE := preload("res://scenes/zombie.tscn")

@export var terrain_path: NodePath
@export var player_path: NodePath
@export var max_zombies := 14
@export var spawn_min := 45.0
@export var spawn_max := 110.0
@export var despawn_distance := 200.0
@export var check_interval := 1.0

var _terrain: TerrainWorld
var _player: Node3D
var _zombies: Array = []
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_terrain = get_node(terrain_path) as TerrainWorld
	_player = get_node(player_path) as Node3D
	_rng.seed = _terrain.seed + 77


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = check_interval
	var here := _player.global_position
	_zombies = _zombies.filter(func(z): return is_instance_valid(z))
	for z in _zombies.duplicate():
		if z.global_position.distance_to(here) > despawn_distance:
			_zombies.erase(z)
			z.queue_free()
	var biome := _terrain.biome_at(here.x, here.z)
	var wanted := int(max_zombies * (0.7 + biome.winter * 0.6))
	for i in 2: # no máximo 2 por checagem
		if _zombies.size() >= wanted:
			break
		_spawn_near(here)


func _spawn_near(center: Vector3) -> void:
	var angle := _rng.randf() * TAU
	var distance := _rng.randf_range(spawn_min, spawn_max)
	var x := center.x + cos(angle) * distance
	var z := center.z + sin(angle) * distance
	if Vector2(x, z).length() < _terrain.town_radius * 1.5:
		return # a cidade tem os zumbis dela
	var half := _terrain.world_size * 0.5 - 60.0
	if absf(x) > half or absf(z) > half:
		return
	var zombie: Zombie = ZOMBIE_SCENE.instantiate()
	zombie.position = Vector3(x, _terrain.height_at(x, z) + 0.3, z)
	zombie.rotation.y = _rng.randf() * TAU
	get_parent().add_child(zombie)
	_zombies.append(zombie)
