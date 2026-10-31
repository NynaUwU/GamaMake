class_name CityCars
extends RefCounted
## Carros abandonados nas ruas das cidades: 1 nas vilas, 2 nas médias e 4 nas
## grandes, modelo e lugar sorteados pela semente da cidade (mesmos nomes em
## todos os jogadores, para a rede e o save). Ficam congelados até alguém chegar
## perto (VintageCar.parked).

const COUNT := {"small": 1, "medium": 2, "large": 4}


static func spawn(world: Node3D, terrain: TerrainWorld) -> void:
	var models := [AeroV12Car, BrutusCar, Chevy55Car, DarracqV8Car, HallScottCar, MormonMeteorCar]
	for i in terrain.cities.size():
		var city: Dictionary = terrain.cities[i]
		var streets: Array = city.streets.filter(func(s): return s.a.distance_to(s.b) > 14.0)
		if streets.is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = city.seed + 777
		var used: Array[Vector2] = []
		for k in COUNT.get(city.size, 1):
			for attempt in 8:
				var street: Dictionary = streets[rng.randi() % streets.size()]
				var dir: Vector2 = (street.b - street.a).normalized()
				var side := Vector2(-dir.y, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
				var at: Vector2 = street.a.lerp(street.b, rng.randf_range(0.2, 0.8)) + side * street.width * 0.25
				if used.any(func(u: Vector2): return u.distance_to(at) < 9.0):
					continue
				used.append(at)
				var car: VintageCar = models[rng.randi() % models.size()].new()
				car.name = "CarroCidade_%d_%d" % [i, k]
				car.parked = true
				car.freeze = true
				# Largado meio torto na rua, para um lado ou para o outro.
				var yaw := atan2(dir.x, dir.y) + (PI if rng.randf() < 0.5 else 0.0) + rng.randf_range(-0.35, 0.35)
				car.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, city.base + 1.0, at.y))
				world.add_child(car)
				break
