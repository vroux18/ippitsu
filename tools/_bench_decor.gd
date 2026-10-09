extends SceneTree
## Banc jetable : coût de Worlds.build_props (décor d'une salle) avec la fusion par copie CPU
## (Decor._cpu_ok = 1) et sans (0), en alternance dans le même processus (même charge machine).
## `godot [--headless] --path . -s tools/_bench_decor.gd`

func _init() -> void:
	var W := load("res://scripts/worlds.gd")
	var D := load("res://scripts/decor.gd")
	var root := Node3D.new()
	get_root().add_child(root)
	var rects := [Rect2(-4.6, -8.6, 9.2, 17.2)]
	var tot := {0: 0.0, 1: 0.0}
	var n := 0
	for rep in 2:
		for wid in [1, 3, 4, 7]:
			for s in 3:
				for mode in [0, 1]:
					D._cpu_ok = mode
					var holder := Node3D.new()
					root.add_child(holder)
					var t0 := Time.get_ticks_usec()
					W.build_props(wid, holder, rects, 100 + s, Rect2(), 1, [])
					var dt := (Time.get_ticks_usec() - t0) / 1000.0
					tot[mode] += dt
					holder.free()
				n += 1
	print("BENCH décor : %d salles, append_from direct %.1f ms/salle, copie CPU %.1f ms/salle" % [n, tot[0] / n, tot[1] / n])
	# primitives : cache contre création
	var t1 := Time.get_ticks_usec()
	for i in 3000:
		var m := BoxMesh.new()
		m.size = Vector3(0.3, 0.2, 0.1)
		var c := CylinderMesh.new()
		c.top_radius = 0.2
		c.bottom_radius = 0.2
		c.height = 1.0
	var a := (Time.get_ticks_usec() - t1) / 1000.0
	var T := load("res://scripts/toon.gd")
	t1 = Time.get_ticks_usec()
	for i in 3000:
		T.box(Vector3(0.3, 0.2, 0.1))
		T.cyl(0.2, 0.2, 1.0)
	var b := (Time.get_ticks_usec() - t1) / 1000.0
	t1 = Time.get_ticks_usec()
	for i in 3000:
		T.mat(Color.RED)
	var c2 := (Time.get_ticks_usec() - t1) / 1000.0
	t1 = Time.get_ticks_usec()
	for i in 3000:
		T.mat_shared(Color.RED)
	var d2 := (Time.get_ticks_usec() - t1) / 1000.0
	print("BENCH primitives : 3000 boîtes+cylindres neufs %.1f ms, en cache %.1f ms ; 3000 mat() %.1f ms, mat_shared() %.1f ms" % [a, b, c2, d2])
	quit()
