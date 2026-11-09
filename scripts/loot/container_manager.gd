class_name ContainerManager
extends Node
## Nó "Containers": o conteúdo de cada baú/armário/caixote (chave fixa do
## LootBox). Na primeira abertura o host sorteia o saque e guarda nos slots;
## depois o baú é um inventário normal: pegar e guardar itens. Online o host
## decide e repassa; vai no save.

signal changed(key: String)

const SLOTS := 12
const STORAGE_SLOTS := 21 ## 7x3

static var i: ContainerManager

var contents := {} ## chave -> Array de slots ({} ou {"id", "amount"})


func _enter_tree() -> void:
	i = self


func _exit_tree() -> void:
	if i == self:
		i = null


func _ready() -> void:
	add_to_group("persist")


func request(action: String, args: Array) -> void:
	Net.i.system_request(name, action, args)


func slots_of(key: String) -> Array:
	return contents.get(key, [])


static func empty_slots(count := SLOTS) -> Array:
	var list := []
	for k in count:
		list.append({})
	return list


## Coloca itens nos slots (junta pilhas, depois vazios). Devolve o que sobrou.
static func add_to(slots: Array, id: StringName, amount: int) -> int:
	var stack := ItemDB.max_stack(id)
	for s in slots:
		if amount <= 0:
			break
		if not s.is_empty() and s.id == id and s.amount < stack:
			var moved := mini(stack - s.amount, amount)
			ItemDB.merge_into(s, moved)
			amount -= moved
	for k in slots.size():
		if amount <= 0:
			break
		if slots[k].is_empty():
			var moved := mini(stack, amount)
			slots[k] = {"id": id, "amount": moved}
			amount -= moved
	return amount


# --- Host ---------------------------------------------------------------------------

func host_apply(action: String, args: Array) -> Array:
	var result := _host(action, args)
	if not result.is_empty():
		changed.emit(result[0])
	return result


## Baús do mundo ("loot_...") só deixam retirar; baús construídos ("placed_...")
## guardam também (21 slots, arrastar e soltar).
static func is_storage(key: String) -> bool:
	return key.begins_with("placed_") or key.begins_with("car_") or key.begins_with("furnace_") # baú, porta-malas, fornalha


func _host(action: String, args: Array) -> Array:
	var key: String = args[0]
	match action:
		"open":
			if not contents.has(key):
				var slots := empty_slots(3 if key.begins_with("furnace_") else (STORAGE_SLOTS if is_storage(key) else SLOTS))
				if not is_storage(key) and not Net.i.taken.has(key): # baú de save antigo já revistado: vazio
					for drop in Loot.roll(args[1]):
						add_to(slots, drop[0], drop[1])
				contents[key] = slots
			if is_storage(key) and not key.begins_with("furnace_"):
				while contents[key].size() < STORAGE_SLOTS: # baú de save antigo (20)
					contents[key].append({})
			if not is_storage(key) and not Net.i.taken.has(key):
				Net.i.mark_taken(key) # tampa abre para todos
			return [key, contents[key]]
		"take":
			# args: [chave, slot do baú, (slot da mochila de destino, opcional)]
			var slots: Array = contents.get(key, [])
			var index: int = args[1]
			if index < 0 or index >= slots.size() or slots[index].is_empty():
				return []
			var slot: Dictionary = slots[index]
			slots[index] = {}
			Net.i.give_to(Net.i.request_peer, slot.id, slot.amount, args[2] if args.size() > 2 else -1, slot.get("dur", 1.0), ItemDB.extras(slot))
			return [key, slots]
		"swap":
			var slots: Array = contents.get(key, [])
			var a: int = args[1]
			var b: int = args[2]
			if not is_storage(key) or a == b or a < 0 or b < 0 or a >= slots.size() or b >= slots.size():
				return []
			var fkind := Smelting.kind_of_key(key) if key.begins_with("furnace_") else ""
			if key.begins_with("furnace_") and (not slots[a].is_empty() and not Smelting.accepts(b, slots[a].id, fkind) \
					or not slots[b].is_empty() and not Smelting.accepts(a, slots[b].id, fkind)):
				return [] # combustível só no lugar do combustível; resultado não recebe nada
			_swap(slots, a, b)
			return [key, slots]
		"sync":
			# Host avisando todos (a fornalha fundiu algo).
			if Net.i.request_peer != Net.i.my_id() or not contents.has(key):
				return []
			return [key, contents[key]]
		"put_at":
			# Item vindo da mochila para um slot certo do baú construído.
			var slots: Array = contents.get(key, [])
			var index: int = args[1]
			var id := StringName(args[2])
			var amount: int = args[3]
			if not is_storage(key) or index < 0 or index >= slots.size() or not ItemDB.has(id) or amount <= 0 \
					or (key.begins_with("furnace_") and not Smelting.accepts(index, id, Smelting.kind_of_key(key))):
				if ItemDB.has(id) and amount > 0:
					Net.i.give_to(Net.i.request_peer, id, amount) # recusado: devolve
				return []
			var target: Dictionary = slots[index]
			var dur: float = args[4] if args.size() > 4 else 1.0
			var extra: Dictionary = args[5] if args.size() > 5 and args[5] is Dictionary else {}
			if target.is_empty():
				slots[index] = {"id": id, "amount": amount}
				if dur < 1.0:
					slots[index].dur = dur
				slots[index].merge(extra)
			elif target.id == id and extra.is_empty() and ItemDB.extras(target).is_empty():
				var moved := mini(ItemDB.max_stack(id) - target.amount, amount)
				ItemDB.merge_into(target, moved, dur)
				if amount - moved > 0:
					Net.i.give_to(Net.i.request_peer, id, amount - moved)
			else:
				slots[index] = {"id": id, "amount": amount} # troca: o que estava volta para quem soltou
				if dur < 1.0:
					slots[index].dur = dur
				slots[index].merge(extra)
				Net.i.give_to(Net.i.request_peer, target.id, target.amount, -1, target.get("dur", 1.0), ItemDB.extras(target))
			return [key, slots]
	return []


static func _swap(slots: Array, a: int, b: int) -> void:
	if not slots[a].is_empty() and not slots[b].is_empty() and slots[a].id == slots[b].id:
		var moved := mini(ItemDB.max_stack(slots[a].id) - slots[b].amount, slots[a].amount)
		if moved > 0:
			ItemDB.merge_into(slots[b], moved, slots[a].get("dur", 1.0))
			slots[a].amount -= moved
			if slots[a].amount <= 0:
				slots[a] = {}
			return
	var temp: Dictionary = slots[a]
	slots[a] = slots[b]
	slots[b] = temp


## Baú construído desmontado: o que tinha dentro cai no chão.
## Host: a comida guardada também estraga (geladeira, no Tier 4, vai pular isso).
var _spoil_timer := 10.0
func _process(delta: float) -> void:
	_spoil_timer -= delta
	if _spoil_timer > 0.0 or not Net.i.is_host():
		return
	_spoil_timer = 10.0
	for key in contents:
		if cold_keys.has(key):
			continue
		var touched := false
		for k in contents[key].size():
			var s: Dictionary = contents[key][k]
			if not s.is_empty() and ItemDB.spoils(s.id):
				s.dur = s.get("dur", 1.0) - 10.0 / ItemDB.SPOIL[s.id]
				touched = true
				if s.dur <= 0.0:
					contents[key][k] = {"id": &"comida_estragada", "amount": s.amount}
		if touched:
			changed.emit(key)

var cold_keys := {} ## baús frios (geladeira): a comida não estraga


func dump(key: String, where: Vector3) -> void:
	for slot in contents.get(key, []):
		if not slot.is_empty():
			Net.i.drop_item(slot.id, slot.amount, Transform3D(Basis(), where + Vector3.UP * 0.6),
				Vector3(randf_range(-1.5, 1.5), 2.5, randf_range(-1.5, 1.5)))
	contents.erase(key)


func apply_remote(action: String, args: Array) -> void:
	if args.size() >= 2:
		contents[args[0]] = args[1]
		changed.emit(args[0])


# --- Salvar / rede ------------------------------------------------------------------

func persist_key() -> String:
	return "containers"


func save_data() -> Dictionary:
	return contents.duplicate(true)


func load_data(data: Dictionary) -> void:
	contents = data.duplicate(true)
	for key in contents:
		changed.emit(key)


func net_sync_to(peer: int) -> void:
	Net.i.send_system_state(peer, name, contents)
