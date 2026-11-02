class_name Ranch
extends RefCounted
## Fazenda de animais (objetos do martelo, aba "Fazenda"):
##   trough        cocho: baú ([E] abre). Os bichos mansos comem a comida deles
##                 (galinha: sementes; ovelha e vaca: trigo; porco: trigo ou legumes)
##   water_trough  bebedouro: até 12 de água. Enche com garrafa (clique com água na mão),
##                 com a chuva ou por cano (porta de latão no lado)
##   fence         cerca de madeira, 2,4 m (encaixa na grade com Shift); segura os bichos
##   gate          porteira: cerca que abre e fecha com [E]
## Bicho manso alimentado E com água, perto de outro igual: nasce filhote (a água é o que
## destrava a cria). Zumbis tratam a cerca como construção (contornam ou quebram).

const KINDS := ["trough", "water_trough", "fence", "gate"]
const WATER_CAP := 12.0
const FENCE_LEN := 2.4
const FENCE_HP := 6 ## golpes de zumbi
const WOOD := Color(0.45, 0.31, 0.18)
const WOOD_DARK := Color(0.32, 0.22, 0.13)
const STRAW := Color(0.85, 0.72, 0.35)
const WATER := Color(0.32, 0.52, 0.62)


static func has(kind: String) -> bool:
	return kind in KINDS


static func key_of(obj: PlacedObject) -> String:
	return "placed_%d" % obj.net_id


# --- Modelos ----------------------------------------------------------------------------

static func build(kind: String, obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	match kind:
		"trough":
			# Cocho de tábuas em V sobre dois cavaletes, palha dentro ("Food").
			for side in [-1.0, 1.0]:
				mb.color(WOOD.lightened(0.05 if side > 0 else 0.0))
				mb.box(Vector3(0, 0.42, side * 0.17), Vector3(1.5, 0.26, 0.04), Basis(Vector3.RIGHT, side * 0.35))
			mb.color(WOOD_DARK)
			mb.box(Vector3(0, 0.3, 0), Vector3(1.5, 0.04, 0.2))
			for x in [-0.72, 0.72]:
				mb.box(Vector3(x, 0.44, 0), Vector3(0.05, 0.3, 0.46)) # cabeceiras
				for side in [-1.0, 1.0]:
					mb.color(WOOD_DARK.darkened(0.1))
					mb.box(Vector3(x * 0.85, 0.15, side * 0.16), Vector3(0.06, 0.34, 0.06), Basis(Vector3.RIGHT, side * 0.3)) # pés
			mb.color(ItemModels.IRON)
			for x in [-0.45, 0.45]:
				mb.box(Vector3(x, 0.55, 0.26), Vector3(0.03, 0.02, 0.01))
				mb.box(Vector3(x, 0.55, -0.26), Vector3(0.03, 0.02, 0.01))
			obj._shape(Vector3(0, 0.3, 0), Vector3(1.5, 0.6, 0.5))
			var food := MeshBuilder.new()
			food.color(STRAW)
			food.box(Vector3(0, 0.0, 0), Vector3(1.38, 0.1, 0.28))
			for k in 7:
				food.color(STRAW.darkened(0.08 * (k % 3)))
				food.box(Vector3(-0.6 + k * 0.2, 0.06, (k % 2) * 0.06 - 0.03), Vector3(0.16, 0.06, 0.12), Basis(Vector3.UP, k * 0.7))
			_add(obj, food, "Food", Vector3(0, 0.42, 0)).visible = false
		"water_trough":
			# Tina comprida de tábuas com cintas de ferro; água ("Water", escala em Y).
			mb.color(WOOD)
			for side in [-1.0, 1.0]:
				mb.box(Vector3(0, 0.27, side * 0.24), Vector3(1.3, 0.46, 0.05))
				mb.box(Vector3(side * 0.63, 0.27, 0), Vector3(0.05, 0.46, 0.53))
			mb.color(WOOD_DARK)
			mb.box(Vector3(0, 0.05, 0), Vector3(1.3, 0.06, 0.5))
			for x in [-0.5, 0.5]:
				mb.box(Vector3(x, 0.02, 0), Vector3(0.1, 0.04, 0.6))
			mb.color(ItemModels.IRON)
			for x in [-0.4, 0.4]:
				mb.box(Vector3(x, 0.4, 0.27), Vector3(0.05, 0.03, 0.01))
				mb.box(Vector3(x, 0.4, -0.27), Vector3(0.05, 0.03, 0.01))
				mb.box(Vector3(x, 0.15, 0.27), Vector3(0.05, 0.03, 0.01))
				mb.box(Vector3(x, 0.15, -0.27), Vector3(0.05, 0.03, 0.01))
			obj._shape(Vector3(0, 0.25, 0), Vector3(1.32, 0.5, 0.55))
			var water := MeshBuilder.new()
			water.color(WATER)
			water.box(Vector3(0, 0.19, 0), Vector3(1.2, 0.38, 0.44))
			var node := _add(obj, water, "Water", Vector3(0, 0.08, 0))
			node.scale = Vector3(1, 0.01, 1)
			node.visible = false
		"fence", "gate":
			# Cerca: dois mourões nas pontas e duas travessas (a porteira tem tábuas em X
			# e gira na dobradiça da esquerda).
			for x in [-FENCE_LEN * 0.5, FENCE_LEN * 0.5]:
				mb.color(WOOD_DARK)
				mb.box(Vector3(x, 0.55, 0), Vector3(0.12, 1.1, 0.12))
				mb.color(WOOD_DARK.darkened(0.1))
				mb.box(Vector3(x, 1.12, 0), Vector3(0.14, 0.04, 0.14))
			var rails := mb if kind == "fence" else MeshBuilder.new()
			var inner := FENCE_LEN - 0.12
			var x0 := 0.0 if kind == "fence" else inner * 0.5 # porteira: espaço do pivô (dobradiça em x=0)
			for y in [0.42, 0.85]:
				rails.color(WOOD.lightened(0.04 if y > 0.5 else 0.0))
				rails.box(Vector3(x0, y, 0), Vector3(inner, 0.1, 0.05))
			if kind == "fence":
				mb.color(WOOD)
				mb.box(Vector3(0, 0.62, 0), Vector3(0.08, 0.95, 0.04)) # mourão do meio
			else:
				rails.color(WOOD.darkened(0.06))
				var diag := atan2(0.43, inner)
				rails.box(Vector3(x0, 0.64, 0), Vector3(Vector2(inner, 0.43).length(), 0.08, 0.04), Basis(Vector3.BACK, diag))
				rails.color(ItemModels.IRON)
				for y in [0.42, 0.85]:
					rails.box(Vector3(0.05, y, 0.03), Vector3(0.12, 0.05, 0.02)) # dobradiças
				rails.box(Vector3(inner - 0.04, 0.64, 0.04), Vector3(0.03, 0.1, 0.03)) # trinco
				var panel := _add(obj, rails, "Gate", Vector3(-FENCE_LEN * 0.5 + 0.06, 0, 0))
				panel.rotation.y = -PI / 2 if obj.extra.get("open", false) else 0.0
			var shape := CollisionShape3D.new()
			shape.name = "Bar"
			var box := BoxShape3D.new()
			box.size = Vector3(FENCE_LEN, 1.15, 0.14)
			shape.shape = box
			shape.position.y = 0.57
			shape.disabled = kind == "gate" and obj.extra.get("open", false)
			obj.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)


static func _add(obj: PlacedObject, mb: MeshBuilder, node_name: String, at: Vector3) -> Node3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mb.finish(PlacedObject._mat(), false)
	node.position = at
	obj.add_child(node)
	return node


## Desenho conforme o estado (1x por segundo e quando muda).
static func refresh(obj: PlacedObject) -> void:
	match obj.kind:
		"water_trough":
			var water := obj.get_node_or_null("Water") as Node3D
			if water:
				var level := clampf(obj.extra.get("water", 0.0) / WATER_CAP, 0.0, 1.0)
				water.visible = level > 0.01
				water.scale.y = maxf(level, 0.01)
		"trough":
			var food := obj.get_node_or_null("Food") as Node3D
			if food and ContainerManager.i:
				var slots: Array = ContainerManager.i.slots_of(key_of(obj))
				food.visible = slots.any(func(s): return not s.is_empty())
		"gate":
			var open: bool = obj.extra.get("open", false)
			var panel := obj.get_node_or_null("Gate") as Node3D
			if panel:
				panel.rotation.y = -PI / 2 if open else 0.0
			var bar := obj.get_node_or_null("Bar") as CollisionShape3D
			if bar:
				bar.disabled = open


# --- Interação --------------------------------------------------------------------------

static func text(obj: PlacedObject) -> String:
	match obj.kind:
		"trough":
			var count := 0
			if ContainerManager.i:
				for s in ContainerManager.i.slots_of(key_of(obj)):
					if not s.is_empty():
						count += s.amount
			return "[E] Cocho (%d de comida)" % count
		"water_trough":
			var water: float = obj.extra.get("water", 0.0)
			return "Bebedouro: água %d de %d%s" % [int(water), int(WATER_CAP), "  (clique com água na mão para encher)" if water < WATER_CAP - 1.0 else ""]
		"fence":
			return "Cerca"
		"gate":
			return "[E] %s a porteira" % ("Fechar" if obj.extra.get("open", false) else "Abrir")
	return ""


static func interact(player: Node, obj: PlacedObject) -> void:
	var manager := obj.get_parent() as PlacedManager
	match obj.kind:
		"trough":
			StorageUI.open_for(player, key_of(obj))
		"gate":
			manager.request("gate", [obj.net_id])
			Sfx.play_at("creak", obj.global_position + Vector3.UP * 0.6, -2.0, 1.2)
		_:
			Sfx.play("click", -6.0, 0.6)


# --- Bichos comendo e bebendo (host) ------------------------------------------------------

## Cocho com a comida deste bicho (water = bebedouro com água) perto da casa dele.
static func find_trough(animal: Animal, water: bool) -> PlacedObject:
	var world: Node = Net.i.world
	var placed: PlacedManager = world.get_node_or_null("Placed") if world else null
	if placed == null:
		return null
	var best: PlacedObject = null
	var best_d := Animal.TROUGH_RANGE
	var food: Array = animal.def().get("food", [])
	for value in placed.objects.values():
		if not is_instance_valid(value):
			continue
		var obj := value as PlacedObject
		if obj.kind != ("water_trough" if water else "trough"):
			continue
		var d := obj.global_position.distance_to(animal.home)
		if d >= best_d:
			continue
		if water:
			if obj.extra.get("water", 0.0) < 1.0:
				continue
		elif _food_slot(obj, food) < 0:
			continue
		best_d = d
		best = obj
	return best


static func _food_slot(obj: PlacedObject, food: Array) -> int:
	if ContainerManager.i == null:
		return -1
	var slots: Array = ContainerManager.i.slots_of(key_of(obj))
	for k in slots.size():
		if not slots[k].is_empty() and slots[k].id in food:
			return k
	return -1


## Tira 1 da comida deste bicho do cocho. false = não tinha.
static func take_food(obj: PlacedObject, kind: String) -> bool:
	var k := _food_slot(obj, Animal.KINDS[kind].get("food", []))
	if k < 0:
		return false
	var key := key_of(obj)
	var slots: Array = ContainerManager.i.contents[key]
	slots[k].amount -= 1
	if slots[k].amount <= 0:
		slots[k] = {}
	ContainerManager.i.changed.emit(key)
	if Net.i.online():
		Net.i._system.rpc("Containers", "sync", [key, slots]) # quem estiver com o cocho aberto vê
	refresh(obj)
	return true


static func take_water(obj: PlacedObject) -> bool:
	if obj.extra.get("water", 0.0) < 1.0:
		return false
	obj.extra.water = obj.extra.water - 1.0
	(obj.get_parent() as PlacedManager).request("extra", [obj.net_id, {"water": obj.extra.water}])
	refresh(obj)
	return true
