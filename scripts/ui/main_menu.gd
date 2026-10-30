extends Control
## Menu inicial no estilo dos menus padrão das versões antigas da Unity
## (LegacyGUI), na frente de uma cena 3D: um carro, um zumbi parado e a
## câmera girando devagar.
## Telas: principal (nome, jogar sozinho, multiplayer, sair) e multiplayer
## (partidas achadas na rede, entrar pelo IP, criar servidor). Até 32 jogadores.

const ZOMBIE_SCENE := preload("res://scenes/zombie.tscn")

var _name := "Jogador"
var _seed := ""
var _page: Control
var _status: Label
var _servers_column: VBoxContainer
var _camera: Camera3D
var _ui: Control # fica numa camada acima do pós-processamento (texto nítido)
var _angle := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name = Net.i.player_name if Net.i.player_name != "Jogador" else "Jogador%d" % (randi() % 1000)
	_seed = str(Net.i.world_seed) if Net.i.world_seed != 0 else ""
	_build_backdrop()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	var version := Label.new()
	version.theme = LegacyGUI.theme()
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0")
	version.modulate = Color(1, 1, 1, 0.6)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.position += Vector2(8, -22)
	_ui.add_child(version)
	Net.i.servers_changed.connect(_refresh_servers)
	Net.i.message.connect(_on_message)
	_show_main()


func _exit_tree() -> void:
	Net.i.stop_listening()


func _process(delta: float) -> void:
	# Câmera balançando devagar; carro e zumbi ficam à direita da caixa do menu.
	_angle += delta * 0.25
	_camera.position = Vector3(1.0 + sin(_angle) * 0.6, 1.5, 6.0)
	_camera.look_at(Vector3(-3.4 + sin(_angle * 0.7) * 0.2, 1.0, 0.0))


# --- Telas --------------------------------------------------------------------

func _new_page(title: String) -> VBoxContainer:
	if _page:
		_page.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(center)
	_page = center
	var column := LegacyGUI.box(center, title, 320.0)
	return column


func _show_main() -> void:
	Net.i.stop_listening()
	var column := _new_page("Zumbi FPS")
	var name_edit := LegacyGUI.field(column, "Nome:", _name)
	name_edit.text_changed.connect(func(text: String): _name = text)
	LegacyGUI.button(column, "Jogar sozinho", _on_solo)
	LegacyGUI.button(column, "Multiplayer (rede local)", _show_multiplayer)
	LegacyGUI.button(column, "Sair", func(): get_tree().quit())
	_add_status(column)


func _show_multiplayer() -> void:
	var column := _new_page("Multiplayer - rede local")
	var found := Label.new()
	found.text = "Partidas na rede:"
	column.add_child(found)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 110)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_servers_column = VBoxContainer.new()
	_servers_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_servers_column.add_theme_constant_override("separation", 4)
	scroll.add_child(_servers_column)
	var row := HBoxContainer.new()
	column.add_child(row)
	var ip := LineEdit.new()
	ip.placeholder_text = "IP do host (192.168.0.10)"
	ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip.custom_minimum_size = Vector2(0, 24)
	row.add_child(ip)
	LegacyGUI.button(row, "Conectar", func(): _join(ip.text.strip_edges()))
	column.add_child(HSeparator.new())
	var seed_edit := LegacyGUI.field(column, "Semente do mapa:", _seed, "vazio = padrão")
	seed_edit.text_changed.connect(func(text: String): _seed = text)
	LegacyGUI.button(column, "Criar servidor (até %d jogadores)" % Net.i.MAX_PLAYERS, _on_host)
	LegacyGUI.button(column, "Voltar", _show_main)
	_add_status(column)
	Net.i.start_listening()
	_refresh_servers()


func _add_status(column: VBoxContainer) -> void:
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.modulate = Color(1.0, 0.85, 0.55)
	_status.custom_minimum_size = Vector2(0, 18)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)


func _refresh_servers() -> void:
	if not is_instance_valid(_servers_column):
		return
	for child in _servers_column.get_children():
		child.queue_free()
	if Net.i.servers.is_empty():
		var waiting := Label.new()
		waiting.text = "Procurando..."
		waiting.modulate = Color(1, 1, 1, 0.6)
		_servers_column.add_child(waiting)
		return
	for key in Net.i.servers:
		var info: Dictionary = Net.i.servers[key]
		var address := "%s:%d" % [info.ip, info.port]
		LegacyGUI.button(_servers_column, "%s   (%d/%d)   %s" % [info.name, info.players, info.max, address],
				func(): _join(address))


# --- Ações --------------------------------------------------------------------

func _player_name() -> String:
	var text := _name.strip_edges()
	return text if text != "" else "Jogador"


func _seed_value() -> int:
	return int(_seed) if _seed.is_valid_int() else 0


func _on_solo() -> void:
	Net.i.leave(false)
	Net.i.player_name = _player_name()
	Net.i.world_seed = _seed_value()
	get_tree().change_scene_to_file(Net.i.MAIN_SCENE)


func _on_host() -> void:
	_on_message("Abrindo servidor...")
	Net.i.host_game(_player_name(), _seed_value())


func _join(address: String) -> void:
	if address == "":
		_on_message("Digite o IP do host.")
		return
	Net.i.join_game(address, _player_name())


func _on_message(text: String) -> void:
	if is_instance_valid(_status):
		_status.text = text


# --- Cena de fundo -------------------------------------------------------------

func _build_backdrop() -> void:
	var world := Node3D.new()
	world.name = "Backdrop"
	add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.32, 0.3, 0.32)
	sky_material.sky_horizon_color = Color(0.75, 0.55, 0.38)
	sky_material.ground_horizon_color = Color(0.45, 0.35, 0.27)
	sky_material.ground_bottom_color = Color(0.12, 0.1, 0.09)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.7, 0.55, 0.4)
	environment.fog_density = 0.008
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	world.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.35, 0.9, 0)
	sun.light_color = Color(1.0, 0.8, 0.6)
	sun.shadow_enabled = true
	world.add_child(sun)
	# Chão.
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.36, 0.33, 0.26)
	ground_material.roughness = 1.0
	plane.material = ground_material
	ground_mesh.mesh = plane
	ground.add_child(ground_mesh)
	world.add_child(ground)
	# Um carro e um zumbi (parado: sem ninguém para perseguir).
	var car := VintageCar.new()
	car.position = Vector3(0.9, 0.8, -1.2)
	car.rotation.y = 2.3
	world.add_child(car)
	var zombie: Zombie = ZOMBIE_SCENE.instantiate()
	zombie.position = Vector3(0.0, 0.1, 1.2)
	zombie.rotation.y = -2.9
	zombie.detect_range = 0.0
	world.add_child(zombie)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	world.add_child(_camera)
	_camera.current = true
	# O mesmo pós-processamento do jogo (pixelado).
	var retro: Node = load("res://scenes/ui/retro_screen.tscn").instantiate()
	add_child(retro)
