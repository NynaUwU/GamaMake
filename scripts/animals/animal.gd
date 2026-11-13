class_name Animal
extends CharacterBody3D
## Bicho do mapa (ser vivo = em blocos, AnimalModels). O host simula; os outros
## jogadores veem uma cópia que só segue a posição e as marcas (AnimalManager manda).
## Comportamentos ("type"):
##   prey         foge de quem chega perto (cervo, coelho, raposa, cabra)
##   defend       apanhou, avança em quem bateu e morde por um tempo (javali)
##   hunter       ataca quem chegar perto, e a matilha vem junto (lobo; de noite de mais longe)
##   territorial  ataca quem chega perto demais ou bate (urso)
##   farm         de criação (galinha, ovelha, vaca, porco): selvagem foge, mas segue quem
##                segura a comida dele; [E] com a comida = fica manso. Manso: fica em volta
##                de casa, come no cocho, bebe no bebedouro, cria filhotes e dá produtos.
##   bird         pássaro: anda bicando; chegou perto, levanta voo e pousa longe
##                (pato nada no lago, gaivota plana sobre a costa).
## Golpes: hitbox com meta "enemy" (igual aos zumbis): espada, soco, tiro, lança...

const KINDS := {
	"cervo": {"hp": 60.0, "walk": 1.4, "run": 7.0, "fear": 16.0, "size": Vector3(0.45, 0.9, 1.1), "type": "prey",
		"drops": [[&"carne_crua", 2, 3], [&"pele", 1, 2]]},
	"coelho": {"hp": 12.0, "walk": 1.0, "run": 6.0, "fear": 9.0, "size": Vector3(0.22, 0.25, 0.32), "type": "prey",
		"drops": [[&"carne_crua", 1, 1], [&"pele", 1, 1]]},
	"javali": {"hp": 90.0, "walk": 1.1, "run": 5.2, "fear": 0.0, "size": Vector3(0.5, 0.7, 1.0), "type": "defend", "bite": 12.0,
		"drops": [[&"carne_crua", 3, 4], [&"pele", 1, 2], [&"gordura", 1, 2]]},
	"lobo": {"hp": 55.0, "walk": 1.3, "run": 6.6, "fear": 0.0, "size": Vector3(0.34, 0.75, 0.95), "type": "hunter", "bite": 10.0, "aggro": 12.0,
		"drops": [[&"carne_crua", 2, 2], [&"pele", 1, 1]]},
	"urso": {"hp": 220.0, "walk": 1.0, "run": 5.6, "fear": 0.0, "size": Vector3(0.75, 1.3, 1.45), "type": "territorial", "bite": 24.0, "aggro": 7.0,
		"drops": [[&"carne_crua", 4, 6], [&"pele", 2, 3], [&"gordura", 2, 3]]},
	"raposa": {"hp": 20.0, "walk": 1.2, "run": 6.4, "fear": 12.0, "size": Vector3(0.22, 0.45, 0.6), "type": "prey",
		"drops": [[&"carne_crua", 1, 1], [&"pele", 1, 1]]},
	"cabra": {"hp": 40.0, "walk": 1.1, "run": 5.8, "fear": 12.0, "size": Vector3(0.34, 0.95, 0.8), "type": "prey",
		"drops": [[&"carne_crua", 2, 2], [&"pele", 1, 1]]},
	"galinha": {"hp": 8.0, "walk": 0.6, "run": 3.4, "fear": 5.0, "size": Vector3(0.2, 0.42, 0.3), "type": "farm",
		"food": [&"semente_trigo", &"semente_algodao", &"semente_cenoura", &"semente_batata", &"semente_abobora"],
		"drops": [[&"carne_crua", 1, 1], [&"pena", 1, 3]]},
	"ovelha": {"hp": 35.0, "walk": 0.8, "run": 4.6, "fear": 9.0, "size": Vector3(0.5, 0.95, 0.9), "type": "farm", "food": [&"trigo"],
		"drops": [[&"carne_crua", 2, 2], [&"la", 1, 2], [&"pele", 1, 1]]},
	"vaca": {"hp": 70.0, "walk": 0.8, "run": 3.8, "fear": 7.0, "size": Vector3(0.62, 1.4, 1.4), "type": "farm", "food": [&"trigo"],
		"drops": [[&"carne_crua", 4, 5], [&"pele", 2, 2], [&"gordura", 1, 1]]},
	"porco": {"hp": 45.0, "walk": 0.8, "run": 4.2, "fear": 7.0, "size": Vector3(0.45, 0.7, 0.85), "type": "farm",
		"food": [&"trigo", &"cenoura", &"batata", &"abobora"], "litter": 2,
		"drops": [[&"carne_crua", 3, 3], [&"gordura", 1, 2]]},
	"pombo": {"hp": 6.0, "walk": 0.4, "run": 1.2, "fear": 7.0, "size": Vector3(0.15, 0.22, 0.24), "type": "bird", "fly": 7.0,
		"drops": [[&"carne_crua", 1, 1], [&"pena", 1, 2]]},
	"corvo": {"hp": 8.0, "walk": 0.5, "run": 1.4, "fear": 11.0, "size": Vector3(0.18, 0.28, 0.3), "type": "bird", "fly": 8.0,
		"drops": [[&"carne_crua", 1, 1], [&"pena", 2, 3]]},
	"pato": {"hp": 10.0, "walk": 0.4, "run": 1.2, "fear": 9.0, "size": Vector3(0.2, 0.3, 0.34), "type": "bird", "fly": 6.5, "swims": true,
		"drops": [[&"carne_crua", 1, 2], [&"pena", 1, 3]]},
	"gaivota": {"hp": 8.0, "walk": 0.5, "run": 1.4, "fear": 9.0, "size": Vector3(0.2, 0.3, 0.34), "type": "bird", "fly": 8.5, "soar": true,
		"drops": [[&"carne_crua", 1, 1], [&"pena", 1, 3]]},
}
const NAMES := {"cervo": "Cervo", "coelho": "Coelho", "javali": "Javali", "lobo": "Lobo", "urso": "Urso", "raposa": "Raposa",
	"cabra": "Cabra", "galinha": "Galinha", "ovelha": "Ovelha", "vaca": "Vaca", "porco": "Porco", "pombo": "Pombo",
	"corvo": "Corvo", "pato": "Pato", "gaivota": "Gaivota"}
const GRAVITY := 20.0
const GROW_TIME := 900.0 ## filhote vira adulto (s do relógio da fazenda)
const FED_TIME := 600.0 ## comeu no cocho: alimentado por meio dia
const WATER_TIME := 600.0
const HOME_RADIUS := 6.0
const TROUGH_RANGE := 14.0
const LURE_RANGE := 11.0
## Marcas que vão para as cópias (snapshot).
const F_TAME := 1
const F_BABY := 2
const F_FLY := 4
const F_SHORN := 8
const F_PRODUCT := 16
const F_FED := 32
const F_WATER := 64
const F_GRAZE := 128

var net_id := 0
var kind := "cervo"
var hp := 60.0
var puppet := false ## cópia de cliente (sem física, só segue)
var flags := 0 ## (cópias) marcas vindas do host
# Criação (host; vão no save).
var tame := false
var birth := -1e9 ## relógio da fazenda em que nasceu (filhote se < GROW_TIME)
var fed_until := 0.0
var water_until := 0.0
var next_breed := 0.0
var next_product := 0.0
var home := Vector3.ZERO
var shorn := false
var _target := Vector3.ZERO
var _think := 0.0
var _angry := 0.0 ## segundos atrás de quem bateu / chegou perto
var _angry_at: Node3D
var _bite := 0.0
var _goal: PlacedObject # cocho/bebedouro indo até ele
var _goal_check := 0.0
var _graze := 0.0
var _flying := false
var _fly_to := Vector3.ZERO
var _soar := 0.0
var _swimming := false
var _model := {}
var _root: Node3D
var _walk_phase := 0.0
var _snap_pos := Vector3.ZERO
var _snap_yaw := 0.0
var _time := 0.0
var anim_speed := 0.0 ## velocidade (para as pernas, também nas cópias)
var _voice := randf_range(4.0, 16.0)
const VOICES := {"galinha": "cluck", "ovelha": "baa", "vaca": "moo", "porco": "oink", "corvo": "caw", "pato": "quack",
	"lobo": "howl", "urso": "roar", "javali": "oink", "gaivota": "caw"}


func def() -> Dictionary:
	return KINDS[kind]


func is_bird() -> bool:
	return def().type == "bird"


func is_farm() -> bool:
	return def().type == "farm"


func setup(kind_: String, id: int, is_puppet: bool) -> void:
	kind = kind_ if KINDS.has(kind_) else "cervo"
	net_id = id
	puppet = is_puppet
	hp = def().hp
	var d := def()
	# "inimigo": jogadores e carros esbarram (pássaro não: voa por cima de todo mundo).
	collision_layer = 0 if is_bird() else 1 << 2
	if is_farm():
		collision_layer |= 1 << 5 # mira de interação ([E] alimentar, ordenhar, tosquiar)
		add_to_group("interactable")
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = d.size
	shape.shape = box
	shape.position.y = d.size.y * 0.5
	add_child(shape)
	_root = Node3D.new()
	_root.name = "Model"
	add_child(_root)
	_model = AnimalModels.build(kind, _root)
	# Hitbox: o que a arma acerta (mesma camada das hitboxes dos zumbis). Pássaro: maior.
	var hitbox := Area3D.new()
	hitbox.collision_layer = 1 << 4
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.set_meta("enemy", self)
	hitbox.set_meta("bone", &"")
	var hit_shape := CollisionShape3D.new()
	var hit_box := BoxShape3D.new()
	hit_box.size = d.size * (2.2 if is_bird() else 1.25)
	hit_shape.shape = hit_box
	hit_shape.position.y = d.size.y * 0.55
	hitbox.add_child(hit_shape)
	add_child(hitbox)
	_target = global_position if is_inside_tree() else Vector3.ZERO


func _ready() -> void:
	if home == Vector3.ZERO:
		home = global_position


# --- Estado de criação ------------------------------------------------------------------

func clock() -> float:
	var world: Node = Net.i.world
	var placed: PlacedManager = world.get_node_or_null("Placed") if world else null
	return placed.clock if placed else Time.get_ticks_msec() / 1000.0


func is_baby() -> bool:
	return (flags & F_BABY) != 0 if puppet else clock() - birth < GROW_TIME


func is_tame() -> bool:
	return (flags & F_TAME) != 0 if puppet else tame


func is_fed() -> bool:
	return (flags & F_FED) != 0 if puppet else clock() < fed_until


func is_watered() -> bool:
	return (flags & F_WATER) != 0 if puppet else clock() < water_until


## Leite pronto / lã crescida (a galinha bota o ovo sozinha).
func product_ready() -> bool:
	if puppet:
		return (flags & F_PRODUCT) != 0
	if not tame or is_baby():
		return false
	match kind:
		"vaca":
			return clock() >= next_product and is_fed()
		"ovelha":
			return not shorn
	return false


func net_flags() -> int:
	var f := 0
	if tame:
		f |= F_TAME
	if is_baby():
		f |= F_BABY
	if _flying:
		f |= F_FLY
	if shorn:
		f |= F_SHORN
	if product_ready():
		f |= F_PRODUCT
	if is_fed():
		f |= F_FED
	if is_watered():
		f |= F_WATER
	if _graze > 0.0:
		f |= F_GRAZE
	return f


# --- Simulação (host) -------------------------------------------------------------------

var _ground_timer := 0.0
var _ground_ok := true


func _physics_process(delta: float) -> void:
	_time += delta
	if puppet:
		global_position = global_position.lerp(_snap_pos, 1.0 - exp(-10.0 * delta))
		rotation.y = lerp_angle(rotation.y, _snap_yaw, 1.0 - exp(-10.0 * delta))
		_flying = (flags & F_FLY) != 0
		_graze = 1.0 if (flags & F_GRAZE) != 0 else 0.0
		_animate(delta)
		return
	if is_bird():
		_bird(delta)
		_animate(delta)
		return
	_ground_timer -= delta
	if _ground_timer <= 0.0:
		_ground_timer = 0.5
		_ground_ok = WorldFloor.ground_at(global_position)
	if not _ground_ok:
		velocity = Vector3.ZERO # sem chão carregado aqui: espera parado (não cai pelo mundo)
		return
	var d := def()
	var player := _nearest_player()
	var to_player := (player.global_position - global_position) if player else Vector3.ZERO
	to_player.y = 0.0
	var speed: float = d.walk
	var desired := Vector3.ZERO
	_think -= delta
	_angry = maxf(_angry - delta, 0.0)
	_bite -= delta
	_graze = maxf(_graze - delta, 0.0)
	_check_aggro(player, to_player)
	if _angry > 0.0 and is_instance_valid(_angry_at):
		# Bravo: corre até quem bateu (ou chegou perto) e morde.
		var to: Vector3 = _angry_at.global_position - global_position
		to.y = 0.0
		speed = d.run
		desired = to.normalized()
		if to.length() < 1.3 + d.size.z * 0.4 and _bite <= 0.0 and _angry_at.has_method("take_damage"):
			_bite = 1.2
			_angry_at.take_damage(d.get("bite", 10.0), to.normalized())
			Sfx.play_at("growl", global_position + Vector3.UP * 0.5, 2.0, 0.6 if kind != "lobo" else 1.0)
		if _angry_at.get("health") != null and _angry_at.health <= 0.0:
			_angry = 0.0
	elif is_farm() and _lured_by(player):
		# Segurando a comida dele: vem atrás (para levar até o cercado).
		if to_player.length() > 2.0:
			desired = to_player.normalized()
			speed = d.walk * 1.8
		if tame:
			home = global_position
	elif tame:
		desired = _tame_move(delta)
	elif player and d.fear > 0.0 and to_player.length() < d.fear:
		# Foge (coelho em zigue-zague).
		speed = d.run
		desired = -to_player.normalized()
		if kind in ["coelho", "galinha"]:
			desired = desired.rotated(Vector3.UP, sin(_time * 6.0 + net_id) * 0.8)
	else:
		desired = _wander(global_position, 12.0)
	if is_baby():
		speed *= 0.8
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
	if anim_speed < 0.2 and desired == Vector3.ZERO and d.type in ["prey", "farm", "defend"] and randf() < delta * 0.3:
		_graze = randf_range(1.5, 3.5) # parado: abaixa a cabeça e pasta
	_animate(delta)


## Lobo/urso: quem chega perto vira alvo; a matilha vem junto.
func _check_aggro(player: Node3D, to_player: Vector3) -> void:
	var d := def()
	if not d.type in ["hunter", "territorial"] or player == null or _angry > 0.0:
		return
	var range_: float = d.aggro
	if d.type == "hunter" and DayNight.i and DayNight.i.is_night():
		range_ *= 1.6
	if to_player.length() < range_:
		_anger(player, 12.0)


func _anger(who: Node3D, seconds: float) -> void:
	_angry = seconds
	_angry_at = who
	if kind == "lobo":
		Sfx.play_at("growl", global_position + Vector3.UP * 0.5, 3.0, 1.2)
		var manager := get_parent() as AnimalManager
		if manager:
			for other: Animal in manager.animals.values():
				if is_instance_valid(other) and other != self and other.kind == "lobo" and other._angry <= 0.0 \
						and other.global_position.distance_to(global_position) < 18.0:
					other._angry = seconds
					other._angry_at = who


func _wander(center: Vector3, radius: float) -> Vector3:
	if _think <= 0.0 or global_position.distance_to(_target) < 1.0:
		_think = randf_range(4.0, 9.0)
		var a := randf() * TAU
		_target = center + Vector3(cos(a), 0, sin(a)) * randf_range(radius * 0.3, radius)
	var to_target := _target - global_position
	to_target.y = 0.0
	if to_target.length() > 1.0 and _think < 6.0: # às vezes para e "pasta"
		return to_target.normalized()
	return Vector3.ZERO


## Manso: come no cocho, bebe no bebedouro, senão fica em volta de casa.
func _tame_move(delta: float) -> Vector3:
	var now := clock()
	_goal_check -= delta
	if _goal_check <= 0.0:
		_goal_check = 2.0
		_goal = null
		if now >= fed_until:
			_goal = Ranch.find_trough(self, false)
		if _goal == null and now >= water_until:
			_goal = Ranch.find_trough(self, true)
	if is_instance_valid(_goal):
		var to := _goal.global_position - global_position
		to.y = 0.0
		if to.length() < 1.2 + def().size.z * 0.5:
			if _goal.kind == "trough" and Ranch.take_food(_goal, kind):
				fed_until = now + FED_TIME
				_graze = 2.5
				Sfx.play_at("crunch", global_position + Vector3.UP * 0.4, -6.0, 1.3)
			elif _goal.kind == "water_trough" and Ranch.take_water(_goal):
				water_until = now + WATER_TIME
				_graze = 2.0
				Sfx.play_at("splash", global_position + Vector3.UP * 0.3, -10.0, 1.4)
			_goal = null
			_goal_check = 1.0
			return Vector3.ZERO
		return to.normalized()
	return _wander(home, HOME_RADIUS)


## Jogador perto segurando a comida deste bicho.
func _lured_by(player: Node3D) -> bool:
	if player == null or player.global_position.distance_to(global_position) > LURE_RANGE:
		return false
	return held_item(player) in def().get("food", [])


static func held_item(player: Node) -> StringName:
	if player.has_method("is_puppet") and player.is_puppet():
		return StringName(player.get("_net_item")) if player.get("_net_item") != null else &""
	return player.inventory.selected_id() if player.get("inventory") else &""


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


func _terrain() -> TerrainWorld:
	var world: Node = Net.i.world
	return world.get_node_or_null("Terrain") as TerrainWorld if world else null


# --- Pássaros ---------------------------------------------------------------------------

func _bird(delta: float) -> void:
	var d := def()
	var player := _nearest_player()
	var near: bool = player != null and player.global_position.distance_to(global_position) < d.fear
	var terrain := _terrain()
	if not _flying:
		_swimming = d.get("swims", false) and WaterManager.i != null and WaterManager.i.depth_at(global_position + Vector3.UP * 0.05) > -0.05
		if near or (d.get("soar", false) and randf() < delta * 0.05) or randf() < delta * 0.004:
			_take_off(player)
			return
		var desired := _wander(global_position, 4.0)
		var flat := Vector3(velocity.x, 0, velocity.z).lerp(desired * d.walk, 1.0 - exp(-5.0 * delta))
		velocity.x = flat.x
		velocity.z = flat.z
		if _swimming:
			var level: float = global_position.y + WaterManager.i.depth_at(global_position)
			velocity.y = clampf((level - 0.06 - global_position.y) * 4.0, -1.0, 1.0)
		elif not is_on_floor():
			velocity.y -= GRAVITY * delta
		if flat.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), 1.0 - exp(-8.0 * delta))
		elif randf() < delta * 0.8:
			_graze = 0.4 # bicadinha
		_graze = maxf(_graze - delta, 0.0)
		move_and_slide()
		anim_speed = flat.length()
		return
	# Voando: sobe até a altura de cruzeiro e vai até o ponto; perto, desce e pousa.
	var to := _fly_to - global_position
	var flat_to := Vector3(to.x, 0.0, to.z)
	var ground := terrain.height_at(global_position.x, global_position.z) if terrain else 0.0
	var cruise := ground + 9.0
	if _soar > 0.0:
		# Gaivota planando em círculo.
		_soar -= delta
		var around := Vector3(-flat_to.z, 0.0, flat_to.x).normalized()
		flat_to = around * 10.0 + flat_to * 0.08
		cruise = ground + 13.0
		if _soar <= 0.0:
			_fly_to = _landing_spot(global_position, 25.0)
	var landing := flat_to.length() < 5.0 and _soar <= 0.0
	var target_y := _fly_to.y if landing else maxf(cruise, _fly_to.y + 3.0)
	var hv: Vector3 = flat_to.normalized() * float(d.fly) * (0.5 if landing else 1.0)
	velocity.x = lerpf(velocity.x, hv.x, 1.0 - exp(-3.0 * delta))
	velocity.z = lerpf(velocity.z, hv.z, 1.0 - exp(-3.0 * delta))
	velocity.y = clampf((target_y - global_position.y) * 1.5, -3.5, 4.0)
	if Vector2(velocity.x, velocity.z).length() > 0.3:
		rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), 1.0 - exp(-5.0 * delta))
	move_and_slide()
	anim_speed = velocity.length()
	if landing and (is_on_floor() or global_position.y - _fly_to.y < 0.12):
		_flying = false
		velocity = Vector3.ZERO
		_think = 0.0
	elif get_slide_collision_count() > 0 and not landing:
		_fly_to = _landing_spot(global_position, 30.0) # bateu em algo: muda de rumo


func _take_off(from: Node3D) -> void:
	_flying = true
	var away := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	if from:
		away = global_position - from.global_position
		away.y = 0.0
	away = away.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6))
	_fly_to = _landing_spot(global_position + away * randf_range(30.0, 55.0), 6.0)
	if def().get("soar", false):
		_soar = randf_range(8.0, 20.0)
	velocity = Vector3.UP * 3.0 + away * 2.0
	Sfx.play_at("swing", global_position, -6.0, 1.6)


## Ponto de pouso perto de "at": chão (ou o lago, para o pato).
func _landing_spot(at: Vector3, spread: float, tries := 0) -> Vector3:
	var p := at + Vector3(randf_range(-spread, spread), 0, randf_range(-spread, spread))
	var terrain := _terrain()
	p.y = terrain.height_at(p.x, p.z) if terrain else at.y
	if WaterManager.i:
		var depth := WaterManager.i.depth_at(p)
		if depth > 0.0:
			if def().get("swims", false) or tries >= 8:
				p.y += depth # pato pousa na água (os outros só se não acharem chão)
			else:
				return _landing_spot(at + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20)), spread, tries + 1)
	return p


# --- Golpes e morte ---------------------------------------------------------------------

## Golpe (arma, soco, tiro). No cliente, pede ao host.
func take_hit(info: HitInfo) -> void:
	ImpactFX.burst(get_parent(), info.point, -info.direction, ImpactFX.BLOOD, 10, 2.0)
	Sfx.play_at("hit", info.point, 0.0, 1.3 if def().size.y < 0.5 else 0.9)
	if puppet:
		Net.i.system_request("Animals", "hit", [net_id, info.damage, info.direction])
		return
	apply_hit(info.damage, info.direction)


func apply_hit(damage: float, direction: Vector3) -> void:
	hp -= damage
	if not _flying:
		velocity += Vector3(direction.x, 0.0, direction.z).normalized() * 3.0
	match def().type:
		"defend", "hunter", "territorial":
			_anger(_nearest_player(), 15.0)
		"bird":
			if not _flying:
				_take_off(_nearest_player())
		_:
			_think = 0.0
	if hp <= 0.0:
		_die()


func _die() -> void:
	# Sai da física antes de soltar: o item nascia dentro da caixa do bicho (ainda
	# viva até o fim do quadro) e era empurrado para baixo, atravessando o chão.
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true
	var where := Transform3D(Basis(), global_position + Vector3.UP * maxf(0.5, def().size.y * 0.7))
	var baby := is_baby()
	for drop in def().drops:
		var amount := randi_range(drop[1], drop[2])
		if baby:
			amount = mini(amount, 1) if drop[0] == &"carne_crua" else 0
		if amount > 0:
			Net.i.drop_item(drop[0], amount, where, Vector3(randf_range(-1, 1), 2.0, randf_range(-1, 1)))
	ImpactFX.burst(get_parent(), global_position + Vector3.UP * 0.4, Vector3.UP, ImpactFX.BLOOD, 22, 3.0)
	Sfx.play_at("death", global_position, -2.0, 1.6 if def().size.y < 0.5 else 1.1)
	var manager := get_parent() as AnimalManager
	if manager:
		manager.forget(net_id)
	queue_free()


## Cópia: posição/direção/marcas vindas do host.
func apply_snapshot(pos: Vector3, yaw: float, speed: float, flags_ := 0) -> void:
	_snap_pos = pos
	_snap_yaw = yaw
	anim_speed = speed
	flags = flags_


# --- Interação (criação) ----------------------------------------------------------------

func get_interact_text() -> String:
	var name_: String = NAMES[kind]
	var player := get_tree().get_first_node_in_group("player")
	var holding := held_item(player) if player else &""
	var food: Array = def().get("food", [])
	if is_baby():
		return "Filhote de %s" % name_.to_lower()
	if not is_tame():
		return "[E] Alimentar: fica manso" if holding in food else "%s selvagem (segure %s para atrair)" % [name_, ItemDB.display_name(food[0]).to_lower()]
	var state := []
	state.append("alimentada" if is_fed() else "com fome")
	state.append("com água" if is_watered() else "com sede")
	var action := ""
	if holding in food and not is_fed():
		action = "[E] Alimentar · "
	elif kind == "vaca" and product_ready():
		action = "[E] Ordenhar (garrafa vazia) · "
	elif kind == "ovelha" and product_ready():
		action = "[E] Tosquiar · "
	return "%s%s mansa (%s)" % [action, name_, ", ".join(state)]


func interact(player: Node) -> void:
	var food: Array = def().get("food", [])
	var holding := held_item(player)
	if holding in food and (not is_tame() or not is_fed()):
		player.inventory.take(player.inventory.selected, 1)
		Net.i.system_request("Animals", "feed", [net_id, String(holding)])
		Sfx.play_at("crunch", global_position + Vector3.UP * 0.4, -4.0, 1.3)
		return
	if not is_tame() or is_baby():
		Sfx.play("click", -6.0, 0.6)
		return
	if kind == "vaca" and product_ready():
		var bottle := Cooking.find_any(player.inventory, {&"garrafa": true})
		if bottle < 0:
			Sfx.play("click", -6.0, 0.6)
			return
		player.inventory.take(bottle, 1)
		Net.i.system_request("Animals", "milk", [net_id])
		Sfx.play_at("slap", global_position + Vector3.UP * 0.6, -6.0, 1.5)
		return
	if kind == "ovelha" and product_ready():
		Net.i.system_request("Animals", "shear", [net_id])
		Sfx.play_at("slice", global_position + Vector3.UP * 0.6, -4.0, 1.2)
		return
	Sfx.play("click", -6.0, 0.6)


# --- Visual -----------------------------------------------------------------------------

## De vez em quando o bicho faz barulho (só perto de quem está jogando aqui).
## Lobo uiva de noite; gaivota grita mais aguda que o corvo.
func _voices(delta: float) -> void:
	_voice -= delta
	if _voice > 0.0:
		return
	_voice = randf_range(8.0, 22.0)
	if not VOICES.has(kind):
		return
	if kind == "lobo" and (DayNight.i == null or not DayNight.i.is_night()):
		return
	var local := get_tree().get_first_node_in_group("player") as Node3D
	if local == null or local.global_position.distance_to(global_position) > (60.0 if kind == "lobo" else 28.0):
		return
	var pitch: float = {"gaivota": 1.5, "javali": 0.75, "urso": 0.7}.get(kind, 1.0) * (1.3 if is_baby() else 1.0)
	Sfx.play_at(VOICES[kind], global_position + Vector3.UP * def().size.y, -2.0 if kind != "lobo" else 2.0, pitch)

func _animate(delta: float) -> void:
	_voices(delta)
	var baby := is_baby()
	_root.scale = Vector3.ONE * (0.55 if baby else 1.0)
	if _model.wool:
		_model.wool.visible = not (shorn if not puppet else (flags & F_SHORN) != 0) and not baby
	var small: bool = def().size.y < 0.5
	_walk_phase += delta * anim_speed * (6.0 if small else 3.5)
	var swing := sin(_walk_phase) * clampf(anim_speed / 2.0, 0.0, 0.7)
	var legs: Array = _model.legs
	for i in legs.size():
		var leg: Node3D = legs[i]
		if _flying:
			leg.rotation.x = lerpf(leg.rotation.x, -0.9, 1.0 - exp(-8.0 * delta)) # pernas recolhidas
		elif legs.size() == 2:
			leg.rotation.x = swing * (1.0 if i == 0 else -1.0)
		else:
			leg.rotation.x = swing * (1.0 if i % 2 == 0 else -1.0) * (1.0 if i < 2 else -1.0)
	var head: Node3D = _model.head
	if head:
		var down := 0.0
		if _graze > 0.0:
			down = 0.75 if not is_bird() else 0.5 + sin(_time * 25.0) * 0.4
		head.rotation.x = lerpf(head.rotation.x, down, 1.0 - exp(-8.0 * delta))
	for wing: Node3D in _model.wings:
		var side: float = wing.get_meta("side")
		if _flying:
			var flap := sin(_time * (16.0 if _soar <= 0.0 else 3.0)) * (0.9 if _soar <= 0.0 else 0.15)
			wing.rotation.z = side * flap
			wing.scale.x = 1.0
		else:
			var hop := sin(_time * 30.0) * 0.6 if anim_speed > 2.0 else 0.0 # galinha correndo bate as asas
			wing.rotation.z = lerpf(wing.rotation.z, side * (-0.1 + hop), 1.0 - exp(-10.0 * delta))
			wing.scale.x = 1.0 if kind == "galinha" else 0.35
