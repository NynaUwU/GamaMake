class_name WorldMap
extends Control
## Minimapa (canto de baixo à direita) e mapa do mundo (tecla M).
## A imagem do mapa inteiro é gerada uma vez, em thread, a partir do próprio
## terreno (cor do bioma + sombreado do relevo), com os prédios da cidade por
## cima. Marcadores: player (seta), carro e zumbis próximos (só no minimapa).

const BASE_PIXELS := 384 ## amostras do terreno (cor + relevo): 8 m cada, caro (~0,16 ms por amostra)
const MAP_PIXELS := 1536 ## imagem final (2 m por pixel): base suavizada + ruas, pista e casas nítidas
const MINIMAP_SIZE := 150.0
const MINIMAP_RANGE := 260.0 ## metros mostrados de lado a lado no minimapa
const ROAD_COLORS := {"avenue": Color(0.24, 0.23, 0.22), "street": Color(0.33, 0.31, 0.28),
	"dirt": Color(0.5, 0.4, 0.28), "asphalt": Color(0.17, 0.17, 0.18)}
const COLOR_PLAYER := Color(1.0, 0.95, 0.4)
const COLOR_CAR := Color(1.0, 0.5, 0.15)
const COLOR_ZOMBIE := Color(0.9, 0.15, 0.1)
const COLOR_OTHER := Color(0.3, 0.7, 1.0) ## outros jogadores (online)

var player: Node3D
var terrain: TerrainWorld
var _texture: ImageTexture
var _task := -1
var _image: Image
var _big_open := false
var _minimap: Control
var _big: Control


func setup(p: Node3D, world: TerrainWorld) -> void:
	player = p
	terrain = world
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap = Control.new()
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_minimap.offset_left = -MINIMAP_SIZE - 16
	_minimap.offset_right = -16
	_minimap.offset_top = -MINIMAP_SIZE - 48
	_minimap.offset_bottom = -48
	_minimap.draw.connect(_draw_minimap)
	add_child(_minimap)
	_big = Control.new()
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_big.draw.connect(_draw_world)
	_big.visible = false
	add_child(_big)
	if terrain:
		_task = WorkerThreadPool.add_task(_generate)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		_big_open = not _big_open
		_big.visible = _big_open
		_minimap.visible = not _big_open
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _minimap == null:
		return
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_draw_buildings(_image)
		_image.generate_mipmaps() # mapa grande reduzido sem serrilhar as ruas finas
		_texture = ImageTexture.create_from_image(_image)
		_big.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_minimap.queue_redraw()
	if _big_open:
		_big.queue_redraw()


# --- Imagem do mundo ----------------------------------------------------------

## Roda em thread: cor + altura de cada pixel e sombreado pelo relevo.
func _generate() -> void:
	var n := BASE_PIXELS
	var size := terrain.world_size
	var cell := size / n
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var image := Image.create(n, n, false, Image.FORMAT_RGB8)
	for j in n:
		for i in n:
			var sample := terrain.map_sample(-size * 0.5 + (i + 0.5) * cell, -size * 0.5 + (j + 0.5) * cell)
			heights[j * n + i] = sample[1]
			image.set_pixel(i, j, sample[0])
	# Luz vindo do noroeste: encostas viradas para lá clareiam, as outras escurecem.
	for j in n:
		for i in n:
			var h := heights[j * n + i]
			var hx := heights[j * n + mini(i + 1, n - 1)] - heights[j * n + maxi(i - 1, 0)]
			var hz := heights[mini(j + 1, n - 1) * n + i] - heights[maxi(j - 1, 0) * n + i]
			var shade := clampf(1.0 - (hx + hz) / (cell * 2.0) * 0.9, 0.55, 1.35)
			var color := image.get_pixel(i, j) * shade
			color = color.lerp(Color(1, 1, 1), smoothstep(40.0, 130.0, h) * 0.12) # altitude clareia
			image.set_pixel(i, j, Color(color, 1.0))
	# Amplia 4x suavizando o relevo; o que precisa de contorno é desenhado por cima.
	image.resize(MAP_PIXELS, MAP_PIXELS, Image.INTERPOLATE_BILINEAR)
	for road in terrain.avenues + terrain.race_track:
		_stroke(image, road.a, road.b, road.width, ROAD_COLORS.get(road.kind, ROAD_COLORS.street))
	for city in terrain.cities:
		for street in city.streets:
			_stroke(image, street.a, street.b, street.width, ROAD_COLORS.get(street.kind, ROAD_COLORS.street))
	_image = image


## Faixa de rua de a até b (metros do mundo), com pelo menos 2 px de largura.
func _stroke(image: Image, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var pa := _world_to_pixel(a)
	var pb := _world_to_pixel(b)
	var brush := maxi(2, roundi(width / terrain.world_size * MAP_PIXELS))
	var steps := maxi(1, ceili(pa.distance_to(pb) * 1.5))
	var half := Vector2.ONE * brush * 0.5
	for k in steps + 1:
		var p := pa.lerp(pb, float(k) / steps)
		image.fill_rect(Rect2i(Vector2i(p - half), Vector2i(brush, brush)), color)


## Prédios e muros da cidade (CSG do nó Level) como blocos escuros no mapa.
func _draw_buildings(image: Image) -> void:
	# Casas das cidades geradas.
	# Casas das cidades: retângulo girado com a borda mais escura (dá para contar as casas).
	var scale := MAP_PIXELS / terrain.world_size
	for city in terrain.cities:
		for lot in city.lots:
			var c := _world_to_pixel(lot.pos)
			var half := Vector2(lot.w, lot.d) * 0.5 * scale
			var shade := 0.36 - minf(lot.floors, 12) * 0.015
			var fill := Color(shade * 1.1, shade, shade * 0.9) if not lot.ruin else Color(0.3, 0.24, 0.2)
			var edge := fill.darkened(0.45)
			var axis_x := Vector2(cos(lot.yaw), -sin(lot.yaw))
			var axis_y := Vector2(sin(lot.yaw), cos(lot.yaw))
			var reach := ceili(half.length()) + 1
			for y in range(-reach, reach + 1):
				for x in range(-reach, reach + 1):
					var px := Vector2i(roundi(c.x) + x, roundi(c.y) + y)
					if px.x < 0 or px.y < 0 or px.x >= MAP_PIXELS or px.y >= MAP_PIXELS:
						continue
					var d := Vector2(px) + Vector2(0.5, 0.5) - c
					var u := absf(d.dot(axis_x))
					var v := absf(d.dot(axis_y))
					if u <= half.x and v <= half.y:
						image.set_pixelv(px, edge if u > half.x - 1.0 or v > half.y - 1.0 else fill)
	var level := terrain.get_parent().get_node_or_null("Level")
	if level == null:
		return
	for box in level.find_children("*", "CSGBox3D", true, false):
		if box.name == "Chao" or box.size.y < 0.6:
			continue
		var center: Vector3 = box.global_position
		var half: Vector3 = box.size * 0.5
		var a := _world_to_pixel(Vector2(center.x - half.x, center.z - half.z))
		var b := _world_to_pixel(Vector2(center.x + half.x, center.z + half.z))
		image.fill_rect(Rect2i(Vector2i(a), (Vector2i(b - a)).max(Vector2i.ONE)), Color(0.22, 0.2, 0.19))


func _world_to_pixel(p: Vector2) -> Vector2:
	return (p / terrain.world_size + Vector2(0.5, 0.5)) * MAP_PIXELS


# --- Desenho ------------------------------------------------------------------

func _draw_minimap() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2.ONE * MINIMAP_SIZE)
	_minimap.draw_rect(rect.grow(2), Color(0, 0, 0, 0.8))
	if _texture == null or player == null:
		_minimap.draw_rect(rect, Color(0.1, 0.1, 0.1, 0.8))
		return
	var here := Vector2(player.global_position.x, player.global_position.z)
	var src_size := MINIMAP_RANGE / terrain.world_size * MAP_PIXELS
	var src := Rect2(_world_to_pixel(here) - Vector2.ONE * src_size * 0.5, Vector2.ONE * src_size)
	_minimap.draw_texture_rect_region(_texture, rect, src)
	var to_screen := func(world: Vector2) -> Vector2:
		return rect.size * 0.5 + (world - here) / MINIMAP_RANGE * MINIMAP_SIZE
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.state == Zombie.State.DEAD:
			continue
		var pos: Vector2 = to_screen.call(Vector2(enemy.global_position.x, enemy.global_position.z))
		if rect.has_point(pos):
			_minimap.draw_rect(Rect2(pos - Vector2(2, 2), Vector2(4, 4)), COLOR_ZOMBIE)
	_draw_hordes(_minimap, to_screen, rect, false)
	_draw_pings(_minimap, to_screen, rect)
	_draw_car(_minimap, to_screen, rect)
	_draw_others(_minimap, to_screen, rect)
	_draw_arrow(_minimap, rect.size * 0.5, 7.0)
	_minimap.draw_string(get_theme_default_font(), Vector2(4, 12), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))


func _draw_world() -> void:
	var screen := _big.size
	_big.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.7))
	var side := minf(screen.x, screen.y) - 70.0
	var rect := Rect2((screen - Vector2.ONE * side) * 0.5, Vector2.ONE * side)
	_big.draw_rect(rect.grow(2), Color(0.5, 0.45, 0.35))
	var font := get_theme_default_font()
	if _texture == null:
		_big.draw_string(font, rect.get_center(), "Gerando mapa...", HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		return
	_big.draw_texture_rect(_texture, rect, false)
	var to_screen := func(world: Vector2) -> Vector2:
		return rect.position + (world / terrain.world_size + Vector2(0.5, 0.5)) * side
	_draw_hordes(_big, to_screen, rect, true)
	_draw_pings(_big, to_screen, rect)
	_draw_car(_big, to_screen, rect)
	_draw_others(_big, to_screen, rect, true)
	_draw_arrow(_big, to_screen.call(Vector2(player.global_position.x, player.global_position.z)), 8.0)
	_big.draw_string(font, rect.position + Vector2(0, -8), "Mapa  ·  M fechar  ·  norte para cima", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	_big.draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 80), Vector2(92, 76)), Color(0, 0, 0, 0.6))
	var legend := [["Planície", TerrainWorld.COLOR_GRASS], ["Deserto", TerrainWorld.COLOR_SAND],
		["Neve", TerrainWorld.COLOR_SNOW], ["Montanha", TerrainWorld.COLOR_ROCK]]
	for i in legend.size():
		var at := rect.position + Vector2(8, rect.size.y - 18 - i * 16)
		_big.draw_rect(Rect2(at - Vector2(0, 10), Vector2(10, 10)), legend[i][1])
		_big.draw_string(font, at + Vector2(14, 0), legend[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)


func _draw_car(target: Control, to_screen: Callable, clip: Rect2) -> void:
	for car in get_tree().get_nodes_in_group("vehicle"):
		if car == null or player.get("vehicle") == car or not car.get("discovered"):
			continue
		var pos: Vector2 = to_screen.call(Vector2(car.global_position.x, car.global_position.z))
		if clip.has_point(pos):
			target.draw_rect(Rect2(pos - Vector2(4, 3), Vector2(8, 6)), COLOR_CAR)
			target.draw_rect(Rect2(pos - Vector2(4, 3), Vector2(8, 6)), Color.BLACK, false, 1.0)


## Hordas andando pelo mapa: mancha vermelha (maior = mais zumbis) com a contagem.
func _draw_hordes(target: Control, to_screen: Callable, clip: Rect2, big: bool) -> void:
	if HordeManager.i == null:
		return
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
	for entry in HordeManager.i.map_list:
		var pos: Vector2 = to_screen.call(entry[0])
		if not clip.has_point(pos):
			continue
		var radius := (4.0 + sqrt(float(entry[1])) * (1.6 if big else 1.0)) * pulse
		target.draw_circle(pos, radius, Color(0.75, 0.05, 0.05, 0.55))
		target.draw_arc(pos, radius, 0.0, TAU, 16, Color(0.2, 0, 0, 0.9), 1.0)
		if big:
			target.draw_string(get_theme_default_font(), pos + Vector2(radius + 3, 4), "Horda (%d)" % entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.7, 0.65))


## Pings: losango na cor do marcador (preso na borda do minimapa se estiver fora).
func _draw_pings(target: Control, to_screen: Callable, clip: Rect2) -> void:
	if PingMarkers.i == null:
		return
	for entry in PingMarkers.i.list:
		var pos: Vector2 = to_screen.call(Vector2(entry.pos.x, entry.pos.z))
		pos = pos.clamp(clip.position + Vector2(5, 5), clip.end - Vector2(5, 5))
		var color: Color = PingMarkers.COLORS.get(entry.kind, Color.YELLOW)
		var points := PackedVector2Array([pos + Vector2(0, -6), pos + Vector2(5, 0), pos + Vector2(0, 6), pos + Vector2(-5, 0)])
		target.draw_colored_polygon(points, color)
		target.draw_polyline(points + PackedVector2Array([points[0]]), Color.BLACK, 1.0)


## Outros jogadores (online): bolinha azul (no mapa grande, com o nome).
func _draw_others(target: Control, to_screen: Callable, clip: Rect2, names := false) -> void:
	for other in get_tree().get_nodes_in_group("remote_player"):
		var pos: Vector2 = to_screen.call(Vector2(other.global_position.x, other.global_position.z))
		if not clip.has_point(pos):
			continue
		target.draw_circle(pos, 4.0, COLOR_OTHER)
		target.draw_arc(pos, 4.0, 0.0, TAU, 12, Color.BLACK, 1.0)
		if names:
			target.draw_string(get_theme_default_font(), pos + Vector2(6, 4), other.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)


## Seta apontando para onde a câmera olha (norte = -Z = para cima).
func _draw_arrow(target: Control, at: Vector2, size: float) -> void:
	var cam: Camera3D = player.get("camera")
	var forward := -cam.global_basis.z if cam else -player.global_basis.z
	var dir := Vector2(forward.x, forward.z).normalized()
	if dir.is_zero_approx():
		dir = Vector2.UP
	var side := Vector2(-dir.y, dir.x)
	var points := PackedVector2Array([at + dir * size, at - dir * size * 0.6 + side * size * 0.6,
		at - dir * size * 0.25, at - dir * size * 0.6 - side * size * 0.6])
	target.draw_colored_polygon(points, COLOR_PLAYER)
	target.draw_polyline(points + PackedVector2Array([points[0]]), Color.BLACK, 1.0)
