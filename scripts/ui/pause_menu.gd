class_name PauseMenu
extends CanvasLayer
## Menu de pausa (ESC): pausa o jogo, solta o mouse e mostra Continuar /
## Recomeçar / Sair. Continuar (ou ESC de novo) volta e prende o mouse de novo,
## inclusive dirigindo o carro.

var _panel: PanelContainer
var _restart_button: Button


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS # funciona com o jogo pausado
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.92)
	style.set_border_width_all(1)
	style.border_color = Color(0.5, 0.45, 0.35)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(220, 0)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "Pausado"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	_button(column, "Continuar", close)
	_restart_button = _button(column, "Recomeçar", _restart)
	_button(column, "Sair para o menu", func(): Net.i.leave())
	_button(column, "Sair do jogo", func(): get_tree().quit())
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var player := get_tree().get_first_node_in_group("player")
	if not visible and player and player.ui_blocked:
		return # mochila aberta: o ESC fecha a mochila primeiro
	if visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = not Net.i.online() # online o mundo continua (é de todo mundo)
	_restart_button.visible = Net.i.is_host() # online só o host recomeça a partida
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _restart() -> void:
	close()
	if Net.i.online():
		Net.i.restart_world()
		return
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 34)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
