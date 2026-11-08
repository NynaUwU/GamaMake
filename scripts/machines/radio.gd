class_name Radio
extends RefCounted
## Rádio (Tier 4): ligado e com energia, a cada 4-7 h de jogo pega uma transmissão:
##   horda    de tarde avisa de onde vem a horda desta noite (direção da onda)
##   airdrop  suprimentos lançados a 120-260 m (aparece no mapa como os outros)
##   pedido   sobreviventes pedem itens; [E] no rádio com tudo na mochila entrega e
##            o rádio manda a recompensa (2 sorteios de airdrop) para a mochila
## A mensagem vai para o chat de todos e aparece na tela de quem está perto (30 m),
## com chiado. Fica guardada no rádio ([E] repete).

const HOURS := Vector2(4.0, 7.0) ## intervalo entre transmissões (horas de jogo)
const HEAR := 30.0
## Pedidos possíveis: [item, mínimo, máximo].
const WANTS := [[&"tabua", 10, 24], [&"pao_fresco", 2, 4], [&"barra_ferro", 3, 8], [&"tecido", 2, 5], [&"carne_seca", 3, 6],
	[&"agua", 3, 6], [&"carvao", 6, 12], [&"tijolo", 8, 16], [&"barra_cobre", 3, 6], [&"oleo", 1, 3], [&"bandagem", 2, 4]]


static func _now() -> float:
	return DayNight.i.day * 24.0 + DayNight.i.hour if DayNight.i else 0.0


## Host, 1x por segundo (PlacedManager): rádios ligados com energia transmitem na hora certa.
static func host_tick(manager: PlacedManager) -> void:
	if DayNight.i == null:
		return
	var now := _now()
	for obj: PlacedObject in manager.objects.values():
		if obj.kind != "radio" or not Electric.powered(obj):
			continue
		if not obj.extra.has("next"):
			obj.extra.next = now + 0.05 # primeira transmissão logo que liga
		if now < obj.extra.next:
			continue
		var update := broadcast(manager, obj)
		update.next = now + randf_range(HOURS.x, HOURS.y)
		obj.extra.merge(update, true)
		manager.request("extra", [obj.net_id, update])


## Escolhe e monta a transmissão. Devolve o extra novo do rádio.
static func broadcast(manager: PlacedManager, obj: PlacedObject) -> Dictionary:
	var hour: float = DayNight.i.hour if DayNight.i else 12.0
	var options := ["airdrop"]
	if obj.extra.get("mission", {}).is_empty():
		options.append("pedido")
	if hour >= 11.0 and hour < 19.5 and HordeManager.i:
		options.append("horda")
		options.append("horda") # de tarde é o mais comum
	var pick: String = options[randi() % options.size()]
	var msg := ""
	var update := {}
	match pick:
		"horda":
			msg = "Rádio: a horda desta noite vem do %s. Reforce esse lado." % compass(HordeManager.i.upcoming_angle())
		"airdrop":
			var spot := _drop_spot(manager, obj.global_position)
			if spot == Vector3.INF:
				msg = "Rádio: chiado... (nada dá para entender)"
			else:
				manager.drop_airdrop(Transform3D(Basis(Vector3.UP, randf() * TAU), spot))
				var to := spot - obj.global_position
				msg = "Rádio: suprimentos lançados a %d m ao %s. Veja no mapa." % [int(Vector2(to.x, to.z).length()), compass(atan2(to.z, to.x))]
		"pedido":
			var mission := _new_mission()
			update.mission = mission
			msg = "Rádio: sobreviventes pedem %s. Entregue pelo rádio e eles mandam suprimentos." % mission_text(mission)
	update.msg = msg
	update.msg_t = _now()
	return update


## Lugar plano para o airdrop a 120-260 m (Vector3.INF se não achou).
static func _drop_spot(manager: PlacedManager, from: Vector3) -> Vector3:
	var space := manager.get_world_3d().direct_space_state
	var terrain := manager.get_parent().get_node_or_null("Terrain") as TerrainWorld
	for attempt in 12:
		var a := randf() * TAU
		var r := randf_range(120.0, 260.0)
		var p := from + Vector3(cos(a) * r, 0, sin(a) * r)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 120.0, p + Vector3.DOWN * 120.0, 1))
		if hit.is_empty() and terrain:
			if terrain.sea_at(p.x, p.z):
				continue
			hit = {"position": Vector3(p.x, terrain.height_at(p.x, p.z), p.z), "normal": Vector3.UP}
		if hit.is_empty() or hit.normal.y < 0.75 or hit.position.y < TerrainWorld.SEA_LEVEL + 0.5:
			continue
		return hit.position
	return Vector3.INF


static func _new_mission() -> Dictionary:
	var pool := WANTS.duplicate()
	pool.shuffle()
	var items := {}
	for k in 2:
		var w: Array = pool[k]
		items[String(w[0])] = randi_range(w[1], w[2])
	return {"items": items}


static func mission_text(mission: Dictionary) -> String:
	var list: Array[String] = []
	for id in mission.get("items", {}):
		list.append("%d %s" % [mission.items[id], ItemDB.display_name(StringName(id))])
	return " e ".join(list)


## Direção (de onde vem / para onde fica) a partir do ângulo em XZ (x = cos, z = sin). Norte = -Z.
static func compass(angle: float) -> String:
	var dir := Vector2(cos(angle), sin(angle))
	var bearing := fposmod(rad_to_deg(atan2(dir.x, -dir.y)), 360.0) # 0 = norte, 90 = leste
	var names := ["norte", "nordeste", "leste", "sudeste", "sul", "sudoeste", "oeste", "noroeste"]
	return names[int(roundf(bearing / 45.0)) % 8]


# --- Jogador ---------------------------------------------------------------------------

## [E]: entrega o pedido (se tiver tudo) ou repete a última mensagem.
static func interact(player: Node, obj: PlacedObject) -> void:
	var manager := obj.get_parent() as PlacedManager
	var mission: Dictionary = obj.extra.get("mission", {})
	if not mission.is_empty():
		var missing := []
		for id in mission.items:
			if player.inventory.count(StringName(id)) < int(mission.items[id]):
				missing.append(id)
		if missing.is_empty():
			var cost := {}
			for id in mission.items:
				cost[StringName(id)] = int(mission.items[id])
			Builder.pay(player.inventory, cost)
			manager.request("radio_deliver", [obj.net_id])
			Sfx.play_at("pickup", obj.global_position + Vector3.UP * 0.5, 2.0, 0.8)
			return
	var msg: String = obj.extra.get("msg", "")
	if msg != "" and player.has_signal("notify"):
		player.notify.emit(msg)
	_static_sound(obj)


## Host: pedido entregue (os itens já saíram da mochila de quem entregou).
static func host_deliver(manager: PlacedManager, obj: PlacedObject) -> Dictionary:
	if obj.extra.get("mission", {}).is_empty():
		return {}
	for k in 2:
		for drop in Loot.roll("airdrop"):
			Net.i.give_to(Net.i.request_peer, drop[0], drop[1])
	return {"mission": {}, "msg": "Rádio: recebido, obrigado! Suprimentos a caminho da sua mochila.", "msg_t": _now()}


## Cliente/host: a mensagem nova do rádio chegou (refresh do objeto).
static func refresh(obj: PlacedObject) -> void:
	var t: float = obj.extra.get("msg_t", -1.0)
	if t < 0.0 or is_equal_approx(obj.get_meta("heard", -2.0), t):
		ElectricModels.refresh(obj)
		return
	var first := not obj.has_meta("heard")
	obj.set_meta("heard", t)
	ElectricModels.refresh(obj)
	if first and _now() - t > 0.5:
		return # mensagem velha (save carregado / entrou depois): não repete
	var msg: String = obj.extra.get("msg", "")
	if msg == "":
		return
	if Chat.i:
		Chat.i.add_line("", msg)
	var me := obj.get_tree().get_first_node_in_group("player") as Player if obj.is_inside_tree() else null
	if me and me.global_position.distance_to(obj.global_position) < HEAR:
		me.notify.emit(msg)
		_static_sound(obj)


static func _static_sound(obj: PlacedObject) -> void:
	Sfx.play_at("static", obj.global_position + Vector3.UP * 0.5, 0.0, 1.0)
