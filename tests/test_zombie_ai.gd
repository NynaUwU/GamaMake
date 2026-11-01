extends SceneTree
## IA nova dos zumbis:
##   A) jogador FORA da casa construída: o zumbi dá a volta (não quebra parede)
##   B) jogador DENTRO (casa com teto): o zumbi quebra a parede
##   C) zumbi no lago: boia com a cabeça para fora e nada até a margem
##   D) especiais: inchado (bile), saltador (bote), brutamontes (investida e parede),
##      cuspidor (poça de ácido)
## Uso: godot --headless -s res://tests/test_zombie_ai.gd [-- ONLY=A,B]

var main: Node
var player: Player
var bm: BuildingManager
var terrain: TerrainWorld
var only := ""


func _init() -> void:
	only = OS.get_environment("ONLY")
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	player = main.player
	bm = main.get_node("Building")
	terrain = main.get_node("Terrain")
	main.get_node("ZombieSpawner").process_mode = Node.PROCESS_MODE_DISABLED
	if HordeManager.i:
		HordeManager.i.process_mode = Node.PROCESS_MODE_DISABLED
	if DayNight.i:
		DayNight.i.hour = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	_clear()
	if _run("A"):
		await _house_test(false)
	if _run("B"):
		await _house_test(true)
	if _run("C"):
		await _swim_test()
	if _run("D"):
		await _specials_test()
	quit()


func _run(key: String) -> bool:
	return only == "" or key in only.split(",")


func _clear() -> void:
	for e in main.get_node("Enemies").get_children():
		e.free()
	for id in bm.pieces.keys().duplicate():
		bm._remove(id)


func _wait(frames: int) -> void:
	for k in frames:
		await physics_frame


func _keep_still(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO


## Casa 5,6 x 5,6 m (2 paredes por lado) com canto na célula (cx, cz).
func _house(cx: int, cz: int, roof: bool) -> void:
	var cy := floori(terrain.height_at(cx * BuildPiece.SEG + 2.8, cz * BuildPiece.SEG + 2.8) / BuildPiece.SEG)
	for k in 2:
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx + 7 * k, cy, cz), 0])
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx + 7 * k, cy, cz + 14), 0])
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx, cy, cz + 7 * k), 1])
		bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx + 14, cy, cz + 7 * k), 1])
	if roof:
		for a in 2:
			for b in 2:
				bm.host_apply("place", [BuildPiece.Kind.ROOF, Vector3i(cx + 7 * a, cy + 7, cz + 7 * b), 0])


func _broken() -> int:
	var n := 0
	for piece: BuildPiece in bm.pieces.values():
		for b in piece.removed:
			n += b
	return n + (8 if bm.pieces.size() < 8 else 0)


func _house_test(inside: bool) -> void:
	_clear()
	var cx := 60
	var cz := 60
	_house(cx, cz, inside)
	await _wait(5)
	var center := Vector3((cx + 7) * BuildPiece.SEG, 0, (cz + 7) * BuildPiece.SEG)
	center.y = terrain.height_at(center.x, center.z)
	var spot := center + (Vector3.ZERO if inside else Vector3(5.5, 0, 0))
	spot.y = terrain.height_at(spot.x, spot.z) + 0.2
	_keep_still(spot)
	var start := center + Vector3(-7.0, 0, 0.4)
	start.y = terrain.height_at(start.x, start.z) + 0.3
	var z: Zombie = Zombie.new() if false else load("res://scenes/zombie.tscn").instantiate()
	z.position = start
	z.target = player
	main.get_node("Enemies").add_child(z)
	await _wait(2)
	z.alert(player)
	var reached := -1.0
	var attacks := 0
	var last_state := -1
	for f in 60 * 30:
		await physics_frame
		_keep_still(spot)
		if z.state == Zombie.State.ATTACK and last_state != Zombie.State.ATTACK and not z._wall.is_empty():
			attacks += 1
		last_state = z.state
		var d := Vector2(z.global_position.x - spot.x, z.global_position.z - spot.z).length()
		if not inside and d < 2.0 and reached < 0.0:
			reached = f / 60.0
			break
		if inside and _broken() >= 4 and reached < 0.0:
			reached = f / 60.0
			break
	print("%s: abrigado=%s  %s em %.1f s  golpes em parede=%d  pedaços quebrados=%d  zumbi em %s" % [
		"B dentro da casa" if inside else "A fora da casa", Zombie.target_sheltered(player),
		"quebrou a parede" if inside else "chegou no jogador", reached, attacks, _broken(),
		z.global_position.snapped(Vector3.ONE * 0.1)])
	z.free()


func _swim_test() -> void:
	_clear()
	var lake := {}
	for l in WaterManager.i.lakes():
		if not l.frozen and l.radius > 9.0:
			var floor_y := terrain.height_at(l.center.x, l.center.y)
			if l.level - floor_y > 2.0:
				lake = l
				break
	if lake.is_empty():
		print("C: nenhum lago fundo o bastante")
		return
	var c: Vector2 = lake.center
	var shore := Vector3(c.x + lake.radius + 4.0, 0, c.y)
	shore.y = terrain.height_at(shore.x, shore.z) + 0.3
	_keep_still(shore)
	await _wait(90) # terreno em volta
	var z: Zombie = load("res://scenes/zombie.tscn").instantiate()
	z.position = Vector3(c.x - lake.radius * 0.3, lake.level - 2.5, c.y)
	z.target = player
	main.get_node("Enemies").add_child(z)
	await _wait(2)
	z.alert(player)
	var samples := []
	var out_at := -1.0
	for f in 60 * 40:
		await physics_frame
		_keep_still(shore)
		if f % 120 == 60:
			samples.append("%.2f" % (z.global_position.y - lake.level))
		if out_at < 0.0 and WaterManager.i.depth_at(z.global_position) < 0.3 and f > 30:
			out_at = f / 60.0
	print("C lago (fundo %.1f m): altura dos pés em relação à água a cada 2 s: %s" % [lake.level - terrain.height_at(c.x, c.y), ", ".join(samples)])
	print("C: saiu da água em %.1f s, braços abertos=%.1f, distância final ao jogador %.1f m" % [out_at, z.pose_flail,
		Vector2(z.global_position.x - shore.x, z.global_position.z - shore.z).length()])
	z.free()


func _special(kind: String, offset: Vector3) -> Zombie:
	var at := player.global_position + offset
	return main.spawn_special(kind, at)


func _specials_test() -> void:
	_clear()
	var base := Vector3(30, 0, -30)
	base.y = terrain.height_at(base.x, base.z) + 0.2
	_keep_still(base)
	await _wait(30)
	# Aparência: blocos a mais e vida de cada um.
	var looks := []
	for kind in ZombieSpecial.KINDS:
		var z := _special(kind, Vector3(60, 0, 60))
		await _wait(2)
		looks.append("%s vida=%d extras=%d" % [kind, z.max_health, z.find_children("Extra", "MeshInstance3D", true, false).size()])
		z.free()
	print("D aparência: ", " | ".join(looks))
	# Inchado: vomita perto e estoura ao morrer.
	player.health = player.max_health
	var fat := _special("inchado", Vector3(5, 0, 0))
	var friend: Zombie = load("res://scenes/zombie.tscn").instantiate()
	friend.position = base + Vector3(-30, 0.3, 0)
	main.get_node("Enemies").add_child(friend)
	await _wait(2)
	fat.alert(player)
	var vomit_at := -1.0
	for f in 60 * 12:
		await physics_frame
		_keep_still(base)
		if player.bile_time > 0.0:
			vomit_at = f / 60.0
			break
	print("D inchado: vomitou em %.1f s, bile=%.1f s, zumbi a 30 m veio atrás=%s (alvo=%s)" % [vomit_at, player.bile_time,
		friend._alerted, friend.target == player])
	player.bile_time = 0.0
	fat.take_hit(HitInfo.make(500.0, &"Chest", fat.global_position + Vector3.UP, Vector3.FORWARD, 30.0, HitInfo.Type.BLUNT))
	await _wait(5)
	print("D inchado morto: bile ao estourar=%.1f s, membros arrancados=%d" % [player.bile_time, fat._cut_bones.size()])
	_clear()
	# Saltador: bote de longe.
	player.health = player.max_health
	var hunter := _special("saltador", Vector3(9, 0, 0))
	await _wait(2)
	hunter.alert(player)
	var top := -INF
	var hp0 := player.health
	var leap_at := -1.0
	for f in 60 * 8:
		await physics_frame
		_keep_still(base)
		top = maxf(top, hunter.global_position.y - base.y)
		if leap_at < 0.0 and hunter.special._phase == 2:
			leap_at = f / 60.0
		if hp0 - player.health >= 20.0:
			break
	print("D saltador: pulou em %.1f s, altura máx %.1f m, dano no jogador %.0f" % [leap_at, top, hp0 - player.health])
	_clear()
	# Brutamontes: investida no jogador, depois numa parede.
	player.health = player.max_health
	var brute := _special("brutamontes", Vector3(14, 0, 0))
	await _wait(2)
	brute.alert(player)
	hp0 = player.health
	var max_speed := 0.0
	var knock := 0.0
	for f in 60 * 8:
		await physics_frame
		if hp0 - player.health < 1.0:
			_keep_still(base)
		max_speed = maxf(max_speed, Vector2(brute.velocity.x, brute.velocity.z).length())
		knock = maxf(knock, player.velocity.length())
		if hp0 - player.health >= 30.0:
			break
	print("D brutamontes: velocidade máx %.1f m/s, dano %.0f, empurrão %.1f m/s" % [max_speed, hp0 - player.health, knock])
	_clear()
	# Brutamontes x parede (jogador do outro lado, fora da casa).
	var cx := floori((base.x + 4.0) / BuildPiece.SEG)
	var cz := floori((base.z - 2.8) / BuildPiece.SEG)
	var cy := floori(terrain.height_at(cx * 0.4, cz * 0.4) / BuildPiece.SEG)
	bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx, cy, cz), 1])
	bm.host_apply("place", [BuildPiece.Kind.WALL, Vector3i(cx, cy, cz + 7), 1])
	await _wait(3)
	var brute2 := _special("brutamontes", Vector3(12, 0, 0))
	await _wait(2)
	brute2.alert(player)
	for f in 60 * 10:
		await physics_frame
		_keep_still(base)
		if _broken() >= 3:
			break
	print("D brutamontes x parede: pedaços quebrados=%d (estado %s)" % [_broken(), Zombie.State.keys()[brute2.state]])
	_clear()
	# Cuspidor: fica longe e cospe.
	player.health = player.max_health
	var spitter := _special("cuspidor", Vector3(12, 0, 0))
	await _wait(2)
	spitter.alert(player)
	hp0 = player.health
	var puddle_at := -1.0
	var min_d := INF
	for f in 60 * 10:
		await physics_frame
		_keep_still(base)
		min_d = minf(min_d, spitter.global_position.distance_to(base))
		if puddle_at < 0.0 and not main.find_children("*", "AcidPuddle", true, false).is_empty():
			puddle_at = f / 60.0
	print("D cuspidor: poça em %.1f s, dano do ácido %.0f, mais perto que chegou %.1f m" % [puddle_at, hp0 - player.health, min_d])
	_clear()
	for p in main.find_children("*", "AcidPuddle", true, false):
		p.free()
	_clear()
