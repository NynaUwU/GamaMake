extends SceneTree
## Cidades: quantas, onde, tamanhos, altura dos prédios, tempo de construção.
var main: Node
var frame := 0

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	print("scene ready: ", Time.get_ticks_msec() - t0, " ms")

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		var terrain: TerrainWorld = main.get_node("Terrain")
		var counts := {}
		for c in terrain.cities:
			counts[c.size] = counts.get(c.size, 0) + 1
			var max_floors := 0
			for lot in c.lots:
				max_floors = maxi(max_floors, lot.floors)
			print("  ", c.size, " at ", c.center.snapped(Vector2.ONE), " base=", snappedf(c.base, 0.1), " houses=", c.lots.size(), " max floors=", max_floors, " (~", snappedf(max_floors * CityGen.FLOOR_HEIGHT, 1), " m)")
		print("cities: ", counts)
		# Constrói a maior cidade inteira e mede.
		var big: Dictionary = terrain.cities[0]
		var player: Player = main.get_node("Player")
		player.global_position = Vector3(big.center.x, big.base + 40, big.center.y)
		var t0 := Time.get_ticks_usec()
		var mgr: CityManager = main.get_node("Cities")
		mgr._update_cities(true)
		print("built large city in ", (Time.get_ticks_usec() - t0) / 1000.0, " ms")
		var house_t := Time.get_ticks_usec()
		var h := CityGen.build_house(big.lots[0])
		print("one tall house: ", (Time.get_ticks_usec() - house_t) / 1000.0, " ms, floors=", big.lots[0].floors)
		h.free()
		print("flatness: terrain at center=", snappedf(terrain.height_at(big.center.x, big.center.y), 0.1), " at r/2=", snappedf(terrain.height_at(big.center.x + big.radius * 0.5, big.center.y), 0.1))
	if frame == 10:
		quit()
	return false
