class_name WorldFloor
extends Node
## Barreira do fundo do mundo (nó "WorldFloor" da cena principal). Ninguém some
## caindo pelo mapa: 4x por segundo confere quem passou do fundo (y < FLOOR_Y) ou
## atravessou o chão (mais de UNDER metros abaixo do terreno naquele ponto) e põe
## de volta EM CIMA da terra (ou da água), parado:
##   - o jogador daqui (cada um cuida do seu)
##   - host: zumbis de pé, bichos e carros simulados aqui
##   - itens no chão (cada jogador os seus)
## Barato: só olha a altura do terreno de quem está CAINDO (velocidade para baixo);
## parado/andando no chão é só uma leitura de velocidade.
## Itens: só os que se mexem ficam na lista (PickupItem se registra ao nascer).
## Parado por STILL_TIME segundos, o item vira estático (congelado, fora da física)
## e sai da lista. Item que cai onde o terreno ainda não tem colisão (longe de todo
## mundo) fica congelado até o pedaço de chão aparecer.

const FLOOR_Y := -66.0 ## abaixo da rocha-mãe (61 m abaixo do mar) e do fundo do mar
const UNDER := 4.0 ## metros abaixo do terreno = atravessou o chão
const LIFT := 1.2
const STILL_TIME := 15.0 ## parado esse tempo: o item vira estático
const STILL_SPEED := 0.08
const FALL_SPEED := -2.5 ## caindo mais rápido que isso: vale conferir a altura do terreno

static var i: WorldFloor

var rescued := 0 ## quantos já salvou (testes)
var _timer := 0.0
var _items := {} ## PickupItem se mexendo -> segundos parado
var _waiting := {} ## PickupItem congelado esperando o chão (colisão) aparecer
var _keys: Array = [] # volta atual pela lista de itens (um pedaço por quadro: sem picos)
var _cursor := 0
var _terrain: TerrainWorld
const SLICES := 15 ## cada item é visto a cada 15 quadros (~0,25 s)


func _enter_tree() -> void:
	i = self


func _exit_tree() -> void:
	if i == self:
		i = null


## Item novo (nasceu, caiu de um bicho, foi largado): entra na lista dos que se mexem.
static func track(item: PickupItem) -> void:
	if i:
		i._items[item] = 0.0


func tracked_count() -> int:
	return _items.size()


func _physics_process(delta: float) -> void:
	var world := get_parent()
	if _terrain == null:
		_terrain = world.get_node_or_null("Terrain") as TerrainWorld
	_item_slice(_terrain)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	var terrain := _terrain
	var player = world.get("player")
	if player is Node3D and player.get("vehicle") == null:
		_check_body(player, terrain)
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
	# Área de voxels: abaixo do chão é normal (caverna, buraco cavado); só conta se ficou
	# dentro de bloco cheio.
	if VoxelWorld.i and VoxelWorld.i.covers(at):
		return VoxelWorld.i.solid_at(at + Vector3.UP * 0.5) == 1
	return terrain != null and at.y < terrain.height_at(at.x, at.z) - UNDER


func _check_body(body: Node3D, terrain: TerrainWorld) -> void:
	var p0 := body.global_position
	var falling: bool = body is CharacterBody3D and body.velocity.y < FALL_SPEED
	if p0.y >= FLOOR_Y and not falling:
		return # em pé/andando no chão: nem calcula a altura do terreno
	if not fell(terrain, p0):
		return
	var p := body.global_position
	body.global_position = Vector3(p.x, surface_at(terrain, p.x, p.z) + LIFT, p.z)
	if body is CharacterBody3D:
		body.velocity = Vector3.ZERO
	rescued += 1


## Um pedaço da lista de itens por quadro (1/SLICES): mil itens caindo juntos não
## travam o quadro. Ao fim de cada volta confere os que esperam o chão aparecer.
func _item_slice(terrain: TerrainWorld) -> void:
	if _cursor >= _keys.size():
		_keys = _items.keys()
		_cursor = 0
		_check_waiting(terrain)
		if _keys.is_empty():
			return
	var count := ceili(_keys.size() / float(SLICES))
	for k in count:
		if _cursor >= _keys.size():
			break
		_check_item(_keys[_cursor], terrain)
		_cursor += 1


func _check_item(item, terrain: TerrainWorld) -> void:
	if not _items.has(item):
		return
	if not is_instance_valid(item) or item.is_queued_for_deletion() or not item.is_inside_tree() or item.freeze:
		_items.erase(item)
		return
	var velocity: Vector3 = item.linear_velocity
	var p: Vector3 = item.global_position
	if p.y < FLOOR_Y or (velocity.y < FALL_SPEED and fell(terrain, p)):
		_rescue_item(item, terrain)
		return
	if velocity.length() < STILL_SPEED:
		_items[item] += 0.25
		if _items[item] >= STILL_TIME:
			item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			item.freeze = true # parado: vira estático e sai da lista
			_items.erase(item)
	else:
		_items[item] = 0.0


func _check_waiting(terrain: TerrainWorld) -> void:
	for item in _waiting.keys():
		if not is_instance_valid(item) or item.is_queued_for_deletion():
			_waiting.erase(item)
		elif _has_ground(terrain, item.global_position):
			_waiting.erase(item)
			item.freeze = false
			_items[item] = 0.0


func _rescue_item(item: PickupItem, terrain: TerrainWorld) -> void:
	var p := item.global_position
	item.global_position = Vector3(p.x, surface_at(terrain, p.x, p.z) + 0.4, p.z)
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	if not _has_ground(terrain, p):
		item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		item.freeze = true # chão ainda sem colisão aqui: espera parado
		_items.erase(item)
		_waiting[item] = true
	rescued += 1


func _check_car(car: VintageCar, terrain: TerrainWorld) -> void:
	if car.global_position.y >= FLOOR_Y and car.linear_velocity.y > FALL_SPEED:
		return
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
