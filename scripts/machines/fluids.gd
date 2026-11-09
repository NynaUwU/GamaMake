class_name Fluids
extends RefCounted
## Canos e rede de fluido (Tier 3). Cada cano é um trecho reto (PlacedObject
## "pipe", extra.len) que sai da origem e vai em +Z local. Canos e máquinas se
## ligam quando as pontas/portas (bolinhas de latão) ficam a até PIPE_SNAP.
## O host recalcula 1x por segundo, por rede ligada e por fluido:
##   - fontes: carneiro hidráulico (rio), coletor de chuva, caixa d'água (estoque),
##     caldeira (vapor da pressão);
##   - consumidores: caldeira e destilaria (enchem o tanque), aspersor, motor a vapor;
##   - sobrou água: as caixas d'água guardam; faltou: as caixas soltam.
## Água em "garrafas" (1 unidade = 1 garrafa); vapor em "segundos de motor a 100%".

const PIPE_SNAP := 0.35
const MAX_PIPE := 6.0 ## comprimento máximo de um trecho
const PIPE_PER_ITEM := 2.0 ## metros de cano por item "cano"
const TANK_CAP := 60.0
const BOILER_WATER := 20.0
const STILL_WATER := 10.0
const SPRINKLER_RADIUS := 8.0
## Portas em espaço local: [posição, fluido, sentido ("in"/"out"/"both")].
const PORTS := {
	"ram_pump": [[Vector3(0.35, 0.2, 0.0), "water", "out"]],
	"rain_collector": [[Vector3(0.0, 0.18, 0.5), "water", "out"]],
	"water_tank": [[Vector3(0.62, 0.35, 0), "water", "both"], [Vector3(-0.62, 0.35, 0), "water", "both"],
		[Vector3(0, 0.35, 0.62), "water", "both"], [Vector3(0, 0.35, -0.62), "water", "both"]],
	"boiler": [[Vector3(-1.2, 0.55, 0.0), "water", "in"], [Vector3(0.55, 2.05, 0.0), "steam", "out"]],
	"steam_engine": [[Vector3(-0.15, 1.12, -0.7), "steam", "in"]],
	"distillery": [[Vector3(0.55, 0.25, 0.45), "water", "in"]],
	"sprinkler": [[Vector3(0.0, 0.1, 0.22), "water", "in"]],
	"water_trough": [[Vector3(0.68, 0.3, 0.0), "water", "in"]],
	"electric_pump": [[Vector3(0.45, 0.25, 0.0), "water", "out"]],
	"pump": [[Vector3(0.36, 0.25, 0.0), "water", "out"]], # bomba manual com força no eixo
}
## Água que cada fonte consegue mandar por segundo.
const SOURCE_RATE := {"ram_pump": 1.0, "rain_collector": 0.5, "water_tank": 2.0, "electric_pump": 1.5}


static func is_fluid(kind: String) -> bool:
	return kind == "pipe" or PORTS.has(kind)


## Pontas do cano no mundo.
static func pipe_ends(obj: PlacedObject) -> Array:
	var a := obj.global_position
	return [a, a + obj.global_basis.z * float(obj.extra.get("len", 1.0))]


## Pontos de ligação no mundo: [[posição, fluido, sentido], ...].
static func world_ports(obj: PlacedObject) -> Array:
	if obj.kind == "pipe":
		var ends := pipe_ends(obj)
		return [[ends[0], "any", "both"], [ends[1], "any", "both"]]
	var list := []
	for port in PORTS.get(obj.kind, []):
		list.append([obj.global_transform * port[0], port[1], port[2]])
	return list


## Ligados por alguma porta encostada (fluid = "" qualquer; senão só portas desse fluido ou ponta de cano).
static func touching(a: PlacedObject, b: PlacedObject, fluid := "") -> bool:
	for pa in world_ports(a):
		if fluid != "" and pa[1] != fluid and pa[1] != "any":
			continue
		for pb in world_ports(b):
			if fluid != "" and pb[1] != fluid and pb[1] != "any":
				continue
			if pa[0].distance_to(pb[0]) < PIPE_SNAP:
				return true
	return false


static func _has_fluid(obj: PlacedObject, fluid: String) -> bool:
	if obj.kind == "pipe":
		return true
	for port in PORTS.get(obj.kind, []):
		if port[1] == fluid:
			return true
	return false


## Ponto de encaixe mais perto (porta de máquina ou ponta de cano) a até "radius": Vector3.INF se nada.
static func snap_point(objects: Dictionary, near: Vector3, radius := 0.5) -> Vector3:
	var best := Vector3.INF
	var best_d := radius
	for obj: PlacedObject in objects.values():
		if not is_fluid(obj.kind) or obj.global_position.distance_to(near) > MAX_PIPE + 3.0:
			continue
		for port in world_ports(obj):
			var d: float = port[0].distance_to(near)
			if d < best_d:
				best_d = d
				best = port[0]
	return best


## Quantos itens "cano" um trecho deste tamanho gasta.
static func pipe_cost(length: float) -> int:
	return maxi(1, ceili(length / PIPE_PER_ITEM - 0.01))


# --- Host: a rede ---------------------------------------------------------------------

## Host, 1x por segundo. Devolve {net_id: extra parcial} do que mudou (para mandar a todos).
## Água e vapor são redes separadas: a caldeira entra nas duas, mas não as junta.
static func tick(objects: Dictionary, clock: float) -> Dictionary:
	var parts: Array = objects.values().filter(func(o): return is_fluid(o.kind))
	for fluid in ["water", "steam"]:
		var seen := {}
		for start in parts:
			if seen.has(start.net_id) or not _has_fluid(start, fluid):
				continue
			var group := [start]
			seen[start.net_id] = true
			var k := 0
			while k < group.size():
				var obj: PlacedObject = group[k]
				k += 1
				for other in parts:
					if seen.has(other.net_id) or not _has_fluid(other, fluid):
						continue
					if obj.global_position.distance_to(other.global_position) < MAX_PIPE + 3.0 and touching(obj, other, fluid):
						seen[other.net_id] = true
						group.append(other)
			var rate := _water(group) if fluid == "water" else _steam(group)
			for obj: PlacedObject in group:
				if obj.kind == "pipe":
					obj.extra["flow" if fluid == "water" else "vapor"] = rate
	var changed := {}
	for obj: PlacedObject in parts:
		var before: Dictionary = obj.get_meta("fluid_sent", {})
		var now := _fluid_state(obj)
		if _differs(before, now):
			obj.set_meta("fluid_sent", now.duplicate())
			changed[obj.net_id] = now
	return changed


## Estado que vai para os clientes (o resto fica só no host).
static func _fluid_state(obj: PlacedObject) -> Dictionary:
	match obj.kind:
		"pipe":
			return {"flow": snappedf(obj.extra.get("flow", 0.0), 0.1), "vapor": snappedf(obj.extra.get("vapor", 0.0), 0.1)}
		"steam_engine":
			return {"steam": snappedf(obj.extra.get("steam", 0.0), 0.05)}
		"sprinkler":
			return {"wet": obj.extra.get("wet", false)}
		"water_tank", "boiler", "distillery", "rain_collector", "water_trough":
			return {"water": snappedf(obj.extra.get("water", 0.0), 0.5)}
	return {}


static func _differs(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return true
	for key in b:
		if not a.has(key) or (b[key] is float and absf(a[key] - b[key]) > 0.04) or (not b[key] is float and a[key] != b[key]):
			return true
	return false


## Água numa rede: divide o que as fontes mandam entre quem precisa. Devolve o fluxo (unid/s).
static func _water(group: Array) -> float:
	var supply := 0.0
	var tanks := []
	var sources := []
	var wants := {} # obj -> quanto quer
	for obj: PlacedObject in group:
		match obj.kind:
			"ram_pump":
				supply += SOURCE_RATE.ram_pump
			"electric_pump":
				if Electric.powered(obj):
					supply += SOURCE_RATE.electric_pump # poço: sem fim, com energia
			"pump":
				if obj.extra.get("pstate", "") == "ok":
					supply += 1.0 # bomba da beira do lago movida pelo eixo
			"rain_collector":
				var give: float = minf(obj.extra.get("water", 0.0), SOURCE_RATE.rain_collector)
				if give > 0.0:
					sources.append([obj, give])
					supply += give
			"water_tank":
				tanks.append(obj)
			"boiler":
				wants[obj] = clampf(BOILER_WATER - obj.extra.get("water", 0.0), 0.0, 0.6)
			"distillery":
				wants[obj] = clampf(STILL_WATER - obj.extra.get("water", 0.0), 0.0, 0.4)
			"sprinkler":
				wants[obj] = 0.1
			"water_trough":
				wants[obj] = clampf(Ranch.WATER_CAP - obj.extra.get("water", 0.0), 0.0, 0.5)
	var demand := 0.0
	for obj in wants:
		demand += wants[obj]
	# Faltou: as caixas d'água completam.
	var from_tanks := 0.0
	if demand > supply:
		for tank: PlacedObject in tanks:
			var give: float = minf(tank.extra.get("water", 0.0), SOURCE_RATE.water_tank)
			give = minf(give, demand - supply - from_tanks)
			if give > 0.0:
				tank.extra.water = tank.extra.get("water", 0.0) - give
				from_tanks += give
	var total := supply + from_tanks
	var fraction := 1.0 if demand <= 0.0 else minf(1.0, total / demand)
	for obj: PlacedObject in wants:
		var got: float = wants[obj] * fraction
		if obj.kind == "sprinkler":
			obj.extra.wet = got >= 0.05
		else:
			obj.extra.water = obj.extra.get("water", 0.0) + got
	# Sobrou água das fontes: as caixas d'água guardam.
	var used := minf(demand, total)
	var surplus := maxf(supply - used, 0.0)
	var to_tanks := 0.0
	for tank: PlacedObject in tanks:
		var room: float = clampf(TANK_CAP - tank.extra.get("water", 0.0), 0.0, SOURCE_RATE.water_tank)
		var put := minf(room, surplus - to_tanks)
		if put > 0.0:
			tank.extra.water = tank.extra.get("water", 0.0) + put
			to_tanks += put
	# Coletores de chuva pagam a parte deles do que saiu das fontes (o carneiro é sem fim).
	var drawn := minf(used, supply) + to_tanks
	if supply > 0.0:
		for entry in sources:
			entry[0].extra.water = maxf(entry[0].extra.get("water", 0.0) - entry[1] / supply * drawn, 0.0)
	return used + to_tanks


## Vapor: as caldeiras (pressão guardada) alimentam os motores. Devolve o fluxo.
static func _steam(group: Array) -> float:
	var boilers := []
	var engines := []
	var supply := 0.0
	for obj: PlacedObject in group:
		if obj.kind == "boiler":
			boilers.append(obj)
			supply += minf(obj.extra.get("pressure", 0.0), 1.5)
		elif obj.kind == "steam_engine":
			engines.append(obj)
	var demand := float(engines.size())
	var fraction := 0.0 if demand <= 0.0 else minf(1.0, supply / demand)
	for engine: PlacedObject in engines:
		engine.extra.steam = fraction
	var used := minf(supply, demand)
	for boiler: PlacedObject in boilers:
		var p: float = minf(boiler.extra.get("pressure", 0.0), 1.5)
		if supply > 0.0:
			boiler.extra.pressure = maxf(boiler.extra.get("pressure", 0.0) - p / supply * used, 0.0)
	return used


# --- Caldeira (chamada pela Smelting, 1x por segundo no host) ---------------------------

const BOILER_HEAT_UP := 0.05 ## por segundo queimando (20 s até o máximo)
const BOILER_COOL := 0.02
const BOILER_WATER_PER_STEAM := 0.15
const PRESSURE_MAX := 1.5
const DRY_LIMIT := 12.0 ## segundos seca e quente até explodir


## Esquenta com o fogo, ferve a água em vapor (pressão) e conta o tempo seca.
## Devolve "boom" se explodiu, "vent" se a válvula de segurança abriu, "" se nada.
static func boiler_step(obj: PlacedObject, burning: bool) -> String:
	var heat: float = obj.extra.get("heat", 0.0)
	heat = clampf(heat + (BOILER_HEAT_UP if burning else -BOILER_COOL), 0.0, 1.0)
	obj.extra.heat = heat
	var water: float = obj.extra.get("water", 0.0)
	var pressure: float = obj.extra.get("pressure", 0.0)
	var result := ""
	if heat > 0.5 and water > 0.0:
		var steam := clampf((heat - 0.5) * 2.4, 0.0, 1.2)
		steam = minf(steam, water / BOILER_WATER_PER_STEAM)
		water -= steam * BOILER_WATER_PER_STEAM
		pressure += steam
		if pressure > PRESSURE_MAX:
			pressure = PRESSURE_MAX
			result = "vent" # válvula chiando: está sobrando vapor
	else:
		pressure = maxf(pressure - 0.05, 0.0)
	obj.extra.water = maxf(water, 0.0)
	obj.extra.pressure = pressure
	# Seca e quente: superaquece. Com água de novo, esfria a contagem.
	var dry: float = obj.extra.get("dry", 0.0)
	if obj.extra.water <= 0.01 and heat > 0.6:
		dry += 1.0
	else:
		dry = maxf(dry - 2.0, 0.0)
	obj.extra.dry = dry
	if dry >= DRY_LIMIT:
		return "boom"
	return result


# --- Alto-forno (multibloco) ---------------------------------------------------------------

const BLAST_BASE_H := 1.3
const BLAST_RING_H := 1.05
const BLAST_RINGS := 2


## Anéis empilhados em cima da base (0..2). Completo com 2.
static func blast_rings(obj: PlacedObject) -> int:
	var manager := obj.get_parent() as PlacedManager
	if manager == null:
		return 0
	var count := 0
	var y := BLAST_BASE_H
	for k in BLAST_RINGS:
		var want := obj.global_position + Vector3.UP * y
		var found := false
		for other: PlacedObject in manager.objects.values():
			if other.kind == "blast_stack" and other.global_position.distance_to(want) < 0.35:
				found = true
				break
		if not found:
			break
		count += 1
		y += BLAST_RING_H
	return count


static func blast_complete(obj: PlacedObject) -> bool:
	return blast_rings(obj) >= BLAST_RINGS
