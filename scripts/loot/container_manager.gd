class_name ContainerManager
extends Node
## Nó "Containers": o conteúdo de cada baú/armário/caixote (chave fixa do
## LootBox). Na primeira abertura o host sorteia o saque e guarda nos slots;
## depois o baú é um inventário normal: pegar e guardar itens. Online o host
## decide e repassa; vai no save.

signal changed(key: String)

const SLOTS := 12

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


static func empty_slots() -> Array:
	var list := []
	for k in SLOTS:
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
			s.amount += moved
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


func _host(action: String, args: Array) -> Array:
	var key: String = args[0]
	match action:
		"open":
			if not contents.has(key):
				var slots := empty_slots()
				if not Net.i.taken.has(key): # baú de save antigo já revistado: vazio
					for drop in Loot.roll(args[1]):
						add_to(slots, drop[0], drop[1])
				contents[key] = slots
			if not Net.i.taken.has(key):
				Net.i.mark_taken(key) # tampa abre para todos
			return [key, contents[key]]
		"take":
			var slots: Array = contents.get(key, [])
			var index: int = args[1]
			if index < 0 or index >= slots.size() or slots[index].is_empty():
				return []
			var slot: Dictionary = slots[index]
			slots[index] = {}
			Net.i.give_to(Net.i.request_peer, slot.id, slot.amount)
			return [key, slots]
		"put":
			var slots: Array = contents.get(key, [])
			var id := StringName(args[1])
			var amount: int = args[2]
			if slots.is_empty() or not ItemDB.has(id) or amount <= 0:
				return []
			var left := add_to(slots, id, amount)
			if left > 0:
				Net.i.give_to(Net.i.request_peer, id, left) # não coube: volta
			return [key, slots]
	return []


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
