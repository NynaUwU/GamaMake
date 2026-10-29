class_name ItemDB
## Catálogo de itens: nome, tipo, quanto empilha e o modelo usado no chão
## (e na mão dos zumbis). Para criar um item novo, adicione uma entrada aqui.
##
## kind: "weapon" (equipa ao selecionar na hotbar), "tool" (funciona estando
## no inventário, ex.: lanterna) ou "material" (para crafting no futuro).

## Campos da janela de informação (hover no inventário): damage_type, damage,
## knockback e desc. Os números são os valores padrão das armas no Player.
const ITEMS := {
	&"espada": {"name": "Espada", "kind": "weapon", "weapon": "sword", "stack": 1, "size": Vector3(0.2, 0.05, 1.0),
		"damage_type": "Corte", "damage": 34, "knockback": 30,
		"desc": "Afiada o bastante para cortar braços. E pão. Principalmente braços."},
	&"taco": {"name": "Taco", "kind": "weapon", "weapon": "bat", "stack": 1, "size": Vector3(0.1, 0.1, 0.9),
		"damage_type": "Impacto", "damage": 24, "knockback": 58,
		"desc": "Feito para beisebol. Ninguém mais lembra as regras do beisebol."},
	&"cajado": {"name": "Cajado", "kind": "weapon", "weapon": "staff", "stack": 1, "size": Vector3(0.12, 0.12, 1.2),
		"damage_type": "Explosão", "damage": 70, "knockback": 450,
		"desc": "Dispara mísseis mágicos. Ler o manual antes era opcional."},
	&"pistola": {"name": "Pistola", "kind": "weapon", "weapon": "pistol", "stack": 1, "size": Vector3(0.05, 0.15, 0.22),
		"damage_type": "Perfuração", "damage": 40, "knockback": 20,
		"desc": "12 balas e munição infinita. A física da munição pediu demissão."},
	&"lanterna": {"name": "Lanterna", "kind": "tool", "stack": 1, "size": Vector3(0.08, 0.08, 0.24),
		"desc": "Aperte L. Zumbis adoram uma luz na cara, igual mariposa com fome."},
	&"sucata": {"name": "Sucata", "kind": "material", "stack": 10, "size": Vector3(0.3, 0.12, 0.2),
		"desc": "Metal velho. Um dia vai virar algo incrível. Hoje é só sucata."},
	&"pano": {"name": "Pano", "kind": "material", "stack": 10, "size": Vector3(0.3, 0.05, 0.25),
		"desc": "Cheira estranho. Não pergunte de onde veio."},
	&"fita": {"name": "Fita adesiva", "kind": "material", "stack": 10, "size": Vector3(0.14, 0.06, 0.14),
		"desc": "Conserta tudo, menos o fim do mundo. Ainda."},
}

## Armas que zumbis podem carregar (só corpo a corpo).
const ZOMBIE_WEAPONS := [&"taco", &"espada"]


static func has(id: StringName) -> bool:
	return ITEMS.has(id)


static func def(id: StringName) -> Dictionary:
	return ITEMS.get(id, {"name": String(id), "kind": "material", "stack": 10, "size": Vector3(0.2, 0.2, 0.2)})


static func display_name(id: StringName) -> String:
	return def(id).name


static func description(id: StringName) -> String:
	return def(id).get("desc", "")


static func weapon_of(id: StringName) -> String:
	return def(id).get("weapon", "")


static func max_stack(id: StringName) -> int:
	return def(id).stack


## Modelo 3D do item, montado ao longo de -Z (como as armas na mão do player).
static func make_mesh(id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	match id:
		&"espada":
			_box(root, Vector3(0.06, 0.012, 0.82), Vector3(0, 0, -0.47), Color(0.5, 0.5, 0.53), 0.6)
			_box(root, Vector3(0.2, 0.035, 0.035), Vector3(0, 0, -0.05), Color(0.35, 0.28, 0.15))
			_box(root, Vector3(0.04, 0.04, 0.18), Vector3(0, 0, 0.04), Color(0.12, 0.12, 0.12))
		&"taco":
			_cylinder(root, 0.05, 0.022, 0.86, Vector3(0, 0, -0.43), Color(0.72, 0.55, 0.34))
		&"cajado":
			_cylinder(root, 0.022, 0.028, 1.1, Vector3(0, 0, -0.5), Color(0.32, 0.2, 0.12))
			var orb := _box(root, Vector3(0.1, 0.1, 0.1), Vector3(0, 0, -1.05), Color(0.8, 0.55, 1.0))
			_glow(orb, Color(0.6, 0.25, 1.0))
		&"pistola":
			_box(root, Vector3(0.036, 0.04, 0.2), Vector3(0, 0.035, -0.06), Color(0.13, 0.13, 0.14), 0.7)
			_box(root, Vector3(0.032, 0.11, 0.05), Vector3(0, -0.04, 0.02), Color(0.22, 0.16, 0.12))
		&"lanterna":
			_cylinder(root, 0.035, 0.03, 0.22, Vector3(0, 0, -0.11), Color(0.1, 0.1, 0.1))
			var lens := _box(root, Vector3(0.06, 0.06, 0.01), Vector3(0, 0, -0.225), Color(1.0, 0.95, 0.7))
			_glow(lens, Color(1.0, 0.9, 0.6))
		_:
			var colors := {&"sucata": Color(0.5, 0.48, 0.45), &"pano": Color(0.7, 0.68, 0.6), &"fita": Color(0.6, 0.6, 0.62)}
			_box(root, def(id).size, Vector3.ZERO, colors.get(id, Color(0.55, 0.5, 0.35)))
	return root


## Centro da caixa de colisão do item no chão.
static func shape_center(id: StringName) -> Vector3:
	if def(id).kind in ["weapon", "tool"] and id != &"pistola":
		return Vector3(0, 0, -def(id).size.z * 0.5 + 0.05)
	return Vector3.ZERO


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metallic := 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = _material(color, metallic)
	parent.add_child(mesh)
	return mesh


static func _cylinder(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = 8
	cylinder.rings = 1
	mesh.mesh = cylinder
	mesh.position = pos
	mesh.rotation = Vector3(-PI / 2, 0, 0) # cilindro deitado ao longo de -Z
	mesh.material_override = _material(color, 0.0)
	parent.add_child(mesh)


static func _glow(mesh: MeshInstance3D, color: Color) -> void:
	var material: StandardMaterial3D = mesh.material_override
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5


static func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.6 if metallic > 0.0 else 0.85
	return material
