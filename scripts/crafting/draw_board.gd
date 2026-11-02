class_name DrawBoard
extends Node3D
## Lousa de desenho num cavalete (PlacedObject "drawboard"). A tela é uma
## imagem de W x H pixels mostrada no quadro; [E] abre a DrawUI para desenhar.
## Cada traço vira um pedido "draw" ao host (PlacedManager), que pinta e
## repassa a todos: todo mundo desenha junto na mesma lousa e vê ao vivo.
## O desenho vai no save (comprimido).

const W := 128
const H := 96
const PAPER := Color(0.93, 0.9, 0.82)
const PALETTE := [Color(0.08, 0.08, 0.09), Color(0.93, 0.9, 0.82), Color(0.75, 0.15, 0.12), Color(0.95, 0.55, 0.15),
	Color(0.95, 0.85, 0.25), Color(0.3, 0.6, 0.25), Color(0.2, 0.45, 0.8), Color(0.5, 0.3, 0.65),
	Color(0.45, 0.3, 0.18), Color(0.55, 0.55, 0.57), Color(0.95, 0.65, 0.7), Color(0.4, 0.75, 0.8)]

var obj: PlacedObject
var image: Image
var texture: ImageTexture


func setup(obj_: PlacedObject) -> void:
	obj = obj_
	image = Image.create(W, H, false, Image.FORMAT_RGB8)
	image.fill(PAPER)
	texture = ImageTexture.create_from_image(image)
	_build()


## Traço: pontos em pixels da lousa, cor e espessura (pincel quadrado, estilo pixel).
func stroke(points: PackedVector2Array, color: Color, size: int) -> void:
	if points.is_empty():
		return
	size = clampi(size, 1, 12)
	var prev := points[0]
	_dab(prev, color, size)
	for i in range(1, points.size()):
		var p := points[i]
		var steps := maxi(1, int(prev.distance_to(p) / maxf(size * 0.5, 0.5)))
		for k in steps:
			_dab(prev.lerp(p, float(k + 1) / steps), color, size)
		prev = p
	texture.update(image)


func _dab(p: Vector2, color: Color, size: int) -> void:
	var half := size / 2
	image.fill_rect(Rect2i(int(p.x) - half, int(p.y) - half, size, size).intersection(Rect2i(0, 0, W, H)), color)


func clear() -> void:
	image.fill(PAPER)
	texture.update(image)


func packed() -> PackedByteArray:
	return image.get_data().compress(FileAccess.COMPRESSION_ZSTD)


func unpack(data: PackedByteArray) -> void:
	var raw := data.decompress(W * H * 3, FileAccess.COMPRESSION_ZSTD)
	if raw.size() == W * H * 3:
		image.set_data(W, H, false, Image.FORMAT_RGB8, raw)
		texture.update(image)


func _build() -> void:
	var mb := MeshBuilder.new()
	var wood := Color(0.42, 0.28, 0.16)
	# Cavalete: duas pernas da frente abertas com travessa, perna de trás com
	# dobradiça e corrente, bandeja com potes de tinta e pincéis, moldura com
	# cantoneiras, presilha de latão e a paleta pendurada.
	for side in [-1.0, 1.0]:
		mb.color(wood)
		mb.tube(PackedVector3Array([Vector3(side * 0.45, 0.0, 0.15), Vector3(side * 0.38, 0.9, 0.05), Vector3(side * 0.3, 1.78, -0.05)]), 0.03, 6)
		mb.color(wood.darkened(0.25))
		mb.box(Vector3(side * 0.45, 0.02, 0.15), Vector3(0.07, 0.04, 0.07)) # pezinho
	mb.color(wood.darkened(0.1))
	mb.box(Vector3(0, 0.35, 0.12), Vector3(0.86, 0.04, 0.04)) # travessa de baixo
	mb.tube(PackedVector3Array([Vector3(0, 0.0, -0.5), Vector3(0, 0.8, -0.3), Vector3(0, 1.66, -0.09)]), 0.028, 6)
	mb.color(ItemModels.IRON)
	mb.box(Vector3(0, 1.66, -0.07), Vector3(0.08, 0.06, 0.05)) # dobradiça
	mb.tube(PackedVector3Array([Vector3(0, 0.6, -0.36), Vector3(0, 0.58, -0.1), Vector3(0, 0.6, 0.1)]), 0.005, 3) # corrente
	mb.color(wood)
	mb.box(Vector3(0, 0.74, 0.08), Vector3(1.12, 0.04, 0.16)) # bandeja
	mb.box(Vector3(0, 0.77, 0.155), Vector3(1.12, 0.04, 0.02)) # borda
	var paints := [Color(0.8, 0.15, 0.1), Color(0.15, 0.35, 0.75), Color(0.9, 0.75, 0.15), Color(0.2, 0.55, 0.25)]
	for k in 4:
		mb.color(Color(0.55, 0.55, 0.52))
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.76), Vector2(0.035, 0.76), Vector2(0.035, 0.82), Vector2(0.002, 0.82)]), 8, Basis.IDENTITY, Vector3(-0.42 + k * 0.1, 0, 0.08))
		mb.color(paints[k])
		mb.lathe(PackedVector2Array([Vector2(0.002, 0.821), Vector2(0.032, 0.821)]), 8, Basis.IDENTITY, Vector3(-0.42 + k * 0.1, 0, 0.08))
	for k in 3:
		mb.color(wood.lightened(0.2))
		mb.box(Vector3(0.15 + k * 0.08, 0.77, 0.07), Vector3(0.012, 0.012, 0.2), Basis(Vector3.UP, 0.2 * k)) # pincéis
		mb.color(paints[k])
		mb.box(Vector3(0.15 + k * 0.08 + 0.02 * k, 0.77, -0.04), Vector3(0.018, 0.018, 0.03), Basis(Vector3.UP, 0.2 * k))
	mb.color(wood.darkened(0.2))
	mb.box(Vector3(0, 1.23, -0.025), Vector3(1.04, 0.8, 0.03)) # fundo da moldura
	for side in [-1.0, 1.0]:
		mb.box(Vector3(side * 0.505, 1.23, 0.0), Vector3(0.04, 0.82, 0.05))
		mb.box(Vector3(0, 1.23 + side * 0.39, 0.0), Vector3(1.05, 0.04, 0.05))
	mb.color(ItemModels.IRON)
	for x in [-0.5, 0.5]:
		for y in [0.84, 1.62]:
			mb.box(Vector3(x, y, 0.02), Vector3(0.06, 0.06, 0.02)) # cantoneiras
	mb.color(ItemModels.BRASS)
	mb.box(Vector3(0, 1.68, 0.0), Vector3(0.14, 0.06, 0.07)) # presilha
	mb.box(Vector3(0, 1.72, -0.02), Vector3(0.03, 0.1, 0.03))
	# Paleta de madeira pendurada num prego, com manchas de tinta.
	mb.color(wood.lightened(0.15))
	mb.lathe(PackedVector2Array([Vector2(0.002, 0.0), Vector2(0.11, 0.0), Vector2(0.11, 0.01), Vector2(0.002, 0.01)]), 10, Basis(Vector3.RIGHT, PI / 2) * Basis.IDENTITY, Vector3(0.62, 1.0, 0.03))
	for k in 4:
		mb.color(paints[k])
		mb.box(Vector3(0.62 + cos(k * 1.4) * 0.06, 1.0 + sin(k * 1.4) * 0.06, 0.045), Vector3(0.03, 0.03, 0.006))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(PlacedObject._mat(), false)
	add_child(mesh)
	# A tela (com a imagem desenhada), um pouco à frente da moldura.
	var canvas := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.96, 0.72)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	quad.material = material
	canvas.mesh = quad
	# Entre o fundo (frente em z=-0,01) e as ripas da moldura (frente em z=0,025),
	# reta como a moldura: antes vinha inclinada e metade entrava nas tábuas do fundo.
	canvas.position = Vector3(0, 1.23, 0.002)
	add_child(canvas)
	obj._shape(Vector3(0, 0.9, -0.1), Vector3(1.1, 1.8, 0.5))
