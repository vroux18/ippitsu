extends CanvasLayer
## Mode mesure (caché) : fluidité mesurée sur le vrai téléphone. S'active par un appui long (1,5 s) sur le titre
## IPPITSU de l'accueil (menu.gd), mémorisé dans la sauvegarde (meta.measure_mode) ; `-- --q=mesure` le force
## (captures, sans rien sauvegarder).
## Actif : chaque image est relevée (temps entre deux images, part des _process, des pas physiques, le reste =
## rendu et attente de l'affichage) ; un petit encart en bas à gauche (zone du pouce, libre de HUD) montre les IPS,
## le temps d'image moyen et max de la dernière seconde, et le graphe des 120 dernières images (repères 16,7 et
## 33 ms), redessiné 4 fois par seconde au plus. Les images de plus de 33 ms sont consignées avec leur contexte
## (état, monde/étape/salle, bulle du coach, ennemis, effets, construction ou préchauffage récents, moniteurs du
## moteur). Le rapport (report()) se copie depuis la pause : texte compact, moins de ~3000 caractères.
## Inactif : le nœud ne traite rien (set_process(false)), aucun relevé.

const UiKit = preload("res://scripts/ui_kit.gd")
const UIColors = preload("res://scripts/ui_colors.gd")

const SLOW_MS := 33.0  # image consignée au-delà (deux images ratées à 60 Hz)
const BAD_MS := 50.0
const BIN_MS := 0.5  # histogrammes : cases de 0,5 ms jusqu'à 500 ms (la dernière case prend tout le reste)
const BINS := 1000
const GRAPH_N := 120  # images du graphe
const WORST_N := 15
const LOG_MAX := 300  # journal des images lentes (les plus anciennes partent)
const EVENT_FRAMES := 4  # une construction / un préchauffage « vient d'avoir lieu » s'il date de 4 images au plus
const REPORT_MAX := 3000
# états de main.state -> libellé du rapport (le tutoriel et le sanctuaire sont tirés du jeu)
const STATE_NAMES := {"menu": "accueil", "worlds": "carte des mondes", "sail": "traversée", "intro": "intro",
	"play": "jeu", "boss_intro": "entrée de boss", "pick": "rouleau", "transit": "transition", "paused": "pause",
	"dying": "mort", "over": "résultats", "tuto": "dojo"}
const SHOW_IN := ["play", "transit", "pick", "tuto", "boss_intro", "dying"]  # états où l'encart paraît

var main: Node
var active := false
var last_report := ""  # dernier rapport copié (robot UI : vérifié sans presse-papiers)

var _view: Control
var _sb := StyleBoxFlat.new()
var _toast := ""
var _toast_ms := 0
var _start: Node  # premier nœud traité à chaque image (début des _process et des pas physiques)

# relevés (remis à zéro par reset())
var _t0_ms := 0
var _last_us := 0
var _frames := 0
var _sum := 0.0
var _max := 0.0
var _hist := PackedInt32Array()
var _by_state := {}  # libellé -> [images, somme ms, >33, >50, max, histogramme]
var _ring := PackedFloat32Array()
var _ring_i := 0
var _worst: Array = []  # [ms, ligne de contexte], du pire au moins pire
var _slow: Array = []  # journal : [ms, ligne]
var _events: Array = []  # [image, étiquette, ms] : constructions, préchauffage, chargements (main.perf_mark)
var _proc0 := 0
var _phys0 := 0
var _phys_us := 0
# encart : chiffres de la dernière seconde
var _sec_ms := 0
var _sec_n := 0
var _sec_sum := 0.0
var _sec_max := 0.0
var _shown_fps := 0.0
var _shown_avg := 0.0
var _shown_max := 0.0
var _draw_ms := 0
var _shown := false  # encart affiché (état de jeu)


## Premier nœud traité à chaque image et à chaque pas physique (priorité la plus basse).
class _Start extends Node:
	var m: Node

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = -100000
		process_physics_priority = -100000

	func _process(_d: float) -> void:
		m.set(&"_proc0", Time.get_ticks_usec())

	func _physics_process(_d: float) -> void:
		m.set(&"_phys0", Time.get_ticks_usec())


func _init() -> void:
	layer = 9  # au-dessus de tout (pause, rouleaux, options), sans prendre un seul toucher
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100000  # après tous les autres _process de l'image
	process_physics_priority = 100000


func _ready() -> void:
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	add_child(_view)
	_hist.resize(BINS)
	_ring.resize(GRAPH_N)
	set_process(false)
	set_physics_process(false)


## Met le mode en marche ou l'arrête (rien n'est relevé à l'arrêt).
func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	if on:
		reset()
		_start = _Start.new()
		_start.m = self
		add_child(_start)
	elif _start != null:
		_start.queue_free()
		_start = null
	set_physics_process(on)
	_shown = false
	_wake()


func reset() -> void:
	_t0_ms = Time.get_ticks_msec()
	_last_us = 0
	_frames = 0
	_sum = 0.0
	_max = 0.0
	_hist.fill(0)
	_by_state.clear()
	_ring.fill(0.0)
	_ring_i = 0
	_worst.clear()
	_slow.clear()
	_events.clear()
	_sec_ms = Time.get_ticks_msec()
	_sec_n = 0
	_sec_sum = 0.0
	_sec_max = 0.0
	_shown_fps = 0.0
	_shown_avg = 0.0
	_shown_max = 0.0
	_phys_us = 0


func toast(text: String) -> void:
	_toast = text
	_toast_ms = Time.get_ticks_msec()
	_wake()


## Repère d'événement (main.perf_mark : construction d'étape, préchauffage, chargements…).
func event(label: String, ms: float) -> void:
	if not active:
		return
	_events.append([_frames, label, ms])
	if _events.size() > 12:
		_events.pop_front()


func frames() -> int:
	return _frames


func _wake() -> void:
	set_process(active or _toast != "")
	_view.queue_redraw()


func _physics_process(_d: float) -> void:
	if _phys0 != 0:
		_phys_us += Time.get_ticks_usec() - _phys0
		_phys0 = 0


func _process(_d: float) -> void:
	var now_ms := Time.get_ticks_msec()
	if _toast != "" and now_ms - _toast_ms > 1800:
		_toast = ""
		_view.queue_redraw()
		if not active:
			set_process(false)
			return
	if not active:
		return
	var now := Time.get_ticks_usec()
	if _last_us == 0:
		_last_us = now
		_phys_us = 0
		return
	var ms := float(now - _last_us) / 1000.0
	_last_us = now
	var proc := float(now - _proc0) / 1000.0 if _proc0 != 0 else 0.0
	var phys := float(_phys_us) / 1000.0
	_phys_us = 0
	_frames += 1
	_sum += ms
	_max = maxf(_max, ms)
	var bin := mini(BINS - 1, int(ms / BIN_MS))
	_hist[bin] += 1
	var st := _state_name()
	var s: Array = _by_state.get(st, [])
	if s.is_empty():
		var h := []  # (Array : modifié en place)
		h.resize(BINS)
		h.fill(0)
		s = [0, 0.0, 0, 0, 0.0, h]
		_by_state[st] = s
	s[0] += 1
	s[1] += ms
	if ms > SLOW_MS:
		s[2] += 1
	if ms > BAD_MS:
		s[3] += 1
	s[4] = maxf(float(s[4]), ms)
	s[5][bin] += 1
	_ring[_ring_i] = ms
	_ring_i = (_ring_i + 1) % GRAPH_N
	if ms > SLOW_MS:
		_note_slow(ms, proc, phys, st)
	# encart : moyenne et max de la dernière seconde
	_sec_n += 1
	_sec_sum += ms
	_sec_max = maxf(_sec_max, ms)
	if now_ms - _sec_ms >= 1000:
		_shown_fps = float(_sec_n) * 1000.0 / float(now_ms - _sec_ms)
		_shown_avg = _sec_sum / float(maxi(1, _sec_n))
		_shown_max = _sec_max
		_sec_ms = now_ms
		_sec_n = 0
		_sec_sum = 0.0
		_sec_max = 0.0
	var show := main != null and String(main.state) in SHOW_IN
	if show != _shown:
		_shown = show
		_view.queue_redraw()
	elif show and now_ms - _draw_ms >= 250:
		_draw_ms = now_ms
		_view.queue_redraw()


func _state_name() -> String:
	if main == null:
		return "?"
	var s := String(main.state)
	if s == "play":
		if bool(main.in_hub):
			return "sanctuaire"
		if main.meta != null and not bool(main.meta.tuto_done):
			return "tutoriel"
	return String(STATE_NAMES.get(s, s))


## Image lente : contexte relevé (seulement pour elle, rien pour les images ordinaires).
func _note_slow(ms: float, proc: float, phys: float, st: String) -> void:
	var parts: Array = ["%.0f ms @%s" % [ms, _clock(float(Time.get_ticks_msec() - _t0_ms) / 1000.0)], st]
	if main != null:
		parts.append("m%d é%d s%d" % [int(main.current_world), int(main.stage_i) + 1, int(main.room)])
		var co = main.coach
		if co != null and String(co.mark) != "":
			parts.append("bulle %s%s" % [String(co.mark), " figée" if bool(co.frozen()) else ""])
		parts.append("%d enn" % main.enemies.size())
		if main.vfx != null:
			parts.append("%d vfx" % (main.vfx.get("_fx") as Array).size())
		if not bool(main.warmed):
			parts.append("préchauffage en cours")
	parts.append("proc %.0f phys %.0f reste %.0f" % [proc, phys, maxf(0.0, ms - proc - phys)])
	parts.append("%d appels" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	parts.append("%d obj" % int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	parts.append("%.0f Mo" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	var ev: Array = []  # les deux repères les plus récents des dernières images (ms)
	for i in range(_events.size() - 1, -1, -1):
		var e: Array = _events[i]
		if _frames - int(e[0]) > EVENT_FRAMES or ev.size() >= 2:
			break
		ev.push_front("%s %.0f" % [String(e[1]), float(e[2])])
	if not ev.is_empty():
		parts.append("après " + ", ".join(ev))
	var line := " · ".join(parts)
	_slow.append([ms, line])
	if _slow.size() > LOG_MAX:
		_slow.pop_front()
	if _worst.size() < WORST_N or ms > float(_worst[_worst.size() - 1][0]):
		var t := line
		var i := 0
		while i < _worst.size() and float(_worst[i][0]) >= ms:
			i += 1
		_worst.insert(i, [ms, t])
		if _worst.size() > WORST_N:
			_worst.pop_back()


static func _clock(sec: float) -> String:
	return "%d:%02d" % [int(sec / 60.0), int(sec) % 60]


## Centile (0..1) d'un histogramme : milieu de la case (la dernière case, ouverte : le max).
static func _pct(h, n: int, q: float, mx: float) -> float:
	if n <= 0:
		return 0.0
	var want := int(ceil(float(n) * q))
	var acc := 0
	for i in h.size():
		acc += h[i]
		if acc >= want:
			return mx if i == h.size() - 1 else minf(mx, (float(i) + 0.5) * BIN_MS)
	return float(h.size()) * BIN_MS


func _stats_line(n: int, sum: float, h, slow: int, bad: int, mx: float, short := false) -> String:
	var avg := sum / float(maxi(1, n))
	if short:
		return "%d img · moy %.1f · p50 %.1f · p95 %.1f · p99 %.1f · max %.0f · >33 : %d · >50 : %d" % [
			n, avg, _pct(h, n, 0.5, mx), _pct(h, n, 0.95, mx), _pct(h, n, 0.99, mx), mx, slow, bad]
	return "%d img · moy %.1f ms (%.0f IPS) · p50 %.1f · p95 %.1f · p99 %.1f · max %.0f · >33 ms : %d (%.1f %%) · >50 ms : %d" % [
		n, avg, 1000.0 / maxf(avg, 0.001), _pct(h, n, 0.5, mx), _pct(h, n, 0.95, mx), _pct(h, n, 0.99, mx), mx, slow,
		100.0 * float(slow) / float(maxi(1, n)), bad]


## Rapport compact, en français, une information par ligne (moins de REPORT_MAX caractères).
func report() -> String:
	var head: Array = []
	head.append("IPPITSU — rapport de fluidité")
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	head.append("Version du jeu : %s · Godot %s" % [ver if ver != "" else "dev", Engine.get_version_info().get("string", "?")])
	head.append("Appareil : %s" % OS.get_model_name())
	head.append("Système : %s %s" % [OS.get_name(), OS.get_version()])
	var win := DisplayServer.window_get_size()
	var vp: Vector2 = _view.get_viewport_rect().size if _view != null else Vector2.ZERO
	var hz := DisplayServer.screen_get_refresh_rate()
	head.append("Écran : %d×%d px (vue %d×%d)%s" % [win.x, win.y, int(vp.x), int(vp.y), (", %.0f Hz" % hz) if hz > 1.0 and hz < 1000.0 else ""])
	head.append("Rendu : %s · %s · %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(),
		RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_current_rendering_method()])
	head.append("Durée mesurée : %s" % _clock(float(Time.get_ticks_msec() - _t0_ms) / 1000.0))
	var slow := 0
	var bad := 0
	for st in _by_state.keys():
		slow += int(_by_state[st][2])
		bad += int(_by_state[st][3])
	head.append("Global : " + _stats_line(_frames, _sum, _hist, slow, bad, _max))
	head.append("Par état (ms) :")
	var keys := _by_state.keys()
	keys.sort_custom(func(a, b): return int(_by_state[a][0]) > int(_by_state[b][0]))
	for st in keys:
		var s: Array = _by_state[st]
		head.append("- %s : %s" % [st, _stats_line(int(s[0]), float(s[1]), s[5], int(s[2]), int(s[3]), float(s[4]), true)])
	var out := "\n".join(head)
	if _worst.is_empty():
		return out + "\nPires images : aucune au-delà de 33 ms"
	out += "\nPires images (%d sur %d au-delà de 33 ms) :" % [mini(WORST_N, _worst.size()), slow]
	out += "\n(@ = instant ; m/é/s = monde, étape, salle ; proc = _process des scripts, phys = pas physiques, reste = rendu, attente de l'écran, signaux)"
	for i in _worst.size():
		var ln := "\n%d. %s" % [i + 1, String(_worst[i][1])]
		if out.length() + ln.length() > REPORT_MAX:
			out += "\n(… coupé)"
			break
		out += ln
	return out


# --- dessin ----------------------------------------------------------------

func _draw_view() -> void:
	var sz := _view.size
	if sz.x < 10.0:
		return
	var u := sz.x / 400.0
	var nf := UiKit.num_font()
	var safe := UiKit.safe_insets(sz)
	if active and _shown:
		# encart en bas à gauche : zone du pouce (le HUD n'y pose rien), sous les grappes latérales
		var bw := 128.0 * u
		var bh := 60.0 * u
		var r := Rect2(Vector2(6.0 * u, sz.y - safe.y - 6.0 * u - bh), Vector2(bw, bh))
		_view.draw_rect(r, Color(UIColors.SUMI, 0.72))
		var fs := int(10.0 * u)
		var col := UIColors.WASHI
		var hot := Color("#E8574A")
		var fps_col := col if _shown_avg <= 17.5 else (Color("#E8B04A") if _shown_avg <= 25.0 else hot)
		_view.draw_string(nf, r.position + Vector2(5.0 * u, 12.0 * u), "%.0f IPS" % _shown_fps, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12.0 * u), fps_col)
		_view.draw_string(nf, r.position + Vector2(52.0 * u, 12.0 * u), "moy %.1f" % _shown_avg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		_view.draw_string(nf, r.position + Vector2(5.0 * u, 24.0 * u), "max %.1f ms" % _shown_max, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			col if _shown_max <= SLOW_MS else hot)
		var nslow := 0
		for st in _by_state.keys():
			nslow += int(_by_state[st][2])
		_view.draw_string(nf, r.position + Vector2(76.0 * u, 24.0 * u), ">33 %d" % nslow, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, 0.75))
		# graphe : 120 images, de la plus ancienne à la plus récente ; 0..50 ms sur la hauteur
		var g := Rect2(r.position + Vector2(4.0 * u, 29.0 * u), Vector2(bw - 8.0 * u, bh - 33.0 * u))
		var ky := g.size.y / 50.0
		for ref in [[16.7, Color(col, 0.35)], [33.3, Color(hot, 0.6)]]:
			var y: float = g.end.y - float(ref[0]) * ky
			_view.draw_line(Vector2(g.position.x, y), Vector2(g.end.x, y), ref[1], 1.0)
		var pts := PackedVector2Array()
		pts.resize(GRAPH_N)
		var dx := g.size.x / float(GRAPH_N - 1)
		for i in GRAPH_N:
			var v := _ring[(_ring_i + i) % GRAPH_N]
			pts[i] = Vector2(g.position.x + dx * float(i), g.end.y - minf(v, 50.0) * ky)
		_view.draw_polyline(pts, Color("#7FD1C0"), maxf(1.0, 1.2 * u))
	if _toast != "":
		var tfs := int(15.0 * u)
		var f := UiKit.UI_FONT
		var tw := f.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		var tr := Rect2(Vector2((sz.x - tw) / 2.0 - 16.0 * u, sz.y * 0.42), Vector2(tw + 32.0 * u, 38.0 * u))
		_view.draw_style_box(UiKit.box(_sb, Color(UIColors.SUMI, 0.92), int(14.0 * u)), tr)
		_view.draw_string(f, Vector2(tr.position.x + 16.0 * u, tr.get_center().y + float(tfs) * 0.36), _toast,
			HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, UIColors.WASHI)
