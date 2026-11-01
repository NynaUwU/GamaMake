class_name Rivers
extends RefCounted
## Rios do mapa (sorteados pela semente: iguais para todos). Cada um nasce num
## lago e desce o relevo em passos de 24 m até ~700 m, parando antes de cidades,
## da pista e das avenidas. O nível da água só desce ao longo do rio; o terreno
## é cavado num leito (shape()) e a água é uma faixa (WaterManager).
## Água corrente: a roda d'água e o carneiro hidráulico só funcionam na beira.

const COUNT := 5
const STEP := 24.0
const MAX_STEPS := 30
const CELL := 64.0 ## grade de busca dos trechos


## Lista de rios: {"points": PackedVector2Array, "levels": PackedFloat32Array, "width": float, "depth": float}
static func place(world: TerrainWorld) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed * 53 + 11
	var list := []
	var sources: Array = world.lakes.filter(func(l): return l.kind == "lake" and not l.frozen)
	var order := range(sources.size())
	for i in order.size():
		var j := rng.randi_range(i, order.size() - 1)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for index in order:
		if list.size() >= COUNT:
			break
		var lake: Dictionary = sources[index]
		var river := _trace(world, lake, rng, list)
		if not river.is_empty():
			list.append(river)
	return list


static func _trace(world: TerrainWorld, lake: Dictionary, rng: RandomNumberGenerator, others: Array) -> Dictionary:
	var a := rng.randf() * TAU
	var dir := Vector2(cos(a), sin(a))
	var start: Vector2 = lake.center + dir * (lake.radius * 0.8)
	var points := PackedVector2Array([start])
	var levels := PackedFloat32Array([lake.level])
	var half := world.world_size * 0.47
	var p := start
	for step in MAX_STEPS:
		# Escolhe, entre algumas direções perto da atual, a que desce mais (com um pouco de curva).
		var best := Vector2.ZERO
		var best_h := INF
		for k in 5:
			var turn := (k - 2) * 0.35 + rng.randf_range(-0.15, 0.15)
			var d := dir.rotated(turn)
			var q := p + d * STEP
			var h := world.raw_height(q.x, q.y, world.biome_at(q.x, q.y)) + absf(turn) * 1.5
			if h < best_h:
				best_h = h
				best = d
		var next := p + best * STEP
		if absf(next.x) > half or absf(next.y) > half or not _clear(world, next, lake, others):
			break
		var level := minf(levels[levels.size() - 1] - 0.05, world.raw_height(next.x, next.y, world.biome_at(next.x, next.y)) - 0.9)
		points.append(next)
		levels.append(level)
		p = next
		dir = best
	if points.size() < 8:
		return {}
	return {"points": points, "levels": levels, "width": rng.randf_range(6.0, 9.0), "depth": rng.randf_range(1.6, 2.4)}


static func _clear(world: TerrainWorld, p: Vector2, source: Dictionary, others: Array) -> bool:
	if p.length() < world.town_radius * 3.0:
		return false
	for city in world.cities:
		if p.distance_to(city.center) < city.radius * 2.0 + 15.0:
			return false
	for lake in world.lakes:
		if lake != source and p.distance_to(lake.center) < lake.radius * Lakes.SHORE + 10.0:
			return false
	if not world.track.is_empty() and RaceTrack.flatten_weight(world.track, p) > 0.0:
		return false
	for k in 5:
		var q := p + Vector2(cos(k * 1.3), sin(k * 1.3)) * 12.0 * (1.0 if k > 0 else 0.0)
		if not world.road_at(q.x, q.y).is_empty():
			return false
	for river in others:
		for q in river.points:
			if p.distance_to(q) < 30.0:
				return false
	return true


## Grade célula -> trechos [rio, índice] que passam perto (busca rápida no terreno).
static func index(rivers: Array) -> Dictionary:
	var grid := {}
	for r in rivers.size():
		var river: Dictionary = rivers[r]
		var reach: float = river.width * 0.5 + FLOODPLAIN + 2.0
		for i in river.points.size() - 1:
			var a: Vector2 = river.points[i]
			var b: Vector2 = river.points[i + 1]
			var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * reach
			var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * reach
			for cx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
				for cz in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
					var key := Vector2i(cx, cz)
					if not grid.has(key):
						grid[key] = []
					grid[key].append([r, i])
	return grid


## Trecho mais perto: {"river", "i", "t", "dist", "level", "half", "dir"} ou {}.
static func nearest(rivers: Array, grid: Dictionary, x: float, z: float) -> Dictionary:
	var p := Vector2(x, z)
	var best := {}
	for entry in grid.get(Vector2i(floori(x / CELL), floori(z / CELL)), []):
		var river: Dictionary = rivers[entry[0]]
		var i: int = entry[1]
		var a: Vector2 = river.points[i]
		var b: Vector2 = river.points[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if best.is_empty() or d < best.dist:
			best = {"river": entry[0], "i": i, "t": t, "dist": d, "half": river.width * 0.5, "depth": river.depth,
				"level": lerpf(river.levels[i], river.levels[i + 1], t), "dir": ab.normalized()}
	return best


## Altura do terreno com o leito cavado (chamado depois dos lagos).
const FLOODPLAIN := 32.0 ## até onde a margem é suavizada de cada lado


static func shape(rivers: Array, grid: Dictionary, x: float, z: float, h: float) -> float:
	var near := nearest(rivers, grid, x, z)
	if near.is_empty():
		return h
	var half: float = near.half
	var d: float = near.dist
	if d > half + FLOODPLAIN:
		return h
	if d < half:
		var u := d / half
		return minf(h, near.level - near.depth * maxf(1.0 - u * u, 0.0) - 0.2) # leito
	# Várzea: perto da água o chão fica quase plano, só um pouco acima do nível,
	# e vai voltando ao relevo normal até FLOODPLAIN metros da margem.
	var bank: float = near.level + 0.35 + (d - half) * 0.02
	return lerpf(bank, h, smoothstep(half + 8.0, half + FLOODPLAIN, d)) # ~8 m quase planos, depois sobe suave


## Ponto dentro da água de algum rio: {"level", "dir"} ou {}.
static func water_at(rivers: Array, grid: Dictionary, x: float, z: float) -> Dictionary:
	var near := nearest(rivers, grid, x, z)
	if near.is_empty() or near.dist > near.half:
		return {}
	return near
