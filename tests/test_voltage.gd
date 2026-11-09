extends SceneTree
## Fase 3 das eras: tensão (12/110 V), fusível da bateria de 12 V numa rede de 110 V,
## carregador e inversor (com sobrecarga queimando e conserto), banco de baterias de
## 110 V (só com as 9 células), desgaste das células, célula estourando e perda nos cabos.

var main: Node3D
var player: Player
var placed: PlacedManager
var at := Vector3.ZERO


func _spawn(kind: String, offset: Vector3) -> PlacedObject:
	var id: int = placed._next_id
	placed._spawn(id, kind, Transform3D(Basis(), at + offset))
	return placed.objects[id]


func _cable(a: PlacedObject, b: PlacedObject) -> bool:
	return placed.host_apply("cable", [a.net_id, b.net_id]).size() > 0


func _tick(n := 1) -> void:
	for k in n:
		placed._power()
		placed._electric()


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	player = main.player
	placed = main.get_node("Placed")
	player.inventory.add(&"cabo", 100)
	at = player.global_position + Vector3(6, 0, -6)
	at.y = main.get_node("Terrain").height_at(at.x, at.z)
	DayNight.i.hour = 12.0
	DayNight.i._apply()
	Weather.i.rain = 0.0
	# --- Rede de 12 V: painel + bateria + lâmpada (bivolt) e bancada de solda (só 110 V).
	var solar := _spawn("solar_panel", Vector3(0, 0, 0))
	var battery := _spawn("battery", Vector3(2, 0, 0))
	battery.extra.cells = 2
	battery.extra.charge = 300.0
	var lamp := _spawn("lamp", Vector3(4, 0, 0))
	var bench := _spawn("weld_bench", Vector3(6, 0, 2))
	_cable(solar, battery)
	_cable(battery, lamp)
	_cable(lamp, bench)
	_tick(2)
	print("12 V: lâmpada acesa=%s; bancada de solda ligada=%s, texto '%s'" % [Electric.powered(lamp), Electric.powered(bench), Electric.text(bench)])
	# --- Inversor: 12 V -> 110 V para a bancada.
	placed.host_apply("cable", [lamp.net_id, bench.net_id]) # tira o cabo direto
	var inverter := _spawn("inverter", Vector3(6, 0, 0))
	var left_side := inverter.global_transform * Electric.SWITCH_TERMINALS["inverter"][0]
	print("inversor: borne de entrada em %s" % left_side.snapped(Vector3.ONE * 0.01))
	_cable(lamp, inverter)
	_cable(inverter, bench)
	_tick(3)
	print("com inversor: lados %s (entrada=lâmpada %d, saída=bancada %d), bancada ligada=%s, carga do inversor %.2f, estado '%s'" % [
		Electric.converter_sides(inverter), lamp.net_id, bench.net_id, Electric.powered(bench), inverter.extra.get("gauge", 0.0), inverter.extra.get("status", "")])
	# Sobrecarga: mais aparelhos de 110 V na saída do que os 600 W do inversor.
	var fridges: Array[PlacedObject] = []
	for k in 4:
		var f := _spawn("fridge", Vector3(8 + k * 1.2, 0, 2))
		_cable(bench if k == 0 else fridges[k - 1], f)
		fridges.append(f)
	var burnt_at := -1
	for k in 40:
		_tick()
		if inverter.extra.get("burnt", false) and burnt_at < 0:
			burnt_at = k
	print("sobrecarga (300 + 4x150 W = 900 W na saída de 600 W): queimou=%s depois de %d s; texto '%s'" % [inverter.extra.get("burnt", false), burnt_at + 1, Electric.text(inverter)])
	player.inventory.add(&"bobina", 1)
	Electric.interact(player, inverter)
	await process_frame
	print("conserto com bobina: queimado=%s, bobinas na mochila %d" % [inverter.extra.get("burnt", false), player.inventory.count(&"bobina")])
	for f in fridges:
		placed.host_apply("remove", [f.net_id])
	# --- Dínamo em 110 V na mesma rede da bateria de 12 V: queima o fusível.
	var wheel := _spawn("water_wheel", Vector3(0, 0, 10))
	var port: Vector3 = Power.world_ports(wheel)[0][0]
	var id: int = placed._next_id
	placed._spawn(id, "dynamo", Transform3D(Basis(), port + Vector3(0.7, -0.6, 0)))
	var dynamo: PlacedObject = placed.objects[id]
	_cable(dynamo, battery)
	_tick(3)
	print("dínamo em %d V na rede da bateria: fusível=%s, lâmpada=%s" % [int(dynamo.extra.get("v", 12)), battery.extra.get("fuse", false), Electric.powered(lamp)])
	dynamo.extra.v = 110
	_tick(2)
	print("dínamo em 110 V: fusível da bateria de 12 V queimou=%s; painel bloqueado (gera na rede)=%s; texto '%s'" % [battery.extra.get("fuse", false),
		Electric.source_volts(solar) == 110, Electric.text(battery).left(80)])
	# --- Carregador: dínamo 110 V -> carregador -> bateria nova de 12 V.
	placed.host_apply("cable", [dynamo.net_id, battery.net_id]) # tira
	var charger := _spawn("charger", Vector3(2, 0, 10))
	var battery2 := _spawn("battery", Vector3(4, 0, 10))
	battery2.extra.cells = 2
	battery2.extra.charge = 0.0
	_cable(dynamo, charger)
	_cable(charger, battery2)
	_tick(5)
	print("carregador: lados %s, estado '%s', bateria nova %.0f Wh em 5 s (fusível %s)" % [Electric.converter_sides(charger), charger.extra.get("status", ""),
		battery2.extra.get("charge", 0.0), battery2.extra.get("fuse", false)])
	# --- Banco de 110 V: só com 9 células.
	var bank := _spawn("battery_bank", Vector3(0, 0, 16))
	bank.extra.cells = 8
	bank.extra.charge = 2000.0
	var bench2 := _spawn("weld_bench", Vector3(3, 0, 16))
	_cable(bank, bench2)
	_tick(2)
	print("banco com 8 células: fonte %d V, bancada=%s" % [Electric.source_volts(bank), Electric.powered(bench2)])
	bank.extra.cells = 9
	_tick(2)
	print("banco com 9 células: fonte %d V, bancada=%s, capacidade %.0f Wh" % [Electric.source_volts(bank), Electric.powered(bench2), Electric.capacity(bank)])
	# --- Bateria tirando mais que o normal: esquenta e estoura uma célula.
	var weak := _spawn("battery", Vector3(0, 0, 22))
	weak.extra.cells = 1
	weak.extra.charge = 300.0
	var prev: PlacedObject = weak
	for k in 13: # 13 x 50 W = 650 W numa célula de 500 W
		var l := _spawn("lamp", Vector3(1.2 + k * 0.8, 0, 22))
		_cable(prev, l)
		prev = l
	var burst := -1
	for k in 30:
		_tick()
		if Electric.cells(weak) == 0 and burst < 0:
			burst = k
	print("célula tirando 650 W de 500 W: estourou=%s depois de %d s" % [burst >= 0, burst + 1])
	# --- Desgaste: um ciclo inteiro.
	var cyc := _spawn("battery", Vector3(0, 0, 28))
	cyc.extra.cells = 1
	cyc.extra.charge = 300.0
	var load_lamp := _spawn("lamp", Vector3(2, 0, 28))
	_cable(cyc, load_lamp)
	var guard := 0
	while cyc.extra.get("charge", 0.0) > 0.01 and guard < 20000:
		guard += 1
		_tick()
	for k in 10:
		_tick()
	print("um ciclo inteiro (e 10 s vazia com consumo): saúde %.3f" % Electric.health(cyc))
	# --- Perda nos cabos: 12 V x 110 V.
	print("perda: 25 m de cabo em 12 V %.0f%%, em 110 V %.1f%%" % [Electric.cable_loss({"cable": 25.0, "volts": 12}) * 100.0, Electric.cable_loss({"cable": 25.0, "volts": 110}) * 100.0])
	print("texto do dínamo: '%s'; do carregador: '%s'" % [Electric.text(dynamo), Electric.text(charger)])
	quit()
