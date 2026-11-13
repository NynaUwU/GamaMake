#include "apio_voxel.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

#include <cstring>

using namespace godot;

namespace {
constexpr int DATA_SIZE = apio::P3 * 2 + 4;

// PackedByteArray <-> apio::Section (densidade, material, contagem de cheios no fim).
void unpack(const PackedByteArray &data, apio::Section &s) {
	if (data.size() < DATA_SIZE) {
		std::memset(&s, 0, sizeof(s));
		return;
	}
	const uint8_t *src = data.ptr();
	std::memcpy(s.density, src, apio::P3);
	std::memcpy(s.material, src + apio::P3, apio::P3);
	int32_t count = 0;
	std::memcpy(&count, src + apio::P3 * 2, 4);
	s.solid_count = count;
}
} // namespace

ApioVoxel::ApioVoxel() :
		generator(std::make_unique<apio::Generator>(apio::GenParams())) {}

void ApioVoxel::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "seed", "cave_amount", "ore_amount"), &ApioVoxel::setup);
	ClassDB::bind_method(D_METHOD("fill", "section", "heights", "soil"), &ApioVoxel::fill);
	ClassDB::bind_method(D_METHOD("build_mesh", "data", "column_colors"), &ApioVoxel::build_mesh);
	ClassDB::bind_method(D_METHOD("solid_count", "data"), &ApioVoxel::solid_count);
	ClassDB::bind_method(D_METHOD("padded"), &ApioVoxel::padded);
	ClassDB::bind_method(D_METHOD("size"), &ApioVoxel::size);
	ClassDB::bind_method(D_METHOD("grid"), &ApioVoxel::grid);
}

void ApioVoxel::setup(int seed, float cave_amount, float ore_amount) {
	apio::GenParams p;
	p.seed = seed;
	p.cave_amount = cave_amount;
	p.ore_amount = ore_amount;
	generator = std::make_unique<apio::Generator>(p);
}

PackedByteArray ApioVoxel::fill(const Vector3i &section, const PackedFloat32Array &heights, const PackedByteArray &soil) const {
	PackedByteArray out;
	if (heights.size() < apio::P * apio::P) {
		return out;
	}
	apio::Section s;
	apio::Columns cols{ heights.ptr(), soil.size() >= apio::P * apio::P ? soil.ptr() : nullptr };
	generator->fill(s, section.x, section.y, section.z, cols);
	out.resize(DATA_SIZE);
	uint8_t *dst = out.ptrw();
	std::memcpy(dst, s.density, apio::P3);
	std::memcpy(dst + apio::P3, s.material, apio::P3);
	const int32_t count = s.solid_count;
	std::memcpy(dst + apio::P3 * 2, &count, 4);
	return out;
}

Array ApioVoxel::build_mesh(const PackedByteArray &data, const PackedColorArray &column_colors) const {
	apio::Section s;
	unpack(data, s);
	apio::Palette pal;
	std::vector<float> columns;
	if (column_colors.size() >= apio::P * apio::P) {
		columns.resize(apio::P * apio::P * 4);
		for (int i = 0; i < apio::P * apio::P; i++) {
			const Color c = column_colors[i];
			columns[i * 4] = c.r;
			columns[i * 4 + 1] = c.g;
			columns[i * 4 + 2] = c.b;
			columns[i * 4 + 3] = 1.0f;
		}
		pal.column = columns.data();
	}
	apio::MeshOut m;
	apio::mesh(s, pal, m);
	const int count = int(m.pos.size() / 3);
	PackedVector3Array verts, normals;
	PackedColorArray colors;
	verts.resize(count);
	normals.resize(count);
	colors.resize(count);
	Vector3 *v = verts.ptrw();
	Vector3 *n = normals.ptrw();
	Color *c = colors.ptrw();
	for (int i = 0; i < count; i++) {
		v[i] = Vector3(m.pos[i * 3], m.pos[i * 3 + 1], m.pos[i * 3 + 2]);
		n[i] = Vector3(m.nrm[i * 3], m.nrm[i * 3 + 1], m.nrm[i * 3 + 2]);
		c[i] = Color(m.col[i * 4], m.col[i * 4 + 1], m.col[i * 4 + 2], m.col[i * 4 + 3]);
	}
	Array out;
	out.append(verts);
	out.append(normals);
	out.append(colors);
	return out;
}

int ApioVoxel::solid_count(const PackedByteArray &data) const {
	if (data.size() < DATA_SIZE) {
		return 0;
	}
	int32_t count = 0;
	std::memcpy(&count, data.ptr() + apio::P3 * 2, 4);
	return count;
}
