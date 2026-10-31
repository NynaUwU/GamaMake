class_name Lakes
extends RefCounted
## Lagos e lagoas do mapa. Sorteados pela semente (iguais para todos os
## jogadores), longe das cidades, da pista, das avenidas e da área inicial.
## O terreno afunda numa bacia até "depth" abaixo do nível da água (shape()),
## então a margem sempre fica na linha d'água.
##   lake  lago: raio 22-48 m, 5-9 m de fundo (tem atum)
##   pond  lagoa: raio 9-18 m, 2,5-4 m de fundo

const LAKES := 9
const PONDS := 16
const SHORE := 1.3 ## a borda da bacia vai até raio * SHORE


static func place(world: TerrainWorld) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed * 31 + 7
	var list := []
	var half := world.world_size * 0.42
	for want in [["lake", LAKES], ["pond", PONDS]]:
		var placed := 0
		var tries := 0
		while placed < want[1] and tries < want[1] * 40:
			tries += 1
			var kind: String = want[0]
			var r := rng.randf_range(22.0, 48.0) if kind == "lake" else rng.randf_range(9.0, 18.0)
			var c := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
			if not _free(world, list, c, r):
				continue
			var biome := world.biome_at(c.x, c.y)
			if biome.desert > 0.5 and rng.randf() > 0.15:
				continue # deserto quase sem água (às vezes um oásis)
			if biome.depth > 0.3:
				continue # nada de lago no alto das montanhas
			# Nível: um pouco abaixo da parte mais baixa da margem.
			var level := INF
			for k in 16:
				var a := TAU * k / 16.0
				var p := c + Vector2(cos(a), sin(a)) * r
				level = minf(level, world.raw_height(p.x, p.y, world.biome_at(p.x, p.y)))
			level -= 0.4
			var depth := rng.randf_range(5.0, 9.0) if kind == "lake" else rng.randf_range(2.5, 4.0)
			list.append({"center": c, "radius": r, "level": level, "depth": depth, "kind": kind,
				"seed": rng.randi(), "frozen": biome.winter > 0.6})
			placed += 1
	return list


static func _free(world: TerrainWorld, list: Array, c: Vector2, r: float) -> bool:
	if c.length() < world.town_radius * 3.0 + r:
		return false
	for city in world.cities:
		if c.distance_to(city.center) < city.radius * 1.9 + r * SHORE + 10.0:
			return false
	for lake in list:
		if c.distance_to(lake.center) < (lake.radius + r) * SHORE + 12.0:
			return false
	if not world.track.is_empty():
		for k in 9:
			var a := TAU * k / 8.0
			var p := c + (Vector2(cos(a), sin(a)) * r * SHORE if k < 8 else Vector2.ZERO)
			if RaceTrack.flatten_weight(world.track, p) > 0.0:
				return false
	for k in 9:
		var a := TAU * k / 8.0
		var p := c + (Vector2(cos(a), sin(a)) * r * SHORE if k < 8 else Vector2.ZERO)
		if not world.road_at(p.x, p.y).is_empty():
			return false
	return true


## Altura do terreno com as bacias dos lagos.
static func shape(lakes: Array, x: float, z: float, h: float) -> float:
	for lake in lakes:
		var r: float = lake.radius
		var dx: float = x - lake.center.x
		var dz: float = z - lake.center.y
		if absf(dx) > r * SHORE or absf(dz) > r * SHORE:
			continue
		var d := sqrt(dx * dx + dz * dz)
		if d > r * SHORE:
			continue
		var t := d / r
		var bowl: float = lake.level - lake.depth * maxf(1.0 - t * t, 0.0) - 0.15 # um pouco abaixo d'água na margem
		var blend := smoothstep(r * 0.85, r * SHORE, d)
		h = lerpf(minf(h, bowl), h, blend)
	return h


## Lago que contém o ponto (no plano), ou {}.
static func at(lakes: Array, x: float, z: float) -> Dictionary:
	for lake in lakes:
		if Vector2(x, z).distance_to(lake.center) < lake.radius:
			return lake
	return {}
