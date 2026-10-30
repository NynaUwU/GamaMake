extends SceneTree
## Vegetação: quantos tufos/árvores por chunk, frutas penduradas e comer fruta.
var main: Node
var frame := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		var terrain: TerrainWorld = main.get_node("Terrain")
		var counts := {}
		var fruits := 0
		var t0 := Time.get_ticks_usec()
		for i in 8:
			var chunk := terrain._build_chunk(Vector2i(8 + i, -3))
			for mmi in chunk.find_children("*", "MultiMeshInstance3D", true, false):
				var mesh: Mesh = mmi.multimesh.mesh
				var kind: String = TerrainProps._meshes.find_key(mesh)
				counts[kind] = counts.get(kind, 0) + mmi.multimesh.instance_count
			fruits += chunk.find_children("*", "PickupItem", true, false).size()
		print("8 plains chunks in ", (Time.get_ticks_usec() - t0) / 1000.0, " ms: ", counts, " fruits=", fruits)
		var player: Player = main.get_node("Player")
		player.inventory.add(&"fruta", 2)
		player.health = 40.0
		for s in Inventory.HOTBAR_SIZE:
			if not player.inventory.slots[s].is_empty() and player.inventory.slots[s].id == &"fruta":
				player.inventory.select(s)
		var ev := InputEventAction.new()
		ev.action = "attack"
		ev.pressed = true
		player._unhandled_input(ev)
		print("ate fruit: hp 40 -> ", player.health, " fruits left=", player.inventory.count(&"fruta"))
		quit()
	return false
