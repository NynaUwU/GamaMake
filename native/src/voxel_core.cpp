#include "voxel_core.h"

#include <algorithm>
#include <cmath>

namespace apio {

// --- Ruído ------------------------------------------------------------------------------

// Embaralha 0..255 com xorshift32 (o mesmo em scripts/world/voxel_ref.gd: as duas versões
// geram exatamente o mesmo mundo).
Noise3::Noise3(uint32_t seed) {
	uint8_t p[256];
	for (int i = 0; i < 256; i++) {
		p[i] = uint8_t(i);
	}
	uint32_t state = seed * 2654435761u + 12345u;
	if (state == 0) {
		state = 1;
	}
	for (int i = 255; i > 0; i--) {
		state ^= state << 13;
		state ^= state >> 17;
		state ^= state << 5;
		std::swap(p[i], p[state % uint32_t(i + 1)]);
	}
	for (int i = 0; i < 512; i++) {
		perm[i] = p[i & 255];
	}
}

static inline float fade(float t) { return t * t * t * (t * (t * 6.0f - 15.0f) + 10.0f); }
static inline float lerpf(float a, float b, float t) { return a + (b - a) * t; }
static inline float grad(int h, float x, float y, float z) {
	const int g = h & 15;
	const float u = g < 8 ? x : y;
	const float v = g < 4 ? y : (g == 12 || g == 14 ? x : z);
	return ((g & 1) ? -u : u) + ((g & 2) ? -v : v);
}
static inline float smoothstep(float a, float b, float x) {
	const float t = std::clamp((x - a) / (b - a), 0.0f, 1.0f);
	return t * t * (3.0f - 2.0f * t);
}

float Noise3::noise(float x, float y, float z) const {
	const float fx = std::floor(x), fy = std::floor(y), fz = std::floor(z);
	const int X = int(fx) & 255, Y = int(fy) & 255, Z = int(fz) & 255;
	x -= fx;
	y -= fy;
	z -= fz;
	const float u = fade(x), v = fade(y), w = fade(z);
	const int A = perm[X] + Y, AA = perm[A] + Z, AB = perm[A + 1] + Z;
	const int B = perm[X + 1] + Y, BA = perm[B] + Z, BB = perm[B + 1] + Z;
	return lerpf(
			lerpf(lerpf(grad(perm[AA], x, y, z), grad(perm[BA], x - 1, y, z), u),
					lerpf(grad(perm[AB], x, y - 1, z), grad(perm[BB], x - 1, y - 1, z), u), v),
			lerpf(lerpf(grad(perm[AA + 1], x, y, z - 1), grad(perm[BA + 1], x - 1, y, z - 1), u),
					lerpf(grad(perm[AB + 1], x, y - 1, z - 1), grad(perm[BB + 1], x - 1, y - 1, z - 1), u), v),
			w);
}

float Noise3::fbm(float x, float y, float z, int octaves) const {
	float sum = 0.0f, amp = 1.0f, norm = 0.0f;
	for (int i = 0; i < octaves; i++) {
		sum += noise(x, y, z) * amp;
		norm += amp;
		amp *= 0.5f;
		x *= 2.03f;
		y *= 2.03f;
		z *= 2.03f;
	}
	return sum / norm;
}

// --- Geração ------------------------------------------------------------------------------

Generator::Generator(const GenParams &p) :
		params(p),
		tunnel_a(uint32_t(p.seed) * 7u + 1u),
		tunnel_b(uint32_t(p.seed) * 7u + 2u),
		cavern(uint32_t(p.seed) * 7u + 3u),
		entrance(uint32_t(p.seed) * 7u + 4u),
		ore_shape(uint32_t(p.seed) * 7u + 5u),
		ore_kind(uint32_t(p.seed) * 7u + 6u) {}

// > 0 = dentro da caverna (ar), em blocos (dá a posição exata da parede entre dois blocos).
float Generator::cave_field(float x, float y, float z, float depth) const {
	if (params.cave_amount <= 0.0f || y < BOTTOM + 2.0f) {
		return -10.0f;
	}
	// Túneis ("minhocas"): onde dois ruídos passam perto de zero ao mesmo tempo.
	const float a = tunnel_a.noise(x / 30.0f, y / 16.0f, z / 30.0f);
	const float b = tunnel_b.noise(x / 30.0f, y / 16.0f, z / 30.0f);
	const float width = 0.06f * std::sqrt(params.cave_amount) * (1.0f + 0.5f * smoothstep(15.0f, 50.0f, depth));
	const float tunnel = (width - std::sqrt(a * a + b * b)) * 55.0f;
	// Salões: bolsões grandes, mais comuns quanto mais fundo.
	const float c = cavern.fbm(x / 46.0f, y / 26.0f, z / 46.0f, 2);
	const float threshold = 0.56f + (1.0f - params.cave_amount) * 0.2f - 0.12f * smoothstep(12.0f, 50.0f, depth);
	const float hall = (c - threshold) * 45.0f;
	float field = std::max(tunnel, hall);
	// Perto da superfície a caverna fecha (o teto não cai), menos nas entradas raras.
	const float opening = smoothstep(0.55f, 0.7f, entrance.noise(x / 70.0f, 0.37f, z / 70.0f));
	const float roof = std::max(smoothstep(2.5f, 7.0f, depth), opening * smoothstep(-1.0f, 1.5f, depth));
	field = field * roof - (1.0f - roof) * 3.0f;
	return field;
}

float Generator::entrance_field(const Entrance *const *list, int n, float x, float y, float z, float h) {
	float best = -10.0f;
	for (int k = 0; k < n; k++) {
		const Entrance &e = *list[k];
		const float rx = x - e.x;
		const float rz = z - e.z;
		const float along = rx * e.dx + rz * e.dz;
		const float side = rz * e.dx - rx * e.dz;
		if (along > -ENTRANCE_RW && along < ENTRANCE_LEN + ENTRANCE_RW) {
			// Túnel que desce acompanhando o chão; no começo o teto some (vala aberta = a boca).
			const float t = std::clamp(along, 0.0f, ENTRANCE_LEN);
			const float yc = h - (0.4f + t * ENTRANCE_SLOPE);
			const float dy = y - yc;
			const float up = ENTRANCE_RH + std::max(ENTRANCE_OPEN - t, 0.0f) * 0.9f;
			const float vy = dy / (dy > 0.0f ? up : ENTRANCE_RH);
			const float vx = side / ENTRANCE_RW;
			const float va = (along - t) / ENTRANCE_RW;
			best = std::max(best, (1.0f - std::sqrt(vx * vx + vy * vy + va * va)) * ENTRANCE_RW / GRID);
		}
		// Salão no fim (um pouco achatado).
		const float cx = x - (e.x + e.dx * ENTRANCE_LEN);
		const float cz = z - (e.z + e.dz * ENTRANCE_LEN);
		const float cy = (y - (h - (1.4f + ENTRANCE_LEN * ENTRANCE_SLOPE))) * 1.4f;
		best = std::max(best, (ENTRANCE_ROOM - std::sqrt(cx * cx + cy * cy + cz * cz)) / GRID);
	}
	return best;
}

// Minério a partir dos ruídos já calculados (grade grossa interpolada).
static uint8_t ore_from(float blob, float vein, float kind, float depth, float amount) {
	if (amount <= 0.0f || depth < 2.0f) {
		return STONE;
	}
	// Bolsões (2 a 3 m) e fios finos que serpenteiam pela pedra; mais fundo, um pouco mais.
	const float rare = 0.02f * amount + 0.03f * smoothstep(10.0f, 50.0f, depth);
	if (blob < 0.66f - rare && std::abs(vein) > 0.009f * amount) {
		return STONE;
	}
	// Que minério: região (ruído largo) e profundidade.
	const float k = (kind + 1.0f) * 0.5f;
	if (depth < 18.0f) {
		return k < 0.6f ? COAL : IRON;
	}
	if (depth < 38.0f) {
		return k < 0.35f ? COAL : (k < 0.7f ? IRON : COPPER);
	}
	return k < 0.3f ? IRON : (k < 0.55f ? COPPER : (k < 0.8f ? TIN : SULFUR));
}

uint8_t Generator::ore_at(float x, float y, float z, float depth) const {
	return ore_from(ore_shape.noise(x / 4.5f, y / 4.0f, z / 4.5f), ore_shape.noise(x / 13.0f + 31.7f, y / 7.0f, z / 13.0f),
			ore_kind.noise(x / 70.0f, y / 40.0f, z / 70.0f), depth, params.ore_amount);
}

void Generator::fill(Section &out, int sx, int sy, int sz, const Columns &cols) const {
	// Ruídos de caverna e minério numa grade grossa (a cada 2 blocos, 10^3 pontos) e
	// interpolados: 6x menos chamadas de ruído, e as formas têm metros de tamanho mesmo.
	constexpr int G = P / 2 + 1; // 10
	static thread_local float cave[G * G * G], blob[G * G * G], vein[G * G * G], kind[G * G * G];
	const float top = (float(sy * N + P - 1) + 0.5f) * GRID;
	const float bottom_y = (float(sy * N - 1) + 0.5f) * GRID;
	float h_min = 1e9f, h_max = -1e9f;
	for (int c = 0; c < P * P; c++) {
		h_min = std::min(h_min, cols.height[c]);
		h_max = std::max(h_max, cols.height[c]);
	}
	const bool underground = bottom_y < h_max + 1.0f && top > BOTTOM; // tem algo abaixo do chão
	// Entradas de caverna que podem tocar esta seção (quase sempre nenhuma).
	const Entrance *near[8];
	int n_near = 0;
	if (underground && params.cave_amount > 0.0f) {
		const float x0 = float(sx * N - 1) * GRID, x1 = float(sx * N + P - 1) * GRID;
		const float z0 = float(sz * N - 1) * GRID, z1 = float(sz * N + P - 1) * GRID;
		const float m = ENTRANCE_ROOM + 2.0f;
		for (const Entrance &e : entrances) {
			const float ex = e.x + e.dx * ENTRANCE_LEN, ez = e.z + e.dz * ENTRANCE_LEN;
			if (std::max(e.x, ex) + m < x0 || std::min(e.x, ex) - m > x1 || std::max(e.z, ez) + m < z0 || std::min(e.z, ez) - m > z1) {
				continue;
			}
			if (n_near < 8) {
				near[n_near++] = &e;
			}
		}
	}
	if (underground) {
		for (int gy = 0; gy < G; gy++) {
			const float y = (float(sy * N + gy * 2 - 1) + 0.5f) * GRID;
			for (int gz = 0; gz < G; gz++) {
				const float z = (float(sz * N + gz * 2 - 1) + 0.5f) * GRID;
				for (int gx = 0; gx < G; gx++) {
					const float x = (float(sx * N + gx * 2 - 1) + 0.5f) * GRID;
					const int col = std::min(gz * 2, P - 1) * P + std::min(gx * 2, P - 1);
					const float depth = cols.height[col] - y;
					const int g = (gy * G + gz) * G + gx;
					const bool dry = depth > -2.0f && cols.height[col] > SEA_LEVEL + 1.5f;
					cave[g] = dry ? cave_field(x, y, z, depth) : -10.0f;
					if (dry && n_near > 0) {
						cave[g] = std::max(cave[g], entrance_field(near, n_near, x, y, z, cols.height[col]));
					}
					if (depth > 2.0f && params.ore_amount > 0.0f) {
						blob[g] = ore_shape.noise(x / 4.5f, y / 4.0f, z / 4.5f);
						vein[g] = ore_shape.noise(x / 13.0f + 31.7f, y / 7.0f, z / 13.0f);
						kind[g] = ore_kind.noise(x / 70.0f, y / 40.0f, z / 70.0f);
					} else {
						blob[g] = -1.0f;
						vein[g] = 1.0f;
						kind[g] = 0.0f;
					}
				}
			}
		}
	}
	auto lerp3 = [&](const float *a, int px, int py, int pz) {
		const int x0 = px >> 1, y0 = py >> 1, z0 = pz >> 1;
		const float fx = (px & 1) * 0.5f, fy = (py & 1) * 0.5f, fz = (pz & 1) * 0.5f;
		const int x1 = std::min(x0 + 1, G - 1), y1 = std::min(y0 + 1, G - 1), z1 = std::min(z0 + 1, G - 1);
		auto at = [&](int x, int y, int z) { return a[(y * G + z) * G + x]; };
		const float c00 = lerpf(at(x0, y0, z0), at(x1, y0, z0), fx), c10 = lerpf(at(x0, y1, z0), at(x1, y1, z0), fx);
		const float c01 = lerpf(at(x0, y0, z1), at(x1, y0, z1), fx), c11 = lerpf(at(x0, y1, z1), at(x1, y1, z1), fx);
		return lerpf(lerpf(c00, c10, fy), lerpf(c01, c11, fy), fz);
	};
	int solid = 0;
	for (int py = 0; py < P; py++) {
		const float y = (float(sy * N + py - 1) + 0.5f) * GRID;
		for (int pz = 0; pz < P; pz++) {
			for (int px = 0; px < P; px++) {
				const int col = pz * P + px;
				const int i = idx(px, py, pz);
				if (y < BOTTOM) {
					out.density[i] = 127;
					out.material[i] = BEDROCK;
					solid++;
					continue;
				}
				const float h = cols.height[col];
				const float depth = h - y; // metros abaixo do chão natural
				float d = depth / GRID; // em blocos: a superfície passa onde d = 0
				if (underground && d > -2.0f) {
					d = std::min(d, -lerp3(cave, px, py, pz));
				}
				d = std::clamp(d, -1.0f, 1.0f);
				const int8_t q = int8_t(std::lround(d * 127.0f));
				out.density[i] = q;
				if (q <= 0) {
					out.material[i] = AIR;
					continue;
				}
				solid++;
				const uint8_t soil = cols.soil ? cols.soil[col] : 0;
				if (depth < 1.0f) {
					out.material[i] = TOPSOIL;
				} else if (depth < 3.2f) {
					out.material[i] = soil == 1 ? SAND : (soil == 2 ? STONE : DIRT);
				} else {
					out.material[i] = ore_from(lerp3(blob, px, py, pz), lerp3(vein, px, py, pz), kind[((py >> 1) * G + (pz >> 1)) * G + (px >> 1)],
							depth, params.ore_amount);
				}
			}
		}
	}
	out.solid_count = solid;
}

// --- Malha (Surface Nets) ------------------------------------------------------------------

Palette::Palette() {
	auto set = [this](int m, float r, float g, float b) {
		material[m][0] = r;
		material[m][1] = g;
		material[m][2] = b;
		material[m][3] = 1.0f;
	};
	for (int m = 0; m < 32; m++) {
		set(m, 0.5f, 0.5f, 0.5f);
	}
	set(TOPSOIL, 0.32f, 0.42f, 0.2f);
	set(DIRT, 0.4f, 0.29f, 0.19f);
	set(SAND, 0.76f, 0.65f, 0.45f);
	set(STONE, 0.45f, 0.44f, 0.42f);
	set(BEDROCK, 0.18f, 0.17f, 0.17f);
	set(COAL, 0.13f, 0.12f, 0.12f);
	set(IRON, 0.6f, 0.38f, 0.28f);
	set(COPPER, 0.3f, 0.55f, 0.48f);
	set(TIN, 0.72f, 0.73f, 0.76f);
	set(SULFUR, 0.86f, 0.78f, 0.22f);
	set(GRAVEL, 0.52f, 0.5f, 0.47f);
	set(BUILT_DIRT, 0.43f, 0.31f, 0.2f);
	set(BUILT_STONE, 0.5f, 0.49f, 0.46f);
	set(BUILT_SAND, 0.76f, 0.65f, 0.45f);
}

namespace {

constexpr int C = P - 1; // cubos por lado (17)

struct Vec3 {
	float x, y, z;
};
inline Vec3 sub(Vec3 a, Vec3 b) { return { a.x - b.x, a.y - b.y, a.z - b.z }; }
inline Vec3 cross(Vec3 a, Vec3 b) { return { a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x }; }
inline float dot(Vec3 a, Vec3 b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
inline float len2(Vec3 a) { return dot(a, a); }

// Os 8 cantos e as 12 arestas de um cubo.
const int CORNER[8][3] = { { 0, 0, 0 }, { 1, 0, 0 }, { 0, 1, 0 }, { 1, 1, 0 }, { 0, 0, 1 }, { 1, 0, 1 }, { 0, 1, 1 }, { 1, 1, 1 } };
const int EDGE[12][2] = { { 0, 1 }, { 2, 3 }, { 4, 5 }, { 6, 7 }, { 0, 2 }, { 1, 3 }, { 4, 6 }, { 5, 7 }, { 0, 4 }, { 1, 5 }, { 2, 6 }, { 3, 7 } };

inline Vec3 sample_pos(int px, int py, int pz) {
	// Centro do bloco, relativo à origem da seção (bloco 0 começa em 0).
	return { (float(px) - 0.5f) * GRID, (float(py) - 0.5f) * GRID, (float(pz) - 0.5f) * GRID };
}

} // namespace

void mesh(const Section &s, const Palette &pal, MeshOut &out) {
	out.pos.clear();
	out.nrm.clear();
	out.col.clear();
	if (s.solid_count == 0 || s.solid_count == P3) {
		return; // tudo ar ou tudo cheio: sem superfície
	}
	// 1) Um vértice por cubo cortado: média dos pontos onde a superfície cruza as arestas.
	std::vector<int> cell_vertex(C * C * C, -1);
	std::vector<Vec3> verts;
	verts.reserve(2048);
	for (int cy = 0; cy < C; cy++) {
		for (int cz = 0; cz < C; cz++) {
			for (int cx = 0; cx < C; cx++) {
				float d[8];
				int mask = 0;
				for (int k = 0; k < 8; k++) {
					d[k] = float(s.density[idx(cx + CORNER[k][0], cy + CORNER[k][1], cz + CORNER[k][2])]);
					if (d[k] > 0.0f) {
						mask |= 1 << k;
					}
				}
				if (mask == 0 || mask == 255) {
					continue;
				}
				Vec3 sum = { 0, 0, 0 };
				int n = 0;
				for (int e = 0; e < 12; e++) {
					const int a = EDGE[e][0], b = EDGE[e][1];
					if (((mask >> a) & 1) == ((mask >> b) & 1)) {
						continue;
					}
					const float t = d[a] / (d[a] - d[b]);
					const Vec3 pa = sample_pos(cx + CORNER[a][0], cy + CORNER[a][1], cz + CORNER[a][2]);
					const Vec3 pb = sample_pos(cx + CORNER[b][0], cy + CORNER[b][1], cz + CORNER[b][2]);
					sum.x += pa.x + (pb.x - pa.x) * t;
					sum.y += pa.y + (pb.y - pa.y) * t;
					sum.z += pa.z + (pb.z - pa.z) * t;
					n++;
				}
				cell_vertex[(cy * C + cz) * C + cx] = int(verts.size());
				verts.push_back({ sum.x / n, sum.y / n, sum.z / n });
			}
		}
	}
	// 2) Um quadrado por aresta cheio/vazio que a seção possui (bloco de baixo em 1..N).
	auto cell = [&](int x, int y, int z) { return cell_vertex[(y * C + z) * C + x]; };
	auto emit = [&](Vec3 a, Vec3 b, Vec3 c, Vec3 outward, const float *color) {
		Vec3 n = cross(sub(c, a), sub(b, a)); // frente do Godot: sentido horário visto de fora
		if (dot(n, outward) < 0.0f) {
			std::swap(b, c);
			n = { -n.x, -n.y, -n.z };
		}
		const float l2 = len2(n);
		if (l2 < 1e-12f) {
			return; // triângulo degenerado
		}
		const float inv = 1.0f / std::sqrt(l2);
		n = { n.x * inv, n.y * inv, n.z * inv };
		for (const Vec3 &p : { a, b, c }) {
			out.pos.insert(out.pos.end(), { p.x, p.y, p.z });
			out.nrm.insert(out.nrm.end(), { n.x, n.y, n.z });
			out.col.insert(out.col.end(), { color[0], color[1], color[2], color[3] });
		}
	};
	for (int y = 1; y <= N; y++) {
		for (int z = 1; z <= N; z++) {
			for (int x = 1; x <= N; x++) {
				const int i0 = idx(x, y, z);
				const bool solid0 = s.density[i0] > 0;
				for (int axis = 0; axis < 3; axis++) {
					const int nx = x + (axis == 0), ny = y + (axis == 1), nz = z + (axis == 2);
					const int i1 = idx(nx, ny, nz);
					const bool solid1 = s.density[i1] > 0;
					if (solid0 == solid1) {
						continue;
					}
					// Os 4 cubos em volta da aresta (eixos u e v perpendiculares a ela).
					int q[4];
					if (axis == 0) {
						q[0] = cell(x, y - 1, z - 1);
						q[1] = cell(x, y, z - 1);
						q[2] = cell(x, y, z);
						q[3] = cell(x, y - 1, z);
					} else if (axis == 1) {
						q[0] = cell(x - 1, y, z - 1);
						q[1] = cell(x, y, z - 1);
						q[2] = cell(x, y, z);
						q[3] = cell(x - 1, y, z);
					} else {
						q[0] = cell(x - 1, y - 1, z);
						q[1] = cell(x, y - 1, z);
						q[2] = cell(x, y, z);
						q[3] = cell(x - 1, y, z);
					}
					if (q[0] < 0 || q[1] < 0 || q[2] < 0 || q[3] < 0) {
						continue;
					}
					const Vec3 outward = { float(axis == 0) * (solid0 ? 1.0f : -1.0f), float(axis == 1) * (solid0 ? 1.0f : -1.0f),
						float(axis == 2) * (solid0 ? 1.0f : -1.0f) };
					// Cor: o bloco cheio da aresta (chão natural usa a cor da coluna).
					const int si = solid0 ? i0 : i1;
					const int sxp = solid0 ? x : nx, szp = solid0 ? z : nz;
					const uint8_t m = s.material[si];
					float color[4];
					const float *base = (m == TOPSOIL && pal.column) ? &pal.column[(szp * P + sxp) * 4] : pal.material[m & 31];
					color[0] = base[0];
					color[1] = base[1];
					color[2] = base[2];
					color[3] = 1.0f;
					const Vec3 a = verts[q[0]], b = verts[q[1]], c = verts[q[2]], d = verts[q[3]];
					// Diagonal mais curta: menos triângulo comprido.
					if (len2(sub(a, c)) <= len2(sub(b, d))) {
						emit(a, b, c, outward, color);
						emit(a, c, d, outward, color);
					} else {
						emit(a, b, d, outward, color);
						emit(b, c, d, outward, color);
					}
				}
			}
		}
	}
	// Face muito inclinada (barranco, parede de caverna): puxa um pouco para a cor de rocha.
	const float *rock = pal.material[STONE];
	for (size_t t = 0; t < out.nrm.size(); t += 3) {
		const float ny = out.nrm[t + 1];
		if (ny < 0.55f) {
			const size_t c = t / 3 * 4;
			const float k = std::clamp((0.55f - ny) * 2.2f, 0.0f, 0.85f);
			for (int ch = 0; ch < 3; ch++) {
				out.col[c + ch] = out.col[c + ch] + (rock[ch] - out.col[c + ch]) * k * 0.6f;
			}
		}
	}
}

} // namespace apio
