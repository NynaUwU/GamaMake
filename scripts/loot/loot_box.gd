class_name LootBox
extends StaticBody3D
## Baú, armário ou caixote das cidades. [E] revista: os itens pulam para fora
## (o host sorteia; ver Net.loot_request). Cada um só uma vez por mundo: a chave
## é fixa (cidade + casa), então todo jogador vê o mesmo baú vazio e o save lembra.

const STYLES := ["bau", "armario", "caixote"]

var key := ""
var style := "bau"
var table := "casa"
var _lid: Node3D

static var _material: StandardMaterial3D


func setup(key_: String, style_: String, table_: String) -> void:
	key = key_
	style = style_
	table = table_
	collision_layer = 1 | (1 << 5)
	collision_mask = 0
	_build()
	if Net.i.taken.has(key):
		_set_open(false)
	else:
		add_to_group("interactable")
	Net.i.looted.connect(_on_looted)


func get_interact_text() -> String:
	return "[E] Revistar %s" % {"bau": "baú", "armario": "armário", "caixote": "caixote"}[style]


func interact(_player: Node) -> void:
	Net.i.loot_request(key, global_transform, table)


func _on_looted(k: String) -> void:
	if k == key and is_in_group("interactable"):
		_set_open(true)


func _set_open(animate: bool) -> void:
	remove_from_group("interactable")
	if animate:
		Sfx.play_at("creak", global_position + Vector3.UP * 0.6, 0.0, 1.3)
	if _lid == null:
		return
	var target := Vector3(-1.9, 0, 0) if style == "bau" else (Vector3(0, -1.8, 0) if style == "armario" else Vector3(-0.4, 0.3, 0.9))
	if animate:
		create_tween().tween_property(_lid, "rotation", target, 0.35).set_trans(Tween.TRANS_BACK)
	else:
		_lid.rotation = target


func _build() -> void:
	var body := MeshBuilder.new()
	var lid := MeshBuilder.new()
	var wood := Color(0.4, 0.26, 0.15)
	var dark := Color(0.24, 0.15, 0.08)
	var hinge := Vector3.ZERO
	match style:
		"bau": # baú com cintas de ferro e fecho de latão
			body.color(wood)
			body.box(Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.55))
			body.color(ItemModels.IRON)
			for x in [-0.32, 0.32]:
				body.box(Vector3(x, 0.25, 0), Vector3(0.05, 0.52, 0.57))
			hinge = Vector3(0, 0.5, -0.275)
			lid.color(wood.darkened(0.08))
			lid.box(Vector3(0, 0.08, 0.275), Vector3(0.9, 0.16, 0.55))
			lid.color(ItemModels.BRASS)
			lid.box(Vector3(0, 0.02, 0.56), Vector3(0.08, 0.1, 0.03))
			_shape(Vector3(0, 0.33, 0), Vector3(0.9, 0.66, 0.55))
		"armario": # armário alto com porta de uma folha
			body.color(dark)
			body.box(Vector3(0, 0.9, -0.02), Vector3(0.8, 1.8, 0.46))
			body.color(wood)
			body.box(Vector3(0, 1.84, 0), Vector3(0.88, 0.08, 0.52))
			hinge = Vector3(-0.39, 0.0, 0.23)
			lid.color(wood)
			lid.box(Vector3(0.39, 0.9, 0.0), Vector3(0.78, 1.7, 0.04))
			lid.color(ItemModels.BRASS)
			lid.box(Vector3(0.7, 0.95, 0.05), Vector3(0.03, 0.12, 0.03))
			_shape(Vector3(0, 0.92, 0), Vector3(0.88, 1.84, 0.52))
		"caixote": # caixote de ripas com tampa solta
			body.color(wood.lightened(0.08))
			body.box(Vector3(0, 0.3, 0), Vector3(0.7, 0.6, 0.7))
			body.color(dark)
			for y in [0.12, 0.48]:
				body.box(Vector3(0, y, 0), Vector3(0.72, 0.06, 0.72))
			hinge = Vector3(0, 0.6, 0)
			lid.color(wood)
			lid.box(Vector3(0, 0.025, 0), Vector3(0.72, 0.05, 0.72))
			_shape(Vector3(0, 0.32, 0), Vector3(0.72, 0.65, 0.72))
	var mesh := MeshInstance3D.new()
	mesh.mesh = body.finish(_mat(), false)
	add_child(mesh)
	_lid = Node3D.new()
	_lid.position = hinge
	add_child(_lid)
	var lid_mesh := MeshInstance3D.new()
	lid_mesh.mesh = lid.finish(_mat(), false) # a tampa/porta já é desenhada a partir da dobradiça
	_lid.add_child(lid_mesh)


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
