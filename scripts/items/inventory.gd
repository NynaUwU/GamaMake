class_name Inventory
extends Node
## Inventário do player: 9 slots de hotbar (teclas 1-9) + mochila 9x4, e o
## equipamento vestido (cabeça, corpo, pernas, pés) + a mão secundária (tocha ou
## lanterna, sempre com você sem ocupar a mão da arma).
## Cada slot é {} (vazio) ou {"id": StringName, "amount": int}.

signal changed ## qualquer slot mudou
signal selection_changed(index: int)
signal gained(id: StringName, amount: int) ## entrou na mochila (aviso de coleta)

const HOTBAR_SIZE := 9
const BACKPACK_SIZE := 36
const EQUIP_SLOTS := ["head", "body", "legs", "feet", "offhand"]

var slots: Array = []
var selected := 0
var equipment := {"head": {}, "body": {}, "legs": {}, "feet": {}, "offhand": {}} ## o que está vestido / na outra mão


## Gasta "uses" usos do item do slot. Devolve true se quebrou (some do slot).
func wear(index: int, uses := 1.0) -> bool:
	if index < 0 or index >= slots.size() or slots[index].is_empty():
		return false
	var broke := _wear_item(slots[index], uses)
	if broke:
		slots[index] = {}
	changed.emit()
	return broke


## Cada pedaço de roupa vestido gasta um uso (levou um golpe). true = algo quebrou.
func wear_equipment() -> bool:
	var broke := false
	for slot in equipment:
		if slot == "offhand":
			continue # tocha/lanterna não gastam com pancada
		if not equipment[slot].is_empty() and _wear_item(equipment[slot], 1):
			equipment[slot] = {}
			broke = true
	changed.emit()
	return broke


func _wear_item(item: Dictionary, uses: float) -> bool:
	var total := ItemDB.max_durability(item.id)
	if total <= 0:
		return false
	item.dur = item.get("dur", 1.0) - uses * ItemDB.quality_wear(item) / total # peça forjada boa gasta menos
	return item.dur <= 0.0


## Quanto do dano a roupa/armadura vestida segura (0..0,8).
func armor() -> float:
	var total := 0.0
	for slot in equipment:
		if not equipment[slot].is_empty():
			total += ItemDB.def(equipment[slot].id).get("armor", 0.0) * ItemDB.quality_damage(equipment[slot]) # solda/forja boa protege mais
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
func add(id: StringName, amount := 1, dur := 1.0, extra := {}) -> int:
	var left := amount
	var stack := ItemDB.max_stack(id)
	for i in slots.size():
		if left <= 0 or not extra.is_empty():
			break # peça com qualidade/fio não junta com outra
		if not slots[i].is_empty() and slots[i].id == id and slots[i].amount < stack:
			var moved := mini(stack - slots[i].amount, left)
			ItemDB.merge_into(slots[i], moved, dur)
			left -= moved
	var order := _fill_order(id)
	for i in order:
		if left <= 0:
			break
		if slots[i].is_empty():
			var moved := mini(stack, left)
			slots[i] = {"id": id, "amount": moved}
			if dur < 1.0 and (ItemDB.max_durability(id) > 0 or ItemDB.spoils(id)):
				slots[i].dur = dur # item gasto (do chão, de zumbi...)
			slots[i].merge(extra)
			left -= moved
	if left != amount:
		gained.emit(id, amount - left)
		changed.emit()
	return left


## Recursos "brutos" (o resto dos materiais conta como refinado).
const RAW := [&"tronco", &"pedra", &"minerio_ferro", &"minerio_cobre", &"argila", &"areia", &"sucata", &"fibra",
	&"trigo", &"carvao", &"muda"]


## Ordem do botão Organizar: armas, ferramentas, recursos brutos, refinados,
## outros, sementes, comida. Alfabético em cada grupo; comida pelo que vence antes.
static func sort_group(id: StringName) -> int:
	var kind: String = ItemDB.def(id).get("kind", "material")
	if id in RAW:
		return 2
	match kind:
		"weapon":
			return 0
		"tool":
			return 1
		"material":
			return 3
		"seed":
			return 5
		"food":
			return 6
	return 4


## Organiza só a mochila (a hotbar fica como está): junta pilhas e ordena.
func sort_backpack() -> void:
	var items: Array = []
	for i in range(HOTBAR_SIZE, slots.size()):
		if slots[i].is_empty():
			continue
		var item: Dictionary = slots[i].duplicate()
		var merged := false
		for other in items:
			if other.id == item.id and other.amount < ItemDB.max_stack(item.id) and ItemDB.max_durability(item.id) <= 0:
				var moved := mini(ItemDB.max_stack(item.id) - other.amount, item.amount)
				ItemDB.merge_into(other, moved, item.get("dur", 1.0))
				item.amount -= moved
				if item.amount <= 0:
					merged = true
					break
		if not merged:
			items.append(item)
	items.sort_custom(func(a, b):
		var ga := sort_group(a.id)
		var gb := sort_group(b.id)
		if ga != gb:
			return ga < gb
		if ga == 6: # comida: o que vence antes primeiro (o que não estraga por último)
			var ta: float = ItemDB.SPOIL.get(a.id, INF) * a.get("dur", 1.0)
			var tb: float = ItemDB.SPOIL.get(b.id, INF) * b.get("dur", 1.0)
			if ta != tb:
				return ta < tb
		return ItemDB.display_name(a.id).naturalnocasecmp_to(ItemDB.display_name(b.id)) < 0)
	for i in range(HOTBAR_SIZE, slots.size()):
		var k := i - HOTBAR_SIZE
		slots[i] = items[k] if k < items.size() else {}
	changed.emit()


## Comida estragando (chamado pelo jogador a cada poucos segundos). true = mudou algo.
func spoil(seconds: float) -> bool:
	var result := ItemDB.spoil_slots(slots, seconds)
	if result.rotten > 0:
		gained.emit(&"comida_estragada", result.rotten)
	if result.any:
		changed.emit()
	return result.any


## Tira "amount" do slot; devolve o que saiu ({} se vazio).
func take(index: int, amount := 1) -> Dictionary:
	if slots[index].is_empty():
		return {}
	var moved := mini(amount, slots[index].amount)
	var result := {"id": slots[index].id, "amount": moved}
	if slots[index].has("dur"):
		result.dur = slots[index].dur
	result.merge(ItemDB.extras(slots[index])) # qualidade da forja, fio
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
			ItemDB.merge_into(slots[b], moved, slots[a].get("dur", 1.0))
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
