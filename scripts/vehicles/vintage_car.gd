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

const WHEELBASE := 2.7
const TRACK := 1.36
const WHEEL_RADIUS := 0.42
const FLOOR_Y := 0.1 ## fundo da carroceria (vão livre alto)
const SPEEDO_MAX := 140.0 ## km/h no fim da escala

@export var max_engine_force := 2600.0
@export var max_brake := 35.0
@export var max_steer := 0.55
@export var top_speed := 28.0 ## m/s (~100 km/h)

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


func _ready() -> void:
	mass = 1050.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.15, 0) # baixo: não capota fácil
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
	seat.position = Vector3(-0.22, 0.17, -0.38) # banco da direita (o carro anda para +Z: direita = -X)
	seat.rotation = Vector3(0, PI, 0) # o player olha para -Z; o carro anda para +Z
	add_child(seat)


# --- Interação ---------------------------------------------------------------

func get_interact_text() -> String:
	return "[E] Dirigir" if driver == null else ""


func interact(player: Node) -> void:
	if driver == null and player.has_method("enter_vehicle"):
		player.enter_vehicle(self)


func set_driver(who: Node3D) -> void:
	driver = who
	set_see_through(who != null)
	set_headlights(who != null) # entra: faróis acendem; sai: apagam
	if who == null:
		engine_force = 0.0
		steering = 0.0
		brake = max_brake * 0.5


## Onde o player sai: ao lado do banco (direita do carro).
func exit_point() -> Vector3:
	return global_transform * Vector3(-1.35, 0.2, -0.38)


## Pontos do aro do volante (mundo) para as mãos: 10h e 2h, girando com a direção.
func hand_points() -> Array:
	var points := []
	for a in [0.95, -0.95]: # esquerda, direita do motorista (local +X = esquerda dele; o nó já gira com a direção)
		points.append(steering_wheel.global_transform * Vector3(sin(a) * 0.18, cos(a) * 0.18, 0))
	return points


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


func _process(_delta: float) -> void:
	# Volante gira com a direção; ponteiro do velocímetro segue a velocidade.
	steering_wheel.rotation.z = -steering * 2.2
	var kmh := absf(linear_velocity.dot(global_basis.z)) * 3.6
	_needle.rotation.z = lerpf(2.3, -2.3, clampf(kmh / SPEEDO_MAX, 0.0, 1.0))


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


# --- Modelo ------------------------------------------------------------------

func _build_model() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
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
	_build_cockpit(model)
	_build_headlights(model)
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
	for z in [WHEELBASE * 0.5, -WHEELBASE * 0.5]:
		var front: bool = z > 0.0
		for side in [-1.0, 1.0]:
			var x0: float = side * TRACK * 0.5
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
	for z in [WHEELBASE * 0.5, -WHEELBASE * 0.5]:
		dark.tube(PackedVector3Array([Vector3(-TRACK * 0.5, 0.08, z), Vector3(TRACK * 0.5, 0.08, z)]), 0.035, 6)
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


## Painel (só velocímetro), volante e para-brisas pequenos.
func _build_cockpit(model: Node3D) -> void:
	# Painel acompanha o arco da carroceria (por dentro do cockpit).
	var panel := MeshBuilder.new()
	var arc := MeshBuilder.ring(Vector3(0, 0.44, 0.19), 0.44, 0.255, 3.0, 16, 0.5, 0.0, PI)
	var bottom := PackedVector3Array()
	for p in arc:
		bottom.append(Vector3(p.x, 0.5, 0.19))
	panel.sheet([bottom, arc])
	_add(model, panel.finish(_material("panel", ALUMINIUM, 0.45, 0.6, true)))
	# Velocímetro na frente do motorista (lado direito).
	var gauge := Node3D.new()
	gauge.name = "Speedometer"
	# No centro do painel, um pouco abaixo da borda, virado de leve para o motorista.
	gauge.position = Vector3(0.0, 0.7, 0.16) # 1,5 cm à frente do painel (evita z-fighting)
	gauge.rotation = Vector3(-0.3, PI + 0.3, 0) # mostrador virado para o motorista (-Z)
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
		label.text = str(i * 20)
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
	var column_base := Vector3(-0.22, 0.52, 0.32)
	steering_wheel.position = Vector3(-0.22, 0.68, 0.07)
	steering_wheel.rotation = Vector3(0.57, 0, 0) # topo inclinado para o painel, perpendicular à coluna
	model.add_child(steering_wheel)
	var wheel := MeshBuilder.new()
	wheel.torus(0.18, 0.014, 20, 6, Basis(Vector3.RIGHT, PI / 2))
	for a in [PI / 2, PI * 7 / 6, PI * 11 / 6]:
		wheel.tube(PackedVector3Array([Vector3.ZERO, Vector3(cos(a), sin(a), 0) * 0.175]), 0.007, 4)
	wheel.lathe(PackedVector2Array([Vector2(0.03, -0.01), Vector2(0.03, 0.01), Vector2(0.015, 0.02)]), 10, Basis(Vector3.RIGHT, PI / 2))
	_add(steering_wheel, wheel.finish(_material("wheel_rim", DARK, 0.6, 0.2)))
	var column := MeshBuilder.new()
	column.tube(PackedVector3Array([column_base, steering_wheel.position + Vector3(0, -0.01, 0.02)]), 0.018, 6)
	_add(model, column.finish(_material("column", DARK, 0.6, 0.3)))


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
			wheel.wheel_friction_slip = 2.2 # escorrega um pouco antes de tombar
			wheel.wheel_roll_influence = 0.25
			wheel.add_child(_wheel_node())
			add_child(wheel)


## Roda raiada: pneu (toro), aro cromado, 16 raios cruzados e cubo "knock-off".
func _wheel_node() -> Node3D:
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


func _material(key: String, color: Color, roughness: float, metallic: float, double_sided := false) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	# Pós-apocalíptico: pintura e cromados gastos, quase sem reflexo.
	material.albedo_color = color.darkened(0.12) if key in ["paint", "chrome"] else color
	material.roughness = maxf(roughness, 0.78)
	material.metallic = minf(metallic, 0.25)
	if double_sided:
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
