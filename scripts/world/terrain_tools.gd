class_name TerrainTools
extends RefCounted
## Cavar e construir com o chão (grade de 0,4 m do TerrainWorld).
##
## - Pá ou picareta: o golpe que pega no chão (sem zumbi/árvore/pedra no caminho)
##   tira um bloco da coluna mirada. Terra e areia saem com a pá num golpe; pedra
##   precisa da picareta (com a pá são 3 golpes). Bloco posto pelo jogador volta
##   inteiro (pedra devolve as 2 pedras).
## - Terra, areia ou pedra na mão + clique no chão: põe um bloco de 0,4 m na coluna
##   mirada (em cima da pilha). É construção: zumbi quebra (terra 3 golpes, pedra 8).
## - Um cubo de arame mostra o bloco que vai sair (vermelho) ou entrar (verde).

const REACH := 3.4
const NO_COL := Vector2i(-2147483647, 0)

static var _cursor: MeshInstance3D
static var _cursor_mat: StandardMaterial3D
static var _progress := {} # coluna -> golpes de pá em pedra


## O que a mira pega no chão: {"dig": coluna a cavar, "place": coluna onde pôr,
## "point", "normal"} ou {} (mirando nada, longe, zumbi, construção, árvore...).
static func aim(player: Player) -> Dictionary:
	var terrain := TerrainWorld.i
	if terrain == null or player.camera == null:
		return {}
	var from := player.camera.global_position
	var forward := -player.camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * REACH, Player.MASK_AIM, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and VoxelWorld.i and VoxelWorld.is_voxel_body(hit.collider):
		return _aim_voxel(hit, forward)
	if hit.is_empty() or not TerrainWorld.is_ground(hit.collider):
		return {}
	var body := hit.collider as CollisionObject3D
	if body.shape_owner_get_owner(body.shape_find_owner(hit.shape)) != body.get_node_or_null("GroundShape"):
		return {} # tronco/pedra do cenário (colisão no mesmo corpo do chunk)
	var point: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	# Cavar: bloco posto perto (a mira pega na rampa ao lado da pilha) ou a coluna do ponto.
	var dig := terrain.built_near(point - normal * 0.05, forward)
	if not TerrainWorld.is_column(dig):
		var inside := point - normal * 0.05
		dig = TerrainWorld.column_at(inside.x, inside.z)
	# Pôr: do lado de onde se olha (na encosta da pilha vai para a coluna de fora).
	var out := point + Vector3(normal.x, 0.0, normal.z) * 0.15
	var place := TerrainWorld.column_at(out.x, out.z)
	return {"dig": dig, "place": place, "point": point, "normal": normal}


## Mira no chão de voxel: o bloco cheio logo atrás da superfície (cavar) e o vazio logo na
## frente dela (pôr), em 3D (dá para cavar de lado e para cima).
static func _aim_voxel(hit: Dictionary, forward: Vector3) -> Dictionary:
	var vw := VoxelWorld.i
	var point: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var dig := VoxelWorld.NO_BLOCK
	for depth in [0.1, 0.3, 0.5, 0.7]:
		for dir in [-normal, forward]:
			var b := VoxelWorld.block_of(point + (dir as Vector3) * depth)
			if vw.material_at(b) > VoxelRef.AIR:
				dig = b
				break
		if dig != VoxelWorld.NO_BLOCK:
			break
	var place := VoxelWorld.NO_BLOCK
	for dist in [0.15, 0.35, 0.55]:
		var b := VoxelWorld.block_of(point + normal * dist)
		if vw.material_at(b) == VoxelRef.AIR:
			place = b
			break
	return {"voxel": true, "dig": dig, "place": place, "point": point, "normal": normal}


static func is_block_item(id: StringName) -> bool:
	if VoxelWorld.i and VoxelWorld.ITEM_BLOCK.has(id):
		return true # terra, pedra, areia e tábua viram blocos (voxels)
	return TerrainWorld.ITEM_MAT.has(id)


static func is_dig_tool(player: Player) -> bool:
	return player._weapon_type in [Player.WeaponType.SHOVEL, Player.WeaponType.PICKAXE]


## Golpe de pá/picareta que não pegou em nada: cava o bloco mirado. true = cavou.
static func dig(player: Player) -> bool:
	var terrain := TerrainWorld.i
	var target := aim(player)
	if terrain == null or target.is_empty():
		return false
	if target.get("voxel", false):
		return _dig_voxel(player, target)
	var col: Vector2i = target.dig
	var mat := terrain.dig_result(col)
	if mat == TerrainWorld.Mat.NATURAL:
		Sfx.play_at("knock", target.point, 0.0, 0.5) # fundo demais: rocha que não sai
		return false
	var built := terrain.built_count(col) > 0
	# Pedra com a pá: 3 golpes; terra/areia com a picareta: 2.
	var need := 1
	if mat == TerrainWorld.Mat.STONE and player._weapon_type == Player.WeaponType.SHOVEL:
		need = 3
	elif mat != TerrainWorld.Mat.STONE and player._weapon_type == Player.WeaponType.PICKAXE:
		need = 2
	var done: int = int(_progress.get(col, 0)) + 1
	if done < need:
		_progress = {col: done}
		Sfx.play_at("knock" if mat == TerrainWorld.Mat.STONE else "step_soft", target.point, 2.0, 0.7)
		return true
	_progress.clear()
	terrain.request_dig(col)
	var item: StringName = TerrainWorld.MAT_ITEM[mat]
	var amount: int = TerrainWorld.MAT_COST[mat] if built else 1
	player.pick_up(item, ItemDB.display_name(item), amount)
	_dust(player, target.point, TerrainWorld.MAT_COLORS.get(mat, Color(0.4, 0.3, 0.2)))
	return true


## Cava um bloco de voxel: terra/areia com a pá num golpe; pedra com a pá 3 golpes e com a
## picareta 1; minério só com a picareta. Bloco posto devolve o que custou.
static func _dig_voxel(player: Player, target: Dictionary) -> bool:
	var vw := VoxelWorld.i
	var b: Vector3i = target.dig
	var res := vw.dig_result(b) if b != VoxelWorld.NO_BLOCK else {}
	if res.is_empty():
		Sfx.play_at("knock", target.point, 0.0, 0.5) # rocha-mãe: não sai
		return false
	var shovel := player._weapon_type == Player.WeaponType.SHOVEL
	if res.ore and shovel:
		Sfx.play_at("knock", target.point, 0.0, 0.6) # minério: só a picareta tira
		return true
	var need := 1
	if res.deposit:
		need = VoxelWorld.DEPOSIT_HITS # jazida: rocha dura, mas não acaba
	elif res.hard and shovel:
		need = 3
	elif not res.hard and not shovel:
		need = 2
	var done: int = int(_progress.get(b, 0)) + 1
	if done < need:
		_progress = {b: done}
		Sfx.play_at("knock" if res.hard else "step_soft", target.point, 2.0, 0.7)
		return true
	_progress.clear()
	if res.deposit:
		# Jazida infinita: sai 1 minério e o bloco fica (a perfuratriz tira sozinha).
		player.pick_up(res.item, ItemDB.display_name(res.item), 1)
		Progress.event("deposit", String(res.item))
		_dust(player, target.point, VoxelRef.COLORS.get(res.material, Color(0.5, 0.5, 0.5)))
		Sfx.play_at("knock", target.point, 2.0, 0.9)
		return true
	# Picareta e pá tiram uma esfera de 3x3x3 (19 blocos); cada bloco dá o seu item.
	var drops := {}
	for t: Vector3i in vw.sphere_targets(b, shovel):
		var r := vw.dig_result(t)
		if not r.is_empty():
			drops[r.item] = int(drops.get(r.item, 0)) + int(r.amount)
	vw.request_dig_sphere(b, shovel)
	for item: StringName in drops:
		player.pick_up(item, ItemDB.display_name(item), drops[item])
	var color: Color = VoxelRef.COLORS.get(res.material, Color(0.4, 0.3, 0.2))
	_dust(player, target.point, color)
	_dust(player, target.point + Vector3.UP * 0.3, color)
	return true


## Terra/areia/pedra na mão + clique no chão: põe um bloco. true = pôs (ou tentou:
## o clique não vira soco).
static func place(player: Player) -> bool:
	var terrain := TerrainWorld.i
	var id := player.inventory.selected_id()
	var target := aim(player)
	if terrain == null or target.is_empty() or not is_block_item(id):
		return false
	if target.get("voxel", false):
		return _start_mass(player, target, id)
	if not TerrainWorld.ITEM_MAT.has(id):
		return false # tábua só vira bloco no chão de voxels
	var col: Vector2i = target.place
	var mat: int = TerrainWorld.ITEM_MAT[id]
	var cost: int = TerrainWorld.MAT_COST[mat]
	if not terrain.can_place(col) or _blocked(player, col):
		Sfx.play("click", -6.0, 0.6)
		return true
	# Começa pela pilha da mão (Builder.pay tira da primeira que achar).
	if not Builder.can_afford(player.inventory, {id: cost}):
		Sfx.play("click", -6.0, 0.6)
		return true
	if not Cheats.creative:
		var got: int = player.inventory.take(player.inventory.selected, cost).get("amount", 0)
		if got < cost:
			Builder.pay(player.inventory, {id: cost - got})
	terrain.request_place(col, mat)
	_dust(player, target.point, TerrainWorld.MAT_COLORS[mat])
	return true


# --- Pôr em massa (como a talhadeira): segura o clique num bloco, arrasta e solta ---------

static var _mass := {} ## {"start", "end": Vector3i, "id": item na mão}


## Clique com bloco na mão: marca o primeiro bloco; o resto vem arrastando (update_cursor).
static func _start_mass(player: Player, target: Dictionary, id: StringName) -> bool:
	var b: Vector3i = target.place
	if b == VoxelWorld.NO_BLOCK:
		Sfx.play("click", -6.0, 0.6)
		return true
	_mass = {"start": b, "end": b, "id": id}
	if not Input.is_action_pressed("attack"):
		_finish_mass(player) # chamado sem o botão (script/teste): põe já
	return true


## Caixa entre o começo e o fim, no máximo MASS_MAX_SIDE por lado.
static func _mass_box() -> Array:
	var a: Vector3i = _mass.start
	var e: Vector3i = _mass.end
	var lim := VoxelWorld.MASS_MAX_SIDE - 1
	e = Vector3i(clampi(e.x, a.x - lim, a.x + lim), clampi(e.y, a.y - lim, a.y + lim), clampi(e.z, a.z - lim, a.z + lim))
	return [Vector3i(mini(a.x, e.x), mini(a.y, e.y), mini(a.z, e.z)), Vector3i(maxi(a.x, e.x), maxi(a.y, e.y), maxi(a.z, e.z))]


## Soltou o clique: põe os blocos vazios da caixa (os mais perto do começo primeiro), até
## acabar o material ou MASS_MAX.
static func _finish_mass(player: Player) -> void:
	var vw := VoxelWorld.i
	var id: StringName = _mass.id
	var start: Vector3i = _mass.start
	var box := _mass_box()
	_mass = {}
	if vw == null or player.inventory.selected_id() != id:
		return
	var mat: int = VoxelWorld.ITEM_BLOCK[id]
	var cost: int = VoxelWorld.BLOCK_COST[mat]
	var list := []
	for y in range(box[0].y, box[1].y + 1):
		for z in range(box[0].z, box[1].z + 1):
			for x in range(box[0].x, box[1].x + 1):
				var b := Vector3i(x, y, z)
				if vw.material_at(b) == VoxelRef.AIR and not _blocked_3d(player, b):
					list.append(b)
	list.sort_custom(func(p, q): return (p - start).length_squared() < (q - start).length_squared())
	var can := VoxelWorld.MASS_MAX if Cheats.creative else mini(player.inventory.count(id) / cost, VoxelWorld.MASS_MAX)
	list = list.slice(0, can)
	if list.is_empty():
		Sfx.play("click", -6.0, 0.6)
		return
	if not Cheats.creative:
		var need: int = list.size() * cost
		var got: int = player.inventory.take(player.inventory.selected, need).get("amount", 0)
		if got < need:
			Builder.pay(player.inventory, {id: need - got})
	vw.request_place_many(list[0], mat, list)
	_dust(player, VoxelWorld.block_center(list[0]), VoxelRef.COLORS.get(mat, Color(0.4, 0.3, 0.2)))


static func _place_voxel(player: Player, target: Dictionary, id: StringName) -> bool:
	var vw := VoxelWorld.i
	var b: Vector3i = target.place
	var mat: int = VoxelWorld.ITEM_BLOCK[id]
	var cost: int = VoxelWorld.BLOCK_COST[mat]
	if b == VoxelWorld.NO_BLOCK or vw.material_at(b) != VoxelRef.AIR or _blocked_3d(player, b):
		Sfx.play("click", -6.0, 0.6)
		return true
	if not Builder.can_afford(player.inventory, {id: cost}):
		Sfx.play("click", -6.0, 0.6)
		return true
	if not Cheats.creative:
		var got: int = player.inventory.take(player.inventory.selected, cost).get("amount", 0)
		if got < cost:
			Builder.pay(player.inventory, {id: cost - got})
	vw.request_place(b, mat)
	_dust(player, target.point, VoxelRef.COLORS.get(mat, Color(0.4, 0.3, 0.2)))
	return true


## Alguém (jogador, outro jogador, zumbi) ocupa o bloco: ficaria preso dentro dele.
static func _blocked_3d(player: Player, b: Vector3i) -> bool:
	var c := VoxelWorld.block_center(b)
	for body in player.get_tree().get_nodes_in_group("player") + player.get_tree().get_nodes_in_group("remote_player") \
			+ player.get_tree().get_nodes_in_group("enemy"):
		if body is Node3D:
			var p: Vector3 = body.global_position
			if Vector2(p.x - c.x, p.z - c.z).length() < 0.6 and c.y > p.y - 0.3 and c.y < p.y + 2.0:
				return true
	return false


## Jogador (ou outro jogador/zumbi) em pé na coluna: o bloco o empurraria para dentro do chão.
static func _blocked(player: Player, col: Vector2i) -> bool:
	var center := (Vector2(col) + Vector2(0.5, 0.5)) * TerrainWorld.GRID
	for body in player.get_tree().get_nodes_in_group("player") + player.get_tree().get_nodes_in_group("remote_player") \
			+ player.get_tree().get_nodes_in_group("enemy"):
		if body is Node3D and Vector2(body.global_position.x, body.global_position.z).distance_to(center) < 0.55:
			if absf(body.global_position.y - TerrainWorld.i.column_top(col)) < 1.0:
				return true
	return false


## Poeirinha do bloco saindo/entrando.
static func _dust(player: Player, at: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 10
	p.lifetime = 0.6
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -7, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.05
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	p.mesh = mesh
	player.get_parent().add_child(p)
	p.global_position = at + Vector3.UP * 0.05
	p.emitting = true
	p.finished.connect(p.queue_free)


## Cubo de arame no bloco mirado (pá/picareta: o que sai; terra/pedra na mão: onde entra).
static func update_cursor(player: Player) -> void:
	var id := player.inventory.selected_id() if player.inventory else &""
	var mode := ""
	if is_dig_tool(player) and player._equip >= 1.0:
		mode = "dig"
	elif is_block_item(id):
		mode = "place"
	var target := aim(player) if mode != "" and not player.ui_blocked and player.vehicle == null else {}
	if not _mass.is_empty():
		# Arrastando com bloco na mão: a caixa vai do começo até o bloco mirado.
		if id != _mass.id or player.ui_blocked:
			_mass = {}
		elif Input.is_action_pressed("attack"):
			if target.get("voxel", false) and target.place != VoxelWorld.NO_BLOCK:
				_mass.end = target.place
			_show_mass(player)
			return
		else:
			_finish_mass(player)
	if target.is_empty():
		if is_instance_valid(_cursor):
			_cursor.visible = false
		return
	if not is_instance_valid(_cursor):
		_cursor = MeshInstance3D.new()
		_cursor.name = "BlockCursor"
		_cursor.mesh = _wire_box()
		_cursor_mat = StandardMaterial3D.new()
		_cursor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cursor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cursor_mat.no_depth_test = false
		_cursor.material_override = _cursor_mat
		_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		player.get_parent().add_child(_cursor)
	var terrain := TerrainWorld.i
	if target.get("voxel", false):
		var b: Vector3i = target.dig if mode == "dig" else target.place
		if b == VoxelWorld.NO_BLOCK:
			_cursor.visible = false
			return
		_cursor.global_position = VoxelWorld.block_center(b)
		# Cavando: a caixa mostra a esfera de 3x3x3 (construção mirada: só o bloco).
		var whole := mode == "dig" and not VoxelWorld.is_built(VoxelWorld.i.material_at(b))
		_cursor.scale = Vector3.ONE * (3.0 if whole else 1.0)
		var ok_v := not VoxelWorld.i.dig_result(b).is_empty() if mode == "dig" else VoxelWorld.i.material_at(b) == VoxelRef.AIR
		_cursor_mat.albedo_color = (Color(1.0, 0.45, 0.3, 0.9) if mode == "dig" else Color(0.5, 1.0, 0.45, 0.9)) if ok_v else Color(0.6, 0.6, 0.6, 0.5)
		_cursor.visible = true
		return
	_cursor.scale = Vector3.ONE
	var col: Vector2i = target.dig if mode == "dig" else target.place
	var top := terrain.column_top(col)
	var y := top - TerrainWorld.GRID * 0.5 if mode == "dig" else top + TerrainWorld.GRID * 0.5
	_cursor.global_position = Vector3((col.x + 0.5) * TerrainWorld.GRID, y, (col.y + 0.5) * TerrainWorld.GRID)
	var ok := terrain.dig_result(col) != TerrainWorld.Mat.NATURAL if mode == "dig" else terrain.can_place(col)
	_cursor_mat.albedo_color = (Color(1.0, 0.45, 0.3, 0.9) if mode == "dig" else Color(0.5, 1.0, 0.45, 0.9)) if ok else Color(0.6, 0.6, 0.6, 0.5)
	_cursor.visible = true


static func _show_mass(player: Player) -> void:
	if not is_instance_valid(_cursor):
		return
	var box := _mass_box()
	var lo := VoxelWorld.block_center(box[0])
	var hi := VoxelWorld.block_center(box[1])
	_cursor.global_position = (lo + hi) * 0.5
	_cursor.scale = Vector3(box[1] - box[0]) + Vector3.ONE
	var count: int = (box[1].x - box[0].x + 1) * (box[1].y - box[0].y + 1) * (box[1].z - box[0].z + 1)
	var cost: int = VoxelWorld.BLOCK_COST[VoxelWorld.ITEM_BLOCK[_mass.id]]
	var enough := Cheats.creative or player.inventory.count(_mass.id) >= count * cost
	_cursor_mat.albedo_color = Color(0.5, 1.0, 0.45, 0.9) if enough else Color(1.0, 0.8, 0.3, 0.9) # amarelo: falta material
	_cursor.visible = true


## Arestas de um cubo de 0,4 m (linhas).
static func _wire_box() -> ArrayMesh:
	var h := TerrainWorld.GRID * 0.5 + 0.005
	var c := []
	for k in 8:
		c.append(Vector3(h if k & 1 else -h, h if k & 2 else -h, h if k & 4 else -h))
	var lines := PackedVector3Array()
	for pair in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		lines.append(c[pair[0]])
		lines.append(c[pair[1]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lines
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh
