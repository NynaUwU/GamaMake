class_name Furniture
extends StaticBody3D
## Móvel dentro das casas com interior (mesa, cadeira, cama, armário, estante,
## fogão a lenha). Qualquer golpe (arma, ferramenta ou soco) desmonta: ao zerar a
## "vida" ele quebra e solta material (tábuas, gravetos, pano, sucata).
## Chave fixa (casa + índice): quebrado fica quebrado para todos e no save.
## Montado dentro da thread das casas: só cria nós aqui; liga no Net no _ready.

const HP := {"mesa": 40.0, "cadeira": 20.0, "cama": 50.0, "armario": 60.0, "estante": 45.0, "fogao": 70.0,
	"sofa": 45.0, "banheira": 70.0, "privada": 40.0, "pia": 35.0, "balcao": 50.0, "comoda": 40.0}
const PORCELAIN := Color(0.86, 0.86, 0.82)
const WOOD := Color(0.45, 0.3, 0.17)
const DARK := Color(0.28, 0.18, 0.1)

var key := ""
var kind := "mesa"
var hp := 40.0
var _done := false
var _material: StandardMaterial3D


func setup(key_: String, kind_: String, material: StandardMaterial3D) -> void:
	key = key_
	kind = kind_
	hp = HP.get(kind, 40.0)
	_material = material
	collision_layer = 1
	collision_mask = 0
	_build()


func _ready() -> void:
	if Net.i.taken.has(key):
		queue_free() # já quebrado neste mundo
		return
	Net.i.looted.connect(_on_looted)


## Golpe de qualquer arma/ferramenta (Player._apply_swing_hit) ou soco.
func tool_hit(_player: Node, _weapon_type: int, damage: float, point: Vector3) -> void:
	if _done:
		return
	hp -= damage
	ImpactFX.burst(get_parent(), point, Vector3.UP, WOOD if kind != "fogao" else Color(0.3, 0.3, 0.3), 8, 2.0, 0.04)
	Sfx.play_at("knock", point, 2.0, 0.8 if kind != "fogao" else 1.3)
	if hp <= 0.0:
		_done = true
		Net.i.loot_request(key, global_transform.translated(Vector3.UP * 0.2), "movel_" + kind)


func _on_looted(k: String) -> void:
	if k != key:
		return
	Sfx.play_at("crunch", global_position + Vector3.UP * 0.5, 4.0, 0.7)
	ImpactFX.burst(get_parent(), global_position + Vector3.UP * 0.5, Vector3.UP, WOOD, 24, 3.0, 0.06)
	queue_free()


func _build() -> void:
	var mb := MeshBuilder.new()
	match kind:
		"mesa":
			mb.color(WOOD)
			mb.box(Vector3(0, 0.76, 0), Vector3(1.3, 0.06, 0.8))
			for x in [-0.58, 0.58]:
				for z in [-0.33, 0.33]:
					mb.box(Vector3(x, 0.37, z), Vector3(0.07, 0.74, 0.07))
			mb.color(Color(0.8, 0.78, 0.7))
			mb.box(Vector3(0.2, 0.81, 0.1), Vector3(0.18, 0.04, 0.18)) # prato
			_shape(Vector3(0, 0.4, 0), Vector3(1.3, 0.8, 0.8))
		"cadeira":
			mb.color(WOOD.darkened(0.1))
			mb.box(Vector3(0, 0.45, 0), Vector3(0.42, 0.05, 0.42))
			for x in [-0.18, 0.18]:
				for z in [-0.18, 0.18]:
					mb.box(Vector3(x, 0.22, z), Vector3(0.05, 0.45, 0.05))
			mb.box(Vector3(0, 0.75, 0.19), Vector3(0.42, 0.5, 0.05))
			_shape(Vector3(0, 0.45, 0), Vector3(0.45, 0.9, 0.45))
		"cama":
			mb.color(DARK)
			mb.box(Vector3(0, 0.22, 0), Vector3(0.95, 0.3, 1.95))
			mb.box(Vector3(0, 0.55, -0.95), Vector3(0.95, 0.7, 0.07)) # cabeceira
			mb.color(Color(0.75, 0.72, 0.62))
			mb.box(Vector3(0, 0.42, 0.05), Vector3(0.88, 0.12, 1.8)) # colchão
			mb.color(Color(0.5, 0.18, 0.15))
			mb.box(Vector3(0, 0.5, 0.35), Vector3(0.9, 0.06, 1.1)) # coberta
			mb.color(Color(0.9, 0.88, 0.82))
			mb.box(Vector3(0, 0.52, -0.7), Vector3(0.6, 0.1, 0.3)) # travesseiro
			_shape(Vector3(0, 0.3, 0), Vector3(0.95, 0.6, 1.95))
		"armario":
			mb.color(DARK)
			mb.box(Vector3(0, 0.95, 0), Vector3(1.0, 1.9, 0.5))
			mb.color(WOOD)
			for x in [-0.24, 0.24]:
				mb.box(Vector3(x, 0.95, 0.26), Vector3(0.46, 1.8, 0.03))
			mb.color(ItemModels.BRASS)
			for x in [-0.04, 0.04]:
				mb.box(Vector3(x, 1.0, 0.29), Vector3(0.025, 0.1, 0.025))
			_shape(Vector3(0, 0.95, 0), Vector3(1.0, 1.9, 0.5))
		"estante":
			mb.color(WOOD)
			for side in [-0.48, 0.48]:
				mb.box(Vector3(side, 0.9, 0), Vector3(0.05, 1.8, 0.35))
			for k in 4:
				mb.box(Vector3(0, 0.1 + k * 0.55, 0), Vector3(1.0, 0.04, 0.35))
			for k in 9: # livros e potes
				mb.color([Color(0.55, 0.15, 0.12), Color(0.2, 0.35, 0.5), Color(0.3, 0.45, 0.25), Color(0.6, 0.5, 0.25)][k % 4])
				mb.box(Vector3(-0.38 + (k % 3) * 0.32, 0.27 + (k / 3) * 0.55, 0), Vector3(0.22, 0.28, 0.24))
			_shape(Vector3(0, 0.9, 0), Vector3(1.0, 1.8, 0.35))
		"fogao":
			mb.color(Color(0.18, 0.17, 0.16))
			mb.box(Vector3(0, 0.42, 0), Vector3(0.8, 0.84, 0.6))
			mb.color(Color(0.25, 0.24, 0.23))
			mb.box(Vector3(0, 0.86, 0), Vector3(0.84, 0.04, 0.64))
			mb.tube(PackedVector3Array([Vector3(0.25, 0.88, -0.2), Vector3(0.25, 2.6, -0.2)]), 0.07, 6) # chaminé
			mb.color(ItemModels.BRASS)
			mb.box(Vector3(0, 0.45, 0.31), Vector3(0.36, 0.26, 0.02))
			_shape(Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.6))
		"sofa":
			var cloth := Color(0.42, 0.24, 0.2)
			mb.color(cloth)
			mb.box(Vector3(0, 0.25, 0), Vector3(1.6, 0.3, 0.75))
			mb.box(Vector3(0, 0.6, -0.3), Vector3(1.6, 0.5, 0.18)) # encosto
			for x in [-0.72, 0.72]:
				mb.box(Vector3(x, 0.45, 0), Vector3(0.16, 0.3, 0.75)) # braços
			mb.color(cloth.lightened(0.1))
			for x in [-0.36, 0.36]:
				mb.box(Vector3(x, 0.43, 0.04), Vector3(0.66, 0.08, 0.6)) # almofadas
			_shape(Vector3(0, 0.42, 0), Vector3(1.6, 0.85, 0.75))
		"banheira":
			mb.color(PORCELAIN)
			mb.box(Vector3(0, 0.3, 0), Vector3(1.6, 0.12, 0.75))
			for side in [-1.0, 1.0]:
				mb.box(Vector3(0, 0.5, side * 0.33), Vector3(1.6, 0.4, 0.08))
				mb.box(Vector3(side * 0.76, 0.5, 0), Vector3(0.08, 0.4, 0.75))
			mb.color(ItemModels.BRASS)
			for x in [-0.6, 0.6]:
				for z in [-0.28, 0.28]:
					mb.box(Vector3(x, 0.12, z), Vector3(0.08, 0.24, 0.08)) # pés de garra
			mb.box(Vector3(-0.72, 0.8, 0), Vector3(0.04, 0.2, 0.04)) # torneira
			_shape(Vector3(0, 0.38, 0), Vector3(1.6, 0.76, 0.75))
		"privada":
			mb.color(PORCELAIN)
			mb.box(Vector3(0, 0.2, 0.05), Vector3(0.36, 0.4, 0.45))
			mb.box(Vector3(0, 0.42, 0.05), Vector3(0.42, 0.05, 0.5)) # assento
			mb.box(Vector3(0, 0.62, -0.22), Vector3(0.44, 0.4, 0.16)) # caixa
			mb.color(ItemModels.BRASS)
			mb.box(Vector3(0.15, 0.8, -0.2), Vector3(0.06, 0.03, 0.03))
			_shape(Vector3(0, 0.4, 0), Vector3(0.45, 0.8, 0.6))
		"pia":
			mb.color(PORCELAIN)
			mb.box(Vector3(0, 0.82, 0), Vector3(0.55, 0.14, 0.42))
			mb.box(Vector3(0, 0.4, -0.05), Vector3(0.12, 0.72, 0.12)) # coluna
			mb.color(Color(0.55, 0.6, 0.62))
			mb.box(Vector3(0, 1.3, -0.19), Vector3(0.4, 0.5, 0.03)) # espelho
			mb.color(ItemModels.BRASS)
			mb.box(Vector3(0, 0.95, -0.14), Vector3(0.04, 0.1, 0.04))
			_shape(Vector3(0, 0.5, 0), Vector3(0.55, 1.0, 0.42))
		"balcao":
			mb.color(WOOD)
			mb.box(Vector3(0, 0.43, 0), Vector3(1.6, 0.86, 0.6))
			mb.color(Color(0.5, 0.48, 0.45))
			mb.box(Vector3(0, 0.88, 0), Vector3(1.64, 0.05, 0.64)) # tampo de pedra
			mb.color(DARK)
			for x in [-0.5, 0.0, 0.5]:
				mb.box(Vector3(x, 0.45, 0.305), Vector3(0.44, 0.7, 0.02)) # portinhas
			mb.color(Color(0.7, 0.68, 0.62))
			mb.box(Vector3(0.45, 0.95, 0.0), Vector3(0.2, 0.12, 0.2)) # panela
			_shape(Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.6))
		"comoda":
			mb.color(DARK)
			mb.box(Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.45))
			mb.color(WOOD)
			for y in [0.2, 0.47, 0.74]:
				mb.box(Vector3(0, y, 0.23), Vector3(0.84, 0.22, 0.02)) # gavetas
			mb.color(ItemModels.BRASS)
			for y in [0.2, 0.47, 0.74]:
				mb.box(Vector3(0, y, 0.25), Vector3(0.1, 0.03, 0.02))
			_shape(Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.45))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(_material, false)
	add_child(mesh)


func _shape(center: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	add_child(shape)
