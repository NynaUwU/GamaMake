class_name Machines
extends RefCounted
## Máquinas do Tier 1 (manuais): o jogador é a energia. Toque em [E] = pôr/tirar
## material ou abrir; SEGURAR [E] = girar a manivela, gastando stamina.
##   grindstone     pedra de amolar: segurando, recupera a durabilidade do item da mão
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
const NAMES := {"grindstone": "Pedra de amolar", "quern": "Moinho manual", "pump": "Bomba d'água",
	"spinning": "Roca", "loom": "Tear", "stone_furnace": "Fornalha de pedra", "oven": "Forno de tijolo",
	"sieve": "Peneira", "furnace": "Fornalha", "sawmill": "Serraria", "water_wheel": "Roda d'água",
	"windmill": "Moinho de vento", "shaft": "Eixo", "ram_pump": "Carneiro hidráulico",
	"blast_furnace": "Alto-forno", "boiler": "Caldeira", "distillery": "Destilaria"}
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
			return name + "  [segure E com a ferramenta na mão]"
		"pump":
			return name + "  [segure E: enche garrafas vazias]"
		"stone_furnace":
			return "%s %d%%  [E] abrir · [segure E] fole" % [name, int(heat(obj) * 100.0)]
		"oven":
			return "[E] " + name
	match obj.kind:
		"water_wheel", "windmill":
			return "%s: %d%% de força" % [name, int(Power.output(obj) / Power.OUTPUT[obj.kind] * 100.0)]
		"shaft":
			return "%s %s" % [name, "girando" if obj.extra.get("speed", 0.0) > 0.0 else "parado"]
		"ram_pump":
			return name + ": irriga as plantações em volta  [E] encher garrafa"
	if PROCESS.has(obj.kind):
		var recipe: Array = PROCESS[obj.kind]
		var parts := "%s: %d %s · %d %s" % [name, obj.extra.get("in", 0), ItemDB.display_name(recipe[0]),
			obj.extra.get("out", 0), ItemDB.display_name(recipe[2])]
		if Power.DEMAND.has(obj.kind) and obj.extra.get("speed", 0.0) > 0.0:
			return parts + "  · energia %d%%" % int(obj.extra.speed * 100.0)
		return parts + ("" if obj.kind == "sawmill" else "  [segure E] girar")
	return name


## Toque em [E].
static func tap(player: Player, obj: PlacedObject) -> void:
	var manager := obj.get_parent() as PlacedManager
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
			if slot.is_empty() or ItemDB.max_durability(slot.id) <= 0 or slot.get("dur", 1.0) >= 0.999:
				return false
			slot.dur = minf(slot.get("dur", 1.0) + 0.07 * delta, 1.0) # ~14 s de 0 a 100%
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
	if crank and obj.kind == "sieve":
		var t: float = obj.get_meta("shake", 0.0) + delta * 18.0
		obj.set_meta("shake", t)
		crank.position.x = sin(t) * 0.06 # peneira vai e volta
	elif crank:
		crank.rotate_object_local(Vector3.FORWARD if obj.kind != "quern" else Vector3.UP, delta * 6.0)
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


# --- Modelos ---------------------------------------------------------------------

const WOOD := Color(0.4, 0.26, 0.15)
const STONE := Color(0.5, 0.48, 0.45)
const IRON := Color(0.22, 0.21, 0.21)
const BRICK := Color(0.62, 0.3, 0.2)
const BRASS_COLOR := Color(0.6, 0.48, 0.26)
const STEEL_COLOR := Color(0.58, 0.59, 0.6)


static func build(kind: String, obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	var crank := MeshBuilder.new() # parte que gira (nó "Crank")
	var crank_at := Vector3.ZERO
	var spin := MeshBuilder.new() # parte girada pela energia (nó "Spin")
	var spin_at := Vector3.ZERO
	var spin_axis := Vector3.RIGHT
	match kind:
		"grindstone":
			mb.color(WOOD)
			for x in [-0.35, 0.35]:
				mb.box(Vector3(x, 0.35, 0), Vector3(0.08, 0.7, 0.12))
			mb.box(Vector3(0, 0.08, 0), Vector3(0.9, 0.08, 0.5))
			crank_at = Vector3(0, 0.75, 0)
			crank.color(STONE)
			crank.lathe(PackedVector2Array([Vector2(0.002, -0.06), Vector2(0.32, -0.06), Vector2(0.32, 0.06), Vector2(0.002, 0.06)]), 14, Basis(Vector3.RIGHT, PI / 2))
			crank.color(IRON)
			crank.box(Vector3(0, 0, 0.2), Vector3(0.05, 0.05, 0.32))
			crank.box(Vector3(0, 0.12, 0.34), Vector3(0.04, 0.24, 0.04))
			# Cocho de água embaixo da pedra, pedal e mancais de ferro.
			mb.color(WOOD.darkened(0.2))
			mb.box(Vector3(0, 0.3, 0), Vector3(0.5, 0.12, 0.3))
			mb.color(Color(0.3, 0.42, 0.5))
			mb.box(Vector3(0, 0.365, 0), Vector3(0.44, 0.01, 0.24))
			mb.color(IRON)
			for x in [-0.35, 0.35]:
				mb.box(Vector3(x, 0.75, 0), Vector3(0.1, 0.06, 0.14)) # mancal
			mb.color(WOOD)
			mb.box(Vector3(0.0, 0.1, 0.32), Vector3(0.5, 0.04, 0.12), Basis(Vector3.RIGHT, 0.2)) # pedal
			mb.color(IRON)
			mb.tube(PackedVector3Array([Vector3(0.2, 0.12, 0.3), Vector3(0.3, 0.5, 0.15), Vector3(0.36, 0.75, 0.0)]), 0.01, 4) # biela
			obj._shape(Vector3(0, 0.55, 0), Vector3(0.9, 1.1, 0.5))
		"quern":
			mb.color(WOOD)
			mb.box(Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.8))
			mb.color(STONE)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.6), Vector2(0.34, 0.6), Vector2(0.34, 0.72), Vector2(0.002, 0.72)]), 14)
			crank_at = Vector3(0, 0.72, 0)
			crank.color(STONE.lightened(0.1))
			crank.lathe(PackedVector2Array([Vector2(0.05, 0.0), Vector2(0.33, 0.0), Vector2(0.33, 0.14), Vector2(0.05, 0.14)]), 14)
			crank.color(WOOD.darkened(0.2))
			crank.box(Vector3(0.25, 0.28, 0), Vector3(0.05, 0.3, 0.05)) # cabo
			# Bica de farinha, saco embaixo e cintas de ferro na caixa.
			mb.color(WOOD.darkened(0.25))
			mb.box(Vector3(0, 0.55, 0.45), Vector3(0.12, 0.05, 0.2), Basis(Vector3.RIGHT, 0.3))
			mb.color(Color(0.82, 0.78, 0.66))
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.13, 0.0), Vector2(0.15, 0.15), Vector2(0.1, 0.32), Vector2(0.06, 0.36)]), 8, Basis.IDENTITY, Vector3(0, 0, 0.62))
			mb.color(Color(0.95, 0.93, 0.88))
			mb.lathe(PackedVector2Array([Vector2(0.06, 0.36), Vector2(0.002, 0.37)]), 8, Basis.IDENTITY, Vector3(0, 0, 0.62))
			mb.color(IRON)
			for y in [0.1, 0.5]:
				mb.box(Vector3(0, y, 0), Vector3(0.82, 0.04, 0.82))
			mb.color(Color(0.85, 0.72, 0.4))
			for k in 5:
				mb.box(Vector3(-0.3 + k * 0.03, 0.62, -0.3), Vector3(0.012, 0.18, 0.012)) # feixe de trigo encostado
			obj._shape(Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.8))
		"pump":
			mb.color(IRON)
			mb.box(Vector3(0, 0.55, 0), Vector3(0.18, 1.1, 0.18))
			mb.box(Vector3(0, 0.9, 0.2), Vector3(0.06, 0.06, 0.3)) # bica
			mb.color(WOOD)
			mb.box(Vector3(0, 0.05, 0), Vector3(0.6, 0.1, 0.6))
			crank_at = Vector3(0, 1.1, 0)
			crank.color(IRON.lightened(0.2))
			crank.box(Vector3(0, 0, -0.3), Vector3(0.05, 0.05, 0.65)) # alavanca
			# Cano descendo até a água, balde embaixo da bica, rebites e base de pedra.
			mb.color(IRON.darkened(0.2))
			mb.tube(PackedVector3Array([Vector3(0, 0.1, -0.1), Vector3(0, -0.2, -0.4), Vector3(0, -0.6, -0.6)]), 0.04, 6)
			mb.color(Color(0.5, 0.49, 0.46))
			for k in 6:
				var a := TAU * k / 6.0
				mb.box(Vector3(cos(a) * 0.28, 0.06, sin(a) * 0.28), Vector3(0.16, 0.12, 0.12), Basis(Vector3.UP, a))
			mb.color(WOOD)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.1, 0.0), Vector2(0.12, 0.2), Vector2(0.125, 0.21)]), 10, Basis.IDENTITY, Vector3(0, 0.1, 0.35))
			mb.color(IRON)
			mb.lathe(PackedVector2Array([Vector2(0.123, 0.18), Vector2(0.123, 0.2)]), 10, Basis.IDENTITY, Vector3(0, 0.1, 0.35))
			mb.lathe(PackedVector2Array([Vector2(0.105, 0.04), Vector2(0.105, 0.06)]), 10, Basis.IDENTITY, Vector3(0, 0.1, 0.35))
			for y in [0.3, 0.6, 0.9]:
				mb.box(Vector3(0, y, 0.092), Vector3(0.02, 0.02, 0.01)) # rebites
			obj._shape(Vector3(0, 0.55, 0), Vector3(0.4, 1.1, 0.4))
		"spinning":
			mb.color(WOOD)
			mb.box(Vector3(0, 0.2, 0), Vector3(1.0, 0.08, 0.3))
			for x in [-0.4, 0.3]:
				mb.box(Vector3(x, 0.1, 0), Vector3(0.06, 0.2, 0.3))
			mb.box(Vector3(0.25, 0.55, 0), Vector3(0.06, 0.7, 0.06))
			mb.color(Color(0.9, 0.88, 0.82))
			mb.box(Vector3(-0.35, 0.45, 0), Vector3(0.12, 0.25, 0.12)) # roca com fibra
			crank_at = Vector3(0.25, 0.75, 0)
			crank.color(WOOD.lightened(0.1))
			for k in 8:
				var a := TAU * k / 8.0
				crank.box(Vector3(cos(a) * 0.18, sin(a) * 0.18, 0), Vector3(0.03, 0.36, 0.03), Basis(Vector3.FORWARD, a))
			crank.lathe(PackedVector2Array([Vector2(0.33, -0.02), Vector2(0.36, -0.02), Vector2(0.36, 0.02), Vector2(0.33, 0.02)]), 16, Basis(Vector3.RIGHT, PI / 2))
			# Pedal, banquinho e cesto de fibra do lado.
			mb.color(WOOD.darkened(0.15))
			mb.box(Vector3(0.25, 0.06, 0.15), Vector3(0.3, 0.03, 0.12), Basis(Vector3.RIGHT, 0.15))
			mb.color(IRON)
			mb.tube(PackedVector3Array([Vector3(0.25, 0.08, 0.15), Vector3(0.25, 0.5, 0.05)]), 0.006, 3)
			mb.color(Color(0.5, 0.4, 0.25))
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.14, 0.0), Vector2(0.17, 0.16), Vector2(0.175, 0.17)]), 10, Basis.IDENTITY, Vector3(-0.55, 0, 0.35))
			mb.color(Color(0.95, 0.94, 0.9))
			mb.lathe(PackedVector2Array([Vector2(0.16, 0.15), Vector2(0.1, 0.2), Vector2(0.002, 0.22)]), 10, Basis.IDENTITY, Vector3(-0.55, 0, 0.35))
			mb.color(Color(0.85, 0.82, 0.74))
			mb.tube(PackedVector3Array([Vector3(-0.35, 0.5, 0), Vector3(0.0, 0.62, 0), Vector3(0.25, 0.75, 0)]), 0.004, 3) # fio sendo puxado
			obj._shape(Vector3(0, 0.55, 0), Vector3(1.0, 1.1, 0.4))
		"loom":
			mb.color(WOOD)
			for x in [-0.6, 0.6]:
				for z in [-0.35, 0.35]:
					mb.box(Vector3(x, 0.6, z), Vector3(0.07, 1.2, 0.07))
			mb.box(Vector3(0, 1.18, 0), Vector3(1.3, 0.06, 0.8))
			mb.box(Vector3(0, 0.7, 0.35), Vector3(1.2, 0.06, 0.06))
			mb.color(Color(0.86, 0.84, 0.78))
			mb.box(Vector3(0, 0.75, 0), Vector3(1.0, 0.01, 0.6)) # trama
			crank_at = Vector3(0, 0.95, -0.35)
			crank.color(WOOD.lightened(0.15))
			crank.box(Vector3.ZERO, Vector3(1.2, 0.08, 0.08)) # liço
			# Rolo de tecido pronto na frente, fios verticais (urdidura) e pedais.
			mb.color(Color(0.68, 0.62, 0.5))
			mb.lathe(PackedVector2Array([Vector2(0.002, -0.55), Vector2(0.07, -0.55), Vector2(0.07, 0.55), Vector2(0.002, 0.55)]), 10, Basis(Vector3.BACK, PI / 2), Vector3(0, 0.55, 0.38))
			mb.color(Color(0.9, 0.88, 0.82))
			for k in 14:
				mb.box(Vector3(-0.5 + k * 0.077, 0.95, 0.0), Vector3(0.004, 0.45, 0.004))
			mb.color(WOOD.darkened(0.2))
			for x in [-0.2, 0.2]:
				mb.box(Vector3(x, 0.08, 0.2), Vector3(0.12, 0.03, 0.4), Basis(Vector3.RIGHT, 0.12))
			obj._shape(Vector3(0, 0.6, 0), Vector3(1.3, 1.2, 0.8))
		"stone_furnace":
			mb.color(BRICK)
			mb.box(Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.1))
			mb.color(BRICK.darkened(0.25))
			mb.box(Vector3(0, 1.6, -0.2), Vector3(0.4, 0.8, 0.4)) # chaminé
			mb.color(Color(0.08, 0.06, 0.05))
			mb.box(Vector3(0, 0.4, 0.556), Vector3(0.5, 0.4, 0.01)) # boca
			mb.color(Color(0.45, 0.32, 0.2))
			mb.box(Vector3(0.8, 0.35, 0.2), Vector3(0.4, 0.25, 0.6)) # fole de couro
			crank_at = Vector3(0.8, 0.5, 0.2)
			crank.color(WOOD)
			crank.box(Vector3(0, 0, 0), Vector3(0.42, 0.04, 0.62))
			crank.box(Vector3(0, 0, 0.4), Vector3(0.06, 0.06, 0.3)) # cabo
			# Tijolos à vista (juntas), cinta de ferro, pilha de carvão e lingotes prontos.
			mb.color(BRICK.darkened(0.35))
			for k in 6:
				mb.box(Vector3(0, 0.1 + k * 0.2, 0.552), Vector3(1.2, 0.012, 0.004))
				for j in 4:
					var x := -0.45 + j * 0.3 + (0.15 if k % 2 == 1 else 0.0)
					mb.box(Vector3(x, 0.2 + k * 0.2, 0.552), Vector3(0.012, 0.19, 0.004))
			mb.color(IRON)
			mb.box(Vector3(0, 1.0, 0), Vector3(1.24, 0.06, 1.14))
			mb.color(Color(0.1, 0.09, 0.09))
			for k in 6:
				mb.box(Vector3(-0.85 + (k % 3) * 0.1, 0.05 + (k / 3) * 0.08, 0.35 + (k % 2) * 0.08), Vector3(0.1, 0.08, 0.09), Basis(Vector3.UP, k))
			mb.color(IRON.lightened(0.2))
			for k in 3:
				mb.box(Vector3(-0.75, 0.03 + k * 0.045, -0.35), Vector3(0.24, 0.04, 0.08), Basis(Vector3.UP, (k % 2) * PI / 2))
			obj._shape(Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.1))
			StationModels._fire(obj, Vector3(0, 0.35, 0.45), 0.1, 0.8)
		"oven":
			mb.color(BRICK)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.62, 0.0), Vector2(0.62, 0.5), Vector2(0.5, 0.85),
				Vector2(0.25, 1.05), Vector2(0.002, 1.1)]), 12)
			mb.color(Color(0.08, 0.06, 0.05))
			mb.box(Vector3(0, 0.35, 0.6), Vector3(0.4, 0.35, 0.05))
			# Chaminé, pá de padeiro encostada, lenha e um pão na boca.
			mb.color(BRICK.darkened(0.15))
			mb.lathe(PackedVector2Array([Vector2(0.12, 0.9), Vector2(0.1, 1.45), Vector2(0.13, 1.5)]), 8, Basis.IDENTITY, Vector3(0.0, 0, -0.25))
			mb.color(WOOD)
			mb.tube(PackedVector3Array([Vector3(0.72, 0.0, 0.3), Vector3(0.62, 1.2, 0.4)]), 0.02, 5)
			mb.box(Vector3(0.73, 0.1, 0.29), Vector3(0.22, 0.02, 0.26), Basis(Vector3.BACK, 0.08))
			for k in 4:
				mb.color(WOOD.darkened(0.1 + 0.05 * (k % 2)))
				mb.tube(PackedVector3Array([Vector3(-0.85, 0.06 + (k / 2) * 0.11, -0.2 + (k % 2) * 0.13), Vector3(-0.55, 0.06 + (k / 2) * 0.11, -0.2 + (k % 2) * 0.13)]), 0.055, 6)
			mb.color(Color(0.78, 0.5, 0.22))
			mb.box(Vector3(0, 0.22, 0.58), Vector3(0.18, 0.07, 0.1))
			obj._shape(Vector3(0, 0.55, 0), Vector3(1.24, 1.1, 1.24))
			StationModels._fire(obj, Vector3(0, 0.3, 0.45), 0.08, 0.6)
		"filter":
			# Funil de lata num tripé: areia e carvão dentro, pinga nas garrafas embaixo.
			mb.color(WOOD)
			for k in 3:
				var a := TAU * k / 3.0
				mb.tube(PackedVector3Array([Vector3(cos(a) * 0.42, 0, sin(a) * 0.42), Vector3(cos(a) * 0.22, 1.0, sin(a) * 0.22)]), 0.03, 5)
			mb.color(Color(0.55, 0.55, 0.52))
			mb.lathe(PackedVector2Array([Vector2(0.03, 0.55), Vector2(0.05, 0.62), Vector2(0.36, 1.0), Vector2(0.38, 1.12),
				Vector2(0.35, 1.12), Vector2(0.33, 1.02), Vector2(0.04, 0.65)]), 12)
			mb.color(Color(0.85, 0.75, 0.5)) # areia em cima
			mb.lathe(PackedVector2Array([Vector2(0.002, 1.04), Vector2(0.33, 1.04)]), 12)
			mb.color(Color(0.15, 0.15, 0.15)) # faixa de carvão aparecendo na boca
			mb.lathe(PackedVector2Array([Vector2(0.32, 1.0), Vector2(0.34, 1.035)]), 12)
			mb.color(Color(0.35, 0.5, 0.6)) # pingo
			mb.box(Vector3(0, 0.45, 0), Vector3(0.02, 0.1, 0.02))
			obj._shape(Vector3(0, 0.56, 0), Vector3(0.8, 1.12, 0.8))
		"smoker":
			# Fornalha de tijolo embaixo e armário de madeira aberto na frente: dá para
			# ver o peixe pendurado dentro (até 6).
			mb.color(BRICK.darkened(0.1))
			mb.box(Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.6))
			mb.color(Color(0.08, 0.06, 0.05))
			mb.box(Vector3(0, 0.25, 0.301), Vector3(0.3, 0.22, 0.01)) # boca do fogo
			mb.color(WOOD.darkened(0.3))
			for x in [-0.38, 0.38]:
				for z in [-0.27, 0.27]:
					mb.box(Vector3(x, 0.95, z), Vector3(0.05, 0.7, 0.05))
			mb.box(Vector3(0, 0.95, -0.28), Vector3(0.8, 0.7, 0.03)) # fundo
			for x in [-0.39, 0.39]:
				for k in 4:
					mb.box(Vector3(x, 0.68 + k * 0.17, 0), Vector3(0.03, 0.09, 0.55)) # laterais em ripas
			mb.box(Vector3(0, 1.32, 0), Vector3(0.9, 0.06, 0.7)) # teto
			mb.color(IRON)
			for z in [-0.08, 0.08]:
				mb.box(Vector3(0, 1.22, z), Vector3(0.72, 0.02, 0.02)) # varas dos ganchos
			obj._shape(Vector3(0, 0.7, 0), Vector3(0.8, 1.4, 0.6))
			StationModels._fire(obj, Vector3(0, 0.15, 0.2), 0.08, 0.5)
			var smoke := CPUParticles3D.new()
			smoke.amount = 10
			smoke.lifetime = 2.5
			smoke.position = Vector3(0, 1.4, 0)
			smoke.direction = Vector3.UP
			smoke.spread = 10.0
			smoke.gravity = Vector3(0, 0.4, 0)
			smoke.initial_velocity_min = 0.2
			smoke.initial_velocity_max = 0.4
			var puff := BoxMesh.new()
			puff.size = Vector3.ONE * 0.16
			var smoke_mat := StandardMaterial3D.new()
			smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			smoke_mat.albedo_color = Color(0.55, 0.55, 0.55, 0.35)
			puff.material = smoke_mat
			smoke.mesh = puff
			obj.add_child(smoke)
		"sieve":
			mb.color(WOOD)
			for x in [-0.45, 0.45]:
				for z in [-0.3, 0.3]:
					mb.box(Vector3(x, 0.35, z), Vector3(0.05, 0.7, 0.05))
			mb.color(Color(0.62, 0.45, 0.35)) # monte de argila embaixo
			mb.box(Vector3(0, 0.05, 0), Vector3(0.5, 0.1, 0.4))
			crank_at = Vector3(0, 0.72, 0)
			crank.color(WOOD.lightened(0.1))
			for side in [-1.0, 1.0]:
				crank.box(Vector3(0, 0, side * 0.3), Vector3(0.9, 0.08, 0.04))
				crank.box(Vector3(side * 0.45, 0, 0), Vector3(0.04, 0.08, 0.6))
			crank.color(Color(0.55, 0.55, 0.5)) # tela
			for k in 9:
				crank.box(Vector3(-0.4 + k * 0.1, -0.03, 0), Vector3(0.008, 0.008, 0.58))
				crank.box(Vector3(0, -0.03, -0.28 + k * 0.07), Vector3(0.86, 0.008, 0.008))
			obj._shape(Vector3(0, 0.38, 0), Vector3(0.95, 0.76, 0.65))
		"compost":
			# Caixa de ripas com frestas (ventila), postes nos cantos, tampa meio aberta e
			# o monte de composto escuro com restinhos verdes.
			mb.color(WOOD.darkened(0.25))
			for x in [-0.5, 0.5]:
				for z in [-0.45, 0.45]:
					mb.box(Vector3(x, 0.38, z), Vector3(0.07, 0.76, 0.07))
			mb.color(WOOD.darkened(0.05))
			for k in 4:
				var y := 0.1 + k * 0.17
				for side in [-1.0, 1.0]:
					mb.box(Vector3(0, y, side * 0.46), Vector3(1.0, 0.11, 0.035))
					mb.box(Vector3(side * 0.51, y, 0), Vector3(0.035, 0.11, 0.86))
			mb.color(Color(0.22, 0.15, 0.08))
			mb.lathe(PackedVector2Array([Vector2(0.44, 0.38), Vector2(0.38, 0.46), Vector2(0.2, 0.52), Vector2(0.002, 0.54)]), 10)
			mb.box(Vector3(0, 0.3, 0), Vector3(0.95, 0.16, 0.85))
			for k in 7:
				var a := k * 2.1
				mb.color([Color(0.35, 0.5, 0.2), Color(0.55, 0.4, 0.2), Color(0.3, 0.42, 0.18)][k % 3])
				mb.box(Vector3(cos(a) * 0.25, 0.5, sin(a) * 0.2), Vector3(0.06, 0.03, 0.05))
			mb.color(WOOD.darkened(0.15)) # tampa levantada atrás
			mb.box(Vector3(0, 0.95, -0.62), Vector3(1.05, 0.04, 0.5), Basis(Vector3.RIGHT, -1.1))
			obj._shape(Vector3(0, 0.38, 0), Vector3(1.05, 0.76, 0.95))
		"shaft":
			# Eixo de madeira com cintas de ferro em dois cavaletes; acoplamentos de latão nas pontas.
			mb.color(WOOD.darkened(0.2))
			for x in [-0.65, 0.65]:
				mb.tube(PackedVector3Array([Vector3(x, 0.0, -0.25), Vector3(x, 0.6, 0.0)]), 0.035, 5)
				mb.tube(PackedVector3Array([Vector3(x, 0.0, 0.25), Vector3(x, 0.6, 0.0)]), 0.035, 5)
				mb.color(IRON)
				mb.box(Vector3(x, 0.6, 0), Vector3(0.08, 0.12, 0.12)) # mancal
				mb.color(WOOD.darkened(0.2))
			spin_at = Vector3(0, 0.6, 0)
			spin_axis = Vector3.RIGHT
			spin.color(WOOD)
			spin.lathe(PackedVector2Array([Vector2(0.045, -0.95), Vector2(0.045, 0.95)]), 8, Basis(Vector3.BACK, PI / 2))
			spin.color(IRON)
			for x in [-0.4, 0.0, 0.4]:
				spin.lathe(PackedVector2Array([Vector2(0.05, x - 0.02), Vector2(0.05, x + 0.02)]), 8, Basis(Vector3.BACK, PI / 2))
			spin.color(BRASS_COLOR)
			for x in [-0.98, 0.98]:
				spin.lathe(PackedVector2Array([Vector2(0.002, -0.03), Vector2(0.08, -0.03), Vector2(0.08, 0.03), Vector2(0.002, 0.03)]), 10, Basis(Vector3.BACK, PI / 2), Vector3(x, 0, 0))
			obj._shape(Vector3(0, 0.35, 0), Vector3(2.0, 0.7, 0.5))
		"water_wheel":
			# Roda de pás dentro do rio (à frente), eixo até a margem, cavaletes e caixa de engrenagem com a porta.
			mb.color(WOOD.darkened(0.25))
			for x in [-0.55, 0.55]:
				mb.box(Vector3(x, 0.15, -1.6), Vector3(0.12, 1.6, 0.12)) # estacas no rio
				mb.box(Vector3(x, 0.55, -0.6), Vector3(0.1, 0.9, 0.1))
			mb.box(Vector3(0, 0.95, -1.1), Vector3(1.2, 0.08, 1.2)) # travessa
			mb.color(IRON)
			mb.box(Vector3(0, 0.6, 0.15), Vector3(0.36, 0.36, 0.36)) # caixa de engrenagem
			mb.color(BRASS_COLOR)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.08, 0.0), Vector2(0.08, 0.04), Vector2(0.002, 0.04)]), 10, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.6, 0.33))
			spin_at = Vector3(0, 0.45, -1.6)
			spin_axis = Vector3.BACK
			spin.color(WOOD)
			spin.tube(PackedVector3Array([Vector3(0, 0, 0.0), Vector3(0, 0.15, 1.6)]), 0.055, 8) # eixo até a margem
			for side in [-0.18, 0.18]:
				spin.torus(1.05, 0.04, 20, 4, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, side)) # aros
			for k in 12:
				var a := TAU * k / 12.0
				var out := Vector3(cos(a), sin(a), 0)
				spin.box(out * 0.55, Vector3(0.05, 1.05, 0.05), Basis(Vector3.BACK, a - PI / 2)) # raios
				spin.box(out * 1.1, Vector3(0.36, 0.06, 0.42), Basis(Vector3.BACK, a)) # pás
			obj._shape(Vector3(0, 0.6, 0.15), Vector3(0.4, 0.4, 0.4))
		"windmill":
			# Torre de madeira afinando, telhado, quatro pás de lona e a caixa de engrenagem embaixo.
			mb.color(WOOD.darkened(0.1))
			mb.lathe(PackedVector2Array([Vector2(0.75, 0.0), Vector2(0.65, 1.5), Vector2(0.45, 3.6), Vector2(0.5, 3.7)]), 8)
			mb.color(WOOD.darkened(0.3))
			for y in [0.8, 1.8, 2.8]:
				mb.lathe(PackedVector2Array([Vector2(0.72 - y * 0.075, y), Vector2(0.73 - y * 0.075, y + 0.06)]), 8)
			mb.color(Color(0.35, 0.22, 0.14))
			mb.lathe(PackedVector2Array([Vector2(0.62, 3.7), Vector2(0.002, 4.5)]), 8) # telhado
			mb.color(Color(0.08, 0.06, 0.05))
			mb.box(Vector3(0, 0.55, 0.72), Vector3(0.45, 0.9, 0.05)) # porta
			mb.color(IRON)
			mb.box(Vector3(0, 0.6, 0.78), Vector3(0.28, 0.28, 0.16))
			mb.color(BRASS_COLOR)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.08, 0.0), Vector2(0.08, 0.04), Vector2(0.002, 0.04)]), 10, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.6, 0.84))
			spin_at = Vector3(0, 3.6, 0.7)
			spin_axis = Vector3.BACK
			spin.color(WOOD.darkened(0.2))
			spin.lathe(PackedVector2Array([Vector2(0.002, -0.1), Vector2(0.14, -0.08), Vector2(0.14, 0.1), Vector2(0.002, 0.15)]), 8, Basis(Vector3.RIGHT, PI / 2))
			for k in 4:
				var a := TAU * k / 4.0
				var out := Vector3(cos(a), sin(a), 0)
				var side := Vector3(-sin(a), cos(a), 0)
				spin.box(out * 1.3, Vector3(0.06, 2.5, 0.06), Basis(Vector3.BACK, a - PI / 2)) # vara
				spin.color(Color(0.85, 0.8, 0.68))
				spin.box(out * 1.45 + side * 0.22, Vector3(0.38, 1.9, 0.02), Basis(Vector3.BACK, a - PI / 2)) # lona
				spin.color(WOOD.darkened(0.2))
			obj._shape(Vector3(0, 2.0, 0), Vector3(1.4, 4.0, 1.4))
		"sawmill":
			# Mesa comprida, serra circular girando no meio, tora no carrinho, pilha de tábuas e a polia/porta.
			mb.color(WOOD.darkened(0.15))
			for x in [-0.9, 0.9]:
				for z in [-0.3, 0.3]:
					mb.box(Vector3(x, 0.4, z), Vector3(0.1, 0.8, 0.1))
			mb.color(WOOD)
			mb.box(Vector3(0, 0.82, 0), Vector3(2.1, 0.08, 0.75))
			mb.color(Color(0.06, 0.05, 0.05))
			mb.box(Vector3(0, 0.865, 0), Vector3(0.7, 0.01, 0.02)) # fenda da serra
			mb.color(Color(0.36, 0.24, 0.14))
			mb.lathe(PackedVector2Array([Vector2(0.002, -0.45), Vector2(0.14, -0.45), Vector2(0.15, 0.45), Vector2(0.002, 0.45)]), 8, Basis(Vector3.BACK, PI / 2), Vector3(-0.45, 1.0, 0.0)) # tora
			for k in 4:
				mb.color(WOOD.lightened(0.05 * (k % 2)))
				mb.box(Vector3(0.75, 0.9 + k * 0.03, 0.0), Vector3(0.5, 0.025, 0.12)) # tábuas cortadas
			mb.color(IRON)
			mb.box(Vector3(-1.0, 0.6, 0), Vector3(0.22, 0.3, 0.3)) # caixa da polia
			mb.color(BRASS_COLOR)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.09, 0.0), Vector2(0.09, 0.04), Vector2(0.002, 0.04)]), 10, Basis(Vector3.BACK, PI / 2), Vector3(-1.12, 0.6, 0))
			mb.color(Color(0.6, 0.55, 0.4)) # serragem
			mb.box(Vector3(0.1, 0.03, 0.2), Vector3(0.5, 0.06, 0.4))
			spin_at = Vector3(0, 0.88, 0)
			spin_axis = Vector3.BACK
			spin.color(STEEL_COLOR)
			spin.lathe(PackedVector2Array([Vector2(0.002, -0.006), Vector2(0.28, -0.004), Vector2(0.28, 0.004), Vector2(0.002, 0.006)]), 16, Basis(Vector3.RIGHT, PI / 2))
			for k in 16:
				var a := TAU * k / 16.0
				spin.box(Vector3(cos(a), sin(a), 0) * 0.29, Vector3(0.03, 0.03, 0.01), Basis(Vector3.BACK, a + 0.4)) # dentes
			obj._shape(Vector3(0, 0.45, 0), Vector3(2.1, 0.9, 0.75))
		"ram_pump":
			# Carneiro hidráulico: cano vindo do rio, câmara de ar de ferro, válvula e o cano subindo até um esguicho.
			mb.color(IRON.darkened(0.2))
			mb.tube(PackedVector3Array([Vector3(0, 0.15, -1.6), Vector3(0, 0.1, -0.6), Vector3(0, 0.15, 0.0)]), 0.06, 8) # entrada (do rio)
			mb.color(IRON)
			mb.box(Vector3(0, 0.15, 0.0), Vector3(0.5, 0.3, 0.4))
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.3), Vector2(0.16, 0.32), Vector2(0.18, 0.6), Vector2(0.14, 0.82), Vector2(0.002, 0.88)]), 12, Basis.IDENTITY, Vector3(0.0, 0, 0.05)) # câmara
			mb.color(BRASS_COLOR)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.06, 0.0), Vector2(0.06, 0.05), Vector2(0.002, 0.06)]), 8, Basis.IDENTITY, Vector3(0.25, 0.3, -0.05)) # válvula
			for k in 6:
				mb.box(Vector3(cos(k * 1.05) * 0.18, 0.31, 0.05 + sin(k * 1.05) * 0.18), Vector3(0.025, 0.02, 0.025)) # parafusos
			mb.color(IRON.darkened(0.2))
			mb.tube(PackedVector3Array([Vector3(0.0, 0.2, 0.2), Vector3(0.0, 0.2, 0.5), Vector3(0.0, 1.6, 0.6), Vector3(0.0, 1.7, 0.75)]), 0.035, 6) # cano de saída subindo
			mb.color(BRASS_COLOR)
			mb.lathe(PackedVector2Array([Vector2(0.035, 0.0), Vector2(0.07, 0.08)]), 8, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 1.7, 0.75)) # esguicho
			obj._shape(Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.5))
			var spray := CPUParticles3D.new()
			spray.amount = 30
			spray.lifetime = 1.1
			spray.position = Vector3(0, 1.72, 0.8)
			spray.direction = Vector3(0, 0.4, 1)
			spray.spread = 25.0
			spray.gravity = Vector3(0, -6, 0)
			spray.initial_velocity_min = 2.0
			spray.initial_velocity_max = 3.2
			var drop := BoxMesh.new()
			drop.size = Vector3.ONE * 0.03
			var drop_mat := StandardMaterial3D.new()
			drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			drop_mat.albedo_color = Color(0.6, 0.75, 0.9, 0.6)
			drop.material = drop_mat
			spray.mesh = drop
			obj.add_child(spray)
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	if spin_at != Vector3.ZERO:
		var node := MeshInstance3D.new()
		node.name = "Spin"
		node.mesh = spin.finish(PlacedObject._mat(), false)
		node.position = spin_at
		obj.add_child(node)
		var spinner := PowerSpin.new()
		spinner.axis = spin_axis
		obj.add_child(spinner)
	if crank_at != Vector3.ZERO:
		var node := MeshInstance3D.new()
		node.name = "Crank"
		node.mesh = crank.finish(PlacedObject._mat(), false)
		node.position = crank_at
		obj.add_child(node)
