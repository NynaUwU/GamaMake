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
@export var slide_steer := 1.4 ## rad/s: o deslize curva de leve para onde o mouse aponta
@export var slide_friction := 2.4 ## m/s² de atrito no plano
@export var slide_max_speed := 15.0

@export_group("Obstáculos")
@export var min_height := 0.45 ## abaixo disso é só um degrau
@export var vault_max_height := 1.3 ## altura do quadril (+ capô de carro)
@export var vault_max_depth := 4.0 ## até isso passa deslizando por cima (capô, mesa comprida); mais: sobe em cima
@export var climb_max_height := 2.3 ## um pouco acima da cabeça
@export var fence_max_depth := 0.6 ## cerca fina: escala e desce do outro lado
@export var reach := 1.1 ## distância máxima até o obstáculo

var crouching := false
var move := Move.NONE
var camera_roll := 0.0
## Animação (lidas pelo Player): inclinação extra da câmera, mergulho da cabeça
## e mãos apoiadas no obstáculo (pontos no mundo; INF = mão livre).
var camera_pitch := 0.0
var camera_dip := 0.0
var hand_targets: Array[Vector3] = [Vector3.INF, Vector3.INF] # esquerda, direita
var hand_weight := 0.0
var _dip_velocity := 0.0
var _entry_speed := 0.0

var _player: CharacterBody3D
var _collision: CollisionShape3D
var _shape: CapsuleShape3D
var _eye := 1.6
var _t := 0.0
var _duration := 1.0
var _points: Array[Vector3] = []
var _slide_dir := Vector3.FORWARD
var _slide_time := 0.0
var _slide_speed := 0.0
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
	# Mola do "mergulho" (aterrissagem, fim de vault): desce e volta.
	# Passos pequenos: um frame lento (carregamento) não pode fazer a mola explodir.
	var remaining := minf(delta, 0.1)
	while remaining > 0.0:
		var dt := minf(remaining, 1.0 / 120.0)
		_dip_velocity += (-camera_dip * 140.0 - _dip_velocity * 14.0) * dt
		camera_dip += _dip_velocity * dt
		remaining -= dt
	camera_dip = clampf(camera_dip, -0.6, 0.3)
	if move == Move.NONE:
		camera_pitch = lerpf(camera_pitch, 0.0, 1.0 - exp(-10.0 * delta))
		hand_weight = move_toward(hand_weight, 0.0, delta * 6.0)
	return _eye + camera_dip


## Impacto na cabeça ao aterrissar (strength ~ velocidade da queda em m/s).
func land(strength: float) -> void:
	_dip_velocity -= clampf(strength, 0.0, 12.0) * 0.45 # pesado: a cabeça afunda mais


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
	_slide_speed = slide_speed
	_tripped.clear()
	var flat := Vector3(_player.velocity.x, 0, _player.velocity.z)
	_slide_dir = flat.normalized() if flat.length() > 0.5 else -_player.global_basis.z
	_set_height(slide_height)
	# Passa por baixo dos zumbis: deixa de colidir com eles durante o deslize.
	_mask_backup = _player.collision_mask
	_player.collision_mask &= ~LAYER_ENEMY


func _update_slide(delta: float) -> void:
	_slide_time += delta
	# O mouse curva o deslize de leve: a direção vai girando até onde o player olha.
	var look := -_player.global_basis.z
	look = Vector3(look.x, 0, look.z).normalized()
	var turn := clampf(_slide_dir.signed_angle_to(look, Vector3.UP), -slide_steer * delta, slide_steer * delta)
	_slide_dir = _slide_dir.rotated(Vector3.UP, turn).normalized()
	# Física simples: a ladeira acelera, o atrito freia. Descendo, não para.
	var slope := 0.0
	if _player.is_on_floor():
		var n := _player.get_floor_normal()
		slope = Vector3(n.x, 0, n.z).dot(_slide_dir) # >0 = descendo
	_slide_speed = clampf(_slide_speed + (slope * 9.8 * 1.3 - slide_friction) * delta, 0.0, slide_max_speed)
	var running: bool = Input.is_action_pressed("sprint") and Input.is_action_pressed("move_forward")
	var exit_speed: float = _player.sprint_speed if running else _player.walk_speed
	var downhill := slope > 0.06
	# k: "progresso" usado nas animações; termina ao cair à velocidade de saída no plano.
	var k := clampf(_slide_time / slide_time, 0.0, 1.0)
	if downhill:
		k = minf(k, 0.5)
	var done := _slide_time > 0.35 and not downhill and _slide_speed <= exit_speed
	var speed := maxf(_slide_speed, exit_speed if done else 0.0)
	_player.velocity.x = _slide_dir.x * speed
	_player.velocity.z = _slide_dir.z * speed
	if not _player.is_on_floor():
		_player.velocity.y -= 9.8 * delta
	_player.move_and_slide()
	camera_roll = -0.08 * (1.0 - k * 0.6)
	camera_pitch = 0.08 * sin(minf(k * 4.0, 1.0) * PI * 0.5) * (1.0 - k)
	# Mão esquerda arrastando no chão, ao lado.
	var side := _slide_dir.cross(Vector3.UP).normalized()
	hand_targets = [_player.global_position - side * 0.55 - _slide_dir * 0.1 + Vector3.UP * 0.05, Vector3.INF]
	hand_weight = smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.6, 0.9, k))
	_trip_zombies()
	if done or _slide_speed < 0.5:
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
	hand_targets = [Vector3.INF, Vector3.INF]
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
	_entry_speed = Vector2(_player.velocity.x, _player.velocity.z).length()
	var edge := Vector3(wall.x, top_y, wall.z) + forward * 0.06
	var right := forward.cross(Vector3.UP).normalized()
	var landing := _landing_point(wall + forward * (info.depth + 0.55), feet.y, top_y)
	var on_top := Vector3(wall.x, top_y, wall.z) + forward * minf(0.45, info.depth * 0.5)

	if info.height <= vault_max_height:
		if sprinting and info.depth <= vault_max_depth and landing != Vector3.INF:
			# Passa por cima deslizando (capô de carro / barreira).
			# Tempo pela distância e pela velocidade de entrada: atravessa sem perder ritmo.
			var distance := Vector2(landing.x - feet.x, landing.z - feet.z).length()
			var duration := clampf(distance / maxf(_entry_speed, 5.0), 0.28, 0.55)
			_begin(Move.VAULT, duration, [feet, Vector3(wall.x, top_y + 0.25, wall.z) + forward * info.depth * 0.5, landing])
			hand_targets = [edge + forward * info.depth * 0.4 - right * 0.12, Vector3.INF] # apoia a mão esquerda
			return true
		if _has_room(on_top):
			_begin_mantle(feet, top_y, on_top + forward * minf(_entry_speed * 0.08, 0.4), info.height)
			hand_targets = [edge - right * 0.24, edge + right * 0.24]
			return true
		return false
	if info.depth <= fence_max_depth and landing != Vector3.INF:
		# Cerca: sobe, passa por cima e desce do outro lado.
		var over := Vector3(wall.x, top_y + 0.2, wall.z)
		_begin(Move.CLIMB_OVER, 0.55 + info.height * 0.2,
				[feet, over - forward * 0.15, over + forward * (info.depth + 0.15), landing])
		_entry_speed = 0.0 # escalar a cerca é o único que para o player
		hand_targets = [edge - right * 0.24, edge + right * 0.24]
		return true
	if _has_room(on_top):
		_begin_mantle(feet, top_y, on_top, info.height)
		hand_targets = [edge - right * 0.24, edge + right * 0.24]
		return true
	return false


## Subir em cima: curva contínua (sobe e já avança), mais rápida com impulso.
func _begin_mantle(feet: Vector3, top_y: float, on_top: Vector3, height: float) -> void:
	var lift := Vector3(feet.x, top_y + 0.3, feet.z).lerp(on_top, 0.25)
	var duration := clampf(0.24 + height * 0.2 - _entry_speed * 0.025, 0.24, 0.7)
	_begin(Move.MANTLE, duration, [feet, lift, on_top])


func _begin(kind: Move, duration: float, points: Array) -> void:
	move = kind
	_t = 0.0
	_duration = duration
	_points.assign(points)
	_collision.disabled = true
	_player.velocity = Vector3.ZERO


func _update_traverse(delta: float) -> void:
	var before := _player.global_position
	_t += delta / _duration
	var k := clampf(_t, 0.0, 1.0)
	if move == Move.VAULT or move == Move.MANTLE:
		# Curva contínua (sem parar nos pontos): vault passa "deslizando" por cima,
		# mantle sobe e já sai andando.
		var a := _points[0]
		var apex := _points[1]
		var b := _points[2]
		var control := apex * 2.0 - (a + b) * 0.5 if move == Move.VAULT else apex
		var t := k if move == Move.VAULT else ease(k, 0.8)
		_player.global_position = a.lerp(control, t).lerp(control.lerp(b, t), t)
		if move == Move.VAULT:
			camera_roll = sin(k * PI) * 0.14
			camera_pitch = -sin(k * PI) * 0.12
			hand_weight = smoothstep(0.0, 0.2, k) * (1.0 - smoothstep(0.55, 0.85, k))
		else:
			camera_roll = sin(k * PI) * 0.04
			camera_pitch = -sin(minf(k * 1.6, 1.0) * PI) * 0.22
			hand_weight = smoothstep(0.0, 0.12, k) * (1.0 - smoothstep(0.7, 0.95, k))
	else:
		# Trechos retos: sobe, depois anda por cima (e desce, na cerca).
		var segments := _points.size() - 1
		var f := k * segments
		var i := mini(int(f), segments - 1)
		_player.global_position = _points[i].lerp(_points[i + 1], smoothstep(0.0, 1.0, f - i))
		camera_roll = sin(k * PI) * 0.05
		camera_pitch = -sin(k * PI) * 0.18
		hand_weight = smoothstep(0.0, 0.1, k) * (1.0 - smoothstep(0.55, 0.75, k))
	# Velocidade real do movimento (corpo e balanço da arma continuam animando).
	if delta > 0.0:
		_player.velocity = (_player.global_position - before) / delta
	if k >= 1.0:
		var kind := move
		move = Move.NONE
		camera_roll = 0.0
		_collision.disabled = false
		hand_targets = [Vector3.INF, Vector3.INF]
		# Sai na mesma velocidade em que entrou (vault e mantle não freiam o player).
		var forward := -_player.global_basis.z
		forward = Vector3(forward.x, 0, forward.z).normalized()
		_player.velocity = forward * _entry_speed
		land(3.0 if kind == Move.CLIMB_OVER else 1.6)


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
	var depth := 4.5
	var d := 0.2
	while d < 4.5:
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
