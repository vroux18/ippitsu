extends Node
## Relevé de performance image par image : `-- --perf` (jamais par défaut ; le CI ne le passe pas).
## Toutes les PERF_WINDOW images (5 s de jeu au pas fixe du robot, --fixed-fps 30) : moyenne, p95 et max
## de chaque mesure (« PERF … »), et le pire moment de la fenêtre (monde, salle, état). Bilan de toute la
## partie à la sortie (« PERF BILAN »), avec les postes de script classés par coût.
## « proc » : du premier au dernier _process de l'image (tous les scripts) ; « phys » : les pas physiques.
## Mesures du moteur (Performance) : TIME_PROCESS et TIME_PHYSICS_PROCESS (ms ; le moteur n'en publie que le
## maximum de la dernière seconde réelle, d'où « process »/« physics » presque constants), nœuds,
## objets, appels de dessin et primitives (nuls en --headless : lancer sous Xvfb avec --rendering-driver
## opengl3), mémoire statique. « img » = temps réel entre deux images (au pas fixe, le moteur ne dort pas :
## c'est le vrai coût d'une image, rendu compris).
## Postes de script : chaque gros _process / _draw mesuré s'enveloppe de Perf.t0() / Perf.add(&"poste", t)
## (rien n'est mesuré sans --perf : une seule lecture de booléen statique).
## `--perftrace` (avec --perf) : une ligne « PERFT » par image (temps, appels de dessin 2D, postes de script, bulle du
## coach affichée et figée ou non) pour suivre une animation image par image (ex. l'apparition d'une bulle du tutoriel).

const PERF_WINDOW := 150  # images par fenêtre (5 s à 30 images/s)
const TOP_N := 10

static var on := false
# pas de temps réel simulé (s) : avec --fixed-fps, le moteur ne dort pas et une image dure 2 ms au lieu de 33 ;
# les animations en temps réel de l'interface (UiKit.real_delta) dureraient 15 fois trop d'images et fausseraient
# la part des images où le HUD s'anime. Sous --perf, elles avancent donc au pas fixe (0 : horloge réelle).
static var sim_dt := 0.0
static var _acc := {}  # poste -> µs cumulés depuis l'image précédente
static var _calls := {}  # poste -> appels depuis l'image précédente

var main: Node
var _last_us := 0
var _frames := 0
var _win := {}  # mesure -> Array de float (fenêtre en cours)
var _all := {}  # mesure -> Array de float (toute la partie)
var _keys_all := {}  # poste -> Array de float (µs par image, toute la partie ; 0 quand le poste n'a pas tourné)
var _keys_win := {}
var _calls_max := {}  # poste -> appels max dans une image
var _worst_win := [0.0, ""]
var _worst_all := [0.0, ""]
const METRICS := ["img", "proc", "phys", "process", "physics", "nodes", "added", "objects", "draws", "d_vis", "d_shadow", "d_canvas", "prims", "mem"]
var _added := 0  # nœuds entrés dans l'arbre depuis l'image précédente (créations d'effets, de pièces…)
var _added_by := {}  # classe ou script -> nœuds entrés (toute la partie)
var _proc0 := 0  # début des _process de l'image (nœud _Start, priorité la plus basse)
var _phys_us := 0  # µs de _physics_process cumulés depuis l'image précédente
var _phys0 := 0


## Premier nœud traité à chaque image (et à chaque pas physique) : début des mesures « proc » et « phys ».
class _Start extends Node:
	var probe: Node

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = -100000
		process_physics_priority = -100000

	func _process(_d: float) -> void:
		probe.set(&"_proc0", Time.get_ticks_usec())

	func _physics_process(_d: float) -> void:
		probe.set(&"_phys0", Time.get_ticks_usec())


## Début de mesure d'un poste (0 sans --perf).
static func t0() -> int:
	return Time.get_ticks_usec() if on else 0


## Fin de mesure d'un poste commencé par t0().
static func add(key: StringName, t: int) -> void:
	if not on:
		return
	_acc[key] = int(_acc.get(key, 0)) + Time.get_ticks_usec() - t
	_calls[key] = int(_calls.get(key, 0)) + 1


func _init() -> void:
	on = true
	var args := OS.get_cmdline_args()
	var i := args.find("--fixed-fps")
	if i >= 0 and i + 1 < args.size() and int(args[i + 1]) > 0:
		sim_dt = 1.0 / float(int(args[i + 1]))
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100000  # après tous les autres _process de l'image
	process_physics_priority = 100000
	var st := _Start.new()
	st.probe = self
	add_child(st)


func _physics_process(_d: float) -> void:
	if _phys0 != 0:
		_phys_us += Time.get_ticks_usec() - _phys0


var _census_at: Array = []  # `--census=N[,M…]` : recensement de la scène 3D à ces images


## Recensement de ce que la scène 3D dessine : instances de géométrie visibles par branche de l'arbre (premier
## ancêtre sous main, puis sous le monde et l'arène), dont celles qui portent une ombre, matières distinctes,
## particules. Pour savoir d'où viennent les appels de dessin.
func census() -> void:
	var rows := {}  # branche -> [instances, ombres, surfaces]
	var mats := {}
	var parts := 0
	var procs := {}  # script ou classe -> nœuds qui ont un _process (ou un traitement interne) actif
	var cpu_parts := 0  # particules CPU simulées (émetteurs qui émettent)
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n.is_processing() or n.is_processing_internal() or n.is_physics_processing():
			var sc: Script = n.get_script()
			var pk: String = sc.resource_path.get_file() if sc != null else n.get_class()
			procs[pk] = int(procs.get(pk, 0)) + 1
		var cp := n as CPUParticles3D
		if cp != null and cp.emitting:
			cpu_parts += cp.amount
		var gi := n as GeometryInstance3D
		if gi == null or not gi.is_visible_in_tree():
			continue
		var key := _branch(n)
		var r: Array = rows.get(key, [0, 0, 0])
		r[0] += 1
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			r[1] += 1
		var mi := gi as MeshInstance3D
		if mi != null and mi.mesh != null:
			r[2] += mi.mesh.get_surface_count()
			for si in mi.mesh.get_surface_count():
				var m: Material = mi.material_override if mi.material_override != null else mi.get_active_material(si)
				if m != null:
					mats[m.get_instance_id()] = true
		elif gi is GPUParticles3D or gi is CPUParticles3D:
			parts += 1
		rows[key] = r
	var keys := rows.keys()
	keys.sort_custom(func(a, b): return int(rows[a][0]) > int(rows[b][0]))
	print("PERF RECENSEMENT [%s] : %d matières distinctes, %d émetteurs de particules visibles" % [_where(), mats.size(), parts])
	for k in keys:
		var r: Array = rows[k]
		print("PERF RECENSEMENT %-40s instances %4d  ombres %4d  surfaces %4d" % [k, r[0], r[1], r[2]])
	var pks := procs.keys()
	pks.sort_custom(func(a, b): return int(procs[a]) > int(procs[b]))
	var pl: Array = []
	for k in pks:
		pl.append("%s %d" % [k, procs[k]])
	print("PERF RECENSEMENT traités à chaque image : ", ", ".join(pl))
	print("PERF RECENSEMENT particules CPU (émetteurs actifs) : %d" % cpu_parts)


## Signature du shader d'une matière : ShaderMaterial -> son shader ; matière standard -> ses options qui changent
## le code généré (mélange, ombrage, faces, profondeur, billboard, émission, textures, couleurs de sommets…).
func _mat_sig(m: Material, instanced: bool) -> String:
	var id := m.get_instance_id()
	var base: String = _mat_sig_cache.get(id, "")
	if base == "":
		if m is ShaderMaterial:
			var sh: Shader = (m as ShaderMaterial).shader
			base = "shader:%s" % (sh.resource_path if sh != null and sh.resource_path != "" else str(sh.get_instance_id() if sh != null else 0))
		elif m is BaseMaterial3D:
			var b := m as BaseMaterial3D
			var parts: Array = [b.get_class(), b.transparency, b.blend_mode, b.shading_mode, b.diffuse_mode, b.specular_mode,
				b.cull_mode, b.depth_draw_mode, b.no_depth_test, b.vertex_color_use_as_albedo, b.vertex_color_is_srgb,
				b.billboard_mode, b.billboard_keep_scale, b.emission_enabled, b.albedo_texture != null, b.emission_texture != null,
				b.normal_enabled, b.rim_enabled, b.clearcoat_enabled, b.anisotropy_enabled, b.ao_enabled, b.heightmap_enabled,
				b.subsurf_scatter_enabled, b.backlight_enabled, b.refraction_enabled, b.detail_enabled, b.texture_filter,
				b.use_point_size, b.fixed_size, b.disable_receive_shadows, b.disable_ambient_light, b.shadow_to_opacity,
				b.proximity_fade_enabled, b.distance_fade_mode, b.grow, b.uv1_triplanar, b.texture_repeat, b.alpha_antialiasing_mode,
				b.metallic_texture != null, b.roughness_texture != null, b.disable_fog, b.vertex_color_is_srgb, b.use_particle_trails]
			base = "std:" + str(parts)
		else:
			base = m.get_class()
		_mat_sig_cache[id] = base
	return base + ("|inst" if instanced else "")


func _scan_materials() -> void:
	if main == null:
		return
	# premier passage après le préchauffage : sa miniature (ennemis, effets) est encore là, tout compte comme vu
	var report := _warm_done
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var gi := n as GeometryInstance3D
		if gi == null or not gi.is_visible_in_tree():
			continue
		var mats: Array = []
		var inst := gi is MultiMeshInstance3D or gi is CPUParticles3D or gi is GPUParticles3D
		if gi.material_override != null:
			mats.append(gi.material_override)
		var mesh: Mesh = null
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
			if mesh != null and gi.material_override == null:
				for si in mesh.get_surface_count():
					var sm: Material = (gi as MeshInstance3D).get_active_material(si)
					if sm != null:
						mats.append(sm)
		elif gi is CPUParticles3D:
			mesh = (gi as CPUParticles3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			mesh = (gi as MultiMeshInstance3D).multimesh.mesh
		if mesh != null and gi.material_override == null and not (gi is MeshInstance3D):
			for si in mesh.get_surface_count():
				var mm: Material = mesh.surface_get_material(si)
				if mm != null:
					mats.append(mm)
		for m in mats:
			var sig := _mat_sig(m, inst)
			if _mat_seen.has(sig):
				continue
			_mat_seen[sig] = true
			if report:
				print("PERF NOUVEAU SHADER [%s] image %d : %s (%s)" % [_where(), _frames, _chain(n), sig.left(160)])
	if bool(main.get("warmed")) and not _warm_done:
		_warm_done = true
		print("PERF préchauffage : %d sortes de matières vues" % _mat_seen.size())


## Ascendance lisible d'un nœud (scripts et noms), du plus proche de main au nœud.
func _chain(n: Node) -> String:
	var out: Array = []
	var p := n
	while p != null and p != main and out.size() < 6:
		out.push_front(_label(p))
		p = p.get_parent()
	return " / ".join(out)


func _branch(n: Node) -> String:
	var chain: Array = []
	var p := n
	while p != null and p != main:
		chain.push_front(p)
		p = p.get_parent()
	if chain.is_empty():
		return "?"
	var out := _label(chain[0])
	# sous le monde ou l'arène : un niveau de plus (décor, ennemis, salle…)
	if chain.size() > 1 and (out.begins_with("world") or out.begins_with("Arena") or out.begins_with("@Node3D")):
		out += "/" + _label(chain[1])
		if chain.size() > 2 and _label(chain[1]).begins_with("@Node3D"):
			out += "/" + _label(chain[2])
	return out


func _label(n: Node) -> String:
	var sc: Script = n.get_script()
	if sc != null:
		return "%s(%s)" % [String(n.name).left(16), sc.resource_path.get_file().get_basename()]
	return "%s:%s" % [String(n.name).left(16), n.get_class()]


# `--shadercheck` : sortes de matières (une sorte = un shader à compiler) vues à l'écran ; celles qui paraissent
# après la fin du préchauffage (main.warmed) sont signalées avec le nœud qui les porte : shader compilé en partie
var _shader_check := false
var _trace := false  # `--perftrace` : une ligne par image (temps, postes de script, bulle du coach)
var _mat_seen := {}  # signature -> true
var _mat_sig_cache := {}  # id de matière -> signature
var _warm_done := false


func _ready() -> void:
	_shader_check = "--shadercheck" in OS.get_cmdline_user_args()
	_trace = "--perftrace" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--census="):
			for v in String(a).substr(9).split(","):
				_census_at.append(int(v))
	for m in METRICS:
		_win[m] = []
		_all[m] = []
	get_tree().node_added.connect(_on_node_added)
	print("PERF relevé actif : fenêtres de %d images" % PERF_WINDOW)


func _on_node_added(n: Node) -> void:
	_added += 1
	if _frames > 0:
		var sc: Script = n.get_script()
		var k: String = sc.resource_path.get_file() if sc != null else n.get_class()
		var par := n.get_parent()
		if par != null:
			var ps: Script = par.get_script()
			k += " < " + (ps.resource_path.get_file() if ps != null else par.get_class())
		_added_by[k] = int(_added_by.get(k, 0)) + 1


func _where() -> String:
	if main == null:
		return "?"
	var w = main.get("current_world")
	var r = main.get("room")
	var s = main.get("state")
	var out := "monde %s salle %s état %s" % [str(w), str(r), str(s)]
	var co = main.get("coach")
	if co != null and String(co.get("mark")) != "":
		out += " bulle %s%s" % [String(co.get("mark")), " figée" if float(co.get("_fz")) >= 0.0 else ""]
	return out


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_us == 0:
		_last_us = now
		_acc.clear()
		_calls.clear()
		return
	var img := float(now - _last_us) / 1000.0
	_last_us = now
	_frames += 1
	var vals := {
		"img": img,
		"proc": float(now - _proc0) / 1000.0 if _proc0 != 0 else 0.0,
		"phys": float(_phys_us) / 1000.0,
		"process": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"added": float(_added),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"d_vis": _rinfo(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE),  # appels de dessin : passe principale
		"d_shadow": _rinfo(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW),  # ombres
		"d_canvas": _rinfo(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS),  # interface 2D
		"prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"mem": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	}
	for m in METRICS:
		(_win[m] as Array).append(float(vals[m]))
		(_all[m] as Array).append(float(vals[m]))
	# postes de script : µs de l'image (0 si absent), comptés sur toutes les images
	for k in _acc.keys():
		if not _keys_all.has(k):
			var z := []
			z.resize(_frames - 1)
			z.fill(0.0)
			_keys_all[k] = z
		_calls_max[k] = maxi(int(_calls_max.get(k, 0)), int(_calls.get(k, 0)))
	for k in _keys_all.keys():
		var us := float(_acc.get(k, 0))
		(_keys_all[k] as Array).append(us)
		if not _keys_win.has(k):
			_keys_win[k] = []
		(_keys_win[k] as Array).append(us)
	if _trace:
		var ks: Array = []
		for k in _acc.keys():
			if int(_acc[k]) >= 20:
				ks.append("%s %d" % [k, int(_acc[k])])
		print("PERFT %d img %.2f proc %.2f canvas %d prims %d [%s] %s" % [_frames, img, float(vals["proc"]), int(vals["d_canvas"]),
			int(vals["prims"]), _where(), ", ".join(ks)])
	_acc.clear()
	_calls.clear()
	_phys_us = 0
	_added = 0
	var cost := img  # pire moment : la plus longue image (rendu compris)
	if cost > float(_worst_win[0]):
		_worst_win = [cost, _where()]
	if cost > float(_worst_all[0]):
		_worst_all = [cost, _where()]
	if (_win["img"] as Array).size() >= PERF_WINDOW:
		_print_window()
	if _frames in _census_at:
		census()
	if _shader_check and _frames % 2 == 0:
		_scan_materials()


func _rinfo(kind: int) -> float:
	return float(RenderingServer.viewport_get_render_info(get_viewport().get_viewport_rid(), kind,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))


static func _stats(a: Array) -> Array:
	if a.is_empty():
		return [0.0, 0.0, 0.0, 0.0]
	var s := a.duplicate()
	s.sort()
	var tot := 0.0
	for v in s:
		tot += v
	# moyenne, p95, max, médiane (la médiane écarte les images de chargement et les à-coups de la machine)
	return [tot / float(s.size()), s[mini(s.size() - 1, int(float(s.size()) * 0.95))], s[s.size() - 1], s[s.size() / 2]]


func _fmt(m: String, a: Array) -> String:
	var st := _stats(a)
	if m in ["nodes", "added", "objects", "draws", "d_vis", "d_shadow", "d_canvas", "prims"]:
		return "%s %d/%d/%d/%d" % [m, int(st[0]), int(st[3]), int(st[1]), int(st[2])]
	return "%s %.2f/%.2f/%.2f/%.2f" % [m, st[0], st[3], st[1], st[2]]


func _line(src: Dictionary) -> String:
	var parts: Array = []
	for m in METRICS:
		parts.append(_fmt(m, src[m]))
	return " | ".join(parts)


func _top(src: Dictionary, n: int) -> Array:
	var rows: Array = []
	for k in src.keys():
		var st := _stats(src[k])
		rows.append([String(k), st[0], st[1], st[2], st[3]])
	rows.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	return rows.slice(0, n)


func _print_window() -> void:
	print("PERF [%s] t=%.1f (moy/méd/p95/max) %s | pire %.2f ms : %s" % [_where(), Time.get_unix_time_from_system(), _line(_win),
		float(_worst_win[0]), String(_worst_win[1])])
	var tops: Array = []
	for r in _top(_keys_win, TOP_N):
		tops.append("%s %.0f/%.0f/%.0f/%.0f" % [r[0], r[1], r[4], r[2], r[3]])
	if not tops.is_empty():
		print("PERF postes µs (moy/méd/p95/max) : ", ", ".join(tops))
	for m in METRICS:
		_win[m] = []
	_keys_win.clear()
	_worst_win = [0.0, ""]


func _exit_tree() -> void:
	summary()


var _summarized := false


## Bilan de toute la partie (appelé à la sortie ; une seule fois).
func summary() -> void:
	if _summarized or _frames == 0:
		return
	_summarized = true
	print("PERF BILAN %d images (moy/méd/p95/max) %s" % [_frames, _line(_all)])
	print("PERF BILAN pire image %.2f ms : %s" % [float(_worst_all[0]), String(_worst_all[1])])
	var ak := _added_by.keys()
	ak.sort_custom(func(a, b): return int(_added_by[a]) > int(_added_by[b]))
	var al: Array = []
	for k in ak.slice(0, 16):
		al.append("%s %d" % [k, _added_by[k]])
	print("PERF BILAN nœuds créés (nœud < parent) : ", ", ".join(al))
	var i := 1
	for r in _top(_keys_all, 99):
		print("PERF BILAN poste %2d %-14s moy %7.1f µs  méd %7.1f  p95 %7.1f  max %8.1f  appels/image max %d" % [i, r[0], r[1], r[4], r[2], r[3], int(_calls_max.get(StringName(r[0]), _calls_max.get(r[0], 0)))])
		i += 1
