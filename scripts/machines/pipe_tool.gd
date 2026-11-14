class_name PipeTool
extends Node3D
## Cano na mão: segure o clique numa saída de latão (ou na ponta de um cano, ou
## em qualquer superfície: o começo cai na grade de 0,4 m), arraste e solte. O cano só
## anda nas direções da grade (±X, ±Y, ±Z), em passos de 0,4 m: curvas só de 90° (outro
## trecho saindo da ponta). Mirando uma porta alinhada, termina nela. Cada 2 m gasta 1 cano;
## o trecho vai até 6 m. Ponta solta no ar ganha um tripé (o host põe).
## Fantasma: verde = cabe, vermelho = curto/longo/sem cano; bolinha amarela =
## a ponta encaixou numa porta ou noutro cano.

const REACH := 7.0
const MASK := 1 | (1 << 5)

var player: Player
var _start := Vector3.INF
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _tip: MeshInstance3D
var _tip_mat: StandardMaterial3D


func _ready() -> void:
	top_level = true
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tube := CylinderMesh.new()
	tube.top_radius = 0.06
	tube.bottom_radius = 0.06
	tube.height = 1.0
	tube.radial_segments = 8
	_ghost = MeshInstance3D.new()
	_ghost.mesh = tube
	_ghost.material_override = _ghost_mat
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.top_level = true
	_ghost.visible = false
	add_child(_ghost)
	var ball := SphereMesh.new()
	ball.radius = 0.09
	ball.height = 0.18
	ball.radial_segments = 8
	ball.rings = 4
	_tip_mat = StandardMaterial3D.new()
	_tip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tip_mat.albedo_color = Color(1.0, 0.85, 0.2)
	_tip = MeshInstance3D.new()
	_tip.mesh = ball
	_tip.material_override = _tip_mat
	_tip.top_level = true
	_tip.visible = false
	add_child(_tip)


func _placed() -> PlacedManager:
	return player.get_parent().get_node_or_null("Placed") as PlacedManager


## Clique (com cano na mão): começa um trecho.
func press() -> void:
	var placed := _placed()
	if placed == null:
		return
	var aim := _aim(placed, Vector3.INF)
	if aim.is_empty():
		Sfx.play("click", -6.0, 0.6)
		return
	_start = aim.point
	Sfx.play_at("knock", _start, -8.0, 1.6)


func cancel() -> void:
	_start = Vector3.INF
	_ghost.visible = false
	_tip.visible = false


func _process(_delta: float) -> void:
	if player == null:
		return
	var holding := player.inventory.selected_id() == &"cano" and not player.ui_blocked and player.vehicle == null
	if not holding:
		cancel()
		return
	var placed := _placed()
	if placed == null:
		return
	if _start == Vector3.INF:
		# Só mirando: mostra onde encaixaria.
		var aim := _aim(placed, Vector3.INF)
		_tip.visible = not aim.is_empty() and aim.snapped
		if _tip.visible:
			_tip.global_position = aim.point
		_ghost.visible = false
		return
	var plan := _plan(placed)
	_show(plan)
	if not Input.is_action_pressed("attack"):
		_finish(placed, plan)


## Onde a mira cai: {"point", "snapped"} (encaixe em porta/ponta tem prioridade).
func _aim(placed: PlacedManager, from: Vector3) -> Dictionary:
	var origin := player.camera.global_position
	var forward := -player.camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * REACH, MASK, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3
	if hit.is_empty():
		if from == Vector3.INF:
			return {}
		point = origin + forward * minf(REACH, origin.distance_to(from) + 1.0)
	else:
		point = hit.position + hit.normal * 0.08 # um pouco fora da superfície
	var snap := Fluids.snap_point(placed.objects, point, 0.5)
	if snap != Vector3.INF and snap.distance_to(from) > 0.1:
		return {"point": snap, "snapped": true}
	if from == Vector3.INF and not hit.is_empty():
		point = GridSnap.on_surface(point, hit.normal) # começo solto: na grade
	return {"point": point, "snapped": false}


## Trecho que sairia agora: {"a", "b", "len", "valid", "snapped"}.
func _plan(placed: PlacedManager) -> Dictionary:
	var aim := _aim(placed, _start)
	if aim.is_empty():
		return {}
	var end: Vector3 = aim.point
	var snapped: bool = aim.snapped and GridSnap.on_axis(_start, end) and _start.distance_to(end) <= Fluids.MAX_PIPE
	if not snapped:
		# Na direção da grade mais perto da mira, em passos de 0,4 m.
		var seg := GridSnap.segment(_start, player.camera.global_position, -player.camera.global_basis.z, Fluids.MAX_PIPE)
		if seg.is_empty():
			return {}
		end = seg.end
		var snap := Fluids.snap_point(placed.objects, end, 0.3)
		if snap != Vector3.INF and snap.distance_to(_start) > 0.1 and GridSnap.on_axis(_start, snap):
			end = snap # porta/ponta logo ali na mesma linha
			snapped = true
	var length := _start.distance_to(end)
	var valid := length >= 0.25 and player.inventory.count(&"cano") >= Fluids.pipe_cost(length)
	return {"a": _start, "b": end, "len": length, "valid": valid, "snapped": snapped}


func _show(plan: Dictionary) -> void:
	if plan.is_empty() or plan.len < 0.01:
		_ghost.visible = false
		_tip.visible = false
		return
	var a: Vector3 = plan.a
	var b: Vector3 = plan.b
	var dir := (b - a).normalized()
	_ghost.visible = true
	_ghost.global_transform = Transform3D(_basis_y_to(dir).scaled(Vector3(1.0, plan.len, 1.0)), (a + b) * 0.5)
	_ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.45) if plan.valid else Color(1.0, 0.25, 0.2, 0.45)
	_tip.visible = plan.snapped
	_tip.global_position = b


func _finish(placed: PlacedManager, plan: Dictionary) -> void:
	_start = Vector3.INF
	_ghost.visible = false
	if plan.is_empty() or not plan.valid:
		Sfx.play("click", -6.0, 0.6)
		return
	var dir: Vector3 = (plan.b - plan.a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
	var basis := Basis.looking_at(-dir, up) # +Z local aponta para o fim do cano
	var cost := Fluids.pipe_cost(plan.len)
	var left := cost
	while left > 0:
		var index := Cooking.find_any(player.inventory, {&"cano": true})
		if index < 0:
			break
		left -= player.inventory.take(index, left).get("amount", left)
	placed.request("pipe", [Transform3D(basis, plan.a), plan.len])


static func _basis_y_to(dir: Vector3) -> Basis:
	if dir.is_equal_approx(Vector3.UP):
		return Basis.IDENTITY
	if dir.is_equal_approx(Vector3.DOWN):
		return Basis(Vector3.RIGHT, PI)
	return Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP.angle_to(dir))
