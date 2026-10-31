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
var _wave: Label
var _arcs: StatusArcs


func _process(_delta: float) -> void:
	if _clock and DayNight.i:
		_clock.text = DayNight.i.clock_text()
		_clock.modulate = Color(1.0, 0.95, 0.85) if not DayNight.i.is_night() else Color(0.7, 0.78, 1.0)
		_wave.text = _wave_text()
		_wave.modulate = Color(1.0, 0.55, 0.45) if DayNight.i.is_night() else Color(1, 1, 1, 0.75)


## "Onda 2 · 5 vivos · 11 abatidos · amanhece em 3:10" / "Próxima noite em 6:20".
func _wave_text() -> String:
	var dn := DayNight.i
	var hours := fposmod((DayNight.NIGHT_END if dn.is_night() else DayNight.NIGHT_START) - dn.hour, 24.0)
	var seconds := int(hours / 24.0 * DayNight.DAY_LENGTH)
	var clock := "%d:%02d" % [seconds / 60, seconds % 60]
	if not dn.is_night():
		return "Próxima noite em %s" % clock
	var hm := HordeManager.i
	var alive := hm.wave_alive if hm else 0
	var killed := hm.wave_killed if hm else 0
	return "Onda noturna %d  ·  %d vivos  ·  %d abatidos  ·  amanhece em %s" % [dn.day if dn.hour >= 12.0 else dn.day - 1, alive, killed, clock]


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
	var plants := PlantPanel.new()
	plants.name = "PlantPanel"
	$Root.add_child(plants)
	plants.setup(player)
	player.interact_prompt_changed.connect(func(text: String): prompt_label.text = text)
	player.notify.connect(show_message)
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
	# Contador da onda noturna logo abaixo do relógio.
	_wave = Label.new()
	_wave.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_wave.offset_left = -260.0
	_wave.offset_right = 260.0
	_wave.offset_top = 38.0
	_wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave.add_theme_font_size_override("font_size", 11)
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
