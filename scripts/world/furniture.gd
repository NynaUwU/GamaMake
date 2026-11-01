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
	var cloth := Color(0.42, 0.24, 0.2)
	match kind:
		"mesa":
			# Tampo de tábuas com borda, pernas torneadas, travessas, toalha e louça.
			for k in 4:
				mb.color(WOOD.darkened(0.04 * (k % 2)))
				mb.box(Vector3(0, 0.76, -0.3 + k * 0.2), Vector3(1.3, 0.06, 0.19))
			mb.color(DARK)
			mb.box(Vector3(0, 0.71, 0), Vector3(1.2, 0.06, 0.7)) # saia
			for x in [-0.58, 0.58]:
				for z in [-0.33, 0.33]:
					mb.lathe(PackedVector2Array([Vector2(0.04, 0.0), Vector2(0.03, 0.15), Vector2(0.045, 0.35), Vector2(0.03, 0.6), Vector2(0.04, 0.72)]), 8, Basis.IDENTITY, Vector3(x, 0, z))
			mb.box(Vector3(0, 0.15, 0), Vector3(1.1, 0.04, 0.04))
			mb.color(Color(0.8, 0.78, 0.7))
			mb.box(Vector3(0, 0.795, 0), Vector3(0.5, 0.005, 0.85)) # trilho de toalha
			mb.color(Color(0.85, 0.83, 0.78))
			for x in [-0.35, 0.3]:
				mb.lathe(PackedVector2Array([Vector2(0.002, 0.8), Vector2(0.09, 0.8), Vector2(0.1, 0.815)]), 10, Basis.IDENTITY, Vector3(x, 0, 0.12)) # pratos
			mb.color(ItemModels.STEEL)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.8), Vector2(0.03, 0.8), Vector2(0.035, 0.9), Vector2(0.03, 0.91)]), 8, Basis.IDENTITY, Vector3(0.0, 0, -0.15)) # caneca
			mb.color(Color(0.95, 0.9, 0.7))
			mb.lathe(PackedVector2Array([Vector2(0.025, 0.8), Vector2(0.02, 0.92), Vector2(0.002, 0.93)]), 6, Basis.IDENTITY, Vector3(-0.1, 0, -0.25)) # vela
			_shape(Vector3(0, 0.4, 0), Vector3(1.3, 0.8, 0.8))
		"cadeira":
			mb.color(WOOD.darkened(0.1))
			mb.box(Vector3(0, 0.45, 0), Vector3(0.42, 0.05, 0.42))
			for x in [-0.18, 0.18]:
				for z in [-0.18, 0.18]:
					mb.lathe(PackedVector2Array([Vector2(0.025, 0.0), Vector2(0.02, 0.2), Vector2(0.025, 0.44)]), 6, Basis.IDENTITY, Vector3(x, 0, z))
			mb.box(Vector3(0, 0.15, 0.18), Vector3(0.36, 0.03, 0.03))
			mb.box(Vector3(0, 0.15, -0.18), Vector3(0.36, 0.03, 0.03))
			for x in [-0.18, 0.18]:
				mb.box(Vector3(x, 0.72, 0.19), Vector3(0.04, 0.55, 0.04)) # montantes do encosto
			for y in [0.62, 0.78, 0.95]:
				mb.box(Vector3(0, y, 0.19), Vector3(0.36, 0.05, 0.025)) # travessas do encosto
			mb.color(cloth)
			mb.box(Vector3(0, 0.485, 0), Vector3(0.36, 0.03, 0.36)) # almofada
			_shape(Vector3(0, 0.45, 0), Vector3(0.45, 0.9, 0.45))
		"cama":
			mb.color(DARK)
			mb.box(Vector3(0, 0.22, 0), Vector3(0.95, 0.12, 1.95))
			for x in [-0.44, 0.44]:
				for z in [-0.95, 0.95]:
					mb.lathe(PackedVector2Array([Vector2(0.04, 0.0), Vector2(0.035, 0.6 if z < 0 else 0.4), Vector2(0.05, 0.64 if z < 0 else 0.44), Vector2(0.002, 0.68 if z < 0 else 0.48)]), 8, Basis.IDENTITY, Vector3(x, 0, z))
			mb.box(Vector3(0, 0.55, -0.95), Vector3(0.88, 0.5, 0.05)) # cabeceira
			mb.color(WOOD)
			for k in 4:
				mb.box(Vector3(-0.3 + k * 0.2, 0.55, -0.93), Vector3(0.06, 0.4, 0.02)) # ripas
			mb.box(Vector3(0, 0.35, 0.95), Vector3(0.88, 0.2, 0.05)) # peseira
			mb.color(Color(0.75, 0.72, 0.62))
			mb.box(Vector3(0, 0.36, 0.05), Vector3(0.86, 0.12, 1.78)) # colchão
			mb.color(Color(0.5, 0.18, 0.15))
			var quilt := []
			for r in 4:
				var row := PackedVector3Array()
				for c in 6:
					var x := lerpf(-0.48, 0.48, c / 5.0)
					var edge := absf(x) > 0.42
					row.append(Vector3(x, (0.3 if edge else 0.44) + sin(c * 1.7 + r) * 0.01, lerpf(-0.2, 0.92, r / 3.0)))
				quilt.append(row)
			mb.sheet(quilt) # coberta caindo dos lados
			mb.color(Color(0.9, 0.88, 0.82))
			mb.lathe(PackedVector2Array([Vector2(0.002, -0.28), Vector2(0.08, -0.25), Vector2(0.1, 0.0), Vector2(0.08, 0.25), Vector2(0.002, 0.28)]), 8, Basis(Vector3.BACK, PI / 2), Vector3(0, 0.47, -0.7)) # travesseiro
			_shape(Vector3(0, 0.3, 0), Vector3(0.95, 0.6, 1.95))
		"armario":
			mb.color(DARK)
			mb.box(Vector3(0, 0.95, 0), Vector3(1.0, 1.9, 0.5))
			mb.box(Vector3(0, 1.93, 0.02), Vector3(1.08, 0.06, 0.56)) # cornija
			mb.box(Vector3(0, 0.05, 0.02), Vector3(1.04, 0.1, 0.54)) # rodapé
			mb.color(WOOD)
			for x in [-0.24, 0.24]:
				mb.box(Vector3(x, 1.05, 0.26), Vector3(0.46, 1.5, 0.03))
				for y in [0.65, 1.4]:
					mb.color(WOOD.darkened(0.15))
					mb.box(Vector3(x, y, 0.28), Vector3(0.34, 0.6, 0.01)) # almofadas
					mb.color(WOOD)
			mb.box(Vector3(0, 0.2, 0.26), Vector3(0.94, 0.2, 0.03)) # gaveta
			mb.color(ItemModels.BRASS)
			for x in [-0.04, 0.04]:
				mb.box(Vector3(x, 1.0, 0.29), Vector3(0.025, 0.12, 0.025))
			mb.box(Vector3(0, 0.2, 0.29), Vector3(0.1, 0.025, 0.025))
			for x in [-0.46, 0.46]:
				for y in [0.5, 1.6]:
					mb.box(Vector3(x, y, 0.27), Vector3(0.02, 0.08, 0.02)) # dobradiças
			_shape(Vector3(0, 0.95, 0), Vector3(1.0, 1.9, 0.5))
		"estante":
			mb.color(WOOD)
			for side in [-0.48, 0.48]:
				mb.box(Vector3(side, 0.9, 0), Vector3(0.05, 1.8, 0.35))
			mb.box(Vector3(0, 0.9, -0.17), Vector3(1.0, 1.8, 0.02)) # fundo
			for k in 4:
				mb.box(Vector3(0, 0.1 + k * 0.55, 0), Vector3(1.0, 0.04, 0.35))
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for shelf in 3: # livros de alturas e cores variadas, um tombado
				var x := -0.42
				while x < 0.38:
					var w := rng.randf_range(0.04, 0.08)
					var h := rng.randf_range(0.22, 0.36)
					mb.color([Color(0.55, 0.15, 0.12), Color(0.2, 0.35, 0.5), Color(0.3, 0.45, 0.25), Color(0.6, 0.5, 0.25), Color(0.35, 0.25, 0.2)][rng.randi() % 5])
					mb.box(Vector3(x + w * 0.5, 0.12 + shelf * 0.55 + h * 0.5, 0.02), Vector3(w, h, rng.randf_range(0.18, 0.26)))
					x += w + 0.005
					if rng.randf() < 0.12:
						x += 0.1
			mb.color(Color(0.62, 0.5, 0.3)) # pote e vela na prateleira de cima
			mb.lathe(PackedVector2Array([Vector2(0.002, 1.77), Vector2(0.07, 1.77), Vector2(0.08, 1.88), Vector2(0.05, 1.95)]), 8, Basis.IDENTITY, Vector3(-0.25, 0, 0))
			_shape(Vector3(0, 0.9, 0), Vector3(1.0, 1.8, 0.35))
		"fogao":
			mb.color(Color(0.18, 0.17, 0.16))
			mb.box(Vector3(0, 0.42, 0), Vector3(0.8, 0.74, 0.6))
			for x in [-0.36, 0.36]:
				for z in [-0.26, 0.26]:
					mb.lathe(PackedVector2Array([Vector2(0.03, 0.0), Vector2(0.04, 0.03), Vector2(0.025, 0.06)]), 6, Basis.IDENTITY, Vector3(x, 0, z)) # pés
			mb.color(Color(0.25, 0.24, 0.23))
			mb.box(Vector3(0, 0.81, 0), Vector3(0.86, 0.04, 0.66))
			mb.color(Color(0.12, 0.11, 0.1))
			for x in [-0.2, 0.2]:
				mb.torus(0.1, 0.012, 10, 3, Basis.IDENTITY, Vector3(x, 0.835, 0.05)) # bocas
			mb.tube(PackedVector3Array([Vector3(0.25, 0.83, -0.22), Vector3(0.25, 2.0, -0.22), Vector3(0.25, 2.2, -0.35), Vector3(0.25, 2.6, -0.35)]), 0.07, 8) # chaminé com curva
			mb.color(ItemModels.BRASS)
			mb.box(Vector3(0, 0.45, 0.31), Vector3(0.36, 0.26, 0.02))
			mb.box(Vector3(0.16, 0.45, 0.33), Vector3(0.04, 0.02, 0.03)) # puxador
			mb.box(Vector3(0, 0.15, 0.31), Vector3(0.5, 0.08, 0.02)) # cinzeiro
			mb.color(ItemModels.STEEL)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.84), Vector2(0.11, 0.84), Vector2(0.12, 0.98), Vector2(0.125, 0.99)]), 10, Basis.IDENTITY, Vector3(-0.2, 0, 0.05)) # panela
			mb.tube(PackedVector3Array([Vector3(-0.08, 0.95, 0.05), Vector3(0.05, 0.95, 0.05)]), 0.01, 4)
			_shape(Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.6))
		"sofa":
			mb.color(DARK)
			for x in [-0.72, 0.72]:
				for z in [-0.3, 0.3]:
					mb.lathe(PackedVector2Array([Vector2(0.03, 0.0), Vector2(0.02, 0.1)]), 6, Basis.IDENTITY, Vector3(x, 0, z)) # pés
			mb.color(cloth)
			mb.box(Vector3(0, 0.25, 0), Vector3(1.6, 0.28, 0.75))
			var back := []
			for k in 5: # encosto arredondado
				var t := k / 4.0
				back.append(MeshBuilder.ring(Vector3(0, 0.4 + t * 0.4, -0.3 + sin(t * PI) * 0.03), 0.8, 0.09 * (1.0 - t * 0.3) + 0.01, 3.0, 12))
			for k in 5:
				var ring := PackedVector3Array()
				for v in back[k]:
					ring.append(Vector3(v.x, back[k][0].y if false else v.y * 0.0 + 0.4 + k / 4.0 * 0.4, -0.3 + (v.y - (0.4 + k / 4.0 * 0.4)) * 1.0))
				back[k] = ring
			mb.box(Vector3(0, 0.62, -0.3), Vector3(1.6, 0.5, 0.18))
			for x in [-0.72, 0.72]:
				mb.lathe(PackedVector2Array([Vector2(0.002, -0.37), Vector2(0.11, -0.36), Vector2(0.12, 0.0), Vector2(0.11, 0.36), Vector2(0.002, 0.37)]), 8, Basis(Vector3.RIGHT, PI / 2), Vector3(x, 0.45, 0)) # braços rolo
			mb.color(cloth.lightened(0.1))
			for x in [-0.36, 0.36]:
				mb.box(Vector3(x, 0.43, 0.04), Vector3(0.66, 0.1, 0.6)) # almofadas do assento
				mb.box(Vector3(x, 0.66, -0.18), Vector3(0.62, 0.36, 0.1), Basis(Vector3.RIGHT, -0.15)) # almofadas do encosto
			mb.color(Color(0.75, 0.68, 0.45))
			mb.box(Vector3(-0.2, 0.52, 0.0), Vector3(0.28, 0.08, 0.28), Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -0.3)) # almofadinha
			mb.color(Color(0.3, 0.17, 0.14))
			mb.box(Vector3(0.45, 0.48, 0.15), Vector3(0.18, 0.005, 0.12)) # rasgo
			_shape(Vector3(0, 0.42, 0), Vector3(1.6, 0.85, 0.75))
		"banheira":
			var rings := []
			for s_ in [[0.14, 0.7, 0.3], [0.2, 0.78, 0.36], [0.55, 0.8, 0.38], [0.62, 0.83, 0.4]]:
				rings.append(MeshBuilder.ring(Vector3(0, s_[0], 0), s_[1], s_[2], 3.0, 16))
			var bowl := []
			for r in rings:
				var ring := PackedVector3Array()
				for v in r:
					ring.append(Vector3(v.x, r[0].y if false else v.z * 0.0 + v.y if false else 0.0, 0.0))
				bowl.append(ring)
			mb.color(PORCELAIN)
			for k in 4:
				var y: float = [0.14, 0.2, 0.55, 0.62][k]
				var rx: float = [0.7, 0.78, 0.8, 0.83][k]
				var rz: float = [0.3, 0.36, 0.38, 0.4][k]
				if k < 3:
					var y2: float = [0.14, 0.2, 0.55, 0.62][k + 1]
					var rx2: float = [0.7, 0.78, 0.8, 0.83][k + 1]
					var rz2: float = [0.3, 0.36, 0.38, 0.4][k + 1]
					var ra := PackedVector3Array()
					var rb := PackedVector3Array()
					for i in 16:
						var a := TAU * i / 16.0
						ra.append(Vector3(cos(a) * rx, y, sin(a) * rz))
						rb.append(Vector3(cos(a) * rx2, y2, sin(a) * rz2))
					mb.loft([ra, rb], true, false, true)
			mb.color(PORCELAIN.darkened(0.1))
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.25), Vector2(0.7, 0.25)]), 16, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.45)))
			mb.color(Color(0.4, 0.5, 0.45))
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.35), Vector2(0.72, 0.35)]), 16, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.45))) # água parada
			mb.color(ItemModels.BRASS)
			for x in [-0.6, 0.6]:
				for z in [-0.28, 0.28]:
					mb.lathe(PackedVector2Array([Vector2(0.05, 0.0), Vector2(0.03, 0.06), Vector2(0.04, 0.16)]), 6, Basis.IDENTITY, Vector3(x, 0, z)) # pés de garra
			mb.tube(PackedVector3Array([Vector3(-0.78, 0.6, 0), Vector3(-0.78, 0.85, 0), Vector3(-0.65, 0.88, 0)]), 0.02, 6) # torneira
			for z in [-0.08, 0.08]:
				mb.box(Vector3(-0.78, 0.75, z), Vector3(0.05, 0.02, 0.05))
			_shape(Vector3(0, 0.38, 0), Vector3(1.6, 0.76, 0.75))
		"privada":
			mb.color(PORCELAIN)
			mb.lathe(PackedVector2Array([Vector2(0.12, 0.0), Vector2(0.1, 0.15), Vector2(0.16, 0.38), Vector2(0.18, 0.4)]), 12, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 1.25)), Vector3(0, 0, 0.06))
			mb.color(PORCELAIN.darkened(0.08))
			mb.torus(0.17, 0.025, 12, 4, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 1.25)), Vector3(0, 0.42, 0.06)) # assento
			mb.color(Color(0.35, 0.42, 0.38))
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.33), Vector2(0.12, 0.33)]), 10, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 1.25)), Vector3(0, 0, 0.06))
			mb.color(PORCELAIN)
			mb.box(Vector3(0, 0.66, -0.22), Vector3(0.44, 0.4, 0.16)) # caixa
			mb.box(Vector3(0, 0.875, -0.22), Vector3(0.47, 0.03, 0.19)) # tampa
			mb.color(ItemModels.BRASS)
			mb.box(Vector3(0.17, 0.8, -0.13), Vector3(0.07, 0.02, 0.02))
			mb.tube(PackedVector3Array([Vector3(0, 0.48, -0.22), Vector3(0, 0.3, -0.25), Vector3(0, 0.0, -0.25)]), 0.02, 6) # cano
			_shape(Vector3(0, 0.4, 0), Vector3(0.45, 0.8, 0.6))
		"pia":
			mb.color(PORCELAIN)
			mb.lathe(PackedVector2Array([Vector2(0.06, 0.0), Vector2(0.05, 0.3), Vector2(0.07, 0.72)]), 10, Basis.IDENTITY, Vector3(0, 0, -0.05)) # coluna
			mb.lathe(PackedVector2Array([Vector2(0.12, 0.72), Vector2(0.27, 0.8), Vector2(0.29, 0.88), Vector2(0.25, 0.89), Vector2(0.22, 0.82), Vector2(0.002, 0.8)]), 12, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.75)))
			mb.color(Color(0.55, 0.6, 0.62))
			mb.box(Vector3(0, 1.3, -0.19), Vector3(0.4, 0.5, 0.02)) # espelho
			mb.color(WOOD)
			for x in [-0.21, 0.21]:
				mb.box(Vector3(x, 1.3, -0.19), Vector3(0.03, 0.56, 0.03))
			for y in [1.03, 1.57]:
				mb.box(Vector3(0, y, -0.19), Vector3(0.45, 0.03, 0.03))
			mb.color(Color(0.4, 0.42, 0.45))
			mb.box(Vector3(-0.1, 1.4, -0.177), Vector3(0.12, 0.2, 0.002), Basis(Vector3.BACK, 0.5)) # rachadura
			mb.color(ItemModels.BRASS)
			mb.tube(PackedVector3Array([Vector3(0, 0.88, -0.17), Vector3(0, 0.98, -0.17), Vector3(0, 0.98, -0.09)]), 0.015, 6)
			for x in [-0.08, 0.08]:
				mb.box(Vector3(x, 0.92, -0.17), Vector3(0.04, 0.02, 0.04))
			_shape(Vector3(0, 0.5, 0), Vector3(0.55, 1.0, 0.42))
		"balcao":
			mb.color(WOOD)
			mb.box(Vector3(0, 0.45, 0), Vector3(1.6, 0.82, 0.6))
			mb.color(DARK)
			mb.box(Vector3(0, 0.03, 0.02), Vector3(1.6, 0.06, 0.56)) # rodapé recuado
			mb.color(Color(0.5, 0.48, 0.45))
			mb.box(Vector3(0, 0.88, 0), Vector3(1.64, 0.05, 0.64)) # tampo de pedra
			mb.color(Color(0.42, 0.4, 0.38))
			mb.box(Vector3(0.0, 0.906, -0.1), Vector3(0.5, 0.002, 0.02)) # veio da pedra
			mb.color(DARK)
			for x in [-0.53, 0.0, 0.53]:
				mb.box(Vector3(x, 0.32, 0.305), Vector3(0.48, 0.5, 0.02)) # portinhas
				mb.box(Vector3(x, 0.71, 0.305), Vector3(0.48, 0.16, 0.02)) # gavetas
			mb.color(ItemModels.BRASS)
			for x in [-0.53, 0.0, 0.53]:
				mb.box(Vector3(x + 0.18, 0.4, 0.32), Vector3(0.02, 0.08, 0.02))
				mb.box(Vector3(x, 0.71, 0.32), Vector3(0.1, 0.02, 0.02))
			mb.color(ItemModels.STEEL)
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.905), Vector2(0.1, 0.905), Vector2(0.11, 1.02), Vector2(0.115, 1.03)]), 10, Basis.IDENTITY, Vector3(0.45, 0, 0.0)) # panela
			mb.color(Color(0.6, 0.45, 0.25))
			mb.box(Vector3(-0.4, 0.92, 0.1), Vector3(0.35, 0.03, 0.22)) # tábua de cortar
			mb.color(ItemModels.STEEL)
			mb.box(Vector3(-0.4, 0.94, 0.1), Vector3(0.2, 0.005, 0.03), Basis(Vector3.UP, 0.3)) # faca
			_shape(Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.6))
		"comoda":
			mb.color(DARK)
			mb.box(Vector3(0, 0.47, 0), Vector3(0.9, 0.86, 0.45))
			mb.box(Vector3(0, 0.92, 0.01), Vector3(0.96, 0.04, 0.5)) # tampo
			for x in [-0.4, 0.4]:
				for z in [-0.18, 0.18]:
					mb.lathe(PackedVector2Array([Vector2(0.035, 0.0), Vector2(0.025, 0.04), Vector2(0.035, 0.06)]), 6, Basis.IDENTITY, Vector3(x, 0, z))
			mb.color(WOOD)
			for y in [0.24, 0.5, 0.76]:
				mb.box(Vector3(0, y, 0.23), Vector3(0.84, 0.22, 0.02))
				mb.color(WOOD.darkened(0.12))
				mb.box(Vector3(0, y, 0.242), Vector3(0.74, 0.14, 0.005)) # filete
				mb.color(WOOD)
			mb.color(ItemModels.BRASS)
			for y in [0.24, 0.5, 0.76]:
				for x in [-0.25, 0.25]:
					mb.box(Vector3(x, y, 0.25), Vector3(0.08, 0.025, 0.02))
			mb.color(Color(0.6, 0.62, 0.65))
			mb.box(Vector3(0, 1.25, -0.2), Vector3(0.6, 0.6, 0.02)) # espelho
			mb.color(DARK)
			mb.box(Vector3(0, 1.25, -0.21), Vector3(0.66, 0.66, 0.02))
			mb.color(Color(0.85, 0.82, 0.75))
			mb.lathe(PackedVector2Array([Vector2(0.002, 0.94), Vector2(0.05, 0.94), Vector2(0.06, 1.05), Vector2(0.03, 1.12)]), 8, Basis.IDENTITY, Vector3(-0.3, 0, 0.05)) # vaso
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
