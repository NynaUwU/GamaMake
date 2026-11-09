class_name Power
extends RefCounted
## Força rotacional (no estilo do Create, sem a parte de velocidade). Geradores dão
## FORÇA (capacidade); máquinas trabalhando pedem CARGA. Numa rede ligada:
##   - força 0                 -> nada gira ("none")
##   - carga maior que a força -> sobrecarga: tudo para ("over")
##   - senão                   -> tudo gira a 100% ("ok"); quem tem trabalho trabalha
## Peças que ligam a rede (PowerParts):
##   axle      eixo de qualquer tamanho (arrastar com o item "eixo"); liga pelas pontas
##   tripod    tripé: nasce sozinho na ponta solta de um eixo; outro eixo continua dele
##   cog       engrenagem montada num eixo, tripé ou porta de máquina: vira a força em 90°
##             (duas engrenagens cônicas encostadas; giram ao contrário uma da outra).
##             Eixos paralelos se ligam por polia + esteira, não por engrenagem.
##   pulley    polia montada no meio de um eixo; a esteira liga polia <-> polia ou
##             polia <-> máquina (na polia de latão da porta)
##   shaft     eixo antigo de 2 m (saves velhos)
## Máquinas e geradores se ligam pela porta de latão (PORTS): ponta de eixo, tripé,
## engrenagem ou esteira encostada ali. Portas de duas máquinas encostadas também.
## O host recalcula a força 1x por segundo; a forma da rede só quando algo muda.

const BELT_RANGE := 10.0
const SNAP := 0.3 ## pontas/portas a até isso se ligam
const MOUNT := 0.12 ## centro da engrenagem/polia a até isso da linha do eixo = montada
## Geradores: força máxima.
const OUTPUT := {"water_wheel": 4.0, "windmill": 6.0, "steam_engine": 10.0, "electric_motor": 4.0}
## Consumidores: carga quando têm trabalho.
const DEMAND := {"sawmill": 3.0, "quern": 1.0, "spinning": 1.0, "loom": 1.5, "blast_furnace": 2.0, "lathe": 2.0, "press": 1.5,
	"dynamo": 2.0, # = Electric.DYNAMO_LOAD
	"sieve": 1.0, "stone_furnace": 1.5, "grindstone": 1.0, "pump": 1.0, "rotisserie": 0.5}
## Bancadas com energia (torno, prensa): giram sempre que a rede tem força, mas só
## pedem carga nos segundos depois de fabricar algo (extra.used).
const STATIONS := ["lathe", "press"]
## Portas em espaço local: [posição, eixo].
const PORTS := {
	"shaft": [[Vector3(1.0, 0.6, 0), Vector3.RIGHT], [Vector3(-1.0, 0.6, 0), Vector3.LEFT]],
	"water_wheel": [[Vector3(1.05, 0.6, 0), Vector3.RIGHT]],
	"windmill": [[Vector3(0, 0.6, 0.85), Vector3.BACK]],
	"sawmill": [[Vector3(-1.15, 0.6, 0), Vector3.LEFT]],
	"quern": [[Vector3(-0.55, 0.6, 0), Vector3.LEFT]],
	"spinning": [[Vector3(-0.65, 0.6, 0), Vector3.LEFT]],
	"loom": [[Vector3(-0.8, 0.6, 0), Vector3.LEFT]],
	"steam_engine": [[Vector3(1.08, 0.6, 0), Vector3.RIGHT]],
	"blast_furnace": [[Vector3(-1.0, 0.6, 0), Vector3.LEFT]],
	"lathe": [[Vector3(-0.98, 0.6, 0), Vector3.LEFT]], # na polia de latão do modelo
	"press": [[Vector3(-0.84, 0.6, 0), Vector3.LEFT]],
	"dynamo": [[Vector3(-0.7, 0.6, 0), Vector3.LEFT]], # na polia de latão do eixo
	"electric_motor": [[Vector3.ZERO, Vector3.LEFT]], # encaixado na porta da máquina (corpo para +X)
	# Máquinas que eram só na mão (AutoMachines): porta de latão nova do lado esquerdo.
	"sieve": [[Vector3(-0.58, 0.6, 0), Vector3.LEFT]],
	"stone_furnace": [[Vector3(-0.9, 0.6, 0), Vector3.LEFT]],
	"grindstone": [[Vector3(-0.56, 0.6, 0), Vector3.LEFT]],
	"pump": [[Vector3(-0.4, 0.6, 0), Vector3.LEFT]],
	"rotisserie": [[Vector3(-0.86, 0.6, 0), Vector3.LEFT]],
}
const PARTS := ["axle", "tripod", "cog", "pulley"]
const COG_RADIUS := {"cog": 0.3}
const PULLEY_RADIUS := 0.2

## Forma da rede guardada (refeita quando algo é posto/tirado: dirty = true).
static var dirty := true
static var _groups: Array = [] # [[net_id, ...], ...]
static var _dir := {} # net_id -> 1/-1 (sentido de giro visual)


static func is_power(kind: String) -> bool:
	return PORTS.has(kind) or kind in PARTS


static func is_machine(kind: String) -> bool:
	return PORTS.has(kind) and kind != "shaft"


## Portas no mundo: [[posição, direção], ...].
static func world_ports(obj: PlacedObject) -> Array:
	var list := []
	for port in PORTS.get(obj.kind, []):
		list.append([obj.global_transform * port[0], obj.global_basis * port[1]])
	return list


## Pontas do eixo no mundo [A, B].
static func axle_ends(obj: PlacedObject) -> Array:
	return [obj.global_position, obj.global_transform * Vector3(0, 0, obj.extra.get("len", 1.0))]


## Pontos de ligação de uma peça (no mundo).
static func points(obj: PlacedObject) -> Array:
	match obj.kind:
		"axle":
			return axle_ends(obj)
		"tripod", "cog", "pulley":
			return [obj.global_position]
	var list := []
	for port in world_ports(obj):
		list.append(port[0])
	return list


## Ponto mais perto onde um eixo novo encaixaria (porta, tripé, ponta de eixo,
## engrenagem/polia) ou INF.
static func snap_point(objects: Dictionary, point: Vector3, radius: float) -> Vector3:
	var best := Vector3.INF
	var best_d := radius
	for value in objects.values():
		if not is_instance_valid(value) or not is_power(value.kind):
			continue
		var obj: PlacedObject = value
		if obj.global_position.distance_to(point) > 12.0:
			continue
		for p: Vector3 in points(obj):
			var d := p.distance_to(point)
			if d < best_d:
				best_d = d
				best = p
	return best


## Ponto da linha do eixo mais perto de "p" (e a distância até ela).
static func closest_on_axle(axle: PlacedObject, p: Vector3) -> Vector3:
	var ends := axle_ends(axle)
	return Geometry3D.get_closest_point_to_segment(p, ends[0], ends[1])


## Direção (eixo de giro) de uma peça no mundo.
static func spin_axis(obj: PlacedObject) -> Vector3:
	match obj.kind:
		"axle", "cog", "pulley":
			return obj.global_basis.z.normalized()
	var ports := world_ports(obj)
	return ports[0][1].normalized() if not ports.is_empty() else Vector3.RIGHT


## Ponto e raio onde a esteira passa numa peça (polia ou porta da máquina).
static func belt_anchor(obj: PlacedObject) -> Array:
	if obj.kind == "pulley":
		return [obj.global_position, PULLEY_RADIUS]
	var ports := world_ports(obj)
	return [ports[0][0] if not ports.is_empty() else obj.global_position + Vector3.UP * 0.6, 0.1]


static func belt_ok(a: PlacedObject, b: PlacedObject) -> bool:
	if a == b or not (a.kind == "pulley" or is_machine(a.kind)) or not (b.kind == "pulley" or is_machine(b.kind)):
		return false
	if a.kind != "pulley" and b.kind != "pulley":
		return false # pelo menos uma ponta é polia
	var pa: Vector3 = belt_anchor(a)[0]
	var pb: Vector3 = belt_anchor(b)[0]
	if pa.distance_to(pb) > BELT_RANGE or pa.distance_to(pb) < 0.5:
		return false
	return absf(spin_axis(a).dot(spin_axis(b))) > 0.85 # polias paralelas


# --- Gerar / consumir ---------------------------------------------------------------

## Força do gerador agora. Roda d'água: constante (rio). Moinho: vento x altitude.
static func output(obj: PlacedObject) -> float:
	match obj.kind:
		"water_wheel":
			return OUTPUT.water_wheel
		"windmill":
			var wind: float = Weather.i.wind if Weather.i else 0.3
			var altitude := clampf(0.6 + obj.global_position.y / 80.0, 0.5, 1.4)
			return OUTPUT.windmill * wind * altitude
		"steam_engine":
			return OUTPUT.steam_engine * clampf(obj.extra.get("steam", 0.0), 0.0, 1.0) # vapor da caldeira
		"electric_motor":
			# Com energia; não move dínamo (nada de moto-contínuo).
			if not Electric.powered(obj):
				return 0.0
			var manager := obj.get_parent() as PlacedManager
			if manager:
				for id in group_of(obj.net_id):
					var other: PlacedObject = manager.objects.get(id)
					if other and other.kind == "dynamo":
						return 0.0
			return OUTPUT.electric_motor
	return 0.0


## Tem trabalho agora? (só pede carga quando tem material)
static func busy(obj: PlacedObject) -> bool:
	if Machines.PROCESS.has(obj.kind):
		return obj.extra.get("in", 0) >= Machines.PROCESS[obj.kind][1]
	if obj.kind in STATIONS:
		var manager := obj.get_parent() as PlacedManager
		return manager != null and obj.extra.get("used", 0.0) > manager.clock
	match obj.kind:
		"dynamo":
			return obj.extra.get("draw", false) # gerando para a rede elétrica (Electric.tick)
		"stone_furnace":
			if ContainerManager.i == null:
				return false
			var slots: Array = ContainerManager.i.contents.get(Smelting.key_of(obj), [])
			return slots.size() > 0 and not slots[Smelting.INPUT].is_empty() # tem minério: o fole sopra
		"grindstone":
			return AutoMachines.grinding(obj)
		"pump":
			return true # bomba: sempre puxando água para o cano
		"rotisserie":
			# O espeto gira enquanto o fogo está aceso (dá para pôr a comida com ele girando).
			var manager := obj.get_parent() as PlacedManager
			return manager != null and obj.is_lit(manager.clock)
	if obj.kind == "blast_furnace" and ContainerManager.i:
		var slots: Array = ContainerManager.i.contents.get(Smelting.key_of(obj), [])
		return slots.size() > 0 and not slots[Smelting.INPUT].is_empty() # tem ferro para virar aço
	return false


## Duas peças ligadas por portas/pontas encostadas?
static func touching(a: PlacedObject, b: PlacedObject) -> bool:
	for pa: Vector3 in points(a):
		for pb: Vector3 in points(b):
			if pa.distance_to(pb) < SNAP:
				return true
	return false


# --- Forma da rede -----------------------------------------------------------------

## Monta as redes (grupos ligados) e o sentido de giro de cada peça.
static func build(objects: Dictionary) -> void:
	dirty = false
	var parts: Array = []
	for value in objects.values():
		if is_instance_valid(value) and is_power(value.kind):
			parts.append(value)
	var n := parts.size()
	var index := {}
	for i in n:
		index[parts[i].net_id] = i
	var edges := [] # [i, j, inverte?]
	# 1) Pontos encostados (grade de 1 m para não comparar tudo com tudo).
	var grid := {}
	for i in n:
		for p: Vector3 in points(parts[i]):
			var cell := Vector3i(p.floor())
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						for entry in grid.get(cell + Vector3i(dx, dy, dz), []):
							if entry[0] != i and entry[1].distance_to(p) < SNAP:
								edges.append([i, entry[0], false])
			if not grid.has(cell):
				grid[cell] = []
			grid[cell].append([i, p])
	# 2) Engrenagem/polia montada no meio de um eixo; 3) engrenagens encostadas.
	var axles := []
	var hubs := []
	for i in n:
		if parts[i].kind == "axle":
			axles.append(i)
		elif parts[i].kind in ["cog", "pulley"]:
			hubs.append(i)
	for h in hubs:
		var hub: PlacedObject = parts[h]
		for a in axles:
			var axle: PlacedObject = parts[a]
			if axle.global_position.distance_to(hub.global_position) > axle.extra.get("len", 1.0) + 1.0:
				continue
			if closest_on_axle(axle, hub.global_position).distance_to(hub.global_position) < MOUNT:
				edges.append([h, a, false])
	for x in hubs.size():
		var ca: PlacedObject = parts[hubs[x]]
		if not COG_RADIUS.has(ca.kind):
			continue
		for y in range(x + 1, hubs.size()):
			var cb: PlacedObject = parts[hubs[y]]
			if COG_RADIUS.has(cb.kind) and engaged(ca, cb):
				edges.append([hubs[x], hubs[y], true]) # engrenadas: giram ao contrário
	# 4) Esteiras.
	for i in n:
		for other_id in parts[i].extra.get("belts", []):
			if index.has(other_id):
				edges.append([i, index[other_id], false])
	# Grupos e sentido (BFS).
	var links := []
	links.resize(n)
	for i in n:
		links[i] = []
	for e in edges:
		links[e[0]].append([e[1], e[2]])
		links[e[1]].append([e[0], e[2]])
	_groups = []
	_dir = {}
	var seen := {}
	for start in n:
		if seen.has(start):
			continue
		var group := [parts[start].net_id]
		seen[start] = 1
		var queue := [start]
		while not queue.is_empty():
			var cur: int = queue.pop_back()
			for link in links[cur]:
				if seen.has(link[0]):
					continue
				seen[link[0]] = -seen[cur] if link[1] else seen[cur]
				group.append(parts[link[0]].net_id)
				queue.append(link[0])
		_groups.append(group)
	for i in seen:
		_dir[parts[i].net_id] = seen[i]


## Engrenagens engatadas de verdade: eixos a 90° e os aros se tocando (cônicas, com
## os eixos se cruzando ou uma de quina na outra), sem uma estar dentro da outra.
## Lado a lado (eixos paralelos) não conta: para isso tem polia + esteira.
static func engaged(a: PlacedObject, b: PlacedObject) -> bool:
	var ra: float = COG_RADIUS[a.kind]
	var rb: float = COG_RADIUS[b.kind]
	var ua := a.global_basis.z.normalized()
	var ub := b.global_basis.z.normalized()
	if absf(ua.dot(ub)) > 0.2:
		return false
	var d := a.global_position.distance_to(b.global_position)
	if d > ra + rb + 0.15 or d < 0.8 * maxf(ra, rb):
		return false
	return rim_gap(a.global_position, ua, ra, b.global_position, ub, rb) < 0.08


## Quanto falta para o aro de A encostar no aro de B (0 = encostados).
static func rim_gap(ca: Vector3, ua: Vector3, ra: float, cb: Vector3, ub: Vector3, rb: float) -> float:
	var e1 := ua.cross(Vector3.UP if absf(ua.y) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := ua.cross(e1)
	var best := INF
	for k in 36:
		var ang := TAU * k / 36.0
		var q := ca + (e1 * cos(ang) + e2 * sin(ang)) * ra - cb
		var axial := q.dot(ub)
		best = minf(best, Vector2(axial, (q - ub * axial).length() - rb).length())
	return best


## Engrenagem nova no eixo (A0 + t*dir, raio r): pontos t onde ela engata numa
## engrenagem que já existe por perto. Devolve [t, engrenagem] ou [].
static func mesh_spot(objects: Dictionary, a0: Vector3, dir: Vector3, length: float, r: float, near_t: float) -> Array:
	var best := []
	var best_off := 0.9 # só puxa até 0,9 m da mira
	for value in objects.values():
		if not is_instance_valid(value) or not COG_RADIUS.has(value.kind):
			continue
		var g: PlacedObject = value
		if g.global_position.distance_to(a0 + dir * near_t) > 2.5:
			continue
		var rg: float = COG_RADIUS[g.kind]
		var ug := g.global_basis.z.normalized()
		if absf(dir.dot(ug)) > 0.2:
			continue # só engata a 90°
		var tc := (g.global_position - a0).dot(dir)
		for t_raw in [tc, tc + rg, tc - rg, tc + r, tc - r]:
			if t_raw < -0.02 or t_raw > length + 0.02:
				continue
			var t := clampf(t_raw, 0.0, length) # (conta de ponto flutuante na ponta do eixo)
			if absf(t - near_t) > best_off:
				continue
			var p: Vector3 = a0 + dir * t
			var d: float = p.distance_to(g.global_position)
			if d < 0.8 * maxf(r, rg) or d > r + rg + 0.15:
				continue
			if rim_gap(p, dir, r, g.global_position, ug, rg) < 0.06:
				best_off = absf(t - near_t)
				best = [t, g]
	return best


## Grupo (rede) de uma peça, para testes e para o painel.
static func group_of(net_id: int) -> Array:
	for g in _groups:
		if net_id in g:
			return g
	return []


# --- Tick (host) ----------------------------------------------------------------------

## Host, 1x por segundo: força e carga de cada rede; máquinas com trabalho e força
## trabalham. Devolve {net_id: extra mudado} para mandar a todos.
static func tick(objects: Dictionary, clock: float) -> Dictionary:
	if dirty:
		build(objects)
	var changed := {}
	for group in _groups:
		var members := []
		var supply := 0.0
		var demand := 0.0
		for id in group:
			var obj: PlacedObject = objects.get(id)
			if not is_instance_valid(obj):
				continue
			members.append(obj)
			supply += output(obj)
			if busy(obj):
				demand += DEMAND.get(obj.kind, 0.0)
		var state := "none" if supply <= 0.01 else ("over" if demand > supply + 0.01 else "ok")
		for obj: PlacedObject in members:
			var spin := 1.0 if state == "ok" else 0.0
			if OUTPUT.has(obj.kind):
				spin = 1.0 if output(obj) > 0.01 and state != "over" else 0.0 # gerador gira com vento/rio/vapor
			var update := {}
			if absf(obj.extra.get("speed", 0.0) - spin) > 0.01:
				update.speed = spin
			if obj.extra.get("pstate", "") != state:
				update.pstate = state
			var dir: int = _dir.get(obj.net_id, 1)
			if obj.extra.get("dir", 1) != dir:
				update.dir = dir
			if obj.kind == "grindstone" and obj.extra.get("driven", false) != (members.size() > 1):
				update.driven = members.size() > 1 # tem eixo/motor na porta (mesmo parado)
			if is_machine(obj.kind):
				var load := [snappedf(demand, 0.1), snappedf(supply, 0.1)]
				if obj.extra.get("load", []) != load:
					update.load = load
			if not update.is_empty():
				obj.extra.merge(update, true)
				changed[obj.net_id] = update
			# A máquina com força trabalha sozinha (igual a girar a manivela).
			if state == "ok" and obj.kind in ["stone_furnace", "grindstone"] and busy(obj):
				if obj.kind == "stone_furnace":
					Machines.host_crank(obj, 1.0, clock) # o fole sopra sozinho
				else:
					AutoMachines.host_grind(obj)
				changed[obj.net_id] = obj.extra.duplicate()
			if state == "ok" and Machines.PROCESS.has(obj.kind) and busy(obj):
				var before := [obj.extra.get("in", 0), obj.extra.get("out", 0)]
				Machines.host_crank(obj, 1.0, clock)
				if before != [obj.extra.get("in", 0), obj.extra.get("out", 0)]:
					changed[obj.net_id] = obj.extra.duplicate()
	return changed


## Linha de estado para o painel da máquina ("força 3 de 6", "sobrecarga!", "sem força").
static func status(obj: PlacedObject) -> String:
	var load: Array = obj.extra.get("load", [0.0, 0.0])
	match obj.extra.get("pstate", "none"):
		"ok":
			if OUTPUT.has(obj.kind):
				return "carga %s de %s" % [_num(load[0]), _num(load[1])]
			return "força: carga %s de %s" % [_num(load[0]), _num(load[1])]
		"over":
			return "SOBRECARGA! carga %s de %s" % [_num(load[0]), _num(load[1])]
	return "sem força (ligue eixo, engrenagem ou esteira na porta de latão)" if not OUTPUT.has(obj.kind) else "parado"


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


# --- Esteiras (desenho) ---------------------------------------------------------------

## Malha das esteiras: duas tiras escuras tangentes às polias de cada par ligado.
static func belt_mesh(objects: Dictionary) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var done := {}
	for value in objects.values():
		if not is_instance_valid(value):
			continue
		var obj: PlacedObject = value
		for other_id in obj.extra.get("belts", []):
			var other: PlacedObject = objects.get(other_id)
			if other == null or not is_instance_valid(other):
				continue
			var key := "%d_%d" % [mini(obj.net_id, other_id), maxi(obj.net_id, other_id)]
			if done.has(key):
				continue
			done[key] = true
			var a := belt_anchor(obj)
			var b := belt_anchor(other)
			var axis := spin_axis(obj)
			var d: Vector3 = b[0] - a[0]
			d -= axis * d.dot(axis)
			if d.length() < 0.05:
				continue
			var n := axis.cross(d.normalized()).normalized()
			for side in [1.0, -1.0]:
				var p0: Vector3 = a[0] + n * a[1] * side
				var p1: Vector3 = b[0] + n * b[1] * side
				var up := axis if absf(axis.dot((p1 - p0).normalized())) < 0.95 else Vector3.UP
				mb.color(Color(0.2, 0.13, 0.08) if side > 0 else Color(0.16, 0.1, 0.06))
				mb.box((p0 + p1) * 0.5, Vector3(0.016, 0.09, p0.distance_to(p1)), Basis.looking_at(p1 - p0, up)) # largura ao longo do eixo, fina para fora
	return mb.finish(PlacedObject._mat(), false)
