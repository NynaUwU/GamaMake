extends SceneTree
## Teste do mapa aberto: tempo de geração, biomas, alturas, cidade plana e neblina.
var main: Node
var frame := 0
var spots := {}

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	print("scene + initial terrain: ", Time.get_ticks_msec() - t0, " ms, chunks=", main.get_node("Terrain")._chunks.size())

func _physics_process(_d: float) -> bool:
	frame += 1
	var terrain: TerrainWorld = main.get_node("Terrain")
	var player: Player = main.get_node("Player")
	if frame == 2:
		var t0 := Time.get_ticks_usec()
		terrain._build_chunk(Vector2i(10, 10))
		print("one chunk: ", (Time.get_ticks_usec() - t0) / 1000.0, " ms")
		# Distribuição de biomas numa grade do mapa inteiro.
		var counts := {"desert": 0, "plains": 0, "winter": 0, "mountain": 0}
		var hmin := INF
		var hmax := -INF
		var step := 48.0
		var half := terrain.world_size * 0.5
		var x := -half
		while x < half:
			var z := -half
			while z < half:
				var b := terrain.biome_at(x, z)
				var best := "plains"
				for k in counts:
					if b[k] > b[best]:
						best = k
				counts[best] += 1
				if not spots.has(best) or randf() < 0.02:
					if Vector2(x, z).length() > 300.0 and absf(x) < half * 0.8 and absf(z) < half * 0.8 and b[best] > 0.9:
						spots[best] = Vector3(x, 0, z)
				var h := terrain.height_at(x, z)
				hmin = minf(hmin, h)
				hmax = maxf(hmax, h)
				z += step
			x += step
		var total := 0
		for k in counts:
			total += counts[k]
		for k in counts:
			print("  ", k, ": ", snappedf(100.0 * counts[k] / total, 0.1), "%")
		print("height range: ", snappedf(hmin, 0.1), " .. ", snappedf(hmax, 0.1))
		print("town center h=", snappedf(terrain.height_at(0, 0), 0.01), " at 30m=", snappedf(terrain.height_at(30, 10), 0.01))
		# Achatamento do deserto: variação de altura numa área de 200 m.
		if spots.has("desert"):
			var d: Vector3 = spots.desert
			var lo := INF
			var hi := -INF
			for i in 50:
				var hh := terrain.height_at(d.x + randf_range(-100, 100), d.z + randf_range(-100, 100))
				lo = minf(lo, hh)
				hi = maxf(hi, hh)
			print("desert relief over 200 m: ", snappedf(hi - lo, 0.1), " m")
		print("spots: ", spots)
	# Neblina em cada bioma (teleporta o player e espera a transição).
	var order := ["plains", "desert", "mountain", "winter"]
	for i in order.size():
		var f := 10 + i * 200
		if frame == f and spots.has(order[i]):
			var p: Vector3 = spots[order[i]]
			player.global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 1.0, p.z)
		if frame == f + 190 and spots.has(order[i]):
			var env: Environment = main.get_node("WorldEnvironment").environment
			print("fog in ", order[i], ": end=", snappedf(env.fog_depth_end, 1), " m, snow=", main.get_node("Atmosphere")._snow.emitting,
				" chunks=", terrain._chunks.size(), " spawned zombies=", main.get_node("ZombieSpawner")._zombies.size())
	if frame == 10 + order.size() * 200:
		quit()
	return false
