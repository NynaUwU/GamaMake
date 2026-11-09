class_name AutoMachines
extends RefCounted
## Versões automáticas (com força no eixo, ou motor elétrico na porta de latão) das
## máquinas que eram só na mão:
##   sieve          peneira: com força, peneira sozinha a argila posta
##   stone_furnace  fornalha de pedra: com força, o fole sopra sozinho (esquenta enquanto
##                  tem minério para fundir)
##   grindstone     pedra de amolar: com força, [E] com a lâmina/ferramenta na mão deixa ela
##                  na pedra; afia sozinha (~14 s até o fio cheio, +35% de dano) e [E] pega
##   pump           bomba d'água: com força, põe 1 de água por segundo no cano (flange de
##                  latão); garrafa no [E] continua funcionando
##   rotisserie     assador giratório: fogueira com espeto que gira pelo eixo; assa 4
##                  peças e NÃO QUEIMA (o espeto fica girando a comida pronta)
## As máquinas que já eram sozinhas continuam (secador, filtro, defumador, composteira,
## fornalhas, forno); as de manivela que já tinham porta (moinho, roca, tear) também.

const HUB_KINDS := ["grindstone", "sieve", "stone_furnace", "pump"]
const GRIND_RATE := 0.07 ## fio por segundo com força


## Caixinha de engrenagem com a polia de latão na porta nova (as máquinas antigas
## não tinham porta desenhada).
static func add_hub(obj: PlacedObject) -> void:
	var ports: Array = Power.PORTS.get(obj.kind, [])
	if ports.is_empty() or obj.get_node_or_null("PortHub"):
		return
	var at: Vector3 = ports[0][0]
	var out: Vector3 = ports[0][1]
	var mb := MeshBuilder.new()
	var basis := Basis(out, Vector3.UP, out.cross(Vector3.UP))
	mb.color(ObjectModels.IRON)
	mb.box(at - out * 0.12, Vector3(0.16, 0.18, 0.18), basis)
	mb.box(at - out * 0.12 + Vector3.DOWN * 0.34, Vector3(0.08, 0.5, 0.08), basis) # pé até o chão
	mb.color(ItemModels.BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.02, -0.03), Vector2(0.1, -0.03), Vector2(0.11, 0.0), Vector2(0.1, 0.03), Vector2(0.02, 0.03)]), 12,
		basis * Basis(Vector3.BACK, -PI / 2), at - out * 0.02)
	mb.color(ItemModels.STEEL)
	mb.tube(PackedVector3Array([at - out * 0.2, at]), 0.022, 6)
	var node := MeshInstance3D.new()
	node.name = "PortHub"
	node.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(node)


# --- Pedra de amolar automática ---------------------------------------------------------

static func grinding(obj: PlacedObject) -> bool:
	var tool: Dictionary = obj.extra.get("tool", {})
	return not tool.is_empty() and float(tool.get("sharp", 0.0)) < 0.999


## Host, 1x por segundo com força: afia a ferramenta posta. true = mudou.
static func host_grind(obj: PlacedObject) -> bool:
	if not grinding(obj):
		return false
	var tool: Dictionary = obj.extra.tool.duplicate()
	tool.sharp = minf(float(tool.get("sharp", 0.0)) + GRIND_RATE, 1.0)
	obj.extra.tool = tool
	return true


## Quem pegou a ferramenta de volta recebe com a durabilidade e o fio dela.
static func receive(manager: PlacedManager, tool: Dictionary) -> void:
	var world := manager.get_parent()
	var player: Player = world.get("player")
	if player == null or tool.is_empty():
		return
	var id := StringName(tool.id)
	var dur := float(tool.get("dur", 1.0))
	if player.inventory.add(id, 1, dur) > 0:
		Net.i.drop_item(id, 1, player.global_transform.translated(Vector3.UP), Vector3.ZERO, dur) # mochila cheia
		return
	for slot in player.inventory.slots:
		if not slot.is_empty() and slot.id == id and not slot.has("sharp") and is_equal_approx(float(slot.get("dur", 1.0)), dur):
			if float(tool.get("sharp", 0.0)) > 0.0:
				slot.sharp = float(tool.sharp)
			break
	player.inventory.changed.emit()
	ItemFly.play(id, player.global_position + Vector3.UP, player)


## [E] com força: põe a ferramenta da mão na pedra, ou pega a que está nela.
## false = não é o caso (sem força): segue o uso normal (segurar E com a ferramenta).
static func grind_tap(player: Player, obj: PlacedObject) -> bool:
	var manager := obj.get_parent() as PlacedManager
	if not obj.extra.get("tool", {}).is_empty():
		# Pegar de volta funciona sempre (pronta, o motor já parou de girar).
		manager.request("grind_take", [obj.net_id])
		Sfx.play_at("pickup", obj.global_position + Vector3.UP * 0.8, 0.0, 1.1)
		return true
	if obj.extra.get("pstate", "") != "ok" and not _has_driver(obj):
		return false
	var slot: Dictionary = player.inventory.slots[player.inventory.selected]
	if slot.is_empty() or not ItemDB.sharpenable(slot.id) or float(slot.get("sharp", 0.0)) >= 0.999:
		Sfx.play("click", -6.0, 0.6)
		return true
	var tool := {"id": String(slot.id), "dur": slot.get("dur", 1.0), "sharp": float(slot.get("sharp", 0.0))}
	player.inventory.take(player.inventory.selected, 1)
	manager.request("grind_put", [obj.net_id, tool])
	Sfx.play_at("knock", obj.global_position + Vector3.UP * 0.8, -2.0, 1.3)
	return true


## Tem como girar? (força agora, ou motor/eixo encostado na porta esperando trabalho)
static func _has_driver(obj: PlacedObject) -> bool:
	return obj.extra.get("driven", false) # Power.tick marca (vai para os clientes também)


static func grind_text(obj: PlacedObject) -> String:
	var tool: Dictionary = obj.extra.get("tool", {})
	if not tool.is_empty():
		return "Pedra de amolar: %s · fio %d%%  [E] pegar" % [ItemDB.display_name(StringName(tool.id)), int(float(tool.get("sharp", 0.0)) * 100.0)]
	if obj.extra.get("pstate", "") == "ok" or _has_driver(obj):
		return "Pedra de amolar (no eixo)  [E] deixar a arma/ferramenta da mão para afiar"
	return ""


## Ferramenta deitada no apoio enquanto amola.
static func refresh_grind(obj: PlacedObject) -> void:
	var tool: Dictionary = obj.extra.get("tool", {})
	var shown := obj.get_node_or_null("GrindTool") as Node3D
	var id := String(tool.get("id", ""))
	if shown and shown.get_meta("id", "") == id:
		return
	if shown:
		shown.queue_free()
	if id == "":
		return
	var model := ItemModels.build(StringName(id))
	model.name = "GrindTool"
	model.set_meta("id", id)
	model.position = Vector3(0.0, 0.66, 0.24)
	model.rotation = Vector3(-PI / 2, PI / 2, 0)
	model.scale = Vector3.ONE * 0.8
	obj.add_child(model)


# --- Assador giratório ----------------------------------------------------------------------

static func build_rotisserie(obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	# Fogo no chão entre pedras, dois cavaletes de ferro em X e o espeto comprido com 4
	# garfos; na ponta esquerda a engrenagem da porta de latão (o eixo gira o espeto).
	for x in [-0.3, 0.0, 0.3]:
		ObjectModels._stone_ring(mb, Vector3(x, 0, 0), 0.32, 8, Vector3(0.16, 0.13, 0.12), 7 + int(x * 10.0))
	mb.color(ObjectModels.SOOT)
	mb.box(Vector3(0, 0.03, 0), Vector3(0.9, 0.04, 0.4))
	for k in 5:
		var a := k * 0.9
		mb.color(ObjectModels.WOOD_DARK)
		mb.tube(PackedVector3Array([Vector3(-0.35 + k * 0.17, 0.04, -0.12), Vector3(-0.3 + k * 0.17, 0.12, 0.12)]), 0.035, 5)
		mb.color(Color(0.98, 0.5, 0.12))
		mb.box(Vector3(-0.3 + k * 0.15, 0.05, sin(a) * 0.08), Vector3(0.05, 0.03, 0.04))
	mb.color(ObjectModels.IRON)
	for x in [-0.6, 0.6]:
		for z in [-0.18, 0.18]:
			mb.tube(PackedVector3Array([Vector3(x, 0.0, z * 1.5), Vector3(x, 0.6, 0)]), 0.02, 5)
		mb.box(Vector3(x, 0.6, 0), Vector3(0.05, 0.05, 0.08)) # mancal do espeto
	mb.box(Vector3(-0.72, 0.6, 0), Vector3(0.14, 0.16, 0.16)) # caixinha da engrenagem
	mb.box(Vector3(-0.72, 0.26, 0), Vector3(0.06, 0.52, 0.06))
	mb.color(ItemModels.BRASS)
	mb.lathe(PackedVector2Array([Vector2(0.02, -0.03), Vector2(0.1, -0.03), Vector2(0.11, 0.0), Vector2(0.1, 0.03), Vector2(0.02, 0.03)]), 12,
		Basis(Vector3.BACK, -PI / 2), Vector3(-0.8, 0.6, 0))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	# Espeto (gira junto com a comida).
	var spit := MeshBuilder.new()
	spit.color(ItemModels.STEEL)
	spit.tube(PackedVector3Array([Vector3(-0.66, 0, 0), Vector3(0.7, 0, 0)]), 0.012, 5)
	for k in 4:
		var x := -0.42 + k * 0.28
		spit.box(Vector3(x, 0, 0), Vector3(0.012, 0.09, 0.012))
	spit.color(ObjectModels.WOOD_LIGHT)
	spit.tube(PackedVector3Array([Vector3(0.7, 0, 0), Vector3(0.7, 0.12, 0), Vector3(0.78, 0.14, 0)]), 0.014, 4) # manivela (enfeite)
	var node := MeshInstance3D.new()
	node.name = "Spin"
	node.mesh = spit.finish(PlacedObject._mat(), false)
	node.position = Vector3(0, 0.6, 0)
	obj.add_child(node)
	var spinner := PowerSpin.new()
	spinner.axis = Vector3.RIGHT
	obj.add_child(spinner)
	obj.add_child(SpitTurner.new())
	StationModels._fire(obj, Vector3(0, 0.12, 0), 0.25, 0.9)
	obj._shape(Vector3(0, 0.35, 0), Vector3(1.4, 0.7, 0.6))
	Cooking.fires.append(obj)


## Gira a comida espetada junto com o espeto (só visual, em cada jogador).
class SpitTurner extends Node:
	func _process(delta: float) -> void:
		var obj := get_parent() as PlacedObject
		if obj == null or obj.extra.get("speed", 0.0) <= 0.0:
			return
		for plant in obj._plants:
			plant.rotate_object_local(Vector3.RIGHT, delta * PowerSpin.RATE)
