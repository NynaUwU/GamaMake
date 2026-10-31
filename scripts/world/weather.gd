class_name Weather
extends Node
## Clima (nó "Weather" da cena principal): chuva e vento, de 0 a 1.
## O host sorteia o próximo tempo a cada 2-5 min e manda para todos; vai no save.
##   chuva  enche os coletores, escurece o céu, gotas caindo em volta da câmera e som
##   vento  mais forte com chuva; vai mover os moinhos de vento (Tier 2)

static var i: Weather

var rain := 0.0 ## intensidade atual (suaviza até o alvo)
var wind := 0.3
var target_rain := 0.0
var target_wind := 0.3
var _timer := 150.0
var _drops: CPUParticles3D
var _sound: AudioStreamPlayer
var _drop_mat: StandardMaterial3D


func _enter_tree() -> void:
	i = self


func _exit_tree() -> void:
	if i == self:
		i = null


func _ready() -> void:
	add_to_group("persist")
	_drops = CPUParticles3D.new()
	_drops.amount = 900
	_drops.lifetime = 0.9
	_drops.local_coords = false
	_drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_drops.emission_box_extents = Vector3(14, 0.5, 14)
	_drops.direction = Vector3.DOWN
	_drops.spread = 3.0
	_drops.gravity = Vector3(0, -20, 0)
	_drops.initial_velocity_min = 12.0
	_drops.initial_velocity_max = 15.0
	var streak := BoxMesh.new()
	streak.size = Vector3(0.012, 0.42, 0.012)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.7, 0.75, 0.85, 0.45)
	streak.material = mat
	_drop_mat = mat
	_drops.mesh = streak
	_drops.emitting = false
	add_child(_drops)
	_sound = AudioStreamPlayer.new()
	_sound.stream = Sfx.stream("rain")
	_sound.volume_db = -80.0
	add_child(_sound)


func _process(delta: float) -> void:
	if Net.i.is_host():
		_timer -= delta
		if _timer <= 0.0:
			_roll()
	rain = move_toward(rain, target_rain, delta * 0.04) # ~25 s para engrossar/parar
	wind = move_toward(wind, target_wind, delta * 0.03)
	_update_fx()


## Host: próximo tempo. ~35% de chance de chover; vento mais forte com chuva.
func _roll() -> void:
	_timer = randf_range(120.0, 300.0)
	target_rain = randf_range(0.4, 1.0) if randf() < 0.35 else 0.0
	target_wind = clampf(randf_range(0.05, 0.7) + target_rain * 0.3, 0.0, 1.0)
	if Net.i.online():
		Net.i.broadcast_system_state(name, save_data())


func _update_fx() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera:
		_drops.global_position = camera.global_position + Vector3.UP * 7.0
	_drops.emitting = rain > 0.05
	_drop_mat.albedo_color.a = 0.15 + 0.35 * rain # garoa quase some; temporal fica bem visível
	if rain > 0.02:
		if not _sound.playing:
			_sound.play()
		_sound.volume_db = linear_to_db(rain) - 8.0
	elif _sound.playing:
		_sound.stop()


# --- Salvar / rede ---------------------------------------------------------------

func persist_key() -> String:
	return "weather"


func save_data() -> Dictionary:
	return {"rain": target_rain, "wind": target_wind, "timer": _timer}


func load_data(data: Dictionary) -> void:
	target_rain = data.get("rain", 0.0)
	target_wind = data.get("wind", 0.3)
	_timer = data.get("timer", 150.0)


func net_sync_to(peer: int) -> void:
	Net.i.send_system_state(peer, name, save_data())
