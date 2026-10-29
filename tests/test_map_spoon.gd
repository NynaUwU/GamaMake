extends SceneTree
## Mapa gerado, colherona arremessa zumbi, esterço menor em alta velocidade.
var main: Node
var frame := 0
var t0 := 0

func _initialize() -> void:
	t0 = Time.get_ticks_msec()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	frame += 1
	var map: WorldMap = main.get_node("HUD/Root/WorldMap")
	var player: Player = main.get_node("Player")
	if frame == 2:
		player.equip_item(&"colher")
		var z: Zombie = main.get_node("Enemies/Zombie1")
		z.detect_range = 0.0
		z.max_health = 1000.0
		z.health = 1000.0
	if frame == 30:
		var z: Zombie = main.get_node("Enemies/Zombie1")
		var before := z.global_position
		z.take_hit(HitInfo.make(20, &"Chest", z.global_position + Vector3.UP, Vector3(0, 0, -1), 95, HitInfo.Type.BLUNT))
		print("spoon hit: state=", Zombie.State.keys()[z.state], " weapon=", Player.WeaponType.keys()[player._weapon_type])
	if map._texture != null and t0 > 0:
		print("map ready after ", Time.get_ticks_msec() - t0, " ms, size=", map._texture.get_size())
		t0 = 0
	if frame == 400:
		var car: VintageCar = main.get_node("Carro")
		print("steer limit at 0/50/100 km/h: ", [0.0, 13.9, 27.8].map(func(v): return snappedf(car.max_steer * lerpf(1.0, 0.15, smoothstep(0.1, 0.75, v / car.top_speed)), 0.01)))
		quit()
	return false
