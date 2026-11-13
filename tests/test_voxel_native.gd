extends SceneTree
## A extensão C++ (ApioVoxel) carrega e dá o mesmo resultado que a versão GDScript
## (VoxelRef) bloco a bloco; mede as duas dentro do Godot.

func _init() -> void:
	print("ApioVoxel existe: %s" % ClassDB.class_exists("ApioVoxel"))
	if not ClassDB.class_exists("ApioVoxel"):
		quit()
		return
	var native: Object = ClassDB.instantiate("ApioVoxel")
	native.setup(1337, 1.0, 1.0)
	var ref := VoxelRef.new()
	ref.setup(1337, 1.0, 1.0)
	var P := VoxelRef.P
	var total_diff := 0
	var native_ms := 0.0
	var ref_ms := 0.0
	var tris := [0, 0]
	for sec in [Vector3i(3, -1, 2), Vector3i(3, 1, 2), Vector3i(-7, -6, 11), Vector3i(2, -9, 1), Vector3i(0, 0, 0), Vector3i(12, 3, -4)]:
		var heights := PackedFloat32Array()
		heights.resize(P * P)
		var soil := PackedByteArray()
		soil.resize(P * P)
		var colors := PackedColorArray()
		colors.resize(P * P)
		for pz in P:
			for px in P:
				var x: float = (sec.x * 16 + px - 0.5) * 0.4
				var z: float = (sec.z * 16 + pz - 0.5) * 0.4
				heights[pz * P + px] = 8.0 + 7.0 * sin(x * 0.045) * cos(z * 0.06) + 3.0 * sin(z * 0.11 + 1.0)
				soil[pz * P + px] = (px + pz) % 3
				colors[pz * P + px] = Color(0.3, 0.4, 0.2)
		var t0 := Time.get_ticks_usec()
		var a: PackedByteArray = native.fill(sec, heights, soil)
		var ma: Array = native.build_mesh(a, colors)
		var t1 := Time.get_ticks_usec()
		var b := ref.fill(sec, heights, soil)
		var mb := ref.build_mesh(b, colors)
		var t2 := Time.get_ticks_usec()
		native_ms += (t1 - t0) / 1000.0
		ref_ms += (t2 - t1) / 1000.0
		var diff := 0
		for i in VoxelRef.P3:
			if (VoxelRef.density(a, i) > 0) != (VoxelRef.density(b, i) > 0) or a[VoxelRef.P3 + i] != b[VoxelRef.P3 + i]:
				diff += 1
		total_diff += diff
		tris[0] += (ma[0] as PackedVector3Array).size() / 3
		tris[1] += (mb[0] as PackedVector3Array).size() / 3
		print("seção %s: cheios C++ %d / GDScript %d, blocos diferentes %d, triângulos %d / %d" % [sec, native.solid_count(a), VoxelRef.solid_count(b), diff,
			(ma[0] as PackedVector3Array).size() / 3, (mb[0] as PackedVector3Array).size() / 3])
	print("total: blocos diferentes %d, triângulos C++ %d / GDScript %d" % [total_diff, tris[0], tris[1]])
	print("tempo (encher + malha, 6 seções): C++ %.1f ms, GDScript %.1f ms (%.0fx)" % [native_ms, ref_ms, ref_ms / maxf(native_ms, 0.001)])
	quit()
