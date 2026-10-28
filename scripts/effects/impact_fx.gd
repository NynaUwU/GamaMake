class_name ImpactFX
## Efeitos de impacto reutilizáveis: respingo de sangue, faíscas, rastro de bala.
## Tudo é criado por código (partículas em CPU, funcionam em qualquer renderer).

const BLOOD := Color(0.45, 0.03, 0.03)
const SPARK := Color(1.0, 0.85, 0.5)


## Explosão curta de partículas. normal = para onde elas saem.
static func burst(parent: Node, position: Vector3, normal: Vector3, color: Color,
		amount := 16, speed := 3.0, size := 0.05, gravity := 9.8) -> CPUParticles3D:
	var particles := _make_particles(color, size)
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.6
	particles.direction = normal if normal.length() > 0.01 else Vector3.UP
	particles.spread = 45.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector3.DOWN * gravity
	parent.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles


## Jato contínuo (ex.: sangue saindo do toco) que para depois de "duration".
static func spurt(parent: Node3D, local_position: Vector3, color: Color, duration := 1.2) -> void:
	var particles := _make_particles(color, 0.04)
	particles.amount = 24
	particles.lifetime = 0.5
	particles.local_coords = false
	particles.direction = Vector3.UP
	particles.spread = 35.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.5
	particles.gravity = Vector3.DOWN * 9.8
	parent.add_child(particles)
	particles.position = local_position
	particles.emitting = true
	parent.get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(particles):
			particles.emitting = false
			particles.get_tree().create_timer(0.6).timeout.connect(particles.queue_free))


## Rastro de bala: linha fina que some rápido.
static func tracer(parent: Node, from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.3:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.012, length)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.9, 0.6, 0.7)
	mesh.material = material
	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(line)
	line.global_transform = Transform3D(Basis.looking_at(to - from), (from + to) * 0.5)
	var tween := line.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.06)
	tween.tween_callback(line.queue_free)


static func _make_particles(color: Color, size: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.4
	mesh.material = material
	particles.mesh = mesh
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	return particles
