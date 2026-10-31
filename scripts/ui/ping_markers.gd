class_name PingMarkers
extends Node3D
## Marcadores de ping (botão do meio do mouse ou B): todos os jogadores veem um
## losango por cima de tudo (atravessa paredes), com nome, o que foi marcado e
## a distância. Também aparecem no mapa/minimapa. Somem em LIFETIME segundos.

const LIFETIME := 12.0
const COLORS := {"zumbi": Color(1.0, 0.25, 0.2), "item": Color(0.4, 0.9, 1.0), "carro": Color(0.6, 1.0, 0.4), "aqui": Color(1.0, 0.85, 0.2)}
const TEXT := {"zumbi": "Zumbi!", "item": "Item", "carro": "Carro", "aqui": "Aqui"}

static var i: PingMarkers

var list: Array = [] ## [{pos, from, kind, time, node, label}]


func _enter_tree() -> void:
	i = self


func _exit_tree() -> void:
	if i == self:
		i = null


## Jogador local marcando onde mira (até 300 m).
static func ping_from(player: Player) -> void:
	var cam := player.camera
	var query := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 300.0,
			1 | (1 << 2) | (1 << 4) | (1 << 5), [player.get_rid()])
	query.collide_with_areas = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	if collider.has_meta("enemy"):
		collider = collider.get_meta("enemy")
	var kind := "aqui"
	if collider is Zombie or (collider is Node and collider.get_parent() is Zombie):
		kind = "zumbi"
	elif collider is PickupItem or collider is LootBox:
		kind = "item"
	elif collider is VintageCar:
		kind = "carro"
	Net.i.send_ping(hit.position, kind)


func add(pos: Vector3, from: String, kind: String) -> void:
	var color: Color = COLORS.get(kind, COLORS.aqui)
	var node := Node3D.new()
	add_child(node)
	node.global_position = pos + Vector3.UP * 0.6
	var diamond := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.35
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.albedo_color = color
	material.fixed_size = true
	material.render_priority = 10
	mesh.material = material
	diamond.mesh = mesh
	diamond.scale = Vector3.ONE * 0.06
	diamond.rotation = Vector3(PI / 4, 0, PI / 4)
	diamond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(diamond)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.font_size = 22
	label.outline_size = 6
	label.modulate = color
	label.position = Vector3(0, 0.03, 0)
	label.render_priority = 11
	node.add_child(label)
	list.append({"pos": pos, "from": from, "kind": kind, "time": LIFETIME, "node": node, "label": label})
	Sfx.play_at("ping", pos, 6.0, 1.3)
	Sfx.play("ping", -8.0, 1.5) # ouve mesmo longe
	if Chat.i:
		Chat.i.add_line("", "%s marcou: %s" % [from, TEXT.get(kind, "Aqui")])


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	for entry in list.duplicate():
		entry.time -= delta
		if entry.time <= 0.0:
			entry.node.queue_free()
			list.erase(entry)
			continue
		var distance: float = cam.global_position.distance_to(entry.pos) if cam else 0.0
		entry.label.text = "%s\n%s  %dm" % [entry.from, TEXT.get(entry.kind, "Aqui"), distance]
		var fade := clampf(entry.time / 1.5, 0.0, 1.0)
		entry.label.modulate.a = fade
		entry.node.get_child(0).rotation.y += delta * 2.0
