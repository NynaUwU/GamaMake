extends SceneTree
## Teste da bateria da lanterna e do carregador: clicar rápido carrega,
## devagar não; a luz gasta a bateria e apaga quando acaba.
var main: Node
var frame := 0
var player: Player

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		player = main.get_node("Player")
		player.inventory.add(&"lanterna")
		player.equip_item(&"carregador")
		player.flashlight_charge = 0.2
	if frame == 30:
		print("holding=", Player.WeaponType.keys()[player._weapon_type], " charge=", snappedf(player.flashlight_charge, 0.001))
	# Bem devagar: 1 clique a cada 1,5 s durante 4 s.
	if frame > 30 and frame <= 270 and frame % 90 == 0:
		player._crank()
	if frame == 270:
		print("slow cranking 4s: charge=", snappedf(player.flashlight_charge, 0.001))
	# Rápido: 8 cliques por segundo durante 4 s.
	if frame > 270 and frame <= 510 and frame % 8 == 0:
		player._crank()
	if frame == 510:
		print("fast cranking 4s: charge=", snappedf(player.flashlight_charge, 0.001))
		player.battery_duration = 2.0
		player._toggle_flashlight()
		print("flashlight on=", player.is_flashlight_on())
	if frame == 700:
		print("after drain: on=", player.is_flashlight_on(), " charge=", player.flashlight_charge)
		player._toggle_flashlight()
		print("try turn on empty: on=", player.is_flashlight_on())
		quit()
	return false
