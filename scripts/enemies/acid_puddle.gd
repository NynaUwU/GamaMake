class_name AcidPuddle
extends Node3D
## Poça de ácido do cuspidor: disco verde borbulhando que queima quem pisa.
## Só o host machuca (damaging = true); nos clientes é só o visual (o dano chega
## pela rede como qualquer outro). Some sozinha depois de "duration" segundos.
## launch(): a bola de cuspe voando em arco até o ponto, e a poça nasce lá.

const COLOR := Color(0.55, 0.85, 0.15)
const DPS := 9.0 ## dano por segundo dentro da poça

var radius := 2.2
var duration := 7.0
var damaging := false
var _age := 0.0
var _tick := 0.0
var _hiss := 0.0
var _disc: MeshInstance3D
var _mat: StandardMaterial3D
var _bubbles: CPUParticles3D


static func spawn(parent: Node, at: Vector3, radius_: float, duration_: float, damaging_: bool) -> AcidPuddle:
	var puddle := AcidPuddle.new()
	puddle.radius = radius_
	puddle.duration = duration_
	puddle.damaging = damaging_
	parent.add_child(puddle)
	puddle.global_position = at + Vector3.UP * 0.03
	return puddle


## Cuspe voando de "from" até "to" (arco); ao chegar vira poça.
static func launch(parent: Node, from: Vector3, to: Vector3, damaging_: bool) -> void:
	var glob := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.16, 0.16)
	glob.mesh = box
	glob.material_override = _glow_material(1.0)
	parent.add_child(glob)
	glob.global_position = from
	var flight := 0.35 + from.distance_to(to) / 22.0
	var arc := 1.0 + from.distance_to(to) * 0.12
	var tween := glob.create_tween()
	tween.tween_method(func(t: float):
		if is_instance_valid(glob):
			glob.global_position = from.lerp(to, t) + Vector3.UP * arc * 4.0 * t * (1.0 - t)
			glob.rotation = Vector3(t * 9.0, t * 7.0, 0.0), 0.0, 1.0, flight)
	tween.tween_callback(func():
		if not is_instance_valid(glob):
			return
		var host := glob.get_parent()
		glob.queue_free()
		Sfx.play_at("spit", to, 0.0, 0.8)
		ImpactFX.burst(host, to + Vector3.UP * 0.1, Vector3.UP, COLOR, 18, 3.0, 0.06)
		AcidPuddle.spawn(host, to, 2.2, 7.0, damaging_))


static func _glow_material(alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(COLOR, alpha)
	mat.emission_enabled = true
	mat.emission = COLOR * 0.6
	mat.roughness = 0.4
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _ready() -> void:
	# Disco baixo de poucas faces (estilo PS2) + borda irregular de blocos.
	_disc = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.03
	cyl.radial_segments = 10
	cyl.rings = 1
	_disc.mesh = cyl
	_mat = _glow_material(0.75)
	_disc.material_override = _mat
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)
	for k in 7:
		var blob := MeshInstance3D.new()
		var b := CylinderMesh.new()
		var r := radius * randf_range(0.25, 0.4)
		b.top_radius = r
		b.bottom_radius = r
		b.height = 0.035
		b.radial_segments = 7
		b.rings = 1
		blob.mesh = b
		blob.material_override = _mat
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * k / 7.0 + randf() * 0.4
		blob.position = Vector3(cos(a), 0.0, sin(a)) * radius * 0.85
		add_child(blob)
	_bubbles = CPUParticles3D.new()
	var bubble := BoxMesh.new()
	bubble.size = Vector3.ONE * 0.05
	_bubbles.mesh = bubble
	_bubbles.material_override = _glow_material(1.0)
	_bubbles.amount = 14
	_bubbles.lifetime = 0.8
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_bubbles.emission_box_extents = Vector3(radius * 0.7, 0.01, radius * 0.7)
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 10.0
	_bubbles.initial_velocity_min = 0.2
	_bubbles.initial_velocity_max = 0.5
	_bubbles.gravity = Vector3.ZERO
	add_child(_bubbles)
	Sfx.play_at("hiss", global_position, -4.0, 0.7)


func _physics_process(delta: float) -> void:
	_age += delta
	var left := duration - _age
	if left <= 0.0:
		queue_free()
		return
	if left < 1.5:
		_mat.albedo_color.a = 0.75 * left / 1.5
		scale = Vector3(1.0, 1.0, 1.0) * lerpf(0.6, 1.0, left / 1.5)
		_bubbles.emitting = false
	_hiss -= delta
	if _hiss <= 0.0:
		_hiss = 1.6
		Sfx.play_at("hiss", global_position, -10.0, 0.6)
	if not damaging:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	for group in [&"player", &"remote_player"]:
		for p in get_tree().get_nodes_in_group(group):
			if not p.has_method("take_damage") or (p.get("health") != null and p.health <= 0.0):
				continue
			var off: Vector3 = p.global_position - global_position
			if absf(off.y) < 1.2 and Vector2(off.x, off.z).length() < radius * scale.x:
				p.take_damage(DPS * 0.5)
