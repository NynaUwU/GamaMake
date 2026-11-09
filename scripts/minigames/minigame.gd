class_name Minigame
extends CanvasLayer
## Base dos minigames: cada um é uma cena separada (scenes/minigames/<tipo>.tscn)
## que a estação abre com Minigame.play(). Quando acaba, devolve a qualidade em
## finished: 0..1 (0 = estragou a peça) ou -1 (desistiu: a estação não gasta nada).
## Enquanto está aberto o jogador fica parado e com o mouse solto.

signal finished(quality: float)

const CANCELLED := -1.0

var player: Player
var context := {} ## o que a estação mandou (receita, metal, manual lido...)
var _done := false


## Abre o minigame "kind" para o jogador daqui. done(qualidade) é chamado no fim.
static func play(p: Player, kind: String, context_: Dictionary, done: Callable) -> Minigame:
	if p == null or p.is_puppet():
		return null
	var scene := load("res://scenes/minigames/%s.tscn" % kind) as PackedScene
	if scene == null:
		push_error("Minigame sem cena: %s" % kind)
		return null
	var game := scene.instantiate() as Minigame
	game.player = p
	game.context = context_
	game.finished.connect(done, CONNECT_ONE_SHOT)
	p.get_parent().add_child(game)
	return game


func _enter_tree() -> void:
	layer = 10
	if player:
		player.ui_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Termina (uma vez só): devolve a qualidade e solta o jogador.
func finish(quality: float) -> void:
	if _done:
		return
	_done = true
	if player:
		player.ui_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	finished.emit(quality if quality < 0.0 else clampf(quality, 0.0, 1.0))
	queue_free()


## Enquanto joga, nenhuma tecla/clique vaza para o jogo (mochila, mapa, pausa...).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


## Fundo escuro de tela cheia + caixa no meio (estilo dos menus). Devolve a coluna.
func frame(title: String, width: float) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	return LegacyGUI.box(center, title, width)
