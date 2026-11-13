class_name PlacedObject
extends StaticBody3D
## Objeto colocado pelo martelo (ou cova cavada pela pá):
##   pot_small  pote pequeno de barro (1 planta, sem abóbora)
##   pot_wide   floreira larga de madeira (3 plantas)
##   bed        canteiro: piso de terra de 2,8 x 2,8 m na grade da construção (9 plantas)
##   ground     cova cavada no chão pela pá (1 planta)
##   bench      bancada de fabricação ([E] abre a lista de receitas)
##   workbench  mesa de trabalho (receitas de metal) · furnace fornalha (fundir)
##   campfire   fogueira com grelha (3 lugares para assar comida: Cooking)
##   spikes / beartrap / barbed / mine  armadilhas (Trap)
## As plantas crescem pelo relógio do PlacedManager (igual para todos e salvo).

const FARM_KINDS := ["pot_small", "pot_wide", "bed", "ground"]
const STATIONS := {"bench": "mesa", "workbench": "mesa"} # "bench" = saves antigos (fornalhas: Smelting)
const TRAPS := ["spikes", "beartrap", "barbed", "mine"]
const SOIL := Color(0.34, 0.23, 0.15)
const CLAY := Color(0.62, 0.32, 0.2)

var net_id := 0
var kind := "pot_small"
var crops: Array = [] ## por vaga: {} ou {"crop": "cenoura", "t": hora em que plantou}
var _stages: Array = [] # estágio desenhado em cada vaga (-1 = vazia)
var _plants: Array = [] # Node3D de cada vaga
var extra := {} ## estado salvo de armadilhas (usos, armada, vida)
var trap: Trap
var board: DrawBoard

static var _material: Material


func setup(kind_: String) -> void:
	kind = kind_
	collision_layer = 1 | (1 << 5)
	collision_mask = 0
	add_to_group("interactable")
	var slots := slot_positions()
	crops.resize(slots.size())
	for i in slots.size():
		crops[i] = {}
		_stages.append(-1)
		var plant := Node3D.new()
		plant.position = slots[i]
		add_child(plant)
		_plants.append(plant)
	_build()
	if Fluids.PORTS.has(kind) and not kind in SteamModels.KINDS:
		SteamModels.add_ports(self) # flange de latão onde o cano encaixa (carneiro, coletor)
	if kind in AutoMachines.HUB_KINDS:
		AutoMachines.add_hub(self) # porta de latão nova (versão automática da máquina de mão)
	if Power.is_machine(kind) and kind != "electric_motor":
		PowerParts.add_lamp(self) # luz de força em cima da porta de latão


func is_farm() -> bool:
	return kind in FARM_KINDS


## Onde fica cada planta (espaço local).
func slot_positions() -> Array:
	match kind:
		"pot_small":
			return [Vector3(0, 0.3, 0)]
		"pot_wide":
			return [Vector3(-0.4, 0.34, 0), Vector3(0, 0.34, 0), Vector3(0.4, 0.34, 0)]
		"bed":
			var list := []
			for j in 3:
				for i in 3:
					list.append(Vector3(0.47 + i * 0.93, 0.22, 0.47 + j * 0.93))
			return list
		"ground":
			return [Vector3(0, 0.06, 0)]
		"campfire":
			return _grid_slots(3, 2, 0.22, 0.2, 0.6)
		"rotisserie":
			return _grid_slots(4, 1, 0.28, 0.0, 0.6) # no espeto
		"dryer":
			return _grid_slots(6, 1, 0.22, 0.0, 1.05)
		"filter":
			return _grid_slots(3, 2, 0.16, 0.16, 0.0) # garrafas na base do funil
		"smoker":
			return _grid_slots(3, 2, 0.2, 0.16, 1.2) # penduradas nas varas, dentro
		"compost":
			return _grid_slots(3, 3, 0.26, 0.24, 0.5)
	return []


## Lugares em grade (colunas x linhas), centralizada, na altura y.
func _grid_slots(cols: int, rows: int, dx: float, dz: float, y: float) -> Array:
	var list := []
	for j in rows:
		for i in cols:
			list.append(Vector3((i - (cols - 1) * 0.5) * dx, y, (j - (rows - 1) * 0.5) * dz))
	return list


func allows(crop: String) -> bool:
	return is_farm() and not extra.has("tree") and not (kind == "pot_small" and crop == "abobora")


## Canteiro: a vaga do meio é o cesto (a colheita vai para ele, não dá para plantar).
const BASKET_SLOT := 4


func has_basket() -> bool:
	return kind == "bed"


func plantable(slot: int) -> bool:
	return not (has_basket() and slot == BASKET_SLOT)


func basket_key() -> String:
	return "placed_%d" % net_id


func basket_count() -> int:
	var n := 0
	if ContainerManager.i:
		for s in ContainerManager.i.slots_of(basket_key()):
			if not s.is_empty():
				n += s.amount
	return n


## A mira está no cesto? (raio da câmera do jogador)
func aiming_basket(player: Node) -> bool:
	if not has_basket() or player.get("camera") == null:
		return false
	var cam: Camera3D = player.camera
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position,
		cam.global_position - cam.global_basis.z * 4.0, 1 | (1 << 5), [player.get_rid()]))
	if hit.is_empty() or hit.collider != self:
		return false
	var local := to_local(hit.position)
	var c: Vector3 = slot_positions()[BASKET_SLOT]
	return Vector2(local.x - c.x, local.z - c.z).length() < 0.42


# --- Fogo (acende só em uso) -----------------------------------------------------

const LIT_KINDS := ["campfire", "furnace", "stone_furnace", "oven", "smoker", "blast_furnace", "boiler", "distillery", "torch", "torch_wall", "rotisserie", "forge", "foundry", "weld_bench", "torch_bench", "chem_bench"]


## Está acesa agora? Fogueira: tem lenha queimando. Fornalhas: combustível
## queimando. Forno: assou algo há pouco. Defumador: tem peixe defumando.
func is_lit(clock := -1.0) -> bool:
	if clock < 0.0:
		var manager := get_parent() as PlacedManager
		clock = manager.clock if manager else 0.0
	match kind:
		"campfire", "torch", "torch_wall", "rotisserie":
			return extra.get("fuel_until", 0.0) > clock
		"furnace", "stone_furnace", "blast_furnace", "boiler", "distillery":
			return extra.get("burn", 0.0) > 0.0
		"oven":
			return extra.get("lit_until", 0.0) > clock
		"smoker":
			return crops.any(func(c): return Cooking.stage(c, clock) == 0)
		"forge", "foundry", "weld_bench", "torch_bench", "chem_bench":
			return Smithing.is_lit(self, clock)
	return false


# --- Coletor de água da chuva ----------------------------------------------------

const COLLECTOR_CAP := 5 ## garrafas
var _water_mesh: Node3D


func _refresh_collector() -> void:
	if _water_mesh == null:
		_water_mesh = get_node_or_null("Water")
	if _water_mesh:
		var level := clampf(extra.get("water", 0.0) / COLLECTOR_CAP, 0.0, 1.0)
		_water_mesh.visible = level > 0.01
		_water_mesh.scale.y = maxf(level, 0.01)


func _exit_tree() -> void:
	Cooking.fires.erase(self)


# --- Árvore plantada (muda) ----------------------------------------------------------

const TREE_TIME := 480.0 ## segundos até a muda virar árvore
var _tree_stage := -1
var _tree_visual: Node3D


func tree_growth(clock: float) -> float:
	if extra.get("deco", false):
		return 0.0 # no vaso/floreira não cresce
	return clampf((clock - extra.get("t", clock)) / TREE_TIME, 0.0, 1.0)


func _refresh_tree(clock: float) -> void:
	var stage := mini(int(tree_growth(clock) * 3.0), 3)
	if stage == _tree_stage:
		return
	_tree_stage = stage
	if _tree_visual:
		_tree_visual.queue_free()
	if stage == 0:
		_tree_visual = ItemModels.build(&"muda")
		_tree_visual.scale = Vector3.ONE * (1.1 if extra.get("deco", false) else 1.6)
	else:
		_tree_visual = MeshInstance3D.new()
		(_tree_visual as MeshInstance3D).mesh = TerrainProps._mesh("tree")
		_tree_visual.scale = Vector3.ONE * [0.35, 0.65, 1.0][stage - 1]
	add_child(_tree_visual)
	for child in get_children():
		if child is CollisionShape3D:
			child.queue_free()
	var scale: float = [0.3, 0.35, 0.65, 1.0][stage]
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.24 * scale
	cylinder.height = 2.4 * scale
	var shape := CollisionShape3D.new()
	shape.shape = cylinder
	shape.position.y = cylinder.height * 0.5
	add_child(shape)


## Golpe de machado na árvore adulta: o host conta a "vida" e derruba.
func tool_hit(_player: Node, weapon_type: int, damage: float, point: Vector3) -> void:
	if kind != "tree":
		return
	var manager := get_parent() as PlacedManager
	ImpactFX.burst(manager.get_parent(), point, Vector3.UP, Color(0.5, 0.35, 0.2), 8, 2.0, 0.05)
	Sfx.play_at("knock", point, 2.0, 0.6)
	if tree_growth(manager.clock) < 1.0 and not extra.get("deco", false):
		return # muda: ainda não dá madeira
	manager.request("chop", [net_id, damage * (1.0 if weapon_type == Player.WeaponType.AXE else 0.2)])


func slot_world(i: int) -> Vector3:
	return to_global(slot_positions()[i])


static func progress(entry: Dictionary, clock: float) -> float:
	# (boost: irrigada pelo carneiro hidráulico cresce mais rápido)
	if entry.is_empty():
		return -1.0
	# Relógio das plantas (PlacedManager.grow_clock): anda a 20% de noite.
	var time: float = Farming.grow_time(entry.crop) / entry.get("boost", 1.0)
	return clampf((PlacedManager.grow_clock - entry.t) / time, 0.0, 1.0)


## Atualiza o desenho das plantas (chamado ~1x por segundo pelo manager).
func refresh(clock: float) -> void:
	if kind == "tree":
		_refresh_tree(clock)
		return
	if PowerParts.has(kind):
		PowerParts.refresh(self)
		return
	if Power.is_machine(kind):
		PowerParts.refresh_lamp(self)
	if kind in LIT_KINDS:
		StationModels.set_lit(self, is_lit(clock))
	if kind == "grindstone":
		AutoMachines.refresh_grind(self)
	if Smithing.has(kind):
		Smithing.refresh(self, clock) # peça em brasa esfriando na bigorna
		return
	if PlacedTorch.has(kind):
		return
	if Electric.has(kind):
		if kind == "radio":
			Radio.refresh(self)
		else:
			ElectricModels.refresh(self)
		return
	if Decor.has(kind):
		Decor.refresh(self)
		return
	if Drill.has(kind):
		Drill.refresh(self)
	if kind in SteamModels.KINDS:
		SteamModels.refresh(self)
		return
	if Ranch.has(kind):
		Ranch.refresh(self)
		return
	if kind == "rain_collector":
		_refresh_collector()
		return
	if has_basket():
		var fill := get_node_or_null("Fill") as Node3D
		if fill:
			fill.visible = basket_count() > 0
	if kind in Cooking.KINDS:
		for i in crops.size():
			var st := Cooking.stage(crops[i], clock)
			if st != _stages[i]:
				_stages[i] = st
				for child in _plants[i].get_children():
					child.queue_free()
				if st >= 0:
					_plants[i].add_child(Cooking.model(crops[i], clock))
		return
	if trap:
		trap.refresh()
		return
	for i in crops.size():
		var p := progress(crops[i], clock)
		var stage := -1 if p < 0.0 else mini(int(p * 3.0), 3)
		if stage != _stages[i]:
			_stages[i] = stage
			for child in _plants[i].get_children():
				child.queue_free()
			if stage >= 0:
				_plants[i].add_child(Farming.plant_model(crops[i].crop, stage, kind == "bed"))


func ready_count(clock: float) -> int:
	var n := 0
	for entry in crops:
		if progress(entry, clock) >= 1.0:
			n += 1
	return n


func get_interact_text() -> String:
	var manager := get_parent() as PlacedManager
	var clock := manager.clock if manager else 0.0
	match kind:
		"bench":
			return "[E] Bancada (fabricar)"
		"workbench":
			return "[E] Mesa de trabalho (metal, armas, ferramentas)"
		"furnace":
			return "[E] Fornalha (fundir minério, vidro, carvão)"
		"campfire", "dryer", "filter", "smoker", "compost", "rotisserie":
			return Cooking.text(self, clock)
		"grindstone", "quern", "pump", "spinning", "loom", "stone_furnace", "oven", "sieve", "sawmill", "water_wheel", "windmill", "shaft", "ram_pump":
			return Machines.text(self)
	if Drill.has(kind):
		return Drill.text(self)
	if kind in SteamModels.KINDS:
		return SteamModels.text(self)
	if Smithing.has(kind):
		return Smithing.text(self)
	if Ranch.has(kind):
		return Ranch.text(self)
	if PowerParts.has(kind):
		return PowerParts.text(self)
	if Electric.has(kind):
		return Electric.text(self)
	if Decor.has(kind):
		return Decor.text(self)
	if PlacedTorch.has(kind):
		return PlacedTorch.text(self, clock)
	match kind:
		"rain_collector":
			var water: float = extra.get("water", 0.0)
			return "Coletor de chuva: %d de %d garrafas%s" % [int(water), COLLECTOR_CAP, "  [E] encher garrafa" if water >= 1.0 else ""]
		"drawboard":
			return "[E] Desenhar na lousa"
		"tree":
			var growth := tree_growth(clock)
			if extra.get("deco", false):
				return "Muda"
			return "Árvore" if growth >= 1.0 else "Muda de árvore %d%%" % int(growth * 100.0)
		"chest":
			return "[E] Abrir baú"
		"airdrop":
			return "[E] Abrir airdrop"
		"flag":
			return "[E] Recolher bandeira"
	if trap:
		return trap.get_text()
	if has_basket():
		var player := get_tree().get_first_node_in_group("player")
		if player and aiming_basket(player):
			return "[E] Cesto (%d colhido%s)" % [basket_count(), "s" if basket_count() != 1 else ""]
	var ready := ready_count(clock)
	if ready > 0:
		return "[E] Colher (%d pronta%s)" % [ready, "s" if ready > 1 else ""]
	var growing := []
	for entry in crops:
		if not entry.is_empty():
			growing.append("%s %d%%" % [ItemDB.display_name(Farming.CROPS[entry.crop].food), progress(entry, clock) * 100.0])
	if growing.is_empty():
		return "Vazio: plante com sementes na mão ou com a pá"
	return " · ".join(growing.slice(0, 3)) + (" ..." if growing.size() > 3 else "")


func interact(player: Node) -> void:
	var manager := get_parent() as PlacedManager
	if manager == null:
		return
	if STATIONS.has(kind):
		CraftingUI.open_for(player, STATIONS[kind])
		return
	if kind == "furnace":
		StorageUI.open_for(player, Smelting.key_of(self), self)
		return
	if kind in Cooking.KINDS:
		Cooking.interact(player, self)
		return
	if Machines.is_crank(kind) or kind in ["oven", "sawmill"]:
		Machines.tap(player, self)
		return
	if Drill.has(kind):
		Drill.tap(player, self)
		return
	if kind in SteamModels.KINDS:
		SteamModels.interact(player, self)
		return
	if Smithing.has(kind):
		Smithing.interact(player, self) # lugares (e as peças das estações de minigame)
		return
	if Ranch.has(kind):
		Ranch.interact(player, self)
		return
	if PowerParts.has(kind):
		Sfx.play("click", -6.0, 0.6)
		return
	if Electric.has(kind):
		Electric.interact(player, self)
		return
	if PlacedTorch.has(kind):
		PlacedTorch.interact(player, self)
		return
	if Decor.has(kind):
		return
	if kind == "ram_pump":
		var bottle := Cooking.find_any(player.inventory, {&"garrafa": true})
		if bottle < 0:
			Sfx.play("click", -6.0, 0.6)
			return
		player.inventory.take(bottle, 1)
		player.pick_up(&"agua_suja", ItemDB.display_name(&"agua_suja"), 1)
		Sfx.play_at("slap", global_position + Vector3.UP, -4.0, 1.3)
		return
	if board:
		DrawUI.open_for(player, board)
		return
	if kind in ["chest", "airdrop"]:
		StorageUI.open_for(player, "placed_%d" % net_id)
		return
	if kind == "rain_collector":
		# Garrafa vazia de qualquer lugar da mochila.
		var bottle := Cooking.find_any(player.inventory, {&"garrafa": true})
		if bottle < 0 or extra.get("water", 0.0) < 1.0:
			Sfx.play("click", -6.0, 0.6)
			return
		player.inventory.take(bottle, 1)
		ItemFly.play(&"agua", global_position + Vector3.UP * 1.0, player)
		manager.request("draw_water", [net_id])
		Sfx.play_at("slap", global_position + Vector3.UP, -6.0, 1.4)
		return
	if kind == "flag":
		manager.request("remove", [net_id])
		Sfx.play_at("step_soft", global_position, 0.0, 1.2)
		return
	if trap:
		trap.interact(player)
		return
	if has_basket() and (aiming_basket(player) or ready_count(manager.clock) == 0):
		StorageUI.open_for(player, basket_key()) # cesto do canteiro: pega o que foi colhido
		return
	for i in crops.size():
		if progress(crops[i], manager.clock) >= 1.0:
			manager.request("harvest", [net_id, i])


# --- Modelos ---------------------------------------------------------------------

func _build() -> void:
	if kind == "tree":
		return # desenho e colisão vêm do crescimento (_refresh_tree)
	if Drill.has(kind):
		Drill.build(self) # perfuratriz (jazida infinita)
		return
	if kind in SteamModels.KINDS:
		SteamModels.build(kind, self)
		if kind in LIT_KINDS:
			StationModels.set_lit(self, false)
		return
	if Ranch.has(kind):
		Ranch.build(kind, self) # cocho, bebedouro, cerca, porteira
		return
	if PowerParts.has(kind):
		PowerParts.build(self) # eixo, tripé, engrenagem, polia
		return
	if Smithing.has(kind):
		SmithingModels.build(kind, self) # forja, fundição, bancada de solda (elétrica), trefiladora
		StationModels.set_lit(self, false)
		return
	if Electric.has(kind):
		ElectricModels.build(kind, self) # Tier 4: cabos, geradores, lâmpadas, rádio...
		return
	if kind == "rotisserie":
		AutoMachines.build_rotisserie(self) # assador giratório (fogueira com espeto no eixo)
		StationModels.set_lit(self, false)
		return
	if Decor.has(kind):
		Decor.build(kind, self)
		return
	if PlacedTorch.has(kind):
		PlacedTorch.build(kind, self)
		return
	if ObjectModels.has(kind):
		ObjectModels.build(kind, self) # plantadores, estações e máquinas (Tier 0-2)
		if kind == "campfire":
			Cooking.fires.append(self)
		if kind in LIT_KINDS:
			StationModels.set_lit(self, false)
		return
	if kind == "airdrop":
		var fx := AirdropFX.new()
		add_child(fx)
		fx.setup("placed_%d" % net_id)
		_shape(Vector3(0, 0.42, 0), Vector3(1.1, 0.84, 1.1))
		return
	if kind == "drawboard":
		board = DrawBoard.new()
		add_child(board)
		board.setup(self)
		return
	if kind in TRAPS:
		trap = Trap.new()
		add_child(trap)
		trap.setup(self)
		if kind != "barbed":
			collision_layer = 1 << 5 # pisável: zumbis e jogadores passam por cima
		return
	var mb := MeshBuilder.new()
	match kind:
		"stairs":
			# Escada de madeira: sobe um andar (2,8 m) em 7 degraus de 0,4 m, para
			# a frente (-Z). Duas longarinas inclinadas, degraus com espelho e corrimão.
			var wood := Color(0.44, 0.3, 0.17)
			var rise := BuildPiece.SIZE / 7.0
			var slope := Vector3(0, BuildPiece.SIZE, -BuildPiece.SIZE)
			var along := slope.length()
			var tilt := Basis(Vector3.RIGHT, PI / 4)
			for side in [-0.56, 0.56]:
				mb.color(wood.darkened(0.15))
				mb.box(Vector3(side, BuildPiece.SIZE * 0.5 - 0.12, -BuildPiece.SIZE * 0.5), Vector3(0.08, 0.26, along), tilt) # longarina
			for k in 7:
				var top: float = (k + 1) * rise
				var z := -(k + 0.5) * rise
				mb.color(wood.darkened(0.04 * (k % 2)))
				mb.box(Vector3(0, top - 0.025, z - 0.01), Vector3(1.04, 0.05, rise + 0.04)) # piso do degrau
				mb.color(wood.darkened(0.25))
				mb.box(Vector3(0, top - rise * 0.5, z + rise * 0.5 - 0.02), Vector3(1.04, rise - 0.05, 0.03)) # espelho
				mb.color(ItemModels.IRON)
				for x in [-0.45, 0.45]:
					mb.box(Vector3(x, top + 0.002, z), Vector3(0.012, 0.004, 0.012)) # pregos
			# Corrimão num lado, com balaústres.
			mb.color(wood.darkened(0.1))
			for k in [0, 3, 6]:
				var top: float = (k + 1) * rise
				mb.box(Vector3(0.56, top + 0.45, -(k + 0.5) * rise), Vector3(0.05, 0.9, 0.05))
			mb.box(Vector3(0.56, BuildPiece.SIZE * 0.5 + 0.88, -BuildPiece.SIZE * 0.5), Vector3(0.06, 0.06, along), tilt)
			# Colisão: rampa lisa um pouco menos íngreme que os degraus (~42°), começando
			# na frente do primeiro degrau. Andar sobe sozinho; degraus de verdade
			# (0,4 m um atrás do outro) travariam o "subir degrau".
			var ramp := CollisionShape3D.new()
			var wedge := ConvexPolygonShape3D.new()
			var s2 := BuildPiece.SIZE
			wedge.points = PackedVector3Array([Vector3(-0.6, 0, 0.3), Vector3(0.6, 0, 0.3), Vector3(-0.6, 0, -s2), Vector3(0.6, 0, -s2),
				Vector3(-0.6, s2, -s2), Vector3(0.6, s2, -s2)])
			ramp.shape = wedge
			add_child(ramp)
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(_mat(), false)
	add_child(mesh)


func _shape(center: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	add_child(shape)


static func _mat() -> Material:
	if _material == null:
		_material = Look.surface(true, 0.8, 0.92) # máquinas, estações, armadilhas: textura um pouco mais leve
	return _material
