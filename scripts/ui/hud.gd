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
	prompt_label.text = ""
	message_label.modulate.a = 0.0
	var inventory_ui := InventoryUI.new()
	inventory_ui.name = "InventoryUI"
	$Root.add_child(inventory_ui)
	inventory_ui.setup(player)


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
