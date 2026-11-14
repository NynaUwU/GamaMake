extends SceneTree
## Fase 3 do terreno: jazidas infinitas e perfuratriz.
##  - a jazida existe no salão do fim de uma entrada (blocos de jazida nos voxels);
##  - picareta: 1 minério a cada 4 golpes e o bloco fica (não acaba);
##  - perfuratriz (só elétrica): recusada longe da jazida; em cima dela, com cabo de uma bateria,
##    1 minério a cada 5 s; sem energia não anda; [E] entrega tudo; save guarda.

var placed: PlacedManager


func _tick(seconds: int) -> void:
	for k in seconds:
		placed.clock += 1.0
		placed._power()
		placed._electric()


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await process_frame
	var main: Node3D = current_scene
	var player: Player = main.player
	var terrain: TerrainWorld = main.get_node("Terrain")
	var vw: VoxelWorld = main.get_node_or_null("Voxels")
	placed = main.get_node("Placed")
	for e in main.get_node("Enemies").get_children():
		e.queue_free()
	var deposits := terrain.deposits()
	var kinds := {}
	for d in deposits:
		kinds[d[1]] = kinds.get(d[1], 0) + 1
	print("jazidas na ilha: %d %s" % [deposits.size(), kinds])
	if vw == null or deposits.is_empty():
		quit()
		return
	# A mais perto do centro.
	deposits.sort_custom(func(a, b): return Vector2(a[0].x, a[0].z).length() < Vector2(b[0].x, b[0].z).length())
	var center: Vector3 = deposits[0][0]
	var ore: StringName = deposits[0][1]
	var k: int = deposits[0][2]
	var dir := Vector3(terrain.cave_entrances[k + 2], 0, terrain.cave_entrances[k + 3])
	player.set_physics_process(false)
	player.global_position = center - dir * 3.0
	terrain.update_around(center, -1, 140.0)
	vw.update_around(center, VoxelWorld.NEAR)
	for f in 10:
		await process_frame
	# Blocos de jazida em volta e um exposto (com ar em cima: o chão do salão).
	var c := VoxelWorld.block_of(center)
	var count := 0
	var face := VoxelWorld.NO_BLOCK
	for dy in range(-7, 8):
		for dz in range(-7, 8):
			for dx in range(-7, 8):
				var b := c + Vector3i(dx, dy, dz)
				if VoxelWorld.is_deposit(vw.material_at(b)):
					count += 1
					if face == VoxelWorld.NO_BLOCK and vw.material_at(b + Vector3i.UP) == VoxelRef.AIR:
						face = b
	print("jazida de %s em %s: %d blocos de jazida em volta; um exposto em cima: %s" % [ore, center.snapped(Vector3.ONE * 0.1), count, face])
	if face == VoxelWorld.NO_BLOCK:
		quit()
		return
	# Picareta à mão: 8 golpes = 2 minérios; o bloco continua jazida.
	player.inventory.add(&"picareta")
	player.equip_item(&"picareta")
	var before := player.inventory.count(ore)
	for hit in 8:
		TerrainTools._dig_voxel(player, {"dig": face, "point": VoxelWorld.block_center(face), "voxel": true})
	print("picareta, 8 golpes na jazida: +%d %s; bloco ainda é jazida? %s" % [player.inventory.count(ore) - before, ore,
		VoxelWorld.is_deposit(vw.material_at(face))])
	# Perfuratriz longe: recusada. Em cima (no chão do salão, perto do veio): aceita.
	var far := placed.host_apply("place", ["drill", Transform3D(Basis(), center + Vector3(40, 0, 40))])
	var spot := VoxelWorld.block_center(face) + Vector3.UP * 0.2 # em cima do veio, no chão do salão
	var r := placed.host_apply("place", ["drill", Transform3D(Basis(), spot)])
	print("perfuratriz longe da jazida aceita? %s; em cima aceita? %s" % [not far.is_empty(), not r.is_empty()])
	if r.is_empty():
		quit()
		return
	var drill: PlacedObject = placed.objects[r[0]]
	print("jazida da perfuratriz: %s | %s" % [drill.extra.get("ore", ""), Drill.text(drill)])
	# Sem energia: parada.
	_tick(10)
	print("10 s sem energia: prontos %d (esperado 0) | %s" % [drill.extra.get("out", 0), Drill.text(drill)])
	print("porta de eixo na perfuratriz? %s (esperado false: só elétrica)" % Power.PORTS.has("drill"))
	# Bateria carregada a 3 m, cabo até o borne.
	var rb := placed.host_apply("place", ["battery", Transform3D(Basis(), drill.global_position + Vector3(3.0, 0, 0))])
	var battery: PlacedObject = placed.objects[rb[0]]
	battery.extra.merge({"cells": 6, "charge": 1500.0, "health": 1.0}, true)
	var rc := placed.host_apply("cable", [battery.net_id, drill.net_id])
	print("cabo bateria -> perfuratriz: %s" % (not rc.is_empty()))
	Electric.dirty = true
	_tick(30)
	print("30 s com energia: %s, prontos %d (esperado 6), broca girando %s, bateria %.0f Wh" % [Drill.text(drill), drill.extra.get("out", 0),
		drill.extra.get("speed", 0.0) > 0.0, battery.extra.get("charge", 0.0)])
	var have := player.inventory.count(ore)
	Net.i.request_peer = Net.i.my_id()
	placed.host_apply("drill_take", [drill.net_id])
	for f in 5:
		await process_frame
	print("[E] pegou: +%d %s, sobrou %d" % [player.inventory.count(ore) - have, ore, drill.extra.get("out", 0)])
	_tick(10)
	var saved := "?"
	for entry in placed.save_data().list:
		if entry[1] == "drill":
			saved = "%s %d" % [entry[4].get("ore", ""), int(entry[4].get("out", -1))]
	print("depois de mais 10 s: prontos %d; no save: %s" % [drill.extra.get("out", 0), saved])
	quit()
