class_name Chat
extends Control
## Chat (Enter) e avisos no canto de baixo à esquerda, acima das barras.
## Enter abre a caixa de texto, Enter envia, Esc cancela. As mensagens somem
## depois de alguns segundos (com o chat aberto, aparecem todas de novo).
## Comandos do host: /noite, /dia, /hora 14, /horda. /ajuda lista.

const KEEP := 40
const SHOW_TIME := 9.0

static var i: Chat

var player: Player
var _log: VBoxContainer
var _input: LineEdit
var _lines: Array = [] # [Label, hora em que chegou]


func _enter_tree() -> void:
	i = self


func _exit_tree() -> void:
	if i == self:
		i = null


func setup(p: Player) -> void:
	player = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -370.0
	offset_bottom = -150.0 # acima dos arcos de vida/stamina/fome
	offset_left = 12.0
	offset_right = 432.0
	_log = VBoxContainer.new()
	_log.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log.alignment = BoxContainer.ALIGNMENT_END
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_constant_override("separation", 0)
	_log.offset_bottom = -26.0
	add_child(_log)
	_input = LineEdit.new()
	_input.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_input.offset_top = -24.0
	_input.placeholder_text = "Mensagem (Enter envia, Esc cancela)"
	_input.max_length = 160
	_input.visible = false
	_input.theme = LegacyGUI.theme()
	_input.text_submitted.connect(_submit)
	add_child(_input)
	Net.i.chat_received.connect(add_line)


func is_open() -> bool:
	return _input.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("chat") and not is_open() and not player.ui_blocked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		get_viewport().set_input_as_handled()
		_open()
	elif is_open() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _open() -> void:
	_input.visible = true
	_input.text = ""
	player.ui_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_input.grab_focus.call_deferred()


func _close() -> void:
	_input.visible = false
	_input.release_focus()
	player.ui_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _submit(text: String) -> void:
	text = text.strip_edges()
	_close()
	if text == "":
		return
	if text.begins_with("/"):
		_command(text)
		return
	Net.i.send_chat(text)


## Linha no chat. from = "" para aviso do jogo (amarelo).
func add_line(from: String, text: String) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(410, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	if from == "":
		label.text = text
		label.modulate = Color(1.0, 0.85, 0.5)
	else:
		label.text = "%s: %s" % [from, text]
	_log.add_child(label)
	_lines.append([label, Time.get_ticks_msec() / 1000.0])
	while _lines.size() > KEEP:
		_lines.pop_front()[0].queue_free()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for entry in _lines:
		var age: float = now - entry[1]
		entry[0].modulate.a = 1.0 if is_open() else clampf((SHOW_TIME - age) / 1.5, 0.0, 1.0)


func _command(text: String) -> void:
	var parts := text.substr(1).split(" ", false)
	var cmd := parts[0].to_lower() if parts.size() > 0 else ""
	if cmd in ["ajuda", "help", "?"]:
		add_line("", "Comandos: /ajuda · host: /noite, /dia, /hora <0-23>, /horda")
		return
	if not Net.i.is_host():
		add_line("", "Só o host usa comandos.")
		return
	var dn := DayNight.i
	match cmd:
		"noite":
			if dn:
				dn.hour = 20.5
				_sync_clock()
		"dia":
			if dn:
				dn.hour = 7.0
				_sync_clock()
		"hora":
			if dn and parts.size() > 1 and parts[1].is_valid_float():
				dn.hour = fposmod(float(parts[1]), 24.0)
				_sync_clock()
		"horda":
			if HordeManager.i:
				HordeManager.i.spawn_near(player.global_position)
				add_line("", "Uma horda apareceu por perto...")
		_:
			add_line("", "Comando desconhecido. /ajuda")


func _sync_clock() -> void:
	add_line("", "Hora: %s" % DayNight.i.clock_text())
	if Net.i.online():
		Net.i.broadcast_system_state("DayNight", DayNight.i.save_data())
