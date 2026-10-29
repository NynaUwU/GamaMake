extends SceneTree
## Teste do cajado: troca de arma, dispara um míssil num zumbi e confere a explosão.
var main: Node
var frame := 0
var z: Zombie
var player: Player
var start_pos: Vector3

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		player = main.get_node("Player")
		z = main.get_node("Enemies/Zombie1")
		z.detect_range = 0.0
		for other in main.get_node("Enemies").get_children():
			if other != z:
				other.global_position += Vector3(40, 0, 0)
		player.global_position = z.global_position + Vector3(1.5, 0, 9.0) # um pouco de lado: testa a curva
		player.rotation.y = 0.0
		player.equip_item(&"cajado")
		start_pos = z.global_position
	if frame == 30:
		print("weapon=", Player.WeaponType.keys()[player._weapon_type], " equip=", player._equip)
		player._cast_missile()
		print("missiles in scene: ", main.get_children().filter(func(n): return n is MagicMissile).size())
	if frame == 60:
		print("after missile: z state=", Zombie.State.keys()[z.state], " hp=", snappedf(z.health, 0.1),
			" explosions=", main.get_children().filter(func(n): return n is Explosion).size())
	if frame == 75:
		var hips := z.ragdoll.get_root_position()
		print("ragdoll moved: ", snappedf(hips.distance_to(start_pos + Vector3.UP), 0.01), "m, hips y=", snappedf(hips.y, 0.01))
	if frame == 90:
		quit()
	return false
