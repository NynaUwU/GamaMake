class_name Decor
extends RefCounted
## Decorações (martelo, aba Decoração): só enfeite, com colisão. Lista provisória
## (o jogador vai mandar a dele). As de parede (quadro, prateleira, relógio) só vão
## mirando uma parede: z = 0 é a parede e o modelo sai para +Z.
## O relógio de parede mostra a hora do jogo (ponteiros andam no refresh).

const WOOD := Color(0.45, 0.3, 0.17)
const WOOD_DARK := Color(0.3, 0.19, 0.1)
const CLOTH := Color(0.55, 0.16, 0.12)
const FLOOR_KINDS := ["deco_table", "deco_chair", "deco_stool", "deco_rug", "deco_vase", "deco_plant", "deco_barrel", "deco_crates"]
const WALL_KINDS := ["deco_painting", "deco_shelf", "deco_clock"]
const NAMES := {"deco_table": "Mesa", "deco_chair": "Cadeira", "deco_stool": "Banquinho", "deco_rug": "Tapete",
	"deco_vase": "Vaso de flores", "deco_plant": "Planta", "deco_barrel": "Barril", "deco_crates": "Caixotes",
	"deco_painting": "Quadro", "deco_shelf": "Prateleira", "deco_clock": "Relógio"}


static func has(kind: String) -> bool:
	return kind in FLOOR_KINDS or kind in WALL_KINDS


static func text(obj: PlacedObject) -> String:
	if obj.kind == "deco_clock" and DayNight.i:
		return "Relógio: %02d:%02d" % [int(DayNight.i.hour), int(fmod(DayNight.i.hour, 1.0) * 60.0)]
	return NAMES.get(obj.kind, "Enfeite")


static func build(kind: String, obj: PlacedObject) -> void:
	var mb := MeshBuilder.new()
	match kind:
		"deco_table":
			mb.color(WOOD)
			mb.box(Vector3(0, 0.76, 0), Vector3(1.2, 0.05, 0.7))
			mb.color(WOOD_DARK)
			mb.box(Vector3(0, 0.7, 0), Vector3(1.1, 0.08, 0.6))
			for x in [-0.52, 0.52]:
				for z in [-0.28, 0.28]:
					_leg(mb, Vector3(x, 0, z), 0.7)
			obj._shape(Vector3(0, 0.39, 0), Vector3(1.2, 0.78, 0.7))
		"deco_chair":
			mb.color(WOOD)
			mb.box(Vector3(0, 0.46, 0), Vector3(0.44, 0.04, 0.44))
			for x in [-0.19, 0.19]:
				for z in [-0.19, 0.19]:
					_leg(mb, Vector3(x, 0, z), 0.45, 0.022)
			mb.color(WOOD_DARK)
			for x in [-0.19, 0.19]:
				mb.box(Vector3(x, 0.72, -0.2), Vector3(0.04, 0.52, 0.04))
			for y in [0.66, 0.84]:
				mb.box(Vector3(0, y, -0.2), Vector3(0.38, 0.06, 0.025))
			obj._shape(Vector3(0, 0.25, 0), Vector3(0.44, 0.5, 0.44))
			obj._shape(Vector3(0, 0.72, -0.2), Vector3(0.44, 0.52, 0.06))
		"deco_stool":
			mb.color(WOOD)
			mb.lathe(PackedVector2Array([Vector2(0.0, 0.48), Vector2(0.18, 0.48), Vector2(0.19, 0.5), Vector2(0.18, 0.53), Vector2(0.0, 0.53)]), 10)
			for k in 3:
				var a := TAU * k / 3.0
				mb.color(WOOD_DARK)
				mb.box(Vector3(cos(a) * 0.1, 0.24, sin(a) * 0.1), Vector3(0.035, 0.5, 0.035), Basis(Vector3(-sin(a), 0, cos(a)), 0.15))
			obj._shape(Vector3(0, 0.27, 0), Vector3(0.38, 0.54, 0.38))
		"deco_rug":
			mb.color(CLOTH)
			mb.box(Vector3(0, 0.008, 0), Vector3(1.8, 0.016, 1.2))
			mb.color(Color(0.8, 0.62, 0.3))
			mb.box(Vector3(0, 0.017, 0), Vector3(1.5, 0.004, 0.9))
			mb.color(CLOTH.darkened(0.25))
			mb.box(Vector3(0, 0.02, 0), Vector3(1.3, 0.004, 0.7))
			for k in 3:
				mb.color(Color(0.85, 0.75, 0.45))
				mb.box(Vector3(-0.4 + k * 0.4, 0.023, 0), Vector3(0.16, 0.003, 0.16), Basis(Vector3.UP, PI / 4))
			mb.color(Color(0.85, 0.78, 0.6))
			for x in range(-8, 9):
				for z in [-0.61, 0.61]:
					mb.box(Vector3(x * 0.1, 0.006, z), Vector3(0.015, 0.008, 0.04)) # franja
			obj._shape(Vector3(0, 0.01, 0), Vector3(1.8, 0.02, 1.2))
			obj.collision_layer = 1 << 5 # pisável
		"deco_vase":
			mb.color(Color(0.3, 0.42, 0.55))
			mb.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.14, 0.12), Vector2(0.12, 0.26), Vector2(0.06, 0.34), Vector2(0.075, 0.38), Vector2(0.065, 0.38)]), 10)
			mb.color(Color(0.85, 0.8, 0.65))
			mb.lathe(PackedVector2Array([Vector2(0.141, 0.14), Vector2(0.145, 0.16), Vector2(0.141, 0.18)]), 10) # faixa
			for k in 6:
				var a := TAU * k / 6.0
				var tip := Vector3(cos(a) * 0.12, 0.62 + (k % 2) * 0.08, sin(a) * 0.12)
				mb.color(Color(0.25, 0.45, 0.18))
				mb.tube(PackedVector3Array([Vector3(0, 0.34, 0), tip * Vector3(0.5, 1.0, 0.5), tip]), 0.008, 4)
				mb.color([Color(0.85, 0.25, 0.3), Color(0.95, 0.8, 0.25), Color(0.9, 0.9, 0.95)][k % 3])
				mb.box(tip + Vector3.UP * 0.02, Vector3(0.06, 0.04, 0.06), Basis(Vector3.UP, a))
				mb.color(Color(0.95, 0.75, 0.2))
				mb.box(tip + Vector3.UP * 0.045, Vector3(0.022, 0.015, 0.022))
			obj._shape(Vector3(0, 0.2, 0), Vector3(0.28, 0.4, 0.28))
		"deco_plant":
			mb.color(Color(0.55, 0.3, 0.2))
			mb.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.16, 0.0), Vector2(0.22, 0.34), Vector2(0.24, 0.36), Vector2(0.0, 0.36)]), 10)
			mb.color(Color(0.3, 0.2, 0.12))
			mb.lathe(PackedVector2Array([Vector2(0.0, 0.32), Vector2(0.21, 0.32), Vector2(0.0, 0.34)]), 10)
			for k in 9:
				var a := TAU * k / 9.0 + k * 0.3
				var out := 0.35 + (k % 3) * 0.08
				var leaf := PackedVector3Array([Vector3(0, 0.34, 0), Vector3(cos(a) * out * 0.4, 0.75 + (k % 2) * 0.15, sin(a) * out * 0.4),
					Vector3(cos(a) * out, 0.62 + (k % 3) * 0.1, sin(a) * out)])
				mb.color(Color(0.22, 0.45, 0.2).lightened(0.05 * (k % 3)))
				mb.tube(leaf, 0.03 - (k % 2) * 0.008, 4)
			obj._shape(Vector3(0, 0.25, 0), Vector3(0.45, 0.5, 0.45))
		"deco_barrel":
			mb.color(WOOD)
			mb.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.26, 0.0), Vector2(0.31, 0.2), Vector2(0.33, 0.45), Vector2(0.31, 0.7),
				Vector2(0.26, 0.9), Vector2(0.0, 0.9)]), 12)
			mb.color(ItemModels.IRON)
			for y in [0.1, 0.32, 0.58, 0.8]:
				var r := 0.27 + 0.06 * sin(y / 0.9 * PI)
				mb.torus(r + 0.012, 0.015, 14, 4, Basis.IDENTITY, Vector3(0, y, 0))
			mb.color(WOOD_DARK)
			mb.lathe(PackedVector2Array([Vector2(0.0, 0.9), Vector2(0.25, 0.9), Vector2(0.0, 0.905)]), 12)
			obj._shape(Vector3(0, 0.45, 0), Vector3(0.64, 0.9, 0.64))
		"deco_crates":
			for c in [[Vector3(-0.3, 0.25, 0), 0.5, 0.0], [Vector3(0.28, 0.22, 0.05), 0.44, 0.3], [Vector3(-0.15, 0.73, 0.02), 0.46, -0.2]]:
				_crate(mb, c[0], c[1], c[2])
			obj._shape(Vector3(0, 0.25, 0), Vector3(1.1, 0.5, 0.55))
			obj._shape(Vector3(-0.15, 0.73, 0.02), Vector3(0.46, 0.46, 0.46))
		"deco_painting":
			mb.color(Color(0.55, 0.38, 0.15))
			mb.box(Vector3(0, 0, 0.02), Vector3(0.9, 0.7, 0.04)) # moldura
			mb.color(Color(0.6, 0.48, 0.2))
			mb.box(Vector3(0, 0, 0.042), Vector3(0.78, 0.58, 0.004))
			# Paisagem simples: céu, montanha, campo e sol.
			mb.color(Color(0.45, 0.6, 0.78))
			mb.box(Vector3(0, 0.08, 0.046), Vector3(0.74, 0.38, 0.004))
			mb.color(Color(0.4, 0.42, 0.48))
			mb.tri(Vector3(-0.37, -0.05, 0.05), Vector3(-0.05, 0.2, 0.05), Vector3(0.25, -0.05, 0.05))
			mb.color(Color(0.36, 0.52, 0.25))
			mb.box(Vector3(0, -0.17, 0.047), Vector3(0.74, 0.18, 0.004))
			mb.color(Color(0.95, 0.85, 0.4))
			mb.box(Vector3(0.24, 0.17, 0.05), Vector3(0.08, 0.08, 0.004))
			obj._shape(Vector3(0, 0, 0.03), Vector3(0.9, 0.7, 0.06))
		"deco_shelf":
			mb.color(WOOD)
			mb.box(Vector3(0, 0, 0.13), Vector3(1.0, 0.04, 0.26))
			mb.color(WOOD_DARK)
			for x in [-0.4, 0.4]:
				mb.box(Vector3(x, -0.1, 0.1), Vector3(0.04, 0.2, 0.04))
				mb.box(Vector3(x, -0.18, 0.02), Vector3(0.04, 0.04, 0.04))
			for k in 4:
				mb.color([Color(0.5, 0.15, 0.12), Color(0.15, 0.3, 0.45), Color(0.25, 0.4, 0.2), Color(0.55, 0.45, 0.2)][k])
				mb.box(Vector3(-0.38 + k * 0.05, 0.13, 0.12), Vector3(0.045, 0.22 - (k % 2) * 0.03, 0.17)) # livros
			for k in 3:
				mb.color(Color(0.6, 0.72, 0.7))
				mb.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.12), Vector2(0.03, 0.14), Vector2(0.032, 0.16), Vector2(0.0, 0.16)]), 8, Basis.IDENTITY, Vector3(0.05 + k * 0.13, 0.02, 0.13))
				mb.color([Color(0.7, 0.4, 0.15), Color(0.5, 0.2, 0.25), Color(0.8, 0.75, 0.5)][k])
				mb.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.044, 0.0), Vector2(0.044, 0.08), Vector2(0.0, 0.08)]), 8, Basis.IDENTITY, Vector3(0.05 + k * 0.13, 0.025, 0.13))
			obj._shape(Vector3(0, 0.05, 0.13), Vector3(1.0, 0.3, 0.26))
		"deco_clock":
			mb.color(WOOD_DARK)
			mb.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.22, 0.0), Vector2(0.24, 0.02), Vector2(0.24, 0.05), Vector2(0.2, 0.06), Vector2(0.0, 0.06)]), 16, Basis(Vector3.RIGHT, PI / 2))
			mb.color(Color(0.92, 0.88, 0.76))
			mb.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.19, 0.0), Vector2(0.0, 0.002)]), 16, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.062))
			mb.color(Color(0.15, 0.12, 0.1))
			for k in 12:
				var a := TAU * k / 12.0
				var len := 0.035 if k % 3 == 0 else 0.018
				mb.box(Vector3(sin(a) * 0.165, cos(a) * 0.165, 0.066), Vector3(0.008, len, 0.003), Basis(Vector3.BACK, -a))
			mb.color(ItemModels.BRASS)
			mb.box(Vector3(0, 0, 0.074), Vector3(0.02, 0.02, 0.006))
			for hand in [["Hour", 0.1, 0.014], ["Minute", 0.15, 0.009]]:
				var h := MeshBuilder.new()
				h.color(Color(0.1, 0.08, 0.06))
				h.box(Vector3(0, hand[1] * 0.5 - 0.01, 0), Vector3(hand[2], hand[1], 0.004))
				var node := MeshInstance3D.new()
				node.name = hand[0]
				node.mesh = h.finish(PlacedObject._mat(), false)
				node.position = Vector3(0, 0, 0.07 if hand[0] == "Hour" else 0.072)
				obj.add_child(node)
			obj._shape(Vector3(0, 0, 0.03), Vector3(0.48, 0.48, 0.06))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	obj.add_child(mesh)
	refresh(obj)


## Relógio: ponteiros na hora do jogo.
static func refresh(obj: PlacedObject) -> void:
	if obj.kind != "deco_clock" or DayNight.i == null:
		return
	var hour: float = DayNight.i.hour
	var hand_h := obj.get_node_or_null("Hour") as Node3D
	var hand_m := obj.get_node_or_null("Minute") as Node3D
	if hand_h:
		hand_h.rotation.z = -fmod(hour, 12.0) / 12.0 * TAU
	if hand_m:
		hand_m.rotation.z = -fmod(hour, 1.0) * TAU


static func _leg(mb: MeshBuilder, at: Vector3, height: float, r := 0.03) -> void:
	mb.color(WOOD_DARK)
	mb.lathe(PackedVector2Array([Vector2(r * 0.8, 0.0), Vector2(r, 0.03), Vector2(r * 0.7, height * 0.3), Vector2(r * 1.2, height * 0.5),
		Vector2(r * 0.75, height * 0.75), Vector2(r, height)]), 8, Basis.IDENTITY, at)


static func _crate(mb: MeshBuilder, at: Vector3, size: float, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	mb.color(WOOD.lightened(0.05))
	mb.box(at, Vector3.ONE * size * 0.96, basis)
	mb.color(WOOD_DARK)
	var h := size * 0.5
	for edge in [Vector3(-h, 0, h), Vector3(h, 0, h), Vector3(-h, 0, -h), Vector3(h, 0, -h)]:
		mb.box(at + basis * edge, Vector3(0.05, size, 0.05), basis)
	for y in [-h, h]:
		mb.box(at + basis * Vector3(0, y, h), Vector3(size, 0.05, 0.03), basis)
		mb.box(at + basis * Vector3(0, y, -h), Vector3(size, 0.05, 0.03), basis)
	mb.box(at + basis * Vector3(0, 0, h + 0.005), Vector3(size * 1.3, 0.05, 0.02), basis * Basis(Vector3.BACK, 0.78)) # diagonal
