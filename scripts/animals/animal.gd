class_name Animal
extends CharacterBody3D
## Bicho do mapa (ser vivo = em blocos). O host simula; os outros jogadores veem
## uma cópia que só segue a posição (AnimalManager manda os instantâneos).
##   cervo   foge de longe, rápido; dá bastante carne e pele
##   coelho  pequeno, foge em zigue-zague; pouca carne e pele pequena
##   javali  anda devagar; apanhou, avança em quem bateu (morde) por um tempo
## Golpes: hitbox com meta "enemy" (igual aos zumbis), então espada, soco,
## revólver, lança... funcionam do mesmo jeito.

const KINDS := {
	"cervo": {"hp": 60.0, "walk": 1.4, "run": 7.0, "fear": 16.0, "size": Vector3(0.45, 0.9, 1.1),
		"drops": [[&"carne_crua", 2, 3], [&"pele", 1, 2]]},
	"coelho": {"hp": 12.0, "walk": 1.0, "run": 6.0, "fear": 9.0, "size": Vector3(0.22, 0.25, 0.32),
		"drops": [[&"carne_crua", 1, 1], [&"pele", 1, 1]]},
	"javali": {"hp": 90.0, "walk": 1.1, "run": 5.2, "fear": 0.0, "size": Vector3(0.5, 0.7, 1.0),
		"drops": [[&"carne_crua", 3, 4], [&"pele", 1, 2], [&"gordura", 1, 2]]},
}
const GRAVITY := 20.0

var net_id := 0
var kind := "cervo"
var hp := 60.0
var puppet := false ## cópia de cliente (sem física, só segue)
var _target := Vector3.ZERO
var _think := 0.0
var _angry := 0.0 ## javali: segundos atrás de quem bateu
var _angry_at: Node3D
var _bite := 0.0
var _legs: Array[Node3D] = []
var _walk_phase := 0.0
var _snap_pos := Vector3.ZERO
var _snap_yaw := 0.0
var anim_speed := 0.0 ## velocidade (para as pernas, também nas cópias)


func setup(kind_: String, id: int, is_puppet: bool) -> void:
	kind = kind_
	net_id = id
	puppet = is_puppet
	hp = KINDS[kind].hp
	collision_layer = 1 << 2 # "inimigo": jogadores e carros esbarram
	collision_mask = 1
	var def: Dictionary = KINDS[kind]
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = def.size
	shape.shape = box
	shape.position.y = def.size.y * 0.5
	add_child(shape)
	_build_model()
	# Hitbox: o que a arma acerta (mesma camada das hitboxes dos zumbis).
	var hitbox := Area3D.new()
	hitbox.collision_layer = 1 << 4
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.set_meta("enemy", self)
	hitbox.set_meta("bone", &"")
	var hit_shape := CollisionShape3D.new()
	var hit_box := BoxShape3D.new()
	hit_box.size = def.size * 1.25
	hit_shape.shape = hit_box
	hit_shape.position.y = def.size.y * 0.55
	hitbox.add_child(hit_shape)
	add_child(hitbox)
	_target = global_position if is_inside_tree() else Vector3.ZERO


func _physics_process(delta: float) -> void:
	if puppet:
		global_position = global_position.lerp(_snap_pos, 1.0 - exp(-10.0 * delta))
		rotation.y = lerp_angle(rotation.y, _snap_yaw, 1.0 - exp(-10.0 * delta))
		_animate(delta)
		return
	var def: Dictionary = KINDS[kind]
	var player := _nearest_player()
	var to_player := (player.global_position - global_position) if player else Vector3.ZERO
	to_player.y = 0.0
	var speed: float = def.walk
	var desired := Vector3.ZERO
	_think -= delta
	_angry = maxf(_angry - delta, 0.0)
	_bite -= delta
	if _angry > 0.0 and is_instance_valid(_angry_at):
		# Javali bravo: corre até quem bateu e morde.
		var to: Vector3 = _angry_at.global_position - global_position
		to.y = 0.0
		speed = def.run
		desired = to.normalized()
		if to.length() < 1.3 and _bite <= 0.0 and _angry_at.has_method("take_damage"):
			_bite = 1.2
			_angry_at.take_damage(12.0, to.normalized())
			Sfx.play_at("growl", global_position, 2.0, 0.6)
	elif player and def.fear > 0.0 and to_player.length() < def.fear:
		# Foge (coelho em zigue-zague).
		speed = def.run
		desired = -to_player.normalized()
		if kind == "coelho":
			desired = desired.rotated(Vector3.UP, sin(Time.get_ticks_msec() * 0.006) * 0.8)
	else:
		if _think <= 0.0 or global_position.distance_to(_target) < 1.0:
			_think = randf_range(4.0, 9.0)
			var a := randf() * TAU
			_target = global_position + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 12.0)
		var to_target := _target - global_position
		to_target.y = 0.0
		if to_target.length() > 1.0 and _think < 6.0: # às vezes para e "pasta"
			desired = to_target.normalized()
	var flat := Vector3(velocity.x, 0, velocity.z).lerp(desired * speed, 1.0 - exp(-6.0 * delta))
	velocity.x = flat.x
	velocity.z = flat.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if flat.length() > 0.3:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), 1.0 - exp(-8.0 * delta))
	StepClimb.step(self, delta)
	move_and_slide()
	anim_speed = flat.length()
	_animate(delta)


func _nearest_player() -> Node3D:
	var best: Node3D = null
	var world: Node = Net.i.world
	if world == null:
		return null
	var list: Array = [world.player]
	var puppets: Dictionary = world.get("puppets") if world.get("puppets") != null else {}
	for peer in puppets:
		list.append(puppets[peer])
	for p in list:
		if is_instance_valid(p) and (best == null or p.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = p
	return best


## Golpe (arma, soco, tiro). No cliente, pede ao host.
func take_hit(info: HitInfo) -> void:
	ImpactFX.burst(get_parent(), info.point, -info.direction, ImpactFX.BLOOD, 10, 2.0)
	Sfx.play_at("hit", info.point, 0.0, 1.3 if kind == "coelho" else 0.9)
	if puppet:
		Net.i.system_request("Animals", "hit", [net_id, info.damage, info.direction])
		return
	apply_hit(info.damage, info.direction)


func apply_hit(damage: float, direction: Vector3) -> void:
	hp -= damage
	velocity += Vector3(direction.x, 0.0, direction.z).normalized() * 3.0
	if kind == "javali":
		_angry = 15.0
		_angry_at = _nearest_player()
	else:
		_think = 0.0
	if hp <= 0.0:
		_die()


func _die() -> void:
	var where := Transform3D(Basis(), global_position + Vector3.UP * 0.4)
	for drop in KINDS[kind].drops:
		var amount := randi_range(drop[1], drop[2])
		if amount > 0:
			Net.i.drop_item(drop[0], amount, where, Vector3(randf_range(-1, 1), 2.0, randf_range(-1, 1)))
	ImpactFX.burst(get_parent(), global_position + Vector3.UP * 0.4, Vector3.UP, ImpactFX.BLOOD, 22, 3.0)
	Sfx.play_at("death", global_position, -2.0, 1.6 if kind == "coelho" else 1.1)
	var manager := get_parent() as AnimalManager
	if manager:
		manager.forget(net_id)
	queue_free()


## Cópia: posição/direção vindas do host.
func apply_snapshot(pos: Vector3, yaw: float, speed: float) -> void:
	_snap_pos = pos
	_snap_yaw = yaw
	anim_speed = speed


# --- Modelo em blocos -----------------------------------------------------------

func _animate(delta: float) -> void:
	_walk_phase += delta * anim_speed * (3.5 if kind != "coelho" else 6.0)
	var swing := sin(_walk_phase) * clampf(anim_speed / 2.0, 0.0, 0.7)
	for i in _legs.size():
		_legs[i].rotation.x = swing * (1.0 if i % 2 == 0 else -1.0) * (1.0 if i < 2 else -1.0)


func _block(parent: Node3D, color: Color, at: Vector3, size: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	box.material = mat
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _leg(at: Vector3, length: float, width: float, color: Color, hoof: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	_block(pivot, color, Vector3(0, -length * 0.5, 0), Vector3(width, length, width))
	_block(pivot, hoof, Vector3(0, -length + 0.02, 0.01), Vector3(width * 1.1, 0.05, width * 1.2))
	_legs.append(pivot)


func _build_model() -> void:
	match kind:
		"cervo":
			var fur := Color(0.55, 0.38, 0.22)
			var belly := Color(0.85, 0.75, 0.6)
			_block(self, fur, Vector3(0, 0.85, 0), Vector3(0.42, 0.4, 0.95)) # corpo
			_block(self, belly, Vector3(0, 0.67, 0), Vector3(0.36, 0.06, 0.8))
			_block(self, fur, Vector3(0, 1.15, 0.45), Vector3(0.2, 0.45, 0.2)) # pescoço
			_block(self, fur, Vector3(0, 1.4, 0.6), Vector3(0.22, 0.22, 0.36)) # cabeça
			_block(self, Color(0.15, 0.1, 0.08), Vector3(0, 1.36, 0.79), Vector3(0.1, 0.08, 0.04)) # focinho
			for side in [-1.0, 1.0]:
				_block(self, Color(0.05, 0.05, 0.05), Vector3(side * 0.112, 1.44, 0.68), Vector3(0.02, 0.04, 0.04)) # olho
				_block(self, fur, Vector3(side * 0.15, 1.53, 0.5), Vector3(0.12, 0.06, 0.04)) # orelha
				var antler := Color(0.75, 0.68, 0.55)
				_block(self, antler, Vector3(side * 0.08, 1.65, 0.52), Vector3(0.04, 0.3, 0.04))
				_block(self, antler, Vector3(side * 0.16, 1.75, 0.52), Vector3(0.16, 0.04, 0.04))
				_block(self, antler, Vector3(side * 0.1, 1.78, 0.6), Vector3(0.04, 0.04, 0.14))
			_block(self, belly, Vector3(0, 0.95, -0.5), Vector3(0.1, 0.14, 0.06)) # rabinho
			for x in [-0.14, 0.14]:
				for z in [0.35, -0.35]:
					_leg(Vector3(x, 0.66, z), 0.66, 0.08, fur.darkened(0.15), Color(0.1, 0.08, 0.06))
		"coelho":
			var fur := Color(0.62, 0.55, 0.46)
			_block(self, fur, Vector3(0, 0.15, 0), Vector3(0.2, 0.18, 0.3))
			_block(self, fur, Vector3(0, 0.24, 0.16), Vector3(0.14, 0.13, 0.14)) # cabeça
			for side in [-1.0, 1.0]:
				_block(self, fur.lightened(0.1), Vector3(side * 0.035, 0.38, 0.14), Vector3(0.035, 0.16, 0.025)) # orelhas
				_block(self, Color(0.05, 0.05, 0.05), Vector3(side * 0.072, 0.26, 0.2), Vector3(0.012, 0.025, 0.025))
			_block(self, Color(0.95, 0.95, 0.92), Vector3(0, 0.17, -0.16), Vector3(0.07, 0.07, 0.05)) # rabo
			for x in [-0.07, 0.07]:
				for z in [0.09, -0.09]:
					_leg(Vector3(x, 0.08, z), 0.08, 0.045, fur.darkened(0.1), fur.darkened(0.2))
		"javali":
			var fur := Color(0.3, 0.22, 0.17)
			_block(self, fur, Vector3(0, 0.55, 0), Vector3(0.5, 0.45, 0.9))
			_block(self, fur.darkened(0.2), Vector3(0, 0.8, 0.05), Vector3(0.12, 0.08, 0.8)) # crina
			_block(self, fur, Vector3(0, 0.55, 0.55), Vector3(0.36, 0.34, 0.3)) # cabeça
			_block(self, Color(0.5, 0.35, 0.3), Vector3(0, 0.5, 0.74), Vector3(0.18, 0.14, 0.1)) # focinho
			for side in [-1.0, 1.0]:
				_block(self, Color(0.9, 0.88, 0.8), Vector3(side * 0.1, 0.5, 0.78), Vector3(0.03, 0.1, 0.03)) # presas
				_block(self, Color(0.05, 0.05, 0.05), Vector3(side * 0.16, 0.62, 0.66), Vector3(0.02, 0.03, 0.03))
				_block(self, fur, Vector3(side * 0.13, 0.75, 0.48), Vector3(0.08, 0.1, 0.04))
			for x in [-0.16, 0.16]:
				for z in [0.3, -0.3]:
					_leg(Vector3(x, 0.34, z), 0.34, 0.1, fur.darkened(0.1), Color(0.12, 0.1, 0.08))
