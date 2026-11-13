// Ligação do núcleo de voxels (voxel_core) com o Godot: classe ApioVoxel usada pelo
// GDScript (scripts/world/voxel_world.gd). Os métodos são seguros para chamar em várias
// threads ao mesmo tempo (o gerador só lê).
#pragma once

#include "voxel_core.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector3i.hpp>

#include <memory>

namespace godot {

class ApioVoxel : public RefCounted {
	GDCLASS(ApioVoxel, RefCounted)

	std::unique_ptr<apio::Generator> generator;

protected:
	static void _bind_methods();

public:
	ApioVoxel();

	// Semente e quantidades do menu "Criar mundo" (cavernas e minério, 0..2).
	void setup(int seed, float cave_amount, float ore_amount);
	// Dados da seção (18^3 densidades + 18^3 materiais + 4 bytes com a contagem de cheios).
	// heights e soil: 18 x 18 colunas (índice z * 18 + x), centro de cada bloco.
	PackedByteArray fill(const Vector3i &section, const PackedFloat32Array &heights, const PackedByteArray &soil) const;
	// [PackedVector3Array vértices, PackedVector3Array normais, PackedColorArray cores]
	// relativos à origem da seção; column_colors: cor do chão natural de cada coluna (18 x 18).
	Array build_mesh(const PackedByteArray &data, const PackedColorArray &column_colors) const;
	int solid_count(const PackedByteArray &data) const;
	int padded() const { return apio::P; }
	int size() const { return apio::N; }
	double grid() const { return apio::GRID; }
};

} // namespace godot
