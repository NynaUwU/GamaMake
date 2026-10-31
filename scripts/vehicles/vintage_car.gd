class_name VintageCar
extends VehicleBody3D
## Carro de corrida dos anos 30 (inspirado no Alfa Romeo 8C 2300 Monza, 1932).
## Modelado por código em malhas poligonais estilo PS2 (MeshBuilder): carroceria
## em seções "loft" (capô comprido, cockpit aberto, rabo de barco), grade em
## coração, faróis torneados, para-lamas de moto curvos, rodas raiadas,
## escapamento lateral e painel só com velocímetro. Suspensão alta para
## fora de estrada. Volante à direita, como o original.
##
## Dirigir é em PRIMEIRA PESSOA: o player senta no banco, olha com o mouse e
## as mãos ficam no volante. [E] entra/sai. W/S acelera/ré, A/D vira,
## Espaço freio de mão. Atropelar zumbis derruba (ou mata, se estiver rápido).

const PAINT := Color(0.62, 0.05, 0.04) # rosso corsa
const CHROME := Color(0.8, 0.8, 0.82)
const DARK := Color(0.09, 0.09, 0.1)
const LEATHER := Color(0.36, 0.2, 0.11)
const TIRE := Color(0.07, 0.07, 0.07)
const ALUMINIUM := Color(0.62, 0.62, 0.6)
const DIAL := Color(0.97, 0.97, 0.95) # fundo branco do mostrador
const LAYER_ENEMY := 1 << 2

const FLOOR_Y := 0.1 ## fundo da carroceria (vão livre alto)

@export var max_engine_force := 2600.0
@export var max_brake := 35.0
@export var max_steer := 0.55
@export var top_speed := 28.0 ## m/s (~100 km/h)

# --- Ficha do carro: outros modelos mudam estes valores em _configure() ------
var wheelbase := 2.7
var track_width := 1.36
var wheel_radius := 0.42
var wheel_style := "wire" ## "wire" (raiada), "wood" (raios de madeira) ou "disc" (calota)
var speedo_max := 140.0 ## km/h no fim da escala
var car_mass := 1050.0
var center_of_mass_y := 0.15
## Curva de torque: fração da força no arranque, no pico e na velocidade máxima.
## torque_peak = onde fica o pico (0..1 da velocidade máxima).
var torque_low := 1.0
var torque_peak := 0.0
var torque_high := 1.0
var front_grip := 2.2 ## wheel_friction_slip das rodas da frente
var rear_grip := 2.2
## 0..1: quanto o pneu de trás perde aderência com o acelerador no fundo
## (torque demais para o pneu: a traseira sai de lado).
var wheelspin := 0.0
var drift_kick := 1.5 ## giro extra (rad/s²) que o torque dá ao virar acelerando, vezes wheelspin
var drift_hold := 30.0 ## graus de lado a partir dos quais o pneu volta a agarrar
var drift_max := 45.0 ## mais de lado que isso o carro não fica (só carros com wheelspin)
var all_wheel_drive := false
var roll_influence := 0.25 ## menor = mais difícil de capotar na curva
var steer_rate := 2.5 ## quão rápido o volante vira (rad/s nas rodas)
var steer_min := 0.15 ## fração do esterço que sobra em alta velocidade
var suspension_rest := 0.32
var suspension_travel := 0.28
var suspension_stiffness := 38.0
var seat_offset := Vector3(-0.22, 0.17, -0.38)
var exit_offset := Vector3(-1.35, 0.2, -0.38)
var wheel_center := Vector3(-0.22, 0.68, 0.07) ## centro do volante
var wheel_tilt := 0.57
var wheel_size := 0.18
var column_base := Vector3(-0.22, 0.52, 0.32)
var gauge_pos := Vector3(0.0, 0.7, 0.16)
var gauge_yaw := 0.3 ## gira o mostrador para o motorista
## Caixas de colisão [tamanho, centro] e área do para-choque.
var collision_boxes := [[Vector3(1.0, 0.6, 3.7), Vector3(0, 0.4, -0.15)], [Vector3(0.85, 0.3, 1.5), Vector3(0, 0.7, 1.0)]]
var bumper_size := Vector3(1.6, 1.4, 4.8)
var bumper_offset := Vector3(0, 0.5, 0.1)

var driver: Node3D
var seat: Node3D ## onde o player fica (olhando para a frente do carro)
var steering_wheel: Node3D ## gira com a direção; o player põe as mãos no aro
var eye_height := 0.8 ## altura da câmera acima do banco (olha por cima dos para-brisas)
var _needle: Node3D
var _bumper: Area3D
var _hit_cooldown := {}
var _materials := {}
var _headlight_points: Array[Vector3] = []
var _headlights: Array[SpotLight3D] = []
var headlights_on := false


var _rear_wheels: Array[VehicleWheel3D] = []
var _wheels: Array[VehicleWheel3D] = []
var air_damping := 3.0 ## quanto o giro de frente/lado some no ar (por segundo)
var air_leveling := 4.0 ## quanto o carro se endireita no ar


func _ready() -> void:
	_configure()
	mass = car_mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, center_of_mass_y, 0) # baixo: não capota fácil
	collision_layer = 1
	collision_mask = 1 | LAYER_ENEMY
	add_to_group("interactable")
	add_to_group("vehicle")
	_build_collision()
	_build_model()
	_build_wheels()
	_build_bumper()
	seat = Node3D.new()
	seat.name = "DriverSeat"
	seat.position = seat_offset # Monza: banco da direita (o carro anda para +Z: direita = -X)
	seat.rotation = Vector3(0, PI, 0) # o player olha para -Z; o carro anda para +Z
	add_child(seat)
	set_headlights(false) # começa apagado (lentes escuras)
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	if not Net.i.is_host():
		freeze = true # online: no começo quem simula os carros é o host


## Outros carros sobrescrevem para mudar a ficha (medidas, motor, pneus, banco).
func _configure() -> void:
	pass


# --- Interação ---------------------------------------------------------------

func get_interact_text() -> String:
	return "[E] Dirigir" if driver == null and driver_peer == 0 else ""


func interact(player: Node) -> void:
	if driver == null and driver_peer == 0 and player.has_method("enter_vehicle"):
		Net.i.request_car(self) # online o host confere se ninguém pegou antes


# --- Multiplayer ---------------------------------------------------------------
# Quem dirige (ou dirigiu por último) simula o carro e manda a posição; nos
# outros jogadores o carro fica congelado seguindo essa posição.

var net_owner := 1 ## peer que simula este carro
var driver_peer := 0 ## peer dirigindo agora (0 = ninguém)
var _snap_xform := Transform3D()
var _snap_velocity := Vector3.ZERO
var _has_snap := false


func set_net_owner(owner: int, driving: int) -> void:
	net_owner = owner
	driver_peer = driving
	var mine: bool = owner == Net.i.my_id()
	if mine and freeze:
		freeze = false
		linear_velocity = _snap_velocity
	elif not mine:
		freeze = true
		_has_snap = false


func apply_snapshot(xform: Transform3D, velocity: Vector3, steer: float, lights: bool) -> void:
	_snap_xform = xform
	_snap_velocity = velocity
	steering = steer
	if lights != headlights_on:
		set_headlights(lights)
	if not _has_snap:
		_has_snap = true
		global_transform = xform


func _is_copy() -> bool:
	return Net.i.online() and net_owner != Net.i.my_id()


## Cópia: segue a posição do dono (andando um pouco para frente entre as mensagens).
func _follow_owner(delta: float) -> void:
	if not _has_snap:
		return
	_snap_xform.origin += _snap_velocity * delta
	global_transform = global_transform.interpolate_with(_snap_xform, 1.0 - exp(-15.0 * delta))


func set_driver(who: Node3D) -> void:
	driver = who
	set_see_through(who != null)
	# Faróis só mudam com o L (dirigindo); sair do carro não apaga.
	if who == null:
		engine_force = 0.0
		steering = 0.0
		brake = max_brake * 0.5


## Onde o player sai: ao lado do banco (direita do carro).
func exit_point() -> Vector3:
	return global_transform * exit_offset


## Pontos do aro do volante (mundo) para as mãos: 10h e 2h, girando com a direção.
func hand_points() -> Array:
	var points := []
	for a in [0.95, -0.95]: # esquerda, direita do motorista (local +X = esquerda dele; o nó já gira com a direção)
		points.append(steering_wheel.global_transform * Vector3(sin(a) * wheel_size, cos(a) * wheel_size, 0))
	return points


# --- Direção -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _is_copy():
		_follow_owner(delta)
		return
	var forward := global_basis.z
	var speed := linear_velocity.dot(forward)
	_air_control(delta)
	if driver == null:
		engine_force = 0.0
		brake = max_brake * 0.3
		return
	var throttle := Input.get_axis("move_back", "move_forward")
	var steer_input := Input.get_axis("move_right", "move_left")
	# Menos esterço em alta velocidade (não capota na curva).
	# Quanto mais rápido, menos a roda vira (a partir de ~10 km/h; no máximo sobra 15%).
	var ratio := absf(speed) / top_speed
	var fast := smoothstep(0.1, 0.75, ratio)
	var steer_limit := max_steer * lerpf(1.0, steer_min, fast)
	steering = move_toward(steering, steer_input * steer_limit, delta * steer_rate)
	brake = 0.0
	# Torque demais: com o pé no fundo a traseira perde aderência e sai de lado
	# (menos em alta, quando o motor já não tem tanta força sobrando).
	var spin := wheelspin * maxf(throttle, 0.0) * lerpf(1.0, 0.45, clampf(ratio, 0.0, 1.0))
	if Input.is_action_pressed("jump"):
		spin = maxf(spin, 0.35) # freio de mão trava a traseira
	# Ângulo de derrapagem: muito de lado, o pneu volta a agarrar (dá para
	# segurar o carro escorregando sem rodar de vez).
	var flat := linear_velocity - global_basis.y * linear_velocity.dot(global_basis.y)
	var slip := absf(forward.signed_angle_to(flat, global_basis.y)) if flat.length() > 3.0 and speed > 0.0 else 0.0
	spin *= 1.0 - smoothstep(deg_to_rad(drift_hold), deg_to_rad(drift_hold + 25.0), slip)
	for wheel in _rear_wheels:
		wheel.wheel_friction_slip = rear_grip * (1.0 - spin)
	# Limite da derrapagem: passou de drift_max graus de lado, segura o giro e
	# puxa a velocidade de volta para a frente (escorrega, mas não roda).
	var excess := slip - deg_to_rad(drift_max)
	if wheelspin > 0.0 and excess > 0.0:
		var up := global_basis.y
		var yaw := angular_velocity.dot(up)
		angular_velocity -= up * yaw * minf(1.0, 10.0 * delta)
		var side := signf(forward.signed_angle_to(flat, up))
		linear_velocity = linear_velocity.rotated(up, -side * excess * minf(1.0, 5.0 * delta))
	# Saindo de lado: volante reto ou contra-esterço gira o carro de volta para
	# onde ele está indo (o pneu da frente "puxa" a traseira de volta).
	if wheelspin > 0.0 and slip > deg_to_rad(2.0):
		var up := global_basis.y
		var toward := forward.signed_angle_to(flat, up)
		var counter := 1.0 if steer_input * toward >= 0.0 else 0.0
		var yaw := angular_velocity.dot(up)
		angular_velocity += up * (toward * 2.2 - yaw) * minf(1.0, 2.5 * delta) * counter
	# Torque sobrando empurra a traseira para fora quando vira acelerando.
	if wheelspin > 0.0 and throttle > 0.0 and speed > 4.0:
		apply_torque(global_basis.y * steer_input * throttle * wheelspin * drift_kick * mass)
	if throttle > 0.0:
		engine_force = max_engine_force * throttle * _torque(ratio) * (1.0 if speed < top_speed else 0.0)
		if speed < -1.0:
			brake = max_brake # andando de ré e apertou W: freia primeiro
	elif throttle < 0.0:
		if speed > 1.0:
			brake = max_brake * -throttle
			engine_force = 0.0
		else:
			engine_force = max_engine_force * 0.5 * throttle # ré
	else:
		engine_force = 0.0
		brake = 2.0 # freio-motor
	if Input.is_action_pressed("jump"):
		brake = max_brake * 1.5 # freio de mão


## No ar (salto/rampa): segura o giro de frente e de lado para cair de rodas
## (arcade; o giro no próprio eixo continua livre).
func _air_control(delta: float) -> void:
	for wheel in _wheels:
		if wheel.is_in_contact():
			return
	var up := global_basis.y
	var spin := angular_velocity - up * angular_velocity.dot(up)
	angular_velocity -= spin * minf(1.0, air_damping * delta)
	# E endireita devagar se estiver inclinado.
	var tilt := up.cross(Vector3.UP)
	angular_velocity += tilt * air_leveling * delta


## Fração da força do motor nessa velocidade (0..1 da máxima).
func _torque(ratio: float) -> float:
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio < torque_peak:
		return lerpf(torque_low, 1.0, ratio / torque_peak)
	return lerpf(1.0, torque_high, (ratio - torque_peak) / maxf(1.0 - torque_peak, 0.01))


## Lente de vidro fechando cada farol (acende junto com a luz) + luz de verdade.
func _build_headlights(model: Node3D) -> void:
	for point in _headlight_points:
		var lens := MeshBuilder.new()
		lens.lathe(PackedVector2Array([Vector2(0.112, 0.0), Vector2(0.06, 0.012), Vector2(0.002, 0.016)]), 14,
				Basis(Vector3.RIGHT, PI / 2), point)
		_add(model, lens.finish(_material("lens", Color(0.95, 0.9, 0.75), 0.3, 0.0, true)))
		var light := SpotLight3D.new()
		light.light_color = Color(1.0, 0.9, 0.7)
		light.light_energy = 3.0
		light.spot_range = 38.0
		light.spot_angle = 28.0
		light.spot_attenuation = 0.9
		light.shadow_enabled = true
		light.position = point + Vector3(0, 0, 0.03)
		light.rotation = Vector3(-0.06, PI, 0) # luz aponta para -Z: gira para a frente do carro (+Z)
		light.visible = false
		model.add_child(light)
		_headlights.append(light)


func toggle_headlights() -> void:
	set_headlights(not headlights_on)


func set_headlights(on: bool) -> void:
	headlights_on = on
	for light in _headlights:
		light.visible = on
	var lens: StandardMaterial3D = _materials.get("lens")
	if lens:
		lens.emission_enabled = true
		lens.emission = Color(1.0, 0.92, 0.7)
		lens.emission_energy_multiplier = 2.0 if on else 0.05


## Visão do motorista: volante e coluna semitransparentes para não tapar a estrada.
func set_see_through(enabled: bool) -> void:
	for key in ["wheel_rim", "column"]:
		var material: StandardMaterial3D = _materials.get(key)
		if material == null:
			continue
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color.a = 0.45 if enabled else 1.0


func _process(delta: float) -> void:
	# Volante gira com a direção; ponteiro do velocímetro segue a velocidade.
	steering_wheel.rotation.z = -steering * 2.2
	var velocity := _snap_velocity if _is_copy() else linear_velocity
	var kmh := absf(velocity.dot(global_basis.z)) * 3.6
	_needle.rotation.z = lerpf(2.3, -2.3, clampf(kmh / speedo_max, 0.0, 1.0))
	_engine_sound(kmh, delta)


## Motor: liga com alguém dirigindo; o tom sobe com a velocidade (e acelerando).
var _engine: AudioStreamPlayer3D
var _rev := 0.0
var _engine_level := 0.0 # 0..1 (fade)


func _engine_sound(kmh: float, delta: float) -> void:
	var running := driver != null or driver_peer != 0
	if _engine == null:
		if not running:
			return
		_engine = Sfx.loop_player("engine", self, -4.0)
	# Liga/desliga com fade (cortar o som seco dava um "pop").
	_engine_level = move_toward(_engine_level, 1.0 if running else 0.0, delta * 2.5)
	if _engine_level > 0.0 and not _engine.playing:
		_engine.play()
	elif _engine_level <= 0.0 and _engine.playing:
		_engine.stop()
	if _engine.playing:
		var effort := absf(engine_force) / max_engine_force if running else 0.0
		_rev = lerpf(_rev, clampf(kmh / speedo_max, 0.0, 1.0) + effort * 0.25, minf(delta * 3.0, 1.0))
		_engine.pitch_scale = 0.75 + _rev * 1.1
		_engine.volume_db = Sfx.BASE_DB - 8.0 + _rev * 5.0 + linear_to_db(maxf(_engine_level, 0.001))


# --- Atropelar ---------------------------------------------------------------

func _build_bumper() -> void:
	_bumper = Area3D.new()
	_bumper.name = "Bumper"
	_bumper.collision_layer = 0
	_bumper.collision_mask = LAYER_ENEMY
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bumper_size
	shape.shape = box
	shape.position = bumper_offset
	_bumper.add_child(shape)
	add_child(_bumper)
	_bumper.body_entered.connect(_on_bumper_body)


func _on_bumper_body(body: Node) -> void:
	if not body.has_method("hit_by_vehicle") or _is_copy():
		return
	var speed := linear_velocity.length()
	var now := Time.get_ticks_msec()
	if speed < 2.5 or now - _hit_cooldown.get(body, -10000) < 700:
		return
	_hit_cooldown[body] = now
	body.hit_by_vehicle(linear_velocity, global_position)
	linear_velocity *= 0.93 # o impacto segura um pouco o carro


func _build_collision() -> void:
	for entry in collision_boxes:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = entry[0]
		shape.shape = box
		shape.position = entry[1]
		add_child(shape)


# --- Modelo ------------------------------------------------------------------

func _build_model() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	_build_body(model)
	_build_dash(model)
	_build_cockpit(model)
	_build_headlights(model)


## Carroceria do Monza. Cada modelo de carro sobrescreve esta função.
func _build_body(model: Node3D) -> void:
	var paint := MeshBuilder.new()
	var interior := MeshBuilder.new()
	var chrome := MeshBuilder.new()
	var dark := MeshBuilder.new() # peças mecânicas (arestas duras)
	var leather := MeshBuilder.new()
	_body(paint, interior, leather)
	_grille_and_lights(chrome, dark)
	_fenders(paint, dark)
	_details(paint, chrome, dark)
	_seats(leather)
	_add(model, paint.finish(_material("paint", PAINT, 0.35, 0.15, true)))
	_add(model, interior.finish(_material("interior", Color(0.16, 0.1, 0.07), 0.9, 0.0, true)))
	_add(model, chrome.finish(_material("chrome", CHROME, 0.25, 0.85)))
	_add(model, dark.finish(_material("dark", DARK, 0.7, 0.3), false))
	_add(model, leather.finish(_material("leather", LEATHER, 0.75, 0.0)))
	var spare := _wheel_node()
	spare.position = Vector3(0, 0.72, -1.95)
	spare.rotation = Vector3(-0.45, PI / 2, 0)
	spare.scale = Vector3.ONE * 0.92
	model.add_child(spare)


## Carroceria: frente fechada (capô) + cockpit aberto (em "U") + traseira em rabo de barco.
func _body(paint: MeshBuilder, interior: MeshBuilder, leather: MeshBuilder) -> void:
	var seg := 22
	var front := []
	for s in [[1.74, 0.47, 0.27, 0.27, 3.2], [1.5, 0.48, 0.36, 0.27, 3.5], [1.0, 0.49, 0.4, 0.28, 3.5],
			[0.5, 0.5, 0.44, 0.29, 3.2], [0.25, 0.5, 0.47, 0.31, 3.0]]:
		front.append(MeshBuilder.ring(Vector3(0, s[1], s[0]), s[2], s[3], s[4], seg, FLOOR_Y))
	front.reverse() # seções em Z crescente = faces para fora
	paint.loft(front, true, true)
	var rear := []
	for s in [[-0.85, 0.47, 0.47, 0.29, 3.0], [-1.3, 0.45, 0.45, 0.28, 3.0], [-1.8, 0.42, 0.38, 0.25, 2.8],
			[-2.2, 0.38, 0.28, 0.2, 2.6], [-2.45, 0.34, 0.16, 0.13, 2.4], [-2.6, 0.31, 0.05, 0.05, 2.2]]:
		rear.append(MeshBuilder.ring(Vector3(0, s[1], s[0]), s[2], s[3], s[4], seg, FLOOR_Y))
	rear.reverse()
	paint.loft(rear, true, true)
	# Cockpit: casca em U por fora (pintada) e por dentro (forro escuro).
	var outer := []
	var inner := []
	for z in [0.25, -0.3, -0.85]:
		outer.append(MeshBuilder.ring(Vector3(0, 0.44, z), 0.475, 0.27, 3.0, 16, FLOOR_Y, PI * 0.85, PI * 2.15))
		inner.append(MeshBuilder.ring(Vector3(0, 0.44, z), 0.445, 0.24, 3.0, 16, FLOOR_Y + 0.03, PI * 0.85, PI * 2.15))
	outer.reverse()
	inner.reverse()
	paint.loft(outer, false)
	interior.loft(inner, false, false, true)
	# Borda de couro em volta da abertura do cockpit.
	for side in [-1.0, 1.0]:
		var edge := MeshBuilder.ring(Vector3(0, 0.44, 0), 0.46, 0.255, 3.0, 16, FLOOR_Y, PI * 0.85, PI * 2.15)
		var top := edge[0] if side < 0.0 else edge[edge.size() - 1]
		leather.tube(PackedVector3Array([Vector3(top.x, top.y, 0.24), Vector3(top.x, top.y, -0.84)]), 0.025, 6)
	# Linha central do capô.
	paint.tube(PackedVector3Array([Vector3(0, 0.77, 1.7), Vector3(0, 0.775, 1.0), Vector3(0, 0.79, 0.3)]), 0.012, 4)


func _grille_and_lights(chrome: MeshBuilder, dark: MeshBuilder) -> void:
	# Moldura da grade em "coração" (escudo Alfa): arco em cima, ponta embaixo.
	var shape := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		shape.append(Vector2(cos(a) * 0.24, 0.62 + sin(a) * 0.12))
	for p in [Vector2(-0.24, 0.42), Vector2(-0.2, 0.24), Vector2(-0.1, 0.12), Vector2(0, 0.05),
			Vector2(0.1, 0.12), Vector2(0.2, 0.24), Vector2(0.24, 0.42)]:
		shape.append(p)
	chrome.extrude(shape, 0.09, Basis.IDENTITY, Vector3(0, 0, 1.79))
	var inner := PackedVector2Array()
	for p in shape:
		inner.append(Vector2(p.x * 0.82, 0.4 + (p.y - 0.4) * 0.86))
	dark.extrude(inner, 0.02, Basis.IDENTITY, Vector3(0, 0, 1.84))
	for i in 7:
		var x := -0.15 + i * 0.05
		chrome.tube(PackedVector3Array([Vector3(x, 0.18 + absf(x) * 0.6, 1.855), Vector3(x, 0.7, 1.855)]), 0.006, 4, false)
	# Faróis torneados numa barra cromada.
	chrome.tube(PackedVector3Array([Vector3(-0.42, 0.52, 1.95), Vector3(0, 0.5, 1.93), Vector3(0.42, 0.52, 1.95)]), 0.018, 6)
	var lamp := PackedVector2Array([Vector2(0.02, -0.1), Vector2(0.08, -0.09), Vector2(0.115, -0.04), Vector2(0.125, 0.03), Vector2(0.12, 0.06)])
	for side in [-1.0, 1.0]:
		chrome.lathe(lamp, 14, Basis(Vector3.RIGHT, PI / 2), Vector3(side * 0.42, 0.57, 1.99))
		_headlight_points.append(Vector3(side * 0.42, 0.57, 2.04))


func _fenders(paint: MeshBuilder, dark: MeshBuilder) -> void:
	# Para-lamas de moto: chapa curva acima de cada roda + haste de fixação.
	for z in [wheelbase * 0.5, -wheelbase * 0.5]:
		var front: bool = z > 0.0
		for side in [-1.0, 1.0]:
			var x0: float = side * track_width * 0.5
			var grid := []
			for r in 11:
				var a := lerpf(-0.95 if front else -1.2, 1.25 if front else 0.9, r / 10.0)
				var row := PackedVector3Array()
				for c in 5:
					var u := lerpf(-1.0, 1.0, c / 4.0)
					var radius := 0.54 - u * u * 0.04 # bordas caem um pouco
					row.append(Vector3(x0 + u * 0.14, 0.08 + cos(a) * radius, z + sin(a) * radius))
				grid.append(row)
			paint.sheet(grid)
			dark.tube(PackedVector3Array([Vector3(x0 - side * 0.02, 0.08, z), Vector3(x0 - side * 0.1, 0.5, z + 0.12)]), 0.015, 4)


func _details(paint: MeshBuilder, chrome: MeshBuilder, dark: MeshBuilder) -> void:
	# Venezianas do capô (fendas inclinadas nas laterais).
	for i in 7:
		for side in [-1.0, 1.0]:
			dark.box(Vector3(side * 0.405, 0.53, 0.45 + i * 0.15), Vector3(0.012, 0.17, 0.035), Basis(Vector3.RIGHT, 0.25))
	# Eixos e feixes de mola à mostra (suspensão alta).
	for z in [wheelbase * 0.5, -wheelbase * 0.5]:
		dark.tube(PackedVector3Array([Vector3(-track_width * 0.5, 0.08, z), Vector3(track_width * 0.5, 0.08, z)]), 0.035, 6)
		for side in [-1.0, 1.0]:
			var spring := PackedVector3Array()
			for k in 6:
				var t := k / 5.0
				spring.append(Vector3(side * 0.36, 0.13 + sin(t * PI) * 0.05, z - 0.45 + t * 0.9))
			dark.tube(spring, 0.025, 4)
	# Escapamento saindo do capô e correndo pela esquerda.
	var pipe := PackedVector3Array([Vector3(-0.41, 0.5, 0.95), Vector3(-0.47, 0.42, 0.85), Vector3(-0.52, 0.3, 0.6),
		Vector3(-0.53, 0.28, 0.2), Vector3(-0.53, 0.27, -0.8), Vector3(-0.52, 0.26, -1.6), Vector3(-0.5, 0.25, -1.85)])
	dark.tube(pipe, 0.045, 8)
	# Tampa de combustível na traseira e rosetas de número nas laterais.
	chrome.lathe(PackedVector2Array([Vector2(0.06, 0.0), Vector2(0.06, 0.03), Vector2(0.04, 0.05), Vector2(0.01, 0.055)]), 10,
			Basis.IDENTITY, Vector3(0, 0.64, -1.55))
	for side in [-1.0, 1.0]:
		var roundel := MeshBuilder.new()
		roundel.color(Color.WHITE)
		roundel.lathe(PackedVector2Array([Vector2(0.01, 0.0), Vector2(0.19, 0.0), Vector2(0.19, 0.008)]), 16,
				Basis(Vector3.FORWARD, -side * PI / 2), Vector3(side * 0.44, 0.44, -1.4))
		_add(self, roundel.finish(_material("roundel", Color(0.95, 0.95, 0.9), 0.6, 0.0)))
		var number := Label3D.new()
		number.text = "8"
		number.font_size = 96
		number.pixel_size = 0.0035
		number.modulate = Color.BLACK
		number.outline_size = 0
		number.position = Vector3(side * 0.452, 0.44, -1.4)
		number.rotation = Vector3(0, side * PI / 2, 0)
		add_child(number)


func _seats(leather: MeshBuilder) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 0.22
		var cushion := []
		for z in [-0.1, -0.35, -0.6]:
			cushion.append(MeshBuilder.ring(Vector3(x, 0.42, z), 0.17, 0.07, 4.0, 12))
		cushion.reverse()
		leather.loft(cushion, true, true)
		var back := []
		for k in 3:
			var y := 0.5 + k * 0.2
			var z := -0.62 - k * 0.06
			var ring := MeshBuilder.ring(Vector3(x, y, z), 0.17, 0.05, 4.0, 12)
			# Anel deitado: gira a seção para ficar em pé (encosto).
			var standing := PackedVector3Array()
			for p in ring:
				standing.append(Vector3(p.x, y, z + (p.y - y)))
			back.append(standing)
		leather.loft(back, true, true, true)


## Painel do Monza: acompanha o arco da carroceria (por dentro do cockpit).
func _build_dash(model: Node3D) -> void:
	var panel := MeshBuilder.new()
	var arc := MeshBuilder.ring(Vector3(0, 0.44, 0.19), 0.44, 0.255, 3.0, 16, 0.5, 0.0, PI)
	var bottom := PackedVector3Array()
	for p in arc:
		bottom.append(Vector3(p.x, 0.5, 0.19))
	panel.sheet([bottom, arc])
	_add(model, panel.finish(_material("panel", ALUMINIUM, 0.45, 0.6, true)))


# --- Peças para montar outros carros ----------------------------------------

## Casco fechado por seções [z, centro_y, meia_largura, meia_altura, expoente(, centro_x)]
## em qualquer ordem. Expoente alto = mais quadrado.
func _hull(mb: MeshBuilder, sections: Array, floor_y := FLOOR_Y, segments := 18) -> void:
	var sorted := sections.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var rings := []
	for section in sorted:
		var x: float = section[5] if section.size() > 5 else 0.0
		rings.append(MeshBuilder.ring(Vector3(x, section[1], section[0]), section[2], section[3], section[4], segments, floor_y))
	mb.loft(rings, true, true)


## Cockpit aberto em U (casca pintada por fora, forro por dentro) entre z_back e z_front.
func _tub(paint: MeshBuilder, lining: MeshBuilder, z_front: float, z_back: float, center_y: float,
		half_width: float, half_height: float, floor_y := FLOOR_Y, n := 3.0) -> void:
	var outer := []
	var inner := []
	for z in [z_back, (z_back + z_front) * 0.5, z_front]:
		outer.append(MeshBuilder.ring(Vector3(0, center_y, z), half_width, half_height, n, 16, floor_y, PI * 0.85, PI * 2.15))
		inner.append(MeshBuilder.ring(Vector3(0, center_y, z), half_width - 0.03, half_height - 0.03, n, 16, floor_y + 0.03,
				PI * 0.85, PI * 2.15))
	paint.loft(outer, false)
	lining.loft(inner, false, false, true)


## Fileira de cilindros de motor de avião à mostra (com aletas e cabeçote).
## tilt inclina a fileira para o lado (motor em V: uma fileira para cada lado).
func _cylinders(mb: MeshBuilder, start: Vector3, count: int, spacing: float, radius: float, height: float, tilt := 0.0) -> void:
	var up := Vector3(-sin(tilt), cos(tilt), 0)
	for i in count:
		var base := start + Vector3(0, 0, -i * spacing)
		mb.tube(PackedVector3Array([base, base + up * height]), radius, 7)
		for k in 3: # aletas de refrigeração
			mb.tube(PackedVector3Array([base + up * (height * (0.25 + k * 0.22)), base + up * (height * (0.25 + k * 0.22) + 0.02)]),
					radius * 1.25, 7)
		mb.box(base + up * (height + 0.03), Vector3(radius * 2.3, 0.06, radius * 2.3), Basis(Vector3.BACK, tilt))


## Painel reto com o topo levemente arqueado (para os outros carros).
func _plate_dash(model: Node3D, z: float, bottom_y: float, top_y: float, half_width: float, color := ALUMINIUM) -> void:
	var panel := MeshBuilder.new()
	var bottom := PackedVector3Array()
	var top := PackedVector3Array()
	for i in 9:
		var x := lerpf(-half_width, half_width, i / 8.0)
		bottom.append(Vector3(x, bottom_y, z))
		top.append(Vector3(x, top_y - pow(x / half_width, 2.0) * 0.05, z))
	panel.sheet([bottom, top])
	_add(model, panel.finish(_material("panel", color, 0.45, 0.6, true)))


## Velocímetro e volante (posições na ficha do carro).
func _build_cockpit(model: Node3D) -> void:	# Velocímetro na frente do motorista (lado direito).
	var gauge := Node3D.new()
	gauge.name = "Speedometer"
	# No centro do painel, um pouco abaixo da borda, virado de leve para o motorista.
	gauge.position = gauge_pos # 1,5 cm à frente do painel (evita z-fighting)
	gauge.rotation = Vector3(-0.3, PI + gauge_yaw, 0) # mostrador virado para o motorista (-Z)
	model.add_child(gauge)
	var pod := MeshBuilder.new() # moldura funda que embute o mostrador no painel
	pod.lathe(PackedVector2Array([Vector2(0.03, -0.06), Vector2(0.07, -0.05), Vector2(0.088, -0.02), Vector2(0.088, 0.0)]), 16,
			Basis(Vector3.RIGHT, PI / 2))
	_add(gauge, pod.finish(_material("dark_round", DARK, 0.6, 0.3)))
	var bezel := MeshBuilder.new()
	bezel.torus(0.075, 0.009, 18, 5, Basis(Vector3.RIGHT, PI / 2))
	_add(gauge, bezel.finish(_material("chrome", CHROME, 0.25, 0.85)))
	var face := MeshBuilder.new()
	face.lathe(PackedVector2Array([Vector2(0.072, 0.0), Vector2(0.002, 0.004)]), 18, Basis(Vector3.RIGHT, PI / 2)) # perfil de fora para dentro = face virada para o motorista
	_add(gauge, face.finish(_material("dial", DIAL, 0.6, 0.0)))
	# Disco branco de fundo, preenchendo a moldura inteira por trás do mostrador.
	var backing := MeshBuilder.new()
	backing.lathe(PackedVector2Array([Vector2(0.084, -0.004), Vector2(0.002, -0.004)]), 18, Basis(Vector3.RIGHT, PI / 2))
	_add(gauge, backing.finish(_material("dial", DIAL, 0.6, 0.0)))
	var ticks := MeshBuilder.new()
	# Escala no sentido horário: 0 embaixo à esquerda, máximo embaixo à direita.
	for i in 15:
		var a := lerpf(-2.3, 2.3, i / 14.0)
		var long := i % 2 == 0
		ticks.box(Vector3(sin(a), cos(a), 0) * (0.058 if long else 0.062), Vector3(0.003, 0.014 if long else 0.007, 0.002),
				Basis(Vector3.BACK, -a))
	_add(gauge, ticks.finish(_material("ink", DARK, 0.8, 0.0), false))
	for i in 8:
		var a := lerpf(-2.3, 2.3, i / 7.0)
		var label := Label3D.new()
		label.text = str(roundi(i * speedo_max / 7.0 / 10.0) * 10)
		label.font_size = 24
		label.pixel_size = 0.0006
		label.modulate = DARK
		label.outline_size = 0
		label.position = Vector3(sin(a) * 0.042, cos(a) * 0.042, 0.006) # acima do disco branco
		gauge.add_child(label)
	_needle = Node3D.new()
	_needle.position = Vector3(0, 0, 0.008)
	gauge.add_child(_needle)
	var needle := MeshBuilder.new()
	needle.tri(Vector3(-0.003, 0, 0), Vector3(0, 0.058, 0), Vector3(0.003, 0, 0))
	needle.tri(Vector3(0.003, 0, 0), Vector3(0, -0.012, 0), Vector3(-0.003, 0, 0))
	_add(_needle, needle.finish(_material("needle", Color(0.8, 0.1, 0.05), 0.5, 0.0, true), false))
	# Volante de aro fino com 3 raios, inclinado para o motorista.
	steering_wheel = Node3D.new()
	steering_wheel.name = "SteeringWheel"
	steering_wheel.position = wheel_center
	steering_wheel.rotation = Vector3(wheel_tilt, 0, 0) # topo inclinado para o painel, perpendicular à coluna
	model.add_child(steering_wheel)
	var wheel := MeshBuilder.new()
	wheel.torus(wheel_size, 0.014, 20, 6, Basis(Vector3.RIGHT, PI / 2))
	for a in [PI / 2, PI * 7 / 6, PI * 11 / 6]:
		wheel.tube(PackedVector3Array([Vector3.ZERO, Vector3(cos(a), sin(a), 0) * (wheel_size - 0.005)]), 0.007, 4)
	wheel.lathe(PackedVector2Array([Vector2(0.03, -0.01), Vector2(0.03, 0.01), Vector2(0.015, 0.02)]), 10, Basis(Vector3.RIGHT, PI / 2))
	_add(steering_wheel, wheel.finish(_material("wheel_rim", DARK, 0.6, 0.2)))
	var column := MeshBuilder.new()
	column.tube(PackedVector3Array([column_base, steering_wheel.position + Vector3(0, -0.01, 0.02)]), 0.018, 6)
	_add(model, column.finish(_material("column", DARK, 0.6, 0.3)))


func _build_wheels() -> void:
	for z in [wheelbase * 0.5, -wheelbase * 0.5]:
		for side in [-1.0, 1.0]:
			var wheel := VehicleWheel3D.new()
			var front: bool = z > 0.0
			wheel.name = ("Front" if front else "Rear") + ("L" if side > 0 else "R")
			wheel.position = Vector3(side * track_width * 0.5, 0.32, z)
			wheel.use_as_steering = front
			wheel.use_as_traction = all_wheel_drive or not front # tração traseira
			wheel.wheel_radius = wheel_radius
			wheel.wheel_rest_length = suspension_rest
			wheel.suspension_travel = suspension_travel # Monza: curso longo, fora de estrada
			wheel.suspension_stiffness = suspension_stiffness
			wheel.suspension_max_force = 9000.0
			wheel.damping_compression = 2.2
			wheel.damping_relaxation = 3.0
			wheel.wheel_friction_slip = front_grip if front else rear_grip # escorrega um pouco antes de tombar
			wheel.wheel_roll_influence = roll_influence
			wheel.add_child(_wheel_node())
			add_child(wheel)
			_wheels.append(wheel)
			if not front:
				_rear_wheels.append(wheel)


## Roda no estilo da ficha, no tamanho de wheel_radius (o modelo é feito para 0,42 m).
func _wheel_node() -> Node3D:
	var root: Node3D
	match wheel_style:
		"wood": root = _wood_wheel()
		"disc": root = _disc_wheel()
		_: root = _wire_wheel()
	root.scale = Vector3.ONE * (wheel_radius / 0.42)
	return root


## Roda de carroça (1900–1920): pneu fino, 12 raios grossos de madeira.
func _wood_wheel() -> Node3D:
	var root := Node3D.new()
	var axis := Basis(Vector3.FORWARD, PI / 2)
	var tire := MeshBuilder.new()
	tire.torus(0.36, 0.06, 20, 6, axis)
	_add(root, tire.finish(_material("tire", TIRE, 0.95, 0.0)))
	var wood := MeshBuilder.new()
	wood.torus(0.3, 0.03, 20, 4, axis)
	for i in 12:
		var a := TAU * i / 12.0
		wood.box(Vector3(0, cos(a), sin(a)) * 0.17, Vector3(0.045, 0.27, 0.035), Basis(Vector3.RIGHT, -a))
	_add(root, wood.finish(_material("wood", Color(0.3, 0.2, 0.12), 0.9, 0.0), false))
	var hub := MeshBuilder.new()
	hub.lathe(PackedVector2Array([Vector2(0.07, -0.07), Vector2(0.075, 0.0), Vector2(0.05, 0.08), Vector2(0.02, 0.1)]), 8,
			Basis(Vector3.FORWARD, -PI / 2))
	_add(root, hub.finish(_material("dark", DARK, 0.7, 0.3), false))
	return root


## Roda de aço fechada com calota cromada (anos 30–50).
func _disc_wheel() -> Node3D:
	var root := Node3D.new()
	var axis := Basis(Vector3.FORWARD, PI / 2)
	var tire := MeshBuilder.new()
	tire.torus(0.31, 0.11, 20, 8, axis)
	_add(root, tire.finish(_material("tire", TIRE, 0.95, 0.0)))
	var disc := MeshBuilder.new()
	disc.lathe(PackedVector2Array([Vector2(0.26, -0.03), Vector2(0.26, 0.03), Vector2(0.2, 0.05), Vector2(0.12, 0.04)]), 16,
			Basis(Vector3.FORWARD, -PI / 2))
	disc.lathe(PackedVector2Array([Vector2(0.26, 0.03), Vector2(0.26, -0.03), Vector2(0.2, -0.05), Vector2(0.12, -0.04)]), 16,
			Basis(Vector3.FORWARD, PI / 2))
	_add(root, disc.finish(_material("wheel_paint", Color(0.55, 0.12, 0.08), 0.8, 0.1, true)))
	var cap := MeshBuilder.new()
	for side in [-1.0, 1.0]:
		cap.lathe(PackedVector2Array([Vector2(0.13, 0.03), Vector2(0.11, 0.07), Vector2(0.05, 0.09), Vector2(0.005, 0.095)]), 14,
				Basis(Vector3.FORWARD, -side * PI / 2))
	_add(root, cap.finish(_material("chrome", CHROME, 0.25, 0.85, true)))
	return root


## Roda raiada: pneu (toro), aro cromado, 16 raios cruzados e cubo "knock-off".
func _wire_wheel() -> Node3D:
	var root := Node3D.new()
	var axis := Basis(Vector3.FORWARD, PI / 2) # eixo da roda = X
	var tire := MeshBuilder.new()
	tire.torus(0.335, 0.085, 22, 8, axis)
	_add(root, tire.finish(_material("tire", TIRE, 0.95, 0.0)))
	var metal := MeshBuilder.new()
	metal.torus(0.29, 0.022, 22, 5, axis)
	for i in 16:
		var a := TAU * i / 16.0
		var offset := 0.045 if i % 2 == 0 else -0.045 # raios cruzados (alternam o lado do cubo)
		metal.tube(PackedVector3Array([Vector3(offset, cos(a + 0.25) * 0.05, sin(a + 0.25) * 0.05),
			Vector3(0, cos(a) * 0.28, sin(a) * 0.28)]), 0.004, 3, false)
	metal.lathe(PackedVector2Array([Vector2(0.06, -0.06), Vector2(0.065, 0.0), Vector2(0.05, 0.07), Vector2(0.02, 0.1)]), 10,
			Basis(Vector3.FORWARD, -PI / 2))
	for k in 2: # "orelhas" da porca knock-off
		metal.box(Vector3(0.09, 0, 0), Vector3(0.02, 0.1 if k == 0 else 0.02, 0.02 if k == 0 else 0.1))
	_add(root, metal.finish(_material("chrome", CHROME, 0.25, 0.85)))
	return root


func _add(parent: Node, mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _material(key: String, color: Color, roughness: float, metallic: float, _double_sided := false) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	# Pós-apocalíptico: pintura e cromados gastos, quase sem reflexo.
	material.albedo_color = color.darkened(0.12) if key in ["paint", "chrome"] else color
	material.roughness = maxf(roughness, 0.78)
	material.metallic = minf(metallic, 0.25)
	# Sempre dos dois lados: canos, eixos e para-lamas abertos não ficam "furados".
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if key == "dial":
		# Leve brilho próprio: o fundo continua branco na sombra do cockpit.
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.35
	_materials[key] = material
	return material
