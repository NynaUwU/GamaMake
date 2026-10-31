class_name Inventory
extends Node
## Inventário do player: 9 slots de hotbar (teclas 1-9) + mochila 9x4, e o
## equipamento vestido (cabeça, corpo, pernas, pés).
## Cada slot é {} (vazio) ou {"id": StringName, "amount": int}.

signal changed ## qualquer slot mudou
signal selection_changed(index: int)

const HOTBAR_SIZE := 9
const BACKPACK_SIZE := 36
const EQUIP_SLOTS := ["head", "body", "legs", "feet"]

var slots: Array = []
var selected := 0
var equipment := {"head": {}, "body": {}, "legs": {}, "feet": {}} ## o que está vestido


## Quanto do dano a roupa/armadura vestida segura (0..0,8).
func armor() -> float:
	var total := 0.0
	for slot in equipment:
		if not equipment[slot].is_empty():
			total += ItemDB.def(equipment[slot].id).get("armor", 0.0)
	return minf(total, 0.8)


## Veste o item do slot da mochila (troca com o que estava vestido). true = vestiu.
func equip_from(index: int, slot_name: String) -> bool:
	var item: Dictionary = slots[index]
	if item.is_empty() or ItemDB.def(item.id).get("slot", "") != slot_name:
		return false
	var old: Dictionary = equipment[slot_name]
	equipment[slot_name] = item
	slots[index] = old
	changed.emit()
	return true


## Tira o que está vestido para um slot da mochila (troca se tiver roupa do mesmo tipo lá).
func unequip_to(slot_name: String, index: int) -> bool:
	var worn: Dictionary = equipment[slot_name]
	if worn.is_empty():
		return false
	var there: Dictionary = slots[index]
	if not there.is_empty() and ItemDB.def(there.id).get("slot", "") != slot_name:
		return false
	equipment[slot_name] = there
	slots[index] = worn
	changed.emit()
	return true


func _init() -> void:
	slots.resize(HOTBAR_SIZE + BACKPACK_SIZE)
	for i in slots.size():
		slots[i] = {}


## Adiciona itens; devolve quanto NÃO coube (0 = coube tudo).
## Armas e ferramentas vão primeiro para a hotbar; materiais para a mochila.
func add(id: StringName, amount := 1) -> int:
	var left := amount
	var stack := ItemDB.max_stack(id)
	for i in slots.size():
		if left <= 0:
			break
		if not slots[i].is_empty() and slots[i].id == id and slots[i].amount < stack:
			var moved := mini(stack - slots[i].amount, left)
			slots[i].amount += moved
			left -= moved
	var order := _fill_order(id)
	for i in order:
		if left <= 0:
			break
		if slots[i].is_empty():
			var moved := mini(stack, left)
			slots[i] = {"id": id, "amount": moved}
			left -= moved
	if left != amount:
		changed.emit()
	return left


## Tira "amount" do slot; devolve o que saiu ({} se vazio).
func take(index: int, amount := 1) -> Dictionary:
	if slots[index].is_empty():
		return {}
	var moved := mini(amount, slots[index].amount)
	var result := {"id": slots[index].id, "amount": moved}
	slots[index].amount -= moved
	if slots[index].amount <= 0:
		slots[index] = {}
	changed.emit()
	return result


func swap(a: int, b: int) -> void:
	if a == b:
		return
	# Mesmo item empilhável: junta no destino.
	if not slots[a].is_empty() and not slots[b].is_empty() and slots[a].id == slots[b].id:
		var stack := ItemDB.max_stack(slots[a].id)
		var moved := mini(stack - slots[b].amount, slots[a].amount)
		if moved > 0:
			slots[b].amount += moved
			slots[a].amount -= moved
			if slots[a].amount <= 0:
				slots[a] = {}
			changed.emit()
			return
	var temp: Dictionary = slots[a]
	slots[a] = slots[b]
	slots[b] = temp
	changed.emit()


func select(index: int) -> void:
	selected = clampi(index, 0, HOTBAR_SIZE - 1)
	selection_changed.emit(selected)


func selected_id() -> StringName:
	return slots[selected].id if not slots[selected].is_empty() else &""


func has(id: StringName) -> bool:
	for slot in slots:
		if not slot.is_empty() and slot.id == id:
			return true
	return false


func count(id: StringName) -> int:
	var total := 0
	for slot in slots:
		if not slot.is_empty() and slot.id == id:
			total += slot.amount
	return total


func _fill_order(id: StringName) -> Array:
	var hotbar := range(HOTBAR_SIZE)
	var backpack := range(HOTBAR_SIZE, slots.size())
	if ItemDB.def(id).kind == "material":
		return backpack + hotbar
	return hotbar + backpack
