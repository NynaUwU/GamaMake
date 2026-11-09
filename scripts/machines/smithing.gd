class_name Smithing
extends RefCounted
## Era 1-3: forja a carvão com bigorna e trefiladora.
##   forge        forja de tijolo com coifa, fole e bigorna no toco. [E] abre os lugares
##                (metal, carvão, peça pronta) e as peças: escolher uma abre o minigame
##                da forja (ForgeMinigame, cor por temperatura). A peça sai com qualidade
##                ("q" no item: mais dano e menos desgaste); rachou = sobra sucata.
##   wire_drawer  trefiladora: com eixo/motor na porta de latão, barra de cobre vira
##                fio de cobre (sem minigame; mesmos 3 lugares das fornalhas, sem fogo).
## Os lugares são o "baú" furnace_<id> (Smelting), guardado pelo host.

const KINDS := ["forge", "wire_drawer"]
const HOT_TIME := 45.0 ## segundos que a forja fica acesa (e a peça em brasa) depois de forjar
const STEEL_BONUS := 0.1 ## aço: peça um pouco melhor
const SCRAP_BACK := 1 ## peça rachada: sobra isso de sucata


static func has(kind: String) -> bool:
	return kind in KINDS


## Receitas da forja: [índice em CraftingUI.RECIPES, receita].
static func recipes() -> Array:
	var list := []
	for k in CraftingUI.RECIPES.size():
		if CraftingUI.RECIPES[k].station == "forja":
			list.append([k, CraftingUI.RECIPES[k]])
	return list


## Metais que a forja aceita (os das receitas dela).
static func metals() -> Array:
	var list := []
	for entry in recipes():
		for id in entry[1].cost:
			if not id in list:
				list.append(id)
	return list


static func metal_of(recipe: Dictionary) -> StringName:
	return recipe.cost.keys()[0]


## O que falta para forjar a receita com o que está nos lugares ("" = pode).
static func missing(recipe: Dictionary, slots: Array) -> String:
	if not Progress.knows(recipe.get("manual", "")):
		return "Precisa ler: %s" % Progress.MANUALS[StringName(recipe.manual)].title
	var metal := metal_of(recipe)
	var need: int = recipe.cost[metal]
	if slots.size() < 3 or slots[Smelting.INPUT].is_empty() or slots[Smelting.INPUT].id != metal or slots[Smelting.INPUT].amount < need:
		return "Ponha %d %s no lugar do metal" % [need, ItemDB.display_name(metal)]
	if slots[Smelting.FUEL].is_empty() or slots[Smelting.FUEL].amount < 1:
		return "Ponha carvão no lugar do fogo"
	if not slots[Smelting.OUTPUT].is_empty():
		return "Tire a peça pronta primeiro"
	return ""


# --- Forjar (cliente que clicou) ------------------------------------------------------

## Escolheu a peça na janela da forja: abre o minigame; no fim o host gasta o
## material e põe a peça (com a qualidade) no lugar da peça pronta.
static func start(player: Player, obj: PlacedObject, index: int) -> bool:
	var recipe: Dictionary = CraftingUI.RECIPES[index]
	if missing(recipe, ContainerManager.i.slots_of(Smelting.key_of(obj))) != "":
		Sfx.play("click", -6.0, 0.6)
		return false
	var context := {"item": recipe.id, "metal": metal_of(recipe), "hits": recipe.get("hits", 8), "chart": Progress.knows(&"manual_ferreiro") and Progress.i != null}
	var manager := obj.get_parent() as PlacedManager
	var net_id := obj.net_id
	Minigame.play(player, "forge", context, func(quality: float):
		if quality < 0.0 or not is_instance_valid(manager):
			return # desistiu antes do primeiro golpe: nada é gasto
		manager.request("forge_done", [net_id, index, quality])
		Progress.event("forge", String(recipe.id))
		if quality >= 0.9:
			Progress.event("forge_master", String(recipe.id))
		var again: PlacedObject = manager.objects.get(net_id)
		if again and is_instance_valid(player):
			StorageUI.open_for.call_deferred(player, Smelting.key_of(again), again))
	return true


# --- Host ---------------------------------------------------------------------------

## Peça forjada: gasta metal + carvão e põe a peça (ou a sucata) no lugar da peça pronta.
## Devolve o que vai para os outros ({} = recusado).
static func host_forge(manager: PlacedManager, obj: PlacedObject, index: int, quality: float) -> Dictionary:
	if index < 0 or index >= CraftingUI.RECIPES.size() or ContainerManager.i == null:
		return {}
	var recipe: Dictionary = CraftingUI.RECIPES[index]
	var key := Smelting.key_of(obj)
	var slots: Array = ContainerManager.i.contents.get(key, [])
	var metal := metal_of(recipe)
	var need: int = recipe.cost[metal]
	if recipe.station != "forja" or slots.size() < 3 or slots[Smelting.INPUT].is_empty() or slots[Smelting.INPUT].id != metal \
			or slots[Smelting.INPUT].amount < need or slots[Smelting.FUEL].is_empty():
		return {} # alguém tirou o material no meio do caminho
	_use(slots, Smelting.INPUT, need)
	_use(slots, Smelting.FUEL, 1)
	var piece := {"id": &"sucata", "amount": SCRAP_BACK}
	if quality > 0.0:
		piece = {"id": recipe.id, "amount": 1, "q": snappedf(clampf(quality + (STEEL_BONUS if metal == &"barra_aco" else 0.0), 0.05, 1.0), 0.01)}
	if slots[Smelting.OUTPUT].is_empty():
		slots[Smelting.OUTPUT] = piece
	else:
		Net.i.give_to(Net.i.request_peer, piece.id, piece.amount, -1, 1.0, ItemDB.extras(piece))
	ContainerManager.i.changed.emit(key)
	Net.i.system_request("Containers", "sync", [key])
	obj.extra.hot_until = manager.clock + HOT_TIME
	obj.refresh(manager.clock)
	return {"hot_until": obj.extra.hot_until}


static func _use(slots: Array, index: int, amount: int) -> void:
	slots[index].amount -= amount
	if slots[index].amount <= 0:
		slots[index] = {}


# --- Objeto no mundo ----------------------------------------------------------------

static func text(obj: PlacedObject) -> String:
	match obj.kind:
		"forge":
			return "[E] Forja e bigorna (metal + carvão: forjar peças)"
		"wire_drawer":
			if obj.extra.get("pstate", "") != "ok":
				return "[E] Trefiladora (precisa de eixo ou motor na porta de latão)"
			return "[E] Trefiladora (barra de cobre vira fio)"
	return ""


static func interact(player: Node, obj: PlacedObject) -> void:
	StorageUI.open_for(player, Smelting.key_of(obj), obj)


static func is_lit(obj: PlacedObject, clock: float) -> bool:
	return obj.kind == "forge" and obj.extra.get("hot_until", 0.0) > clock


## Peça em brasa na bigorna: esfria pela cor (mesmo shader do minigame).
static func refresh(obj: PlacedObject, clock: float) -> void:
	if obj.kind != "forge":
		return
	var bar := obj.get_node_or_null("HotBar") as MeshInstance3D
	if bar == null:
		return
	var left := clampf((obj.extra.get("hot_until", 0.0) - clock) / HOT_TIME, 0.0, 1.0)
	bar.visible = left > 0.0
	(bar.material_override as ShaderMaterial).set_shader_parameter("temperature", 0.2 + left * 0.55)


static func build(kind: String, obj: PlacedObject) -> void:
	match kind:
		"forge":
			_forge(obj)
		"wire_drawer":
			_wire_drawer(obj)


## Forja de tijolo (esquerda) com leito de carvão, coifa de chapa em pirâmide e
## chaminé, fole de couro do lado; bigorna no toco (direita) com martelo e tenaz,
## balde de água para temperar.
static func _forge(obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	var hx := -0.4
	ObjectModels._bricks(mb, Vector3(hx, 0.4, 0), Vector3(1.1, 0.8, 0.9), 7)
	mb.color(ObjectModels.IRON)
	mb.box(Vector3(hx, 0.82, 0), Vector3(1.16, 0.05, 0.96)) # aro de ferro
	mb.color(ObjectModels.SOOT)
	mb.box(Vector3(hx, 0.85, 0.02), Vector3(0.74, 0.03, 0.56)) # leito de carvão
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for k in 22:
		mb.color(Color(0.08, 0.07, 0.07).lightened(rng.randf_range(0.0, 0.08)))
		mb.box(Vector3(hx + rng.randf_range(-0.32, 0.32), 0.875, rng.randf_range(-0.22, 0.24)), Vector3(0.07, 0.04, 0.06),
			Basis(Vector3.UP, rng.randf_range(0, PI)))
	mb.color(ObjectModels.BRICK.darkened(0.3))
	mb.box(Vector3(hx, 0.3, 0.452), Vector3(0.36, 0.26, 0.01)) # cinzeiro na frente
	# Coifa: pirâmide de chapa presa em 4 hastes, e a chaminé.
	mb.color(ObjectModels.IRON)
	for x in [-0.5, 0.5]:
		for z in [-0.4, 0.4]:
			mb.box(Vector3(hx + x, 1.12, z), Vector3(0.03, 0.56, 0.03))
	mb.color(Color(0.2, 0.19, 0.19))
	mb.lathe(PackedVector2Array([Vector2(0.76, 1.38), Vector2(0.74, 1.42), Vector2(0.2, 1.8), Vector2(0.2, 1.84)]), 4, Basis(Vector3.UP, PI / 4), Vector3(hx, 0, 0))
	mb.color(Color(0.16, 0.15, 0.15))
	mb.lathe(PackedVector2Array([Vector2(0.12, 1.8), Vector2(0.12, 2.55), Vector2(0.15, 2.58), Vector2(0.15, 2.62)]), 8, Basis.IDENTITY, Vector3(hx, 0, 0))
	# Fole de couro sanfonado (esquerda) soprando por um bico de ferro.
	mb.color(ObjectModels.WOOD_DARK)
	mb.box(Vector3(-1.2, 0.5, 0.0), Vector3(0.34, 0.035, 0.56))
	mb.box(Vector3(-1.2, 0.25, 0.0), Vector3(0.07, 0.5, 0.07))
	mb.color(Color(0.42, 0.28, 0.17))
	for k in 3:
		mb.box(Vector3(-1.2, 0.54 + k * 0.03, 0.0), Vector3(0.32 - k * 0.04, 0.03, 0.52 - k * 0.05))
	mb.color(ObjectModels.WOOD)
	mb.box(Vector3(-1.2, 0.635, 0.0), Vector3(0.34, 0.03, 0.56), Basis(Vector3.BACK, 0.08))
	mb.box(Vector3(-1.2, 0.66, 0.34), Vector3(0.05, 0.04, 0.16))
	mb.color(ObjectModels.IRON)
	mb.tube(PackedVector3Array([Vector3(-1.04, 0.55, 0.0), Vector3(-0.95, 0.6, 0.0)]), 0.035, 6)
	# Toco, bigorna (base, cintura, mesa, bico e talão), martelo e tenaz.
	var ax := 0.72
	mb.color(ObjectModels.WOOD_DARK)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.24, 0.0), Vector2(0.23, 0.44), Vector2(0.002, 0.44)]), 10, Basis.IDENTITY, Vector3(ax, 0, 0))
	mb.color(ObjectModels.WOOD_LIGHT)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.441), Vector2(0.2, 0.441)]), 10, Basis.IDENTITY, Vector3(ax, 0, 0))
	mb.color(Color(0.17, 0.17, 0.18))
	mb.box(Vector3(ax, 0.48, 0), Vector3(0.34, 0.07, 0.22))
	mb.box(Vector3(ax, 0.56, 0), Vector3(0.18, 0.1, 0.13))
	mb.box(Vector3(ax, 0.645, 0), Vector3(0.44, 0.08, 0.17))
	mb.lathe(PackedVector2Array([Vector2(0.075, 0.0), Vector2(0.002, 0.2)]), 8, Basis(Vector3.BACK, PI / 2), Vector3(ax - 0.22, 0.65, 0)) # bico
	mb.box(Vector3(ax + 0.25, 0.655, 0), Vector3(0.08, 0.06, 0.12)) # talão
	mb.color(Color(0.36, 0.36, 0.38))
	mb.box(Vector3(ax, 0.687, 0), Vector3(0.42, 0.006, 0.15)) # mesa polida
	mb.color(ObjectModels.WOOD)
	mb.tube(PackedVector3Array([Vector3(ax + 0.06, 0.705, -0.06), Vector3(ax + 0.34, 0.705, -0.15)]), 0.016, 5) # cabo do martelo (atrás)
	mb.color(ObjectModels.IRON)
	mb.box(Vector3(ax + 0.05, 0.712, -0.055), Vector3(0.05, 0.05, 0.1), Basis(Vector3.UP, 0.32))
	mb.color(Color(0.15, 0.15, 0.16))
	for side in [-0.015, 0.015]:
		mb.tube(PackedVector3Array([Vector3(ax + 0.32, 0.0, 0.28 + side), Vector3(ax + 0.24, 0.5, 0.2 + side)]), 0.01, 4) # tenaz
	# Balde de água para temperar.
	mb.color(ObjectModels.WOOD)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.15, 0.0), Vector2(0.18, 0.3), Vector2(0.16, 0.3), Vector2(0.14, 0.03)]), 10, Basis.IDENTITY, Vector3(ax - 0.05, 0, 0.55))
	mb.color(ObjectModels.IRON)
	for y in [0.06, 0.24]:
		mb.lathe(PackedVector2Array([Vector2(0.155 + y * 0.1, y), Vector2(0.158 + y * 0.1, y + 0.025)]), 10, Basis.IDENTITY, Vector3(ax - 0.05, 0, 0.55))
	mb.color(ObjectModels.WATER)
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.26), Vector2(0.165, 0.26)]), 10, Basis.IDENTITY, Vector3(ax - 0.05, 0, 0.55))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	# Brasas acesas (só com a forja quente) e a peça em brasa na bigorna.
	var embers := MeshBuilder.new()
	for k in 14:
		embers.color(Color(1.0, 0.42 + rng.randf_range(0.0, 0.3), 0.1))
		embers.box(Vector3(hx + rng.randf_range(-0.3, 0.3), 0.885, rng.randf_range(-0.2, 0.22)), Vector3(0.06, 0.03, 0.05))
	var glow := MeshInstance3D.new()
	glow.mesh = embers.finish(StationModels._glow_mat(), false)
	obj.add_child(glow)
	var nodes: Array = obj.get_meta("fire_nodes", [])
	nodes.append(glow)
	obj.set_meta("fire_nodes", nodes)
	StationModels._fire(obj, Vector3(hx, 0.9, 0.02), 0.22, 0.6)
	var bar := MeshInstance3D.new()
	bar.name = "HotBar"
	var box := BoxMesh.new()
	box.size = Vector3(0.24, 0.022, 0.045)
	bar.mesh = box
	var heat := ShaderMaterial.new()
	heat.shader = load("res://shaders/forge_heat.gdshader")
	bar.material_override = heat
	bar.position = Vector3(ax - 0.06, 0.702, 0.035)
	bar.visible = false
	obj.add_child(bar)
	obj._shape(Vector3(-0.2, 0.45, 0), Vector3(2.4, 0.9, 1.0))


## Trefiladora: bancada comprida de madeira; a barra de cobre passa pela fieira
## (bloco de ferro com o furo de latão) e sai fio, que enrola no tambor de cima
## (gira com o eixo). Porta de latão à esquerda (AutoMachines.add_hub).
static func _wire_drawer(obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	mb.color(ObjectModels.WOOD)
	mb.box(Vector3(0, 0.62, 0), Vector3(1.8, 0.07, 0.6)) # tampo
	mb.color(ObjectModels.WOOD_DARK)
	for x in [-0.75, 0.75]:
		for z in [-0.24, 0.24]:
			mb.box(Vector3(x, 0.3, z), Vector3(0.08, 0.6, 0.08))
		mb.box(Vector3(x, 0.12, 0), Vector3(0.06, 0.06, 0.5))
	mb.box(Vector3(0, 0.12, 0), Vector3(1.5, 0.05, 0.05))
	# Fieira: bloco de ferro preso no tampo, com o furo de latão.
	mb.color(ObjectModels.IRON)
	mb.box(Vector3(-0.35, 0.8, 0), Vector3(0.12, 0.3, 0.28))
	mb.box(Vector3(-0.35, 0.67, 0), Vector3(0.2, 0.04, 0.34))
	mb.color(ItemModels.BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.01, -0.065), Vector2(0.05, -0.065), Vector2(0.05, 0.065), Vector2(0.01, 0.065)]), 10, Basis(Vector3.BACK, PI / 2), Vector3(-0.35, 0.82, 0))
	# Barra de cobre entrando e o fio saindo até o tambor.
	mb.color(ObjectModels.COPPER)
	mb.box(Vector3(-0.66, 0.82, 0), Vector3(0.5, 0.035, 0.035))
	mb.tube(PackedVector3Array([Vector3(-0.29, 0.82, 0), Vector3(0.3, 0.82, -0.17)]), 0.006, 4)
	# Mesa de apoio da barra.
	mb.color(ObjectModels.WOOD_LIGHT)
	mb.box(Vector3(-0.66, 0.68, 0), Vector3(0.5, 0.05, 0.12))
	# Caixa de engrenagens embaixo do tambor, ligada à porta da esquerda por um eixo.
	mb.color(ObjectModels.IRON)
	mb.box(Vector3(0.48, 0.5, 0), Vector3(0.3, 0.2, 0.3))
	mb.color(ItemModels.STEEL)
	mb.tube(PackedVector3Array([Vector3(-0.9, 0.6, 0), Vector3(0.34, 0.6, 0)]), 0.02, 6)
	# Rolos de fio prontos na ponta da bancada.
	for k in 2:
		mb.color(ObjectModels.COPPER.lightened(0.05 * k))
		mb.torus(0.07, 0.022, 10, 4, Basis.IDENTITY, Vector3(0.8, 0.675 + k * 0.035, 0.12))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	# Tambor (gira com o eixo): carretel de ferro com o fio de cobre enrolado.
	var drum := MeshBuilder.new()
	drum.color(ObjectModels.IRON)
	drum.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.24, 0.0), Vector2(0.24, 0.03), Vector2(0.18, 0.03), Vector2(0.18, 0.2),
		Vector2(0.24, 0.2), Vector2(0.24, 0.23), Vector2(0.002, 0.23)]), 14)
	for k in 5:
		drum.color(ObjectModels.COPPER.darkened(0.06 * (k % 2)))
		drum.torus(0.185, 0.014, 16, 4, Basis.IDENTITY, Vector3(0, 0.05 + k * 0.032, 0))
	drum.color(ItemModels.BRASS)
	drum.box(Vector3(0.0, 0.25, 0.0), Vector3(0.36, 0.03, 0.04)) # trava
	var spin := MeshInstance3D.new()
	spin.name = "Spin"
	spin.mesh = drum.finish(PlacedObject._mat(), false)
	spin.position = Vector3(0.48, 0.655, 0)
	obj.add_child(spin)
	var spinner := PowerSpin.new()
	spinner.axis = Vector3.UP
	obj.add_child(spinner)
	obj._shape(Vector3(0, 0.45, 0), Vector3(1.9, 0.9, 0.65))
