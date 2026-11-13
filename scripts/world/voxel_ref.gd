class_name VoxelRef
extends RefCounted
## Versão em GDScript do núcleo de voxels (native/src/voxel_core.cpp), passo a passo
## igual: mesmo ruído, mesma semente, mesmas cavernas, veios e malha (Surface Nets). Serve
## para conferir o C++ (tests/test_voxel_ref.gd compara as duas), para fotos e como
## reserva se a extensão não carregar. É ~100x mais lenta: o jogo usa a ApioVoxel (C++).
##
## Dados de uma seção: PackedByteArray com 18^3 densidades (int8 em byte), 18^3 materiais
## e 4 bytes com a contagem de blocos cheios (o mesmo formato do C++).

const N := 16
const P := N + 2
const P3 := P * P * P
const GRID := 0.4
const SEA_LEVEL := -1.0
const BOTTOM := -61.0
const DATA_SIZE := P3 * 2 + 4

enum { AIR, TOPSOIL, DIRT, SAND, STONE, BEDROCK, COAL, IRON, COPPER, TIN, SULFUR, GRAVEL,
	BUILT_DIRT = 16, BUILT_STONE, BUILT_SAND }

const COLORS := {TOPSOIL: Color(0.32, 0.42, 0.2), DIRT: Color(0.4, 0.29, 0.19), SAND: Color(0.76, 0.65, 0.45),
	STONE: Color(0.45, 0.44, 0.42), BEDROCK: Color(0.18, 0.17, 0.17), COAL: Color(0.13, 0.12, 0.12),
	IRON: Color(0.6, 0.38, 0.28), COPPER: Color(0.3, 0.55, 0.48), TIN: Color(0.72, 0.73, 0.76),
	SULFUR: Color(0.86, 0.78, 0.22), GRAVEL: Color(0.52, 0.5, 0.47), BUILT_DIRT: Color(0.43, 0.31, 0.2),
	BUILT_STONE: Color(0.5, 0.49, 0.46), BUILT_SAND: Color(0.76, 0.65, 0.45)}


## Ruído gradiente 3D (Perlin melhorado) com a permutação embaralhada por xorshift32.
class Noise3:
	var perm := PackedInt32Array()

	func _init(seed: int) -> void:
		var p := PackedInt32Array()
		p.resize(256)
		for i in 256:
			p[i] = i
		var state := ((seed & 0xFFFFFFFF) * 2654435761 + 12345) & 0xFFFFFFFF
		if state == 0:
			state = 1
		for i in range(255, 0, -1):
			state ^= (state << 13) & 0xFFFFFFFF
			state ^= state >> 17
			state ^= (state << 5) & 0xFFFFFFFF
			var j := state % (i + 1)
			var t := p[i]
			p[i] = p[j]
			p[j] = t
		perm.resize(512)
		for i in 512:
			perm[i] = p[i & 255]

	static func _fade(t: float) -> float:
		return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

	static func _grad(h: int, x: float, y: float, z: float) -> float:
		var g := h & 15
		var u := x if g < 8 else y
		var v := y if g < 4 else (x if g == 12 or g == 14 else z)
		return (-u if g & 1 else u) + (-v if g & 2 else v)

	func noise(x: float, y: float, z: float) -> float:
		var fx := floorf(x)
		var fy := floorf(y)
		var fz := floorf(z)
		var X := int(fx) & 255
		var Y := int(fy) & 255
		var Z := int(fz) & 255
		x -= fx
		y -= fy
		z -= fz
		var u := _fade(x)
		var v := _fade(y)
		var w := _fade(z)
		var A := perm[X] + Y
		var AA := perm[A] + Z
		var AB := perm[A + 1] + Z
		var B := perm[X + 1] + Y
		var BA := perm[B] + Z
		var BB := perm[B + 1] + Z
		return lerpf(
			lerpf(lerpf(_grad(perm[AA], x, y, z), _grad(perm[BA], x - 1, y, z), u),
				lerpf(_grad(perm[AB], x, y - 1, z), _grad(perm[BB], x - 1, y - 1, z), u), v),
			lerpf(lerpf(_grad(perm[AA + 1], x, y, z - 1), _grad(perm[BA + 1], x - 1, y, z - 1), u),
				lerpf(_grad(perm[AB + 1], x, y - 1, z - 1), _grad(perm[BB + 1], x - 1, y - 1, z - 1), u), v),
			w)

	func fbm(x: float, y: float, z: float, octaves: int) -> float:
		var sum := 0.0
		var amp := 1.0
		var norm := 0.0
		for i in octaves:
			sum += noise(x, y, z) * amp
			norm += amp
			amp *= 0.5
			x *= 2.03
			y *= 2.03
			z *= 2.03
		return sum / norm


var seed := 1337
var cave_amount := 1.0
var ore_amount := 1.0
var _tunnel_a: Noise3
var _tunnel_b: Noise3
var _cavern: Noise3
var _entrance: Noise3
var _ore_shape: Noise3
var _ore_kind: Noise3


func _init() -> void:
	setup(1337, 1.0, 1.0)


func setup(seed_: int, caves: float, ores: float) -> void:
	seed = seed_
	cave_amount = caves
	ore_amount = ores
	var s := seed_ & 0xFFFFFFFF
	_tunnel_a = Noise3.new((s * 7 + 1) & 0xFFFFFFFF)
	_tunnel_b = Noise3.new((s * 7 + 2) & 0xFFFFFFFF)
	_cavern = Noise3.new((s * 7 + 3) & 0xFFFFFFFF)
	_entrance = Noise3.new((s * 7 + 4) & 0xFFFFFFFF)
	_ore_shape = Noise3.new((s * 7 + 5) & 0xFFFFFFFF)
	_ore_kind = Noise3.new((s * 7 + 6) & 0xFFFFFFFF)


static func idx(x: int, y: int, z: int) -> int:
	return (y * P + z) * P + x


## > 0 = dentro da caverna (ar), em blocos.
func cave_field(x: float, y: float, z: float, depth: float) -> float:
	if cave_amount <= 0.0 or y < BOTTOM + 2.0:
		return -10.0
	var a := _tunnel_a.noise(x / 30.0, y / 16.0, z / 30.0)
	var b := _tunnel_b.noise(x / 30.0, y / 16.0, z / 30.0)
	var width := 0.06 * sqrt(cave_amount) * (1.0 + 0.5 * smoothstep(15.0, 50.0, depth))
	var tunnel := (width - sqrt(a * a + b * b)) * 55.0
	var c := _cavern.fbm(x / 46.0, y / 26.0, z / 46.0, 2)
	var threshold := 0.56 + (1.0 - cave_amount) * 0.2 - 0.12 * smoothstep(12.0, 50.0, depth)
	var hall := (c - threshold) * 45.0
	var field := maxf(tunnel, hall)
	var opening := smoothstep(0.55, 0.7, _entrance.noise(x / 70.0, 0.37, z / 70.0))
	var roof := maxf(smoothstep(2.5, 7.0, depth), opening * smoothstep(-1.0, 1.5, depth))
	return field * roof - (1.0 - roof) * 3.0


static func ore_from(blob: float, vein: float, kind: float, depth: float, amount: float) -> int:
	if amount <= 0.0 or depth < 2.0:
		return STONE
	var rare := 0.02 * amount + 0.03 * smoothstep(10.0, 50.0, depth)
	if blob < 0.66 - rare and absf(vein) > 0.009 * amount:
		return STONE
	var k := (kind + 1.0) * 0.5
	if depth < 18.0:
		return COAL if k < 0.6 else IRON
	if depth < 38.0:
		return COAL if k < 0.35 else (IRON if k < 0.7 else COPPER)
	return IRON if k < 0.3 else (COPPER if k < 0.55 else (TIN if k < 0.8 else SULFUR))


## Enche a seção a partir das alturas das colunas (18 x 18, índice z * 18 + x) e do solo
## (0 terra, 1 areia, 2 rocha).
func fill(section: Vector3i, heights: PackedFloat32Array, soil: PackedByteArray) -> PackedByteArray:
	const G := P / 2 + 1
	var sx := section.x
	var sy := section.y
	var sz := section.z
	var cave := PackedFloat32Array()
	var blob := PackedFloat32Array()
	var vein := PackedFloat32Array()
	var kind := PackedFloat32Array()
	for arr in [cave, blob, vein, kind]:
		arr.resize(G * G * G)
	var top := (float(sy * N + P - 1) + 0.5) * GRID
	var bottom_y := (float(sy * N - 1) + 0.5) * GRID
	var h_max := -1e9
	for c in P * P:
		h_max = maxf(h_max, heights[c])
	var underground := bottom_y < h_max + 1.0 and top > BOTTOM
	if underground:
		for gy in G:
			var y := (float(sy * N + gy * 2 - 1) + 0.5) * GRID
			for gz in G:
				var z := (float(sz * N + gz * 2 - 1) + 0.5) * GRID
				for gx in G:
					var x := (float(sx * N + gx * 2 - 1) + 0.5) * GRID
					var col := mini(gz * 2, P - 1) * P + mini(gx * 2, P - 1)
					var depth := heights[col] - y
					var g := (gy * G + gz) * G + gx
					cave[g] = cave_field(x, y, z, depth) if depth > -2.0 and heights[col] > SEA_LEVEL + 1.5 else -10.0
					if depth > 2.0 and ore_amount > 0.0:
						blob[g] = _ore_shape.noise(x / 4.5, y / 4.0, z / 4.5)
						vein[g] = _ore_shape.noise(x / 13.0 + 31.7, y / 7.0, z / 13.0)
						kind[g] = _ore_kind.noise(x / 70.0, y / 40.0, z / 70.0)
					else:
						blob[g] = -1.0
						vein[g] = 1.0
						kind[g] = 0.0
	var out := PackedByteArray()
	out.resize(DATA_SIZE)
	var solid := 0
	for py in P:
		var y := (float(sy * N + py - 1) + 0.5) * GRID
		for pz in P:
			for px in P:
				var col := pz * P + px
				var i := idx(px, py, pz)
				if y < BOTTOM:
					out[i] = 127
					out[P3 + i] = BEDROCK
					solid += 1
					continue
				var h := heights[col]
				var depth := h - y
				var d := depth / GRID
				if underground and d > -2.0:
					d = minf(d, -_lerp3(cave, px, py, pz))
				d = clampf(d, -1.0, 1.0)
				var q := roundi(d * 127.0)
				out[i] = q & 255
				if q <= 0:
					out[P3 + i] = AIR
					continue
				solid += 1
				var s := soil[col] if soil.size() >= P * P else 0
				if depth < 1.0:
					out[P3 + i] = TOPSOIL
				elif depth < 3.2:
					out[P3 + i] = SAND if s == 1 else (STONE if s == 2 else DIRT)
				else:
					out[P3 + i] = ore_from(_lerp3(blob, px, py, pz), _lerp3(vein, px, py, pz),
						kind[((py >> 1) * G + (pz >> 1)) * G + (px >> 1)], depth, ore_amount)
	out.encode_s32(P3 * 2, solid)
	return out


static func _lerp3(a: PackedFloat32Array, px: int, py: int, pz: int) -> float:
	const G := P / 2 + 1
	var x0 := px >> 1
	var y0 := py >> 1
	var z0 := pz >> 1
	var fx := (px & 1) * 0.5
	var fy := (py & 1) * 0.5
	var fz := (pz & 1) * 0.5
	var x1 := mini(x0 + 1, G - 1)
	var y1 := mini(y0 + 1, G - 1)
	var z1 := mini(z0 + 1, G - 1)
	var c00 := lerpf(a[(y0 * G + z0) * G + x0], a[(y0 * G + z0) * G + x1], fx)
	var c10 := lerpf(a[(y1 * G + z0) * G + x0], a[(y1 * G + z0) * G + x1], fx)
	var c01 := lerpf(a[(y0 * G + z1) * G + x0], a[(y0 * G + z1) * G + x1], fx)
	var c11 := lerpf(a[(y1 * G + z1) * G + x0], a[(y1 * G + z1) * G + x1], fx)
	return lerpf(lerpf(c00, c10, fy), lerpf(c01, c11, fy), fz)


static func solid_count(data: PackedByteArray) -> int:
	return data.decode_s32(P3 * 2) if data.size() >= DATA_SIZE else 0


static func density(data: PackedByteArray, i: int) -> int:
	var v := data[i]
	return v - 256 if v > 127 else v


const _CORNER := [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 0, 1),
	Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
const _EDGE := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]


## Malha (Surface Nets): [vértices, normais, cores], relativa à origem da seção.
func build_mesh(data: PackedByteArray, column_colors: PackedColorArray) -> Array:
	var verts_out := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var solid := solid_count(data)
	if solid == 0 or solid == P3:
		return [verts_out, normals, colors]
	const C := P - 1
	var dens := PackedInt32Array()
	dens.resize(P3)
	for i in P3:
		dens[i] = density(data, i)
	var cell_vertex := PackedInt32Array()
	cell_vertex.resize(C * C * C)
	cell_vertex.fill(-1)
	var verts := PackedVector3Array()
	var d := PackedFloat32Array()
	d.resize(8)
	for cy in C:
		for cz in C:
			for cx in C:
				var mask := 0
				for k in 8:
					var corner: Vector3i = _CORNER[k]
					d[k] = float(dens[idx(cx + corner.x, cy + corner.y, cz + corner.z)])
					if d[k] > 0.0:
						mask |= 1 << k
				if mask == 0 or mask == 255:
					continue
				var sum := Vector3.ZERO
				var n := 0
				for e in _EDGE:
					var a: int = e[0]
					var b: int = e[1]
					if ((mask >> a) & 1) == ((mask >> b) & 1):
						continue
					var t := d[a] / (d[a] - d[b])
					var pa := _sample_pos(Vector3i(cx, cy, cz) + _CORNER[a])
					var pb := _sample_pos(Vector3i(cx, cy, cz) + _CORNER[b])
					sum += pa + (pb - pa) * t
					n += 1
				cell_vertex[(cy * C + cz) * C + cx] = verts.size()
				verts.append(sum / n)
	var rock: Color = COLORS[STONE]
	for y in range(1, N + 1):
		for z in range(1, N + 1):
			for x in range(1, N + 1):
				var i0 := idx(x, y, z)
				var solid0 := dens[i0] > 0
				for axis in 3:
					var nx := x + int(axis == 0)
					var ny := y + int(axis == 1)
					var nz := z + int(axis == 2)
					var i1 := idx(nx, ny, nz)
					if solid0 == (dens[i1] > 0):
						continue
					var q: Array
					if axis == 0:
						q = [_cell(cell_vertex, x, y - 1, z - 1), _cell(cell_vertex, x, y, z - 1), _cell(cell_vertex, x, y, z), _cell(cell_vertex, x, y - 1, z)]
					elif axis == 1:
						q = [_cell(cell_vertex, x - 1, y, z - 1), _cell(cell_vertex, x, y, z - 1), _cell(cell_vertex, x, y, z), _cell(cell_vertex, x - 1, y, z)]
					else:
						q = [_cell(cell_vertex, x - 1, y - 1, z), _cell(cell_vertex, x, y - 1, z), _cell(cell_vertex, x, y, z), _cell(cell_vertex, x - 1, y, z)]
					if q.min() < 0:
						continue
					var outward := Vector3(float(axis == 0), float(axis == 1), float(axis == 2)) * (1.0 if solid0 else -1.0)
					var si := i0 if solid0 else i1
					var m := data[P3 + si]
					var color: Color
					if m == TOPSOIL and column_colors.size() >= P * P:
						color = column_colors[(z if solid0 else nz) * P + (x if solid0 else nx)]
					else:
						color = COLORS.get(m, Color(0.5, 0.5, 0.5))
					color.a = 1.0
					var a := verts[q[0]]
					var b := verts[q[1]]
					var c := verts[q[2]]
					var dd := verts[q[3]]
					if (a - c).length_squared() <= (b - dd).length_squared():
						_emit(a, b, c, outward, color, rock, verts_out, normals, colors)
						_emit(a, c, dd, outward, color, rock, verts_out, normals, colors)
					else:
						_emit(a, b, dd, outward, color, rock, verts_out, normals, colors)
						_emit(b, c, dd, outward, color, rock, verts_out, normals, colors)
	return [verts_out, normals, colors]


static func _cell(cells: PackedInt32Array, x: int, y: int, z: int) -> int:
	const C := P - 1
	return cells[(y * C + z) * C + x]


static func _sample_pos(p: Vector3i) -> Vector3:
	return Vector3((p.x - 0.5) * GRID, (p.y - 0.5) * GRID, (p.z - 0.5) * GRID)


static func _emit(a: Vector3, b: Vector3, c: Vector3, outward: Vector3, color: Color, rock: Color,
		verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> void:
	var n := (c - a).cross(b - a)
	if n.dot(outward) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	# Face muito inclinada (barranco, parede de caverna): puxa um pouco para a cor de rocha.
	if n.y < 0.55:
		color = color.lerp(rock, clampf((0.55 - n.y) * 2.2, 0.0, 0.85) * 0.6)
	for p in [a, b, c]:
		verts.append(p)
		normals.append(n)
		colors.append(color)
