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
const METRICS := ["img", "proc", "phys", "process", "physics", "nodes", "objects", "draws", "d_vis", "d_shadow", "d_canvas", "prims", "mem"]
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
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
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


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--census="):
			for v in String(a).substr(9).split(","):
				_census_at.append(int(v))
	for m in METRICS:
		_win[m] = []
		_all[m] = []
	print("PERF relevé actif : fenêtres de %d images" % PERF_WINDOW)


func _where() -> String:
	if main == null:
		return "?"
	var w = main.get("current_world")
	var r = main.get("room")
	var s = main.get("state")
	return "monde %s salle %s état %s" % [str(w), str(r), str(s)]


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
	_acc.clear()
	_calls.clear()
	_phys_us = 0
	var cost := img  # pire moment : la plus longue image (rendu compris)
	if cost > float(_worst_win[0]):
		_worst_win = [cost, _where()]
	if cost > float(_worst_all[0]):
		_worst_all = [cost, _where()]
	if (_win["img"] as Array).size() >= PERF_WINDOW:
		_print_window()
	if _frames in _census_at:
		census()


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
	if m in ["nodes", "objects", "draws", "d_vis", "d_shadow", "d_canvas", "prims"]:
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
	print("PERF [%s] (moy/méd/p95/max) %s | pire %.2f ms : %s" % [_where(), _line(_win), float(_worst_win[0]), String(_worst_win[1])])
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
	var i := 1
	for r in _top(_keys_all, 99):
		print("PERF BILAN poste %2d %-14s moy %7.1f µs  méd %7.1f  p95 %7.1f  max %8.1f  appels/image max %d" % [i, r[0], r[1], r[4], r[2], r[3], int(_calls_max.get(StringName(r[0]), _calls_max.get(r[0], 0)))])
		i += 1
