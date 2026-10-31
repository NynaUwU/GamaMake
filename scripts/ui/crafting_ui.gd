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
	{"id": &"machado", "station": "mesa", "cost": {&"graveto": 2, &"sucata": 2, &"fita": 1}},
	{"id": &"picareta", "station": "mesa", "cost": {&"graveto": 2, &"sucata": 3, &"fita": 1}},
	{"id": &"pa", "station": "mesa", "cost": {&"graveto": 2, &"sucata": 2}},
	{"id": &"martelo", "station": "mesa", "cost": {&"graveto": 1, &"sucata": 2}},
	{"id": &"talhadeira", "station": "mesa", "cost": {&"graveto": 1, &"sucata": 2}},
	{"id": &"lanca", "station": "mesa", "cost": {&"graveto": 3, &"sucata": 1, &"fita": 1}},
	{"id": &"vara", "station": "mesa", "cost": {&"graveto": 3, &"pano": 1, &"sucata": 1}},
	{"id": &"taco", "station": "mesa", "cost": {&"tabua": 2, &"sucata": 1}},
	{"id": &"bumerangue", "station": "mesa", "cost": {&"tabua": 2, &"fita": 1}},
	{"id": &"chinelo", "station": "mesa", "cost": {&"pano": 1, &"fita": 1}},
	{"id": &"bandagem", "station": "mesa", "cost": {&"pano": 2}},
	{"id": &"capuz", "station": "mesa", "cost": {&"pano": 3}},
	{"id": &"colete", "station": "mesa", "cost": {&"sucata": 6, &"fita": 2, &"pano": 1}},
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
	{"id": &"barra_ferro", "station": "fornalha", "fuel": true, "cost": {&"minerio_ferro": 2}},
	{"id": &"barra_cobre", "station": "fornalha", "fuel": true, "cost": {&"minerio_cobre": 2}},
	{"id": &"barra_ferro", "station": "fornalha", "fuel": true, "cost": {&"sucata": 3}, "note": "sucata"},
	{"id": &"vidro", "station": "fornalha", "fuel": true, "cost": {&"areia": 2}},
	{"id": &"vidro", "station": "fornalha", "fuel": true, "cost": {&"pedra": 4}, "note": "pedra"},
	{"id": &"carvao", "amount": 2, "station": "fornalha", "cost": {&"tronco": 1}},
	# Mão (mochila): o básico, e versões que rendem menos que na mesa.
	{"id": &"graveto", "amount": 2, "station": "mao", "cost": {&"tabua": 1}},
	{"id": &"tabua", "amount": 3, "station": "mao", "cost": {&"tronco": 1}},
	{"id": &"machado_simples", "station": "mao", "cost": {&"graveto": 2, &"pedra": 2}},
	{"id": &"picareta_simples", "station": "mao", "cost": {&"graveto": 2, &"pedra": 3}},
	{"id": &"bandagem", "station": "mao", "cost": {&"pano": 3}},
	{"id": &"capuz", "station": "mao", "cost": {&"pano": 4}},
]
const TITLES := {"mesa": "Mesa de trabalho", "fornalha": "Fornalha", "mao": "Fabricar"}
## Combustível da fornalha, na ordem de preferência: [item, quanto gasta].
const FUELS := [[&"carvao", 1], [&"tronco", 1], [&"tabua", 2]]

var player: Player
var station := "mesa"


static func open_for(p: Node, station_ := "mesa") -> void:
	if not p is Player or p.is_puppet() or p.ui_blocked:
		return
	var ui := CraftingUI.new()
	ui.player = p
	ui.station = "mesa" if station_ == "bancada" else station_
	p.get_parent().add_child(ui) # junto da cena principal (o pai do jogador)


static func recipes_for(station_: String) -> Array:
	return RECIPES.filter(func(r): return r.station == station_)


## Primeiro combustível disponível [item, quantidade] ou [].
static func fuel_for(inventory: Inventory) -> Array:
	for fuel in FUELS:
		if inventory.count(fuel[0]) >= fuel[1]:
			return fuel
	return []


static func can_craft(inventory: Inventory, recipe: Dictionary) -> bool:
	if not Builder.can_afford(inventory, recipe.cost):
		return false
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
		made += recipe.get("amount", 1)
		done += 1
	if made > 0:
		var left := player.inventory.add(recipe.id, made)
		if left > 0:
			Net.i.drop_item(recipe.id, left, player.global_transform.translated(Vector3.UP), Vector3.ZERO)
		Sfx.play("knock", -4.0, 0.9 if recipe.get("fuel", false) else 1.0)
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


func close() -> void:
	player.ui_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		close()
