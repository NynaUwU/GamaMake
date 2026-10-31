class_name PlacedManager
extends Node3D
## Nó "Placed" da cena principal: potes, canteiros, covas e bancadas.
## Mesma ideia do BuildingManager: online o host valida e repassa a todos;
## quem entra depois recebe tudo (net_sync_to). Salvo pelo SaveGame (grupo
## "persist"). "clock" é o relógio das plantas (segundos de jogo).

var objects := {} ## net_id -> PlacedObject
var clock := 0.0
var _next_id := 1
var _refresh := 0.0


func _ready() -> void:
	add_to_group("persist")


func _process(delta: float) -> void:
	clock += delta
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 1.0
		for obj: PlacedObject in objects.values():
			obj.refresh(clock)


## Pedido de qualquer jogador (vai para o host).
func request(action: String, args: Array) -> void:
	Net.i.system_request(name, action, args)


## Tem alguma coisa a menos de "radius" de "point"? (não empilha potes)
func occupied(point: Vector3, radius: float) -> bool:
	for obj: PlacedObject in objects.values():
		if obj.kind == "bed":
			continue
		if Vector2(obj.global_position.x - point.x, obj.global_position.z - point.z).length() < radius \
				and absf(obj.global_position.y - point.y) < 1.0:
			return true
	return false


func bed_at(cell: Vector3i) -> bool:
	for obj: PlacedObject in objects.values():
		if obj.kind == "bed" and obj.get_meta("cell", Vector3i(-999, 0, 0)) == cell:
			return true
	return false


# --- Host -------------------------------------------------------------------------

func host_apply(action: String, args: Array) -> Array:
	match action:
		"place":
			var kind: String = args[0]
			var xform: Transform3D = args[1]
			if kind not in ["pot_small", "pot_wide", "bed", "ground", "bench", "workbench", "furnace", "campfire",
					"spikes", "beartrap", "barbed", "mine", "drawboard", "chest"]:
				return []
			if kind == "bed":
				var cell := Vector3i((xform.origin / BuildPiece.SEG).round())
				if bed_at(cell):
					return []
			elif occupied(xform.origin, 0.3):
				return []
			var id := _next_id
			_next_id += 1
			_spawn(id, kind, xform)
			return [id, kind, xform]
		"remove":
			if not objects.has(args[0]):
				return []
			var obj: PlacedObject = objects[args[0]]
			if obj.kind == "chest" and ContainerManager.i:
				ContainerManager.i.dump("placed_%d" % obj.net_id, obj.global_position) # o que tinha dentro cai
			_remove(args[0])
			return args
		"plant":
			var obj: PlacedObject = objects.get(args[0])
			var slot: int = args[1]
			var crop: String = args[2]
			if obj == null or slot < 0 or slot >= obj.crops.size() or not obj.crops[slot].is_empty() \
					or not Farming.CROPS.has(crop) or not obj.allows(crop):
				return []
			obj.crops[slot] = {"crop": crop, "t": clock}
			obj.refresh(clock)
			return [args[0], slot, crop, clock]
		"cook":
			var obj: PlacedObject = objects.get(args[0])
			var slot: int = args[1]
			if obj == null or obj.kind != "campfire" or slot < 0 or slot >= obj.crops.size() \
					or not obj.crops[slot].is_empty() or not Cooking.COOK.has(StringName(args[2])):
				return []
			obj.crops[slot] = {"food": StringName(args[2]), "t": clock}
			obj.refresh(clock)
			return [args[0], slot, args[2], clock]
		"take_cooked":
			var obj: PlacedObject = objects.get(args[0])
			var slot: int = args[1]
			if obj == null or obj.kind != "campfire" or slot < 0 or slot >= obj.crops.size():
				return []
			var result := Cooking.result_of(obj.crops[slot], clock)
			if result == &"":
				return []
			Net.i.drop_item(result, 1, Transform3D(Basis(), obj.slot_world(slot) + Vector3.UP * 0.25), Vector3(randf_range(-0.5, 0.5), 2.0, randf_range(-0.5, 0.5)))
			obj.crops[slot] = {}
			obj.refresh(clock)
			return args
		"extra":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or not args[1] is Dictionary:
				return []
			obj.extra.merge(args[1], true)
			obj.refresh(clock)
			return args
		"plant_tree":
			var xform: Transform3D = args[0]
			var planter: PlacedObject = objects.get(args[1]) if args[1] >= 0 else null
			if args[1] >= 0 and (planter == null or planter.extra.has("tree")):
				return []
			if planter == null and occupied(xform.origin, 1.2):
				return []
			var id := _next_id
			_next_id += 1
			_plant_tree(id, xform, clock, args[1])
			return [id, xform, clock, args[1]]
		"chop":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or obj.kind != "tree":
				return []
			if obj.extra.get("deco", false):
				# Muda de decoração (vaso/floreira): um golpe arranca e devolve a muda.
				Net.i.drop_item(&"muda", 1, Transform3D(Basis(), obj.global_position + Vector3.UP * 0.5), Vector3.UP * 2.0)
				_fell(obj)
				return [args[0]]
			if obj.tree_growth(clock) < 1.0:
				return []
			obj.extra.hp = obj.extra.get("hp", 90.0) - float(args[1])
			if obj.extra.hp > 0.0:
				return []
			# Derrubou: troncos, gravetos e SEMPRE uma muda (10% de chance de duas).
			var where := Transform3D(Basis(), obj.global_position + Vector3.UP * 0.8)
			var push := Vector3(randf_range(-1.5, 1.5), 2.5, randf_range(-1.5, 1.5))
			for k in randi_range(2, 3):
				Net.i.drop_item(&"tronco", 1, where.translated(Vector3(k * 0.4, 0, 0)), push)
			Net.i.drop_item(&"muda", 2 if randf() < 0.1 else 1, where, push * Vector3(-1, 1, -1))
			var sticks := randi_range(0, 2)
			if sticks > 0:
				Net.i.drop_item(&"graveto", sticks, where, push * 0.6)
			Sfx.play_at("thud", obj.global_position + Vector3.UP, 4.0, 0.6)
			_fell(obj)
			return [args[0]]
		"draw":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or obj.board == null or not args[1] is PackedVector2Array or args[1].size() > 400:
				return []
			obj.board.stroke(args[1], args[2], args[3])
			return args
		"clear_board":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or obj.board == null:
				return []
			obj.board.clear()
			return args
		"explode":
			var obj: PlacedObject = objects.get(args[0])
			if obj == null or obj.kind != "mine":
				return []
			_explode(obj, false)
			return args
		"harvest":
			var obj: PlacedObject = objects.get(args[0])
			var slot: int = args[1]
			if obj == null or slot < 0 or slot >= obj.crops.size() or PlacedObject.progress(obj.crops[slot], clock) < 1.0:
				return []
			_drop_harvest(obj, slot)
			obj.crops[slot] = {}
			obj.refresh(clock)
			return args
	return []


## A colheita pula da planta: comida + sementes para plantar de novo.
func _drop_harvest(obj: PlacedObject, slot: int) -> void:
	var def: Dictionary = Farming.CROPS[obj.crops[slot].crop]
	var where := Transform3D(Basis(), obj.slot_world(slot) + Vector3.UP * 0.3)
	var food := randi_range(def.yield[0], def.yield[1])
	var seeds := randi_range(def.seeds[0], def.seeds[1])
	Net.i.drop_item(def.food, food, where, Vector3(randf_range(-1, 1), 2.5, randf_range(-1, 1)))
	if seeds > 0:
		Net.i.drop_item(def.seed, seeds, where, Vector3(randf_range(-1, 1), 2.5, randf_range(-1, 1)))
	Sfx.play_at("pickup", where.origin, 0.0, 0.8)


func _plant_tree(id: int, xform: Transform3D, planted: float, planter_id: int) -> void:
	_spawn(id, "tree", xform, true)
	var obj: PlacedObject = objects[id]
	obj.extra.merge({"t": planted, "hp": 90.0, "planter": planter_id}, true)
	var planter: PlacedObject = objects.get(planter_id)
	if planter and planter.kind != "bed":
		obj.extra.deco = true # vaso/floreira não tem terra para virar árvore
	if planter:
		planter.extra.tree = id # floreira/canteiro fica todo ocupado
	obj.refresh(clock)


## Árvore derrubada: some e libera o plantador.
func _fell(obj: PlacedObject) -> void:
	var planter: PlacedObject = objects.get(obj.extra.get("planter", -1))
	if planter:
		planter.extra.erase("tree")
	_remove(obj.net_id)


## Mina: explosão de verdade no host (dano nos zumbis), só o efeito nos clientes.
func _explode(obj: PlacedObject, cosmetic: bool) -> void:
	var explosion := Explosion.new()
	explosion.cosmetic = cosmetic
	get_parent().add_child(explosion)
	explosion.global_position = obj.global_position + Vector3.UP * 0.3
	explosion.detonate(5.0, 120.0, 14.0, 1.8)
	_remove(obj.net_id)


func apply_remote(action: String, args: Array) -> void:
	match action:
		"cook":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.crops[args[1]] = {"food": StringName(args[2]), "t": args[3]}
				obj.refresh(clock)
		"take_cooked":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.crops[args[1]] = {}
				obj.refresh(clock)
		"extra":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.extra.merge(args[1], true)
				obj.refresh(clock)
		"explode":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				_explode(obj, true)
		"plant_tree":
			if not objects.has(args[0]):
				_plant_tree(args[0], args[1], args[2], args[3])
		"chop":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				_fell(obj)
		"draw":
			var obj: PlacedObject = objects.get(args[0])
			if obj and obj.board:
				obj.board.stroke(args[1], args[2], args[3])
		"clear_board":
			var obj: PlacedObject = objects.get(args[0])
			if obj and obj.board:
				obj.board.clear()
		"place":
			if not objects.has(args[0]):
				_spawn(args[0], args[1], args[2])
		"remove":
			_remove(args[0])
		"plant":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.crops[args[1]] = {"crop": args[2], "t": args[3]}
				obj.refresh(clock)
		"harvest":
			var obj: PlacedObject = objects.get(args[0])
			if obj:
				obj.crops[args[1]] = {}
				obj.refresh(clock)


func _spawn(id: int, kind: String, xform: Transform3D, quiet := false) -> void:
	var obj := PlacedObject.new()
	obj.name = "Placed_%d" % id
	obj.net_id = id
	obj.setup(kind)
	if kind == "bed":
		obj.set_meta("cell", Vector3i((xform.origin / BuildPiece.SEG).round()))
	add_child(obj)
	obj.global_transform = xform
	objects[id] = obj
	_next_id = maxi(_next_id, id + 1)
	if not quiet:
		Sfx.play_at("knock" if kind != "ground" else "step_soft", xform.origin + Vector3.UP * 0.3, 0.0, 0.9)


func _remove(id: int) -> void:
	var obj: PlacedObject = objects.get(id)
	objects.erase(id)
	if is_instance_valid(obj):
		obj.queue_free()


# --- Salvar / rede ---------------------------------------------------------------------

func persist_key() -> String:
	return "placed"


func save_data() -> Dictionary:
	var list := []
	for id in objects:
		var obj: PlacedObject = objects[id]
		if obj.board:
			obj.extra["pixels"] = obj.board.packed() # desenho da lousa vai junto
		list.append([id, obj.kind, obj.global_transform, obj.crops.duplicate(true), obj.extra.duplicate(true)])
	return {"clock": clock, "next": _next_id, "list": list}


func load_data(data: Dictionary) -> void:
	for id in objects.keys():
		_remove(id)
	clock = data.get("clock", 0.0)
	_next_id = data.get("next", 1)
	for entry in data.get("list", []):
		_spawn(entry[0], entry[1], entry[2], true)
		var obj: PlacedObject = objects[entry[0]]
		for i in mini(entry[3].size(), obj.crops.size()):
			obj.crops[i] = entry[3][i]
		if entry.size() > 4:
			obj.extra.merge(entry[4], true)
			if obj.board and obj.extra.has("pixels"):
				obj.board.unpack(obj.extra.pixels)
		obj.refresh(clock)


## Quem acabou de entrar recebe tudo.
func net_sync_to(peer: int) -> void:
	Net.i.send_system_state(peer, name, save_data())
