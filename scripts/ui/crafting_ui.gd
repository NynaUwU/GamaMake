class_name CraftingUI
extends CanvasLayer
## Janela da mesa de trabalho e da fornalha ([E] nelas): grade de ícones com o
## nome embaixo (mesmo estilo do menu de construção). Passando o mouse aparece
## o que precisa (tem/precisa). Clique fabrica 1; Shift + clique fabrica o
## máximo possível (até uma pilha de 100: dá para fundir uma pilha inteira).
##   mesa      a única bancada: ferramentas, armas, tábuas e gravetos, metal
##   fornalha  minério/sucata -> barras, pedra -> vidro, tronco -> carvão;
##             cada fundição gasta combustível (carvão, tronco ou 2 tábuas)
##   mao       crafting de mão (na mochila): só o básico e versões que rendem menos

const RECIPES := [
	# Mesa de trabalho
	{"id": &"tabua", "amount": 8, "station": "mesa", "cost": {&"tronco": 1}},
	{"id": &"graveto", "amount": 4, "station": "mesa", "cost": {&"tabua": 1}},
	{"id": &"machado", "station": "mesa", "cost": {&"graveto": 2, &"sucata": 3}},
	{"id": &"picareta", "station": "mesa", "cost": {&"graveto": 2, &"sucata": 4}},
	{"id": &"pa", "station": "mesa", "cost": {&"graveto": 2, &"sucata": 2}},
	{"id": &"talhadeira", "station": "mesa", "cost": {&"tabua": 2, &"sucata": 2}},
	{"id": &"lanca", "station": "mesa", "cost": {&"graveto": 3, &"sucata": 1, &"pano": 1}},
	{"id": &"vara", "station": "mesa", "cost": {&"graveto": 3, &"pano": 1, &"sucata": 1}},
	{"id": &"taco", "station": "mesa", "cost": {&"tabua": 2, &"sucata": 1}},
	{"id": &"bumerangue", "station": "mesa", "cost": {&"tabua": 3}},
	{"id": &"chinelo", "station": "mesa", "cost": {&"pano": 2}},
	{"id": &"bandagem", "station": "mesa", "cost": {&"pano": 2}},
	{"id": &"garrafa", "amount": 2, "station": "fornalha", "fuel": true, "cost": {&"vidro": 1}},
	{"id": &"areia", "station": "mesa", "cost": {&"pedra": 10}},
	{"id": &"correia", "station": "mesa", "cost": {&"tecido": 2, &"fio": 2}},
	{"id": &"eixo", "amount": 3, "station": "mesa", "cost": {&"tabua": 2, &"barra_ferro": 1}},
	{"id": &"engrenagem_madeira", "amount": 2, "station": "mesa", "cost": {&"tabua": 3, &"graveto": 2}},
	{"id": &"polia", "amount": 2, "station": "mesa", "cost": {&"tabua": 2, &"barra_ferro": 1}},
	{"id": &"correia", "amount": 2, "station": "mesa", "cost": {&"couro": 1}, "note": "couro"},
	{"id": &"casaco_pele", "station": "mesa", "cost": {&"pele": 3, &"couro": 2}},
	{"id": &"gorro_la", "station": "mesa", "cost": {&"la": 3}},
	{"id": &"casaco_la", "station": "mesa", "cost": {&"la": 6, &"couro": 1}},
	{"id": &"casaco_penas", "station": "mesa", "cost": {&"pena": 12, &"tecido": 2}},
	{"id": &"botas", "station": "mesa", "cost": {&"couro": 2}, "note": "couro"},
	{"id": &"tocha", "amount": 3, "station": "mesa", "cost": {&"graveto": 2, &"pano": 1, &"carvao": 1}},
	{"id": &"cabo", "amount": 4, "station": "mesa", "cost": {&"barra_cobre": 1, &"pano": 1}},
	{"id": &"lampada", "amount": 2, "station": "mesa", "cost": {&"vidro": 1, &"barra_cobre": 1}},
	{"id": &"celula", "station": "mesa", "cost": {&"vidro": 1, &"barra_cobre": 1, &"sucata": 1}},
	{"id": &"bandeira", "station": "mesa", "cost": {&"graveto": 2, &"pano": 2}},
	{"id": &"capuz", "station": "mesa", "cost": {&"pano": 3}},
	{"id": &"colete", "station": "mesa", "cost": {&"sucata": 6, &"pano": 2}},
	{"id": &"calca", "station": "mesa", "cost": {&"pano": 3, &"sucata": 2}},
	{"id": &"botas", "station": "mesa", "cost": {&"pano": 2, &"sucata": 1}},
	{"id": &"capacete", "station": "mesa", "cost": {&"barra_ferro": 3, &"pano": 1}},
	{"id": &"peitoral", "station": "mesa", "cost": {&"barra_ferro": 6, &"pano": 2}},
	{"id": &"espada", "station": "mesa", "cost": {&"barra_ferro": 3, &"pano": 1}},
	{"id": &"pistola", "station": "mesa", "cost": {&"barra_ferro": 2, &"barra_cobre": 1, &"tabua": 1}},
	{"id": &"lanterna", "station": "mesa", "cost": {&"barra_cobre": 1, &"vidro": 1, &"fita": 1}},
	{"id": &"carregador", "station": "mesa", "cost": {&"barra_cobre": 2, &"sucata": 1}},
	{"id": &"gancho", "station": "mesa", "cost": {&"barra_ferro": 2, &"pano": 2}},
	{"id": &"colher", "station": "mesa", "cost": {&"barra_ferro": 4}},
	{"id": &"cajado", "station": "mesa", "cost": {&"barra_cobre": 3, &"vidro": 2, &"tronco": 1}},
	# Fornalha
	{"id": &"barra_cobre", "station": "fornalha", "fuel": true, "cost": {&"minerio_cobre": 2}},
	{"id": &"barra_ferro", "station": "fornalha", "fuel": true, "cost": {&"sucata": 3}, "note": "sucata"},
	{"id": &"vidro", "station": "fornalha", "fuel": true, "cost": {&"areia": 2}},
	{"id": &"vidro", "station": "fornalha", "fuel": true, "cost": {&"pedra": 4}, "note": "pedra"},
	{"id": &"carvao", "amount": 2, "station": "fornalha", "cost": {&"tronco": 1}},
	# Fornalha de pedra (Tier 1): a única que funde minério de ferro; precisa de calor do fole.
	{"id": &"barra_ferro", "station": "fornalha_pedra", "fuel": true, "heat": true, "cost": {&"minerio_ferro": 2}},
	{"id": &"barra_ferro", "station": "fornalha_pedra", "fuel": true, "heat": true, "cost": {&"sucata": 2}, "note": "sucata"},
	{"id": &"barra_cobre", "amount": 2, "station": "fornalha_pedra", "fuel": true, "cost": {&"minerio_cobre": 2}},
	{"id": &"vidro", "amount": 2, "station": "fornalha_pedra", "fuel": true, "cost": {&"areia": 2}},
	{"id": &"tijolo", "amount": 2, "station": "fornalha_pedra", "fuel": true, "cost": {&"argila": 2}},
	# Forno de tijolo: pão e assados.
	{"id": &"pao_fresco", "amount": 2, "station": "forno", "fuel": true, "cost": {&"farinha": 2, &"agua": 1}},
	{"id": &"torrada", "amount": 2, "station": "forno", "fuel": true, "cost": {&"pao_fresco": 1}},
	{"id": &"batata_assada", "amount": 3, "station": "forno", "fuel": true, "cost": {&"batata": 3}},
	# Mesa: roupas de tecido (Tier 1).
	{"id": &"casaco", "station": "mesa", "cost": {&"tecido": 4, &"pano": 1}},
	{"id": &"pano", "amount": 3, "station": "mesa", "cost": {&"tecido": 1}},
	# Tier 3: canos na mesa (no torno rende o dobro), antisséptico.
	{"id": &"cano", "amount": 2, "station": "mesa", "cost": {&"barra_cobre": 1}},
	{"id": &"bandagem_esteril", "station": "mesa", "cost": {&"bandagem": 1, &"alcool": 1}},
	# Alto-forno (multibloco, precisa do fole girando pela energia): aço. Só queima carvão.
	{"id": &"barra_aco", "station": "alto_forno", "fuel": true, "power": true, "cost": {&"barra_ferro": 2}},
	{"id": &"barra_aco", "station": "alto_forno", "fuel": true, "power": true, "cost": {&"sucata": 4}, "note": "sucata"},
	# Torno (precisa de energia: eixo girando).
	{"id": &"parafuso", "amount": 4, "station": "torno", "power": true, "cost": {&"barra_ferro": 1}},
	{"id": &"engrenagem", "station": "torno", "power": true, "cost": {&"barra_ferro": 2}},
	{"id": &"eixo_aco", "station": "torno", "power": true, "cost": {&"barra_aco": 1}},
	{"id": &"cano", "amount": 4, "station": "torno", "power": true, "cost": {&"barra_cobre": 1}},
	{"id": &"bobina", "station": "torno", "power": true, "cost": {&"barra_cobre": 3, &"barra_ferro": 1}},
	# Prensa (precisa de energia).
	{"id": &"suco", "station": "prensa", "power": true, "cost": {&"fruta": 3, &"garrafa": 1}},
	{"id": &"oleo", "station": "prensa", "power": true, "cost": {&"semente_algodao": 4, &"garrafa": 1}},
	{"id": &"oleo", "station": "prensa", "power": true, "cost": {&"gordura": 2, &"garrafa": 1}, "note": "gordura"},
	# Destilaria (fogo + 1 de água por lote, da caixa d'água/cano ou despejada com garrafa).
	{"id": &"alcool", "station": "destilaria", "fuel": true, "water": 1, "cost": {&"trigo": 4}},
	{"id": &"alcool", "station": "destilaria", "fuel": true, "water": 1, "cost": {&"fruta": 3}, "note": "fruta"},
	{"id": &"alcool", "station": "destilaria", "fuel": true, "water": 1, "cost": {&"batata": 4}, "note": "batata"},
	# Mão (mochila): o básico, e versões que rendem menos que na mesa.
	{"id": &"graveto", "amount": 2, "station": "mao", "cost": {&"tabua": 1}},
	{"id": &"tabua", "amount": 3, "station": "mao", "cost": {&"tronco": 1}},
	{"id": &"machado_simples", "station": "mao", "cost": {&"graveto": 2, &"pedra": 2}},
	{"id": &"picareta_simples", "station": "mao", "cost": {&"graveto": 2, &"pedra": 3}},
	{"id": &"bandagem", "station": "mao", "cost": {&"pano": 3}},
	{"id": &"capuz", "station": "mao", "cost": {&"pano": 4}},
	{"id": &"areia", "station": "mao", "cost": {&"pedra": 10}},
	{"id": &"martelo", "station": "mao", "cost": {&"tronco": 1, &"tabua": 2}},
	{"id": &"tocha", "station": "mao", "cost": {&"graveto": 1, &"pano": 1}},
]
const TITLES := {"mesa": "Mesa de trabalho", "fornalha": "Fornalha", "mao": "Fabricar", "forno": "Forno de tijolo",
	"fornalha_pedra": "Fornalha de pedra", "torno": "Torno", "prensa": "Prensa"}
## Fornalha de pedra aberta agora (o calor do fole libera as receitas "heat").
static var heat_source: PlacedObject
## Combustível da fornalha, na ordem de preferência: [item, quanto gasta].
const FUELS := [[&"carvao", 1], [&"tronco", 1], [&"tabua", 2]]

var player: Player
var station := "mesa"


static func open_for(p: Node, station_ := "mesa", source: PlacedObject = null) -> void:
	if not p is Player or p.is_puppet() or p.ui_blocked:
		return
	heat_source = source
	var ui := CraftingUI.new()
	ui.player = p
	ui.station = "mesa" if station_ == "bancada" else station_
	p.get_parent().add_child(ui) # junto da cena principal (o pai do jogador)


static func recipes_for(station_: String) -> Array:
	return RECIPES.filter(func(r): return r.station == station_)


## Torno/prensa com energia chegando (a rede do eixo tem força).
static func powered(source: PlacedObject) -> bool:
	return is_instance_valid(source) and source.extra.get("speed", 0.0) >= 0.2


## Primeiro combustível disponível [item, quantidade] ou [].
static func fuel_for(inventory: Inventory) -> Array:
	for fuel in FUELS:
		if inventory.count(fuel[0]) >= fuel[1]:
			return fuel
	return []


static func can_craft(inventory: Inventory, recipe: Dictionary) -> bool:
	if not Builder.can_afford(inventory, recipe.cost):
		return false
	if recipe.get("heat", false) and (not is_instance_valid(heat_source) or Machines.heat(heat_source) < Machines.HEAT_NEEDED):
		return false # fornalha fria: segure E no fole
	if recipe.get("power", false) and not powered(heat_source):
		return false # torno/prensa parados: falta o eixo girando
	if recipe.get("fuel", false):
		var fuel := fuel_for(inventory)
		if fuel.is_empty():
			return false
		# O combustível não pode ser o próprio ingrediente que vai faltar.
		var need: Dictionary = recipe.cost.duplicate()
		need[fuel[0]] = need.get(fuel[0], 0) + fuel[1]
		return Builder.can_afford(inventory, need)
	return true


## Fabrica "times" vezes (para no que faltar). Devolve quantas fez.
static func craft(player: Player, recipe: Dictionary, times := 1) -> int:
	var done := 0
	var made := 0
	while done < times and can_craft(player.inventory, recipe):
		if recipe.get("fuel", false):
			var fuel := fuel_for(player.inventory)
			Builder.pay(player.inventory, {fuel[0]: fuel[1]})
		Builder.pay(player.inventory, recipe.cost)
		for id in recipe.cost: # água usada: a garrafa vazia volta
			var returns: StringName = ItemDB.def(id).get("returns", &"")
			if returns != &"":
				player.inventory.add(returns, recipe.cost[id])
		made += recipe.get("amount", 1)
		done += 1
	if made > 0:
		var left := player.inventory.add(recipe.id, made)
		if left > 0:
			Net.i.drop_item(recipe.id, left, player.global_transform.translated(Vector3.UP), Vector3.ZERO)
		Sfx.play("knock", -4.0, 0.9 if recipe.get("fuel", false) else 1.0)
		if recipe.station == "forno" and is_instance_valid(heat_source):
			(heat_source.get_parent() as PlacedManager).request("fuel", [heat_source.net_id, 45.0, "lit_until"]) # o forno acende um pouco
		if recipe.get("power", false) and is_instance_valid(heat_source):
			# Torno/prensa trabalhando: puxam força da rede por uns segundos (e fazem barulho).
			var manager := heat_source.get_parent() as PlacedManager
			manager.request("extra", [heat_source.net_id, {"used": manager.clock + 6.0}])
			Sfx.play_at("creak", heat_source.global_position + Vector3.UP * 0.8, 0.0, 1.4 if recipe.station == "torno" else 0.7)
	else:
		Sfx.play("click", -6.0, 0.6) # faltou material
	return done


## Quantas vezes dá para fazer de uma vez (Shift): até encher uma pilha (100).
static func max_times(recipe: Dictionary) -> int:
	return maxi(1, int(ItemDB.max_stack(recipe.id) / recipe.get("amount", 1)))


func _ready() -> void:
	layer = 9
	player.ui_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	LegacyGUI.close_on_outside(self, close)
	var column := LegacyGUI.box(center, TITLES.get(station, "Mesa de trabalho"), 400.0)
	var grid := RecipeGrid.new()
	grid.setup(player, station, 6, 250.0)
	column.add_child(grid)


var _heat_refresh := 1.0
func _process(delta: float) -> void:
	# Fornalha de pedra: o calor cai com o tempo; reavalia o que dá para fundir.
	if heat_source == null:
		return
	_heat_refresh -= delta
	if _heat_refresh <= 0.0:
		_heat_refresh = 1.0
		for grid in find_children("*", "RecipeGrid", true, false):
			grid.refresh()


func close() -> void:
	player.ui_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		close()
