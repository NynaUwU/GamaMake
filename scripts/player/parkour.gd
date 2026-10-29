class_name Parkour
extends Node
## Movimentos especiais do player:
##   - agachar (C);
##   - deslizar: correndo + C. Passa por baixo dos zumbis e derruba quem estiver em cima;
##   - vault: correndo + pular de frente para algo na altura do quadril e curto
##     (barreira, capô de carro) -> passa por cima deslizando;
##   - subir: obstáculo baixo mas comprido, ou alto até um pouco acima da cabeça -> sobe em cima;
##   - pular cerca: obstáculo alto e fino -> escala e desce do outro lado.

enum Move { NONE, SLIDE, VAULT, MANTLE, CLIMB_OVER }

const MASK_WORLD := 1
const LAYER_ENEMY := 1 << 2

@export_group("Altura")
@export var stand_height := 1.8
@export var crouch_height := 1.15
@export var slide_height := 0.8
@export var stand_eye := 1.6
@export var crouch_eye := 1.0
@export var slide_eye := 0.65
@export var crouch_speed := 2.2

@export_group("Deslizar")
@export var slide_speed := 8.5
@export var slide_time := 0.85
@export var slide_trip_force := 45.0

@export_group("Obstáculos")
@export var min_height := 0.45 ## abaixo disso é só um degrau
@export var vault_max_height := 1.3 ## altura do quadril (+ capô de carro)
@export var vault_max_depth := 1.6 ## mais comprido que isso: sobe em cima em vez de passar
@export var climb_max_height := 2.3 ## um pouco acima da cabeça
@export var fence_max_depth := 0.6 ## cerca fina: escala e desce do outro lado
@export var reach := 1.1 ## distância máxima até o obstáculo

var crouching := false
var move := Move.NONE
var camera_roll := 0.0

var _player: CharacterBody3D
var _collision: CollisionShape3D
var _shape: CapsuleShape3D
var _eye := 1.6
var _t := 0.0
var _duration := 1.0
var _points: Array[Vector3] = []
var _slide_dir := Vector3.FORWARD
var _slide_time := 0.0
var _tripped: Array = []
var _mask_backup := 0


func setup(player: CharacterBody3D, collision: CollisionShape3D) -> void:
	_player = player
	_collision = collision
	_shape = collision.shape as CapsuleShape3D
	_eye = stand_eye


## Altura do olho (câmera) suavizada.
func eye_height(delta: float) -> float:
	var target := stand_eye
	if move == Move.SLIDE:
		target = slide_eye
	elif crouching:
		target = crouch_eye
	_eye = lerpf(_eye, target, 1.0 - exp(-14.0 * delta))
	return _eye


func speed_factor(walk_speed: float) -> float:
	return crouch_speed / walk_speed if crouching else 1.0


func is_busy() -> bool:
	return move != Move.NONE


# --- Agachar / deslizar --------------------------------------------------------

func on_crouch_pressed(sprinting: bool) -> void:
	if move != Move.NONE:
		return
	if sprinting and _player.is_on_floor():
		_start_slide()
	elif crouching:
		if _can_stand():
			crouching = false
			_set_height(stand_height)
	else:
		crouching = true
		_set_height(crouch_height)


func _start_slide() -> void:
	move = Move.SLIDE
	_slide_time = 0.0
	_tripped.clear()
	var flat := Vector3(_player.velocity.x, 0, _player.velocity.z)
	_slide_dir = flat.normalized() if flat.length() > 0.5 else -_player.global_basis.z
	_set_height(slide_height)
	# Passa por baixo dos zumbis: deixa de colidir com eles durante o deslize.
	_mask_backup = _player.collision_mask
	_player.collision_mask &= ~LAYER_ENEMY


func _update_slide(delta: float) -> void:
	_slide_time += delta
	var k := clampf(_slide_time / slide_time, 0.0, 1.0)
	var speed := lerpf(slide_speed, 2.0, k * k)
	_player.velocity.x = _slide_dir.x * speed
	_player.velocity.z = _slide_dir.z * speed
	if not _player.is_on_floor():
		_player.velocity.y -= 9.8 * delta
	_player.move_and_slide()
	camera_roll = -0.08
	_trip_zombies()
	if k >= 1.0:
		_end_slide()


## Quem estiver em cima do deslize perde as pernas e cai.
func _trip_zombies() -> void:
	for enemy in _player.get_tree().get_nodes_in_group("enemy"):
		if enemy in _tripped or not enemy.has_method("trip"):
			continue
		var flat: Vector3 = enemy.global_position - _player.global_position
		flat.y = 0.0
		if flat.length() < 0.85:
			_tripped.append(enemy)
			enemy.trip(_slide_dir, slide_trip_force)


func _end_slide() -> void:
	move = Move.NONE
	camera_roll = 0.0
	_player.collision_mask = _mask_backup
	if _can_stand():
		crouching = false
		_set_height(stand_height)
	else:
		crouching = true
		_set_height(crouch_height)


# --- Obstáculos ---------------------------------------------------------------

## Chamado ao apertar pular. Devolve true se começou um movimento (vault/subir/cerca).
func try_traverse(sprinting: bool) -> bool:
	if move != Move.NONE or crouching:
		return false
	var forward := -_player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var info := _probe(forward)
	if info.is_empty() or info.height < min_height or info.height > climb_max_height:
		return false
	var feet := _player.global_position
	var wall: Vector3 = info.wall
	var top_y: float = info.top_y
	var landing := _landing_point(wall + forward * (info.depth + 0.55), feet.y, top_y)
	var on_top := Vector3(wall.x, top_y, wall.z) + forward * minf(0.45, info.depth * 0.5)

	if info.height <= vault_max_height:
		if sprinting and info.depth <= vault_max_depth and landing != Vector3.INF:
			# Passa por cima deslizando (capô de carro / barreira).
			_begin(Move.VAULT, 0.45, [feet, Vector3(wall.x, top_y + 0.25, wall.z) + forward * info.depth * 0.5, landing])
			return true
		if _has_room(on_top):
			_begin(Move.MANTLE, 0.3 + info.height * 0.2, [feet, Vector3(wall.x, top_y + 0.1, wall.z) - forward * 0.15, on_top])
			return true
		return false
	if info.depth <= fence_max_depth and landing != Vector3.INF:
		# Cerca: sobe, passa por cima e desce do outro lado.
		var over := Vector3(wall.x, top_y + 0.2, wall.z)
		_begin(Move.CLIMB_OVER, 0.55 + info.height * 0.2,
				[feet, over - forward * 0.15, over + forward * (info.depth + 0.15), landing])
		return true
	if _has_room(on_top):
		_begin(Move.MANTLE, 0.35 + info.height * 0.25, [feet, Vector3(wall.x, top_y + 0.1, wall.z) - forward * 0.15, on_top])
		return true
	return false


func _begin(kind: Move, duration: float, points: Array) -> void:
	move = kind
	_t = 0.0
	_duration = duration
	_points.assign(points)
	_collision.disabled = true
	_player.velocity = Vector3.ZERO


func _update_traverse(delta: float) -> void:
	_t += delta / _duration
	var k := clampf(_t, 0.0, 1.0)
	if move == Move.VAULT:
		# Curva suave passando pelo ponto de cima (passa "deslizando").
		var a := _points[0]
		var apex := _points[1]
		var b := _points[2]
		var control := apex * 2.0 - (a + b) * 0.5
		_player.global_position = a.lerp(control, k).lerp(control.lerp(b, k), k)
		camera_roll = sin(k * PI) * 0.12
	else:
		# Trechos retos: sobe, depois anda por cima (e desce, na cerca).
		var segments := _points.size() - 1
		var f := k * segments
		var i := mini(int(f), segments - 1)
		_player.global_position = _points[i].lerp(_points[i + 1], smoothstep(0.0, 1.0, f - i))
		camera_roll = sin(k * PI) * 0.05
	if k >= 1.0:
		var keep_momentum := move == Move.VAULT
		move = Move.NONE
		camera_roll = 0.0
		_collision.disabled = false
		if keep_momentum:
			var forward := -_player.global_basis.z
			_player.velocity = Vector3(forward.x, 0, forward.z).normalized() * 5.5


## Roda no _physics_process do player. Devolve true quando o parkour controla o movimento.
func physics(delta: float) -> bool:
	match move:
		Move.SLIDE:
			_update_slide(delta)
			return true
		Move.VAULT, Move.MANTLE, Move.CLIMB_OVER:
			_update_traverse(delta)
			return true
	return false


## Procura obstáculo à frente: ponto da parede, altura do topo e profundidade.
func _probe(forward: Vector3) -> Dictionary:
	var feet := _player.global_position
	var wall_hit := {}
	for h in [0.4, 0.8, 1.3, 1.8]:
		wall_hit = _ray(feet + Vector3.UP * h, feet + Vector3.UP * h + forward * reach)
		if not wall_hit.is_empty():
			break
	if wall_hit.is_empty():
		return {}
	var wall: Vector3 = wall_hit.position
	var probe := wall + forward * 0.05 # dentro da parede (cerca fina tem ~12 cm)
	var top := _ray(Vector3(probe.x, feet.y + climb_max_height + 0.3, probe.z), Vector3(probe.x, feet.y - 0.1, probe.z))
	if top.is_empty():
		return {} # mais alto que o alcance
	var top_y: float = top.position.y
	# Profundidade: anda por cima até o topo acabar (ou cair).
	var depth := 3.0
	var d := 0.2
	while d < 3.0:
		var p := wall + forward * d
		var down := _ray(Vector3(p.x, top_y + 0.5, p.z), Vector3(p.x, feet.y - 0.1, p.z))
		if down.is_empty() or down.position.y < top_y - 0.3:
			depth = d
			break
		d += 0.15
	return {"wall": Vector3(wall.x, feet.y, wall.z), "top_y": top_y, "height": top_y - feet.y, "depth": depth}


## Chão do outro lado (Vector3.INF se não houver onde cair).
func _landing_point(around: Vector3, feet_y: float, top_y: float) -> Vector3:
	var down := _ray(Vector3(around.x, top_y + 0.5, around.z), Vector3(around.x, feet_y - 1.5, around.z))
	if down.is_empty() or down.position.y > top_y - 0.3:
		return Vector3.INF
	var landing: Vector3 = down.position
	return landing if _has_room(landing) else Vector3.INF


func _has_room(feet: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = _shape.radius * 0.9
	capsule.height = crouch_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis(), feet + Vector3.UP * (crouch_height * 0.5 + 0.05))
	query.collision_mask = MASK_WORLD
	query.exclude = [_player.get_rid()]
	return _player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _can_stand() -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = _shape.radius * 0.9
	capsule.height = stand_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis(), _player.global_position + Vector3.UP * (stand_height * 0.5 + 0.05))
	query.collision_mask = MASK_WORLD
	query.exclude = [_player.get_rid()]
	return _player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _set_height(height: float) -> void:
	_shape.height = height
	_collision.position.y = height * 0.5


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD, [_player.get_rid()])
	return _player.get_world_3d().direct_space_state.intersect_ray(query)
