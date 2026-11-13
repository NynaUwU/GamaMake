class_name Drill
extends RefCounted
## Perfuratriz (fase 3 do terreno em voxels): posta em cima de uma JAZIDA (o salão no fim de
## algumas entradas de caverna, TerrainWorld.deposit_near), com força no eixo (roda d'água,
## moinho de vento, motor a vapor ou motor elétrico na porta de latão), tira minério sozinha
## sem a jazida acabar: 1 a cada RATE segundos, até CAP guardados. [E] pega tudo.
## Guarda em PlacedObject.extra: "ore" (item da jazida, decidido pelo host ao pôr), "out"
## (prontos) e "prog" (segundos de broca girando).

const KIND := "drill"
const RATE := 5.0 ## segundos de força por minério
const CAP := 100
const DEMAND := 3.0 ## carga no eixo (= Power.DEMAND.drill)
const NAME := "Perfuratriz"

const STEEL := Color(0.5, 0.51, 0.53)
const IRON := Color(0.22, 0.21, 0.21)
const BRASS := Color(0.62, 0.5, 0.26)
const WOOD := Color(0.4, 0.26, 0.15)
const PAINT := Color(0.62, 0.42, 0.12) # amarelo de máquina de mina, gasto


static func has(kind: String) -> bool:
	return kind == KIND


## Tem trabalho? (jazida embaixo e espaço para guardar)
static func busy(obj: PlacedObject) -> bool:
	return String(obj.extra.get("ore", "")) != "" and int(obj.extra.get("out", 0)) < CAP


## Host, 1x por segundo com força: a broca avança. true = mudou.
static func host_step(obj: PlacedObject) -> bool:
	if not busy(obj):
		return false
	var prog: float = float(obj.extra.get("prog", 0.0)) + 1.0
	var out := int(obj.extra.get("out", 0))
	while prog >= RATE and out < CAP:
		prog -= RATE
		out += 1
	obj.extra.prog = prog
	obj.extra.out = out
	return true


static func text(obj: PlacedObject) -> String:
	var ore := StringName(obj.extra.get("ore", ""))
	if ore == &"":
		return NAME + ": sem jazida embaixo (ponha no salão do fim de uma caverna, em cima do veio colorido)"
	var out := int(obj.extra.get("out", 0))
	var parts := "%s (jazida de %s): %d pronto%s" % [NAME, ItemDB.display_name(ore).to_lower(), out, "" if out == 1 else "s"]
	if out >= CAP:
		parts += " (cheia)"
	parts += " · " + Power.status(obj)
	return parts + ("  [E] pegar" if out > 0 else "")


## [E]: pega o minério pronto (voa até a mochila).
static func tap(player: Player, obj: PlacedObject) -> void:
	var manager := obj.get_parent() as PlacedManager
	if int(obj.extra.get("out", 0)) <= 0 or manager == null:
		Sfx.play("click", -6.0, 0.6)
		return
	ItemFly.play(StringName(obj.extra.ore), obj.global_position + Vector3.UP * 0.9, player)
	manager.request("drill_take", [obj.net_id])
	Sfx.play_at("pickup", obj.global_position + Vector3.UP, 0.0, 1.0)


## Host: entrega o que está pronto para quem pediu.
static func host_take(obj: PlacedObject) -> bool:
	var out := int(obj.extra.get("out", 0))
	if out <= 0 or String(obj.extra.get("ore", "")) == "":
		return false
	Net.i.give_to(Net.i.request_peer, StringName(obj.extra.ore), out)
	obj.extra.out = 0
	return true


## Monte de minério na caçamba (aparece com minério pronto).
static func refresh(obj: PlacedObject) -> void:
	var pile := obj.get_node_or_null("Pile") as Node3D
	if pile and pile.get_meta("ore", &"") != StringName(obj.extra.get("ore", "")):
		pile.free() # a jazida chegou do host depois do modelo: refaz na cor certa
		pile = _build_pile(obj)
	if pile:
		var out := int(obj.extra.get("out", 0))
		pile.visible = out > 0
		pile.scale = Vector3(1.0, clampf(0.3 + out / float(CAP) * 1.4, 0.3, 1.7), 1.0)


# --- Modelo --------------------------------------------------------------------------------

## Torre de aço em pirâmide com roldana no alto, caixa de engrenagem no meio (porta de latão à
## esquerda), broca em espiral descendo para dentro do chão (gira com força) e uma caçamba de
## madeira do lado onde o minério cai.
static func build(obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	# Base: dois patins de ferro e o estrado de pranchas.
	mb.color(IRON)
	for z in [-0.55, 0.55]:
		mb.box(Vector3(0, 0.06, z), Vector3(1.5, 0.12, 0.14))
	mb.color(WOOD)
	for k in 6:
		mb.box(Vector3(-0.6 + k * 0.24, 0.14, 0), Vector3(0.2, 0.05, 1.3))
	mb.color(IRON.darkened(0.3))
	mb.box(Vector3(0, 0.17, 0), Vector3(0.36, 0.02, 0.36)) # furo no estrado
	# Torre: 4 pernas de cantoneira subindo para o topo, travessas e roldana.
	var top := Vector3(0, 2.5, 0)
	mb.color(PAINT)
	for corner in [Vector3(-0.6, 0.15, -0.5), Vector3(0.6, 0.15, -0.5), Vector3(-0.6, 0.15, 0.5), Vector3(0.6, 0.15, 0.5)]:
		mb.tube(PackedVector3Array([corner, top + Vector3(corner.x, 0, corner.z) * 0.18]), 0.045, 4)
	mb.color(PAINT.darkened(0.25))
	for y: float in [0.9, 1.7]:
		var f: float = 1.0 - (y - 0.15) / 2.35 * 0.82
		mb.box(Vector3(0, y, -0.5 * f), Vector3(1.2 * f, 0.05, 0.05))
		mb.box(Vector3(0, y, 0.5 * f), Vector3(1.2 * f, 0.05, 0.05))
		mb.box(Vector3(-0.6 * f, y, 0), Vector3(0.05, 0.05, 1.0 * f))
		mb.box(Vector3(0.6 * f, y, 0), Vector3(0.05, 0.05, 1.0 * f))
	mb.color(IRON)
	mb.box(top + Vector3(0, 0.05, 0), Vector3(0.36, 0.1, 0.3))
	mb.color(STEEL)
	mb.lathe(PackedVector2Array([Vector2(0.02, -0.04), Vector2(0.15, -0.04), Vector2(0.15, 0.04), Vector2(0.02, 0.04)]), 10,
		Basis(Vector3.RIGHT, PI / 2), top + Vector3(0, 0.2, 0)) # roldana
	# Caixa de engrenagem no meio da torre, com o eixo até a porta de latão (Power.PORTS).
	mb.color(IRON)
	mb.box(Vector3(0, 0.62, 0), Vector3(0.5, 0.4, 0.46))
	mb.color(IRON.lightened(0.1))
	mb.box(Vector3(0, 0.84, 0), Vector3(0.54, 0.04, 0.5))
	mb.color(STEEL)
	mb.tube(PackedVector3Array([Vector3(-0.25, 0.6, 0), Vector3(-0.72, 0.6, 0)]), 0.03, 6)
	mb.color(BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.02, -0.03), Vector2(0.11, -0.03), Vector2(0.12, 0.0), Vector2(0.11, 0.03), Vector2(0.02, 0.03)]), 12,
		Basis(Vector3.BACK, PI / 2), Vector3(-0.74, 0.6, 0)) # polia de latão (a porta)
	mb.color(IRON)
	mb.box(Vector3(-0.66, 0.36, 0), Vector3(0.08, 0.44, 0.08)) # pé da porta
	# Caçamba do lado (+X), com rampa saindo da caixa.
	mb.color(WOOD.darkened(0.1))
	mb.box(Vector3(1.05, 0.2, 0), Vector3(0.5, 0.06, 0.6))
	for side in [-1.0, 1.0]:
		mb.box(Vector3(1.05, 0.38, side * 0.3), Vector3(0.5, 0.32, 0.05))
	mb.box(Vector3(1.3, 0.38, 0), Vector3(0.05, 0.32, 0.6))
	mb.color(STEEL.darkened(0.2))
	mb.box(Vector3(0.55, 0.62, 0), Vector3(0.5, 0.04, 0.22), Basis(Vector3.BACK, -0.45)) # rampa
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	# Broca (gira em Y): haste, espiral e ponta, entrando no chão.
	var spin := MeshBuilder.new()
	spin.color(STEEL)
	spin.lathe(PackedVector2Array([Vector2(0.035, -1.3), Vector2(0.035, 1.55)]), 8)
	spin.color(STEEL.darkened(0.15))
	for k in 18:
		var a := k * 0.7
		var y := -1.15 + k * 0.08
		spin.box(Vector3(cos(a) * 0.08, y, sin(a) * 0.08), Vector3(0.14, 0.025, 0.06), Basis(Vector3.UP, -a))
	spin.color(IRON)
	spin.lathe(PackedVector2Array([Vector2(0.002, -1.55), Vector2(0.1, -1.3), Vector2(0.05, -1.25)]), 8) # ponta
	var bit := MeshInstance3D.new()
	bit.name = "Spin"
	bit.mesh = spin.finish(PlacedObject._mat(), false)
	bit.position = Vector3(0, 1.0, 0)
	obj.add_child(bit)
	var spinner := PowerSpin.new()
	spinner.axis = Vector3.UP
	obj.add_child(spinner)
	_build_pile(obj)
	refresh(obj)


## Monte de minério na caçamba (cor da jazida).
static func _build_pile(obj: PlacedObject) -> Node3D:
	var ore := StringName(obj.extra.get("ore", ""))
	var pile_mb := MeshBuilder.new()
	pile_mb.color(_ore_color(ore))
	for k in 5:
		pile_mb.box(Vector3(-0.12 + (k % 3) * 0.12, 0.05 + (k / 3) * 0.06, -0.12 + (k % 2) * 0.22), Vector3(0.16, 0.12, 0.16),
			Basis(Vector3.UP, k * 0.9))
	var pile := MeshInstance3D.new()
	pile.name = "Pile"
	pile.set_meta("ore", ore)
	pile.mesh = pile_mb.finish(PlacedObject._mat(), false)
	pile.position = Vector3(1.05, 0.22, 0)
	obj.add_child(pile)
	return pile


static func _ore_color(ore: StringName) -> Color:
	match ore:
		&"carvao":
			return VoxelRef.COLORS[VoxelRef.DEPOSIT_COAL]
		&"minerio_ferro":
			return VoxelRef.COLORS[VoxelRef.DEPOSIT_IRON]
		&"minerio_cobre":
			return VoxelRef.COLORS[VoxelRef.DEPOSIT_COPPER]
		&"minerio_estanho":
			return VoxelRef.COLORS[VoxelRef.DEPOSIT_TIN]
		&"enxofre":
			return VoxelRef.COLORS[VoxelRef.DEPOSIT_SULFUR]
	return Color(0.45, 0.44, 0.42)
