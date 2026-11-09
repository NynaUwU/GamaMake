extends CanvasLayer
## HUD simples em 960x540: vida, stamina (corrida), arma atual, hotbar/mochila,
## mira, aviso de interação e mensagens.
## Tudo em Control nodes, então dá para crescer para inventário/crafting
## na mesma camada sem mexer no 3D.

@export var player_path: NodePath

@onready var health_bar: ProgressBar = %HealthBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var prompt_label: Label = %PromptLabel
@onready var message_label: Label = %MessageLabel
@onready var weapon_label: Label = %WeaponLabel

var _message_tween: Tween
var _players_label: Label
var _clock: Label
var _wave: ProgressBar
var _arcs: StatusArcs
var _bile: ColorRect
var _bile_mat: ShaderMaterial
var _player: Node
var _machine: MachinePanel
var _gas_box: VBoxContainer
var _filter_label: Label
var _filter_bar: ProgressBar
var _toxic_label: Label
var _toxic_bar: ProgressBar


func _process(_delta: float) -> void:
	if _machine:
		var plants := $Root.get_node_or_null("PlantPanel") as Control
		prompt_label.visible = not _machine.visible and not (plants and plants.visible)
	if _bile and is_instance_valid(_player):
		var amount := clampf(_player.bile_time / 2.0, 0.0, 1.0)
		_bile.visible = amount > 0.0
		if _bile.visible:
			_bile_mat.set_shader_parameter("amount", amount)
	if _clock and DayNight.i:
		_clock.text = DayNight.i.clock_text()
		_clock.modulate = Color(1.0, 0.95, 0.85) if not DayNight.i.is_night() else Color(0.7, 0.78, 1.0)
		# Onda noturna: só uma barra que esvazia conforme os zumbis da noite morrem.
		var hm := HordeManager.i
		_wave.visible = DayNight.i.is_night() and hm != null
		if _wave.visible:
			_wave.max_value = hm.wave_quota
			_wave.value = lerpf(_wave.value, maxf(hm.wave_quota - hm.wave_killed, 0), 0.15)


## Gás tóxico: bordas esverdeadas que pulsam (intoxicação), a moldura das lentes da
## máscara (dentro do gás, de máscara) e o medidor no canto (filtro e intoxicação).
func _build_gas(player: Node) -> void:
	var toxic := ColorRect.new()
	toxic.name = "Toxic"
	toxic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toxic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var toxic_mat := ShaderMaterial.new()
	toxic_mat.shader = Shader.new()
	toxic_mat.shader.code = """shader_type canvas_item;
uniform float amount = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float edge = smoothstep(0.25, 1.0, length(d) * 0.8);
	float swirl = n(UV * 5.0 + vec2(TIME * 0.2, -TIME * 0.13)) * 0.6 + n(UV * 11.0 - TIME * 0.3) * 0.4;
	float pulse = 0.85 + 0.15 * sin(TIME * 2.5);
	float a = clamp(edge * (0.45 + swirl * 0.7) * pulse + amount * 0.18, 0.0, 0.9) * amount;
	COLOR = vec4(mix(vec3(0.45, 0.55, 0.12), vec3(0.75, 0.78, 0.25), swirl), a);
}"""
	toxic.material = toxic_mat
	toxic.visible = false
	$Root.add_child(toxic)
	$Root.move_child(toxic, 1)
	var mask := ColorRect.new()
	mask.name = "GasMask"
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask_mat := ShaderMaterial.new()
	mask_mat.shader = Shader.new()
	mask_mat.shader.code = """shader_type canvas_item;
uniform float amount = 0.0;
uniform float fog = 0.0; // filtro acabando: as lentes embaçam
void fragment() {
	vec2 p = (UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 l = (p - vec2(-0.3, -0.02)) / vec2(0.36, 0.33);
	vec2 r = (p - vec2(0.3, -0.02)) / vec2(0.36, 0.33);
	float dl = length(l);
	float dr = length(r);
	float lens = min(dl, dr);
	float rubber = smoothstep(0.98, 1.02, lens);
	float rim = smoothstep(0.9, 0.95, lens) * (1.0 - smoothstep(1.0, 1.06, lens));
	vec3 color = mix(vec3(0.07, 0.08, 0.07), vec3(0.55, 0.43, 0.2), rim);
	float inside = (1.0 - rubber) * (smoothstep(0.55, 0.98, lens) * 0.35 + fog * 0.5);
	float a = max(rubber * 0.94, rim * 0.9);
	COLOR = vec4(mix(vec3(0.8, 0.85, 0.8), color, step(0.5, a)), max(a, inside) * amount);
}"""
	mask.material = mask_mat
	mask.visible = false
	$Root.add_child(mask)
	$Root.move_child(mask, 2)
	# Medidor: em cima do quarto de círculo da vida.
	_gas_box = VBoxContainer.new()
	_gas_box.name = "GasMeter"
	_gas_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_gas_box.offset_left = 10.0
	_gas_box.offset_top = -150.0
	_gas_box.offset_bottom = -96.0
	_gas_box.offset_right = 130.0
	_gas_box.add_theme_constant_override("separation", 1)
	_gas_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gas_box.visible = false
	$Root.add_child(_gas_box)
	_filter_label = _gas_label(Color(0.7, 0.9, 0.85))
	_filter_bar = _gas_bar(Color(0.35, 0.75, 0.65))
	_toxic_label = _gas_label(Color(0.85, 0.9, 0.4))
	_toxic_bar = _gas_bar(Color(0.6, 0.72, 0.15))
	player.toxic_changed.connect(func(value: float, gas: float, filter: float):
		var masked := filter >= 0.0
		toxic.visible = value > 0.5
		toxic_mat.set_shader_parameter("amount", clampf(value / 70.0, 0.0, 1.0))
		mask.visible = masked and gas > 0.02
		mask_mat.set_shader_parameter("amount", clampf(gas * 1.5, 0.0, 1.0))
		mask_mat.set_shader_parameter("fog", clampf(1.0 - filter * 4.0, 0.0, 1.0) if masked else 0.0)
		_gas_box.visible = gas > 0.0 or value > 0.5
		_filter_label.visible = masked
		_filter_bar.visible = masked
		_filter_label.text = "Filtro %d%%" % int(filter * 100.0) if filter > 0.0 else "FILTRO VAZIO"
		_filter_bar.value = maxf(filter, 0.0)
		_toxic_label.visible = value > 0.5 or (gas > 0.0 and not (masked and filter > 0.0))
		_toxic_bar.visible = _toxic_label.visible
		_toxic_label.text = ("GÁS! " if gas > 0.0 else "") + "Intoxicação %d%%" % int(value)
		_toxic_bar.value = value / 100.0)


func _gas_label(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	_gas_box.add_child(label)
	return label


func _gas_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(110, 5)
	bar.show_percentage = false
	bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	_gas_box.add_child(bar)
	return bar


func _ready() -> void:
	var player := get_node_or_null(player_path)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.health_changed.connect(_on_health_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	# Vida/stamina/fome: quarto de círculo no canto (as barras antigas ficam escondidas).
	$Root/Bars.visible = false
	_arcs = StatusArcs.new()
	_arcs.name = "StatusArcs"
	$Root.add_child(_arcs)
	_arcs.set_value(1, player.health, player.max_health)
	_arcs.set_value(0, player.stamina, player.max_stamina)
	_arcs.set_value(2, player.hunger, player.MAX_HUNGER)
	player.hunger_changed.connect(func(current: float, maximum: float): _arcs.set_value(2, current, maximum))
	_arcs.set_value(3, player.thirst, player.MAX_THIRST)
	player.thirst_changed.connect(func(current: float, maximum: float): _arcs.set_value(3, current, maximum))
	player.sick_changed.connect(func(sick: bool): _arcs.sick = sick)
	var frost := ColorRect.new()
	frost.name = "Frost"
	frost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frost_mat := ShaderMaterial.new()
	frost_mat.shader = Shader.new()
	frost_mat.shader.code = """shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float edge = smoothstep(0.55, 1.0, max(d.x, d.y));
	float flakes = fract(sin(dot(floor(UV * 90.0), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(0.82, 0.92, 1.0, edge * amount * (0.55 + 0.45 * flakes));
}"""
	frost.material = frost_mat
	$Root.add_child(frost)
	$Root.move_child(frost, 0)
	player.cold_changed.connect(func(body_heat: float, temp: float):
		_arcs.temperature = temp
		_arcs.heat = body_heat / player.MAX_HEAT
		frost_mat.set_shader_parameter("amount", clampf(1.0 - body_heat / 60.0, 0.0, 1.0))) # geada nas bordas quando gela
	# Bile do inchado: manchas verdes escorrendo na tela (some nos últimos 2 s).
	var bile := ColorRect.new()
	bile.name = "Bile"
	bile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bile_mat := ShaderMaterial.new()
	bile_mat.shader = Shader.new()
	bile_mat.shader.code = """shader_type canvas_item;
uniform float amount = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 cell = floor(UV * vec2(14.0, 9.0) + vec2(0.0, -TIME * 0.15 * h(vec2(floor(UV.x * 14.0), 3.0))));
	float blot = step(0.45, h(cell)) * (0.6 + 0.4 * h(cell + 7.0));
	vec2 d = abs(UV - 0.5) * 2.0;
	float edge = smoothstep(0.1, 0.9, max(d.x, d.y));
	float a = clamp(blot * 0.75 + edge * 0.6 + 0.25, 0.0, 0.92) * amount;
	COLOR = vec4(0.38, 0.5, 0.08, a);
}"""
	bile.material = bile_mat
	bile.visible = false
	$Root.add_child(bile)
	$Root.move_child(bile, 1)
	_bile = bile
	_bile_mat = bile_mat
	_player = player
	_build_gas(player)
	var plants := PlantPanel.new()
	plants.name = "PlantPanel"
	$Root.add_child(plants)
	plants.setup(player)
	# Máquinas: painel pequeno (nome, barras, teclas) no lugar da frase embaixo da mira.
	_machine = MachinePanel.new()
	_machine.name = "MachinePanel"
	$Root.add_child(_machine)
	_machine.setup(player)
	player.interact_prompt_changed.connect(func(text: String): prompt_label.text = text)
	player.notify.connect(show_message)
	var feed := PickupFeed.new()
	feed.name = "PickupFeed"
	$Root.add_child(feed)
	feed.setup(player.inventory)
	player.weapon_changed.connect(func(weapon_name: String): weapon_label.text = weapon_name)
	player._emit_weapon_text() # o primeiro aviso saiu antes do HUD conectar
	prompt_label.text = ""
	message_label.modulate.a = 0.0
	var inventory_ui := InventoryUI.new()
	inventory_ui.name = "InventoryUI"
	$Root.add_child(inventory_ui)
	inventory_ui.setup(player)
	var chat := Chat.new()
	chat.name = "Chat"
	$Root.add_child(chat)
	chat.setup(player)
	Net.i.message.connect(func(text: String): chat.add_line("", text))
	var map := WorldMap.new()
	map.name = "WorldMap"
	$Root.add_child(map)
	map.setup(player, player.get_parent().get_node_or_null("Terrain"))
	# Online: quem está na partida (canto de cima à esquerda).
	_players_label = Label.new()
	_players_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_players_label.offset_left = -240.0
	_players_label.offset_right = 240.0
	_players_label.offset_top = 6.0
	_players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_players_label.add_theme_font_size_override("font_size", 11)
	_players_label.modulate = Color(1, 1, 1, 0.75)
	$Root.add_child(_players_label)
	Net.i.peers_changed.connect(_refresh_players)
	_refresh_players()
	# Relógio (dia e hora) em cima, no meio (abaixo da lista de jogadores online).
	_clock = Label.new()
	_clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_clock.offset_left = -100.0
	_clock.offset_right = 100.0
	_clock.offset_top = 22.0
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Barra da onda noturna logo abaixo do relógio (só de noite).
	_wave = ProgressBar.new()
	_wave.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_wave.offset_left = -90.0
	_wave.offset_right = 90.0
	_wave.offset_top = 42.0
	_wave.offset_bottom = 48.0
	_wave.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.12, 0.1)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	_wave.add_theme_stylebox_override("fill", fill)
	_wave.add_theme_stylebox_override("background", bg)
	$Root.add_child(_wave)
	_clock.add_theme_font_size_override("font_size", 13)
	$Root.add_child(_clock)


func _refresh_players() -> void:
	# Teclas de admin (Z, H, Backspace recomeçar) só aparecem para o host.
	var controls := get_node_or_null("Root/Controls") as Label
	if controls and Net.i.online() and not Net.i.is_host():
		controls.text = controls.text.replace("Z novo zumbi  H 100 zumbis  Backspace recomeçar", "Backspace renascer (morto)")
	_players_label.visible = Net.i.online()
	_players_label.text = "Online (%d): %s" % [Net.i.player_count(), ", ".join(Net.i.peers.values())]


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	if _arcs:
		_arcs.set_value(1, current, maximum)


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	if _arcs:
		_arcs.set_value(0, current, maximum)


func show_message(text: String) -> void:
	message_label.text = text
	if _message_tween:
		_message_tween.kill()
	message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(2.0)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)
