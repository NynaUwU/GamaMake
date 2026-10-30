class_name PlacedObject
extends StaticBody3D
## Objeto colocado pelo martelo (ou cova cavada pela pá):
##   pot_small  pote pequeno de barro (1 planta, sem abóbora)
##   pot_wide   floreira larga de madeira (3 plantas)
##   bed        canteiro: piso de terra de 2,8 x 2,8 m na grade da construção (9 plantas)
##   ground     cova cavada no chão pela pá (1 planta)
##   bench      bancada de fabricação ([E] abre a lista de receitas)
## As plantas crescem pelo relógio do PlacedManager (igual para todos e salvo).

const FARM_KINDS := ["pot_small", "pot_wide", "bed", "ground"]
const SOIL := Color(0.34, 0.23, 0.15)
const CLAY := Color(0.62, 0.32, 0.2)

var net_id := 0
var kind := "pot_small"
var crops: Array = [] ## por vaga: {} ou {"crop": "cenoura", "t": hora em que plantou}
var _stages: Array = [] # estágio desenhado em cada vaga (-1 = vazia)
var _plants: Array = [] # Node3D de cada vaga

static var _material: StandardMaterial3D


func setup(kind_: String) -> void:
	kind = kind_
	collision_layer = 1 | (1 << 5)
	collision_mask = 0
	add_to_group("interactable")
	var slots := slot_positions()
	crops.resize(slots.size())
	for i in slots.size():
		crops[i] = {}
		_stages.append(-1)
		var plant := Node3D.new()
		plant.position = slots[i]
		add_child(plant)
		_plants.append(plant)
	_build()


func is_farm() -> bool:
	return kind in FARM_KINDS


## Onde fica cada planta (espaço local).
func slot_positions() -> Array:
	match kind:
		"pot_small":
			return [Vector3(0, 0.3, 0)]
		"pot_wide":
			return [Vector3(-0.4, 0.34, 0), Vector3(0, 0.34, 0), Vector3(0.4, 0.34, 0)]
		"bed":
			var list := []
			for j in 3:
				for i in 3:
					list.append(Vector3(0.47 + i * 0.93, 0.22, 0.47 + j * 0.93))
			return list
		"ground":
			return [Vector3(0, 0.06, 0)]
	return []


func allows(crop: String) -> bool:
	return is_farm() and not (kind == "pot_small" and crop == "abobora")


## Vaga mais perto de um ponto do mundo (onde a mira bateu).
func slot_at(world_point: Vector3) -> int:
	var local := to_local(world_point)
	var best := -1
	var best_d := INF
	var slots := slot_positions()
	for i in slots.size():
		var d: float = Vector2(local.x - slots[i].x, local.z - slots[i].z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


func slot_world(i: int) -> Vector3:
	return to_global(slot_positions()[i])


static func progress(entry: Dictionary, clock: float) -> float:
	if entry.is_empty():
		return -1.0
	var time: float = Farming.CROPS[entry.crop].time
	return clampf((clock - entry.t) / time, 0.0, 1.0)


## Atualiza o desenho das plantas (chamado ~1x por segundo pelo manager).
func refresh(clock: float) -> void:
	for i in crops.size():
		var p := progress(crops[i], clock)
		var stage := -1 if p < 0.0 else mini(int(p * 3.0), 3)
		if stage != _stages[i]:
			_stages[i] = stage
			for child in _plants[i].get_children():
				child.queue_free()
			if stage >= 0:
				_plants[i].add_child(Farming.plant_model(crops[i].crop, stage, kind == "bed"))


func ready_count(clock: float) -> int:
	var n := 0
	for entry in crops:
		if progress(entry, clock) >= 1.0:
			n += 1
	return n


func get_interact_text() -> String:
	if kind == "bench":
		return "[E] Bancada (fabricar)"
	var manager := get_parent() as PlacedManager
	var clock := manager.clock if manager else 0.0
	var ready := ready_count(clock)
	if ready > 0:
		return "[E] Colher (%d pronta%s)" % [ready, "s" if ready > 1 else ""]
	var growing := []
	for entry in crops:
		if not entry.is_empty():
			growing.append("%s %d%%" % [ItemDB.display_name(Farming.CROPS[entry.crop].food), progress(entry, clock) * 100.0])
	if growing.is_empty():
		return "Vazio: plante com sementes na mão ou com a pá"
	return " · ".join(growing.slice(0, 3)) + (" ..." if growing.size() > 3 else "")


func interact(player: Node) -> void:
	var manager := get_parent() as PlacedManager
	if manager == null:
		return
	if kind == "bench":
		CraftingUI.open_for(player)
		return
	for i in crops.size():
		if progress(crops[i], manager.clock) >= 1.0:
			manager.request("harvest", [net_id, i])


# --- Modelos ---------------------------------------------------------------------

func _build() -> void:
	var mb := MeshBuilder.new()
	match kind:
		"pot_small":
			mb.color(CLAY)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.15, 0.0), Vector2(0.2, 0.26), Vector2(0.23, 0.27),
				Vector2(0.23, 0.31), Vector2(0.19, 0.31), Vector2(0.18, 0.28)]), 10)
			mb.color(SOIL)
			mb.lathe(PackedVector2Array([Vector2(0.18, 0.27), Vector2(0.002, 0.28)]), 10)
			_shape(Vector3(0, 0.155, 0), Vector3(0.42, 0.31, 0.42))
		"pot_wide":
			var wood := Color(0.4, 0.26, 0.15)
			mb.color(wood)
			mb.box(Vector3(0, 0.05, 0), Vector3(1.24, 0.1, 0.46))
			for side in [-1.0, 1.0]:
				mb.box(Vector3(0, 0.2, side * 0.21), Vector3(1.24, 0.3, 0.05))
				mb.box(Vector3(side * 0.6, 0.2, 0), Vector3(0.05, 0.3, 0.46))
			mb.color(ItemModels.IRON)
			for side in [-1.0, 1.0]:
				mb.box(Vector3(side * 0.45, 0.2, 0.24), Vector3(0.04, 0.3, 0.01))
				mb.box(Vector3(side * 0.45, 0.2, -0.24), Vector3(0.04, 0.3, 0.01))
			mb.color(SOIL)
			mb.box(Vector3(0, 0.3, 0), Vector3(1.14, 0.04, 0.38))
			_shape(Vector3(0, 0.18, 0), Vector3(1.24, 0.36, 0.48))
		"bed":
			var s := BuildPiece.SIZE
			var t := BuildPiece.THICK
			mb.color(Color(0.36, 0.24, 0.14))
			for side in [0.0, 1.0]:
				mb.box(Vector3(s * 0.5, (0.22 - t) * 0.5, side * s + (0.06 if side == 0.0 else -0.06)), Vector3(s, 0.22 + t, 0.12))
				mb.box(Vector3(side * s + (0.06 if side == 0.0 else -0.06), (0.22 - t) * 0.5, s * 0.5), Vector3(0.12, 0.22 + t, s - 0.24))
			mb.color(SOIL)
			mb.box(Vector3(s * 0.5, (0.18 - t) * 0.5, s * 0.5), Vector3(s - 0.24, 0.18 + t, s - 0.24))
			# Sulcos de terra entre as fileiras.
			mb.color(SOIL.darkened(0.25))
			for j in 2:
				mb.box(Vector3(s * 0.5, 0.185, 0.93 * (j + 1)), Vector3(s - 0.3, 0.02, 0.08))
			_shape(Vector3(s * 0.5, (0.22 - t) * 0.5, s * 0.5), Vector3(s, 0.22 + t, s))
		"ground":
			mb.color(SOIL)
			mb.lathe(PackedVector2Array([Vector2(0.45, -0.05), Vector2(0.4, 0.03), Vector2(0.25, 0.06), Vector2(0.002, 0.04)]), 9)
			mb.color(SOIL.lightened(0.1))
			for k in 5:
				var a := TAU * k / 5.0 + 0.4
				mb.box(Vector3(cos(a) * 0.42, 0.04, sin(a) * 0.42), Vector3(0.1, 0.06, 0.08), Basis(Vector3.UP, a))
			_shape(Vector3(0, 0.0, 0), Vector3(0.8, 0.12, 0.8))
		"bench":
			var wood := Color(0.42, 0.28, 0.16)
			mb.color(wood)
			mb.box(Vector3(0, 0.86, 0), Vector3(1.6, 0.08, 0.75))
			for x in [-0.72, 0.72]:
				for z in [-0.3, 0.3]:
					mb.box(Vector3(x, 0.41, z), Vector3(0.08, 0.82, 0.08))
			mb.box(Vector3(0, 0.25, 0), Vector3(1.44, 0.05, 0.6)) # prateleira
			# Torno de ferro e engrenagem de latão (steampunk).
			mb.color(ItemModels.IRON)
			mb.box(Vector3(0.6, 0.97, 0.2), Vector3(0.16, 0.14, 0.12))
			mb.box(Vector3(0.6, 0.97, 0.32), Vector3(0.03, 0.03, 0.14))
			mb.color(ItemModels.BRASS)
			mb.lathe(PackedVector2Array([Vector2(0.002, -0.015), Vector2(0.12, -0.015), Vector2(0.12, 0.015), Vector2(0.002, 0.015)]), 10,
					Basis(Vector3.RIGHT, PI / 2), Vector3(-0.45, 0.91, -0.1))
			mb.color(ItemModels.WOOD)
			mb.box(Vector3(-0.1, 0.92, 0.05), Vector3(0.6, 0.04, 0.12), Basis(Vector3.UP, 0.3))
			_shape(Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.75))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(_mat(), false)
	add_child(mesh)


func _shape(center: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	add_child(shape)


static func _mat() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 1.0
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material
