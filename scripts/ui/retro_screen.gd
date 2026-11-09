extends CanvasLayer
## Tela "retrô" (cena retro_screen.tscn): o 3D é renderizado na resolução original
## do jogo (540 linhas, ampliado em blocos nítidos pelo retro_screen.gdshader) e
## os menus/HUD ficam por cima na resolução da janela (camadas 2+), com o estilo de
## baixa resolução vindo da fonte sem suavização. A janela pode ter qualquer tamanho.

const LINES := 540.0 ## altura da imagem 3D

@onready var _effect: ColorRect = $Effect


func _ready() -> void:
	layer = 1 # logo acima do 3D, abaixo do HUD (2) e dos menus
	get_viewport().size_changed.connect(_resize)
	_resize()


func _resize() -> void:
	var viewport := get_viewport()
	var pixels := Vector2(get_window().size)
	var scale := clampf(LINES / maxf(pixels.y, 1.0), 0.1, 1.0)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = scale
	(_effect.material as ShaderMaterial).set_shader_parameter("pixel_grid", (pixels * scale).round())
