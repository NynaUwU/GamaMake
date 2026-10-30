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


func _ready() -> void:
	var player := get_node_or_null(player_path)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.health_changed.connect(_on_health_changed)
	player.stamina_changed.connect(_on_stamina_changed)
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
	var map := WorldMap.new()
	map.name = "WorldMap"
	$Root.add_child(map)
	map.setup(player, player.get_parent().get_node_or_null("Terrain"))
	# Online: quem está na partida (canto de cima à esquerda).
	_players_label = Label.new()
	_players_label.position = Vector2(8, 6)
	_players_label.add_theme_font_size_override("font_size", 11)
	_players_label.modulate = Color(1, 1, 1, 0.75)
	$Root.add_child(_players_label)
	Net.i.peers_changed.connect(_refresh_players)
	_refresh_players()


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


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current


func show_message(text: String) -> void:
	message_label.text = text
	if _message_tween:
		_message_tween.kill()
	message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(2.0)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)
