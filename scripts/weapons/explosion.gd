class_name Explosion
extends Node3D
## Explosão mágica: dano com queda pela distância, ragdoll voando para os
## zumbis, empurrão em objetos físicos e um flash roxo com faíscas.

const PROP_MASK := 1 | (1 << 5) # mundo e itens (só os RigidBody3D reagem)
const COLOR_CORE := Color(1.0, 0.85, 1.0)
const COLOR_GLOW := Color(0.65, 0.3, 1.0)

var cosmetic := false ## explosão de um míssil de outro jogador: não dá dano


## kill_radius: quem estiver a essa distância do impacto morre na hora (e despedaça).
func detonate(radius: float, damage: float, force: float, kill_radius := 1.3) -> void:
	if not cosmetic:
		_hit_enemies(radius, damage, force, kill_radius)
	_push_props(radius, force)
	_feedback_player(radius)
	_spawn_visuals(radius)
	get_tree().create_timer(1.5).timeout.connect(queue_free)


func _hit_enemies(radius: float, damage: float, force: float, kill_radius: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.has_method("take_explosion"):
			continue
		var distance := _distance_to_body(enemy)
		if distance > radius:
			continue
		var falloff := 1.0 - distance / radius
		var hit_damage := damage * falloff
		if distance <= kill_radius:
			hit_damage = INF # pegou em cheio
		enemy.take_explosion(global_position, hit_damage, force * (0.4 + 0.6 * falloff))


## Distância até o ponto mais próximo do corpo (segmento dos pés à cabeça,
## ou o quadril se estiver caído): explosão no pé conta como acerto em cheio.
func _distance_to_body(enemy: Node3D) -> float:
	if enemy.ragdoll.is_ragdolling():
		return global_position.distance_to(enemy.ragdoll.get_root_position())
	var feet: Vector3 = enemy.global_position
	var height := clampf(global_position.y - feet.y, 0.0, 1.7)
	return global_position.distance_to(feet + Vector3.UP * height)


func _push_props(radius: float, force: float) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = PROP_MASK
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var body := result.collider as RigidBody3D
		if body == null:
			continue
		var away := body.global_position - global_position
		var falloff := 1.0 - clampf(away.length() / radius, 0.0, 1.0)
		var dir := (away.normalized() + Vector3.UP * 0.6).normalized()
		body.apply_central_impulse(dir * force * 0.08 * falloff * body.mass / 10.0)


func _feedback_player(radius: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("explosion_feedback"):
		player.explosion_feedback(global_position, radius)


func _spawn_visuals(radius: float) -> void:
	# Bola de energia que cresce e some.
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	ball.mesh = sphere
	var ball_mat := StandardMaterial3D.new()
	ball_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball_mat.albedo_color = COLOR_GLOW
	ball.material_override = ball_mat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.scale = Vector3.ONE * 0.2
	add_child(ball)
	var tween := create_tween().set_parallel()
	tween.tween_property(ball, "scale", Vector3.ONE * radius * 0.7, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ball_mat, "albedo_color:a", 0.0, 0.35)

	# Flash de luz.
	var light := OmniLight3D.new()
	light.light_color = COLOR_GLOW
	light.light_energy = 8.0
	light.omni_range = radius * 3.0
	add_child(light)
	tween.tween_property(light, "light_energy", 0.0, 0.5)

	# Faíscas.
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.amount = 48
	sparks.lifetime = 0.7
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 4.0
	sparks.initial_velocity_max = 10.0
	sparks.gravity = Vector3(0, -9.0, 0)
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.4
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3.ONE * 0.06
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = COLOR_CORE
	spark_mesh.material = spark_mat
	sparks.mesh = spark_mesh
	add_child(sparks)
	sparks.emitting = true
