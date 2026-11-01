class_name Builder
extends Node
## Ferramentas de construção na mão do player (só o jogador local tem).
##
## Martelo: mostra a peça "fantasma" na grade (verde = cabe, vermelho = já tem
## peça ali). Clique constrói, R gira a parede, Shift + botão direito desmonta a peça
## (ou tira a janela/porta) mirada. SEGURAR o botão direito abre o menu de
## construção (abas + lista com rolagem): solte em cima do item para escolher.
## Encaixes: parede mirando um piso/teto vai para a borda mais perto dele;
## mirando o topo de uma parede empilha; piso/teto mirando a borda de outro
## piso vai para o lado; teto mirando o topo de uma parede cobre o cômodo.
## Janela/Porta: mire um buraco feito pela talhadeira; ela preenche o buraco
## inteiro (qualquer formato). A porta precisa de um buraco que encoste na base
## da parede.
##
## Talhadeira: clique tira o meio quadrado mirado (triângulo); R troca a
## diagonal do corte ("/" ou "\\"). Clique e ARRASTE seleciona uma área
## (retângulo de quadrados) e tira tudo ao soltar.
##
## Custo: cada peça gasta material do inventário ("cost"); desmontar devolve
## metade. Aba Outros: potes, floreira, canteiro (piso de terra na grade) e
## bancada de fabricação (PlacedManager).

const REACH := 7.0
const MASK := 1 | (1 << 5) # mundo + interagíveis (armadilhas no chão)
const ENTRIES := {
	"Estrutura": [
		{"id": "wall", "name": "Parede", "kind": BuildPiece.Kind.WALL, "desc": "2,8 x 2,8 m; R gira", "cost": {&"tabua": 4}},
		{"id": "floor", "name": "Piso", "kind": BuildPiece.Kind.FLOOR, "desc": "Topo na altura da grade", "cost": {&"tabua": 4}},
		{"id": "roof", "name": "Teto", "kind": BuildPiece.Kind.ROOF, "desc": "Apoia no topo das paredes", "cost": {&"tabua": 4}},
		{"id": "pillar", "name": "Pilar", "kind": BuildPiece.Kind.PILLAR, "desc": "0,4 m de lado, 2,8 m de altura. R deita (viga): em cima de uma parede cobre o topo dela", "cost": {&"tabua": 1, &"pedra": 1}},
		{"id": "stairs", "name": "Escada", "place": "stairs", "desc": "Sobe um andar (2,8 m) para a frente. Segure Shift para alinhar com a grade", "cost": {&"tabua": 6, &"graveto": 2}},
	],
	"Aberturas": [
		{"id": "window", "name": "Janela", "fill": "window", "desc": "Preenche um buraco feito pela talhadeira", "cost": {&"graveto": 2, &"vidro": 1}},
		{"id": "door", "name": "Porta", "fill": "door", "desc": "Buraco que encoste no chão; [E] abre", "cost": {&"tabua": 3, &"sucata": 1}},
	],
	"Outros": [
		{"id": "pot_small", "name": "Pote", "place": "pot_small", "desc": "Pote de barro: 1 planta (não cabe abóbora)", "cost": {&"pedra": 2}},
		{"id": "pot_wide", "name": "Floreira", "place": "pot_wide", "desc": "Floreira larga: 3 plantas", "cost": {&"tabua": 2, &"pedra": 2}},
		{"id": "bed", "name": "Canteiro", "place": "bed", "desc": "Piso de terra na grade da construção: 9 plantas", "cost": {&"tabua": 3, &"pedra": 4}},
		{"id": "chest", "name": "Baú", "place": "chest", "desc": "Guarda 20 itens (arraste entre o baú e a mochila)", "cost": {&"tabua": 6, &"sucata": 1}},
		{"id": "drawboard", "name": "Lousa", "place": "drawboard", "desc": "Cavalete com tela: desenhe junto com os outros jogadores", "cost": {&"tabua": 4, &"pano": 1}},
	],
	"Máquinas": [
		{"id": "workbench", "name": "Mesa de trabalho", "place": "workbench", "desc": "A bancada de fabricação: ferramentas, armas, lanterna...", "cost": {&"tabua": 6, &"sucata": 3}},
		{"id": "campfire", "name": "Fogueira", "place": "campfire", "desc": "Fogueira com grelha: assa comida (enche mais a fome) e ilumina", "cost": {&"pedra": 5, &"tabua": 3}},
		{"id": "furnace", "name": "Fornalha", "place": "furnace", "desc": "Funde minério em barras, faz vidro e carvão", "cost": {&"pedra": 10, &"tabua": 2}},
		{"id": "rain_collector", "name": "Coletor", "place": "rain_collector", "desc": "Barril com funil: junta água da chuva (potável). Clique nele com uma garrafa vazia", "cost": {&"tabua": 4, &"pano": 1}},
		{"id": "dryer", "name": "Secador", "place": "dryer", "desc": "Varal de galhos: peixe e frutos do lago viram peixe seco (enche mais, não queima)", "cost": {&"graveto": 6, &"pano": 1}},
		{"id": "grindstone", "name": "Amolar", "place": "grindstone", "desc": "Pedra de amolar: segure E com a ferramenta/arma na mão para recuperar a durabilidade (gasta stamina)", "cost": {&"pedra": 6, &"tabua": 2, &"graveto": 2}},
		{"id": "quern", "name": "Moinho", "place": "quern", "desc": "Moinho manual: ponha trigo e segure E para moer em farinha (gasta stamina)", "cost": {&"pedra": 8, &"tabua": 2}},
		{"id": "oven", "name": "Forno", "place": "oven", "desc": "Forno de tijolo: farinha + água = pão (com combustível)", "cost": {&"tijolo": 10, &"pedra": 4}},
		{"id": "pump", "name": "Bomba", "place": "pump", "desc": "Bomba d'água manual: só na beira do lago. Segure E com uma garrafa vazia: água suja sem fim", "cost": {&"barra_ferro": 2, &"tabua": 3, &"sucata": 2}},
		{"id": "filter", "name": "Filtro", "place": "filter", "desc": "Areia + carvão: ponha água suja e espere, sai potável", "cost": {&"tabua": 3, &"areia": 4, &"carvao": 3, &"pano": 1}},
		{"id": "stone_furnace", "name": "Forn. pedra", "place": "stone_furnace", "desc": "Fornalha de tijolo com fole: a única que funde minério de ferro. Segure E para esquentar no fole", "cost": {&"tijolo": 12, &"pedra": 6, &"pano": 2}},
		{"id": "sieve", "name": "Peneira", "place": "sieve", "desc": "Ponha argila e segure E: cada argila peneirada tem 50% de chance de dar uma pedra", "cost": {&"tabua": 3, &"graveto": 4, &"pano": 1}},
		{"id": "spinning", "name": "Roca", "place": "spinning", "desc": "Fibra de algodão vira fio (segure E)", "cost": {&"tabua": 4, &"graveto": 4, &"sucata": 1}},
		{"id": "loom", "name": "Tear", "place": "loom", "desc": "Fio vira tecido (segure E)", "cost": {&"tabua": 6, &"graveto": 6}},
		{"id": "water_wheel", "name": "Roda d'água", "place": "water_wheel", "desc": "Na beira de um rio, de frente para a água: gira sem parar (força 4). A porta de latão fica na margem", "cost": {&"tabua": 14, &"barra_ferro": 3}},
		{"id": "windmill", "name": "Moinho vento", "place": "windmill", "desc": "Força conforme o vento (até 6, mais alto = mais forte). Porta de latão na base", "cost": {&"tabua": 12, &"tecido": 4, &"barra_ferro": 2}},
		{"id": "shaft", "name": "Eixo", "place": "shaft", "desc": "Leva o giro adiante: encaixa sozinho na porta de latão mais perto. Use correias para ligar de longe", "cost": {&"tabua": 2, &"barra_ferro": 1}},
		{"id": "sawmill", "name": "Serraria", "place": "sawmill", "desc": "Com energia: 1 tronco vira 12 tábuas (força 3)", "cost": {&"tabua": 8, &"barra_ferro": 4, &"sucata": 2}},
		{"id": "ram_pump", "name": "Carneiro", "place": "ram_pump", "desc": "Na beira de um rio: bombeia água sem energia. Irriga as plantações em volta (10 m crescem 50% mais rápido) e enche garrafas", "cost": {&"barra_ferro": 4, &"sucata": 4, &"tabua": 2}},
		{"id": "smoker", "name": "Defumador", "place": "smoker", "desc": "Peixe cru vira defumado: enche muito e nunca estraga", "cost": {&"tijolo": 4, &"tabua": 4, &"sucata": 1}},
		{"id": "compost", "name": "Composteira", "place": "compost", "desc": "Comida estragada e restos viram adubo (colheitas em dobro)", "cost": {&"tabua": 5, &"graveto": 2}},
	],
	"Vapor": [
		{"id": "blast_furnace", "name": "Alto-forno", "place": "blast_furnace", "desc": "Base do alto-forno: empilhe 2 anéis em cima e ligue um eixo com força no fole. Ferro + carvão = aço", "cost": {&"tijolo": 16, &"pedra": 6, &"barra_ferro": 2}},
		{"id": "blast_stack", "name": "Anel alto-forno", "place": "blast_stack", "desc": "Mire no topo da base do alto-forno (ou de outro anel) para empilhar. Precisa de 2", "cost": {&"tijolo": 10}},
		{"id": "boiler", "name": "Caldeira", "place": "boiler", "desc": "Fogo + água = vapor para o motor. Água pelo cano (latão à esquerda) ou despejada com garrafa. SECA E QUENTE, EXPLODE", "cost": {&"barra_aco": 4, &"tijolo": 6, &"barra_cobre": 2, &"parafuso": 4}},
		{"id": "steam_engine", "name": "Motor a vapor", "place": "steam_engine", "desc": "Vapor da caldeira (cano no alto do cilindro) vira força 10 nos eixos (porta à direita)", "cost": {&"barra_aco": 3, &"engrenagem": 2, &"parafuso": 6, &"eixo_aco": 1, &"oleo": 1}},
		{"id": "water_tank", "name": "Caixa d'água", "place": "water_tank", "desc": "Guarda 60 de água (4 portas). Guarda o que sobra e solta quando falta. [E] enche garrafa", "cost": {&"tabua": 8, &"barra_ferro": 2}},
		{"id": "sprinkler", "name": "Aspersor", "place": "sprinkler", "desc": "Com água no cano, molha as plantações a 8 m: crescem 50% mais rápido", "cost": {&"barra_cobre": 2, &"parafuso": 1}},
		{"id": "lathe", "name": "Torno", "place": "lathe", "desc": "Com eixo girando: parafusos, engrenagens, eixo de aço e canos", "cost": {&"tabua": 6, &"barra_ferro": 4, &"sucata": 2}},
		{"id": "press", "name": "Prensa", "place": "press", "desc": "Com eixo girando: fruta = suco; sementes de algodão ou gordura = óleo", "cost": {&"tabua": 6, &"barra_ferro": 3, &"parafuso": 2}},
		{"id": "distillery", "name": "Destilaria", "place": "distillery", "desc": "Fogo + água + trigo, fruta ou batata = álcool (combustível dos carros e antisséptico)", "cost": {&"barra_cobre": 6, &"tijolo": 6, &"cano": 2}},
	],
	"Armadilhas": [
		{"id": "spikes", "name": "Estacas", "place": "spikes", "desc": "Machucam a perna de quem passa (30 usos)", "cost": {&"tabua": 4}},
		{"id": "beartrap", "name": "Arm. de urso", "place": "beartrap", "desc": "Prende o zumbi: atordoa e quebra a perna. [E] arma de novo", "cost": {&"barra_ferro": 2}},
		{"id": "barbed", "name": "Cerca de espinhos", "place": "barbed", "desc": "Bloqueia; quem bate nela se machuca (12 golpes)", "cost": {&"tabua": 4, &"barra_ferro": 1}},
		{"id": "mine", "name": "Mina", "place": "mine", "desc": "Explode quando um zumbi chega perto (uma vez)", "cost": {&"sucata": 2, &"carvao": 3}},
	],
}

## Tamanho (caixa do fantasma) dos objetos da aba Outros.
const PLACE_SIZE := {"pot_small": Vector3(0.46, 0.31, 0.46), "pot_wide": Vector3(1.24, 0.36, 0.48), "bench": Vector3(1.6, 0.9, 0.75),
	"campfire": Vector3(1.0, 0.6, 1.0), "furnace": Vector3(1.2, 1.2, 1.0), "workbench": Vector3(1.9, 1.95, 0.85),
	"spikes": Vector3(1.2, 0.35, 1.2), "beartrap": Vector3(0.55, 0.1, 0.55), "barbed": Vector3(2.4, 1.1, 0.3), "mine": Vector3(0.36, 0.1, 0.36), "drawboard": Vector3(1.1, 1.8, 0.6), "chest": Vector3(1.0, 0.84, 0.62),
	"rain_collector": Vector3(0.8, 1.1, 0.8), "dryer": Vector3(1.5, 1.5, 0.5), "grindstone": Vector3(0.9, 1.1, 0.5),
	"quern": Vector3(0.8, 0.9, 0.8), "oven": Vector3(1.24, 1.1, 1.24), "pump": Vector3(0.6, 1.2, 0.6), "filter": Vector3(0.7, 0.9, 0.45),
	"stone_furnace": Vector3(1.6, 1.6, 1.1), "spinning": Vector3(1.0, 1.1, 0.4), "loom": Vector3(1.3, 1.2, 0.8),
	"smoker": Vector3(0.8, 1.4, 0.6), "compost": Vector3(1.0, 0.7, 0.9), "sieve": Vector3(0.95, 0.8, 0.65),
	"water_wheel": Vector3(1.3, 1.6, 3.2), "windmill": Vector3(1.5, 4.5, 1.5), "shaft": Vector3(2.0, 0.7, 0.5),
	"sawmill": Vector3(2.1, 0.9, 0.75), "ram_pump": Vector3(0.6, 1.8, 2.0), "stairs": Vector3(1.2, 2.8, 2.8),
	"blast_furnace": Vector3(1.6, 1.3, 1.6), "blast_stack": Vector3(1.4, 1.05, 1.4), "boiler": Vector3(2.3, 2.9, 1.15),
	"steam_engine": Vector3(1.6, 1.4, 1.4), "water_tank": Vector3(1.1, 1.45, 1.1), "sprinkler": Vector3(0.36, 0.8, 0.36),
	"lathe": Vector3(2.0, 1.1, 0.6), "press": Vector3(1.3, 1.7, 0.8), "distillery": Vector3(1.7, 1.45, 0.9), "pipe": Vector3(0.18, 0.18, 1.0)}
## Centro da caixa (vermelha, ao desmontar) quando não é logo acima da origem.
const PLACE_CENTER := {"bed": Vector3(1.4, 0.1, 1.4), "stairs": Vector3(0, 1.4, -1.4), "steam_engine": Vector3(0.45, 0.7, -0.3),
	"distillery": Vector3(0.15, 0.72, 0), "boiler": Vector3(0, 1.45, 0), "pipe": Vector3(0, 0, 0.5)}
## Shift: deslocamento da origem na grade (a escada tem 3 quadrados de largura: borda na linha da grade).
const GRID_OFFSET := {"stairs": Vector3(0.2, 0, 0)}
const PLACE_RADIUS := {"pot_small": 0.35, "pot_wide": 0.7, "bench": 0.9, "campfire": 0.6, "furnace": 0.8, "workbench": 1.0,
	"spikes": 0.7, "beartrap": 0.35, "barbed": 0.9, "mine": 0.3, "drawboard": 0.6, "chest": 0.6, "rain_collector": 0.5, "dryer": 0.8, "grindstone": 0.5,
	"quern": 0.5, "oven": 0.7, "pump": 0.35, "filter": 0.45, "stone_furnace": 0.9, "spinning": 0.55, "loom": 0.7, "smoker": 0.5, "compost": 0.6, "sieve": 0.55,
	"water_wheel": 0.6, "windmill": 0.9, "shaft": 0.3, "sawmill": 1.0, "ram_pump": 0.4, "stairs": 0.6,
	"blast_furnace": 0.9, "blast_stack": 0.1, "boiler": 1.1, "steam_engine": 0.9, "water_tank": 0.6, "sprinkler": 0.25,
	"lathe": 1.0, "press": 0.7, "distillery": 0.9}

var player: Player
var selection: Dictionary = ENTRIES["Estrutura"][0]
var kind := BuildPiece.Kind.WALL
var flip := false ## R: gira a parede (o padrão é ficar de frente para quem constrói) ou deita o pilar (viga)
var target := {} ## onde o martelo vai construir {kind, cell, rot, valid}
var fill_target := {} ## buraco mirado para janela/porta {piece, tris, valid}
var cut_target := {} ## {piece, quarters}: meio quadrado mirado pela talhadeira
var repair_target: BuildPiece ## peça com dano de zumbi mirada (clique conserta)
var cut_selection := PackedInt32Array() ## partes (quartos) da área arrastada
var diag := "/" ## diagonal do corte da talhadeira (R troca)

var _ghost: Node3D
var _ghost_mesh: MeshInstance3D
var _ghost_material: StandardMaterial3D
var _model_ghost: Node3D ## silhueta do modelo de verdade (objetos colocáveis)
var _model_material: StandardMaterial3D
var _model_kind := ""
var _remove_mesh: MeshInstance3D ## Shift: caixa vermelha no que o clique direito desmonta
var _highlight: MeshInstance3D
var _highlight_mesh := ImmediateMesh.new()
var _mark: StandardMaterial3D
var _drag := {} # talhadeira arrastando: {piece, square, triangle}
var _menu: BuildMenu


func _ready() -> void:
	_ghost = Node3D.new()
	_ghost.top_level = true
	add_child(_ghost)
	_ghost_mesh = MeshInstance3D.new()
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_mesh.material_override = _ghost_material
	_ghost_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.add_child(_ghost_mesh)
	_model_material = StandardMaterial3D.new()
	_model_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_model_material.cull_mode = BaseMaterial3D.CULL_BACK
	_model_material.roughness = 1.0
	_model_ghost = Node3D.new()
	_ghost.add_child(_model_ghost)
	_remove_mesh = MeshInstance3D.new()
	_remove_mesh.top_level = true
	var remove_mat := StandardMaterial3D.new()
	remove_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	remove_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	remove_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	remove_mat.albedo_color = Color(1.0, 0.2, 0.15, 0.28)
	_remove_mesh.material_override = remove_mat
	_remove_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_remove_mesh.visible = false
	add_child(_remove_mesh)
	_highlight = MeshInstance3D.new()
	_highlight.top_level = true
	_highlight.mesh = _highlight_mesh
	_mark = StandardMaterial3D.new()
	_mark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark.albedo_color = Color(1.0, 0.85, 0.2, 0.55)
	_mark.cull_mode = BaseMaterial3D.CULL_DISABLED
	_highlight.material_override = _mark
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight)
	_menu = BuildMenu.new()
	_menu.builder = self
	add_child(_menu)
	_set_ghost_shape()


## Modelo para a foto do menu (a peça em si; janela/porta numa parede com o buraco).
static func preview_model(entry: Dictionary) -> Node3D:
	if entry.has("place"):
		var obj := PlacedObject.new()
		obj.setup(entry.place)
		if entry.place == "pot_small" or entry.place == "pot_wide":
			obj.crops[0] = {"crop": "cenoura", "t": -1000.0} # com uma planta, para a foto
			obj.refresh(0.0)
		return obj
	var piece := BuildPiece.new()
	if entry.has("kind"):
		piece.setup(entry.kind, Vector3i.ZERO, 0)
		return piece
	piece.setup(BuildPiece.Kind.WALL, Vector3i.ZERO, 0)
	var parts := PackedInt32Array()
	var rows := range(0, 5) if entry.fill == "door" else range(2, 5)
	for j in rows:
		for i in range(2, 5):
			for q in 4:
				parts.append((j * BuildPiece.N + i) * 4 + q)
	for t in parts:
		piece.removed[t] = 1
	piece.add_fill(entry.fill, parts)
	return piece


func _manager() -> BuildingManager:
	return player.get_parent().get_node_or_null("Building") as BuildingManager


func tool_name() -> String:
	if repair_target:
		return "Consertar  [%s]" % cost_text(repair_cost(repair_target), player.inventory)
	var text: String = "%s%s" % [selection.name, "  (girada)" if flip and selection.get("kind", -1) == BuildPiece.Kind.WALL else ""]
	if selection.has("cost"):
		text += "  [%s]" % cost_text(selection.cost, player.inventory if player else null)
	return text


# --- Custo -----------------------------------------------------------------------

## "4 Tábua, 1 Pedra" (com inventário: "4/10 Tábua").
static func cost_text(cost: Dictionary, inventory: Inventory = null) -> String:
	var parts := []
	for id in cost:
		if inventory:
			parts.append("%d/%d %s" % [inventory.count(id), cost[id], ItemDB.display_name(id)])
		else:
			parts.append("%d %s" % [cost[id], ItemDB.display_name(id)])
	return ", ".join(parts)


## Consertar: 1 tábua a cada 2 quadradinhos quebrados.
static func repair_cost(piece: BuildPiece) -> Dictionary:
	return {&"tabua": maxi(1, ceili(piece.damaged.size() / 8.0))}


static func can_afford(inventory: Inventory, cost: Dictionary) -> bool:
	for id in cost:
		if inventory.count(id) < cost[id]:
			return false
	return true


static func pay(inventory: Inventory, cost: Dictionary) -> void:
	for id in cost:
		var left: int = cost[id]
		for i in inventory.slots.size():
			if left <= 0:
				break
			if not inventory.slots[i].is_empty() and inventory.slots[i].id == id:
				left -= inventory.take(i, left).get("amount", 0)


## Desmontou: devolve metade (arredondando para cima).
func _refund(cost: Dictionary) -> void:
	for id in cost:
		var amount := ceili(cost[id] * 0.5)
		var left := player.inventory.add(id, amount)
		if left > 0:
			Net.i.drop_item(id, left, player.global_transform.translated(Vector3.UP), Vector3.ZERO)


func _paid(entry: Dictionary) -> bool:
	var cost: Dictionary = entry.get("cost", {})
	if not can_afford(player.inventory, cost):
		Sfx.play("click", -6.0, 0.6)
		return false
	pay(player.inventory, cost)
	return true


static func entry_for_kind(kind_: int) -> Dictionary:
	for entry in ENTRIES["Estrutura"]:
		if entry.get("kind", -1) == kind_:
			return entry
	return {}


static func entry_for(key: String, value: String) -> Dictionary:
	for tab in ENTRIES:
		for entry in ENTRIES[tab]:
			if entry.get(key, "") == value:
				return entry
	return {}


func select(entry: Dictionary) -> void:
	selection = entry
	_apply_ghost(entry)
	player._emit_weapon_text()


func _apply_ghost(entry: Dictionary) -> void:
	_ghost_mesh.visible = true
	_model_ghost.visible = false
	if entry.has("kind"):
		kind = entry.kind
		_set_ghost_shape()
	elif entry.has("place"):
		if entry.place == "bed":
			kind = BuildPiece.Kind.FLOOR
		_build_model_ghost(entry.place)
		_ghost_mesh.visible = false
		_model_ghost.visible = true


## Copia só as malhas do modelo de verdade (sem colisão, sem grupos, sem fogo
## registrado) para a silhueta translúcida.
func _build_model_ghost(place: String) -> void:
	if place == _model_kind:
		return
	_model_kind = place
	for child in _model_ghost.get_children():
		_model_ghost.remove_child(child)
		child.queue_free()
	var obj := PlacedObject.new()
	obj.setup(place)
	Cooking.fires.erase(obj)
	var stack := [[obj, Transform3D()]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		for child in item[0].get_children():
			if not child is Node3D:
				continue
			var xform: Transform3D = item[1] * child.transform
			if child is MeshInstance3D and child.mesh and child.visible:
				var copy := MeshInstance3D.new()
				copy.mesh = child.mesh
				copy.transform = xform
				copy.material_override = _model_material
				copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_model_ghost.add_child(copy)
			stack.append([child, xform])
	obj.free()


func _tint(valid: bool) -> void:
	_ghost_material.albedo_color = Color(0.3, 1.0, 0.4, 0.35) if valid else Color(1.0, 0.25, 0.2, 0.35)
	_model_material.albedo_color = Color(0.55, 1.0, 0.6, 0.5) if valid else Color(1.0, 0.35, 0.3, 0.5)
	_model_material.emission_enabled = true
	_model_material.emission = Color(0.1, 0.4, 0.15) if valid else Color(0.45, 0.08, 0.05)


func open_menu() -> void:
	_menu.open()


func menu_open() -> bool:
	return _menu.visible


func rotate() -> void:
	flip = not flip


func toggle_diagonal() -> void:
	diag = "\\" if diag == "/" else "/"


## Chamado todo frame pelo player com a ferramenta da mão ("hammer", "chisel" ou "").
func update(tool: String) -> void:
	target = {}
	fill_target = {}
	cut_target = {}
	repair_target = null
	_ghost.visible = false
	_highlight.visible = false
	_remove_mesh.visible = false
	if tool != "chisel":
		_drag = {}
	if _manager() == null or player.vehicle != null or _menu.visible:
		return
	if tool == "hammer":
		if Input.is_key_pressed(KEY_SHIFT):
			_mark_removal() # o que o Shift + clique direito desmontaria fica vermelho
		# Mirando uma peça quebrada por zumbi: o clique conserta (mostra o dano).
		var aimed := _ray()
		if aimed and aimed.collider is BuildPiece and not aimed.collider.damaged.is_empty():
			repair_target = aimed.collider
			_draw_triangles(repair_target, PackedInt32Array(repair_target.damaged.keys()), Color(0.3, 1.0, 0.45, 0.5))
			return
		if selection.has("place"):
			target = _compute_place()
			if target.is_empty():
				return
			_ghost.visible = true
			_ghost.global_transform = target.xform
			_tint(target.valid)
			return
		if selection.has("fill"):
			fill_target = _compute_hole()
			if not fill_target.is_empty():
				var color := Color(0.4, 0.7, 1.0, 0.5) if selection.fill == "window" else Color(0.8, 0.5, 0.25, 0.6)
				_draw_triangles(fill_target.piece, fill_target.tris, color if fill_target.valid else Color(1, 0.2, 0.15, 0.5))
			return
		target = _compute_target()
		if target.is_empty():
			return
		_ghost.visible = true
		_ghost.global_transform = BuildPiece.piece_transform(target.kind, target.cell, target.rot)
		_tint(target.valid)
	elif tool == "chisel":
		if not _drag.is_empty():
			_update_drag()
			return
		var hit := _ray()
		if hit.is_empty() or not hit.collider is BuildPiece:
			return
		var piece: BuildPiece = hit.collider
		var half := piece.half_at(hit.position, hit.normal, diag)
		if half.is_empty():
			return
		cut_target = {"piece": piece, "quarters": half}
		_draw_triangles(piece, half, Color(1.0, 0.85, 0.2, 0.55))


## Clique com o martelo (constrói ou encaixa janela/porta)
## ou com a talhadeira (começa a selecionar). Devolve true se fez algo.
func use(tool: String) -> bool:
	var manager := _manager()
	if manager == null or _menu.visible:
		return false
	if tool == "hammer":
		if repair_target:
			var cost := repair_cost(repair_target)
			if _paid({"cost": cost}):
				manager.request_repair(repair_target)
				Sfx.play_at("knock", repair_target.global_position, 0.0, 1.1)
				return true
			return false
		if selection.has("place"):
			if selection.place in ["water_wheel", "ram_pump"] and not target.is_empty() and not _placed().river_bank(target.xform.origin):
				Sfx.play("click", -6.0, 0.6) # só na beira de um rio
				return false
			if selection.place == "pump" and not target.is_empty() and not Farming._shore(target.xform.origin):
				Sfx.play("click", -6.0, 0.6) # bomba só na beira do lago
				return false
			if not target.is_empty() and target.valid and _paid(selection):
				_placed().request("place", [selection.place, target.xform])
				return true
			return false
		if selection.has("fill"):
			if not fill_target.is_empty() and fill_target.valid and _paid(selection):
				manager.request_fill(fill_target.piece, selection.fill, fill_target.tris)
				return true
			return false
		if not target.is_empty() and target.valid and _paid(selection):
			manager.request_place(target.kind, target.cell, target.rot)
			return true
	elif tool == "chisel" and not cut_target.is_empty():
		var piece: BuildPiece = cut_target.piece
		var square: int = cut_target.quarters[0] / 4
		_drag = {"piece": piece, "quarters": cut_target.quarters, "square": Vector2i(square % BuildPiece.N, square / BuildPiece.N)}
		cut_selection = cut_target.quarters
		return true
	return false


## Shift + botão direito (ao soltar): desmonta a peça, janela/porta ou objeto
## mirado e devolve metade do custo. Devolve true se desmontou algo.
func _mark_removal() -> void:
	var hit := _ray()
	if hit.is_empty():
		return
	var node: Object = hit.collider
	if node is BuildFill:
		var fill: BuildFill = node
		_draw_triangles(fill.piece, fill.piece.fills[fill.fill_index].tris, Color(1, 0.2, 0.15, 0.55))
		return
	var box := BoxMesh.new()
	var center := Vector3.ZERO
	if node is BuildPiece:
		var size := BuildPiece.SIZE
		var t := BuildPiece.THICK
		match node.kind:
			BuildPiece.Kind.WALL:
				box.size = Vector3(size, size, t)
				center = Vector3(size * 0.5, size * 0.5, 0)
			BuildPiece.Kind.FLOOR:
				box.size = Vector3(size, t, size)
				center = Vector3(size * 0.5, -t * 0.5, size * 0.5)
			BuildPiece.Kind.ROOF:
				box.size = Vector3(size, t, size)
				center = Vector3(size * 0.5, t * 0.5, size * 0.5)
			_:
				box.size = Vector3(BuildPiece.SEG, size, BuildPiece.SEG)
				center = Vector3(0, size * 0.5, 0)
	elif node is PlacedObject and not node.kind in ["ground", "tree", "airdrop"]:
		box.size = PLACE_SIZE.get(node.kind, Vector3(0.8, 0.8, 0.8))
		center = PLACE_CENTER.get(node.kind, Vector3(0, box.size.y * 0.5, 0))
	else:
		return
	box.size *= 1.03
	_remove_mesh.mesh = box
	_remove_mesh.global_transform = node.global_transform * Transform3D(Basis(), center)
	_remove_mesh.visible = true


func dismantle() -> bool:
	var manager := _manager()
	if manager == null or _menu.visible or player.vehicle != null:
		return false
	var hit := _ray()
	if hit and hit.collider is BuildFill:
		_refund(entry_for("fill", hit.collider.type).get("cost", {}))
		manager.request_unfill(hit.collider.piece, hit.collider.fill_index)
		return true
	if hit and hit.collider is BuildPiece:
		_refund(entry_for_kind(hit.collider.kind).get("cost", {}))
		manager.request_remove(hit.collider)
		return true
	if hit and hit.collider is PlacedObject and not hit.collider.kind in ["ground", "tree", "airdrop"]:
		if hit.collider.kind == "pipe":
			player.inventory.add(&"cano", Fluids.pipe_cost(hit.collider.extra.get("len", 1.0))) # cano volta inteiro
		else:
			_refund(entry_for("place", hit.collider.kind).get("cost", {}))
		_placed().request("remove", [hit.collider.net_id])
		return true
	return false


# --- Talhadeira: seleção de área ---------------------------------------------------

func _update_drag() -> void:
	var piece: BuildPiece = _drag.piece
	if not is_instance_valid(piece):
		_drag = {}
		return
	var here: Dictionary = piece.ray_to_panel(_ray_from(), _ray_to())
	if not here.is_empty():
		var a: Vector2i = _drag.square
		var b: Vector2i = here.square
		cut_selection = PackedInt32Array()
		if a == b:
			cut_selection = _drag.quarters # mesmo quadrado: só o meio quadrado do clique
		else:
			for j in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				for i in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
					for q in 4:
						var t := (j * BuildPiece.N + i) * 4 + q
						if piece.removed[t] == 0:
							cut_selection.append(t)
	_draw_triangles(piece, cut_selection, Color(1.0, 0.55, 0.15, 0.55))
	if not Input.is_action_pressed("attack"):
		# Soltou: tira tudo o que estava selecionado.
		var manager := _manager()
		if manager and not cut_selection.is_empty():
			manager.request_cut_many(piece, cut_selection)
		_drag = {}
		cut_selection = PackedInt32Array()


# --- Janela / porta ------------------------------------------------------------------

## Buraco mirado: onde a mira atravessa o plano de uma peça num triângulo tirado.
func _compute_hole() -> Dictionary:
	var manager := _manager()
	var from := _ray_from()
	var to := _ray_to()
	var hit := _ray()
	var limit: float = from.distance_to(hit.position) + 0.05 if hit else REACH
	var best := {}
	var best_t := INF
	for piece: BuildPiece in manager.pieces.values():
		if not piece.has_panel() or piece.global_position.distance_to(from) > REACH + BuildPiece.SIZE * 1.5:
			continue
		var res: Dictionary = piece.ray_to_panel(from, to)
		if res.is_empty() or res.t * REACH > limit or res.t >= best_t:
			continue
		if piece.removed[res.triangle] == 0 or piece.filled(res.triangle):
			continue
		best_t = res.t
		best = {"piece": piece, "triangle": res.triangle}
	if best.is_empty():
		return {}
	var tris: PackedInt32Array = best.piece.hole_at(best.triangle)
	var valid := not tris.is_empty()
	if selection.fill == "door":
		valid = valid and best.piece.kind == BuildPiece.Kind.WALL and BuildPiece.touches_bottom(tris)
	return {"piece": best.piece, "tris": tris, "valid": valid}


# --- Potes, canteiro, bancada --------------------------------------------------------

func _placed() -> PlacedManager:
	return player.get_parent().get_node_or_null("Placed") as PlacedManager


## Canteiro: na grade como um piso. Pote/floreira/bancada: em cima de qualquer
## chão plano mirado, virado para quem coloca.
func _compute_place() -> Dictionary:
	var placed := _placed()
	if placed == null:
		return {}
	if selection.place == "bed":
		var previous := kind
		kind = BuildPiece.Kind.FLOOR
		var grid := _compute_target()
		kind = previous
		if grid.is_empty():
			return {}
		var valid: bool = grid.valid and not placed.bed_at(grid.cell)
		return {"xform": BuildPiece.piece_transform(BuildPiece.Kind.FLOOR, grid.cell, 0), "valid": valid}
	var hit := _ray()
	if selection.place == "blast_stack":
		return _compute_stack(placed, hit)
	if hit.is_empty() or hit.normal.y < 0.7 or hit.collider is PlacedObject and hit.collider.kind != "bed":
		return {}
	var xform := Transform3D(Basis(Vector3.UP, player.rotation.y), hit.position)
	if Input.is_key_pressed(KEY_SHIFT):
		xform = grid_snap(selection.place, xform)
	if selection.place == "shaft":
		var snapped := _snap_shaft(placed, hit.position)
		if snapped != Transform3D():
			return {"xform": snapped, "valid": true}
	var valid := not placed.occupied(xform.origin, PLACE_RADIUS[selection.place]) \
			and player.global_position.distance_to(xform.origin) > 0.6
	return {"xform": xform, "valid": valid}


## Anel do alto-forno: vai em cima da base ou do anel mirado, alinhado com ele.
func _compute_stack(placed: PlacedManager, hit: Dictionary) -> Dictionary:
	if hit.is_empty() or not hit.collider is PlacedObject or not hit.collider.kind in ["blast_furnace", "blast_stack"]:
		return {}
	var below: PlacedObject = hit.collider
	var height := Fluids.BLAST_BASE_H if below.kind == "blast_furnace" else Fluids.BLAST_RING_H
	var xform := Transform3D(below.global_basis, below.global_position + Vector3.UP * height)
	return {"xform": xform, "valid": placed.stack_spot_free(xform.origin)}


## Shift: gira em passos de 90° e prende na grade das peças (0,4 m), igual ao
## piso construído (a grade começa em 0,0 do mundo).
static func grid_snap(place: String, xform: Transform3D) -> Transform3D:
	var yaw := snappedf(xform.basis.get_euler().y, PI / 2.0)
	var basis := Basis(Vector3.UP, yaw)
	var offset: Vector3 = basis * GRID_OFFSET.get(place, Vector3.ZERO)
	var p := xform.origin - offset
	p.x = snappedf(p.x, BuildPiece.SEG)
	p.z = snappedf(p.z, BuildPiece.SEG)
	return Transform3D(basis, p + offset)


## Eixo: encaixa a ponta na porta de latão livre mais perto (até 1,2 m), alinhado com ela.
func _snap_shaft(placed: PlacedManager, near: Vector3) -> Transform3D:
	var best := {}
	for obj: PlacedObject in placed.objects.values():
		if not Power.is_power(obj.kind) or obj.global_position.distance_to(near) > 4.0:
			continue
		for port in Power.world_ports(obj):
			var d := Vector2(port[0].x - near.x, port[0].z - near.z).length()
			if d < 1.2 and (best.is_empty() or d < best.d):
				best = {"d": d, "pos": port[0], "dir": port[1]}
	if best.is_empty():
		return Transform3D()
	var dir: Vector3 = best.dir
	dir.y = 0.0
	dir = dir.normalized()
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP)) # eixo X do eixo = direção da porta
	var center: Vector3 = best.pos + dir * 1.0
	return Transform3D(basis, center - Vector3.UP * 0.6)


func _draw_box(obj: PlacedObject) -> void:
	_ghost.visible = true
	var box := BoxMesh.new()
	box.size = PLACE_SIZE.get(obj.kind, Vector3(BuildPiece.SIZE, 0.3, BuildPiece.SIZE)) * 1.03
	_ghost_mesh.mesh = box
	_ghost_mesh.position = PLACE_CENTER.get(obj.kind, Vector3(0, box.size.y * 0.5, 0))
	_ghost_mesh.visible = true
	_model_ghost.visible = false
	_ghost.global_transform = obj.global_transform
	_ghost_material.albedo_color = Color(1.0, 0.2, 0.15, 0.4)
	call_deferred("_apply_ghost", selection)


# --- Onde construir ---------------------------------------------------------------

func _ray_from() -> Vector3:
	return player.camera.global_position


func _ray_to() -> Vector3:
	return player.camera.global_position - player.camera.global_basis.z * REACH


func _ray() -> Dictionary:
	var cam := player.camera
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * REACH, MASK, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	# As peças colidem dos dois lados: a normal pode vir invertida. Vira para quem mira.
	if hit and hit.normal.dot(dir) > 0.0:
		hit.normal = -hit.normal
	return hit


func _compute_target() -> Dictionary:
	var hit := _ray()
	if hit.is_empty():
		return {}
	var p: Vector3 = hit.position + hit.normal * 0.02
	var piece := hit.collider as BuildPiece
	var on_top: bool = hit.normal.y > 0.7
	# Mirando a quina de cima de uma parede/pilar também conta como "em cima".
	if piece and piece.kind in [BuildPiece.Kind.WALL, BuildPiece.Kind.PILLAR] \
			and piece.to_local(hit.position).y > BuildPiece.SIZE - 0.35:
		on_top = true
	var seg := BuildPiece.SEG
	var n := BuildPiece.N
	var forward := -player.camera.global_basis.z
	var cell := Vector3i.ZERO
	var rot := 0
	var me := player.global_position
	match kind:
		BuildPiece.Kind.WALL:
			# De frente para quem constrói (R gira 90°).
			rot = 1 if absf(forward.x) > absf(forward.z) else 0
			if flip:
				rot = 1 - rot
			if piece and on_top and piece.kind == BuildPiece.Kind.WALL:
				cell = piece.cell + Vector3i(0, n, 0) # empilha
				rot = piece.rot
			elif piece and on_top and piece.kind in [BuildPiece.Kind.FLOOR, BuildPiece.Kind.ROOF]:
				# Na borda mais perto do piso/teto mirado.
				var o := piece.cell
				var y := o.y # no teto a base afunda um pouco na laje (o topo dele não cai na grade)
				if rot == 0:
					var z := o.z if absf(p.z - o.z * seg) < absf(p.z - (o.z + n) * seg) else o.z + n
					cell = Vector3i(o.x, y, z)
				else:
					var x := o.x if absf(p.x - o.x * seg) < absf(p.x - (o.x + n) * seg) else o.x + n
					cell = Vector3i(x, y, o.z)
			else:
				var y := roundi(p.y / seg)
				if rot == 0:
					cell = Vector3i(roundi(p.x / seg) - n / 2, y, roundi(p.z / seg))
				else:
					cell = Vector3i(roundi(p.x / seg), y, roundi(p.z / seg) - n / 2)
		BuildPiece.Kind.FLOOR, BuildPiece.Kind.ROOF:
			if piece and on_top and piece.kind == kind:
				# Perto da borda de outro piso/teto igual: vai para o lado dele.
				var o := piece.cell
				var lu := p.x / seg - o.x
				var lv := p.z / seg - o.z
				var edges := [lu, n - lu, lv, n - lv]
				var best: int = edges.find(edges.min())
				var offsets := [Vector3i(-n, 0, 0), Vector3i(n, 0, 0), Vector3i(0, 0, -n), Vector3i(0, 0, n)]
				cell = o + offsets[best]
			elif piece and on_top and piece.kind == BuildPiece.Kind.WALL:
				# Em cima de uma parede: cobre o lado onde o jogador está.
				var o := piece.cell
				var y := o.y + n
				if piece.rot == 0:
					cell = Vector3i(o.x, y, o.z - n if me.z < o.z * seg else o.z)
				else:
					cell = Vector3i(o.x - n if me.x < o.x * seg else o.x, y, o.z)
			else:
				cell = Vector3i(roundi(p.x / seg) - n / 2, roundi(p.y / seg), roundi(p.z / seg) - n / 2)
		BuildPiece.Kind.PILLAR:
			# R deita o pilar (viga), no sentido da parede que fica de frente para quem constrói.
			var lying := flip
			if lying:
				rot = 1 if absf(forward.z) >= absf(forward.x) else 2
			var standing_piece: bool = piece != null and (piece.kind == BuildPiece.Kind.WALL or (piece.kind == BuildPiece.Kind.PILLAR and piece.rot == 0))
			if lying and piece and on_top and piece.kind == BuildPiece.Kind.WALL:
				cell = piece.cell + Vector3i(0, n, 0) # cobre o topo da parede inteiro
				rot = 1 if piece.rot == 0 else 2
			elif piece and on_top and standing_piece:
				cell = Vector3i(roundi(p.x / seg), piece.cell.y + n, roundi(p.z / seg))
			else:
				cell = Vector3i(roundi(p.x / seg), roundi(p.y / seg), roundi(p.z / seg))
	if kind != BuildPiece.Kind.WALL and kind != BuildPiece.Kind.PILLAR:
		rot = 0
	return {"kind": kind, "cell": cell, "rot": rot, "valid": _manager().can_place(kind, cell, rot)}


# --- Visual ---------------------------------------------------------------------

func _set_ghost_shape() -> void:
	var box := BoxMesh.new()
	var size := BuildPiece.SIZE
	var t := BuildPiece.THICK
	_ghost_mesh.scale = Vector3.ONE
	match kind:
		BuildPiece.Kind.WALL:
			box.size = Vector3(size, size, t)
			_ghost_mesh.position = Vector3(size * 0.5, size * 0.5, 0)
		BuildPiece.Kind.FLOOR:
			box.size = Vector3(size, t, size)
			_ghost_mesh.position = Vector3(size * 0.5, -t * 0.5, size * 0.5)
		BuildPiece.Kind.ROOF:
			box.size = Vector3(size, t, size)
			_ghost_mesh.position = Vector3(size * 0.5, t * 0.5, size * 0.5)
		BuildPiece.Kind.PILLAR:
			box.size = Vector3(BuildPiece.SEG, size, BuildPiece.SEG)
			_ghost_mesh.position = Vector3(0, size * 0.5, 0)
	_ghost_mesh.mesh = box


## Triângulos realçados na face virada para quem mira (um pouco para fora dela).
func _draw_triangles(piece: BuildPiece, tris: PackedInt32Array, color: Color) -> void:
	var w := Vector2(-BuildPiece.THICK * 0.5, BuildPiece.THICK * 0.5) if piece.kind == BuildPiece.Kind.WALL 			else Vector2(0.0, BuildPiece.THICK)
	var eye := piece.to_local(player.camera.global_position)
	var eye_w := eye.z if piece.kind == BuildPiece.Kind.WALL else eye.y + (BuildPiece.THICK if piece.kind == BuildPiece.Kind.FLOOR else 0.0)
	var depth := w.y + 0.01 if eye_w > (w.x + w.y) * 0.5 else w.x - 0.01
	_highlight_mesh.clear_surfaces()
	if tris.is_empty():
		return
	_highlight_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in tris:
		var c := BuildPiece.triangle_uv(index)
		var center := (c[0] + c[1] + c[2]) / 3.0
		for k in 3:
			var corner: Vector2 = center.lerp(c[k], 0.92) # um pouco menor: dá para ver cada triângulo
			_highlight_mesh.surface_add_vertex(piece.uvw(corner.x, corner.y, depth))
	_highlight_mesh.surface_end()
	_mark.albedo_color = color
	_highlight.global_transform = piece.global_transform
	_highlight.visible = true


## Desenho antigo da remoção (caixa no fantasma).
func _show_removal(node: Node) -> void:
	if node is BuildFill:
		var fill: BuildFill = node
		_draw_triangles(fill.piece, fill.piece.fills[fill.fill_index].tris, Color(1, 0.2, 0.15, 0.55))
		return
	var piece: BuildPiece = node
	var previous := kind
	kind = piece.kind
	_set_ghost_shape()
	kind = previous
	_ghost.visible = true
	_ghost_mesh.visible = true
	_model_ghost.visible = false
	_ghost.global_transform = piece.global_transform
	_ghost_mesh.scale = Vector3.ONE * 1.01
	_ghost_material.albedo_color = Color(1.0, 0.2, 0.15, 0.4)
	call_deferred("_apply_ghost", selection)
