extends SceneTree
## Banc jetable : construction étalée des étapes, sanctuaires et arènes (arena.gd, `sliced`) : temps de
## calcul total, plus longue tranche, nombre d'images, et les plus gros morceaux entre deux découpes
## (avec l'endroit du code d'où part la découpe suivante).
## `godot --headless --path . -s tools/_bench_stage.gd`

const ArenaScript = preload("res://scripts/arena.gd")
const Worlds = preload("res://scripts/worlds.gd")


class Probe extends ArenaScript:
	var last := 0
	var units: Array = []  # [µs, endroit]
	var cats := {}  # fonction d'arena.gd -> µs

	var acc := {}

	func _chunk_props(job: Dictionary, holder: Node3D, dz: float, seed_i: int) -> void:
		var t := Time.get_ticks_usec()
		await super(job, holder, dz, seed_i)
		acc["props"] = int(acc.get("props", 0)) + Time.get_ticks_usec() - t

	func _chunk_pits(job: Dictionary, holder: Node3D, dz: float, seed_i: int) -> void:
		var t := Time.get_ticks_usec()
		await super(job, holder, dz, seed_i)
		acc["pits"] = int(acc.get("pits", 0)) + Time.get_ticks_usec() - t

	func _build_floor(w: Dictionary, rng: RandomNumberGenerator) -> void:
		var t := Time.get_ticks_usec()
		await super(w, rng)
		acc["floor"] = int(acc.get("floor", 0)) + Time.get_ticks_usec() - t

	func _next_frame() -> void:
		await super._next_frame()
		last = Time.get_ticks_usec()

	func _cut() -> void:
		var now := Time.get_ticks_usec()
		if last != 0:
			var st := get_stack()
			var where := ""
			for f in st.slice(1):
				if String(f["function"]) in ["_cut", "slice"]:
					continue
				where = "%s:%d %s" % [String(f["source"]).get_file(), int(f["line"]), String(f["function"])]
				break
			var cat := ""
			for f in st.slice(1):
				if String(f["source"]).ends_with("arena.gd") and not String(f["function"]) in ["_cut", "slice"]:
					cat = String(f["function"])
					break
			cats[cat] = int(cats.get(cat, 0)) + now - last
			units.append([now - last, where])
		await super._cut()
		last = Time.get_ticks_usec()


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := Probe.new()
	get_root().add_child(a)
	await process_frame
	var big := {}  # endroit -> max µs
	if "--sync" in OS.get_cmdline_user_args():
		for wid in range(1, Worlds.WORLDS.size() + 1):
			a.set_world(wid)
			for rep in 3:
				a.acc.clear()
				var t0 := Time.get_ticks_usec()
				a.build_stage(4, 91 + wid * 7 + rep, rep == 0, false)
				var tot := Time.get_ticks_usec() - t0
				while not a._pending.is_empty():
					a._build_chunk_decor(a._pending.pop_front())
				var tot2 := Time.get_ticks_usec() - t0
				print("BENCH sync m%d étape %d : build %.1f ms, tout %.1f ms, décor %.1f, fosses %.1f, sol %.1f" % [wid, rep, tot / 1000.0, tot2 / 1000.0, a.acc.get("props", 0) / 1000.0, a.acc.get("pits", 0) / 1000.0, a.acc.get("floor", 0) / 1000.0])
		quit()
		return
	for wid in range(1, Worlds.WORLDS.size() + 1):
		a.set_world(wid)
		for kind in ["hub", "stage0", "stage1", "stage2", "mini", "boss"]:
			a.units.clear()
			a.begin_slices()
			a.last = Time.get_ticks_usec()
			var f0 := Engine.get_process_frames()
			var t0 := Time.get_ticks_usec()
			match kind:
				"hub":
					await a.build_hub(1234 + wid, true)
				"stage0":
					await a.build_stage(4, 77 + wid, true, true)
				"stage1", "stage2":
					await a.build_stage(4, 91 + wid, false, true)
				"mini":
					await a.build_room(8, 15, 55 + wid, 8, true)
				"boss":
					await a.build_room(15, 15, 66 + wid, 8, true)
			a.end_slices()
			var wall := Time.get_ticks_usec() - t0
			print("BENCH m%d %-6s cpu %.1f ms  tranche max %.1f ms  %d images (%.0f ms)" % [wid, kind, a.slice_cpu / 1000.0, a.slice_max / 1000.0, Engine.get_process_frames() - f0, wall / 1000.0])
			var cl: Array = []
			for c in a.cats.keys():
				cl.append("%s %.0f" % [c, a.cats[c] / 1000.0])
			print("BENCH   ", ", ".join(cl))
			a.cats.clear()
			for u in a.units:
				var w := String(u[1])
				big[w] = maxi(int(big.get(w, 0)), int(u[0]))
			# décor différé (tronçons lointains) : laissé à _process
			var guard := 0
			while (not a._pending.is_empty() or a._draining) and guard < 600:
				await process_frame
				guard += 1
	var keys := big.keys()
	keys.sort_custom(func(x, y): return int(big[x]) > int(big[y]))
	for k in keys.slice(0, 25):
		print("BENCH morceau max %.1f ms avant %s" % [int(big[k]) / 1000.0, k])
	quit()
