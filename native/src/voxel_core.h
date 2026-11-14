// Núcleo do terreno em voxels do APIO (C++ puro, sem Godot: dá para compilar e medir
// sozinho; a ligação com o Godot fica em apio_voxel.cpp).
//
// Bloco = cubo de 0,4 m (o quadradinho da parede). Seção = 16x16x16 blocos (6,4 m).
// Cada bloco guarda densidade (int8: >0 cheio, <=0 ar; o valor diz onde a superfície
// passa entre dois blocos, então o chão fica em rampas, não em degraus) e material.
// A malha é Surface Nets: um vértice por cubo que a superfície corta e um quadrado por
// aresta cheio/vazio, faces retas (visual PS2 facetado).
//
// Os dados de uma seção vêm com 1 bloco de borda de cada lado (18^3) para a malha
// emendar com as seções vizinhas sem buraco.
#pragma once

#include <cstdint>
#include <vector>

namespace apio {

constexpr int N = 16; // blocos por lado da seção
constexpr int P = N + 2; // com a borda
constexpr int P3 = P * P * P;
constexpr float GRID = 0.4f; // metros por bloco
constexpr float SEA_LEVEL = -1.0f;
constexpr float BOTTOM = -61.0f; // fundo do mundo: 60 m abaixo do nível do mar (rocha-mãe)

enum Material : uint8_t {
	AIR = 0,
	TOPSOIL = 1, // chão natural da superfície (cor da coluna: grama, areia, neve...)
	DIRT = 2,
	SAND = 3,
	STONE = 4,
	BEDROCK = 5, // não quebra
	COAL = 6,
	IRON = 7,
	COPPER = 8,
	TIN = 9,
	SULFUR = 10,
	GRAVEL = 11,
	BUILT_DIRT = 16, // >= 16: posto pelo jogador (construção: zumbi quebra)
	BUILT_STONE = 17,
	BUILT_SAND = 18,
	BUILT_WOOD = 19, // tábuas postas (parede livre de madeira)
	// Jazidas (infinitas): no salão do fim de algumas entradas de caverna. A picareta tira
	// minério sem acabar; a perfuratriz em cima tira sozinha.
	DEPOSIT_COAL = 20,
	DEPOSIT_IRON = 21,
	DEPOSIT_COPPER = 22,
	DEPOSIT_TIN = 23,
	DEPOSIT_SULFUR = 24,
};

inline bool is_built(uint8_t m) { return m >= BUILT_DIRT && m < DEPOSIT_COAL; }
inline bool is_deposit(uint8_t m) { return m >= DEPOSIT_COAL && m <= DEPOSIT_SULFUR; }

inline int idx(int x, int y, int z) { return (y * P + z) * P + x; }

struct Section {
	int8_t density[P3];
	uint8_t material[P3];
	int solid_count = 0; // blocos cheios (P3 = tudo pedra, 0 = tudo ar)
};

// Ruído gradiente 3D (Perlin melhorado) com semente.
class Noise3 {
public:
	explicit Noise3(uint32_t seed = 0);
	float noise(float x, float y, float z) const; // -1..1
	float fbm(float x, float y, float z, int octaves) const;

private:
	uint8_t perm[512];
};

// Entrada de caverna: rampa aberta que desce da superfície (x, z) na direção (dx, dz),
// vira túnel e termina num salão. A lista vem do jogo (TerrainWorld.cave_entrances), que
// escolhe lugares fora do mar, lagos, rios e cidades. Medidas (iguais em voxel_ref.gd):
constexpr float ENTRANCE_LEN = 30.0f; // metros na horizontal até o salão
constexpr float ENTRANCE_SLOPE = 0.5f; // desce 0,5 m por metro
constexpr float ENTRANCE_RW = 1.7f; // meia largura do túnel
constexpr float ENTRANCE_RH = 1.4f; // meia altura do túnel
constexpr float ENTRANCE_OPEN = 7.0f; // primeiros metros: vala aberta em cima (a boca)
constexpr float ENTRANCE_ROOM = 4.5f; // raio do salão no fim
constexpr float DEPOSIT_R = 2.6f; // jazida: bola na parede do salão, além do centro dele
constexpr float DEPOSIT_AHEAD = 3.8f;
constexpr float DEPOSIT_DROP = 2.6f; // abaixo do centro do salão: vira o chão e o pé da parede
struct Entrance {
	float x, z, dx, dz;
	int kind; // 0 = sem jazida; 1..5 = carvão, ferro, cobre, estanho, enxofre
};

struct GenParams {
	int seed = 1337;
	float cave_amount = 1.0f; // 0 = sem cavernas
	float ore_amount = 1.0f;
};

// Por coluna (P x P, índice z * P + x): altura natural do chão no centro da coluna e o tipo
// de solo (0 terra, 1 areia, 2 rocha/encosta).
struct Columns {
	const float *height = nullptr;
	const uint8_t *soil = nullptr;
};

class Generator {
public:
	explicit Generator(const GenParams &p);
	// Enche a seção (sx, sy, sz) (em seções) a partir das alturas das colunas: chão,
	// cavernas (túneis e salões), veios de minério e rocha-mãe no fundo.
	void fill(Section &out, int sx, int sy, int sz, const Columns &cols) const;
	// Entradas da ilha (chamar antes de gerar; depois só leitura, seguro em várias threads).
	void set_entrances(const std::vector<Entrance> &list) { entrances = list; }
	// > 0 = dentro de alguma entrada (ar), em blocos; h = chão natural da coluna.
	static float entrance_field(const Entrance *const *list, int n, float x, float y, float z, float h);
	// Material de jazida no ponto (0 = nenhuma).
	static uint8_t deposit_at(const Entrance *const *list, int n, float x, float y, float z, float h);
	// Densidade natural de um ponto (útil para testes e para saber se há caverna).
	float cave_field(float x, float y, float z, float depth) const;

private:
	GenParams params;
	Noise3 tunnel_a, tunnel_b, cavern, entrance, ore_shape, ore_kind;
	std::vector<Entrance> entrances;
	uint8_t ore_at(float x, float y, float z, float depth) const;
};

struct MeshOut {
	std::vector<float> pos; // xyz por vértice (relativo à origem da seção)
	std::vector<float> nrm;
	std::vector<float> col; // rgba
	int triangles() const { return int(pos.size() / 9); }
};

// Cores: por material (rgba) e, para TOPSOIL, a cor de cada coluna (P x P x 4).
struct Palette {
	float material[32][4];
	const float *column = nullptr;
	Palette();
};

// Malha (Surface Nets) da seção: só as arestas da própria seção (a borda serve para
// emendar). Triângulos soltos, normal reta por triângulo, cor do bloco cheio.
void mesh(const Section &s, const Palette &pal, MeshOut &out);

} // namespace apio
