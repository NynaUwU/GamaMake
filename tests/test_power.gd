extends SceneTree
## Força rotacional estilo Create: roda d'água -> eixo -> moinho; ponta solta vira
## tripé e outro eixo continua dele; engrenagens engatadas (sentido invertido);
## polia no meio do eixo + esteira até a roca; sobrecarga para tudo; luz indicadora;
## save/load; ferramenta na mão (arrastar eixo, montar engrenagem).

var main: Node
var placed: PlacedManager
var player: Player
var terrain: TerrainWorld
var base := Vector3.ZERO


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	placed = main.get_node("Placed")
	player = main.player
	terrain = main.get_node("Terrain")
	main.get_node("ZombieSpawner").process_mode = Node.PROCESS_MODE_DISABLED
	for e in main.get_node("Enemies").get_children():
		e.free()
	base = player.global_position + Vector3(0, 0, -6)
	base.y = terrain.height_at(base.x, base.z)
	await _chain()
	quit()


func _spawn(kind: String, at: Vector3, basis := Basis()) -> PlacedObject:
	var id := placed._next_id
	placed._spawn(id, kind, Transform3D(basis, at))
	return placed.objects[id]


func _axle(a: Vector3, b: Vector3) -> Array:
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
	return placed.host_apply("axle", [Transform3D(Basis.looking_at(-dir, up), a), a.distance_to(b)])


func _tick(n := 1) -> void:
	for k in n:
		placed.clock += 1.0
		placed._power()


func _state(obj: PlacedObject) -> String:
	return "%s(%s, luz %s)" % [obj.kind, obj.extra.get("pstate", "-"), PowerParts.lamp_state(obj)]


func _chain() -> void:
	# Roda d'água (gera 4) e moinho a 4 m, porta com porta por um eixo.
	var wheel := _spawn("water_wheel", base)
	var quern := _spawn("quern", base + Vector3(5.6, 0, 0))
	var wp: Vector3 = Power.world_ports(wheel)[0][0]
	var qp: Vector3 = Power.world_ports(quern)[0][0]
	var r := _axle(wp, qp)
	print("eixo roda->moinho: id=%s comprimento %.2f m, tripés criados=%d" % [r[0], r[2], r[3].size()])
	quern.extra["in"] = 4
	_tick()
	print("com trigo: %s %s | eixo girando=%s" % [_state(wheel), _state(quern), placed.objects[r[0]].extra.get("speed", 0.0) > 0.0])
	print("texto do moinho: ", quern.get_interact_text())
	_tick(10)
	print("10 s depois: moinho entrada=%d saída=%d (farinha)" % [quern.extra.get("in", 0), quern.extra.get("out", 0)])
	# Ponta solta -> tripé; outro eixo continua do tripé até a roca.
	var spin := _spawn("spinning", base + Vector3(0.65, 0, 6.0))
	var sp: Vector3 = Power.world_ports(spin)[0][0]
	var free_end := wp + Vector3(0, 0, 3.0)
	var r2 := _axle(wp, free_end)
	print("eixo até ponto solto: tripés=%d (altura %.2f m)" % [r2[3].size(), r2[3][0][2] if not r2[3].is_empty() else -1.0])
	var r3 := _axle(free_end, sp)
	spin.extra["in"] = 4
	_tick()
	print("do tripé até a roca: tripés novos=%d, %s, mesma rede que a roda=%s" % [r3[3].size(), _state(spin),
		spin.net_id in Power.group_of(wheel.net_id)])
	# Engrenagens: num eixo perpendicular solto, engrenagem encostada na do eixo da roda.
	var cog_a: Array = placed.host_apply("mount", ["cog", Transform3D(Basis.looking_at(-(qp - wp).normalized(), Vector3.UP), wp + (qp - wp).normalized() * 2.0)])
	var gear_a: PlacedObject = placed.objects[cog_a[0]]
	# Errada: centro a 0,6 m de lado, mas a 90° os aros nem se tocam -> não liga.
	var wrong := gear_a.global_position + Vector3(0, 0, 0.6)
	var cog_w: Array = placed.host_apply("mount", ["cog", Transform3D(Basis(), wrong)])
	# Certa (cônica, eixos se cruzando): centro = A + r*eixo de A + r*eixo de B.
	var ua := (qp - wp).normalized()
	var c2 := gear_a.global_position + ua * 0.3 + Vector3(0, 0, 0.3)
	_axle(c2, c2 + Vector3(0, 0, 3.0))
	var cog_b: Array = placed.host_apply("mount", ["cog", Transform3D(Basis(), c2)])
	var gear_b: PlacedObject = placed.objects[cog_b[0]]
	# Auto-encaixe: mirando perto, a ferramenta acha o ponto onde engata.
	var spot := Power.mesh_spot(placed.objects, c2 + Vector3(0, 0, 3.0) - Vector3(0, 0, 3.0), Vector3(0, 0, 1), 3.0, 0.3, 0.25)
	print("auto-encaixe no eixo perpendicular: t=%s (o certo é 0)" % [snappedf(spot[0], 0.01) if not spot.is_empty() else "nenhum"])
	_tick()
	print("engrenagem mal posta ligou? %s" % (placed.objects[cog_w[0]].net_id in Power.group_of(wheel.net_id)))
	_tick()
	print("engrenagens: A gira %d, B gira %d (sentidos opostos=%s), B na rede da roda=%s" % [gear_a.extra.get("dir", 1), gear_b.extra.get("dir", 1),
		gear_a.extra.get("dir", 1) == -gear_b.extra.get("dir", 1), gear_b.net_id in Power.group_of(wheel.net_id)])
	# Polia no meio do eixo roda->moinho + esteira até uma prensa ao lado.
	var mid := wp + (qp - wp).normalized() * 3.0
	var pul: Array = placed.host_apply("mount", ["pulley", Transform3D(Basis.looking_at(-(qp - wp).normalized(), Vector3.UP), mid)])
	var pulley: PlacedObject = placed.objects[pul[0]]
	var saw := _spawn("sawmill", mid + Vector3(1.15, -0.6, -3.0))
	var belt := placed.host_apply("belt", [pulley.net_id, saw.net_id])
	saw.extra["in"] = 1
	quern.extra["in"] = 4
	_tick()
	print("esteira polia->serraria: ligada=%s, %s, na rede=%s" % [not belt.is_empty(), _state(saw), saw.net_id in Power.group_of(wheel.net_id)])
	print("carga agora (moinho 1 + roca 1 + serraria 3 = 5 > 4): %s" % _state(quern))
	_tick(3)
	print("em sobrecarga, a serraria trabalhou? entrada=%d (1 = parada) | texto: %s" % [saw.extra.get("in", 0), saw.get_interact_text()])
	saw.extra["in"] = 0
	_tick()
	print("tirou a serraria do trabalho: %s %s" % [_state(quern), _state(saw)])
	# Luz e giro no visual.
	quern.refresh(placed.clock)
	var lamp := quern.get_node("PowerLamp") as MeshInstance3D
	print("luz do moinho: cor=%s" % (lamp.material_override as StandardMaterial3D).albedo_color)
	var axle_node: PlacedObject = placed.objects[r[0]]
	var rot0: float = axle_node.get_node("Spin").rotation.z
	for k in 20:
		await process_frame
	print("eixo girou no visual: %s" % (absf(axle_node.get_node("Spin").rotation.z - rot0) > 0.1))
	# Tirar o eixo roda->moinho: o moinho fica sem força (a polia também saía dele).
	placed.host_apply("remove", [r[0]])
	_tick()
	print("tirou o eixo: %s" % _state(quern))
	# Save / load.
	var data := placed.save_data()
	placed.load_data(data)
	_tick()
	var axles := placed.objects.values().filter(func(o): return o.kind == "axle")
	var tripods := placed.objects.values().filter(func(o): return o.kind == "tripod")
	print("depois de carregar: eixos=%d (tamanhos %s) tripés=%d esteiras na polia=%s" % [axles.size(),
		axles.map(func(o): return snappedf(o.extra.len, 0.01)), tripods.size(),
		placed.objects.values().filter(func(o): return o.kind == "pulley").map(func(o): return o.extra.get("belts", []))])
	# Ferramenta na mão: arrastar um eixo de 3 m no chão e montar uma engrenagem nele.
	player.inventory.add(&"eixo", 4)
	player.inventory.add(&"engrenagem_madeira", 1)
	var tool: PowerTool = player.power_tool
	var a := player.global_position + Vector3(2, PowerTool.AXLE_HEIGHT, 2)
	var before := placed.objects.size()
	tool._finish(placed, {"a": a, "b": a + Vector3(3, 0, 0), "len": 3.0, "valid": true, "snapped": false})
	await process_frame
	print("ferramenta: objetos %d -> %d (eixo + 2 tripés), eixos na mochila %d" % [before, placed.objects.size(), player.inventory.count(&"eixo")])
