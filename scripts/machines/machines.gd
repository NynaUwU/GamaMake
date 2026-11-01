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
}
const NAMES := {"grindstone": "Pedra de amolar", "quern": "Moinho manual", "pump": "Bomba d'água",
	"spinning": "Roca", "loom": "Tear", "stone_furnace": "Fornalha de pedra", "oven": "Forno de tijolo",
	"sieve": "Peneira", "furnace": "Fornalha"}
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
	if PROCESS.has(obj.kind):
		var recipe: Array = PROCESS[obj.kind]
		var parts := "%s: %d %s · %d %s" % [name, obj.extra.get("in", 0), ItemDB.display_name(recipe[0]),
			obj.extra.get("out", 0), ItemDB.display_name(recipe[2])]
		return parts + "  [segure E] girar"
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
			obj.extra.out = obj.extra.get("out", 0) + 1
	if obj.extra.get("in", 0) < recipe[1]:
		prog = 0.0
	obj.extra.prog = prog
	return obj.extra


# --- Modelos ---------------------------------------------------------------------

const WOOD := Color(0.4, 0.26, 0.15)
const STONE := Color(0.5, 0.48, 0.45)
const IRON := Color(0.22, 0.21, 0.21)
const BRICK := Color(0.62, 0.3, 0.2)


static func build(kind: String, obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	var crank := MeshBuilder.new() # parte que gira (nó "Crank")
	var crank_at := Vector3.ZERO
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
			obj._shape(Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.1))
			StationModels._fire(obj, Vector3(0, 0.35, 0.45), 0.1, 0.8)
		"oven":
			mb.color(BRICK)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.62, 0.0), Vector2(0.62, 0.5), Vector2(0.5, 0.85),
				Vector2(0.25, 1.05), Vector2(0.002, 1.1)]), 12)
			mb.color(Color(0.08, 0.06, 0.05))
			mb.box(Vector3(0, 0.35, 0.6), Vector3(0.4, 0.35, 0.05))
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
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	if crank_at != Vector3.ZERO:
		var node := MeshInstance3D.new()
		node.name = "Crank"
		node.mesh = crank.finish(PlacedObject._mat(), false)
		node.position = crank_at
		obj.add_child(node)
