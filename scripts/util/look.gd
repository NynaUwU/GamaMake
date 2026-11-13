class_name Look
extends RefCounted
## Visual do jogo num lugar só:
##   - qualidade gráfica Baixa / Média / Alta (salva em user://graphics.cfg):
##     sombras, SSAO, brilho (glow), grama densa e partículas;
##   - materiais "PS2" com textura de detalhe 64x64 pixelada escolhida pela cor
##     (madeira, pedra, grão fino) e cor por vértice em sRGB (sem isso o Forward+
##     deixava tudo pálido);
##   - céu (shaders/sky.gdshader), tonemap AgX, brilho do fogo e das luzes.
## Quem quiser saber quando a qualidade muda entra no grupo "look_quality" e
## implementa apply_quality().

enum Q { LOW, MEDIUM, HIGH }
const NAMES := ["Baixa", "Média", "Alta"]
const CONFIG := "user://graphics.cfg"
const SURFACE_SHADER := preload("res://shaders/ps2_surface.gdshader")
const SURFACE_SHADER_2S := preload("res://shaders/ps2_surface_2s.gdshader")
const FOLIAGE_SHADER := preload("res://shaders/foliage.gdshader")
const BLADES_SHADER := preload("res://shaders/grass_blades.gdshader")
const GLOW_SHADER := preload("res://shaders/fire_glow.gdshader")
const SKY_SHADER := preload("res://shaders/sky.gdshader")

## Menu de gráficos (GraphicsPanel): cada opção [chave, nome, valores [[texto, valor], ...]
## (vazio = liga/desliga), dica]. Ficam em user://graphics.cfg, seção "video".
const OPTIONS := [
	["shadows", "Sombras", [["Desligadas", 0], ["Baixas", 1], ["Médias", 2], ["Altas", 3]], "Qualidade e alcance da sombra do sol"],
	["ssao", "Cantos escuros (SSAO)", [], "Sombra de contato no pé das paredes, cantos e embaixo das coisas"],
	["glow", "Brilho do fogo e das luzes", [], "Fogo, tochas, lâmpadas e olhos dos zumbis brilham"],
	["detail", "Textura PS2", [], "Grão pixelado de madeira, pedra e terra nas superfícies (desligado: cor lisa, como antes)"],
	["color_fix", "Cores fortes", [], "Desligado: as cores lavadas de antes da atualização gráfica"],
	["tonemap", "Tom da imagem", [["AgX (novo)", 0], ["Filmic (antes)", 1]], "Como a luz forte vira cor na tela"],
	["grass", "Grama densa", [["Sem", 0], ["Pouca", 1], ["Média", 2], ["Muita", 3]], "Capim com vento perto de você (pesa na placa de vídeo)"],
	["particles", "Partículas do clima", [["Sem", 0], ["Poucas", 1], ["Muitas", 2]], "Respingos da chuva, ciscos e areia soprada"],
	["lines", "Resolução do 3D", [["Retrô (540 linhas)", 540], ["720 linhas", 720], ["1080 linhas", 1080], ["Da janela", 0]], "O 3D é desenhado nessa altura e ampliado em pixels nítidos; menus e HUD ficam na resolução da janela"],
	["retro", "Filtro retrô", [], "Cores de 16 bits com pontilhado (como placa de vídeo antiga)"],
	["vignette", "Vinheta", [], "Bordas da tela um pouco mais escuras"],
	["view", "Distância de visão", [["Curta", 0], ["Normal", 1], ["Longa", 2]], "Até onde a neblina deixa ver e o terreno é carregado"],
	["fov", "Campo de visão", [["65°", 65], ["75°", 75], ["85°", 85], ["95°", 95]], "Ângulo da câmera em primeira pessoa"],
	["grid", "Grade do terreno", [], "Mostra os blocos de 0,4 m do chão (os mesmos dos quadradinhos da parede)"],
	["vsync", "VSync", [], "Sincroniza com o monitor (sem rasgar a imagem)"],
	["fullscreen", "Tela cheia", [], ""],
	["fps", "Limite de FPS", [["Sem limite", 0], ["30", 30], ["60", 60], ["120", 120], ["144", 144]], ""],
]
## Predefinições: ajustam as opções de qualidade (as de tela ficam como estão).
const PRESET_ORDER := ["classic", "low", "medium", "high"]
const PRESET_NAMES := {"classic": "Clássico (como antes)", "low": "Baixa", "medium": "Média", "high": "Alta", "custom": "Personalizado"}
const PRESET_VALUES := {
	"classic": {"shadows": 2, "ssao": false, "glow": false, "detail": false, "color_fix": false, "tonemap": 1, "grass": 0, "particles": 0},
	"low": {"shadows": 1, "ssao": false, "glow": false, "detail": true, "color_fix": true, "tonemap": 0, "grass": 0, "particles": 0},
	"medium": {"shadows": 2, "ssao": true, "glow": true, "detail": true, "color_fix": true, "tonemap": 0, "grass": 2, "particles": 1},
	"high": {"shadows": 3, "ssao": true, "glow": true, "detail": true, "color_fix": true, "tonemap": 0, "grass": 3, "particles": 2},
}
const DEFAULTS := {"preset": "medium", "shadows": 2, "ssao": true, "glow": true, "detail": true, "color_fix": true, "tonemap": 0,
	"grass": 2, "particles": 1, "lines": 540, "retro": true, "vignette": true, "view": 1, "fov": 75, "grid": false,
	"vsync": true, "fullscreen": false, "fps": 0}
const VIEW_MULT := [0.7, 1.0, 1.45]
## Sombra por nível (0 = sem sombra do sol).
const SHADOW_LEVELS := [
	{"shadow_size": 1024, "shadow_filter": 0, "splits": 2, "shadow_dist": 30.0, "blur": 0.6, "radiance": Sky.RADIANCE_SIZE_32},
	{"shadow_size": 2048, "shadow_filter": 1, "splits": 2, "shadow_dist": 45.0, "blur": 0.6, "radiance": Sky.RADIANCE_SIZE_32},
	{"shadow_size": 4096, "shadow_filter": 2, "splits": 4, "shadow_dist": 70.0, "blur": 1.0, "radiance": Sky.RADIANCE_SIZE_64},
	{"shadow_size": 4096, "shadow_filter": 3, "splits": 4, "shadow_dist": 100.0, "blur": 1.4, "radiance": Sky.RADIANCE_SIZE_128},
]
const GRASS_LEVELS := [[0.0, 0.0], [0.9, 18.0], [1.5, 26.0], [2.4, 38.0]] ## [densidade, raio]
const PARTICLE_LEVELS := [[0.0, 0], [0.6, 12], [1.0, 24]] ## [quantidade, respingos]

static var _settings := {}
static var _detail: ImageTexture
static var _clouds: Texture2D
static var _surfaces := {} ## chave -> ShaderMaterial
static var _wind_materials: Array[ShaderMaterial] = []
static var _glow: ShaderMaterial
static var _sky: ShaderMaterial


# --- Opções ---------------------------------------------------------------------------

static func _load() -> void:
	if not _settings.is_empty():
		return
	_settings = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG) != OK:
		return
	if cfg.has_section_key("video", "preset"):
		for key in DEFAULTS:
			_settings[key] = cfg.get_value("video", key, DEFAULTS[key])
	elif cfg.has_section_key("video", "quality"):
		# Arquivo antigo: só tinha Baixa/Média/Alta.
		_apply_preset(["low", "medium", "high"][clampi(int(cfg.get_value("video", "quality", 1)), 0, 2)])


static func get_setting(key: String) -> Variant:
	_load()
	return _settings.get(key, DEFAULTS.get(key))


## Muda uma opção (vira "Personalizado" se for de qualidade), salva e aplica.
static func set_setting(key: String, value: Variant) -> void:
	_load()
	_settings[key] = value
	if PRESET_VALUES.medium.has(key):
		_settings.preset = "custom"
		for name in PRESET_ORDER:
			if PRESET_VALUES[name].keys().all(func(k): return _settings[k] == PRESET_VALUES[name][k]):
				_settings.preset = name
	_save_and_apply()


static func set_preset(name: String) -> void:
	_load()
	_apply_preset(name)
	_save_and_apply()


static func _apply_preset(name: String) -> void:
	_settings.preset = name
	for key in PRESET_VALUES.get(name, {}):
		_settings[key] = PRESET_VALUES[name][key]


static func preset_name() -> String:
	return PRESET_NAMES.get(get_setting("preset"), "Personalizado")


static func _save_and_apply() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG)
	for key in _settings:
		cfg.set_value("video", key, _settings[key])
	cfg.save(CONFIG)
	var tree := Engine.get_main_loop() as SceneTree
	apply_display()
	if tree and tree.current_scene:
		apply(tree.current_scene)
	if tree:
		tree.call_group("look_screen", "apply_look")


## Qualidade antiga (Baixa/Média/Alta) para quem ainda pergunta: Clássico e
## Personalizado contam como Média.
static func quality() -> int:
	return {"low": Q.LOW, "high": Q.HIGH}.get(get_setting("preset"), Q.MEDIUM)


static func set_quality(q: int) -> void:
	set_preset(["low", "medium", "high"][clampi(q, 0, 2)])


## Números que os sistemas usam (sombra, SSAO, brilho, grama, partículas).
static func preset() -> Dictionary:
	var p: Dictionary = SHADOW_LEVELS[clampi(int(get_setting("shadows")), 0, 3)].duplicate()
	p.shadows = int(get_setting("shadows")) > 0
	p.ssao = bool(get_setting("ssao"))
	p.ssao_half = int(get_setting("shadows")) < 3
	p.glow = bool(get_setting("glow"))
	var grass: Array = GRASS_LEVELS[clampi(int(get_setting("grass")), 0, 3)]
	p.grass_density = grass[0]
	p.grass_radius = grass[1]
	var parts: Array = PARTICLE_LEVELS[clampi(int(get_setting("particles")), 0, 2)]
	p.particles = parts[0]
	p.splashes = parts[1]
	return p


## Sombra do sol ligada no menu?
static func shadows_on() -> bool:
	return int(get_setting("shadows")) > 0


## Multiplica a neblina, o alcance da câmera e os chunks carregados.
static func view_mult() -> float:
	return VIEW_MULT[clampi(int(get_setting("view")), 0, 2)]


static func fov() -> float:
	return float(get_setting("fov"))


## Janela: VSync, tela cheia e limite de FPS (também no menu principal).
static func apply_display() -> void:
	Engine.max_fps = int(get_setting("fps"))
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_setting("vsync") else DisplayServer.VSYNC_DISABLED)
	var full: bool = get_setting("fullscreen")
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if full != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)


## Aplica tonemap, brilho, SSAO, sombras, céu, materiais e alcance na cena do mundo.
static func apply(main: Node) -> void:
	var p := preset()
	RenderingServer.directional_shadow_atlas_set_size(p.shadow_size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(p.shadow_filter)
	RenderingServer.positional_soft_shadow_filter_set_quality(p.shadow_filter)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW if p.ssao_half else RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
		p.ssao_half, 0.5, 2, 40.0, 120.0)
	var world_env := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		setup_environment(world_env.environment)
	var sun := main.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if p.splits == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = p.shadow_dist
		sun.directional_shadow_blend_splits = int(get_setting("shadows")) >= 3
		sun.directional_shadow_fade_start = 0.75
		sun.shadow_blur = p.blur
		if not p.shadows:
			sun.shadow_enabled = false # o DayNight também confere Look.shadows_on()
	_update_materials()
	var terrain := main.get_node_or_null("Terrain")
	if terrain is TerrainWorld:
		terrain.view_distance = 220.0 * view_mult()
	if main.get_tree():
		main.get_tree().call_group("look_quality", "apply_quality")


## Textura PS2, cores fortes e grade do terreno em todos os materiais de superfície.
static func _update_materials() -> void:
	var detail: bool = get_setting("detail")
	var fix := 1.0 if get_setting("color_fix") else 0.0
	for m: ShaderMaterial in _surfaces.values():
		m.set_shader_parameter("detail_strength", float(m.get_meta("strength", 1.0)) if detail else 0.0)
		m.set_shader_parameter("srgb_fix", fix)
		m.set_shader_parameter("grid_lines", 1.0 if get_setting("grid") else 0.0)
	for m in _wind_materials + ([_glow] if _glow else []):
		if m:
			m.set_shader_parameter("srgb_fix", fix)


static func setup_environment(e: Environment) -> void:
	var p := preset()
	# Luz ambiente: parte do céu (azulada) e parte da cor do horizonte (DayNight),
	# para a sombra não ficar azul demais.
	e.ambient_light_sky_contribution = 0.65
	if int(get_setting("tonemap")) == 1:
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC # como era antes da atualização gráfica
		e.tonemap_exposure = 1.0
		e.tonemap_white = 1.0
	else:
		e.tonemap_mode = Environment.TONE_MAPPER_AGX
		e.tonemap_exposure = 1.15
		e.tonemap_agx_contrast = 1.32
		e.tonemap_agx_white = 12.0
	# Brilho só no que é bem claro: fogo, tocha, lâmpadas, olhos, sol.
	e.glow_enabled = p.glow
	e.glow_normalized = false
	e.glow_intensity = 0.75
	e.glow_strength = 1.0
	e.glow_bloom = 0.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.glow_hdr_threshold = 1.05
	e.glow_hdr_scale = 2.0
	for k in 7:
		e.set_glow_level(k, [0.0, 0.6, 0.8, 0.5, 0.25, 0.0, 0.0][k])
	# Oclusão de ambiente na tela: cantos, pé das paredes, embaixo das máquinas.
	e.ssao_enabled = p.ssao
	e.ssao_radius = 0.9
	e.ssao_intensity = 2.2
	e.ssao_power = 1.6
	e.ssao_detail = 0.6
	e.ssao_horizon = 0.06
	e.ssao_sharpness = 0.95
	e.ssao_light_affect = 0.15
	e.ssao_ao_channel_affect = 0.0
	if e.sky:
		e.sky.radiance_size = p.radiance


# --- Materiais ------------------------------------------------------------------------

## Material de superfície PS2 para malhas com cor por vértice.
##   two_sided: sem descarte de faces (peças abertas, ruínas)
##   strength: força da textura de detalhe; roughness/metallic: acabamento
##   sway: balança no vento acima de 1,4 m (copas); terrain: coordenadas do mundo
##   grain_up: veio da madeira na vertical (pilar em pé)
static func surface(two_sided := true, strength := 1.0, roughness := 0.95, sway := 0.0, terrain := false, metallic := 0.0, grain_up := false) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f|%.2f|%s|%.2f|%s" % [two_sided, strength, roughness, sway, terrain, metallic, grain_up]
	if _surfaces.has(key):
		return _surfaces[key]
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER_2S if two_sided else SURFACE_SHADER
	m.set_shader_parameter("detail_tex", detail_texture())
	m.set_meta("strength", strength)
	m.set_shader_parameter("detail_strength", strength if get_setting("detail") else 0.0)
	m.set_shader_parameter("srgb_fix", 1.0 if get_setting("color_fix") else 0.0)
	m.set_shader_parameter("grid_lines", 1.0 if terrain and get_setting("grid") else 0.0)
	m.set_shader_parameter("roughness_value", roughness)
	m.set_shader_parameter("metallic_value", metallic)
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("mode", 1 if terrain else 0)
	m.set_shader_parameter("grain_up", 1.0 if grain_up else 0.0)
	_surfaces[key] = m
	if sway > 0.0:
		_wind_materials.append(m)
	return m


## Folhagem com vento: com textura = tufos recortados (grama, arbustos);
## sem textura = lâminas sólidas da grama densa (fade_far = raio onde some).
static func foliage(texture: Texture2D, fade_far := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE_SHADER if texture else BLADES_SHADER
	if texture:
		m.set_shader_parameter("albedo_tex", texture)
	m.set_shader_parameter("fade_far", fade_far)
	_wind_materials.append(m)
	return m


## Fogo, brasa e chamas: sem luz, cor da partícula puxada acima de 1 (o glow pega).
static func glow_material() -> ShaderMaterial:
	if _glow == null:
		_glow = ShaderMaterial.new()
		_glow.shader = GLOW_SHADER
	return _glow


## Céu do mundo (DayNight mexe nas cores, BiomeAtmosphere na neblina).
static func sky_material() -> ShaderMaterial:
	if _sky == null:
		_sky = ShaderMaterial.new()
		_sky.shader = SKY_SHADER
		_sky.set_shader_parameter("cloud_tex", cloud_texture())
	return _sky


## Vento atual (0..1) para tudo que balança.
static func set_wind(w: float) -> void:
	for m in _wind_materials:
		m.set_shader_parameter("wind", w)


# --- Texturas geradas -------------------------------------------------------------

## 64x64 repetível: R veio de madeira, G grão de pedra, B grão fino, A manchas.
static func detail_texture() -> ImageTexture:
	if _detail:
		return _detail
	const N := 64
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var u := float(x) / N
			var v := float(y) / N
			# Madeira: linhas de veio na horizontal, onduladas, com fibras finas.
			var warp := _fbm(u * 4.0, v * 4.0, 4, 4, 2, 11) * 1.6 + sin(TAU * u) * 0.35
			var rings := sin(TAU * (v * 5.0 + warp))
			var line := smoothstep(0.55, 1.0, rings)
			var fiber := _vnoise(u * 8.0, v * 64.0, 8, 64, 3)
			var wood := 0.62 - 0.34 * line + (fiber - 0.5) * 0.3 + (_vnoise(u * 2.0, v * 16.0, 2, 16, 5) - 0.5) * 0.18
			# Pedra: ruído em 4 escalas + pintinhas escuras.
			var stone := _fbm(u * 4.0, v * 4.0, 4, 4, 4, 21)
			stone = 0.5 + (stone - 0.5) * 1.5
			if _hash(x, y, 31) > 0.94:
				stone -= 0.25
			# Grão fino: pixel a pixel + um pouco de ruído médio.
			var fine := 0.5 + (_hash(x, y, 41) - 0.5) * 0.55 + (_vnoise(u * 16.0, v * 16.0, 16, 16, 43) - 0.5) * 0.4
			# Manchas grandes.
			var blotch := 0.5 + (_fbm(u * 2.0, v * 2.0, 2, 2, 3, 51) - 0.5) * 1.8
			img.set_pixel(x, y, Color(clampf(wood, 0.0, 1.0), clampf(stone, 0.0, 1.0), clampf(fine, 0.0, 1.0), clampf(blotch, 0.0, 1.0)))
	img.generate_mipmaps()
	_detail = ImageTexture.create_from_image(img)
	return _detail


## Nuvens: ruído suave repetível de 128x128 (o céu estica).
static func cloud_texture() -> Texture2D:
	if _clouds:
		return _clouds
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	noise.seed = 7
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	tex.normalize = true
	tex.noise = noise
	tex.generate_mipmaps = true
	_clouds = tex
	return _clouds


static func _hash(x: int, y: int, s: int) -> float:
	var h := x * 374761393 + y * 668265263 + s * 1442695041
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


## Ruído de valor repetível (período px por py células).
static func _vnoise(x: float, y: float, px: int, py: int, s: int) -> float:
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := x - x0
	var fy := y - y0
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(posmod(x0, px), posmod(y0, py), s)
	var b := _hash(posmod(x0 + 1, px), posmod(y0, py), s)
	var c := _hash(posmod(x0, px), posmod(y0 + 1, py), s)
	var d := _hash(posmod(x0 + 1, px), posmod(y0 + 1, py), s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _fbm(x: float, y: float, px: int, py: int, octaves: int, s: int) -> float:
	var total := 0.0
	var amp := 0.5
	var norm := 0.0
	for o in octaves:
		var f := 1 << o
		total += _vnoise(x * f, y * f, px * f, py * f, s + o) * amp
		norm += amp
		amp *= 0.5
	return total / norm
