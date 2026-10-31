class_name DrawUI
extends CanvasLayer
## Tela grande da lousa ([E] no cavalete). Arraste o mouse para desenhar;
## paleta de cores, 4 espessuras, borracha e "Limpar" (apaga para todos).
## Os traços saem em pedaços curtos (a cada ~50 ms) para os outros verem ao vivo.

const ZOOM := 4

var player: Player
var board: DrawBoard
var _color: Color = DrawBoard.PALETTE[0]
var _size := 2
var _drawing := false
var _pending := PackedVector2Array()
var _last := Vector2(-1, -1)
var _flush := 0.0
var _view: TextureRect
var _color_buttons: Array = []


static func open_for(p: Node, board_: DrawBoard) -> void:
	if not p is Player or p.is_puppet() or p.ui_blocked:
		return
	var ui := DrawUI.new()
	ui.player = p
	ui.board = board_
	p.get_parent().add_child(ui) # junto da cena principal (o pai do jogador)


func _ready() -> void:
	layer = 9
	player.ui_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := LegacyGUI.box(center, "Lousa (desenhe junto com os outros)", DrawBoard.W * ZOOM + 120)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_view = TextureRect.new()
	_view.texture = board.texture
	_view.custom_minimum_size = Vector2(DrawBoard.W, DrawBoard.H) * ZOOM
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_view.gui_input.connect(_on_view_input)
	row.add_child(_view)
	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	row.add_child(tools)
	var grid := GridContainer.new()
	grid.columns = 3
	tools.add_child(grid)
	for color: Color in DrawBoard.PALETTE:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.focus_mode = Control.FOCUS_NONE
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_border_width_all(2)
		style.border_color = Color(0.2, 0.2, 0.2)
		for state in ["normal", "hover", "pressed"]:
			swatch.add_theme_stylebox_override(state, style)
		swatch.pressed.connect(_pick.bind(color, swatch))
		grid.add_child(swatch)
		_color_buttons.append([swatch, style])
	var sizes := HBoxContainer.new()
	tools.add_child(sizes)
	for s in [1, 2, 4, 8]:
		var b := LegacyGUI.button(sizes, str(s), func(): _size = s)
		b.custom_minimum_size = Vector2(24, 24)
	LegacyGUI.button(tools, "Borracha", func(): _pick(DrawBoard.PAPER, null))
	LegacyGUI.button(tools, "Limpar", _clear_all)
	LegacyGUI.button(tools, "Fechar", close)
	_pick(_color, _color_buttons[0][0])


func _pick(color: Color, button: Button) -> void:
	_color = color
	for entry in _color_buttons:
		entry[1].border_color = Color(1, 0.9, 0.3) if entry[0] == button else Color(0.2, 0.2, 0.2)


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drawing = event.pressed
		if event.pressed:
			_add_point(event.position)
		else:
			_send()
			_last = Vector2(-1, -1)
	elif event is InputEventMouseMotion and _drawing:
		_add_point(event.position)


func _add_point(at: Vector2) -> void:
	var p := (at / ZOOM).floor()
	if p == _last:
		return
	if _pending.is_empty() and _last.x >= 0.0:
		_pending.append(_last) # continua o traço anterior sem buraco
	_pending.append(p)
	_last = p
	board.stroke(PackedVector2Array([_pending[maxi(_pending.size() - 2, 0)], p]), _color, _size) # aparece na hora


func _process(delta: float) -> void:
	_flush -= delta
	if _flush <= 0.0:
		_flush = 0.05
		_send()


func _send() -> void:
	if _pending.size() == 0:
		return
	var manager := board.obj.get_parent() as PlacedManager
	manager.request("draw", [board.obj.net_id, _pending, _color, _size])
	_pending = PackedVector2Array()


func _clear_all() -> void:
	var manager := board.obj.get_parent() as PlacedManager
	manager.request("clear_board", [board.obj.net_id])
	board.clear()


func close() -> void:
	_send()
	player.ui_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		close()
