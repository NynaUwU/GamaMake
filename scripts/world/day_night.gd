class_name DayNight
extends Node
## Ciclo de dia e noite (nó "DayNight" da cena principal).
## Um dia inteiro dura DAY_LENGTH segundos: dia das 6h às 20h, noite das 20h
## às 6h (noite ~ 1/3 do tempo). O sol gira, o céu/neblina escurecem e à noite
## entra uma lua azulada fraca. Os postes acendem ao anoitecer.
## O host manda a hora; ela vai no save. À noite o HordeManager solta hordas.

signal nightfall
signal dawn

const DAY_LENGTH := 20.0 * 60.0
const NIGHT_START := 20.0
const NIGHT_END := 6.0

static var i: DayNight

var hour := 8.0
var day := 1
## 0 = dia claro, 1 = noite fechada (transição suave no fim da tarde/amanhecer).
var night := 0.0
## Multiplicador da cor da neblina (BiomeAtmosphere) e da força do sol.
var fog_tint := Color.WHITE
var sun_factor := 1.0

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky: ShaderMaterial
var _cloud_offset := Vector2.ZERO
var _broadcast := 0.0
var _was_night := false

const DAY := {"top": Color(0.3, 0.45, 0.68), "horizon": Color(0.74, 0.7, 0.62), "ambient": 0.7, "sun": Color(1.0, 0.9, 0.76)}
const DUSK := {"top": Color(0.2, 0.2, 0.34), "horizon": Color(0.86, 0.5, 0.32), "ambient": 0.5, "sun": Color(1.0, 0.58, 0.36)}
const NIGHT := {"top": Color(0.012, 0.018, 0.04), "horizon": Color(0.05, 0.06, 0.1), "ambient": 0.14, "sun": Color(0.5, 0.6, 0.9)}


func _enter_tree() -> void:
	i = self


func _exit_tree() -> void:
	if i == self:
		i = null


func _ready() -> void:
	add_to_group("persist")
	var main := get_parent()
	_sun = main.get_node_or_null("Sun") as DirectionalLight3D
	var world_env := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env:
		_env = world_env.environment
		if _env.sky:
			# Céu próprio (shaders/sky.gdshader): sol, lua, estrelas e nuvens.
			_sky = Look.sky_material()
			_env.sky.sky_material = _sky
	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.light_color = Color(0.55, 0.65, 1.0)
	_moon.shadow_enabled = false
	_moon.rotation = Vector3(-0.9, -0.6, 0)
	main.add_child.call_deferred(_moon)
	_was_night = is_night()
	_apply()


func is_night() -> bool:
	return hour >= NIGHT_START or hour < NIGHT_END


func clock_text() -> String:
	return "Dia %d  %02d:%02d" % [day, int(hour), int(fmod(hour, 1.0) * 60.0)]


func _process(delta: float) -> void:
	hour += 24.0 * delta / (WorldSettings.get_value("day_length") * 60.0) # menu "Criar mundo" (padrão DAY_LENGTH)
	if hour >= 24.0:
		hour -= 24.0
		day += 1
	var now := is_night()
	if now != _was_night:
		_was_night = now
		if now:
			nightfall.emit()
			_notify("Anoiteceu (dia %d). Hordas à solta: procure abrigo ou luz." % day)
		else:
			dawn.emit()
			_notify("Amanheceu. Sobreviveu à noite %d." % (day - 1 if hour < 12.0 else day))
	# Nuvens andam com o vento.
	var wind := Weather.i.wind if Weather.i else 0.3
	_cloud_offset += Vector2(1.0, 0.35) * (0.0015 + wind * 0.006) * delta
	_apply()
	# Host: acerta o relógio de todo mundo de vez em quando.
	if Net.i.online() and Net.i.is_host():
		_broadcast -= delta
		if _broadcast <= 0.0:
			_broadcast = 15.0
			Net.i.broadcast_system_state(name, save_data())


func _notify(text: String) -> void:
	var world: Node = Net.i.world
	if world and world.get("player"):
		world.player.notify.emit(text)


func _apply() -> void:
	# Noite: escurece das 18:30 às 20:30 e clareia das 5:00 às 7:00.
	night = smoothstep(18.5, 20.5, hour) if hour > 12.0 else 1.0 - smoothstep(5.0, 7.0, hour)
	# Crepúsculo: sol baixo (perto das 6h e das 19h).
	var dusk := maxf(1.0 - absf(hour - 19.0) / 1.6, 1.0 - absf(hour - 6.2) / 1.4)
	dusk = clampf(dusk, 0.0, 1.0) * (1.0 - night)
	var palette := _mix(_mix(DAY, DUSK, dusk), NIGHT, night)
	# Chuva: céu cinza, menos sol e menos luz ambiente.
	var wet := Weather.i.rain if Weather.i else 0.0
	if wet > 0.0:
		var grey := {"top": Color(0.3, 0.32, 0.35) * (1.0 - night * 0.9), "horizon": Color(0.45, 0.46, 0.47) * (1.0 - night * 0.9),
			"ambient": palette.ambient * 0.75, "sun": palette.sun}
		palette = _mix(palette, grey, wet * 0.85)
	sun_factor = (1.0 - night) * lerpf(1.0, 0.6, dusk) * lerpf(1.0, 0.35, wet)
	fog_tint = Color(1, 1, 1).lerp(Color(1.0, 0.75, 0.6), dusk).lerp(Color(0.1, 0.11, 0.16), night)
	if _sky:
		_sky.set_shader_parameter("top_color", palette.top)
		_sky.set_shader_parameter("horizon_color", palette.horizon)
		_sky.set_shader_parameter("ground_color", palette.horizon.darkened(0.6))
		_sky.set_shader_parameter("sun_color", palette.sun)
		_sky.set_shader_parameter("sun_power", lerpf(1.0, 0.25, wet))
		_sky.set_shader_parameter("night", night)
		_sky.set_shader_parameter("cloud_offset", _cloud_offset)
		_sky.set_shader_parameter("cloud_cover", lerpf(0.34, 0.92, wet))
		_sky.set_shader_parameter("cloud_color", Color(0.96, 0.95, 0.93).lerp(Color(0.48, 0.5, 0.53), wet))
	if _env:
		_env.ambient_light_energy = palette.ambient
		_env.ambient_light_color = palette.horizon.lerp(Color(0.5, 0.5, 0.5), 0.4)
	if _sun:
		# Sol nasce no leste (6h), passa alto ao meio-dia e se põe no oeste (18h+).
		var a := (hour - 6.0) / 12.0 * PI
		var dir := Vector3(cos(a), sin(a), 0.35).normalized() # de onde vem a luz
		if dir.y < 0.05:
			dir = Vector3(dir.x, 0.05, dir.z).normalized()
		_sun.global_basis = Basis.looking_at(-dir, Vector3.UP)
		if _sky:
			_sky.set_shader_parameter("sun_dir", dir)
		_sun.light_color = palette.sun
		_sun.light_energy = lerpf(1.0, 0.35, wet)
		_sun.visible = sun_factor > 0.02
		_sun.shadow_enabled = sun_factor > 0.15 and wet < 0.6 and Look.shadows_on()
	if _moon:
		if _sky and _moon.is_inside_tree():
			_sky.set_shader_parameter("moon_dir", _moon.global_basis.z)
		_moon.light_energy = 0.22 * night
		_moon.visible = night > 0.02


static func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return {"top": a.top.lerp(b.top, t), "horizon": a.horizon.lerp(b.horizon, t),
		"ambient": lerpf(a.ambient, b.ambient, t), "sun": a.sun.lerp(b.sun, t)}


# --- Salvar / rede ---------------------------------------------------------------------

func persist_key() -> String:
	return "day_night"


func save_data() -> Dictionary:
	return {"hour": hour, "day": day}


func load_data(data: Dictionary) -> void:
	hour = data.get("hour", 8.0)
	day = data.get("day", 1)
	_was_night = is_night()
	_apply()


func net_sync_to(peer: int) -> void:
	Net.i.send_system_state(peer, name, save_data())
