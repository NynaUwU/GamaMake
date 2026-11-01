class_name WorldFloor
extends Node
## Barreira do fundo do mundo (nó "WorldFloor" da cena principal). Ninguém some
## caindo pelo mapa: 4x por segundo confere quem passou do fundo (y < FLOOR_Y) ou
## atravessou o chão (mais de UNDER metros abaixo do terreno naquele ponto) e põe
## de volta EM CIMA da terra (ou da água), parado:
##   - o jogador daqui (cada um cuida do seu)
##   - host: zumbis de pé, bichos e itens no chão; carros simulados aqui
## Item que cai onde o terreno ainda não tem colisão (longe de todo mundo) fica
## congelado no lugar até o pedaço de chão aparecer.

const FLOOR_Y := -60.0 ## abaixo do fundo do mar mais fundo
const UNDER := 4.0 ## metros abaixo do terreno = atravessou o chão
const LIFT := 1.2

var rescued := 0 ## quantos já salvou (testes)
var _timer := 0.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	var world := get_parent()
	var terrain := world.get_node_or_null("Terrain") as TerrainWorld
	var player = world.get("player")
	if player is Node3D and player.get("vehicle") == null:
		_check_body(player, terrain)
	for item in get_tree().get_nodes_in_group("interactable"):
		if item is PickupItem:
			_check_item(item, terrain)
	if not Net.i.is_host():
		return
	for z in get_tree().get_nodes_in_group("enemy"):
		if z is Zombie and not z.puppet and z.state not in [Zombie.State.DOWN, Zombie.State.DEAD, Zombie.State.IMPALED, Zombie.State.CLIMB]:
			_check_body(z, terrain)
	var animals := world.get_node_or_null("Animals")
	if animals:
		for a in animals.get_children():
			if a is Animal and not a.puppet:
				_check_body(a, terrain)
	for car in get_tree().get_nodes_in_group("vehicle"):
		if car is VintageCar and not car._is_copy() and car.get_parent() == world:
			_check_car(car, terrain)


## Altura segura em cima do chão (ou da água) no ponto.
static func surface_at(terrain: TerrainWorld, x: float, z: float) -> float:
	var h := terrain.height_at(x, z) if terrain else 0.0
	if WaterManager.i:
		var depth := WaterManager.i.depth_at(Vector3(x, h, z))
		if depth > 0.0:
			h += depth # lago/rio/mar: volta boiando na superfície
	return h


static func fell(terrain: TerrainWorld, at: Vector3) -> bool:
	if at.y < FLOOR_Y:
		return true
	return terrain != null and at.y < terrain.height_at(at.x, at.z) - UNDER


func _check_body(body: Node3D, terrain: TerrainWorld) -> void:
	if not fell(terrain, body.global_position):
		return
	var p := body.global_position
	body.global_position = Vector3(p.x, surface_at(terrain, p.x, p.z) + LIFT, p.z)
	if body is CharacterBody3D:
		body.velocity = Vector3.ZERO
	rescued += 1


func _check_item(item: PickupItem, terrain: TerrainWorld) -> void:
	var p := item.global_position
	if item.has_meta("floor_frozen"):
		if _has_ground(terrain, p):
			item.remove_meta("floor_frozen")
			item.freeze = false
		return
	if not fell(terrain, p):
		return
	item.global_position = Vector3(p.x, surface_at(terrain, p.x, p.z) + 0.4, p.z)
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	if not _has_ground(terrain, p):
		item.freeze = true # chão ainda sem colisão aqui: espera parado
		item.set_meta("floor_frozen", true)
	rescued += 1


func _check_car(car: VintageCar, terrain: TerrainWorld) -> void:
	if not fell(terrain, car.global_position):
		return
	var p := car.global_position
	var forward := car.global_basis.z
	forward.y = 0.0
	var yaw := atan2(forward.x, forward.z) if forward.length() > 0.1 else 0.0
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, surface_at(terrain, p.x, p.z) + 1.5, p.z))
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	rescued += 1


## O pedaço de terreno (com colisão) já existe nesse ponto?
static func _has_ground(terrain: TerrainWorld, p: Vector3) -> bool:
	if terrain == null:
		return true
	var coord := Vector2i(floori(p.x / terrain.chunk_size), floori(p.z / terrain.chunk_size))
	return terrain._chunks.has(coord) and is_instance_valid(terrain._chunks[coord])
