class_name PickupFeed
extends VBoxContainer
## Canto de cima à esquerda, discreto: "+3 Graveto" a cada coisa que entra na
## mochila (inclusive comida que estragou). Some sozinho em ~3 s; o mesmo item
## pego de novo logo depois soma na mesma linha.

const LIFE := 3.0
const MAX_LINES := 5

var _lines := {} # id -> {"label": Label, "amount": int, "time": float}


func setup(inventory: Inventory) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(12, 42)
	add_theme_constant_override("separation", 0)
	inventory.gained.connect(_on_gained)


func _on_gained(id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var entry: Dictionary = _lines.get(id, {})
	if entry.is_empty() or not is_instance_valid(entry.label):
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		label.add_theme_constant_override("outline_size", 2)
		label.modulate = Color(1, 1, 1, 0.75)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		entry = {"label": label, "amount": 0, "time": 0.0}
		_lines[id] = entry
		while get_child_count() > MAX_LINES:
			var oldest := get_child(0)
			remove_child(oldest)
			oldest.queue_free()
	entry.amount += amount
	entry.time = LIFE
	entry.label.text = "+%d %s" % [entry.amount, ItemDB.display_name(id)]
	if id == &"comida_estragada":
		entry.label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.4))


func _process(delta: float) -> void:
	for id in _lines.keys():
		var entry: Dictionary = _lines[id]
		if not is_instance_valid(entry.label):
			_lines.erase(id)
			continue
		entry.time -= delta
		entry.label.modulate.a = 0.75 * clampf(entry.time / 0.6, 0.0, 1.0)
		if entry.time <= 0.0:
			entry.label.queue_free()
			_lines.erase(id)
