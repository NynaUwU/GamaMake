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
var _opened := false

static var _material: StandardMaterial3D


func setup(key_: String, style_: String, table_: String) -> void:
	key = key_
	style = style_
	table = table_
	collision_layer = 1 | (1 << 5)
	collision_mask = 0
	_build()
	add_to_group("interactable") # é um inventário: dá para abrir sempre
	if Net.i.taken.has(key):
		_set_open(false)
	Net.i.looted.connect(_on_looted)


func get_interact_text() -> String:
	return "[E] Abrir %s" % _title().to_lower()


func _title() -> String:
	return {"bau": "Baú", "armario": "Armário", "caixote": "Caixote"}[style]


func interact(player: Node) -> void:
	ContainerUI.open_for(player, key, table, _title())


func _on_looted(k: String) -> void:
	if k == key and not _opened:
		_set_open(true)


func _set_open(animate: bool) -> void:
	_opened = true
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
	# Tinta forte (destaca no meio das casas cinza/marrons): baú vermelho,
	# armário azul-turquesa, caixote amarelo.
	var wood: Color = {"bau": Color(0.8, 0.16, 0.1), "armario": Color(0.1, 0.58, 0.6), "caixote": Color(0.95, 0.66, 0.1)}[style]
	var dark := wood.darkened(0.4)
	var hinge := Vector3.ZERO
	match style:
		"bau": # baú de tábuas com cintas rebitadas, cantoneiras, alças e fecho de latão
			body.color(wood)
			body.box(Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.55))
			body.color(wood.darkened(0.2))
			for k in 3:
				body.box(Vector3(0, 0.12 + k * 0.14, 0.277), Vector3(0.88, 0.008, 0.004)) # frestas
			body.color(ItemModels.IRON)
			for x in [-0.32, 0.32]:
				body.box(Vector3(x, 0.25, 0), Vector3(0.05, 0.52, 0.57))
				for y in [0.08, 0.25, 0.42]:
					body.color(ItemModels.BRASS)
					body.box(Vector3(x, y, 0.288), Vector3(0.014, 0.014, 0.006))
					body.color(ItemModels.IRON)
			for x in [-0.45, 0.45]:
				for z in [-0.27, 0.27]:
					body.box(Vector3(x, 0.25, z), Vector3(0.04, 0.52, 0.04))
				body.tube(PackedVector3Array([Vector3(x * 1.04, 0.33, -0.07), Vector3(x * 1.1, 0.27, 0.0), Vector3(x * 1.04, 0.33, 0.07)]), 0.012, 4)
			hinge = Vector3(0, 0.5, -0.275)
			for k in 5: # tampa arredondada em ripas
				var t := lerpf(0.0, PI, k / 4.0)
				lid.color(wood.darkened(0.04 * (k % 2) + 0.06))
				lid.box(Vector3(0, 0.02 + sin(t) * 0.14, 0.275 - cos(t) * 0.26), Vector3(0.9, 0.035, 0.13), Basis(Vector3.RIGHT, -t + PI / 2))
			lid.color(ItemModels.IRON)
			for x in [-0.32, 0.32]:
				lid.lathe(PackedVector2Array([Vector2(0.28, -0.025), Vector2(0.28, 0.025)]), 8, Basis(Vector3.BACK, PI / 2), Vector3(x, 0.02, 0.275))
			lid.color(ItemModels.BRASS)
			lid.box(Vector3(0, 0.02, 0.56), Vector3(0.09, 0.12, 0.03))
			lid.color(Color(0.08, 0.06, 0.05))
			lid.box(Vector3(0, 0.0, 0.577), Vector3(0.015, 0.03, 0.004))
			_shape(Vector3(0, 0.33, 0), Vector3(0.9, 0.66, 0.55))
		"armario": # armário alto: moldura, rodapé, prateleiras dentro e porta almofadada
			body.color(dark)
			body.box(Vector3(0, 0.9, -0.02), Vector3(0.8, 1.8, 0.46))
			body.color(wood)
			body.box(Vector3(0, 1.84, 0), Vector3(0.88, 0.08, 0.52)) # cornija
			body.box(Vector3(0, 0.05, 0), Vector3(0.86, 0.1, 0.5)) # rodapé
			body.color(dark.darkened(0.3))
			for y in [0.45, 0.9, 1.35]:
				body.box(Vector3(0, y, 0.0), Vector3(0.72, 0.03, 0.4)) # prateleiras (aparecem com a porta aberta)
			body.color(Color(0.62, 0.55, 0.42))
			body.box(Vector3(-0.15, 1.0, 0.0), Vector3(0.2, 0.17, 0.25)) # caixa guardada
			hinge = Vector3(-0.39, 0.0, 0.23)
			lid.color(wood)
			lid.box(Vector3(0.39, 0.9, 0.0), Vector3(0.78, 1.7, 0.04))
			lid.color(wood.darkened(0.15))
			for y in [0.5, 1.25]:
				lid.box(Vector3(0.39, y, 0.022), Vector3(0.6, 0.6, 0.01)) # almofadas
			lid.color(ItemModels.BRASS)
			lid.box(Vector3(0.7, 0.95, 0.05), Vector3(0.03, 0.12, 0.03))
			for y in [0.3, 1.5]:
				lid.box(Vector3(0.0, y, 0.0), Vector3(0.02, 0.1, 0.05)) # dobradiças
			_shape(Vector3(0, 0.92, 0), Vector3(0.88, 1.84, 0.52))
		"caixote": # caixote de ripas com frestas, travessas em X e tampa pregada
			body.color(dark)
			for x in [-0.33, 0.33]:
				for z in [-0.33, 0.33]:
					body.box(Vector3(x, 0.3, z), Vector3(0.06, 0.6, 0.06))
			for k in 4:
				body.color(wood.lightened(0.08 - 0.04 * (k % 2)))
				var y := 0.08 + k * 0.145
				for z in [-0.34, 0.34]:
					body.box(Vector3(0, y, z), Vector3(0.7, 0.12, 0.03))
				for x in [-0.34, 0.34]:
					body.box(Vector3(x, y, 0), Vector3(0.03, 0.12, 0.7))
			body.color(dark)
			for z in [-0.36, 0.36]:
				body.box(Vector3(0, 0.3, z), Vector3(0.05, 0.75, 0.02), Basis(Vector3.BACK, 0.72))
			body.color(Color(0.75, 0.68, 0.5)) # palha dentro
			body.box(Vector3(0, 0.5, 0), Vector3(0.62, 0.06, 0.62))
			body.color(Color(0.1, 0.1, 0.1))
			body.box(Vector3(0, 0.35, 0.356), Vector3(0.3, 0.08, 0.002)) # carimbo
			hinge = Vector3(0, 0.6, 0)
			for k in 4:
				lid.color(wood.lightened(0.04 * (k % 2)))
				lid.box(Vector3(0, 0.025, -0.27 + k * 0.18), Vector3(0.72, 0.05, 0.16))
			lid.color(dark)
			lid.box(Vector3(0, 0.055, 0), Vector3(0.06, 0.01, 0.72))
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
