class_name PauseMenu
extends CanvasLayer
## Menu de pausa (ESC): pausa o jogo, solta o mouse e mostra Continuar /
## Recomeçar / Sair. Continuar (ou ESC de novo) volta e prende o mouse de novo,
## inclusive dirigindo o carro.

var _title: Label
var _restart_button: Button
var _lan_button: Button
var _save_button: Button


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS # funciona com o jogo pausado
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	dim.gui_input.connect(func(event: InputEvent): # clicar fora da caixa = continuar
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dim.accept_event()
			close())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	# Caixa no estilo dos menus antigos da Unity (LegacyGUI).
	var column := LegacyGUI.box(center, "Pausado", 230.0)
	_title = column.get_child(0)
	LegacyGUI.button(column, "Continuar", close)
	_save_button = LegacyGUI.button(column, "Salvar", _save)
	_lan_button = LegacyGUI.button(column, "Abrir para LAN", _open_to_lan)
	_restart_button = LegacyGUI.button(column, "Recomeçar", _restart)
	LegacyGUI.button(column, "Sair para o menu", func():
		if Net.i.is_host():
			_save()
		Net.i.leave())
	LegacyGUI.button(column, "Sair do jogo", func(): get_tree().quit())
	visible = false


## Como no Minecraft: a partida solo vira servidor na hora (os outros entram pelo menu).
func _open_to_lan() -> void:
	Net.i.open_to_lan()
	close()


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
	_lan_button.visible = not Net.i.online()
	_save_button.visible = Net.i.is_host() # o mundo é salvo no computador do host
	_title.text = "Pausado" if not Net.i.online() else "Menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _save() -> void:
	var main := get_tree().current_scene
	if main and main.has_method("save_now"):
		_save_button.text = "Salvo!" if main.save_now() else "Erro ao salvar"
		get_tree().create_timer(1.5, true).timeout.connect(func(): _save_button.text = "Salvar")


func _restart() -> void:
	close()
	if Net.i.online():
		Net.i.restart_world()
		return
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
