extends SceneTree
## Test jetable : SurfaceTool.append_from accepte-t-il un Mesh écrit en script (Decor.CpuMesh) ?

func _init() -> void:
	var Decor := load("res://scripts/decor.gd")
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 2, 3)
	var c = Decor._cpu_of(bm, 0)
	print("cpu arrays: ", c.arrays.size(), " verts=", c._surface_get_array_len(0), " fmt=", c.fmt, " prim=", c.prim)
	print("surface_count via Mesh API: ", c.get_surface_count(), " arrays via API: ", c.surface_get_arrays(0).size())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(c, 0, Transform3D(Basis(), Vector3(1, 0, 0)))
	var out := st.commit()
	print("append_from(CpuMesh): surfaces=", out.get_surface_count(), " verts=", (out.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() if out.get_surface_count() > 0 else -1))
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	st2.append_from(bm, 0, Transform3D(Basis(), Vector3(1, 0, 0)))
	var out2 := st2.commit()
	print("append_from(BoxMesh): verts=", out2.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
	# même géométrie ?
	if out.get_surface_count() > 0:
		var a: PackedVector3Array = out.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var b: PackedVector3Array = out2.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var ia = out.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		var ib = out2.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		print("same verts: ", a == b, " idx: ", (ia.size() if ia else -1), "/", (ib.size() if ib else -1))
		# mesure : 2000 fusions
		var t0 := Time.get_ticks_usec()
		var s3 := SurfaceTool.new()
		s3.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 2000:
			s3.append_from(c, 0, Transform3D(Basis(), Vector3(i, 0, 0)))
		print("2000x cpu: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
		t0 = Time.get_ticks_usec()
		var s4 := SurfaceTool.new()
		s4.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 2000:
			s4.append_from(bm, 0, Transform3D(Basis(), Vector3(i, 0, 0)))
		print("2000x gpu: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	quit()
