// Mede o núcleo do terreno em voxels sem o Godot:
//   g++ -O2 -std=c++17 -Inative/src native/src/voxel_core.cpp native/test/bench.cpp -o bench && ./bench
// Gera um pedaço de 64 x 64 m (10 x 10 colunas de seções) do fundo (-61 m) até acima
// do morro, conta seções vazias/cheias/com superfície, triângulos, tempo e memória, e
// confere se a malha fecha entre seções vizinhas.
#include "voxel_core.h"

#include <chrono>
#include <cmath>
#include <cstdio>
#include <algorithm>
#include <map>
#include <string>
#include <tuple>

using namespace apio;

static float height(float x, float z) {
	return 8.0f + 7.0f * std::sin(x * 0.045f) * std::cos(z * 0.06f) + 3.0f * std::sin(z * 0.11f + 1.0f);
}

// Grava seções para tests/test_voxel_ref.gd comparar com a versão GDScript:
// [int32 quantidade] e, para cada uma: int32 sx, sy, sz; P*P float alturas; P*P bytes solo;
// dados (P3 densidades, P3 materiais, int32 cheios); int32 triângulos da malha.
static int dump(const char *path) {
	GenParams params;
	Generator gen(params);
	Palette pal;
	const int list[][3] = { { 3, -1, 2 }, { 3, 1, 2 }, { 5, -4, 7 }, { 2, -8, 1 }, { 0, 0, 0 } };
	FILE *f = fopen(path, "wb");
	if (!f) {
		return 1;
	}
	const int32_t count = 5;
	fwrite(&count, 4, 1, f);
	for (const auto &sec_id : list) {
		float heights[P * P];
		uint8_t soil[P * P];
		for (int pz = 0; pz < P; pz++) {
			for (int px = 0; px < P; px++) {
				heights[pz * P + px] = height((sec_id[0] * N + px - 0.5f) * GRID, (sec_id[2] * N + pz - 0.5f) * GRID);
				soil[pz * P + px] = uint8_t((px + pz) % 3);
			}
		}
		Section sec;
		gen.fill(sec, sec_id[0], sec_id[1], sec_id[2], Columns{ heights, soil });
		MeshOut m;
		mesh(sec, pal, m);
		const int32_t ids[3] = { sec_id[0], sec_id[1], sec_id[2] };
		fwrite(ids, 4, 3, f);
		fwrite(heights, 4, P * P, f);
		fwrite(soil, 1, P * P, f);
		fwrite(sec.density, 1, P3, f);
		fwrite(sec.material, 1, P3, f);
		const int32_t solid = sec.solid_count, tris = m.triangles();
		fwrite(&solid, 4, 1, f);
		fwrite(&tris, 4, 1, f);
	}
	fclose(f);
	return 0;
}

int main(int argc, char **argv) {
	if (argc > 2 && std::string(argv[1]) == "dump") {
		return dump(argv[2]);
	}
	GenParams params;
	Generator gen(params);
	Palette pal;
	float heights[P * P];
	uint8_t soil[P * P] = {};
	Columns cols{ heights, soil };
	Section sec;
	MeshOut m;
	int empty = 0, full = 0, surface = 0, tris = 0, ore = 0, cave_tris = 0, solid_total = 0, under = 0, under_air = 0;
	double t_fill = 0, t_mesh = 0;
	const int y_min = int(std::floor(BOTTOM / (N * GRID))) - 1, y_max = 4;
	auto now = [] { return std::chrono::steady_clock::now(); };
	for (int sz = 0; sz < 10; sz++) {
		for (int sx = 0; sx < 10; sx++) {
			for (int pz = 0; pz < P; pz++) {
				for (int px = 0; px < P; px++) {
					heights[pz * P + px] = height((sx * N + px - 0.5f) * GRID, (sz * N + pz - 0.5f) * GRID);
				}
			}
			for (int sy = y_min; sy <= y_max; sy++) {
				auto t0 = now();
				gen.fill(sec, sx, sy, sz, cols);
				auto t1 = now();
				mesh(sec, pal, m);
				auto t2 = now();
				t_fill += std::chrono::duration<double, std::milli>(t1 - t0).count();
				t_mesh += std::chrono::duration<double, std::milli>(t2 - t1).count();
				if (sec.solid_count == 0) {
					empty++;
				} else if (sec.solid_count == P3) {
					full++;
				} else {
					surface++;
				}
				tris += m.triangles();
				// Seção toda abaixo do chão (3 m de folga): o que tem de triângulo é caverna.
				float h_min = 1e9f;
				for (int c = 0; c < P * P; c++) {
					h_min = std::min(h_min, heights[c]);
				}
				if ((sy * N + P) * GRID < h_min - 3.0f) {
					cave_tris += m.triangles();
				}
				for (int x = 1; x <= N; x++) {
					for (int y = 1; y <= N; y++) {
						for (int z = 1; z <= N; z++) {
							const uint8_t mm = sec.material[idx(x, y, z)];
							ore += mm >= COAL && mm <= SULFUR;
							solid_total += mm != AIR;
							const float yy = (sy * N + y - 0.5f) * GRID;
							if (yy < heights[z * P + x] - 4.0f && yy > BOTTOM) {
								under++;
								under_air += mm == AIR;
							}
						}
					}
				}
			}
		}
	}
	const int total = empty + full + surface;
	printf("seções: %d (vazias %d, cheias %d, com superfície %d)\n", total, empty, full, surface);
	printf("tempo: encher %.1f ms (%.3f ms/seção), malha %.1f ms (%.3f ms/seção com superfície)\n", t_fill, t_fill / total, t_mesh,
			t_mesh / std::max(surface, 1));
	printf("triângulos no pedaço de 64 m: %d (superfície %d, cavernas %d); minério: %d blocos (%.2f%% dos blocos cheios)\n", tris,
			tris - cave_tris, cave_tris, ore, 100.0 * ore / std::max(solid_total, 1));
	printf("subsolo (mais de 4 m abaixo do chão): %.1f%% é caverna\n", 100.0 * under_air / std::max(under, 1));
	printf("memória: seção cheia de dados %zu bytes; só as com superfície: %.1f MB por pedaço\n", sizeof(Section),
			surface * sizeof(Section) / 1048576.0);
	// Costura: a mesma aresta vista de duas seções vizinhas gera os mesmos vértices?
	// Gera duas seções lado a lado e confere os vértices na face comum.
	{
		for (int pz = 0; pz < P; pz++) {
			for (int px = 0; px < P; px++) {
				heights[pz * P + px] = height((px - 0.5f) * GRID, (pz - 0.5f) * GRID);
			}
		}
		Section a, b;
		gen.fill(a, 0, 1, 0, cols);
		float heights_b[P * P];
		for (int pz = 0; pz < P; pz++) {
			for (int px = 0; px < P; px++) {
				heights_b[pz * P + px] = height((N + px - 0.5f) * GRID, (pz - 0.5f) * GRID);
			}
		}
		Columns cols_b{ heights_b, soil };
		gen.fill(b, 1, 1, 0, cols_b);
		MeshOut ma, mb;
		mesh(a, pal, ma);
		mesh(b, pal, mb);
		std::map<std::tuple<int, int, int>, int> seam;
		const float edge = N * GRID;
		int on_a = 0, matched = 0;
		for (size_t i = 0; i < ma.pos.size(); i += 3) {
			if (std::abs(ma.pos[i] - edge) < 1e-4f) {
				seam[{ int(std::lround(ma.pos[i + 1] * 1000)), int(std::lround(ma.pos[i + 2] * 1000)), 0 }] = 1;
				on_a++;
			}
		}
		for (size_t i = 0; i < mb.pos.size(); i += 3) {
			if (std::abs(mb.pos[i]) < 1e-4f && seam.count({ int(std::lround(mb.pos[i + 1] * 1000)), int(std::lround(mb.pos[i + 2] * 1000)), 0 })) {
				matched++;
			}
		}
		printf("costura entre duas seções: %d vértices na face da 1a, %d batem na 2a\n", on_a, matched);
	}
	return 0;
}
