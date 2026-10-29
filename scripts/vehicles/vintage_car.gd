class_name VintageCar
extends VehicleBody3D
## Carro de corrida dos anos 30 (inspirado no Alfa Romeo 8C 2300 Monza, 1932):
## capô comprido com venezianas, grade vertical em "coração", para-lamas de
## moto (cycle fenders), rodas raiadas, traseira em "rabo de barco" com estepe
## e escapamento lateral. Suspensão mais alta para andar fora da estrada.
## Volante à direita, como o original.
##
## [E] entra/sai. Dirigindo: W/S acelera/ré, A/D vira, Espaço freio de mão.
## Atropelar zumbis derruba (ou mata, se estiver rápido).

const RED := Color(0.62, 0.05, 0.04) # rosso corsa
const CHROME := Color(0.78, 0.78, 0.8)
const DARK := Color(0.08, 0.08, 0.09)
const LEATHER := Color(0.36, 0.2, 0.11)
const TIRE := Color(0.06, 0.06, 0.06)
const LAYER_ENEMY := 1 << 2

@export var max_engine_force := 2600.0
@export var max_brake := 35.0
@export var max_steer := 0.55
@export var top_speed := 28.0 ## m/s (~100 km/h)
@export var camera_distance := 6.0
@export var camera_height := 2.4

var driver: Node3D
var seat: Node3D
var _camera: Camera3D
var _bumper: Area3D
var _hit_cooldown := {}
var _hud_timer := 0.0

const WHEELBASE := 2.7
const TRACK := 1.36
const WHEEL_RADIUS := 0.42


func _ready() -> void:
	mass = 1050.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.15, 0) # baixo: não capota fácil
	collision_layer = 1
	collision_mask = 1 | LAYER_ENEMY
	add_to_group("interactable")
	add_to_group("vehicle")
	_build_collision()
	_build_body()
	_build_wheels()
	_build_bumper()
	seat = Node3D.new()
	seat.name = "DriverSeat"
	seat.position = Vector3(0.22, 0.17, -0.35) # banco do lado direito (altura do assento)
	seat.rotation = Vector3(0, PI, 0) # o player olha para -Z; o carro anda para +Z
	add_child(seat)
	_camera = Camera3D.new()
	_camera.name = "ChaseCamera"
	_camera.top_level = true
	_camera.far = 220.0
	_camera.fov = 70.0
	add_child(_camera)


# --- Interação ---------------------------------------------------------------

func get_interact_text() -> String:
	return "[E] Dirigir" if driver == null else ""


func interact(player: Node) -> void:
	if driver == null and player.has_method("enter_vehicle"):
		player.enter_vehicle(self)


func set_driver(who: Node3D) -> void:
	driver = who
	if who:
		_camera.global_transform = _camera_target()
		_camera.current = true
	else:
		_camera.current = false
		engine_force = 0.0
		steering = 0.0
		brake = max_brake * 0.5


## Onde o player sai: ao lado do banco (direita do carro).
func exit_point() -> Vector3:
	return global_transform * Vector3(1.35, 0.2, -0.35)


# --- Direção -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var forward := global_basis.z
	var speed := linear_velocity.dot(forward)
	if driver == null:
		engine_force = 0.0
		brake = max_brake * 0.3
		return
	var throttle := Input.get_axis("move_back", "move_forward")
	var steer_input := Input.get_axis("move_right", "move_left")
	# Menos esterço em alta velocidade (não capota na curva).
	var steer_limit := lerpf(max_steer, max_steer * 0.35, clampf(absf(speed) / top_speed, 0.0, 1.0))
	steering = move_toward(steering, steer_input * steer_limit, delta * 2.5)
	brake = 0.0
	if throttle > 0.0:
		engine_force = max_engine_force * throttle * (1.0 if speed < top_speed else 0.0)
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
	_hud_timer -= delta
	if _hud_timer <= 0.0 and driver.has_signal("weapon_changed"):
		_hud_timer = 0.2
		driver.weapon_changed.emit("Carro  %d km/h" % int(absf(speed) * 3.6))


func _process(delta: float) -> void:
	if driver == null:
		return
	# Câmera de perseguição suave, olhando um pouco à frente do carro.
	var target := _camera_target()
	_camera.global_position = _camera.global_position.lerp(target.origin, 1.0 - exp(-6.0 * delta))
	_camera.look_at(global_position + Vector3.UP * 1.0 + global_basis.z * 2.0)


func _camera_target() -> Transform3D:
	var back := -global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.1 else Vector3.BACK
	var pos := global_position + back * camera_distance + Vector3.UP * camera_height
	return Transform3D(Basis(), pos)


# --- Atropelar ---------------------------------------------------------------

func _build_bumper() -> void:
	_bumper = Area3D.new()
	_bumper.name = "Bumper"
	_bumper.collision_layer = 0
	_bumper.collision_mask = LAYER_ENEMY
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.4, 4.8)
	shape.shape = box
	shape.position = Vector3(0, 0.5, 0.1)
	_bumper.add_child(shape)
	add_child(_bumper)
	_bumper.body_entered.connect(_on_bumper_body)


func _on_bumper_body(body: Node) -> void:
	if not body.has_method("hit_by_vehicle"):
		return
	var speed := linear_velocity.length()
	var now := Time.get_ticks_msec()
	if speed < 2.5 or now - _hit_cooldown.get(body, -10000) < 700:
		return
	_hit_cooldown[body] = now
	body.hit_by_vehicle(linear_velocity, global_position)
	linear_velocity *= 0.93 # o impacto segura um pouco o carro


# --- Modelo ------------------------------------------------------------------

func _build_collision() -> void:
	var body := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.6, 3.7)
	body.shape = box
	body.position = Vector3(0, 0.4, -0.15)
	add_child(body)
	var hood := CollisionShape3D.new()
	var hood_box := BoxShape3D.new()
	hood_box.size = Vector3(0.85, 0.3, 1.5)
	hood.shape = hood_box
	hood.position = Vector3(0, 0.7, 1.0)
	add_child(hood)


func _build_body() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	# Banheira do chassi e capô comprido.
	_box(model, Vector3(0, 0.33, -0.2), Vector3(0.95, 0.5, 3.1), RED)
	_box(model, Vector3(0, 0.5, 1.0), Vector3(0.8, 0.44, 1.5), RED)
	_box(model, Vector3(0, 0.725, 1.0), Vector3(0.04, 0.01, 1.5), DARK) # dobradiça do capô
	for i in 7: # venezianas laterais do capô
		for side in [-1.0, 1.0]:
			_box(model, Vector3(side * 0.405, 0.52, 0.45 + i * 0.15), Vector3(0.01, 0.18, 0.05), DARK)
	# Grade vertical com moldura cromada e "ponta de coração" embaixo.
	_box(model, Vector3(0, 0.5, 1.78), Vector3(0.5, 0.74, 0.08), CHROME)
	_box(model, Vector3(0, 0.52, 1.82), Vector3(0.4, 0.62, 0.02), DARK)
	for i in 5:
		_box(model, Vector3(-0.16 + i * 0.08, 0.52, 1.835), Vector3(0.015, 0.6, 0.01), CHROME)
	_box(model, Vector3(0, 0.13, 1.78), Vector3(0.22, 0.22, 0.07), CHROME, Basis(Vector3.FORWARD, PI / 4))
	# Faróis redondos numa barra na frente da grade.
	_box(model, Vector3(0, 0.55, 1.95), Vector3(0.9, 0.03, 0.03), CHROME)
	for side in [-1.0, 1.0]:
		_cylinder(model, Vector3(side * 0.42, 0.56, 1.98), 0.11, 0.13, CHROME, Basis(Vector3.RIGHT, PI / 2))
		_cylinder(model, Vector3(side * 0.42, 0.56, 2.05), 0.09, 0.01, Color(1.0, 0.92, 0.7), Basis(Vector3.RIGHT, PI / 2), true)
	# Eixo dianteiro à mostra (suspensão alta).
	_box(model, Vector3(0, 0.0, WHEELBASE * 0.5), Vector3(TRACK, 0.06, 0.07), DARK)
	_box(model, Vector3(0, 0.0, -WHEELBASE * 0.5), Vector3(TRACK, 0.07, 0.08), DARK)
	# Painel, para-brisas pequenos ("aero screens"), bancos de couro e volante.
	_box(model, Vector3(0, 0.62, 0.2), Vector3(0.95, 0.16, 0.25), RED)
	_box(model, Vector3(0, 0.62, 0.08), Vector3(0.85, 0.12, 0.02), DARK)
	for side in [-1.0, 1.0]:
		_box(model, Vector3(side * 0.22, 0.8, 0.14), Vector3(0.3, 0.18, 0.015), Color(0.75, 0.85, 0.9, 0.35), Basis(Vector3.RIGHT, -0.25), true)
		_box(model, Vector3(side * 0.22, 0.42, -0.35), Vector3(0.36, 0.14, 0.42), LEATHER)
		_box(model, Vector3(side * 0.22, 0.66, -0.6), Vector3(0.36, 0.4, 0.1), LEATHER, Basis(Vector3.RIGHT, -0.2))
	_cylinder(model, Vector3(0.22, 0.75, -0.02), 0.17, 0.02, DARK, Basis(Vector3.RIGHT, PI / 2 - 0.5))
	# Traseira "rabo de barco" afinando, com estepe em pé.
	_box(model, Vector3(0, 0.36, -1.85), Vector3(0.85, 0.48, 0.5), RED)
	_box(model, Vector3(0, 0.33, -2.2), Vector3(0.62, 0.38, 0.4), RED)
	_box(model, Vector3(0, 0.29, -2.5), Vector3(0.36, 0.26, 0.3), RED)
	var spare := _wheel_visual()
	spare.position = Vector3(0, 0.72, -1.95)
	spare.rotation = Vector3(-0.45, PI / 2, 0)
	spare.scale = Vector3.ONE * 0.92
	model.add_child(spare)
	# Escapamento pelo lado esquerdo e roseta de número nas laterais.
	_cylinder(model, Vector3(-0.52, 0.28, -0.35), 0.05, 2.6, Color(0.25, 0.22, 0.2), Basis(Vector3.RIGHT, PI / 2))
	for side in [-1.0, 1.0]:
		_cylinder(model, Vector3(side * 0.48, 0.38, -1.35), 0.18, 0.01, Color(0.95, 0.95, 0.9), Basis(Vector3.FORWARD, PI / 2))
	# Para-lamas de moto acima de cada roda (arco de placas).
	for z in [WHEELBASE * 0.5, -WHEELBASE * 0.5]:
		for side in [-1.0, 1.0]:
			for k in 5:
				var angle := lerpf(-1.0, 1.1, k / 4.0)
				var pos := Vector3(side * TRACK * 0.5, 0.06 + cos(angle) * 0.56, z + sin(angle) * 0.56)
				_box(model, pos, Vector3(0.24, 0.025, 0.26), RED, Basis(Vector3.RIGHT, angle))


func _build_wheels() -> void:
	for z in [WHEELBASE * 0.5, -WHEELBASE * 0.5]:
		for side in [-1.0, 1.0]:
			var wheel := VehicleWheel3D.new()
			var front: bool = z > 0.0
			wheel.name = ("Front" if front else "Rear") + ("L" if side > 0 else "R")
			wheel.position = Vector3(side * TRACK * 0.5, 0.32, z)
			wheel.use_as_steering = front
			wheel.use_as_traction = not front # tração traseira
			wheel.wheel_radius = WHEEL_RADIUS
			wheel.wheel_rest_length = 0.32
			wheel.suspension_travel = 0.28 # curso longo: fora de estrada
			wheel.suspension_stiffness = 38.0
			wheel.suspension_max_force = 9000.0
			wheel.damping_compression = 2.2
			wheel.damping_relaxation = 3.0
			wheel.wheel_friction_slip = 2.6
			wheel.wheel_roll_influence = 0.25
			wheel.add_child(_wheel_visual())
			add_child(wheel)


## Roda raiada: pneu fino e alto, aro cromado, raios e cubo "knock-off".
func _wheel_visual() -> Node3D:
	var root := Node3D.new()
	var axis := Basis(Vector3.FORWARD, PI / 2) # cilindro deitado no eixo X
	_cylinder(root, Vector3.ZERO, WHEEL_RADIUS, 0.16, TIRE, axis)
	_cylinder(root, Vector3.ZERO, WHEEL_RADIUS - 0.07, 0.17, CHROME, axis)
	_cylinder(root, Vector3.ZERO, WHEEL_RADIUS - 0.1, 0.18, DARK, axis)
	for i in 8:
		_box(root, Vector3.ZERO, Vector3(0.012, (WHEEL_RADIUS - 0.08) * 2.0, 0.012), CHROME, Basis(Vector3.RIGHT, i * PI / 8.0))
	_cylinder(root, Vector3.ZERO, 0.06, 0.24, CHROME, axis)
	return root


func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY, transparent := false) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.transform = Transform3D(basis, pos)
	mesh.material_override = _material(color, transparent)
	parent.add_child(mesh)


func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, basis := Basis.IDENTITY, glow := false) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 12
	cylinder.rings = 1
	mesh.mesh = cylinder
	mesh.transform = Transform3D(basis, pos)
	var material := _material(color, false)
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.6
	mesh.material_override = material
	parent.add_child(mesh)


func _material(color: Color, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color == CHROME:
		material.metallic = 0.8
		material.roughness = 0.3
	elif color == RED:
		material.roughness = 0.45
	else:
		material.roughness = 0.8
	if transparent or color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
