class_name PowerTool
extends Node3D
## Peças de força na mão (filho do jogador):
##   eixo         segure o clique no começo (porta de latão, tripé, ponta de eixo ou o
##                chão: na grade de 0,4 m) e solte no fim. Só anda nas direções da grade
##                (±X, ±Y, ±Z) em passos de 0,4 m: curvas só de 90°. Mirando uma porta,
##                tripé ou ponta alinhada, termina nela. Cada 2 m gasta 1 eixo (até 8 m).
##                Ponta solta no ar vira tripé (o host põe).
##   engrenagem / engrenagem grande / polia: clique num eixo (monta no ponto mirado,
##                de 0,2 em 0,2 m), num tripé ou numa porta de máquina.
##   esteira      clique numa polia (ou máquina) e depois na outra ponta.
##   cabo         clique numa peça elétrica e depois na outra (até 12 m; 1 cabo a cada 4 m):
##                o fio aparece pendurado até a mira antes de ligar.
## Fantasma: verde = cabe, vermelho = não dá; bolinha amarela = ponta encaixada,
## cinza = ali nasce um tripé. A primeira ponta da esteira fica marcada.

const REACH := 7.0
const MASK := 1 | (1 << 5)
const AXLE_HEIGHT := 0.6 ## começando no chão: altura do eixo (= altura das portas)

var player: Player
var _start := Vector3.INF
var _start_snapped := false
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _tips: Array[MeshInstance3D] = []
var _belt_from: PlacedObject
var _belt_mark: MeshInstance3D
var _cable_ghost: MeshInstance3D
var _cable_mat: StandardMaterial3D


func _ready() -> void:
	top_level = true
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rod := CylinderMesh.new()
	rod.top_radius = 0.06
	rod.bottom_radius = 0.06
	rod.height = 1.0
	rod.radial_segments = 8
	_ghost = MeshInstance3D.new()
	_ghost.mesh = rod
	_ghost.material_override = _ghost_mat
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.top_level = true
	_ghost.visible = false
	add_child(_ghost)
	for k in 2:
		_tips.append(_ball(0.08))
	_belt_mark = _ball(0.1)
	(_belt_mark.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.6, 0.15)
	_cable_mat = StandardMaterial3D.new()
	_cable_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cable_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cable_ghost = MeshInstance3D.new()
	_cable_ghost.material_override = _cable_mat
	_cable_ghost.top_level = true
	_cable_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cable_ghost.visible = false
	add_child(_cable_ghost)


func _ball(radius: float) -> MeshInstance3D:
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.radial_segments = 8
	ball.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	var node := MeshInstance3D.new()
	node.mesh = ball
	node.material_override = mat
	node.top_level = true
	node.visible = false
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _placed() -> PlacedManager:
	return player.get_parent().get_node_or_null("Placed") as PlacedManager


static func handles(item: StringName) -> bool:
	return item == PowerParts.AXLE_ITEM or item == &"correia" or item == Electric.CABLE_ITEM or PowerParts.mount_kind(item) != ""


## Clique com a peça na mão.
func press() -> void:
	var placed := _placed()
	if placed == null:
		return
	var item := player.inventory.selected_id()
	if item == PowerParts.AXLE_ITEM:
		var aim := _aim(placed, Vector3.INF)
		if aim.is_empty():
			Sfx.play("click", -6.0, 0.6)
			return
		_start = aim.point
		_start_snapped = aim.snapped
		Sfx.play_at("knock", _start, -8.0, 1.6)
	elif item == &"correia":
		_belt_click(placed)
	elif item == Electric.CABLE_ITEM:
		_cable_click(placed)
	else:
		_mount_click(placed, PowerParts.mount_kind(item))


func cancel() -> void:
	_start = Vector3.INF
	_ghost.visible = false
	for tip in _tips:
		tip.visible = false


func _process(_delta: float) -> void:
	if player == null:
		return
	var item := player.inventory.selected_id()
	var usable := not player.ui_blocked and player.vehicle == null
	var wired := item == Electric.CABLE_ITEM
	if (item != &"correia" and not wired) or not usable:
		_belt_from = null
	if is_instance_valid(_belt_from) and Electric.has(_belt_from.kind) != wired:
		_belt_from = null # trocou de esteira para cabo (ou o contrário)
	_belt_mark.visible = is_instance_valid(_belt_from)
	if _belt_mark.visible:
		_belt_mark.global_position = Electric.terminal(_belt_from) if wired else Power.belt_anchor(_belt_from)[0]
	_show_cable(wired and _belt_mark.visible)
	_show_mount(item, usable)
	if item != PowerParts.AXLE_ITEM or not usable:
		cancel()
		return
	var placed := _placed()
	if placed == null:
		return
	if _start == Vector3.INF:
		var aim := _aim(placed, Vector3.INF)
		_tips[0].visible = not aim.is_empty()
		if _tips[0].visible:
			_tips[0].global_position = aim.point
			_tip_color(_tips[0], aim.snapped)
		_tips[1].visible = false
		_ghost.visible = false
		return
	var plan := _plan(placed)
	_show(plan)
	if not Input.is_action_pressed("attack"):
		_finish(placed, plan)


func _tip_color(tip: MeshInstance3D, snapped: bool) -> void:
	(tip.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.85, 0.2) if snapped else Color(0.75, 0.75, 0.75)


func _ray() -> Dictionary:
	var origin := player.camera.global_position
	var forward := -player.camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * REACH, MASK, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(query)


## Onde a mira cai: {"point", "snapped"} (encaixe em porta/tripé/ponta tem prioridade).
## Com o começo já marcado, sem encaixe, o ponto fica no nível do começo.
func _aim(placed: PlacedManager, from: Vector3) -> Dictionary:
	var origin := player.camera.global_position
	var forward := -player.camera.global_basis.z
	var hit := _ray()
	if hit:
		var snap := Power.snap_point(placed.objects, hit.position, 0.45)
		if snap != Vector3.INF and snap.distance_to(from) > 0.1:
			return {"point": snap, "snapped": true}
	if from == Vector3.INF:
		if hit.is_empty():
			return {}
		var p: Vector3 = hit.position
		if hit.normal.y > 0.6:
			return {"point": GridSnap.flat(p) + Vector3.UP * AXLE_HEIGHT, "snapped": false} # no chão: na altura das portas
		return {"point": GridSnap.on_surface(p, hit.normal) + hit.normal * 0.15, "snapped": false}
	# Arrastando: cruza o raio da mira com o plano do nível do começo.
	var point: Vector3
	if absf(forward.y) > 0.02:
		var t := (from.y - origin.y) / forward.y
		point = origin + forward * t if t > 0.0 and t < REACH * 2.0 else origin + forward * REACH
	else:
		point = origin + forward * REACH
	if hit and origin.distance_to(hit.position) < origin.distance_to(point):
		point = hit.position # parede/objeto no caminho
	point.y = from.y
	return {"point": point, "snapped": false}


## Trecho que sairia agora: {"a", "b", "len", "valid", "snapped"}.
func _plan(placed: PlacedManager) -> Dictionary:
	var aim := _aim(placed, _start)
	if aim.is_empty():
		return {}
	var end: Vector3 = aim.point
	var snapped: bool = aim.snapped and GridSnap.on_axis(_start, end) and _start.distance_to(end) <= PowerParts.MAX_AXLE
	if not snapped:
		# Na direção da grade mais perto da mira, em passos de 0,4 m.
		var seg := GridSnap.segment(_start, player.camera.global_position, -player.camera.global_basis.z, PowerParts.MAX_AXLE)
		if seg.is_empty():
			return {}
		end = seg.end
		var snap := Power.snap_point(placed.objects, end, 0.3)
		if snap != Vector3.INF and snap.distance_to(_start) > 0.1 and GridSnap.on_axis(_start, snap):
			end = snap # porta/tripé/ponta logo ali na mesma linha
			snapped = true
	var length := _start.distance_to(end)
	var valid := length >= 0.3 and player.inventory.count(PowerParts.AXLE_ITEM) >= PowerParts.axle_cost(length)
	return {"a": _start, "b": end, "len": length, "valid": valid, "snapped": snapped}


func _show(plan: Dictionary) -> void:
	if plan.is_empty() or plan.len < 0.01:
		_ghost.visible = false
		return
	var a: Vector3 = plan.a
	var b: Vector3 = plan.b
	var dir := (b - a).normalized()
	_ghost.visible = true
	_ghost.global_transform = Transform3D(PipeTool._basis_y_to(dir).scaled(Vector3(1.0, plan.len, 1.0)), (a + b) * 0.5)
	_ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.45) if plan.valid else Color(1.0, 0.25, 0.2, 0.45)
	_tips[0].visible = true
	_tips[0].global_position = a
	_tip_color(_tips[0], _start_snapped)
	_tips[1].visible = true
	_tips[1].global_position = b
	_tip_color(_tips[1], plan.snapped)


func _finish(placed: PlacedManager, plan: Dictionary) -> void:
	_start = Vector3.INF
	_ghost.visible = false
	if plan.is_empty() or not plan.valid:
		Sfx.play("click", -6.0, 0.6)
		return
	var dir: Vector3 = (plan.b - plan.a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
	var basis := Basis.looking_at(-dir, up) # +Z local aponta para o fim do eixo
	_take(PowerParts.AXLE_ITEM, PowerParts.axle_cost(plan.len))
	placed.request("axle", [Transform3D(basis, plan.a), plan.len])


func _take(item: StringName, amount: int) -> void:
	var left := amount
	while left > 0:
		var index := Cooking.find_any(player.inventory, {item: true})
		if index < 0:
			break
		left -= player.inventory.take(index, left).get("amount", left)


# --- Engrenagem / polia ---------------------------------------------------------------

## Onde a peça montaria: {"point", "axis"} ou {}.
func mount_target(placed: PlacedManager) -> Dictionary:
	var hit := _ray()
	if hit.is_empty() or not hit.collider is PlacedObject:
		return {}
	var obj: PlacedObject = hit.collider
	match obj.kind:
		"axle":
			var dir := obj.global_basis.z.normalized()
			var length: float = obj.extra.get("len", 1.0)
			var raw := clampf((hit.position - obj.global_position).dot(dir), 0.0, length)
			var t := clampf(snappedf(raw, 0.2), 0.0, length)
			# Engrenagem: se dá para engatar numa que já existe ali perto, encaixa no ponto certo.
			var kind := PowerParts.mount_kind(player.inventory.selected_id())
			if Power.COG_RADIUS.has(kind):
				var spot := Power.mesh_spot(placed.objects, obj.global_position, dir, length, Power.COG_RADIUS[kind], raw)
				if not spot.is_empty():
					return {"point": obj.global_position + dir * spot[0], "axis": dir, "meshes": true}
			return {"point": obj.global_position + dir * t, "axis": dir}
		"tripod":
			var axis := Vector3.RIGHT
			for value in placed.objects.values():
				if is_instance_valid(value) and value.kind == "axle":
					for p: Vector3 in Power.axle_ends(value):
						if p.distance_to(obj.global_position) < Power.SNAP:
							axis = value.global_basis.z.normalized()
			return {"point": obj.global_position, "axis": axis}
	if Power.is_power(obj.kind) and Power.PORTS.has(obj.kind):
		var best := {}
		var best_d := 1.2
		for port in Power.world_ports(obj):
			var d: float = port[0].distance_to(hit.position)
			if d < best_d:
				best_d = d
				best = {"point": port[0], "axis": port[1].normalized()}
		return best
	return {}


## Fantasma do disco da engrenagem/polia onde vai montar (verde = engata noutra engrenagem).
var _disc: MeshInstance3D
func _show_mount(item: StringName, usable: bool) -> void:
	var kind := PowerParts.mount_kind(item)
	var target := mount_target(_placed()) if usable and kind != "" and _placed() else {}
	if target.is_empty():
		if _disc:
			_disc.visible = false
		return
	if _disc == null:
		_disc = MeshInstance3D.new()
		_disc.material_override = _ghost_mat.duplicate()
		_disc.top_level = true
		_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_disc)
	var r: float = Power.COG_RADIUS.get(kind, Power.PULLEY_RADIUS)
	var cyl := _disc.mesh as CylinderMesh
	if cyl == null or not is_equal_approx(cyl.top_radius, r):
		cyl = CylinderMesh.new()
		cyl.top_radius = r
		cyl.bottom_radius = r
		cyl.height = 0.1
		cyl.radial_segments = 16
		_disc.mesh = cyl
	_disc.visible = true
	_disc.global_transform = Transform3D(PipeTool._basis_y_to(target.axis), target.point)
	(_disc.material_override as StandardMaterial3D).albedo_color = Color(0.3, 1.0, 0.4, 0.5) if target.get("meshes", false) else Color(1.0, 1.0, 1.0, 0.35)


func _mount_click(placed: PlacedManager, kind: String) -> void:
	var target := mount_target(placed)
	if target.is_empty():
		Sfx.play("click", -6.0, 0.6)
		return
	var axis: Vector3 = target.axis
	var up := Vector3.UP if absf(axis.y) < 0.98 else Vector3.FORWARD
	var basis := Basis.looking_at(-axis, up) # +Z local = eixo de giro
	_take(PowerParts.ITEMS[kind], 1)
	placed.request("mount", [kind, Transform3D(basis, target.point)])


# --- Esteira --------------------------------------------------------------------------

## Cabo: primeiro clique marca a peça, o segundo liga (o host confere a distância).
func _cable_click(placed: PlacedManager) -> void:
	var hit := _ray()
	var target: PlacedObject = hit.collider as PlacedObject if hit and hit.collider is PlacedObject else null
	if target == null or not Electric.has(target.kind):
		Sfx.play("click", -6.0, 0.6)
		return
	if not is_instance_valid(_belt_from) or _belt_from == target:
		_belt_from = target if _belt_from != target else null
		Sfx.play_at("knock", Electric.terminal(target), -4.0, 1.7)
		return
	if not Electric.cable_ok(_belt_from, target):
		Sfx.play("click", -6.0, 0.6) # longe demais
		return
	var cost := Electric.cable_cost(Electric.terminal(_belt_from).distance_to(Electric.terminal(target)))
	if player.inventory.count(Electric.CABLE_ITEM) < cost and not Electric.linked(_belt_from, target):
		Sfx.play("click", -6.0, 0.6) # não tem cabo que chegue
		return
	_take(Electric.CABLE_ITEM, mini(cost, player.inventory.count(Electric.CABLE_ITEM)))
	placed.request("cable", [_belt_from.net_id, target.net_id])
	_belt_from = null


## Fio de prévia pendurado do primeiro borne até a mira (verde = alcança).
func _show_cable(show: bool) -> void:
	_cable_ghost.visible = show
	if not show:
		return
	var a := Electric.terminal(_belt_from)
	var hit := _ray()
	var b: Vector3 = hit.position if hit else a
	if hit and hit.collider is PlacedObject and Electric.has(hit.collider.kind):
		b = Electric.terminal(hit.collider)
	var ok := a.distance_to(b) <= Electric.CABLE_RANGE
	_cable_mat.albedo_color = Color(0.4, 1.0, 0.45, 0.7) if ok else Color(1.0, 0.3, 0.25, 0.7)
	var mb := MeshBuilder.new()
	mb.tube(Electric.catenary(a, b), 0.012, 4)
	_cable_ghost.mesh = mb.finish(null, false)


func _belt_click(placed: PlacedManager) -> void:
	var hit := _ray()
	var target: PlacedObject = hit.collider as PlacedObject if hit and hit.collider is PlacedObject else null
	if target == null or not (target.kind == "pulley" or Power.is_machine(target.kind)):
		Sfx.play("click", -6.0, 0.6)
		return
	if not is_instance_valid(_belt_from) or _belt_from == target:
		_belt_from = target if _belt_from != target else null # primeira ponta (clicar de novo desmarca)
		Sfx.play_at("knock", hit.position, -4.0, 1.4)
		return
	if not Power.belt_ok(_belt_from, target):
		Sfx.play("click", -6.0, 0.6) # longe, não paralelas, ou nenhuma é polia
		return
	_take(&"correia", 1)
	placed.request("belt", [_belt_from.net_id, target.net_id])
	Sfx.play_at("slap", hit.position, -2.0, 0.8)
	_belt_from = null
