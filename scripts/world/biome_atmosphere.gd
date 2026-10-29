class_name BiomeAtmosphere
extends Node
## Neblina e clima pelo bioma onde o player está (mistura suave na transição):
##   planície ~180 m · deserto ~210 m (névoa de calor) · montanha ~160 m
##   inverno ~50 m (nevasca, com neve caindo)
## Usa neblina por distância (fog_mode = DEPTH): fog_end = onde não se vê mais nada.

@export var terrain_path: NodePath
@export var environment_path: NodePath
@export var player_path: NodePath
@export var sun_path: NodePath

## distância de visão (fim da neblina), começo da neblina e cor, por bioma.
const FOG := {
	"plains": {"end": 180.0, "begin": 25.0, "color": Color(0.55, 0.5, 0.45)},
	"desert": {"end": 210.0, "begin": 40.0, "color": Color(0.78, 0.66, 0.5)},
	"mountain": {"end": 160.0, "begin": 20.0, "color": Color(0.52, 0.54, 0.58)},
	"winter": {"end": 50.0, "begin": 4.0, "color": Color(0.78, 0.82, 0.88)},
}

var _terrain: TerrainWorld
var _environment: Environment
var _player: Node3D
var _sun: DirectionalLight3D
var _snow: CPUParticles3D
var _target := {"end": 180.0, "begin": 25.0, "color": Color(0.55, 0.5, 0.45), "snow": 0.0}
var _timer := 0.0
var _snow_amount := 0.0


func _ready() -> void:
	_terrain = get_node(terrain_path) as TerrainWorld
	_environment = (get_node(environment_path) as WorldEnvironment).environment
	_player = get_node(player_path) as Node3D
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_environment.fog_enabled = true
	_environment.fog_mode = Environment.FOG_MODE_DEPTH
	_environment.fog_density = 1.0
	_environment.fog_depth_curve = 1.4
	_environment.fog_sky_affect = 1.0
	_snow = _make_snow()
	_player.add_child(_snow)
	_sample()
	_apply(1.0)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.25
		_sample()
	_apply(1.0 - exp(-1.5 * delta))


## Para o HUD/IA: quão longe dá para ver agora.
func visibility() -> float:
	return _environment.fog_depth_end


func _sample() -> void:
	var p := _player.global_position
	var biome := _terrain.biome_at(p.x, p.z)
	var snow := _terrain.snow_at(p.x, p.z)
	var weights := {"plains": biome.plains, "desert": biome.desert, "mountain": biome.mountain, "winter": biome.winter}
	# Montanha acima da linha de neve conta como inverno.
	var high_snow := maxf(snow - biome.winter, 0.0)
	weights.winter += high_snow * weights.mountain
	weights.mountain -= high_snow * weights.mountain
	var end := 0.0
	var begin := 0.0
	var color := Color(0, 0, 0)
	var total := 0.0
	for key in weights:
		var w: float = weights[key]
		end += FOG[key].end * w
		begin += FOG[key].begin * w
		color += FOG[key].color * w
		total += w
	if total > 0.001:
		end /= total
		begin /= total
		color /= total
	_target = {"end": end, "begin": begin, "color": color, "snow": snow}


func _apply(t: float) -> void:
	_environment.fog_depth_end = lerpf(_environment.fog_depth_end, _target.end, t)
	_environment.fog_depth_begin = lerpf(_environment.fog_depth_begin, _target.begin, t)
	_environment.fog_light_color = _environment.fog_light_color.lerp(_target.color, t)
	_snow_amount = lerpf(_snow_amount, _target.snow, t)
	_snow.emitting = _snow_amount > 0.25
	_snow.speed_scale = 0.6 + _snow_amount * 0.6
	if _sun:
		# Nevasca escurece o sol.
		_sun.light_energy = lerpf(1.2, 0.55, _snow_amount)


func _make_snow() -> CPUParticles3D:
	var snow := CPUParticles3D.new()
	snow.name = "Snow"
	snow.amount = 600
	snow.lifetime = 3.0
	snow.preprocess = 2.0
	snow.local_coords = false
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(18, 1, 18)
	snow.position = Vector3(0, 8, 0)
	snow.direction = Vector3(0.3, -1, 0.1)
	snow.spread = 15.0
	snow.gravity = Vector3(0.8, -2.0, 0)
	snow.initial_velocity_min = 1.5
	snow.initial_velocity_max = 3.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.95, 0.97, 1.0)
	mesh.material = material
	snow.mesh = mesh
	snow.emitting = false
	return snow
