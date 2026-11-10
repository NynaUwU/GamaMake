extends SceneTree
## Menu de admin e trapaças, controles no ESC, teclas Z/H fora, inventário: pegar com
## clique e soltar em outro slot, clicar/arrastar para fora da janela joga no chão,
## e quanto custa uma mudança no inventário (antes recriava estilos e receitas).

var main: Node3D
var player: Player


func _pickups() -> int:
	return get_nodes_in_group("pickup").size() if not get_nodes_in_group("pickup").is_empty() else main.find_children("*", "PickupItem", true, false).size()


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	player = main.player
	print("teclas Z/H no mapa de entrada: %s %s; lista de teclas na tela: %s" % [InputMap.has_action("spawn_zombie"), InputMap.has_action("spawn_horde"),
		main.get_node_or_null("HUD/Root/Controls") != null])
	# --- Menu de pausa: controles e admin.
	var pause: PauseMenu = main.get_node("PauseMenu")
	pause.open()
	print("pausa: botão admin visível %s, controles listados %d" % [pause._admin_button.visible, PauseMenu.CONTROLS.size()])
	pause._show(pause._controls_box)
	print("controles: caixa visível %s, principal %s" % [pause._controls_box.visible, pause._main_box.visible])
	pause._open_admin()
	var admin := pause._admin
	print("admin aberto: %s, trapaças %d" % [admin.box.visible, admin._toggles.size()])
	# --- Trapaças.
	for t in Cheats.TOGGLES:
		admin._toggle(t[0])
	print("todas ligadas: %s; botão '%s'" % [Cheats.TOGGLES.all(func(t): return Cheats.get_flag(t[0])), admin._toggles["god"].text])
	pause.close()
	await physics_frame
	player.take_damage(80.0)
	player.hunger = 10.0
	player.thirst = 5.0
	player.toxic = 70.0
	player.stamina = 1.0
	await physics_frame
	await physics_frame
	print("vida infinita: vida %.0f depois de 80 de dano; fome %.0f sede %.0f intoxicação %.0f stamina %.0f" % [player.health, player.hunger, player.thirst, player.toxic, player.stamina])
	print("criativo: pode pagar 999 barras de aço? %s; invisível: %s; super velocidade %s" % [Builder.can_afford(player.inventory, {&"barra_aco": 999}), player.invisible, Cheats.fast])
	player.inventory.add(&"pistola")
	player.equip_item(&"pistola")
	player._equip = 1.0
	for k in 10:
		player._fire_timer = 0.0
		player._fire_pistol()
	print("munição infinita: 10 tiros sem balas na mochila, tambor %d" % player._ammo)
	var z: Zombie = main.get_node("Enemies").get_children().filter(func(n): return n is Zombie)[0]
	z.target = player
	z._alerted = true
	print("zumbi enxerga o jogador invisível? %s" % z._can_see_target())
	# Ações.
	var before := main.get_node("Enemies").get_child_count()
	main.spawn_zombie_in_front()
	main.spawn_horde(10)
	for k in 3:
		await process_frame
	print("zumbis: %d -> %d (1 na frente + horda de 10)" % [before, main.get_node("Enemies").get_child_count()])
	print("matar todos: %d derrubados" % Cheats.kill_zombies(main))
	Cheats.unlock_all()
	var p := Progress.i
	print("desbloquear tudo: manuais %d/%d, era %d, conquistas %d/%d, receitas no diário %d de %d, novas %d" % [p.manuals.size(), Progress.MANUALS.size(),
		p.era, p.done.size(), Progress.ACHIEVEMENTS.size(), RecipeBook.visible().size(), RecipeBook.all().size(), p.new_recipes().size()])
	Cheats.give(player, &"rifle_luneta")
	Cheats.give(player, &"bala_rifle")
	print("dar itens: rifle com luneta %d, balas de rifle %d" % [player.inventory.count(&"rifle_luneta"), player.inventory.count(&"bala_rifle")])
	Cheats.set_hour(22.0)
	print("noite: hora %.0f, noite %s" % [DayNight.i.hour, DayNight.i.is_night()])
	admin._fill_items()
	print("seletor de itens: %d itens; busca 'bala' -> " % admin._grid.get_child_count(), "")
	admin._search.text = "bala"
	admin._fill_items()
	await process_frame
	print("   %d botões" % admin._grid.get_children().filter(func(c): return not c.is_queued_for_deletion()).size())
	Cheats.reset()
	print("reset: alguma ligada? %s" % Cheats.TOGGLES.any(func(t): return Cheats.get_flag(t[0])))
	# --- Inventário: pegar com clique, soltar em outro slot, jogar fora.
	var inv: InventoryUI = main.get_node("HUD").find_children("*", "InventoryUI", true, false)[0]
	player.inventory.slots[10] = {"id": &"tabua", "amount": 7}
	player.inventory.slots[11] = {}
	player.inventory.changed.emit()
	inv._set_open(true)
	inv._click_slot(10)
	print("clicou na tábua: pegou slot %d, ícone no mouse %s" % [inv._held, inv._cursor.visible])
	inv._click_slot(11)
	print("clicou no slot vazio: slot 10 %s, slot 11 %s, pegando %d" % [player.inventory.slots[10], player.inventory.slots[11], inv._held])
	var drops := main.find_children("*", "", true, false).filter(func(n): return n is RigidBody3D and n.get("item_id") != null).size()
	inv._click_slot(11)
	inv._click_outside()
	await physics_frame
	var drops_after := main.find_children("*", "", true, false).filter(func(n): return n is RigidBody3D and n.get("item_id") != null).size()
	print("pegou e clicou fora: slot 11 %s, itens no chão %d -> %d, mochila aberta %s" % [player.inventory.slots[11], drops, drops_after, inv._backpack.visible])
	player.inventory.slots[12] = {"id": &"pedra", "amount": 5}
	player.inventory.changed.emit()
	print("arrastar para fora aceita? %s" % inv._can_drop_outside(Vector2.ZERO, {"inventory_slot": 12}))
	inv._drop_outside(Vector2.ZERO, {"inventory_slot": 12})
	await physics_frame
	print("arrastou a pedra para fora: slot 12 %s" % player.inventory.slots[12])
	player.inventory.equipment.head = {"id": &"capuz", "amount": 1}
	inv._drop_outside(Vector2.ZERO, {"equip_slot": "head"})
	print("arrastou o capuz vestido para fora: cabeça %s" % player.inventory.equipment.head)
	inv._click_outside()
	print("clique fora sem item pego: fecha a mochila (aberta %s)" % inv._backpack.visible)
	# --- Custo de uma mudança no inventário (mochila fechada e aberta).
	var t0 := Time.get_ticks_usec()
	for k in 200:
		player.inventory.changed.emit()
	var closed_ms := (Time.get_ticks_usec() - t0) / 1000.0
	inv._set_open(true)
	await process_frame
	t0 = Time.get_ticks_usec()
	for k in 200:
		player.inventory.changed.emit()
	var open_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("200 mudanças no inventário: mochila fechada %.1f ms (%.2f ms cada), aberta %.1f ms (%.2f ms cada)" % [closed_ms, closed_ms / 200.0, open_ms, open_ms / 200.0])
	quit()
