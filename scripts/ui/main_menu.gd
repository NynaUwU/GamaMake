extends Control
## Menu inicial: jogar sozinho, criar um servidor na rede local (LAN) ou entrar
## num servidor achado na rede (ou digitando o IP). Até 32 jogadores.

var _name: LineEdit
var _seed: LineEdit
var _ip: LineEdit
var _list: ItemList
var _status: Label
var _ips: Array[String] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.08, 0.07, 0.06)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(420, 0)
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)
	var title := Label.new()
	title.text = "Zumbi FPS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)

	_name = _field(column, "Seu nome", Net.i.player_name if Net.i.player_name != "Jogador" else "Jogador%d" % (randi() % 1000))
	_button(column, "Jogar sozinho", _on_solo)
	column.add_child(HSeparator.new())
	_seed = _field(column, "Semente do mapa (vazio = padrão)", str(Net.i.world_seed) if Net.i.world_seed != 0 else "")
	_button(column, "Criar servidor na rede local (até %d jogadores)" % Net.i.MAX_PLAYERS, _on_host)
	column.add_child(HSeparator.new())
	var found := Label.new()
	found.text = "Servidores na rede local:"
	column.add_child(found)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 110)
	_list.item_activated.connect(func(_i): _on_join_selected())
	column.add_child(_list)
	_button(column, "Entrar no servidor selecionado", _on_join_selected)
	var row := HBoxContainer.new()
	column.add_child(row)
	_ip = LineEdit.new()
	_ip.placeholder_text = "IP do host (ex.: 192.168.0.10)"
	_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_ip)
	var join_ip := Button.new()
	join_ip.text = "Entrar pelo IP"
	join_ip.pressed.connect(_on_join_ip)
	row.add_child(join_ip)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.modulate = Color(1.0, 0.8, 0.5)
	column.add_child(_status)
	_button(column, "Sair", func(): get_tree().quit())

	Net.i.servers_changed.connect(_refresh_servers)
	Net.i.message.connect(_on_message)
	Net.i.start_listening()
	_refresh_servers()


func _exit_tree() -> void:
	Net.i.stop_listening()


func _on_message(text: String) -> void:
	_status.text = text


func _player_name() -> String:
	var text := _name.text.strip_edges()
	return text if text != "" else "Jogador"


func _on_solo() -> void:
	Net.i.leave(false)
	Net.i.player_name = _player_name()
	Net.i.world_seed = int(_seed.text) if _seed.text.is_valid_int() else 0
	get_tree().change_scene_to_file(Net.i.MAIN_SCENE)


func _on_host() -> void:
	_status.text = "Abrindo servidor..."
	Net.i.host_game(_player_name(), int(_seed.text) if _seed.text.is_valid_int() else 0)


func _on_join_selected() -> void:
	var selected := _list.get_selected_items()
	if selected.is_empty():
		_status.text = "Escolha um servidor da lista (ou digite o IP)."
		return
	Net.i.join_game(_ips[selected[0]], _player_name())


func _on_join_ip() -> void:
	var ip := _ip.text.strip_edges()
	if ip == "":
		_status.text = "Digite o IP do host."
		return
	Net.i.join_game(ip, _player_name())


func _refresh_servers() -> void:
	_list.clear()
	_ips.clear()
	for ip in Net.i.servers:
		var info: Dictionary = Net.i.servers[ip]
		_list.add_item("%s  ·  %d/%d jogadores  ·  %s" % [info.name, info.players, info.max, ip])
		_ips.append(ip)
	if _ips.is_empty():
		_list.add_item("(procurando...)")
		_list.set_item_disabled(0, true)


func _field(parent: Control, placeholder: String, value: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.text = value
	parent.add_child(edit)
	return edit


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 34)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
