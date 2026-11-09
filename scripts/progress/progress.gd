class_name Progress
extends Node
## Progresso do jogador daqui (cada um tem o seu e vai no save dele): eras,
## conquistas, manuais lidos, receitas descobertas e pistas. O diário (tecla J,
## JournalUI) mostra tudo; conquistas e eras novas aparecem num aviso no canto.
##
## Eras não travam nada: são o guia (quest) do que fazer a seguir. Quem trava são
## os manuais (achados em casas, ruínas e airdrops): receitas e estações com
## "manual" só aparecem/funcionam depois de ler o manual certo.
##
## Os eventos chegam de vários lugares: Progress.event("tipo", "id")
##   get:<item>      entrou na mochila        craft:<item>   fabricou
##   place:<objeto>  construiu com o martelo  forge:<item>   forjou (forge_master: >= 90%)
##   read:<manual>   leu um manual            radio:deliver  entregou um pedido do rádio
##   refuel:car      abasteceu um carro

signal changed

static var i: Progress

const ERAS := [
	{"name": "Sobrevivente", "desc": "Ferramentas improvisadas, fogueira e coleta de sucata."},
	{"name": "Ferreiro de sucata", "desc": "Forja a carvão: refundir o metal achado e forjar as próprias peças (ainda sem ligas)."},
	{"name": "Mecânica", "desc": "Força motriz da roda d'água e do vento; serraria, torno e prensa movidos a eixo."},
	{"name": "Eletrificação", "desc": "Dínamo, painel solar, baterias e a rede elétrica da base."},
	{"name": "Química e refino", "desc": "Destilar combustível e antisséptico. Pólvora, plástico e ácido de bateria vêm nesta era."},
	{"name": "Reconstrução", "desc": "Rádio, contato com outras comunidades e veículos restaurados."},
]

## Conquistas. "key" = objetivo-chave: todos os da era abrem a próxima.
## "on" = eventos que contam ("tipo:id" ou "tipo:*").
const ACHIEVEMENTS := {
	"sucata": {"era": 0, "key": true, "title": "Catador", "how": "Junte sucata (caixotes, carros, zumbis)", "on": ["get:sucata"]},
	"ferramenta": {"era": 0, "key": true, "title": "Ferramenta improvisada", "how": "Faça um machado ou uma picareta (Tab: fabricar)",
		"on": ["craft:machado_simples", "craft:picareta_simples", "craft:machado", "craft:picareta"]},
	"fogueira": {"era": 0, "key": true, "title": "Fogo", "how": "Construa uma fogueira (martelo, aba Máquinas)", "on": ["place:campfire"]},
	"agua": {"era": 0, "title": "Água limpa", "how": "Consiga água potável (coletor de chuva ou filtro)", "on": ["get:agua"]},
	"colheita": {"era": 0, "title": "Primeira colheita", "how": "Colha uma cenoura ou batata plantada", "on": ["get:cenoura", "get:batata"]},
	"forja": {"era": 1, "key": true, "title": "Forja a carvão", "how": "Construa a forja com bigorna (aba Máquinas)", "on": ["place:forge"]},
	"barra": {"era": 1, "key": true, "title": "Refundir", "how": "Funda sucata ou minério numa barra de ferro (fornalha)", "on": ["get:barra_ferro"]},
	"forjado": {"era": 1, "key": true, "title": "Primeiro golpe", "how": "Forje uma peça na bigorna", "on": ["forge:*"]},
	"leitor": {"era": 1, "title": "Leitor", "how": "Leia um manual (clique com ele na mão)", "on": ["read:*"]},
	"obra_prima": {"era": 1, "title": "Obra-prima", "how": "Forje uma peça com 90% de qualidade ou mais", "on": ["forge_master:*"]},
	"forca": {"era": 2, "key": true, "title": "Força motriz", "how": "Ponha uma roda d'água ou um moinho de vento", "on": ["place:water_wheel", "place:windmill"]},
	"oficina": {"era": 2, "key": true, "title": "Oficina", "how": "Monte uma serraria ou um torno", "on": ["place:sawmill", "place:lathe"]},
	"aco": {"era": 2, "title": "Aço", "how": "Faça aço no alto-forno", "on": ["get:barra_aco"]},
	"vapor": {"era": 2, "title": "Vapor", "how": "Monte um motor a vapor", "on": ["place:steam_engine"]},
	"gerador": {"era": 3, "key": true, "title": "Gerador", "how": "Ponha um dínamo ou um painel solar", "on": ["place:dynamo", "place:solar_panel"]},
	"bateria": {"era": 3, "key": true, "title": "Reserva", "how": "Monte uma bateria", "on": ["place:battery"]},
	"luz": {"era": 3, "title": "Luz elétrica", "how": "Ponha uma lâmpada", "on": ["place:lamp"]},
	"fio_cobre": {"era": 3, "title": "Trefilado", "how": "Puxe fio de cobre na trefiladora", "on": ["get:fio_cobre"]},
	"motor_eletrico": {"era": 3, "title": "Motor elétrico", "how": "Encaixe um motor elétrico numa máquina", "on": ["place:electric_motor"]},
	"destilaria": {"era": 4, "key": true, "title": "Alambique", "how": "Monte uma destilaria", "on": ["place:distillery"]},
	"alcool": {"era": 4, "key": true, "title": "Álcool", "how": "Destile álcool", "on": ["get:alcool"]},
	"esteril": {"era": 4, "title": "Antisséptico", "how": "Faça uma bandagem com álcool", "on": ["craft:bandagem_esteril"]},
	"radio": {"era": 5, "key": true, "title": "Na escuta", "how": "Monte um rádio", "on": ["place:radio"]},
	"pedido": {"era": 5, "key": true, "title": "Comunidade", "how": "Entregue um pedido de sobreviventes pelo rádio", "on": ["radio:deliver"]},
	"abastecer": {"era": 5, "title": "Na estrada", "how": "Abasteça um carro com álcool ou óleo", "on": ["refuel:car"]},
}

## Manuais: o que liberam (receitas com "manual" na CraftingUI e entradas do martelo
## com "manual") e a pista que deixam no diário.
const MANUALS := {
	&"manual_ferreiro": {"title": "Manual do ferreiro", "era": 1,
		"unlocks": "Forja: espada, capacete e peitoral. No minigame da forja aparece a tabela de cores do metal.",
		"clue": "Manual do ferreiro: o ferro se bate do laranja ao amarelo; o cobre, do vermelho-cereja ao laranja. Mais frio que isso o metal racha; branco, queima."},
	&"manual_eletricista": {"title": "Manual do eletricista", "era": 3,
		"unlocks": "Trefiladora (barra de cobre vira fio de cobre), cabo e bobina com fio de cobre (rendem mais).",
		"clue": "Manual do eletricista: a fieira puxa a barra de cobre em fio fino; com fio, uma barra vira o dobro de cabo."},
}

var era := 0
var done := {} ## conquista -> dia em que fez
var manuals := {} ## manual -> true
var recipes := {} ## item -> true (fabricou, pegou ou o manual mostrou)
var clues: Array = [] ## {"text", "day", "hour"} (mais nova no fim)
var _queue: Array = [] # avisos esperando a vez
var _toast: Control
var _toast_time := 0.0


func _enter_tree() -> void:
	i = self


func _exit_tree() -> void:
	if i == self:
		i = null


func _ready() -> void:
	var world := get_parent()
	var player: Player = world.get("player")
	if player:
		player.inventory.gained.connect(func(id: StringName, _amount: int): _event("get", String(id)))
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_toast = PanelContainer.new()
	_toast.theme = LegacyGUI.theme()
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_toast)


# --- Eventos -----------------------------------------------------------------------

static func event(kind: String, id: String) -> void:
	if i:
		i._event(kind, id)


func _event(kind: String, id: String) -> void:
	if kind in ["get", "craft", "forge"] and ItemDB.has(StringName(id)):
		recipes[StringName(id)] = true
	var key := "%s:%s" % [kind, id]
	var any := "%s:*" % kind
	for a: String in ACHIEVEMENTS:
		if not done.has(a) and (key in ACHIEVEMENTS[a].on or any in ACHIEVEMENTS[a].on):
			_complete(a)
	changed.emit()


func _complete(a: String) -> void:
	done[a] = DayNight.i.day if DayNight.i else 1
	var info: Dictionary = ACHIEVEMENTS[a]
	_announce("Conquista", info.title, info.how + "\nJ: diário", false)
	var before := era
	era = current_era()
	for k in range(before + 1, era + 1):
		_announce("Era %d" % k, ERAS[k].name, ERAS[k].desc + "\nObjetivos novos no diário (J).", true)


## Era atual: avança enquanto todos os objetivos-chave da era estiverem feitos.
func current_era() -> int:
	var e := 0
	while e < ERAS.size() - 1 and keys_done(e):
		e += 1
	return e


func keys_done(e: int) -> bool:
	for a: String in ACHIEVEMENTS:
		if ACHIEVEMENTS[a].era == e and ACHIEVEMENTS[a].get("key", false) and not done.has(a):
			return false
	return true


static func achievements_of(e: int) -> Array:
	var list := []
	for a: String in ACHIEVEMENTS:
		if ACHIEVEMENTS[a].era == e:
			list.append(a)
	return list


# --- Manuais -----------------------------------------------------------------------

## Já leu? Sem Progress (servidor dedicado, teste sem cena) conta como lido.
static func knows(manual: Variant) -> bool:
	if manual == null or String(manual) == "":
		return true
	return i == null or i.manuals.has(StringName(manual))


## Clique com o manual na mão: aprende (o livro fica, dá para emprestar).
static func read(player: Player, id: StringName) -> void:
	if i == null or not MANUALS.has(id):
		return
	var info: Dictionary = MANUALS[id]
	Sfx.play("creak", -10.0, 1.6) # página virando
	if i.manuals.has(id):
		player.notify.emit("%s: já leu. Liberou: %s" % [info.title, info.unlocks])
		return
	i.manuals[id] = true
	for r: Dictionary in CraftingUI.RECIPES:
		if String(r.get("manual", "")) == String(id):
			i.recipes[r.id] = true
	add_clue(info.clue)
	i._announce("Manual lido", info.title, "Liberou: " + info.unlocks, false)
	i._event("read", String(id))


# --- Pistas ------------------------------------------------------------------------

static func add_clue(text: String) -> void:
	if i == null or text == "":
		return
	for c in i.clues:
		if c.text == text:
			return
	i.clues.append({"text": text, "day": DayNight.i.day if DayNight.i else 1, "hour": DayNight.i.hour if DayNight.i else 12.0})
	if i.clues.size() > 60:
		i.clues.pop_front()
	i.changed.emit()


# --- Aviso no canto (conquista / era nova) -----------------------------------------------

func _announce(kind: String, title: String, text: String, big: bool) -> void:
	_queue.append({"kind": kind, "title": title, "text": text, "big": big})
	if not _toast.visible:
		_next_toast()


func _next_toast() -> void:
	if _queue.is_empty():
		_toast.visible = false
		return
	var t: Dictionary = _queue.pop_front()
	for child in _toast.get_children():
		child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(column)
	var head := Label.new()
	head.text = t.kind.to_upper()
	head.add_theme_font_size_override("font_size", 11 if not t.big else 13)
	head.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	column.add_child(head)
	var name := Label.new()
	name.text = t.title
	name.add_theme_font_size_override("font_size", 16 if not t.big else 24)
	column.add_child(name)
	var body := Label.new()
	body.text = t.text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.custom_minimum_size = Vector2(280 if not t.big else 420, 0)
	body.add_theme_font_size_override("font_size", 11 if not t.big else 13)
	body.modulate = Color(1, 1, 1, 0.8)
	column.add_child(body)
	_toast.reset_size()
	var screen := get_viewport().get_visible_rect().size
	_toast.size = Vector2.ZERO
	var size := _toast.get_combined_minimum_size()
	_toast.position = Vector2((screen.x - size.x) * 0.5, 70.0) if t.big else Vector2(screen.x - size.x - 16.0, 86.0)
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_time = 6.0 if t.big else 4.0
	if t.big:
		Sfx.play("chime", 2.0, 0.8)
	else:
		Sfx.play("chime", -2.0, 1.0)


func _process(delta: float) -> void:
	if not _toast.visible:
		return
	_toast_time -= delta
	_toast.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)
	if _toast_time <= 0.0:
		_next_toast()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("journal"):
		return
	var player: Player = get_parent().get("player")
	if player and not player.ui_blocked and not player.is_puppet():
		get_viewport().set_input_as_handled()
		JournalUI.open_for(player)


# --- Save (vai junto do jogador: Player.save_extra) --------------------------------------

func save_data() -> Dictionary:
	var ids := []
	for id in recipes:
		ids.append(String(id))
	var books := []
	for id in manuals:
		books.append(String(id))
	return {"done": done.duplicate(), "manuals": books, "recipes": ids, "clues": clues.duplicate(true)}


func load_data(data: Dictionary) -> void:
	done = data.get("done", {}).duplicate()
	manuals.clear()
	for id in data.get("manuals", []):
		manuals[StringName(id)] = true
	recipes.clear()
	for id in data.get("recipes", []):
		recipes[StringName(id)] = true
	clues = data.get("clues", []).duplicate(true)
	era = current_era()
	changed.emit()
