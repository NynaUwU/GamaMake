class_name StationModels
extends RefCounted
## Fogo das estações (chamas, luz que tremula, brasa) e o acender/apagar.
## Os modelos ficam em ObjectModels (Tier 0-2) e SteamModels (Tier 3).

const FIRE := Color(1.0, 0.55, 0.15)

static var _glow: StandardMaterial3D


## Chamas (partículas) + luz alaranjada que tremula.
static func _fire(obj: Node3D, at: Vector3, radius: float, strength: float) -> void:
	var flames := CPUParticles3D.new()
	flames.amount = 26
	flames.lifetime = 0.7
	flames.position = at
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = maxf(radius, 0.05)
	flames.direction = Vector3.UP
	flames.spread = 12.0
	flames.gravity = Vector3(0, 1.2, 0)
	flames.initial_velocity_min = 0.3
	flames.initial_velocity_max = 0.7
	flames.scale_amount_min = 0.6
	flames.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	flames.scale_amount_curve = curve
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.09 * strength
	box.material = _glow_mat()
	flames.mesh = box
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.85, 0.3))
	gradient.set_color(1, Color(0.8, 0.2, 0.05))
	flames.color_ramp = gradient
	obj.add_child(flames)
	_register_fire(obj, flames)
	var light := Flicker.new()
	light.position = at + Vector3.UP * 0.4
	light.light_color = Color(1.0, 0.6, 0.3)
	light.omni_range = 7.0 * strength
	light.base_energy = 1.6 * strength
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 50.0
	obj.add_child(light)
	_register_fire(obj, light)


## Guarda as peças do fogo (chamas, luz, brasa) para acender/apagar depois.
static func _register_fire(obj: Node3D, node: Node3D) -> void:
	var list: Array = obj.get_meta("fire_nodes", [])
	list.append(node)
	obj.set_meta("fire_nodes", list)


## Acende ou apaga o fogo de um objeto (fogueira, fornalhas, forno, defumador).
static func set_lit(obj: Node3D, lit: bool) -> void:
	if obj.has_meta("lit") and obj.get_meta("lit") == lit:
		return
	obj.set_meta("lit", lit)
	for node in obj.get_meta("fire_nodes", []):
		if is_instance_valid(node):
			node.visible = lit
			if node is CPUParticles3D:
				node.emitting = lit


static func _glow_mat() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.vertex_color_use_as_albedo = true
		_glow.albedo_color = FIRE
	return _glow


class Flicker extends OmniLight3D:
	var base_energy := 1.5
	var _t := randf() * 10.0

	func _process(delta: float) -> void:
		_t += delta
		light_energy = base_energy * (0.85 + 0.15 * sin(_t * 13.0) * sin(_t * 5.3 + 1.0))
