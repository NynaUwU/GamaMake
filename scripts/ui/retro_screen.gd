extends CanvasLayer
## Tela "retrô" (cena retro_screen.tscn): o 3D é renderizado na resolução original
## do jogo (540 linhas, ampliado em blocos nítidos pelo retro_screen.gdshader) e
## os menus/HUD ficam por cima na resolução da janela (camadas 2+), com o estilo de
## baixa resolução vindo da fonte sem suavização. A janela pode ter qualquer tamanho.

const LINES := 540.0 ## altura padrão da imagem 3D (menu de gráficos: 540/720/1080/da janela)

@onready var _effect: ColorRect = $Effect


func _ready() -> void:
	layer = 1 # logo acima do 3D, abaixo do HUD (2) e dos menus
	add_to_group("look_screen")
	get_viewport().size_changed.connect(_resize)
	apply_look()


## Menu de gráficos mudou: resolução do 3D, filtro retrô (cores de 16 bits + pontilhado) e vinheta.
func apply_look() -> void:
	var m := _effect.material as ShaderMaterial
	var retro: bool = Look.get_setting("retro")
	m.set_shader_parameter("color_levels", 32.0 if retro else 256.0)
	m.set_shader_parameter("dither_strength", 0.7 if retro else 0.0)
	m.set_shader_parameter("vignette", 0.35 if Look.get_setting("vignette") else 0.0)
	_resize()


func _resize() -> void:
	var viewport := get_viewport()
	var pixels := Vector2(get_window().size)
	var lines := float(Look.get_setting("lines"))
	if lines <= 0.0:
		lines = pixels.y # da janela: sem reduzir
	var scale := clampf(lines / maxf(pixels.y, 1.0), 0.1, 1.0)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = scale
	(_effect.material as ShaderMaterial).set_shader_parameter("pixel_grid", (pixels * scale).round())
