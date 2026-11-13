extends SceneTree
## Confere a versão GDScript (VoxelRef) contra o C++ (native/test/bench.cpp dump ARQ):
## mesmas densidades, materiais e malha para as mesmas alturas; e mede o GDScript.
##   VOXEL_DUMP=arquivo godot --headless --path . --script tests/test_voxel_ref.gd

func _init() -> void:
	var path := OS.get_environment("VOXEL_DUMP")
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("sem arquivo do C++ (VOXEL_DUMP)")
		quit()
		return
	var ref := VoxelRef.new()
	ref.setup(1337, 1.0, 1.0)
	var P := VoxelRef.P
	var count := f.get_32()
	var fill_ms := 0.0
	var mesh_ms := 0.0
	for k in count:
		var id := Vector3i(f.get_32(), f.get_32(), f.get_32())
		id = Vector3i(id.x - (1 << 32) if id.x >= 1 << 31 else id.x, id.y - (1 << 32) if id.y >= 1 << 31 else id.y, id.z - (1 << 32) if id.z >= 1 << 31 else id.z)
		var heights := PackedFloat32Array()
		heights.resize(P * P)
		for i in P * P:
			heights[i] = f.get_float()
		var soil := f.get_buffer(P * P)
		var dens := f.get_buffer(VoxelRef.P3)
		var mats := f.get_buffer(VoxelRef.P3)
		var solid := f.get_32()
		var tris := f.get_32()
		var t0 := Time.get_ticks_usec()
		var data := ref.fill(id, heights, soil)
		var t1 := Time.get_ticks_usec()
		var mesh := ref.build_mesh(data, PackedColorArray())
		var t2 := Time.get_ticks_usec()
		fill_ms += (t1 - t0) / 1000.0
		mesh_ms += (t2 - t1) / 1000.0
		var diff_sign := 0
		var diff_big := 0
		var diff_mat := 0
		for i in VoxelRef.P3:
			var a := VoxelRef.density(data, i)
			var b: int = dens[i] - 256 if dens[i] > 127 else dens[i]
			if (a > 0) != (b > 0):
				diff_sign += 1
			if absi(a - b) > 1:
				diff_big += 1
			if data[VoxelRef.P3 + i] != mats[i]:
				diff_mat += 1
		print("seção %s: cheios C++ %d / GDScript %d; blocos com sinal diferente %d, densidade diferente (>1) %d, material diferente %d; triângulos C++ %d / GDScript %d" % [
			id, solid, VoxelRef.solid_count(data), diff_sign, diff_big, diff_mat, tris, (mesh[0] as PackedVector3Array).size() / 3])
	print("GDScript: encher %.1f ms por seção, malha %.1f ms por seção" % [fill_ms / count, mesh_ms / count])
	quit()
