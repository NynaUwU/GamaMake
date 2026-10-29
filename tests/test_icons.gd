extends SceneTree
## Teste dos ícones e da janela de informação do inventário (headless: ícones simples).
var main: Node
var frame := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	frame += 1
	if frame == 10:
		var icons := root.get_node("ItemIcons")
		print("icons ready=", icons.ready_done, " espada icon=", icons.get_icon(&"espada") != null)
		var player: Player = main.get_node("Player")
		player.inventory.add(&"taco")
		player.inventory.add(&"pano", 3)
		var ui: InventoryUI = main.get_node("HUD/Root/InventoryUI")
		ui._set_open(true)
		print("hotbar slot1 has icon=", ui._hotbar_slots[0].icon != null, " text='", ui._hotbar_slots[0].text, "'")
		ui._hover(0)
		print("tooltip visible=", ui._tooltip.visible, " title=", ui._tooltip_title.text)
		print(ui._tooltip_body.text)
		ui._hover(-1)
		print("tooltip after leave=", ui._tooltip.visible)
		quit()
	return false
