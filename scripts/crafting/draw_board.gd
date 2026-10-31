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
	mb.color(wood)
	# Cavalete: duas pernas da frente abertas, uma atrás, e a travessa da tela.
	for side in [-1.0, 1.0]:
		mb.tube(PackedVector3Array([Vector3(side * 0.45, 0.0, 0.15), Vector3(side * 0.3, 1.75, -0.05)]), 0.03, 5)
	mb.tube(PackedVector3Array([Vector3(0, 0.0, -0.5), Vector3(0, 1.65, -0.08)]), 0.03, 5)
	mb.box(Vector3(0, 0.72, 0.06), Vector3(1.1, 0.05, 0.12)) # apoio da tela
	mb.color(wood.darkened(0.2))
	mb.box(Vector3(0, 1.23, -0.02), Vector3(1.04, 0.8, 0.04)) # moldura
	mb.color(ItemModels.BRASS)
	mb.box(Vector3(0, 1.66, 0.0), Vector3(0.12, 0.05, 0.06)) # presilha
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
	canvas.position = Vector3(0, 1.23, 0.005)
	canvas.rotation.x = -0.06
	add_child(canvas)
	obj._shape(Vector3(0, 0.9, -0.1), Vector3(1.1, 1.8, 0.5))
