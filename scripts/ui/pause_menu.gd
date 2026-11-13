class_name PauseMenu
extends CanvasLayer
## Menu de pausa (ESC): pausa o jogo, solta o mouse e mostra Continuar /
## Recomeçar / Sair. Continuar (ou ESC de novo) volta e prende o mouse de novo,
## inclusive dirigindo o carro. Daqui abrem a lista de controles (as teclas que antes
## ficavam escritas na tela) e o menu de admin (trapaças; só quem hospeda o mundo).

## [tecla, o que faz]
const CONTROLS := [
	["W A S D", "andar"], ["Shift", "correr"], ["Espaço", "pular / escalar"], ["C", "agachar (correndo: deslizar)"],
	["Clique", "atacar / usar o item da mão"], ["Botão direito", "bloquear; armas de fogo: mirar"], ["F", "chute"],
	["Pá / picareta no chão", "cava um bloco de 0,4 m (dá terra, areia ou pedra)"], ["Terra/pedra na mão + clique", "põe um bloco no chão"],
	["1-9 / roda", "escolher na hotbar"], ["Q", "próximo item"], ["G", "soltar o item da mão"],
	["Tab", "mochila (arraste para fora da janela: solta no chão)"], ["E", "pegar / interagir (segure: manivela)"],
	["R", "recarregar / girar a peça"], ["L", "lanterna"], ["M", "mapa"], ["J", "diário (eras, receitas, manuais)"],
	["Enter", "chat"], ["B / botão do meio", "marcar no mapa"], ["Esc", "pausa"], ["Backspace", "morto: recomeçar / renascer"],
]

var _title: Label
var _restart_button: Button
var _lan_button: Button
var _save_button: Button
var _graphics_button: Button
var _main_box: Control
var _controls_box: Control
var _admin_button: Button
var _admin: AdminPanel
var _graphics: GraphicsPanel
var _center: CenterContainer


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
	_center = center
	var column := LegacyGUI.box(center, "Pausado", 230.0)
	_main_box = column.get_parent()
	_title = column.get_child(0)
	LegacyGUI.button(column, "Continuar", close)
	LegacyGUI.button(column, "Controles", func(): _show(_controls_box))
	_admin_button = LegacyGUI.button(column, "Admin (trapaças)", _open_admin)
	_save_button = LegacyGUI.button(column, "Salvar", _save)
	_lan_button = LegacyGUI.button(column, "Abrir para LAN", _open_to_lan)
	_restart_button = LegacyGUI.button(column, "Recomeçar", _restart)
	# Menu de gráficos: predefinições (Clássico = visual de antes) e cada opção solta.
	_graphics_button = LegacyGUI.button(column, _graphics_text(), _open_graphics)
	LegacyGUI.button(column, "Sair para o menu", func():
		if Net.i.is_host():
			_save()
		Net.i.leave())
	LegacyGUI.button(column, "Sair do jogo", func(): get_tree().quit())
	_build_controls(center)
	visible = false


## Mostra uma das caixas (principal, controles, admin) e esconde as outras.
func _show(which: Control) -> void:
	for b in [_main_box, _controls_box] + ([_admin.box, _admin.items_box] if _admin else []) + ([_graphics.box] if _graphics else []):
		b.visible = b == which
	if which == _main_box and _graphics_button:
		_graphics_button.text = _graphics_text()


func _build_controls(center: Control) -> void:
	var column := LegacyGUI.box(center, "Controles", 430.0)
	_controls_box = column.get_parent()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	column.add_child(grid)
	for c in CONTROLS:
		var key := Label.new()
		key.text = c[0]
		key.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
		key.add_theme_font_size_override("font_size", 12)
		grid.add_child(key)
		var what := Label.new()
		what.text = c[1]
		what.add_theme_font_size_override("font_size", 12)
		grid.add_child(what)
	var tip := Label.new()
	tip.text = "Passe o mouse num item da mochila e segure Shift: os controles dele."
	tip.add_theme_font_size_override("font_size", 10)
	tip.modulate = Color(1, 1, 1, 0.6)
	column.add_child(tip)
	LegacyGUI.button(column, "Voltar", func(): _show(_main_box))
	_controls_box.visible = false


func _open_admin() -> void:
	if _admin == null:
		var player := get_tree().get_first_node_in_group("player") as Player
		if player == null:
			return
		_admin = AdminPanel.new(_center, player, func(): _show(_main_box))
	_admin.refresh()
	_show(_admin.box)


func _open_graphics() -> void:
	if _graphics == null:
		_graphics = GraphicsPanel.new(_center, func(): _show(_main_box))
	_graphics.refresh()
	_show(_graphics.box)


static func _graphics_text() -> String:
	return GraphicsPanel.button_text()


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
	if visible and not _main_box.visible:
		_show(_main_box) # ESC numa sub-tela volta para o menu
	elif visible:
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
	_admin_button.visible = Net.i.is_host() # trapaças: só quem hospeda (solo também)
	_show(_main_box)
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
	Cheats.reset()
	if Net.i.online():
		Net.i.restart_world()
		return
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
