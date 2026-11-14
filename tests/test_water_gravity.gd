extends SceneTree
## Água por gravidade: caixa d'água embaixo não sobe até a caldeira 3 m acima; com a bomba de
## recalque ligada no meio do cano, sobe; caixa no alto desce sozinha para a caldeira embaixo.

var placed: PlacedManager


func _pipe(a: Vector3, b: Vector3) -> int:
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
	var r := placed.host_apply("pipe", [Transform3D(Basis.looking_at(-dir, up), a), a.distance_to(b)])
	return r[0] if not r.is_empty() else -1


func _place(kind: String, at: Vector3) -> PlacedObject:
	var r := placed.host_apply("place", [kind, Transform3D(Basis(), at)])
	return placed.objects.get(r[0]) if not r.is_empty() else null


func _port(obj: PlacedObject, index: int) -> Vector3:
	return obj.global_transform * Fluids.PORTS[obj.kind][index][0]


func _ticks(n: int, pump: PlacedObject = null) -> void:
	for k in n:
		placed.clock += 1.0
		if pump:
			pump.extra.pstate = "ok" # força no eixo (o teste não monta o eixo)
		placed._fluids()


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	placed = main.get_node("Placed")
	var terrain: TerrainWorld = main.get_node("Terrain")
	var h := terrain.height_at(30, 30)
	# 1) Caixa no chão, caldeira 3 m acima, cano direto.
	var tank := _place("water_tank", Vector3(30, h, 30))
	tank.extra.water = 50.0
	var boiler := _place("boiler", Vector3(34, h + 3.0, 30))
	_pipe(_port(tank, 0), _port(boiler, 0))
	_ticks(10)
	print("caldeira 3 m acima da caixa, sem bomba: água %.1f (esperado 0)" % boiler.extra.get("water", 0.0))
	# 2) Mesma coisa com a bomba de recalque no meio do cano.
	var tank2 := _place("water_tank", Vector3(30, h, 40))
	tank2.extra.water = 50.0
	var pump := _place("pipe_pump", Vector3(32, h, 40))
	var boiler2 := _place("boiler", Vector3(36, h + 3.0, 40))
	_pipe(_port(tank2, 0), _port(pump, 1))
	_pipe(_port(pump, 0), _port(boiler2, 0))
	_ticks(10)
	print("sem força na bomba: água %.1f" % boiler2.extra.get("water", 0.0))
	_ticks(10, pump)
	print("bomba ligada (eixo/motor): água %.1f (subiu); caixa %.1f; %s" % [boiler2.extra.get("water", 0.0), tank2.extra.get("water", 0.0), SteamModels.text(pump)])
	# 3) Caixa no alto (2,5 m), caldeira no chão: desce sozinha.
	var tank3 := _place("water_tank", Vector3(30, h + 2.5, 50))
	tank3.extra.water = 50.0
	var boiler3 := _place("boiler", Vector3(34, h, 50))
	_pipe(_port(tank3, 0), _port(boiler3, 0))
	_ticks(10)
	print("caixa 2,5 m acima da caldeira: água %.1f (desceu)" % boiler3.extra.get("water", 0.0))
	print("porta de eixo na bomba de recalque: %s; motor elétrico encaixa? %s" % [Power.PORTS.has("pipe_pump"), Power.DEMAND.has("pipe_pump")])
	quit()
