class_name Power
extends RefCounted
## Energia mecânica (Tier 2). Geradores giram eixos; eixos e correias levam o
## giro até as máquinas. O host recalcula 1x por segundo:
##   - redes = grupos de peças ligadas (portas encostadas ou correia entre elas);
##   - oferta = soma dos geradores; demanda = máquinas com trabalho;
##   - velocidade da rede = min(1, oferta / demanda): pouca energia, tudo mais devagar.
## Portas (bolinhas de latão no modelo) precisam se tocar (até 0,35 m); a correia
## liga duas peças a até 8 m, sem precisar alinhar.

const BELT_RANGE := 8.0
const PORT_SNAP := 0.35
## Geradores: potência máxima.
const OUTPUT := {"water_wheel": 4.0, "windmill": 6.0}
## Consumidores: o quanto puxam com trabalho.
const DEMAND := {"sawmill": 3.0, "quern": 1.0, "spinning": 1.0, "loom": 1.5}
## Portas em espaço local: [posição, eixo].
const PORTS := {
	"shaft": [[Vector3(1.0, 0.6, 0), Vector3.RIGHT], [Vector3(-1.0, 0.6, 0), Vector3.LEFT]],
	"water_wheel": [[Vector3(1.05, 0.6, 0), Vector3.RIGHT]],
	"windmill": [[Vector3(0, 0.6, 0.85), Vector3.BACK]],
	"sawmill": [[Vector3(-1.15, 0.6, 0), Vector3.LEFT]],
	"quern": [[Vector3(-0.55, 0.6, 0), Vector3.LEFT]],
	"spinning": [[Vector3(-0.65, 0.6, 0), Vector3.LEFT]],
	"loom": [[Vector3(-0.8, 0.6, 0), Vector3.LEFT]],
}


static func is_power(kind: String) -> bool:
	return PORTS.has(kind)


## Portas no mundo: [[posição, direção], ...].
static func world_ports(obj: PlacedObject) -> Array:
	var list := []
	for port in PORTS.get(obj.kind, []):
		list.append([obj.global_transform * port[0], obj.global_basis * port[1]])
	return list


## Potência do gerador agora. Roda d'água: constante (rio). Moinho: vento x altitude.
static func output(obj: PlacedObject) -> float:
	match obj.kind:
		"water_wheel":
			return OUTPUT.water_wheel
		"windmill":
			var wind: float = Weather.i.wind if Weather.i else 0.3
			var altitude := clampf(0.6 + obj.global_position.y / 80.0, 0.5, 1.4)
			return OUTPUT.windmill * wind * altitude
	return 0.0


## Tem trabalho agora? (só puxa energia quando tem material)
static func busy(obj: PlacedObject) -> bool:
	if Machines.PROCESS.has(obj.kind):
		return obj.extra.get("in", 0) >= Machines.PROCESS[obj.kind][1]
	return false


## Duas peças ligadas por portas encostadas?
static func touching(a: PlacedObject, b: PlacedObject) -> bool:
	for pa in world_ports(a):
		for pb in world_ports(b):
			if pa[0].distance_to(pb[0]) < PORT_SNAP:
				return true
	return false


## Host, 1x por segundo: monta as redes, divide a energia e avança as máquinas.
## Devolve {net_id: {"speed": v}} das peças cuja velocidade mudou (para mandar a todos).
static func tick(objects: Dictionary, clock: float) -> Dictionary:
	var parts: Array = objects.values().filter(func(o): return is_power(o.kind))
	var changed := {}
	var seen := {}
	for start in parts:
		if seen.has(start.net_id):
			continue
		# BFS pela rede.
		var group := [start]
		seen[start.net_id] = true
		var k := 0
		while k < group.size():
			var obj: PlacedObject = group[k]
			k += 1
			for other in parts:
				if seen.has(other.net_id):
					continue
				var belted: bool = other.net_id in obj.extra.get("belts", []) or obj.net_id in other.extra.get("belts", [])
				if belted or (obj.global_position.distance_to(other.global_position) < 4.0 and touching(obj, other)):
					seen[other.net_id] = true
					group.append(other)
		var supply := 0.0
		var demand := 0.0
		for obj in group:
			supply += output(obj)
			if busy(obj):
				demand += DEMAND.get(obj.kind, 0.0)
		var speed := 0.0 if supply <= 0.0 else (1.0 if demand <= 0.0 else minf(1.0, supply / demand))
		for obj in group:
			var spin := speed if not OUTPUT.has(obj.kind) else clampf(output(obj) / OUTPUT[obj.kind], 0.0, 1.0)
			if OUTPUT.has(obj.kind) == false and not busy(obj) and DEMAND.has(obj.kind):
				spin = 0.0 # máquina parada (sem material) não gira
			if absf(obj.extra.get("speed", 0.0) - spin) > 0.04:
				obj.extra.speed = spin
				changed[obj.net_id] = {"speed": spin}
			# A máquina com energia trabalha sozinha (igual a girar a manivela).
			if DEMAND.has(obj.kind) and busy(obj) and speed > 0.0:
				var before := [obj.extra.get("in", 0), obj.extra.get("out", 0)]
				Machines.host_crank(obj, speed, clock)
				if before != [obj.extra.get("in", 0), obj.extra.get("out", 0)]:
					changed[obj.net_id] = obj.extra.duplicate()
	return changed


# --- Correias (desenho) -------------------------------------------------------------

## Malha das correias: duas tiras escuras entre as polias de cada par ligado.
static func belt_mesh(objects: Dictionary) -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.color(Color(0.18, 0.12, 0.08))
	var done := {}
	for obj: PlacedObject in objects.values():
		for other_id in obj.extra.get("belts", []):
			var other: PlacedObject = objects.get(other_id)
			if other == null:
				continue
			var key := "%d_%d" % [mini(obj.net_id, other_id), maxi(obj.net_id, other_id)]
			if done.has(key):
				continue
			done[key] = true
			var a := _pulley(obj)
			var b := _pulley(other)
			var along := (b - a).normalized()
			var up := Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT
			for offset in [Vector3.UP * 0.09, Vector3.DOWN * 0.09]:
				var p0: Vector3 = a + offset
				var p1: Vector3 = b + offset
				var mid := (p0 + p1) * 0.5
				var length := p0.distance_to(p1)
				mb.box(mid, Vector3(0.05, 0.012, length), Basis.looking_at(p1 - p0, up))
	return mb.finish(PlacedObject._mat(), false)


## Onde a correia encaixa (a polia fica na primeira porta da peça).
static func _pulley(obj: PlacedObject) -> Vector3:
	var ports := world_ports(obj)
	return ports[0][0] if not ports.is_empty() else obj.global_position + Vector3.UP * 0.6
