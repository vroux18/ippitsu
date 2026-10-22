extends Node
## Bruitages synthétisés (aucun fichier audio enregistré) et vibrations courtes (Android / iOS / web Android).
##
## Rien n'est calculé pendant le jeu : la banque de sons (toutes les variantes de tous les sons) est fabriquée une
## fois au CI par tools/bake_music.gd (bake_bank -> assets/sfx/bank.res) et chargée en arrière-plan au lancement,
## sous l'écran de chargement. Sans la banque (version locale sans CI), les sons sont fabriqués dès le lancement,
## quelques millisecondes par image ; un son demandé avant son tour est fabriqué sur-le-champ.
## Lecture : quelques variantes par son, et à chaque coup une légère variation de hauteur et de volume (les coups
## répétés ne « mitraillent » pas) ; voix plafonnées (VOICES, MAX_SAME par son) ; son coupé : rien n'est lancé.
##
## Sons (play(id)) : coupe et trait (slash, kill, whoosh, swish, iai, stab), impacts (strike, hurt), tir (shot),
## encre (ink, splash, puff), éléments (zap, thunder, fire, crackle, gust), gains (xp, coin, levelup), figures
## (tech_*), lieux (torii, shrine, pact), interface (empty), rouleaux (reel_tick à chaque arrêt de rouleau,
## reel_rare / reel_legend pour un tirage rare / légendaire).

const RATE := 22050
const VOICES := 10  # voix simultanées au plus (la plus ancienne cède sa place)
const MAX_SAME := 3  # voix d'un même son au plus
const MIN_GAP_MS := 30  # même son relancé plus vite : ignoré
const GAP_MS := {"slash": 15, "reel_tick": 20}  # écart propre à certains sons (touches serrées d'une série)
const BUZZ_GAP_MS := 40  # vibrations : une impulsion toutes les 40 ms au plus
const BANK := "res://assets/sfx/bank.res"
const BUILD_BUDGET_US := 5000  # sans banque : temps de fabrication par image
const CORE := ["slash", "kill", "whoosh", "hurt", "strike", "shot", "empty"]
const LATER := ["xp", "coin", "zap", "thunder", "fire", "crackle", "splash", "swish", "gust", "puff", "stab", "ink", "iai",
	"tech_loop", "tech_zigzag", "tech_straight", "tech_return", "tech_enso", "tech_hook",
	"torii", "levelup", "shrine", "pact", "reel_tick", "reel_rare", "reel_legend"]
# sons mélodiques : hauteur exacte (seul le volume varie)
const TUNED := ["tech_loop", "tech_zigzag", "tech_straight", "tech_return", "tech_enso", "tech_hook",
	"torii", "levelup", "shrine", "pact", "coin", "reel_rare", "reel_legend"]
const PITCH_VAR := 0.045  # variation de hauteur (±) des sons non accordés
const VOL_VAR := 1.5  # variation de volume (± dB)
# motifs de vibration : [délai ms, durée ms, force 0..1]
const HAPTIC := {
	"dash": [[0, 6, 0.2]],
	"hit": [[0, 15, 0.5]],
	"clang": [[0, 14, 0.5]],
	"kill": [[0, 30, 0.8]],
	"multi": [[0, 40, 0.9]],
	"figure": [[0, 30, 0.75]],
	"heavy": [[0, 35, 0.85]],
	"hurt": [[0, 60, 1.0]],
	"death": [[0, 80, 1.0], [160, 120, 1.0]],
	"boss_hit": [[0, 18, 0.7], [70, 10, 0.45]],
	"boss_death": [[0, 40, 1.0], [120, 30, 0.8], [240, 70, 1.0]],
	"clear": [[0, 15, 0.6], [110, 15, 0.6]],
	"level": [[0, 12, 0.4], [90, 18, 0.6], [180, 28, 0.85]],
}

var haptics := true  # option VIBRATIONS
var _streams := {}  # id -> Array d'AudioStreamWAV (variantes)
var _players: Array[AudioStreamPlayer] = []
var _pid: Array[String] = []  # son joué par chaque voix
var _pstart: Array[int] = []  # départ (ms) de chaque voix
var _last := {}  # id -> dernier départ (ms)
var _todo: Array = []
var _bank_wait := false
var _native_vib := false
var _web_vib := false
var _buzz_ms := -1000
var _buzz_len := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
		_pid.append("")
		_pstart.append(0)
	_todo = CORE.duplicate()
	_todo.append_array(LATER)
	if ResourceLoader.exists(BANK) and ResourceLoader.load_threaded_request(BANK) == OK:
		_bank_wait = true
	if DisplayServer.get_name() != "headless":
		_native_vib = OS.has_feature("android") or OS.has_feature("ios")
		if OS.has_feature("web_android"):
			_web_vib = bool(JavaScriptBridge.eval("typeof navigator.vibrate === 'function'", true))


## Tous les sons sont prêts (banque chargée ou fabrication finie).
func is_ready() -> bool:
	return not _bank_wait and _todo.is_empty()


func _process(_delta: float) -> void:
	if _bank_wait:
		var st := ResourceLoader.load_threaded_get_status(BANK)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		_bank_wait = false
		var res: Resource = ResourceLoader.load_threaded_get(BANK) if st == ResourceLoader.THREAD_LOAD_LOADED else null
		var bank: Variant = res.get_meta("bank", null) if res != null else null
		if bank is Dictionary:
			for id in (bank as Dictionary).keys():
				if not _streams.has(id):
					_streams[id] = bank[id]
				_todo.erase(id)
	if _todo.is_empty():
		set_process(false)
		return
	# sans banque : fabrication étalée (quelques ms par image)
	var t0 := Time.get_ticks_usec()
	while not _todo.is_empty() and Time.get_ticks_usec() - t0 < BUILD_BUDGET_US:
		var id := String(_todo.pop_front())
		if not _streams.has(id):
			_streams[id] = _build(id)


## Joue le son `id` (variante au hasard, hauteur et volume légèrement variés). Noms : voir CORE et LATER.
func play(id: String, pitch := 1.0, volume_db := 0.0) -> void:
	if AudioServer.is_bus_mute(0):
		return
	if not _streams.has(id):
		if not id in LATER and not id in CORE:
			return
		_streams[id] = _build(id)  # demandé avant son tour : créé tout de suite
		_todo.erase(id)
	var now := Time.get_ticks_msec()
	if now - int(_last.get(id, -1000)) < int(GAP_MS.get(id, MIN_GAP_MS)):
		return
	_last[id] = now
	var vars: Array = _streams[id]
	if vars.is_empty():
		return
	var k := _voice(id)
	var p := _players[k]
	p.stop()
	p.stream = vars[randi() % vars.size()]
	var pv := pitch
	if not id in TUNED:
		pv *= 1.0 + randf_range(-PITCH_VAR, PITCH_VAR)
	p.pitch_scale = maxf(0.05, pv)
	p.volume_db = volume_db + randf_range(-VOL_VAR, VOL_VAR)
	p.play()
	_pid[k] = id
	_pstart[k] = now


## Voix pour un nouveau son : une libre ; sinon, si ce son a déjà MAX_SAME voix, la plus ancienne des siennes ;
## sinon la plus ancienne de toutes.
func _voice(id: String) -> int:
	var free := -1
	var same := 0
	var old_same := -1
	var old_any := 0
	for k in _players.size():
		if not _players[k].playing:
			if free < 0:
				free = k
			continue
		if _pid[k] == id:
			same += 1
			if old_same < 0 or _pstart[k] < _pstart[old_same]:
				old_same = k
		if _pstart[k] < _pstart[old_any] or not _players[old_any].playing:
			old_any = k
	if same >= MAX_SAME and old_same >= 0:
		return old_same
	if free >= 0:
		return free
	return old_any


# ------------------------------------------------------------------ vibrations

func _can_buzz() -> bool:
	return haptics and (_native_vib or _web_vib)


## Motif de vibration nommé (voir HAPTIC), `boost` ajouté à la force (série). Sans effet hors mobile, sans vibreur
## ou si l'option est coupée.
func haptic(kind: String, boost := 0.0) -> void:
	if not _can_buzz() or not HAPTIC.has(kind):
		return
	var steps: Array = HAPTIC[kind]
	for st in steps:
		var a: Array = st
		var delay := float(a[0]) / 1000.0
		if delay <= 0.0:
			buzz(int(a[1]), float(a[2]) + boost)
		else:
			get_tree().create_timer(delay, true, false, true).timeout.connect(buzz.bind(int(a[1]), float(a[2]) + boost))


## Impulsion brève : ms, force 0..1. Une seule toutes les 40 ms, sauf si la nouvelle est plus longue.
func buzz(ms: int, amp := 0.5) -> void:
	if not _can_buzz():
		return
	var now := Time.get_ticks_msec()
	if now - _buzz_ms < BUZZ_GAP_MS and ms <= _buzz_len:
		return
	_buzz_ms = now
	_buzz_len = ms
	if _native_vib:
		Input.vibrate_handheld(ms, clampf(amp, 0.05, 1.0))
	else:
		JavaScriptBridge.eval("navigator.vibrate(%d)" % ms, true)


# ------------------------------------------------------------------ banque (CI)

## Fabrique tous les sons et les écrit dans une banque (Resource, méta « bank » : id -> variantes).
## Appelé par tools/bake_music.gd ; tirages fixés (banque identique d'une cuisson à l'autre).
func bake_bank(path: String) -> int:
	seed(20251017)
	var bank := {}
	for id in CORE + LATER:
		bank[id] = _build(String(id))
	var res := Resource.new()
	res.set_meta("bank", bank)
	return ResourceSaver.save(res, path, ResourceSaver.FLAG_COMPRESS)


# ------------------------------------------------------------------ fabrication

func _build(id: String) -> Array:
	var out: Array = []
	match id:
		"slash":
			for k in 3:
				out.append(_wav(_slash(1.0 + 0.08 * (k - 1))))
		"kill":
			for k in 3:
				out.append(_wav(_kill(1.0 + 0.07 * (k - 1))))
		"whoosh":
			for k in 3:
				out.append(_wav(_whoosh(0.27 + 0.03 * k, 1.0 + 0.12 * (k - 1))))
		"hurt":
			for k in 2:
				out.append(_wav(_hurt()))
		"strike":
			for k in 3:
				out.append(_wav(_strike(1.0 + 0.06 * (k - 1))))
		"shot":
			for k in 2:
				out.append(_wav(_shot()))
		"empty":
			for k in 2:
				out.append(_wav(_empty()))
		"xp":
			for k in 3:
				out.append(_wav(_xp(1760.0 * pow(2.0, (2.0 * k) / 12.0))))
		"coin":
			out.append(_wav(_coin([1975.5, 2637.0])))
			out.append(_wav(_coin([2093.0, 2793.8])))
		"zap":
			for k in 3:
				out.append(_wav(_zap(0.17)))
		"thunder":
			for k in 2:
				out.append(_wav(_thunder()))
		"fire":
			out.append(_wav(_fire(0.42)))
			out.append(_wav(_fire(0.36)))
		"crackle":
			for k in 2:
				out.append(_wav(_crackle()))
		"splash":
			for k in 2:
				out.append(_wav(_splash()))
		"swish":
			for k in 3:
				out.append(_wav(_norm(_swish(0.18, 700.0, 2600.0 - 250.0 * k, 2.5), 0.7)))
		"gust":
			for k in 2:
				out.append(_wav(_gust()))
		"puff":
			for k in 2:
				out.append(_wav(_puff()))
		"stab":
			for k in 2:
				out.append(_wav(_stab()))
		"ink":
			for k in 2:
				out.append(_wav(_ink()))
		"iai":
			out.append(_wav(_iai()))
		"tech_loop":
			# boucle : le vent tourne, deux clochettes à la quinte
			var s := _buf(0.8)
			s = _add(s, _gust(), 0.0, 0.7)
			s = _add(s, _metal(880.0, 0.7, [1.0, 2.0, 2.76], [1.0, 0.35, 0.2], [6.0, 9.0, 14.0], 0.3), 0.1, 0.45)
			s = _add(s, _metal(1318.5, 0.6, [1.0, 2.0, 2.76], [1.0, 0.35, 0.2], [7.0, 10.0, 15.0], 0.3), 0.2, 0.4)
			out.append(_wav(_norm(_room(s, 0.25), 0.85)))
		"tech_zigzag":
			# zigzag : trois éclairs et un tintement vif
			var s := _buf(0.55)
			for k in 3:
				s = _add(s, _zap(0.1), 0.06 * k, 0.6)
			s = _add(s, _metal(1318.5, 0.4, [1.0, 2.0, 3.0], [1.0, 0.4, 0.2], [9.0, 13.0, 18.0], 0.4), 0.16, 0.5)
			s = _add(s, _metal(1760.0, 0.35, [1.0, 2.0, 3.0], [1.0, 0.4, 0.2], [10.0, 14.0, 20.0], 0.4), 0.22, 0.4)
			out.append(_wav(_norm(s, 0.85)))
		"tech_straight":
			# « kachin » : la lame rengainée (deux claquements), tintement clair sur une note grave
			var s := _buf(0.6)
			s = _add(s, _click(0.02, 3200.0, 1.5), 0.0, 0.8)
			s = _add(s, _click(0.02, 2400.0, 1.5), 0.035, 0.6)
			s = _add(s, _metal(2349.3, 0.45, [1.0, 2.71, 5.1], [1.0, 0.4, 0.2], [9.0, 14.0, 22.0], 0.2), 0.035, 0.55)
			s = _add(s, _metal(293.66, 0.55, [1.0, 2.0, 3.0], [1.0, 0.3, 0.12], [5.0, 8.0, 12.0], 0.0), 0.0, 0.6)
			out.append(_wav(_norm(_sat(s, 1.2), 0.8)))
		"tech_return":
			# retour : souffle aller-retour, deux notes qui reviennent
			var s := _buf(0.65)
			s = _add(s, _swish(0.18, 700.0, 2400.0, 3.0), 0.0, 0.35)
			s = _add(s, _metal(783.99, 0.5, [1.0, 2.0, 2.76], [1.0, 0.4, 0.2], [6.0, 9.0, 13.0], 0.3), 0.04, 0.6)
			s = _add(s, _metal(1174.66, 0.45, [1.0, 2.0, 2.76], [1.0, 0.4, 0.2], [7.0, 10.0, 14.0], 0.3), 0.13, 0.5)
			out.append(_wav(_norm(_room(s, 0.2), 0.8)))
		"tech_enso":
			# ensō : bol chantant grave (rin) et bouffée d'encre
			var s := _buf(1.1)
			s = _add(s, _metal(146.83, 1.1, [1.0, 1.003, 2.71, 5.18], [1.0, 0.8, 0.5, 0.2], [2.4, 2.6, 4.0, 7.0], 0.4), 0.0, 0.8)
			s = _add(s, _metal(220.0, 1.0, [1.0, 2.71], [1.0, 0.4], [3.0, 5.0], 0.2), 0.0, 0.4)
			s = _add(s, _metal(293.66, 1.0, [1.0, 2.71], [1.0, 0.4], [3.5, 6.0], 0.2), 0.0, 0.35)
			s = _add(s, _puff(), 0.0, 0.5)
			out.append(_wav(_norm(_room(s, 0.2), 0.85)))
		"tech_hook":
			# crochet : estoc puis deux notes qui redescendent
			var s := _buf(0.5)
			s = _add(s, _stab(), 0.0, 0.6)
			s = _add(s, _metal(1174.66, 0.35, [1.0, 2.0, 2.76], [1.0, 0.4, 0.2], [9.0, 13.0, 18.0], 0.3), 0.02, 0.6)
			s = _add(s, _metal(880.0, 0.35, [1.0, 2.0, 2.76], [1.0, 0.4, 0.2], [9.0, 13.0, 18.0], 0.3), 0.08, 0.5)
			out.append(_wav(_norm(s, 0.8)))
		"torii":
			# torii : carillon de trois clochettes (accord yo), un peu d'espace
			var s := _buf(1.2)
			var nn := [587.33, 880.0, 1174.66]
			for k in 3:
				s = _add(s, _metal(float(nn[k]), 1.0, [1.0, 2.0, 2.76, 5.4], [1.0, 0.45, 0.3, 0.1], [3.2, 5.0, 7.0, 11.0], 0.35), 0.09 * k, 0.6)
			out.append(_wav(_norm(_sat(_room(s, 0.3), 1.15), 0.8)))
		"levelup":
			# montée : quatre notes de koto (Karplus-Strong) en sararin, chatoiement de clochettes
			var s := _buf(1.0)
			var nn := [659.26, 783.99, 987.77, 1318.5]
			for k in 4:
				s = _add(s, _pluck(float(nn[k]), 0.8), 0.07 * k, 0.55 + 0.1 * k)
			s = _add(s, _metal(2637.0, 0.6, [1.0, 2.32, 4.1], [1.0, 0.5, 0.25], [7.0, 10.0, 14.0], 0.3), 0.28, 0.25)
			out.append(_wav(_norm(_sat(_room(s, 0.25), 1.6), 0.8)))
		"shrine":
			# cloche de temple : fondamentale et sa jumelle (battement), partiel grave, coup de maillet
			var s := _buf(1.6)
			s = _add(s, _metal(196.0, 1.6, [1.0, 1.0066, 2.0, 2.74, 0.5], [1.0, 0.8, 0.5, 0.25, 0.35], [2.0, 2.1, 3.0, 5.0, 2.2], 0.4), 0.0, 1.0)
			s = _add(s, _thump(150.0, 90.0, 0.12, 30.0), 0.0, 0.35)
			out.append(_wav(_norm(_room(s, 0.2), 0.8)))
		"pact":
			out.append(_wav(_pact()))
		"reel_tick":
			for k in 3:
				out.append(_wav(_reel_tick(1.0 + 0.05 * (k - 1))))
		"reel_rare":
			out.append(_wav(_reel_rare()))
		"reel_legend":
			out.append(_wav(_reel_legend()))
	return out


# ------------------------------------------------------------------ outils

func _buf(dur: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(maxi(1, int(dur * RATE)))
	s.fill(0.0)
	return s


func _add(dst: PackedFloat32Array, src: PackedFloat32Array, at: float, gain: float) -> PackedFloat32Array:
	var o := int(at * RATE)
	var n := mini(src.size(), dst.size() - o)
	for i in n:
		dst[o + i] += src[i] * gain
	return dst


func _norm(s: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0
	for i in s.size():
		m = maxf(m, absf(s[i]))
	if m > 0.0001:
		var g := peak / m
		for i in s.size():
			s[i] *= g
	return s


## Saturation douce (tanh) : plus de corps et d'attaque sur les impacts.
func _sat(s: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	var k := 1.0 / tanh(drive)
	for i in s.size():
		s[i] = tanh(s[i] * drive) * k
	return s


func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	# fin en fondu (pas de clic si le son est coupé net à la fin du tampon)
	var n := s.size()
	var f := mini(n / 4, int(0.012 * RATE))
	for k in f:
		s[n - 1 - k] *= float(k) / float(f)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Bruit filtré par un filtre d'état (forme TPT : stable à toute fréquence), fréquence de coupure qui va de f0 à f1
## (courbe u^curve), résonance q ; mode 0 passe-bande, 1 passe-bas, 2 passe-haut. Enveloppe env(u) : sin^pw.
func _noise(dur: float, f0: float, f1: float, q: float, mode: int, curve: float, pw: float, att: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var n := s.size()
	var ic1 := 0.0
	var ic2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var a3 := 0.0
	var k := 1.0 / q
	var env := 0.0
	for i in n:
		if (i & 15) == 0:
			var u := float(i) / n
			var fc := minf(f0 + (f1 - f0) * pow(u, curve), RATE * 0.45)
			var g := tan(PI * fc / RATE)
			a1 = 1.0 / (1.0 + g * (g + k))
			a2 = g * a1
			a3 = g * a2
			var t := float(i) / RATE
			env = minf(1.0, t / maxf(att, 0.0005)) * pow(maxf(0.0, 1.0 - u), pw)
		var v0 := randf_range(-1.0, 1.0)
		var v3 := v0 - ic2
		var v1 := a1 * ic1 + a2 * v3
		var v2 := ic2 + a2 * ic1 + a3 * v3
		ic1 = 2.0 * v1 - ic1
		ic2 = 2.0 * v2 - ic2
		var y := v1
		if mode == 1:
			y = v2
		elif mode == 2:
			y = v0 - k * v1 - v2
		s[i] = y * env
	return s


## Ton qui glisse de f0 à f1 (exponentiel), amorti (decay /s), quelques harmoniques.
func _tone(dur: float, f0: float, f1: float, decay: float, h2: float, h3: float, att: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var n := s.size()
	var ph := 0.0
	var r := log(f1 / f0)
	for i in n:
		var u := float(i) / n
		var t := float(i) / RATE
		ph += TAU * f0 * exp(r * u) / RATE
		var v := sin(ph) + h2 * sin(2.0 * ph) + h3 * sin(3.0 * ph)
		s[i] = v * exp(-decay * t) * minf(1.0, t / maxf(att, 0.0003))
	return s


## Coup sourd (corps) : sinus qui chute de f0 à f1, amorti.
func _thump(f0: float, f1: float, dur: float, decay: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := f1 + (f0 - f1) * exp(-t * 25.0)
		ph += TAU * f / RATE
		s[i] = sin(ph) * exp(-t * decay) * minf(1.0, float(i) / 12.0)
	return s


## Claquement bref (bois, mécanique) : impulsion de bruit + résonance à f, amortie très vite.
func _click(dur: float, f: float, bright: float) -> PackedFloat32Array:
	var s := _noise(dur, f, f * 0.8, 3.0, 0, 1.0, 6.0, 0.0003)
	var prev := 0.0
	for i in mini(s.size(), int(0.0025 * RATE)):
		var w := randf_range(-1.0, 1.0)
		s[i] += (w - prev) * bright * (1.0 - float(i) / (0.0025 * RATE))
		prev = w
	return s


## Métal (cloches, clochettes, lames) : partiels inharmoniques amortis (oscillateurs récurrents), coup de frappe.
func _metal(freq: float, dur: float, ratios: Array, amps: Array, decays: Array, strike: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var n := s.size()
	for p in ratios.size():
		var f: float = freq * float(ratios[p])
		if f >= RATE * 0.45:
			continue
		var w := TAU * f / RATE
		var kk := 2.0 * cos(w)
		var y1 := 0.0
		var y2 := -sin(w)
		var a: float = amps[p]
		var g := exp(-float(decays[p]) / RATE)
		for i in n:
			var y := kk * y1 - y2
			y2 = y1
			y1 = y
			s[i] += y * a
			a *= g
	if strike > 0.0:
		var prev := 0.0
		var tn := mini(n, int(0.004 * RATE))
		for i in tn:
			var w2 := randf_range(-1.0, 1.0)
			s[i] += (w2 - prev) * strike * (1.0 - float(i) / tn)
			prev = w2
	for i in mini(n, 4):
		s[i] *= float(i) / 4.0
	return s


## Corde pincée (Karplus-Strong) : koto des fanfares.
func _pluck(freq: float, dur: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var period := maxi(2, int(round(RATE / freq)))
	var dl := PackedFloat32Array()
	dl.resize(period)
	var lp := 0.0
	for k in period:
		lp += 0.6 * (randf_range(-1.0, 1.0) - lp)
		dl[k] = lp
	var idx := 0
	var prev := 0.0
	var g := pow(0.001, 1.0 / (freq * 1.2))
	for i in s.size():
		var x: float = dl[idx]
		var y := (x * 0.6 + prev * 0.4) * g
		prev = x
		dl[idx] = y
		idx = (idx + 1) % period
		s[i] = x
	return s


## Petite pièce (trois peignes, un passe-tout) : un peu d'espace autour des cloches. mix : part de réverbération.
func _room(s: PackedFloat32Array, mix: float) -> PackedFloat32Array:
	var n := s.size()
	var d := [int(0.0297 * RATE), int(0.0371 * RATE), int(0.0411 * RATE)]
	var bufs: Array = []
	for k in 3:
		var b := PackedFloat32Array()
		b.resize(int(d[k]))
		b.fill(0.0)
		bufs.append(b)
	var b0: PackedFloat32Array = bufs[0]
	var b1: PackedFloat32Array = bufs[1]
	var b2: PackedFloat32Array = bufs[2]
	var i0 := 0
	var i1 := 0
	var i2 := 0
	var ap := PackedFloat32Array()
	ap.resize(int(0.005 * RATE))
	ap.fill(0.0)
	var ia := 0
	var out := _buf(float(n) / RATE)
	for i in n:
		var x: float = s[i]
		var o0: float = b0[i0]
		b0[i0] = x + o0 * 0.72
		i0 = (i0 + 1) % b0.size()
		var o1: float = b1[i1]
		b1[i1] = x + o1 * 0.7
		i1 = (i1 + 1) % b1.size()
		var o2: float = b2[i2]
		b2[i2] = x + o2 * 0.68
		i2 = (i2 + 1) % b2.size()
		var c := (o0 + o1 + o2) * 0.3
		var a: float = ap[ia]
		ap[ia] = c + a * 0.5
		ia = (ia + 1) % ap.size()
		out[i] = x + (a - c) * mix
	return out


## Gouttes : petits « plic » qui descendent, semés entre t0 et t1.
func _drops(s: PackedFloat32Array, n: int, t0: float, t1: float, gain: float) -> PackedFloat32Array:
	for k in n:
		var at := randf_range(t0, t1)
		var f := randf_range(900.0, 1800.0)
		s = _add(s, _tone(0.04, f, f * 0.55, 90.0, 0.0, 0.0, 0.001), at, gain * randf_range(0.6, 1.0))
	return s


# ------------------------------------------------------------------ sons

## Coupe : le pinceau-lame fend l'air (souffle aigu), « shing » métallique, impact d'encre (corps sourd).
func _slash(p: float) -> PackedFloat32Array:
	var s := _buf(0.3)
	s = _add(s, _noise(0.09, 1800.0 * p, 5200.0 * p, 1.4, 0, 0.6, 1.2, 0.004), 0.0, 0.7)
	s = _add(s, _metal(2600.0 * p * randf_range(0.95, 1.05), 0.22, [1.0, 1.51, 2.27, 3.03], [0.6, 0.4, 0.25, 0.12], [16.0, 20.0, 26.0, 32.0], 0.6), 0.012, 0.55)
	s = _add(s, _thump(210.0 * p, 95.0, 0.12, 30.0), 0.01, 0.55)
	s = _add(s, _noise(0.06, 900.0, 400.0, 0.8, 1, 1.0, 2.0, 0.001), 0.01, 0.5)
	return _norm(_sat(s, 1.6), 0.85)


## Mise à mort : coupe plus lourde, coup sourd profond, éclaboussure d'encre et gouttes.
func _kill(p: float) -> PackedFloat32Array:
	var s := _buf(0.5)
	s = _add(s, _slash(1.08 * p), 0.0, 0.8)
	s = _add(s, _thump(160.0 * p, 48.0, 0.3, 14.0), 0.015, 0.9)
	s = _add(s, _noise(0.22, 2200.0, 500.0, 0.9, 1, 0.5, 2.2, 0.002), 0.03, 0.55)
	s = _drops(s, 4, 0.1, 0.32, 0.3)
	return _norm(_sat(s, 1.6), 0.72)


## Mouvement (ruée, transitions) : souffle filtré qui monte puis retombe.
func _whoosh(dur: float, p: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var a := _noise(dur, 350.0 * p, 1900.0 * p, 1.6, 0, 1.0, 0.0, 0.0)
	var b := _noise(dur, 900.0 * p, 3000.0 * p, 1.2, 0, 1.0, 0.0, 0.0)
	var n := s.size()
	for i in n:
		var u := float(i) / n
		var e := pow(sin(PI * pow(u, 0.7)), 1.6)
		s[i] = (a[i] * 1.0 + b[i] * 0.35 * u) * e
	return _norm(s, 0.85)


## Le héros est touché : coup lourd, grincement (seconde mineure qui retombe), souffle.
func _hurt() -> PackedFloat32Array:
	var s := _buf(0.45)
	s = _add(s, _thump(180.0, 55.0, 0.3, 12.0), 0.0, 0.9)
	s = _add(s, _tone(0.32, 330.0, 140.0, 8.0, 0.5, 0.3, 0.003), 0.0, 0.35)
	s = _add(s, _tone(0.32, 350.0, 148.0, 8.0, 0.5, 0.3, 0.003), 0.0, 0.3)
	s = _add(s, _noise(0.12, 2500.0, 600.0, 0.8, 1, 0.5, 2.0, 0.001), 0.0, 0.6)
	return _norm(_sat(s, 2.0), 0.68)


## Impact (coup porté, choc) : coup sourd et sec, peau / bois au médium, claquement.
func _strike(p: float) -> PackedFloat32Array:
	var s := _buf(0.32)
	s = _add(s, _thump(150.0 * p, 52.0, 0.28, 16.0), 0.0, 1.0)
	s = _add(s, _thump(340.0 * p, 260.0, 0.1, 40.0), 0.0, 0.35)
	s = _add(s, _click(0.03, 1800.0 * p, 1.2), 0.0, 0.5)
	s = _add(s, _noise(0.08, 1200.0, 300.0, 0.7, 1, 0.6, 2.5, 0.0008), 0.0, 0.5)
	return _norm(_sat(s, 2.2), 0.9)


## Tir / petite action : « tok » de bois et sifflement bref qui monte.
func _shot() -> PackedFloat32Array:
	var s := _buf(0.2)
	s = _add(s, _click(0.025, 1300.0, 0.8), 0.0, 0.5)
	s = _add(s, _tone(0.17, 520.0 * randf_range(0.97, 1.03), 900.0, 16.0, 0.2, 0.05, 0.002), 0.004, 0.5)
	s = _add(s, _noise(0.1, 1500.0, 3000.0, 1.5, 0, 1.0, 1.5, 0.002), 0.0, 0.2)
	return _norm(s, 0.5)


## Refus (plus d'encre, action impossible) : double « tok » de bois mat, grave.
func _empty() -> PackedFloat32Array:
	var s := _buf(0.13)
	s = _add(s, _click(0.04, 420.0 * randf_range(0.97, 1.03), 0.4), 0.0, 0.7)
	s = _add(s, _click(0.04, 360.0, 0.3), 0.055, 0.5)
	s = _add(s, _thump(200.0, 140.0, 0.06, 60.0), 0.0, 0.25)
	return _norm(s, 0.4)


## Expérience ramassée : tintement de verre bref.
func _xp(f: float) -> PackedFloat32Array:
	var s := _metal(f, 0.11, [1.0, 2.76, 5.4], [1.0, 0.3, 0.1], [45.0, 60.0, 80.0], 0.15)
	s = _add(s, _tone(0.05, f * 1.5, f * 1.6, 70.0, 0.0, 0.0, 0.0005), 0.015, 0.3)
	return _norm(s, 0.5)


## Pièce : « chin-ching » de deux notes claires, petit cliquetis.
func _coin(fs: Array) -> PackedFloat32Array:
	var s := _buf(0.42)
	s = _add(s, _metal(float(fs[0]), 0.3, [1.0, 2.4, 3.9], [1.0, 0.35, 0.15], [18.0, 26.0, 34.0], 0.5), 0.0, 0.7)
	s = _add(s, _metal(float(fs[1]), 0.36, [1.0, 2.4, 3.9], [1.0, 0.35, 0.15], [11.0, 18.0, 26.0], 0.5), 0.055, 0.8)
	s = _add(s, _click(0.015, 5000.0, 0.6), 0.0, 0.2)
	return _norm(s, 0.6)


## Éclair : grésillement à fréquence sautillante, crépitements, claquement d'attaque.
func _zap(dur: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var ph := 0.0
	var f := 800.0
	var hold := 0
	var ck := 0.0
	for i in s.size():
		var t := float(i) / RATE
		hold -= 1
		if hold <= 0:
			hold = randi_range(25, 140)
			f = randf_range(250.0, 2400.0)
		ph += TAU * f / RATE
		var sq := 1.0 if sin(ph) > 0.0 else -1.0
		if randf() < 0.02:
			ck = randf_range(-1.0, 1.0)
		ck *= 0.8
		var env := exp(-t * 10.0) * minf(1.0, t * 2000.0)
		s[i] = (sq * 0.28 + ck * 0.7) * env
	s = _add(s, _click(0.01, 3000.0, 1.0), 0.0, 0.5)
	return _norm(s, 0.9)


## Foudre du ciel : claquement sec, déchirure, puis grondement sourd.
func _thunder() -> PackedFloat32Array:
	var s := _buf(0.9)
	s = _add(s, _noise(0.06, 6000.0, 2000.0, 0.7, 2, 1.0, 1.5, 0.0005), 0.0, 1.0)
	s = _add(s, _noise(0.25, 1800.0, 500.0, 0.8, 0, 0.5, 2.0, 0.002), 0.01, 0.6)
	var r := _noise(0.85, 180.0, 60.0, 0.7, 1, 0.5, 1.3, 0.03)
	s = _add(s, r, 0.02, 4.0)
	s = _add(s, _thump(90.0, 40.0, 0.6, 5.0), 0.02, 0.5)
	return _norm(_sat(s, 1.8), 0.66)


## Feu : souffle qui s'ouvre et se referme, crépitements de braises.
func _fire(dur: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var a := _noise(dur, 300.0, 1400.0, 0.8, 1, 0.5, 0.0, 0.0)
	var n := s.size()
	for i in n:
		var u := float(i) / n
		s[i] = a[i] * pow(sin(PI * u), 0.6) * 1.5
	for k in randi_range(5, 9):
		s = _add(s, _click(0.012, randf_range(1500.0, 4000.0), 1.0), randf_range(0.02, dur - 0.05), randf_range(0.15, 0.4))
	return _norm(s, 0.8)


func _crackle() -> PackedFloat32Array:
	var dur := 0.34
	var s := _noise(dur, 400.0, 300.0, 0.7, 1, 1.0, 0.8, 0.02)
	for i in s.size():
		s[i] *= 0.6
	for k in randi_range(7, 12):
		s = _add(s, _click(0.01, randf_range(1200.0, 4500.0), 1.2), randf_range(0.0, dur - 0.03), randf_range(0.2, 0.6))
	return _norm(_sat(s, 1.5), 0.75)


## Eau : gerbe filtrée qui descend, bulles qui montent.
func _splash() -> PackedFloat32Array:
	var s := _buf(0.42)
	s = _add(s, _noise(0.38, 2800.0, 500.0, 1.0, 0, 0.5, 2.2, 0.003), 0.0, 1.0)
	s = _add(s, _thump(120.0, 70.0, 0.12, 25.0), 0.0, 0.25)
	for k in 5:
		var f := randf_range(500.0, 1300.0)
		s = _add(s, _tone(0.05, f, f * 1.7, 40.0, 0.0, 0.0, 0.004), randf_range(0.04, 0.3), 0.25)
	return _norm(s, 0.8)


## Vent tranchant : bruit dans un filtre résonant qui balaie.
func _swish(dur: float, f_lo: float, f_hi: float, q: float) -> PackedFloat32Array:
	var s := _noise(dur, f_lo, f_hi, q, 0, 1.0, 0.0, 0.0)
	var n := s.size()
	for i in n:
		var u := float(i) / n
		s[i] *= pow(sin(PI * u), 1.5)
	return s


func _gust() -> PackedFloat32Array:
	var s := _swish(0.48, 350.0, 1600.0, 2.0)
	var n := s.size()
	for i in n:
		var t := float(i) / RATE
		s[i] *= 0.75 + 0.25 * sin(TAU * 13.0 * t)
	return _norm(s, 0.75)


## Ombre : bouffée sourde et feutrée.
func _puff() -> PackedFloat32Array:
	var s := _buf(0.28)
	s = _add(s, _noise(0.26, 900.0, 250.0, 0.7, 1, 0.5, 1.8, 0.012), 0.0, 1.0)
	s = _add(s, _thump(130.0, 60.0, 0.2, 14.0), 0.0, 0.3)
	return _norm(s, 0.6)


## Estoc d'ombre : souffle qui plonge puis coup sourd.
func _stab() -> PackedFloat32Array:
	var s := _buf(0.28)
	s = _add(s, _noise(0.12, 3000.0, 450.0, 1.2, 0, 0.6, 1.0, 0.002), 0.0, 0.9)
	s = _add(s, _thump(150.0, 55.0, 0.2, 18.0), 0.04, 0.8)
	s = _add(s, _click(0.02, 900.0, 0.5), 0.04, 0.3)
	return _norm(_sat(s, 1.6), 0.72)


## Encre : claque humide et gouttes.
func _ink() -> PackedFloat32Array:
	var s := _buf(0.32)
	s = _add(s, _noise(0.08, 1600.0, 400.0, 0.8, 1, 0.5, 2.0, 0.001), 0.0, 1.3)
	s = _add(s, _thump(170.0, 80.0, 0.08, 40.0), 0.0, 0.3)
	s = _drops(s, 4, 0.05, 0.24, 0.45)
	return _norm(s, 0.75)


## Iaï : la lame sort du fourreau (frottement qui monte), long « shing » métallique qui résonne.
func _iai() -> PackedFloat32Array:
	var s := _buf(0.8)
	s = _add(s, _noise(0.12, 2500.0, 7000.0, 2.0, 0, 1.0, 0.3, 0.06), 0.0, 0.4)
	s = _add(s, _metal(3150.0, 0.7, [1.0, 1.52, 0.70, 2.31], [0.5, 0.3, 0.25, 0.15], [5.0, 6.5, 7.0, 9.0], 0.8), 0.1, 0.7)
	s = _add(s, _click(0.02, 3500.0, 1.0), 0.1, 0.4)
	return _norm(_room(s, 0.2), 0.85)


## Pacte : bourdon grave et dissonant (secondes mineures qui battent), souffle sombre, coup de taiko lointain.
func _pact() -> PackedFloat32Array:
	var dur := 0.9
	var s := _buf(dur)
	var n := s.size()
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / dur
		lp += 0.03 * (randf_range(-1.0, 1.0) - lp)
		var drone := sin(TAU * 73.4 * t) + sin(TAU * 77.8 * t) * 0.8 + sin(TAU * 146.8 * t) * 0.5 + sin(TAU * 155.6 * t) * 0.4 + sin(TAU * 220.2 * t) * 0.2
		s[i] = (drone * 0.4 + lp * 3.0) * minf(1.0, t * 8.0) * (1.0 - u) * (1.0 - u)
	s = _add(s, _thump(110.0, 45.0, 0.5, 8.0), 0.0, 0.6)
	return _norm(_sat(s, 1.5), 0.8)


## Rouleau qui s'arrête : cliquet mécanique (deux claquements, la came puis le butoir), coup sourd du tambour.
func _reel_tick(p: float) -> PackedFloat32Array:
	var s := _buf(0.14)
	s = _add(s, _click(0.02, 2300.0 * p, 1.4), 0.0, 0.7)
	s = _add(s, _click(0.025, 1500.0 * p, 1.0), 0.016, 0.9)
	s = _add(s, _thump(160.0 * p, 95.0, 0.1, 45.0), 0.016, 0.6)
	s = _add(s, _noise(0.03, 3500.0, 2000.0, 1.0, 0, 1.0, 2.0, 0.0005), 0.0, 0.25)
	return _norm(_sat(s, 1.5), 0.65)


## Tirage rare : claquement, deux notes claires qui montent (mi - si), étincelles.
func _reel_rare() -> PackedFloat32Array:
	var s := _buf(0.75)
	s = _add(s, _reel_tick(1.05), 0.0, 0.7)
	s = _add(s, _metal(1318.5, 0.6, [1.0, 2.0, 2.76, 5.4], [1.0, 0.4, 0.3, 0.1], [5.0, 7.0, 10.0, 16.0], 0.4), 0.03, 0.55)
	s = _add(s, _metal(1975.5, 0.55, [1.0, 2.0, 2.76], [1.0, 0.4, 0.2], [6.0, 8.0, 12.0], 0.4), 0.11, 0.5)
	for k in 4:
		s = _add(s, _metal(randf_range(3200.0, 4800.0), 0.12, [1.0, 2.3], [1.0, 0.3], [28.0, 40.0], 0.2), 0.14 + 0.05 * k, 0.12)
	return _norm(_room(s, 0.25), 0.75)


## Tirage légendaire : claquement lourd, coup d'ōdaiko, gong, cascade dorée de clochettes (accord yo qui monte).
func _reel_legend() -> PackedFloat32Array:
	var s := _buf(1.4)
	s = _add(s, _reel_tick(0.9), 0.0, 0.8)
	s = _add(s, _thump(120.0, 50.0, 0.6, 7.0), 0.01, 0.9)
	s = _add(s, _noise(0.08, 1500.0, 400.0, 0.7, 1, 0.5, 2.0, 0.001), 0.01, 0.5)
	s = _add(s, _metal(220.0, 1.3, [1.0, 1.006, 2.0, 2.76, 3.9], [1.0, 0.8, 0.5, 0.3, 0.15], [2.2, 2.3, 3.5, 5.0, 8.0], 0.5), 0.02, 0.55)
	var nn := [880.0, 1174.66, 1318.5, 1760.0, 2349.3, 2637.0]
	for k in nn.size():
		s = _add(s, _metal(float(nn[k]), 0.7, [1.0, 2.0, 2.76], [1.0, 0.35, 0.2], [5.0, 8.0, 12.0], 0.3), 0.12 + 0.06 * k, 0.3)
	return _norm(_room(_sat(s, 1.3), 0.3), 0.85)
