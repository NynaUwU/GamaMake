extends SceneTree
## Diário de receitas: começo de jogo (mochila e mesa, sem "NOVA"), estação construída
## libera as receitas dela, ingrediente de máquina que não existe esconde a receita,
## "NOVA" some ao olhar, save/load guarda o que foi visto e o que foi construído.

var main: Node3D
var placed: PlacedManager


func _build(kind: String, offset: Vector3) -> void:
	var id: int = placed._next_id
	placed._spawn(id, kind, Transform3D(Basis(), main.player.global_position + offset))
	Progress.event("place", kind)


func _stations(list: Array) -> Dictionary:
	var count := {}
	for r in list:
		count[r.station] = count.get(r.station, 0) + 1
	return count


func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	main = current_scene
	placed = main.get_node("Placed")
	var p := Progress.i
	print("catálogo: %d receitas em %d estações" % [RecipeBook.all().size(), RecipeBook.SECTIONS.size()])
	var start := RecipeBook.visible()
	print("começo: %d visíveis %s; novas %d" % [start.size(), _stations(start), p.new_recipes().size()])
	print("fogueira antes de construir: %d" % _stations(RecipeBook.visible()).get("campfire", 0))
	_build("campfire", Vector3(3, 0, -3))
	var fresh := p.new_recipes()
	print("depois da fogueira: fogueira %d receitas, novas %d (%s); aviso na fila: %s" % [_stations(RecipeBook.visible()).get("campfire", 0), fresh.size(),
		", ".join(fresh.slice(0, 4).map(func(r): return String(r.out))), p._queue.map(func(q): return q.title) + ([p._toast.get_child(0).get_child(1).text] if p._toast.visible and p._toast.get_child_count() > 0 else [])])
	# Forno sem moinho: pão (farinha do moinho) fica escondido; batata assada aparece.
	_build("oven", Vector3(6, 0, -3))
	var forno := RecipeBook.visible().filter(func(r): return r.station == "forno")
	print("forno sem moinho: %s" % [forno.map(func(r): return String(r.out))])
	_build("quern", Vector3(9, 0, -3))
	forno = RecipeBook.visible().filter(func(r): return r.station == "forno")
	print("forno com moinho: %s" % [forno.map(func(r): return String(r.out))])
	# Olhar uma receita tira o NOVA.
	var before := p.new_recipes().size()
	p.mark_seen(p.new_recipes()[0].key)
	print("olhou uma: novas %d -> %d" % [before, p.new_recipes().size()])
	# Diário abre na aba de receitas sem erro e mostra os ingredientes.
	JournalUI.tab = "Receitas"
	JournalUI.open_for(main.player)
	await process_frame
	var journal: JournalUI = null
	for node in main.get_children():
		if node is JournalUI:
			journal = node
	var rows := journal.find_children("*", "PanelContainer", true, false).filter(func(n): return n.custom_minimum_size.x == 376)
	var tab_text := ""
	for b in journal._tabs.get_children():
		if b.get_meta("tab", "") == "Receitas":
			tab_text = b.text
	print("diário: %d linhas de receita, aba '%s', 1ª linha: '%s'" % [rows.size(), tab_text, rows[0].tooltip_text.replace("\n", " | ") if not rows.is_empty() else "?"])
	rows[0].mouse_entered.emit()
	print("passou o mouse na 1ª: novas %d" % p.new_recipes().size())
	journal.close()
	# Save/load.
	var data := p.save_data()
	var seen := p.seen_recipes.size()
	p.load_data({"done": {}})
	print("save antigo (sem 'seen_recipes'): pendente=%s" % p._seen_pending)
	p.load_data(data)
	print("save/load: construídos %s, vistas %d (antes %d), pendente=%s" % [p.built.keys(), p.seen_recipes.size(), seen, p._seen_pending])
	quit()
