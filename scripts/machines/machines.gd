class_name Machines
extends RefCounted
## Máquinas do Tier 1 (manuais): o jogador é a energia. Toque em [E] = pôr/tirar
## material ou abrir; SEGURAR [E] = girar a manivela, gastando stamina.
##   grindstone     pedra de amolar: segurando, afia a lâmina/ferramenta da mão (+dano)
##   quern          moinho manual: trigo -> farinha
##   pump           bomba d'água (só na beira do lago): enche garrafas de água suja
##   spinning       roca: 2 fibra -> 1 fio
##   loom           tear: 3 fio -> 1 tecido
##   stone_furnace  fornalha de pedra: toque abre (lingotes), segurar = fole (esquenta)
## Esperam sozinhas (pelo relógio, como a grelha): filtro, defumador, composteira (Cooking).
## Estação de crafting: forno de tijolo (pão).
## A máquina guarda {"in", "out", "prog"} (ou "heat"/"ht" no fole) em PlacedObject.extra,
## e o host avança: o resultado é o mesmo para todos e vai no save.

const CRANK := ["grindstone", "quern", "pump", "spinning", "loom", "stone_furnace", "sieve"]
const STAMINA_PER_SECOND := 30.0
## Processadoras: [entrada, quantas, saída, segundos de manivela por unidade]
const PROCESS := {
	"quern": [&"trigo", 1, &"farinha", 2.5],
	"spinning": [&"fibra", 2, &"fio", 3.0],
	"loom": [&"fio", 3, &"tecido", 5.0],
	"sieve": [&"argila", 1, &"pedra", 2.0, 0.5], # peneira: 50% de chance de sair uma pedra
	"sawmill": [&"tronco", 1, &"tabua", 4.0, 1.0, 12], # serraria (só com energia): 1 tronco -> 12 tábuas
}
## Outro material que a máquina aceita: [item, quantas unidades da entrada vale cada um].
const ALT_INPUT := {"spinning": [&"la", 2]} # lã das ovelhas: 1 lã = 1 fio
const NAMES := {"grindstone": "Pedra de amolar", "quern": "Moinho manual", "pump": "Bomba d'água",
	"spinning": "Roca", "loom": "Tear", "stone_furnace": "Fornalha de pedra", "oven": "Forno de tijolo",
	"sieve": "Peneira", "furnace": "Fornalha", "sawmill": "Serraria", "water_wheel": "Roda d'água",
	"windmill": "Moinho de vento", "shaft": "Eixo", "ram_pump": "Carneiro hidráulico",
	"blast_furnace": "Alto-forno", "boiler": "Caldeira", "distillery": "Destilaria", "forge": "Forja e bigorna", "wire_drawer": "Trefiladora"}
const HEAT_DECAY := 90.0 ## segundos para a fornalha esfriar de 1 a 0
const HEAT_NEEDED := 0.5 ## ferro só funde com a fornalha a pelo menos 50%
const CAPACITY := 100


static func is_crank(kind: String) -> bool:
	return kind in CRANK


## Calor atual da fornalha de pedra (0..1), esfriando com o tempo.
static func heat(obj: PlacedObject) -> float:
	var manager := obj.get_parent() as PlacedManager
	if manager == null:
		return 0.0
	return clampf(obj.extra.get("heat", 0.0) - (manager.clock - obj.extra.get("ht", manager.clock)) / HEAT_DECAY, 0.0, 1.0)


static func text(obj: PlacedObject) -> String:
	var name: String = NAMES.get(obj.kind, obj.kind)
	match obj.kind:
		"grindstone":
			var auto := AutoMachines.grind_text(obj)
			return auto if auto != "" else name + "  [segure E com a arma/ferramenta na mão: afia]"
		"pump":
			return name + "  [segure E: enche garrafas vazias]"
		"stone_furnace":
			if obj.extra.get("pstate", "") == "ok":
				return "%s: calor %d%% (fole no eixo)  [E] abrir" % [name, int(heat(obj) * 100.0)]
			return "%s: calor %d%%  [E] abrir · [segure E] fole" % [name, int(heat(obj) * 100.0)]
		"oven":
			return "[E] " + name
	match obj.kind:
		"water_wheel", "windmill":
			return "%s: gera %s de força · %s" % [name, Power._num(snappedf(Power.output(obj), 0.1)), Power.status(obj)]
		"shaft":
			return "%s %s" % [name, "girando" if obj.extra.get("speed", 0.0) > 0.0 else "parado"]
		"ram_pump":
			return name + ": irriga as plantações em volta  [E] encher garrafa"
	if PROCESS.has(obj.kind):
		var recipe: Array = PROCESS[obj.kind]
		var parts := "%s: %d %s · %d %s" % [name, obj.extra.get("in", 0), ItemDB.display_name(recipe[0]),
			obj.extra.get("out", 0), ItemDB.display_name(recipe[2])]
		if Power.DEMAND.has(obj.kind):
			parts += " · " + Power.status(obj)
		return parts + ("" if obj.kind == "sawmill" or obj.extra.get("pstate", "") == "ok" else "  [segure E] girar")
	return name


## Toque em [E].
static func tap(player: Player, obj: PlacedObject) -> void:
	var manager := obj.get_parent() as PlacedManager
	if obj.kind == "grindstone" and AutoMachines.grind_tap(player, obj):
		return # com força: deixa/pega a ferramenta na pedra
	match obj.kind:
		"stone_furnace":
			StorageUI.open_for(player, Smelting.key_of(obj), obj)
			return
		"oven":
			CraftingUI.open_for(player, "forno", obj)
			return
	if not PROCESS.has(obj.kind):
		Sfx.play("click", -6.0, 0.6)
		return
	var recipe: Array = PROCESS[obj.kind]
	# Tira o pronto primeiro (voa até a mochila); senão põe TODO o material que tiver na mochila.
	if obj.extra.get("out", 0) > 0:
		ItemFly.play(recipe[2], obj.global_position + Vector3.UP * 0.8, player)
		manager.request("machine_take", [obj.net_id])
		Sfx.play_at("pickup", obj.global_position + Vector3.UP, 0.0, 1.0)
		return
	var room: int = CAPACITY - obj.extra.get("in", 0)
	var amount := mini(player.inventory.count(recipe[0]), room)
	if amount <= 0 and ALT_INPUT.has(obj.kind):
		var alt: Array = ALT_INPUT[obj.kind]
		var units := mini(player.inventory.count(alt[0]), room / alt[1])
		if units > 0:
			var rest := units
			while rest > 0:
				var index := Cooking.find_any(player.inventory, {alt[0]: true})
				rest -= player.inventory.take(index, rest).get("amount", rest)
			manager.request("machine_put", [obj.net_id, units * alt[1]])
			Sfx.play_at("step_soft", obj.global_position + Vector3.UP, 0.0, 1.1)
			return
	if amount > 0:
		var left := amount
		while left > 0:
			var index := Cooking.find_any(player.inventory, {recipe[0]: true})
			left -= player.inventory.take(index, left).get("amount", left)
		manager.request("machine_put", [obj.net_id, amount])
		Sfx.play_at("step_soft", obj.global_position + Vector3.UP, 0.0, 1.1)
	else:
		Sfx.play("click", -6.0, 0.6)


## Segurando [E]: um passo de manivela. false = não deu (sem stamina, sem o item certo...).
## O que é só do jogador (amolar, encher garrafa) acontece aqui; o resto o host avança.
static func crank_local(player: Player, obj: PlacedObject, delta: float) -> bool:
	if player.stamina < 2.0:
		return false
	match obj.kind:
		"grindstone":
			var index := player.inventory.selected
			var slot: Dictionary = player.inventory.slots[index]
			if slot.is_empty() or not ItemDB.sharpenable(slot.id) or float(slot.get("sharp", 0.0)) >= 0.999:
				return false
			slot.sharp = minf(float(slot.get("sharp", 0.0)) + 0.07 * delta, 1.0) # ~14 s até o fio cheio (+35% de dano)
			player.inventory.changed.emit()
		"pump":
			var bottle := Cooking.find_any(player.inventory, {&"garrafa": true}) # de qualquer lugar da mochila
			if bottle < 0:
				return false
			var progress: float = obj.get_meta("pump", 0.0) + delta
			if progress >= 1.5:
				progress = 0.0
				player.inventory.take(bottle, 1)
				player.pick_up(&"agua_suja", ItemDB.display_name(&"agua_suja"), 1)
				Sfx.play_at("slap", obj.global_position + Vector3.UP * 0.4, -2.0, 1.3)
			obj.set_meta("pump", progress)
		_:
			if PROCESS.has(obj.kind) and obj.extra.get("in", 0) < PROCESS[obj.kind][1]:
				return false # sem material para processar
	player.stamina = maxf(player.stamina - STAMINA_PER_SECOND * delta, 0.0)
	player.stamina_changed.emit(player.stamina, player.max_stamina)
	_spin(obj, delta)
	return true


## Gira a manivela/roda do modelo (só visual, local).
static func _spin(obj: PlacedObject, delta: float) -> void:
	var crank := obj.get_node_or_null("Crank") as Node3D
	if crank:
		# Cada modelo diz como a peça se mexe (ObjectModels: meta "crank_mode").
		var base: Vector3 = obj.get_meta("crank_base", crank.position)
		var t: float = obj.get_meta("crank_t", 0.0)
		match obj.get_meta("crank_mode", "spin"):
			"shake": # peneira: vai e volta
				t += delta * 18.0
				crank.position.x = base.x + sin(t) * 0.06
			"swing": # alavanca da bomba / tábua do fole: sobe e desce
				t += delta * 5.0
				crank.rotation.x = sin(t) * 0.35
			"bob": # liços do tear: sobem e descem
				t += delta * 6.0
				crank.position.y = base.y + sin(t) * 0.06
			"spin_up": # mó do moinho: gira deitada
				crank.rotate_object_local(Vector3.UP, delta * 6.0)
			"spin_x": # pedra de amolar: gira no eixo de lado a lado
				crank.rotate_object_local(Vector3.RIGHT, delta * 6.0)
			_:
				crank.rotate_object_local(Vector3.FORWARD, delta * 6.0)
		obj.set_meta("crank_t", t)
	var t: float = obj.get_meta("creak", 0.0) - delta
	if t <= 0.0:
		t = 0.55
		Sfx.play_at("creak" if obj.kind != "stone_furnace" else "wind", obj.global_position + Vector3.UP * 0.8, -6.0, randf_range(0.8, 1.1))
	obj.set_meta("creak", t)


## Host: "seconds" de manivela nesta máquina. Devolve o extra novo (para todos).
static func host_crank(obj: PlacedObject, seconds: float, clock: float) -> Dictionary:
	seconds = clampf(seconds, 0.0, 1.0)
	if obj.kind == "stone_furnace":
		obj.extra.heat = minf(heat(obj) + seconds * 0.22, 1.0) # ~5 s de fole: quente o bastante
		obj.extra.ht = clock
		return obj.extra
	if not PROCESS.has(obj.kind):
		return {}
	var recipe: Array = PROCESS[obj.kind]
	var prog: float = obj.extra.get("prog", 0.0) + seconds
	while prog >= recipe[3] and obj.extra.get("in", 0) >= recipe[1]:
		prog -= recipe[3]
		obj.extra.in = obj.extra.get("in", 0) - recipe[1]
		if recipe.size() < 5 or randf() < recipe[4]:
			obj.extra.out = obj.extra.get("out", 0) + (recipe[5] if recipe.size() > 5 else 1)
	if obj.extra.get("in", 0) < recipe[1]:
		prog = 0.0
	obj.extra.prog = prog
	return obj.extra

# Modelos: ObjectModels (scripts/machines/object_models.gd).
