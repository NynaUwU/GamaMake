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

## Tudo que muda com a qualidade.
const PRESETS := [
	{"shadow_size": 2048, "shadow_filter": 1, "splits": 2, "shadow_dist": 45.0, "blur": 0.6, "ssao": false, "ssao_half": true,
		"glow": false, "grass_density": 0.0, "grass_radius": 0.0, "particles": 0.0, "splashes": 0, "radiance": Sky.RADIANCE_SIZE_32},
	{"shadow_size": 4096, "shadow_filter": 2, "splits": 4, "shadow_dist": 70.0, "blur": 1.0, "ssao": true, "ssao_half": true,
		"glow": true, "grass_density": 1.5, "grass_radius": 26.0, "particles": 0.6, "splashes": 12, "radiance": Sky.RADIANCE_SIZE_64},
	{"shadow_size": 4096, "shadow_filter": 3, "splits": 4, "shadow_dist": 100.0, "blur": 1.4, "ssao": true, "ssao_half": false,
		"glow": true, "grass_density": 2.4, "grass_radius": 38.0, "particles": 1.0, "splashes": 24, "radiance": Sky.RADIANCE_SIZE_128},
]

static var _quality := -1
static var _detail: ImageTexture
static var _clouds: Texture2D
static var _surfaces := {} ## chave -> ShaderMaterial
static var _wind_materials: Array[ShaderMaterial] = []
static var _glow: ShaderMaterial
static var _sky: ShaderMaterial


# --- Qualidade ----------------------------------------------------------------------

static func quality() -> int:
	if _quality < 0:
		_quality = Q.MEDIUM
		var cfg := ConfigFile.new()
		if cfg.load(CONFIG) == OK:
			_quality = clampi(int(cfg.get_value("video", "quality", Q.MEDIUM)), 0, 2)
	return _quality


static func preset() -> Dictionary:
	return PRESETS[quality()]


static func set_quality(q: int) -> void:
	_quality = clampi(q, 0, 2)
	var cfg := ConfigFile.new()
	cfg.load(CONFIG)
	cfg.set_value("video", "quality", _quality)
	cfg.save(CONFIG)
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		apply(tree.current_scene)


## Aplica tonemap, brilho, SSAO, sombras e céu na cena do mundo (main.tscn).
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
		sun.directional_shadow_blend_splits = quality() == Q.HIGH
		sun.directional_shadow_fade_start = 0.75
		sun.shadow_blur = p.blur
	if main.get_tree():
		main.get_tree().call_group("look_quality", "apply_quality")


static func setup_environment(e: Environment) -> void:
	var p := preset()
	# Luz ambiente: parte do céu (azulada) e parte da cor do horizonte (DayNight),
	# para a sombra não ficar azul demais.
	e.ambient_light_sky_contribution = 0.65
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
	m.set_shader_parameter("detail_strength", strength)
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
