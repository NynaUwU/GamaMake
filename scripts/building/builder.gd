class_name Builder
extends Node
## Ferramentas de construção na mão do player (só o jogador local tem).
##
## Martelo: mostra a peça "fantasma" na grade (verde = cabe, vermelho = já tem
## peça ali). Clique constrói, R gira a parede, Shift + clique desmonta a peça
## (ou tira a janela/porta) mirada. SEGURAR o botão direito abre o menu de
## construção (abas + lista com rolagem): solte em cima do item para escolher.
## Encaixes: parede mirando um piso/teto vai para a borda mais perto dele;
## mirando o topo de uma parede empilha; piso/teto mirando a borda de outro
## piso vai para o lado; teto mirando o topo de uma parede cobre o cômodo.
## Janela/Porta: mire um buraco feito pela talhadeira; ela preenche o buraco
## inteiro (qualquer formato). A porta precisa de um buraco que encoste na base
## da parede.
##
## Talhadeira: clique tira o meio quadrado mirado (triângulo); R troca a
## diagonal do corte ("/" ou "\\"). Clique e ARRASTE seleciona uma área
## (retângulo de quadrados) e tira tudo ao soltar.

const REACH := 7.0
const MASK := 1
const ENTRIES := {
	"Estrutura": [
		{"id": "wall", "name": "Parede", "kind": BuildPiece.Kind.WALL, "desc": "2,8 x 2,8 m; R gira"},
		{"id": "floor", "name": "Piso", "kind": BuildPiece.Kind.FLOOR, "desc": "Topo na altura da grade"},
		{"id": "roof", "name": "Teto", "kind": BuildPiece.Kind.ROOF, "desc": "Apoia no topo das paredes"},
		{"id": "pillar", "name": "Pilar", "kind": BuildPiece.Kind.PILLAR, "desc": "0,4 m de lado, 2,8 m de altura"},
	],
	"Aberturas": [
		{"id": "window", "name": "Janela", "fill": "window", "desc": "Preenche um buraco feito pela talhadeira"},
		{"id": "door", "name": "Porta", "fill": "door", "desc": "Buraco que encoste no chão; [E] abre"},
	],
	"Outros": [],
}

var player: Player
var selection: Dictionary = ENTRIES["Estrutura"][0]
var kind := BuildPiece.Kind.WALL
var flip := false ## R: gira a parede (o padrão é ficar de frente para quem constrói)
var target := {} ## onde o martelo vai construir {kind, cell, rot, valid}
var fill_target := {} ## buraco mirado para janela/porta {piece, tris, valid}
var cut_target := {} ## {piece, quarters}: meio quadrado mirado pela talhadeira
var cut_selection := PackedInt32Array() ## partes (quartos) da área arrastada
var diag := "/" ## diagonal do corte da talhadeira (R troca)

var _ghost: Node3D
var _ghost_mesh: MeshInstance3D
var _ghost_material: StandardMaterial3D
var _highlight: MeshInstance3D
var _highlight_mesh := ImmediateMesh.new()
var _mark: StandardMaterial3D
var _drag := {} # talhadeira arrastando: {piece, square, triangle}
var _menu: BuildMenu


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
	_mark = StandardMaterial3D.new()
	_mark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark.albedo_color = Color(1.0, 0.85, 0.2, 0.55)
	_mark.cull_mode = BaseMaterial3D.CULL_DISABLED
	_highlight.material_override = _mark
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight)
	_menu = BuildMenu.new()
	_menu.builder = self
	add_child(_menu)
	_set_ghost_shape()


## Modelo para a foto do menu (a peça em si; janela/porta numa parede com o buraco).
static func preview_model(entry: Dictionary) -> Node3D:
	var piece := BuildPiece.new()
	if entry.has("kind"):
		piece.setup(entry.kind, Vector3i.ZERO, 0)
		return piece
	piece.setup(BuildPiece.Kind.WALL, Vector3i.ZERO, 0)
	var parts := PackedInt32Array()
	var rows := range(0, 5) if entry.fill == "door" else range(2, 5)
	for j in rows:
		for i in range(2, 5):
			for q in 4:
				parts.append((j * BuildPiece.N + i) * 4 + q)
	for t in parts:
		piece.removed[t] = 1
	piece.add_fill(entry.fill, parts)
	return piece


func _manager() -> BuildingManager:
	return player.get_parent().get_node_or_null("Building") as BuildingManager


func tool_name() -> String:
	return "%s%s" % [selection.name, "  (girada)" if flip and selection.get("kind", -1) == BuildPiece.Kind.WALL else ""]


func select(entry: Dictionary) -> void:
	selection = entry
	if entry.has("kind"):
		kind = entry.kind
		_set_ghost_shape()
	player._emit_weapon_text()


func open_menu() -> void:
	_menu.open()


func menu_open() -> bool:
	return _menu.visible


func rotate() -> void:
	flip = not flip


func toggle_diagonal() -> void:
	diag = "\\" if diag == "/" else "/"


## Chamado todo frame pelo player com a ferramenta da mão ("hammer", "chisel" ou "").
func update(tool: String) -> void:
	target = {}
	fill_target = {}
	cut_target = {}
	_ghost.visible = false
	_highlight.visible = false
	if tool != "chisel":
		_drag = {}
	if _manager() == null or player.vehicle != null or _menu.visible:
		return
	if tool == "hammer":
		if Input.is_key_pressed(KEY_SHIFT):
			var hit := _ray()
			if hit and (hit.collider is BuildPiece or hit.collider is BuildFill):
				_show_removal(hit.collider)
			return
		if selection.has("fill"):
			fill_target = _compute_hole()
			if not fill_target.is_empty():
				var color := Color(0.4, 0.7, 1.0, 0.5) if selection.fill == "window" else Color(0.8, 0.5, 0.25, 0.6)
				_draw_triangles(fill_target.piece, fill_target.tris, color if fill_target.valid else Color(1, 0.2, 0.15, 0.5))
			return
		target = _compute_target()
		if target.is_empty():
			return
		_ghost.visible = true
		_ghost.global_transform = BuildPiece.piece_transform(target.kind, target.cell, target.rot)
		_ghost_material.albedo_color = Color(0.3, 1.0, 0.4, 0.35) if target.valid else Color(1.0, 0.25, 0.2, 0.35)
	elif tool == "chisel":
		if not _drag.is_empty():
			_update_drag()
			return
		var hit := _ray()
		if hit.is_empty() or not hit.collider is BuildPiece:
			return
		var piece: BuildPiece = hit.collider
		var half := piece.half_at(hit.position, hit.normal, diag)
		if half.is_empty():
			return
		cut_target = {"piece": piece, "quarters": half}
		_draw_triangles(piece, half, Color(1.0, 0.85, 0.2, 0.55))


## Clique com o martelo (constrói, encaixa janela/porta ou, com Shift, desmonta)
## ou com a talhadeira (começa a selecionar). Devolve true se fez algo.
func use(tool: String) -> bool:
	var manager := _manager()
	if manager == null or _menu.visible:
		return false
	if tool == "hammer":
		if Input.is_key_pressed(KEY_SHIFT):
			var hit := _ray()
			if hit and hit.collider is BuildFill:
				manager.request_unfill(hit.collider.piece, hit.collider.fill_index)
				return true
			if hit and hit.collider is BuildPiece:
				manager.request_remove(hit.collider)
				return true
			return false
		if selection.has("fill"):
			if not fill_target.is_empty() and fill_target.valid:
				manager.request_fill(fill_target.piece, selection.fill, fill_target.tris)
				return true
			return false
		if not target.is_empty() and target.valid:
			manager.request_place(target.kind, target.cell, target.rot)
			return true
	elif tool == "chisel" and not cut_target.is_empty():
		var piece: BuildPiece = cut_target.piece
		var square: int = cut_target.quarters[0] / 4
		_drag = {"piece": piece, "quarters": cut_target.quarters, "square": Vector2i(square % BuildPiece.N, square / BuildPiece.N)}
		cut_selection = cut_target.quarters
		return true
	return false


# --- Talhadeira: seleção de área ---------------------------------------------------

func _update_drag() -> void:
	var piece: BuildPiece = _drag.piece
	if not is_instance_valid(piece):
		_drag = {}
		return
	var here: Dictionary = piece.ray_to_panel(_ray_from(), _ray_to())
	if not here.is_empty():
		var a: Vector2i = _drag.square
		var b: Vector2i = here.square
		cut_selection = PackedInt32Array()
		if a == b:
			cut_selection = _drag.quarters # mesmo quadrado: só o meio quadrado do clique
		else:
			for j in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				for i in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
					for q in 4:
						var t := (j * BuildPiece.N + i) * 4 + q
						if piece.removed[t] == 0:
							cut_selection.append(t)
	_draw_triangles(piece, cut_selection, Color(1.0, 0.55, 0.15, 0.55))
	if not Input.is_action_pressed("attack"):
		# Soltou: tira tudo o que estava selecionado.
		var manager := _manager()
		if manager and not cut_selection.is_empty():
			manager.request_cut_many(piece, cut_selection)
		_drag = {}
		cut_selection = PackedInt32Array()


# --- Janela / porta ------------------------------------------------------------------

## Buraco mirado: onde a mira atravessa o plano de uma peça num triângulo tirado.
func _compute_hole() -> Dictionary:
	var manager := _manager()
	var from := _ray_from()
	var to := _ray_to()
	var hit := _ray()
	var limit: float = from.distance_to(hit.position) + 0.05 if hit else REACH
	var best := {}
	var best_t := INF
	for piece: BuildPiece in manager.pieces.values():
		if not piece.has_panel() or piece.global_position.distance_to(from) > REACH + BuildPiece.SIZE * 1.5:
			continue
		var res: Dictionary = piece.ray_to_panel(from, to)
		if res.is_empty() or res.t * REACH > limit or res.t >= best_t:
			continue
		if piece.removed[res.triangle] == 0 or piece.filled(res.triangle):
			continue
		best_t = res.t
		best = {"piece": piece, "triangle": res.triangle}
	if best.is_empty():
		return {}
	var tris: PackedInt32Array = best.piece.hole_at(best.triangle)
	var valid := not tris.is_empty()
	if selection.fill == "door":
		valid = valid and best.piece.kind == BuildPiece.Kind.WALL and BuildPiece.touches_bottom(tris)
	return {"piece": best.piece, "tris": tris, "valid": valid}


# --- Onde construir ---------------------------------------------------------------

func _ray_from() -> Vector3:
	return player.camera.global_position


func _ray_to() -> Vector3:
	return player.camera.global_position - player.camera.global_basis.z * REACH


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
	_ghost_mesh.scale = Vector3.ONE
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


## Triângulos realçados na face virada para quem mira (um pouco para fora dela).
func _draw_triangles(piece: BuildPiece, tris: PackedInt32Array, color: Color) -> void:
	var w := Vector2(-BuildPiece.THICK * 0.5, BuildPiece.THICK * 0.5) if piece.kind == BuildPiece.Kind.WALL 			else Vector2(0.0, BuildPiece.THICK)
	var eye := piece.to_local(player.camera.global_position)
	var eye_w := eye.z if piece.kind == BuildPiece.Kind.WALL else eye.y + (BuildPiece.THICK if piece.kind == BuildPiece.Kind.FLOOR else 0.0)
	var depth := w.y + 0.01 if eye_w > (w.x + w.y) * 0.5 else w.x - 0.01
	_highlight_mesh.clear_surfaces()
	if tris.is_empty():
		return
	_highlight_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in tris:
		var c := BuildPiece.triangle_uv(index)
		var center := (c[0] + c[1] + c[2]) / 3.0
		for k in 3:
			var corner: Vector2 = center.lerp(c[k], 0.92) # um pouco menor: dá para ver cada triângulo
			_highlight_mesh.surface_add_vertex(piece.uvw(corner.x, corner.y, depth))
	_highlight_mesh.surface_end()
	_mark.albedo_color = color
	_highlight.global_transform = piece.global_transform
	_highlight.visible = true


## Shift com o martelo: o que vai ser desmontado fica vermelho.
func _show_removal(node: Node) -> void:
	if node is BuildFill:
		var fill: BuildFill = node
		_draw_triangles(fill.piece, fill.piece.fills[fill.fill_index].tris, Color(1, 0.2, 0.15, 0.55))
		return
	var piece: BuildPiece = node
	var previous := kind
	kind = piece.kind
	_set_ghost_shape()
	kind = previous
	_ghost.visible = true
	_ghost.global_transform = piece.global_transform
	_ghost_mesh.scale = Vector3.ONE * 1.01
	_ghost_material.albedo_color = Color(1.0, 0.2, 0.15, 0.4)
	call_deferred("_set_ghost_shape")
