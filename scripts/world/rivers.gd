class_name Rivers
extends RefCounted
## Rios do mapa (sorteados pela semente: iguais para todos). Cada um nasce num
## lago (ou numa nascente nos morros) e desce o relevo em passos de 24 m até
## chegar ao mar, desviando de cidades, da pista e das avenidas. Rio que não
## acha caminho até o mar é descartado. O nível da água só desce ao longo do
## rio; o terreno é cavado num leito (shape()) e a água é uma faixa (WaterManager).
## Água corrente: a roda d'água e o carneiro hidráulico só funcionam na beira.

## Quantos rios: WorldSettings "rivers" (padrão 5).
const STEP := 24.0
const MAX_STEPS := 120
const CELL := 64.0 ## grade de busca dos trechos


## Lista de rios: {"points": PackedVector2Array, "levels": PackedFloat32Array, "width": float, "depth": float}
static func place(world: TerrainWorld) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed * 53 + 11
	var list := []
	var want := roundi(WorldSettings.get_value("rivers"))
	if want <= 0:
		return list
	var sources: Array = world.lakes.filter(func(l): return l.kind == "lake" and not l.frozen)
	_shuffle(sources, rng)
	# Nascentes nos morros (se os lagos não bastarem).
	var springs := []
	var half := world.world_size * 0.4
	for attempt in 300:
		if springs.size() >= want * 3:
			break
		var c := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		var biome := world.biome_at(c.x, c.y)
		var h := world.raw_height(c.x, c.y, biome)
		if h < 12.0 or biome.depth > 0.4 or biome.winter > 0.6 or world.coast_distance(c.x, c.y) < 350.0:
			continue
		if world.city_mask(c.x, c.y) > 0.0:
			continue
		springs.append({"center": c, "radius": 0.0, "level": h - 0.9})
	sources.append_array(springs)
	for source in sources:
		if list.size() >= want:
			break
		var river := _trace(world, source, rng, list)
		if not river.is_empty():
			list.append(river)
	return list


static func _shuffle(array: Array, rng: RandomNumberGenerator) -> void:
	for i in array.size():
		var j := rng.randi_range(i, array.size() - 1)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp


static func _height(world: TerrainWorld, q: Vector2) -> float:
	return world.raw_height(q.x, q.y, world.biome_at(q.x, q.y))


static func _trace(world: TerrainWorld, lake: Dictionary, rng: RandomNumberGenerator, others: Array) -> Dictionary:
	var a := rng.randf() * TAU
	var dir := Vector2(cos(a), sin(a))
	var start: Vector2 = lake.center + dir * (lake.radius * 0.8)
	var points := PackedVector2Array([start])
	var levels := PackedFloat32Array([lake.level])
	var p := start
	for step in MAX_STEPS:
		# Entre algumas direções perto da atual, a que desce mais (com um pouco de
		# curva e puxando de leve para fora, rumo ao mar). Direção bloqueada é pulada.
		var best := Vector2.ZERO
		var best_score := INF
		var outward := p.normalized() if p.length() > 1.0 else dir
		for k in 7:
			var turn := (k - 3) * 0.3 + rng.randf_range(-0.12, 0.12)
			var d := dir.rotated(turn)
			var q := p + d * STEP
			var in_sea := world.coast_distance(q.x, q.y) < 0.0
			if not in_sea and not _clear(world, q, lake, others, points):
				continue
			var score := _height(world, q) + absf(turn) * 1.5 - d.dot(outward) * 3.0
			if score < best_score:
				best_score = score
				best = d
		if best == Vector2.ZERO:
			return {} # sem saída: descarta
		var next := p + best * STEP
		var level := minf(levels[levels.size() - 1] - 0.05, _height(world, next) - 0.9)
		level = maxf(level, TerrainWorld.SEA_LEVEL) # desemboca no nível do mar
		points.append(next)
		levels.append(level)
		p = next
		dir = best
		if world.coast_distance(next.x, next.y) < -25.0:
			if points.size() < 8:
				return {}
			return {"points": points, "levels": levels, "width": rng.randf_range(6.0, 9.0), "depth": rng.randf_range(1.6, 2.4)}
	return {} # não chegou ao mar


static func _clear(world: TerrainWorld, p: Vector2, source: Dictionary, others: Array, own := PackedVector2Array()) -> bool:
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
	for i in own.size() - 2: # não volta sobre si mesmo
		if p.distance_to(own[i]) < STEP * 0.9:
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
	# Só rebaixa: perto de lagos (ou de baixadas) o chão não sobe e não tampa a ligação com a água.
	return minf(h, lerpf(bank, h, smoothstep(half + 8.0, half + FLOODPLAIN, d))) # ~8 m quase planos, depois sobe suave


## Ponto dentro da água de algum rio: {"level", "dir"} ou {}.
static func water_at(rivers: Array, grid: Dictionary, x: float, z: float) -> Dictionary:
	var near := nearest(rivers, grid, x, z)
	if near.is_empty() or near.dist > near.half:
		return {}
	return near
