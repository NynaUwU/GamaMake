class_name CityGen
## Cidades geradas pela semente do mapa, no tema medieval com toque steampunk,
## em ruínas. Inspiração das casas: "Hello Neighbor" — casas tortas, andares
## empilhados de tamanhos diferentes, puxadinhos, telhados íngremes.
##
## Tamanhos:
##   small  -> vila: poucas casinhas de 1-2 andares, espalhadas, cercas, poço.
##   medium -> cidade: casas de 2-6 andares em anéis em volta de uma praça.
##   large  -> cidade grande: no centro, torres-casa de até ~15 andares (~50 m).
##
## place_cities() só decide ONDE e a PLANTA (lotes); build_house() monta a
## malha e a colisão de um lote (feito aos poucos pelo CityManager).

## block = lado da quadra (inclui a rua); radius = meia largura do "quadrado" da cidade.
const SIZES := {
	"large": {"count": 2, "radius": 150.0, "max_floors": 15, "block": 30.0, "fill": 0.9},
	"medium": {"count": 4, "radius": 95.0, "max_floors": 6, "block": 28.0, "fill": 0.85},
	"small": {"count": 7, "radius": 60.0, "max_floors": 2, "block": 26.0, "fill": 0.8},
}
## Larguras das ruas (m).
const STREET_WIDTH := {"avenue": 10.0, "street": 6.0, "dirt": 5.0}
const FLOOR_HEIGHT := 3.2

const STONE := Color(0.42, 0.4, 0.37)
const WOOD := Color(0.33, 0.23, 0.15)
const DARK_WOOD := Color(0.2, 0.14, 0.09)
const WINDOW := Color(0.06, 0.06, 0.07)
const COPPER := Color(0.48, 0.32, 0.2)
const IRON := Color(0.25, 0.24, 0.24)
const PLASTER := [Color(0.68, 0.62, 0.5), Color(0.46, 0.5, 0.42), Color(0.44, 0.48, 0.53),
	Color(0.6, 0.48, 0.32), Color(0.55, 0.42, 0.4)]
const ROOF := [Color(0.42, 0.2, 0.14), Color(0.27, 0.29, 0.31), Color(0.33, 0.27, 0.2)]

static var _material: StandardMaterial3D


# --- Onde ficam as cidades ----------------------------------------------------

static func place_cities(world: TerrainWorld) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed * 31 + 7
	var cities := []
	var half := world.world_size * 0.5 - 220.0
	for size in ["large", "medium", "small"]:
		var cfg: Dictionary = SIZES[size]
		var placed := 0
		for attempt in 400:
			if placed >= cfg.count:
				break
			var center := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
			var radius: float = cfg.radius
			if center.length() < 420.0 + radius:
				continue # longe da cidade inicial
			var ok := true
			for other in cities:
				if center.distance_to(other.center) < radius + other.radius + 140.0:
					ok = false
					break
			if not ok:
				continue
			var base := _site_height(world, center, radius)
			if is_nan(base):
				continue
			var city := {"center": center, "radius": radius, "size": size, "base": base, "seed": rng.randi(),
				"yaw": rng.randf() * PI * 0.5}
			_layout(city, cfg)
			cities.append(city)
			placed += 1
	return cities


## Cidade -> coordenadas locais da grade (u, v) e de volta.
static func to_local(city: Dictionary, p: Vector2) -> Vector2:
	return (p - city.center).rotated(-city.yaw)


static func to_world(city: Dictionary, local: Vector2) -> Vector2:
	return city.center + local.rotated(city.yaw)


## Avenidas ligando as cidades grandes e médias (árvore geradora mínima).
static func connect_cities(cities: Array) -> Array:
	var nodes := cities.filter(func(c): return c.size != "small")
	var roads := []
	if nodes.size() < 2:
		return roads
	var connected := [nodes[0]]
	var left := nodes.slice(1)
	while not left.is_empty():
		var best := []
		var best_d := INF
		for a in connected:
			for b in left:
				var d: float = a.center.distance_to(b.center)
				if d < best_d:
					best_d = d
					best = [a, b]
		roads.append_array(_wonky_road(best[0].center, best[1].center))
		connected.append(best[1])
		left.erase(best[1])
	return roads


## Avenida torta entre dois pontos: curvas largas (duas ondas) + pequenos
## desvios a cada trecho. As pontas ficam no lugar para encaixar nas cidades.
## Cada trecho guarda a caixa (lo/hi) da área que ele afeta, para o relevo
## pular rápido os trechos longe.
static func _wonky_road(a: Vector2, b: Vector2) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([a.snapped(Vector2.ONE), b.snapped(Vector2.ONE)])
	var length := a.distance_to(b)
	var side := (b - a).normalized().orthogonal()
	var count := maxi(int(length / 35.0), 2)
	var amplitude := minf(length * 0.12, 110.0)
	var waves := [rng.randf_range(0.6, 1.4), rng.randf_range(1.8, 3.2)]
	var phases := [rng.randf() * TAU, rng.randf() * TAU]
	var points: Array[Vector2] = []
	for i in count + 1:
		var t := float(i) / count
		var taper := sin(PI * t) # zero nas pontas
		var bend := sin(t * PI * waves[0] + phases[0]) * 0.65 + sin(t * PI * waves[1] + phases[1]) * 0.35
		var jitter := rng.randf_range(-7.0, 7.0) if i > 0 and i < count else 0.0
		points.append(a.lerp(b, t) + side * (bend * amplitude * taper + jitter))
	var roads := []
	var reach := STREET_WIDTH.avenue * 0.5 + 20.0
	for i in count:
		var p0 := points[i]
		var p1 := points[i + 1]
		roads.append({"a": p0, "b": p1, "width": STREET_WIDTH.avenue, "kind": "avenue", "city": null,
			"lo": Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)) - Vector2.ONE * reach,
			"hi": Vector2(maxf(p0.x, p1.x), maxf(p0.y, p1.y)) + Vector2.ONE * reach})
	return roads


## Altura média do terreno no local, ou NAN se for montanhoso/inclinado demais.
static func _site_height(world: TerrainWorld, center: Vector2, radius: float) -> float:
	var heights := []
	for i in 9:
		var p := center if i == 0 else center + Vector2.from_angle(TAU * i / 8.0) * radius
		var biome := world.biome_at(p.x, p.y)
		if biome.mountain > 0.3 or biome.depth > 0.15:
			return NAN
		heights.append(world.raw_height(p.x, p.y, biome))
	if heights.max() - heights.min() > 22.0:
		return NAN
	var total := 0.0
	for h in heights:
		total += h
	return total / heights.size()


## Planta em grade (quadrada, mas com bordas irregulares): ruas nas linhas da
## grade — avenidas cruzando o centro (cidades grandes/médias), ruas comuns e
## ruas de terra (vilas e periferia). Lotes dentro das quadras, de frente para a rua.
static func _layout(city: Dictionary, cfg: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = city.seed
	var block: float = cfg.block
	var half: float = city.radius
	var n := int(ceil(half / block))
	var village: bool = city.size == "small"
	# Quadras incluídas: dentro do quadrado, com a borda "mordida" aleatoriamente.
	var blocks := {}
	for i in range(-n, n):
		for j in range(-n, n):
			var c := Vector2((i + 0.5) * block, (j + 0.5) * block)
			var edge := maxf(absf(c.x), absf(c.y))
			if edge > half - rng.randf() * block * 0.9:
				continue
			if rng.randf() > cfg.fill and (i != 0 or j != 0):
				continue
			blocks[Vector2i(i, j)] = c
	city["blocks"] = blocks
	# Ruas: cada linha da grade que encosta em alguma quadra incluída.
	var streets := []
	for axis in 2:
		for k in range(-n, n + 1):
			var lo := INF
			var hi := -INF
			for key in blocks:
				var touches: bool = (key.x == k or key.x == k - 1) if axis == 0 else (key.y == k or key.y == k - 1)
				if not touches:
					continue
				var along: float = blocks[key].y if axis == 0 else blocks[key].x
				lo = minf(lo, along - block * 0.5)
				hi = maxf(hi, along + block * 0.5)
			if lo > hi:
				continue
			var kind := "street"
			if village or absi(k) >= n - 1:
				kind = "dirt"
			if k == 0 and not village:
				kind = "avenue"
			var line := k * block
			var a := Vector2(line, lo) if axis == 0 else Vector2(lo, line)
			var b := Vector2(line, hi) if axis == 0 else Vector2(hi, line)
			streets.append({"a": to_world(city, a), "b": to_world(city, b), "width": STREET_WIDTH[kind], "kind": kind, "city": city})
	city["streets"] = streets
	# Lotes: 2x2 por quadra nas cidades (às vezes um lote grande), 1-2 soltos nas vilas.
	var lots := []
	var inner := block - STREET_WIDTH.street - 1.0
	for key in blocks:
		if key == Vector2i(0, 0) and not village:
			continue # praça no meio
		var c: Vector2 = blocks[key]
		var cells := []
		if village:
			var spots := [Vector2(-5, -5), Vector2(5, 5), Vector2(5, -5), Vector2(-5, 5)]
			spots.shuffle()
			for k in rng.randi_range(1, 3):
				cells.append([c + spots[k] + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)), rng.randf_range(5.0, 7.0), rng.randf_range(5.0, 7.0)])
		elif rng.randf() < 0.2:
			cells.append([c, inner * rng.randf_range(0.6, 0.8), inner * rng.randf_range(0.6, 0.8)])
		else:
			var q := inner * 0.25
			for dx in [-1, 1]:
				for dz in [-1, 1]:
					if rng.randf() < 0.1:
						continue
					cells.append([c + Vector2(dx * q, dz * q), inner * 0.5 - 1.2, inner * 0.5 - 1.2])
		for cell in cells:
			var local: Vector2 = cell[0]
			var t := maxf(absf(local.x), absf(local.y)) / half
			var floors := 1
			match city.size:
				"large":
					# Centro: torres-casa de ~16 andares (~50 m); caem rápido para fora.
					floors = int(round(lerpf(cfg.max_floors + 2.0, 2.0, pow(t, 0.7)) * rng.randf_range(0.75, 1.08)))
				"medium":
					floors = int(round(lerpf(cfg.max_floors, 1.5, t) * rng.randf_range(0.6, 1.1)))
				"small":
					floors = rng.randi_range(1, 2)
			floors = clampi(floors, 1, cfg.max_floors + 1) # grande: até 16 andares ≈ 51 m
			# Frente virada para a rua mais próxima da quadra (múltiplo de 90°, um pouco torto).
			var off: Vector2 = local - c
			var facing := 0.0
			if absf(off.x) > absf(off.y):
				facing = PI * 0.5 if off.x > 0.0 else -PI * 0.5
			else:
				facing = PI if off.y > 0.0 else 0.0
			lots.append({"pos": to_world(city, local), "w": cell[1], "d": cell[2], "floors": floors,
				"ruin": rng.randf() < (0.25 if village else 0.15), "yaw": city.yaw + facing + rng.randf_range(-0.08, 0.08),
				"seed": rng.randi(), "village": village})
	city["lots"] = lots
	city["plaza"] = Vector2(block * 0.5, block * 0.5) if not village else Vector2.ZERO


# --- Construção de uma casa ---------------------------------------------------

static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.95
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED # ruínas abertas: sem faces "furadas"
	return _material


## Poste de rua de ferro com lampião (alguns tortos; luz opcional).
static func build_lamp(rng: RandomNumberGenerator, lit: bool, tilt: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Poste"
	var mb := MeshBuilder.new()
	var iron := Color(0.16, 0.15, 0.15)
	mb.color(iron)
	mb.tube(PackedVector3Array([Vector3.ZERO, Vector3(0, 3.4, 0)]), 0.06, 6)
	mb.box(Vector3(0, 0.15, 0), Vector3(0.22, 0.3, 0.22))
	mb.tube(PackedVector3Array([Vector3(0, 3.3, 0), Vector3(0.25, 3.5, 0), Vector3(0.55, 3.45, 0)]), 0.035, 5)
	mb.color(Color(0.5, 0.42, 0.25)) # lampião de latão
	mb.box(Vector3(0.55, 3.32, 0), Vector3(0.24, 0.05, 0.24))
	mb.box(Vector3(0.55, 3.08, 0), Vector3(0.2, 0.04, 0.2))
	var glass := Color(1.0, 0.85, 0.5) if lit else Color(0.25, 0.25, 0.22)
	mb.color(glass)
	mb.box(Vector3(0.55, 3.2, 0), Vector3(0.18, 0.2, 0.18))
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(material(), false)
	root.add_child(mesh)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.08
	cylinder.height = 3.4
	shape.shape = cylinder
	shape.position = Vector3(0, 1.7, 0)
	body.add_child(shape)
	root.add_child(body)
	if lit:
		var light := OmniLight3D.new()
		light.name = "Light"
		light.position = Vector3(0.55, 3.05, 0)
		light.light_color = Color(1.0, 0.78, 0.45)
		light.light_energy = 1.4
		light.omni_range = 10.0
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		light.distance_fade_enabled = true # longe some (não pesa)
		light.distance_fade_begin = 70.0
		light.distance_fade_length = 20.0
		root.add_child(light)
	if tilt != 0.0:
		root.rotation = Vector3(tilt * 0.6, 0, tilt) # torto: bateram nele ou o chão cedeu
	return root


## Casa pronta (malha + colisão) com a base na origem; posicione pelo lote.
static func build_house(lot: Dictionary) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = lot.seed
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var w: float = lot.w
	var d: float = lot.d
	var floors: int = lot.floors
	# ~30% das casas inteiras têm o térreo oco, com móveis (sorteio separado:
	# não muda o resto do desenho das casas).
	var inside_rng := RandomNumberGenerator.new()
	inside_rng.seed = lot.seed + 4242
	var hollow: bool = not lot.ruin and inside_rng.randf() < 0.3 and w >= 5.0 and d >= 5.0
	# Fundação de pedra (afunda no chão).
	_box(mb, body, STONE.darkened(0.1), Vector3(0, -0.4, 0), Vector3(w + 0.4, 1.4, d + 0.4), Basis.IDENTITY)
	if lot.ruin:
		_ruin(mb, body, rng, w, d)
	else:
		var y := 0.3
		var fw := w
		var fd := d
		var offset := Vector3.ZERO
		var yaw := 0.0
		var plaster: Color = PLASTER[rng.randi() % PLASTER.size()]
		for i in floors:
			# Cada andar um pouco diferente: tamanho, deslocamento e torto (estilo Hello Neighbor).
			if i > 0:
				fw = clampf(fw * rng.randf_range(0.82, 1.08), 3.6, w * 1.15)
				fd = clampf(fd * rng.randf_range(0.82, 1.08), 3.6, d * 1.15)
				offset += Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
				offset = offset.limit_length(1.2)
				yaw += rng.randf_range(-0.07, 0.07)
			var tilt := rng.randf_range(-0.02, 0.02) if i > 0 else 0.0
			var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, tilt)
			var center := offset + Vector3(0, y + FLOOR_HEIGHT * 0.5, 0)
			var color: Color = STONE if i == 0 and not lot.village else (WOOD if (i + int(lot.seed)) % 3 == 0 else plaster)
			color = color.darkened(rng.randf_range(0.0, 0.15))
			if i == 0 and hollow:
				_hollow_floor(mb, body, color, center, fw, fd)
			else:
				_box(mb, body, color, center, Vector3(fw, FLOOR_HEIGHT, fd), basis)
			# Viga escura em cima do andar e janelas nas 4 paredes.
			_box(mb, null, DARK_WOOD, center + basis * Vector3(0, FLOOR_HEIGHT * 0.5 - 0.1, 0), Vector3(fw + 0.12, 0.2, fd + 0.12), basis)
			_windows(mb, rng, center, basis, fw, fd, i == 0)
			# Puxadinho saindo da lateral em alguns andares (casas altas).
			if i > 0 and i < floors - 1 and rng.randf() < 0.22:
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				var annex := center + basis * Vector3(side * (fw * 0.5 + 1.0), -0.2, rng.randf_range(-fd * 0.2, fd * 0.2))
				_box(mb, body, plaster.darkened(0.2), annex, Vector3(2.0, FLOOR_HEIGHT * 0.8, 2.6), basis)
				_box(mb, null, DARK_WOOD, annex + Vector3(0, -FLOOR_HEIGHT * 0.45, 0), Vector3(0.15, 0.6, 0.15), basis) # mão-francesa
			# Ramificação tipo cacto: um "braço" sai da torre e sobe sozinho.
			if floors >= 6 and i >= 2 and i <= floors - 3 and rng.randf() < 0.18:
				_branch(mb, body, rng, center, basis, fw, fd, plaster, floors - i)
			y += FLOOR_HEIGHT
		_roof(mb, body, rng, offset + Vector3(0, y, 0), Basis(Vector3.UP, yaw), fw, fd)
		# Chaminé e cano de cobre descendo pela parede (steampunk).
		var chimney := offset + Vector3(fw * 0.25, y + 1.2, fd * 0.2)
		_box(mb, body, STONE, chimney, Vector3(0.7, 2.6, 0.7), Basis(Vector3.UP, yaw))
		mb.color(COPPER)
		var pipe_x := w * 0.5 + 0.25
		mb.tube(PackedVector3Array([Vector3(pipe_x, 0.2, -d * 0.3), Vector3(pipe_x, minf(y, 9.0), -d * 0.3),
			Vector3(pipe_x - 0.3, minf(y, 9.0) + 0.3, -d * 0.3)]), 0.12, 6)
	# Porta e um barril/caldeira ao lado de algumas casas.
	if not lot.ruin and not hollow:
		_box(mb, null, DARK_WOOD, Vector3(0, 1.3, -d * 0.5 - 0.05), Vector3(1.1, 2.1, 0.1), Basis.IDENTITY)
	if rng.randf() < 0.35:
		mb.color(IRON)
		mb.lathe(PackedVector2Array([Vector2(0.02, 0.0), Vector2(0.55, 0.0), Vector2(0.6, 0.8), Vector2(0.55, 1.6), Vector2(0.02, 1.7)]),
				8, Basis.IDENTITY, Vector3(-w * 0.5 - 0.9, 0.0, d * 0.25))
		_shape(body, Vector3(-w * 0.5 - 0.9, 0.85, d * 0.25), Vector3(1.1, 1.7, 1.1), Basis.IDENTITY)
	if lot.village and rng.randf() < 0.6:
		_fence(mb, rng, w, d)
	var house := Node3D.new()
	if hollow:
		_furnish(house, lot, inside_rng, w, d)
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(material(), false)
	house.add_child(mesh)
	house.add_child(body)
	return house


## Térreo oco: 4 paredes (com a porta aberta na frente, -Z), piso de tábuas e
## teto. Os andares de cima continuam por cima, como antes.
static func _hollow_floor(mb: MeshBuilder, body: StaticBody3D, color: Color, center: Vector3, fw: float, fd: float) -> void:
	var t := 0.3
	var h := FLOOR_HEIGHT
	var base := center - Vector3(0, h * 0.5, 0)
	var door_w := 1.3
	var door_h := 2.3
	# Fundo e laterais.
	_box(mb, body, color, base + Vector3(0, h * 0.5, fd * 0.5 - t * 0.5), Vector3(fw, h, t), Basis.IDENTITY)
	for side in [-1.0, 1.0]:
		_box(mb, body, color, base + Vector3(side * (fw * 0.5 - t * 0.5), h * 0.5, 0), Vector3(t, h, fd - t * 2.0), Basis.IDENTITY)
	# Frente com o vão da porta.
	var piece := (fw - door_w) * 0.5
	for side in [-1.0, 1.0]:
		_box(mb, body, color, base + Vector3(side * (door_w * 0.5 + piece * 0.5), h * 0.5, -fd * 0.5 + t * 0.5), Vector3(piece, h, t), Basis.IDENTITY)
	_box(mb, body, color, base + Vector3(0, door_h + (h - door_h) * 0.5, -fd * 0.5 + t * 0.5), Vector3(door_w, h - door_h, t), Basis.IDENTITY)
	# Batente escuro em volta do vão.
	_box(mb, null, DARK_WOOD, base + Vector3(0, door_h + 0.06, -fd * 0.5 - 0.02), Vector3(door_w + 0.2, 0.12, t + 0.08), Basis.IDENTITY)
	for side in [-1.0, 1.0]:
		_box(mb, null, DARK_WOOD, base + Vector3(side * (door_w * 0.5 + 0.06), door_h * 0.5, -fd * 0.5 - 0.02), Vector3(0.12, door_h, t + 0.08), Basis.IDENTITY)
	# Piso de tábuas e teto.
	_box(mb, body, WOOD.lightened(0.08), base + Vector3(0, 0.03, 0), Vector3(fw - t * 2.0, 0.06, fd - t * 2.0), Basis.IDENTITY)
	_box(mb, body, WOOD.darkened(0.15), base + Vector3(0, h - 0.1, 0), Vector3(fw, 0.2, fd), Basis.IDENTITY)


## Móveis do térreo oco (quebráveis: Furniture). Cama e armário no fundo,
## mesa com cadeiras no meio, estante e fogão nas laterais; a porta fica livre.
static func _furnish(house: Node3D, lot: Dictionary, rng: RandomNumberGenerator, w: float, d: float) -> void:
	var floor_y := 0.36
	var ix := w * 0.5 - 0.3 # face de dentro das paredes
	var iz := d * 0.5 - 0.3
	var plan := [
		["cama", Vector3(-ix + 0.55, floor_y, iz - 1.05), 0.0],
		["armario", Vector3(ix - 0.6, floor_y, iz - 0.3), PI],
		["mesa", Vector3(0.6, floor_y, 0.2), 0.0],
		["cadeira", Vector3(0.6, floor_y, 0.75), PI],
		["cadeira", Vector3(0.6, floor_y, -0.35), 0.0],
		["estante", Vector3(-ix + 0.2, floor_y, -0.6), PI / 2],
		["fogao", Vector3(ix - 0.35, floor_y, -iz + 1.2), -PI / 2],
	]
	for k in plan.size():
		var entry: Array = plan[k]
		if rng.randf() < 0.18:
			continue # alguns móveis já foram levados
		var piece := Furniture.new()
		piece.setup("mov_%d_%d" % [lot.seed, k], entry[0], material())
		piece.position = entry[1]
		piece.rotation.y = entry[2] + rng.randf_range(-0.12, 0.12)
		house.add_child(piece)
	# Lampião aceso no meio do cômodo (luz fraca, some de longe: barato).
	var lamp := Node3D.new()
	lamp.position = Vector3(0.6, floor_y + 2.35, 0.2)
	house.add_child(lamp)
	var mb := MeshBuilder.new()
	mb.color(ItemModels.BRASS)
	mb.box(Vector3(0, 0.12, 0), Vector3(0.02, 0.5, 0.02)) # corrente do teto
	mb.box(Vector3(0, -0.14, 0), Vector3(0.16, 0.03, 0.16))
	mb.color(Color(1.0, 0.85, 0.5))
	mb.box(Vector3(0, -0.24, 0), Vector3(0.12, 0.18, 0.12))
	var lamp_mesh := MeshInstance3D.new()
	lamp_mesh.mesh = mb.finish(material(), false)
	lamp.add_child(lamp_mesh)
	var light := OmniLight3D.new()
	light.position = Vector3(0, -0.3, 0)
	light.light_color = Color(1.0, 0.78, 0.5)
	light.light_energy = 1.1
	light.omni_range = 6.0
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_length = 6.0
	lamp.add_child(light)


## Braço de casa saindo da lateral da torre: passarela fechada e uma torrezinha
## torta que sobe 2-5 andares com telhado próprio (mesma estranheza dos cactos).
static func _branch(mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator, center: Vector3, basis: Basis,
		fw: float, fd: float, plaster: Color, room_above: int) -> void:
	var face := rng.randi() % 4
	var out := basis * (Basis(Vector3.UP, face * PI * 0.5) * Vector3(0, 0, -1))
	var half_depth := (fd if face % 2 == 0 else fw) * 0.5
	var arm_length := rng.randf_range(2.5, 4.5)
	var arm_center := center + out * (half_depth + arm_length * 0.5) + Vector3(0, -0.3, 0)
	var arm_basis := Basis.looking_at(out, Vector3.UP)
	_box(mb, body, WOOD.darkened(0.1), arm_center, Vector3(2.2, FLOOR_HEIGHT * 0.75, arm_length + 0.4), arm_basis)
	_box(mb, null, DARK_WOOD, arm_center + Vector3(0, -FLOOR_HEIGHT * 0.45, 0), Vector3(0.25, 0.25, arm_length), arm_basis)
	# Torrezinha na ponta do braço.
	var size := rng.randf_range(3.2, 4.2)
	var stack := rng.randi_range(2, clampi(room_above + 1, 2, 5))
	var base := center + out * (half_depth + arm_length + size * 0.4)
	var tilt := 0.0
	var y := -FLOOR_HEIGHT * 0.5
	var color := plaster.darkened(rng.randf_range(0.05, 0.2))
	for k in stack:
		tilt += rng.randf_range(-0.05, 0.05)
		var b := arm_basis * Basis(Vector3.BACK, tilt) * Basis(Vector3.UP, rng.randf_range(-0.12, 0.12))
		var c := base + Vector3(0, y + FLOOR_HEIGHT * 0.5, 0) + out * (k * 0.15)
		_box(mb, body, color if k % 2 == 0 else WOOD, c, Vector3(size, FLOOR_HEIGHT, size), b)
		_windows(mb, rng, c, b, size, size, false)
		y += FLOOR_HEIGHT
		size *= rng.randf_range(0.85, 1.0)
	_roof(mb, body, rng, base + Vector3(0, y, 0) + out * (stack * 0.15), arm_basis * Basis(Vector3.BACK, tilt), size, size)


static func _windows(mb: MeshBuilder, rng: RandomNumberGenerator, center: Vector3, basis: Basis, fw: float, fd: float, ground: bool) -> void:
	for face in 4:
		var length := fw if face % 2 == 0 else fd
		var depth := fd if face % 2 == 0 else fw
		var count := int(length / 2.4)
		for k in count:
			if ground and face == 0 and k == count / 2:
				continue # lugar da porta
			if rng.randf() < 0.2:
				continue
			var along := (k + 0.5) / count * length - length * 0.5
			var local := Vector3(along, 0.2, -depth * 0.5 - 0.03) # um pouco para fora da parede
			var face_basis := Basis(Vector3.UP, face * PI / 2.0)
			var boarded := rng.randf() < 0.3
			var color := WOOD if boarded else WINDOW
			_box(mb, null, color, center + basis * (face_basis * local), Vector3(0.85, 1.15, 0.08), basis * face_basis)


static func _roof(mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator, base: Vector3, basis: Basis, fw: float, fd: float) -> void:
	var color: Color = ROOF[rng.randi() % ROOF.size()]
	var height := fw * rng.randf_range(0.5, 0.85) # telhado íngreme
	var hw := fw * 0.5 + 0.35
	var broken := rng.randf() < 0.3
	var shape := PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0), Vector2(0, height)])
	if broken:
		# Telhado desabado de um lado: só uma água + caibros à mostra.
		shape = PackedVector2Array([Vector2(-hw, 0), Vector2(0.0, 0), Vector2(0, height)])
		mb.color(DARK_WOOD)
		var rafter := Basis(Vector3.BACK, -atan2(height, hw)) # caibro ao longo da água que caiu
		for k in 4:
			var z := lerpf(-fd * 0.45, fd * 0.45, k / 3.0)
			mb.box(base + basis * Vector3(hw * 0.5, height * 0.5, z), Vector3(sqrt(hw * hw + height * height), 0.12, 0.12), basis * rafter)
	mb.color(color.darkened(rng.randf_range(0.0, 0.15)))
	# Extrusão em Z local; gira para o telhado correr ao longo da profundidade.
	mb.extrude(shape, fd + 0.6, basis, base)
	var points := PackedVector3Array()
	for p in shape:
		for z in [-(fd + 0.6) * 0.5, (fd + 0.6) * 0.5]:
			points.append(basis * Vector3(p.x, p.y, z) + base)
	var collision := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	convex.points = points
	collision.shape = convex
	body.add_child(collision)


## Ruína: paredes quebradas de alturas diferentes, sem telhado, entulho.
static func _ruin(mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator, w: float, d: float) -> void:
	var walls := [[Vector3(0, 0, -d * 0.5), Vector3(w, 0, 0.4)], [Vector3(0, 0, d * 0.5), Vector3(w, 0, 0.4)],
		[Vector3(-w * 0.5, 0, 0), Vector3(0.4, 0, d)], [Vector3(w * 0.5, 0, 0), Vector3(0.4, 0, d)]]
	for wall in walls:
		if rng.randf() < 0.2:
			continue # parede que caiu inteira
		var pieces := 3
		for k in pieces:
			var t := (k + 0.5) / pieces - 0.5
			var size: Vector3 = wall[1]
			var piece_size := Vector3(maxf(size.x / pieces, 0.4), rng.randf_range(0.8, FLOOR_HEIGHT * 1.8), maxf(size.z / pieces, 0.4))
			var pos: Vector3 = wall[0] + Vector3(size.x * t, piece_size.y * 0.5 + 0.3, size.z * t)
			_box(mb, body, STONE.darkened(rng.randf_range(0.0, 0.2)), pos, piece_size, Basis(Vector3.BACK, rng.randf_range(-0.04, 0.04)))
	for k in 5:
		var pos := Vector3(rng.randf_range(-w, w) * 0.5, 0.3, rng.randf_range(-d, d) * 0.5)
		var size := Vector3(rng.randf_range(0.4, 1.1), rng.randf_range(0.3, 0.7), rng.randf_range(0.4, 1.1))
		_box(mb, body, STONE.darkened(0.25), pos, size, Basis(Vector3.UP, rng.randf() * TAU))


static func _fence(mb: MeshBuilder, rng: RandomNumberGenerator, w: float, d: float) -> void:
	var hw := w * 0.5 + 2.0
	var hd := d * 0.5 + 2.0
	var corners := [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]
	mb.color(WOOD.darkened(0.1))
	for c in 4:
		var a: Vector3 = corners[c]
		var b: Vector3 = corners[(c + 1) % 4]
		var posts := int(a.distance_to(b) / 1.6)
		for k in posts + 1:
			if c == 0 and abs(k - posts / 2) <= 1:
				continue # portão
			var p := a.lerp(b, float(k) / posts)
			mb.box(p + Vector3(0, 0.5, 0), Vector3(0.12, 1.0 + rng.randf_range(-0.2, 0.1), 0.12), Basis(Vector3.BACK, rng.randf_range(-0.1, 0.1)))
		mb.box(a.lerp(b, 0.5) + Vector3(0, 0.7, 0), Vector3(a.distance_to(b), 0.08, 0.06) if c % 2 == 0 else Vector3(0.06, 0.08, a.distance_to(b)))


static func _box(mb: MeshBuilder, body: StaticBody3D, color: Color, center: Vector3, size: Vector3, basis: Basis) -> void:
	mb.color(color)
	mb.box(center, size, basis)
	if body:
		_shape(body, center, size, basis)


static func _shape(body: StaticBody3D, center: Vector3, size: Vector3, basis: Basis) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.transform = Transform3D(basis, center)
	body.add_child(collision)


## Peça central da praça: caldeira enferrujada com chaminé e canos (ou poço, na vila).
static func build_plaza(city: Dictionary) -> Node3D:
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	if city.size == "small":
		mb.color(STONE)
		mb.lathe(PackedVector2Array([Vector2(1.2, 0.0), Vector2(1.2, 0.9), Vector2(0.95, 0.9), Vector2(0.95, 0.2)]), 10)
		_box(mb, null, DARK_WOOD, Vector3(-1.0, 1.6, 0), Vector3(0.15, 1.6, 0.15), Basis.IDENTITY)
		_box(mb, null, DARK_WOOD, Vector3(1.0, 1.6, 0), Vector3(0.15, 1.6, 0.15), Basis.IDENTITY)
		_box(mb, null, ROOF[0], Vector3(0, 2.5, 0), Vector3(2.6, 0.2, 1.6), Basis(Vector3.RIGHT, 0.0))
		_shape(body, Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 2.4), Basis.IDENTITY)
	else:
		var scale := 1.6 if city.size == "large" else 1.0
		mb.color(IRON)
		mb.lathe(Transform2D.IDENTITY.scaled(Vector2.ONE * scale) * PackedVector2Array([Vector2(0.05, 0.0), Vector2(2.4, 0.0), Vector2(2.6, 2.0), Vector2(2.4, 5.5), Vector2(1.4, 6.5), Vector2(0.05, 6.7)]), 12)
		mb.color(STONE)
		mb.lathe(Transform2D.IDENTITY.scaled(Vector2.ONE * scale) * PackedVector2Array([Vector2(0.6, 6.2), Vector2(0.6, 14.0), Vector2(0.8, 14.5)]), 8)
		mb.color(COPPER)
		for i in 4:
			var a := TAU * i / 4.0
			var out := Vector3(cos(a), 0, sin(a))
			mb.tube(PackedVector3Array([out * 2.3 * scale + Vector3(0, 3.0 * scale, 0), out * 3.6 * scale + Vector3(0, 3.4 * scale, 0), out * 3.8 * scale + Vector3(0, 0.0, 0)]), 0.18 * scale, 6)
		_shape(body, Vector3(0, 3.3 * scale, 0), Vector3(5.0, 6.6, 5.0) * scale, Basis.IDENTITY)
		_shape(body, Vector3(0, 10.0 * scale, 0), Vector3(1.4, 8.0, 1.4) * scale, Basis.IDENTITY)
	var node := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = mb.finish(material(), false)
	node.add_child(mesh)
	node.add_child(body)
	return node
