class_name AirdropFX
extends Node3D
## Airdrop da onda vencida: caixa militar que desce de paraquedas e um sinal
## vermelho pulsando (lâmpada em cima da caixa) até alguém esvaziar a caixa.

const FALL_HEIGHT := 45.0
const FALL_SPEED := 7.0

var key := ""
var _crate: Node3D
var _chute: Node3D
var _beam: MeshInstance3D # a lâmpada
var _beam_mat: StandardMaterial3D
var _light: OmniLight3D
var _time := 0.0
var _check := 0.0
var _landed := false


func setup(key_: String) -> void:
	key = key_
	_crate = Node3D.new()
	add_child(_crate)
	var mb := MeshBuilder.new()
	var olive := Color(0.3, 0.34, 0.2)
	mb.color(olive)
	mb.box(Vector3(0, 0.42, 0), Vector3(1.1, 0.84, 1.1))
	mb.color(olive.darkened(0.3))
	for y in [0.08, 0.76]:
		mb.box(Vector3(0, y, 0), Vector3(1.14, 0.08, 1.14)) # cintas
	mb.color(Color(0.85, 0.82, 0.7))
	mb.box(Vector3(0, 0.45, 0.556), Vector3(0.5, 0.18, 0.01)) # placa
	mb.color(Color(0.75, 0.1, 0.08))
	mb.box(Vector3(0, 0.45, 0.562), Vector3(0.18, 0.06, 0.01)) # cruz
	mb.box(Vector3(0, 0.45, 0.562), Vector3(0.06, 0.16, 0.01))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	_crate.add_child(mesh)
	# Paraquedas: cúpula de gomos laranja e branco presa por cordas.
	_chute = Node3D.new()
	_crate.add_child(_chute)
	var cb := MeshBuilder.new()
	for k in 8:
		cb.color(Color(0.9, 0.45, 0.15) if k % 2 == 0 else Color(0.9, 0.88, 0.82))
		var a := k * TAU / 8.0
		cb.box(Vector3(cos(a) * 1.6, 4.2 - 0.25, sin(a) * 1.6), Vector3(1.3, 0.12, 1.3))
	cb.color(Color(0.9, 0.88, 0.82))
	cb.box(Vector3(0, 4.25, 0), Vector3(1.6, 0.14, 1.6))
	cb.color(Color(0.2, 0.2, 0.2))
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		cb.tube(PackedVector3Array([Vector3(cos(a) * 0.5, 0.84, sin(a) * 0.5), Vector3(cos(a) * 2.0, 3.9, sin(a) * 2.0)]), 0.015, 4)
	var chute_mesh := MeshInstance3D.new()
	chute_mesh.mesh = cb.finish(PlacedObject._mat(), false)
	_chute.add_child(chute_mesh)
	# Sinal: lâmpada vermelha em cima da caixa, piscando (brilha sozinha e acende o chão em volta).
	var bulb := SphereMesh.new()
	bulb.radius = 0.09
	bulb.height = 0.18
	bulb.radial_segments = 8
	bulb.rings = 4
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.albedo_color = Color(1.0, 0.12, 0.06)
	_beam = MeshInstance3D.new()
	_beam.mesh = bulb
	_beam.material_override = _beam_mat
	_beam.position.y = 0.95
	_crate.add_child(_beam)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.15, 0.08)
	_light.omni_range = 12.0
	_light.position.y = 1.15
	_crate.add_child(_light)
	_crate.position.y = FALL_HEIGHT


func _process(delta: float) -> void:
	_time += delta
	if not _landed:
		_crate.position.y = maxf(0.0, _crate.position.y - FALL_SPEED * delta)
		_crate.rotation.y += delta * 0.3
		if _crate.position.y <= 0.0:
			_landed = true
			_chute.visible = false # paraquedas murcha e some
			Sfx.play_at("thud", global_position, 6.0, 0.6)
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	_beam_mat.albedo_color = Color(1.0, 0.12, 0.06).lerp(Color(0.25, 0.03, 0.02), 1.0 - pulse)
	_light.light_energy = 0.3 + 4.0 * pulse
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_beam.visible = not _emptied()
		_light.visible = _beam.visible


## Já foi aberta e não sobrou nada: apaga o sinal.
func _emptied() -> bool:
	if ContainerManager.i == null:
		return false
	var slots: Array = ContainerManager.i.slots_of(key)
	return not slots.is_empty() and slots.all(func(s): return s.is_empty())
