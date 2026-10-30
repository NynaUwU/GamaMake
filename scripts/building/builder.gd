class_name Builder
extends Node
## Ferramentas de construção na mão do player (só o jogador local tem).
##
## Martelo: mostra a peça "fantasma" na grade (verde = cabe, vermelho = já tem
## peça ali). Clique constrói, botão direito troca a peça (parede, piso, teto,
## pilar), R gira a parede, Shift + clique desmonta a peça mirada.
## Encaixes: parede mirando um piso/teto vai para a borda mais perto dele;
## mirando o topo de uma parede empilha; piso/teto mirando a borda de outro
## piso vai para o lado; teto mirando o topo de uma parede cobre o cômodo.
##
## Talhadeira: realça o triângulo mirado; clique tira ele (buracos de janela).

const REACH := 7.0
const MASK := 1

var player: Player
var kind := BuildPiece.Kind.WALL
var flip := false ## R: gira a parede (o padrão é ficar de frente para quem constrói)
var target := {} ## onde o martelo vai construir {kind, cell, rot, valid}
var cut_target := {} ## {piece, triangle}

var _ghost: Node3D
var _ghost_mesh: MeshInstance3D
var _ghost_material: StandardMaterial3D
var _highlight: MeshInstance3D
var _highlight_mesh := ImmediateMesh.new()


func _ready() -> void:
	_ghost = Node3D.new()
	_ghost.top_level = true
	add_child(_ghost)
	_ghost_mesh = MeshInstance3D.new()
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_mesh.material_override = _ghost_material
	_ghost_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.add_child(_ghost_mesh)
	_highlight = MeshInstance3D.new()
	_highlight.top_level = true
	_highlight.mesh = _highlight_mesh
	var mark := StandardMaterial3D.new()
	mark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mark.albedo_color = Color(1.0, 0.85, 0.2, 0.55)
	mark.cull_mode = BaseMaterial3D.CULL_DISABLED
	_highlight.material_override = mark
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight)
	_set_ghost_shape()


func _manager() -> BuildingManager:
	return player.get_parent().get_node_or_null("Building") as BuildingManager


func tool_name() -> String:
	return "%s%s" % [BuildPiece.NAMES[kind], "  (girada)" if flip and kind == BuildPiece.Kind.WALL else ""]


## Chamado todo frame pelo player com a ferramenta da mão ("hammer", "chisel" ou "").
func update(tool: String) -> void:
	target = {}
	cut_target = {}
	_ghost.visible = false
	_highlight.visible = false
	if _manager() == null or player.vehicle != null:
		return
	if tool == "hammer":
		var shift := Input.is_key_pressed(KEY_SHIFT)
		if shift:
			var hit := _ray()
			if hit and hit.collider is BuildPiece:
				_show_piece_outline(hit.collider)
			return
		target = _compute_target()
		if target.is_empty():
			return
		_ghost.visible = true
		_ghost.global_transform = BuildPiece.piece_transform(target.kind, target.cell, target.rot)
		_ghost_material.albedo_color = Color(0.3, 1.0, 0.4, 0.35) if target.valid else Color(1.0, 0.25, 0.2, 0.35)
	elif tool == "chisel":
		var hit := _ray()
		if hit.is_empty() or not hit.collider is BuildPiece:
			return
		var piece: BuildPiece = hit.collider
		var triangle := piece.triangle_at(hit.position, hit.normal)
		if triangle < 0:
			return
		cut_target = {"piece": piece, "triangle": triangle}
		_draw_triangle(piece, triangle)


## Clique com o martelo (constrói ou, com Shift, desmonta) ou com a talhadeira (tira um triângulo).
func use(tool: String) -> bool:
	var manager := _manager()
	if manager == null:
		return false
	if tool == "hammer":
		if Input.is_key_pressed(KEY_SHIFT):
			var hit := _ray()
			if hit and hit.collider is BuildPiece:
				manager.request_remove(hit.collider)
				return true
			return false
		if not target.is_empty() and target.valid:
			manager.request_place(target.kind, target.cell, target.rot)
			return true
	elif tool == "chisel" and not cut_target.is_empty():
		manager.request_cut(cut_target.piece, cut_target.triangle)
		return true
	return false


func cycle() -> void:
	kind = ((kind + 1) % 4) as BuildPiece.Kind
	_set_ghost_shape()


func rotate() -> void:
	flip = not flip


# --- Onde construir ---------------------------------------------------------------

func _ray() -> Dictionary:
	var cam := player.camera
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * REACH, MASK, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	# As peças colidem dos dois lados: a normal pode vir invertida. Vira para quem mira.
	if hit and hit.normal.dot(dir) > 0.0:
		hit.normal = -hit.normal
	return hit


func _compute_target() -> Dictionary:
	var hit := _ray()
	if hit.is_empty():
		return {}
	var p: Vector3 = hit.position + hit.normal * 0.02
	var piece := hit.collider as BuildPiece
	var on_top: bool = hit.normal.y > 0.7
	# Mirando a quina de cima de uma parede/pilar também conta como "em cima".
	if piece and piece.kind in [BuildPiece.Kind.WALL, BuildPiece.Kind.PILLAR] \
			and piece.to_local(hit.position).y > BuildPiece.SIZE - 0.35:
		on_top = true
	var seg := BuildPiece.SEG
	var n := BuildPiece.N
	var forward := -player.camera.global_basis.z
	var cell := Vector3i.ZERO
	var rot := 0
	var me := player.global_position
	match kind:
		BuildPiece.Kind.WALL:
			# De frente para quem constrói (R gira 90°).
			rot = 1 if absf(forward.x) > absf(forward.z) else 0
			if flip:
				rot = 1 - rot
			if piece and on_top and piece.kind == BuildPiece.Kind.WALL:
				cell = piece.cell + Vector3i(0, n, 0) # empilha
				rot = piece.rot
			elif piece and on_top and piece.kind in [BuildPiece.Kind.FLOOR, BuildPiece.Kind.ROOF]:
				# Na borda mais perto do piso/teto mirado.
				var o := piece.cell
				var y := o.y # no teto a base afunda um pouco na laje (o topo dele não cai na grade)
				if rot == 0:
					var z := o.z if absf(p.z - o.z * seg) < absf(p.z - (o.z + n) * seg) else o.z + n
					cell = Vector3i(o.x, y, z)
				else:
					var x := o.x if absf(p.x - o.x * seg) < absf(p.x - (o.x + n) * seg) else o.x + n
					cell = Vector3i(x, y, o.z)
			else:
				var y := roundi(p.y / seg)
				if rot == 0:
					cell = Vector3i(roundi(p.x / seg) - n / 2, y, roundi(p.z / seg))
				else:
					cell = Vector3i(roundi(p.x / seg), y, roundi(p.z / seg) - n / 2)
		BuildPiece.Kind.FLOOR, BuildPiece.Kind.ROOF:
			if piece and on_top and piece.kind == kind:
				# Perto da borda de outro piso/teto igual: vai para o lado dele.
				var o := piece.cell
				var lu := p.x / seg - o.x
				var lv := p.z / seg - o.z
				var edges := [lu, n - lu, lv, n - lv]
				var best: int = edges.find(edges.min())
				var offsets := [Vector3i(-n, 0, 0), Vector3i(n, 0, 0), Vector3i(0, 0, -n), Vector3i(0, 0, n)]
				cell = o + offsets[best]
			elif piece and on_top and piece.kind == BuildPiece.Kind.WALL:
				# Em cima de uma parede: cobre o lado onde o jogador está.
				var o := piece.cell
				var y := o.y + n
				if piece.rot == 0:
					cell = Vector3i(o.x, y, o.z - n if me.z < o.z * seg else o.z)
				else:
					cell = Vector3i(o.x - n if me.x < o.x * seg else o.x, y, o.z)
			else:
				cell = Vector3i(roundi(p.x / seg) - n / 2, roundi(p.y / seg), roundi(p.z / seg) - n / 2)
		BuildPiece.Kind.PILLAR:
			if piece and on_top and piece.kind in [BuildPiece.Kind.WALL, BuildPiece.Kind.PILLAR]:
				cell = Vector3i(roundi(p.x / seg), piece.cell.y + n, roundi(p.z / seg))
			else:
				cell = Vector3i(roundi(p.x / seg), roundi(p.y / seg), roundi(p.z / seg))
	if kind != BuildPiece.Kind.WALL:
		rot = 0
	return {"kind": kind, "cell": cell, "rot": rot, "valid": _manager().can_place(kind, cell, rot)}


# --- Visual ---------------------------------------------------------------------

func _set_ghost_shape() -> void:
	var box := BoxMesh.new()
	var size := BuildPiece.SIZE
	var t := BuildPiece.THICK
	match kind:
		BuildPiece.Kind.WALL:
			box.size = Vector3(size, size, t)
			_ghost_mesh.position = Vector3(size * 0.5, size * 0.5, 0)
		BuildPiece.Kind.FLOOR:
			box.size = Vector3(size, t, size)
			_ghost_mesh.position = Vector3(size * 0.5, -t * 0.5, size * 0.5)
		BuildPiece.Kind.ROOF:
			box.size = Vector3(size, t, size)
			_ghost_mesh.position = Vector3(size * 0.5, t * 0.5, size * 0.5)
		BuildPiece.Kind.PILLAR:
			box.size = Vector3(BuildPiece.SEG, size, BuildPiece.SEG)
			_ghost_mesh.position = Vector3(0, size * 0.5, 0)
	_ghost_mesh.mesh = box


## Triângulo mirado pela talhadeira, nas duas faces (um pouco para fora).
func _draw_triangle(piece: BuildPiece, triangle: int) -> void:
	var c := BuildPiece.triangle_uv(triangle)
	var w := Vector2(-BuildPiece.THICK * 0.5, BuildPiece.THICK * 0.5) if piece.kind == BuildPiece.Kind.WALL \
			else Vector2(0.0, BuildPiece.THICK)
	_highlight_mesh.clear_surfaces()
	_highlight_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Só na face virada para quem mira.
	var eye := piece.to_local(player.camera.global_position)
	var eye_w := eye.z if piece.kind == BuildPiece.Kind.WALL else eye.y + (BuildPiece.THICK if piece.kind == BuildPiece.Kind.FLOOR else 0.0)
	for depth in [w.y + 0.01 if eye_w > (w.x + w.y) * 0.5 else w.x - 0.01]:
		# Um pouco menor que o triângulo, para dar para ver a borda.
		var center := (c[0] + c[1] + c[2]) / 3.0
		for k in 3:
			var corner: Vector2 = center.lerp(c[k], 0.9)
			_highlight_mesh.surface_add_vertex(piece.uvw(corner.x, corner.y, depth))
	_highlight_mesh.surface_end()
	_highlight.global_transform = piece.global_transform
	_highlight.visible = true


## Shift com o martelo: a peça que vai ser desmontada fica vermelha (fantasma em cima dela).
func _show_piece_outline(piece: BuildPiece) -> void:
	var previous := kind
	kind = piece.kind
	_set_ghost_shape()
	kind = previous
	_ghost.visible = true
	_ghost.global_transform = piece.global_transform
	_ghost_mesh.scale = Vector3.ONE * 1.01
	_ghost_material.albedo_color = Color(1.0, 0.2, 0.15, 0.4)
	call_deferred("_set_ghost_shape")
