extends SceneTree
## Chinelo (sempre na cabeça, cai duro para trás) e bumerangue (quica em até 5
## zumbis e volta para a mão).
var main: Node
var player: Player
var frame := 0
var z: Zombie
var row: Array = []

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _aim(point: Vector3) -> void:
	var to := point - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		player = main.get_node("Player")
		var zs: Array = main.get_node("Enemies").get_children()
		for e in zs:
			e.detect_range = 0.0
		z = zs[0]
		z.global_position = player.global_position + Vector3(0, 0, -8)
		player.equip_item(&"chinelo")
	if frame == 30:
		_aim(z.global_position + Vector3(0.6, 1.0, 0)) # mira meio torta: o chinelo acha a cabeça igual
		player._throw_slipper()
	if frame == 40:
		player._throw_slipper()
		player._throw_cooldown = 0.0
		player._throw_slipper() # terceiro: não pode (2 no ar)
		print("chinelos no ar=", player._slippers_out, " (máx 2)")
	if frame == 75:
		print("chinelo: estado=", Zombie.State.keys()[z.state], " inclinação (up·Y)=", snappedf(z.global_basis.y.dot(Vector3.UP), 0.01), " vida=", z.health)
	if frame == 200:
		print("chinelos voltaram: no ar=", player._slippers_out)
	if frame == 205:
		print("depois do tombo: estado=", Zombie.State.keys()[z.state], " ragdoll=", z.ragdoll.is_ragdolling(), " raiz de pé de novo=", snappedf(z.global_basis.y.dot(Vector3.UP), 0.01))
		# Fila de 6 zumbis para o bumerangue.
		var zs: Array = main.get_node("Enemies").get_children()
		for i in 5:
			var other: Zombie = zs[i] if i < zs.size() else null
			if other == null or other == z:
				continue
			other.global_position = player.global_position + Vector3(-4.0 + i * 2.5, 0, -10.0 - (i % 2) * 2.0)
			other.velocity = Vector3.ZERO
			row.append(other)
		for i in 2:
			var extra: Zombie = load("res://scenes/zombie.tscn").instantiate()
			main.get_node("Enemies").add_child(extra)
			extra.detect_range = 0.0
			extra.global_position = player.global_position + Vector3(4.0 + i * 2.5, 0, -11.0)
			row.append(extra)
		player.equip_item(&"bumerangue")
	if frame == 235:
		_aim(row[0].global_position + Vector3.UP * 1.5)
		player._throw_boomerang()
	if frame == 245:
		var b: Boomerang = null
		for n in main.get_children():
			if n is Boomerang:
				b = n
		print("bumerangue no ar: ", b != null, " fora da mão=", player._boomerang_out)
		player._throw_boomerang()
		var count := 0
		for n in main.get_children():
			if n is Boomerang:
				count += 1
		print("tentou jogar outro: bumerangues no ar=", count, " (só 1)")
	if frame == 1000:
		var hp := row.map(func(r): return snappedf(r.health, 1))
		print("bumerangue: vida da fila=", hp, " voltou para a mão=", not player._boomerang_out)
		quit()
	if frame > 245 and frame < 1000:
		for r in row:
			if r.state == Zombie.State.STUNNED and not r.has_meta("seen_stun"):
				r.set_meta("seen_stun", true)
				print("  atordoado: ", r.name)
	return false
