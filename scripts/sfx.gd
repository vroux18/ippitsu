extends Node
## Sons synthétisés (pas de fichiers audio) et vibrations courtes (Android / iOS / web Android).
## Plusieurs variantes par son et une légère variation de hauteur : les coups répétés ne « mitraillent » pas.
## Les sons de base sont créés au démarrage, les autres un par image ensuite (pas d'à-coup).

const RATE := 22050
const PLAYERS := 16
const MIN_GAP_MS := 30  # même son relancé plus vite : ignoré
const BUZZ_GAP_MS := 40  # vibrations : une impulsion toutes les 40 ms au plus
const CORE := ["slash", "kill", "whoosh", "hurt", "strike", "shot", "empty"]
const LATER := ["xp", "coin", "zap", "thunder", "fire", "crackle", "splash", "swish", "gust", "puff", "stab", "ink", "iai",
	"tech_loop", "tech_zigzag", "tech_straight", "tech_return", "tech_enso", "tech_hook",
	"torii", "levelup", "shrine", "pact"]
# sons mélodiques : hauteur exacte, sans variation aléatoire
const TUNED := ["tech_loop", "tech_zigzag", "tech_straight", "tech_return", "tech_enso", "tech_hook",
	"torii", "levelup", "shrine", "pact", "coin"]
# motifs de vibration : [délai ms, durée ms, force 0..1]
const HAPTIC := {
	"dash": [[0, 6, 0.2]],
	"hit": [[0, 10, 0.35]],
	"clang": [[0, 14, 0.5]],
	"kill": [[0, 22, 0.6]],
	"multi": [[0, 30, 0.8]],
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
var _next := 0
var _last := {}  # id -> dernier départ (ms)
var _todo: Array = []
var _native_vib := false
var _web_vib := false
var _buzz_ms := -1000
var _buzz_len := 0


func _ready() -> void:
	for i in PLAYERS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for id in CORE:
		_streams[String(id)] = _build(String(id))
	_todo = LATER.duplicate()
	if DisplayServer.get_name() != "headless":
		_native_vib = OS.has_feature("android") or OS.has_feature("ios")
		if OS.has_feature("web_android"):
			_web_vib = bool(JavaScriptBridge.eval("typeof navigator.vibrate === 'function'", true))


func _process(_delta: float) -> void:
	if _todo.is_empty():
		set_process(false)
		return
	var id := String(_todo.pop_front())
	if not _streams.has(id):
		_streams[id] = _build(id)


## Joue le son `id` (variante au hasard). Noms : voir CORE et LATER.
func play(id: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _streams.has(id):
		if not id in LATER:
			return
		_streams[id] = _build(id)  # demandé avant son tour : créé tout de suite
		_todo.erase(id)
	var now := Time.get_ticks_msec()
	if now - int(_last.get(id, -1000)) < MIN_GAP_MS:
		return
	_last[id] = now
	var vars: Array = _streams[id]
	if vars.is_empty():
		return
	var p := _free_player()
	p.stream = vars[randi() % vars.size()]
	p.pitch_scale = maxf(0.05, pitch if id in TUNED else pitch * randf_range(0.96, 1.04))
	p.volume_db = volume_db
	p.play()


func _free_player() -> AudioStreamPlayer:
	var n := _players.size()
	for k in n:
		var p := _players[(_next + k) % n]
		if not p.playing:
			_next = (_next + k + 1) % n
			return p
	var q := _players[_next]
	_next = (_next + 1) % n
	return q


# ------------------------------------------------------------------ vibrations

func _can_buzz() -> bool:
	return haptics and (_native_vib or _web_vib)


## Motif de vibration nommé (voir HAPTIC). Sans effet hors mobile, sans vibreur ou si l'option est coupée.
func haptic(kind: String) -> void:
	if not _can_buzz() or not HAPTIC.has(kind):
		return
	var steps: Array = HAPTIC[kind]
	for st in steps:
		var a: Array = st
		var delay := float(a[0]) / 1000.0
		if delay <= 0.0:
			buzz(int(a[1]), float(a[2]))
		else:
			get_tree().create_timer(delay, true, false, true).timeout.connect(buzz.bind(int(a[1]), float(a[2])))


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


# ------------------------------------------------------------------ fabrication

func _build(id: String) -> Array:
	var out: Array = []
	match id:
		"slash":
			for k in 3:
				out.append(_wav(_slash_raw(0.22, 2600.0 * randf_range(0.88, 1.12))))
		"kill":
			for k in 3:
				out.append(_wav(_kill_raw(1700.0 * randf_range(0.88, 1.12))))
		"whoosh":
			out.append(_wav(_whoosh_raw(0.3)))
			out.append(_wav(_whoosh_raw(0.26)))
		"hurt":
			out.append(_wav(_hurt_raw()))
		"strike":
			out.append(_wav(_thud_raw()))
			out.append(_wav(_thud_raw()))
		"shot":
			out.append(_wav(_blip_raw()))
		"empty":
			out.append(_wav(_click_raw()))
		"xp":
			for k in 3:
				out.append(_wav(_tick_raw(1700.0 + 250.0 * k)))
		"coin":
			out.append(_wav(_bell([1975.5, 2637.0], 0.045, 0.2, 22.0, 0.6, 0.6)))
			out.append(_wav(_bell([2093.0, 2793.8], 0.045, 0.2, 22.0, 0.6, 0.6)))
		"zap":
			for k in 3:
				out.append(_wav(_zap_raw(0.16)))
		"thunder":
			out.append(_wav(_thunder_raw()))
			out.append(_wav(_thunder_raw()))
		"fire":
			out.append(_wav(_fire_raw(0.42)))
			out.append(_wav(_fire_raw(0.36)))
		"crackle":
			out.append(_wav(_crackle_raw()))
			out.append(_wav(_crackle_raw()))
		"splash":
			out.append(_wav(_splash_raw()))
			out.append(_wav(_splash_raw()))
		"swish":
			for k in 3:
				out.append(_wav(_swish_raw(0.17, 700.0, 2400.0 - 200.0 * k, 0.5)))
		"gust":
			out.append(_wav(_gust_raw()))
		"puff":
			out.append(_wav(_puff_raw()))
			out.append(_wav(_puff_raw()))
		"stab":
			out.append(_wav(_stab_raw()))
			out.append(_wav(_stab_raw()))
		"ink":
			out.append(_wav(_ink_raw()))
			out.append(_wav(_ink_raw()))
		"iai":
			out.append(_wav(_iai_raw()))
		"tech_loop":
			var s := _buf(0.6)
			s = _add(s, _gust_raw(), 0.0, 0.8)
			s = _add(s, _bell([880.0, 1174.66], 0.1, 0.45, 7.0, 0.6, 1.0), 0.12, 0.5)
			out.append(_wav(_norm(s, 0.85)))
		"tech_zigzag":
			var s := _buf(0.45)
			for k in 3:
				s = _add(s, _zap_raw(0.1), 0.06 * k, 0.7)
			s = _add(s, _bell([1318.5, 1760.0], 0.05, 0.3, 9.0, 0.8, 1.0), 0.15, 0.45)
			out.append(_wav(_norm(s, 0.85)))
		"tech_straight":
			# « kachin » : la lame rengainée, tintement clair sur une note grave
			var s := _buf(0.5)
			s = _add(s, _tick_raw(3000.0), 0.0, 0.8)
			s = _add(s, _bell([2349.3], 0.0, 0.4, 10.0, 1.0, 1.0), 0.02, 0.6)
			s = _add(s, _bell([293.66], 0.0, 0.5, 5.0, 0.3, 1.0), 0.0, 0.4)
			out.append(_wav(_norm(s, 0.8)))
		"tech_return":
			var s := _buf(0.55)
			s = _add(s, _swish_raw(0.17, 700.0, 2200.0, 0.5), 0.0, 0.4)
			s = _add(s, _bell([783.99, 1174.66], 0.08, 0.5, 7.0, 0.8, 1.0), 0.03, 0.8)
			out.append(_wav(_norm(s, 0.8)))
		"tech_enso":
			var s := _buf(0.9)
			s = _add(s, _bell([146.83, 220.0, 293.66], 0.0, 0.9, 3.2, 0.7, 1.0), 0.0, 0.8)
			s = _add(s, _puff_raw(), 0.0, 0.5)
			out.append(_wav(_norm(s, 0.85)))
		"tech_hook":
			var s := _buf(0.4)
			s = _add(s, _stab_raw(), 0.0, 0.6)
			s = _add(s, _bell([1174.66, 880.0], 0.06, 0.35, 10.0, 0.8, 1.0), 0.02, 0.7)
			out.append(_wav(_norm(s, 0.8)))
		"torii":
			out.append(_wav(_bell([587.33, 880.0, 1174.66], 0.1, 1.0, 3.5, 0.7, 0.8)))
		"levelup":
			out.append(_wav(_bell([659.26, 783.99, 987.77, 1318.5], 0.07, 0.8, 4.5, 0.8, 0.8)))
		"shrine":
			# cloche de temple : fondamentale et sa jumelle un peu désaccordée (battement)
			out.append(_wav(_bell([196.0, 197.3, 392.0], 0.0, 1.2, 2.0, 0.9, 0.8)))
		"pact":
			out.append(_wav(_pact_raw()))
	return out


func _buf(dur: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	return s


func _add(dst: PackedFloat32Array, src: PackedFloat32Array, at: float, gain: float) -> PackedFloat32Array:
	var o := int(at * RATE)
	for i in src.size():
		var j := o + i
		if j >= dst.size():
			break
		dst[j] += src[i] * gain
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


func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Gouttes : petits « plic » qui descendent, semés entre t0 et t1.
func _drops(s: PackedFloat32Array, n: int, t0: float, t1: float, gain: float) -> PackedFloat32Array:
	var n_s := int(0.03 * RATE)
	for k in n:
		var at := int(randf_range(t0, t1) * RATE)
		var f := randf_range(900.0, 1700.0)
		var ph := 0.0
		for j in n_s:
			var i := at + j
			if i >= s.size():
				break
			var t := float(j) / RATE
			ph += TAU * f * (1.0 - t * 12.0) / RATE
			s[i] += sin(ph) * exp(-t * 110.0) * gain
	return s


## Cloche (partiels inharmoniques), une note après l'autre tous les `gap` s.
func _bell(notes: Array, gap: float, dur: float, decay: float, bright: float, peak: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var d1 := exp(-decay / RATE)
	var d2 := exp(-decay * 2.0 / RATE)
	var d3 := exp(-decay * 3.0 / RATE)
	var d5 := exp(-decay * 5.0 / RATE)
	for ni in notes.size():
		var f0 := float(notes[ni])
		var start := int(ni * gap * RATE)
		var e1 := 1.0
		var e2 := 1.0
		var e3 := 1.0
		var e5 := 1.0
		for i in range(start, s.size()):
			var t := float(i - start) / RATE
			var w := TAU * f0 * t
			var v := sin(w) * e1 + bright * 0.5 * sin(w * 2.0) * e2 + bright * 0.3 * sin(w * 2.76) * e3 + 0.15 * sin(w * 5.4) * e5
			s[i] += v * minf(1.0, t * 800.0)
			e1 *= d1
			e2 *= d2
			e3 *= d3
			e5 *= d5
	return _norm(s, peak)


## « Shing » : bruit très bref et aigu + sifflement métallique qui descend.
func _slash_raw(dur: float, f0: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var ph := 0.0
	var ph2 := 0.0
	var prev := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var env := exp(-t * 18.0)
		var noise := randf_range(-1.0, 1.0)
		var hp := noise - prev
		prev = noise
		var f := f0 * (1.0 - 0.45 * t / dur)
		ph += TAU * f / RATE
		ph2 += TAU * f * 1.51 / RATE
		var ring := (sin(ph) * 0.5 + sin(ph2) * 0.3) * exp(-t * 9.0)
		var attack := minf(1.0, t * 900.0)
		s[i] = attack * (hp * 0.55 * env + ring * 0.5)
	return s


## Mise à mort : « shing » + coup sourd + éclaboussure d'encre (trois couches).
func _kill_raw(f0: float) -> PackedFloat32Array:
	var s := _slash_raw(0.34, f0)
	var ph := 0.0
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		ph += TAU * lerpf(170.0, 45.0, minf(1.0, t / 0.2)) / RATE
		var thump := sin(ph) * exp(-t * 16.0) * minf(1.0, t * 400.0)
		lp += 0.18 * (randf_range(-1.0, 1.0) - lp)
		var wet := 0.0
		if t > 0.025:
			wet = lp * exp(-(t - 0.025) * 22.0) * 1.8
		s[i] += thump * 0.75 + wet
	s = _drops(s, 3, 0.09, 0.26, 0.35)
	return _norm(s, 0.95)


func _whoosh_raw(dur: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var k := t / dur
		var env := sin(PI * k) * (1.0 - k * 0.4)
		var a := 0.05 + 0.25 * sin(PI * k)
		lp += a * (randf_range(-1.0, 1.0) - lp)
		s[i] = lp * env * 1.6
	return s


func _hurt_raw() -> PackedFloat32Array:
	var dur := 0.35
	var s := _buf(dur)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := lerpf(260.0, 70.0, t / dur)
		ph += TAU * f / RATE
		var sq := 1.0 if sin(ph) > 0.0 else -1.0
		s[i] = (sq * 0.35 + randf_range(-0.3, 0.3) * exp(-t * 20.0)) * exp(-t * 7.0)
	return s


func _thud_raw() -> PackedFloat32Array:
	var dur := 0.25
	var s := _buf(dur)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		ph += TAU * lerpf(120.0, 45.0, t / dur) / RATE
		s[i] = (sin(ph) * 0.9 + randf_range(-0.4, 0.4) * exp(-t * 40.0)) * exp(-t * 12.0)
	return s


func _blip_raw() -> PackedFloat32Array:
	var dur := 0.18
	var s := _buf(dur)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		ph += TAU * lerpf(500.0, 900.0, t / dur) / RATE
		s[i] = sin(ph) * 0.35 * exp(-t * 14.0)
	return s


func _click_raw() -> PackedFloat32Array:
	var s := _buf(0.05)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = randf_range(-1.0, 1.0) * 0.3 * exp(-t * 90.0)
	return s


## Petit tic aigu (expérience ramassée, lame rengainée).
func _tick_raw(f0: float) -> PackedFloat32Array:
	var s := _buf(0.06)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		ph += TAU * f0 * (1.0 + t * 6.0) / RATE
		s[i] = sin(ph) * exp(-t * 70.0) * minf(1.0, t * 3000.0)
	return _norm(s, 0.5)


## Éclair : grésillement carré à fréquence sautillante + crépitements.
func _zap_raw(dur: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var ph := 0.0
	var f := 800.0
	var hold := 0
	var click := 0.0
	for i in s.size():
		var t := float(i) / RATE
		hold -= 1
		if hold <= 0:
			hold = randi_range(30, 160)
			f = randf_range(250.0, 2200.0)
		ph += TAU * f / RATE
		var sq := 1.0 if sin(ph) > 0.0 else -1.0
		if randf() < 0.015:
			click = randf_range(-1.0, 1.0)
		click *= 0.8
		var env := exp(-t * 11.0) * minf(1.0, t * 2000.0)
		s[i] = (sq * 0.3 + click * 0.7) * env
	return _norm(s, 0.75)


## Foudre du ciel : claquement sec puis grondement sourd.
func _thunder_raw() -> PackedFloat32Array:
	var s := _buf(0.6)
	var prev := 0.0
	var lp := 0.0
	var lp2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		var crack := (n - prev) * exp(-t * 55.0)
		prev = n
		lp += 0.06 * (n - lp)
		lp2 += 0.06 * (lp - lp2)
		var rumble := lp2 * 9.0 * minf(1.0, t * 40.0) * exp(-t * 4.0)
		s[i] = crack * 0.8 + rumble
	return _norm(s, 0.9)


## Feu : souffle qui s'ouvre et se referme, crépitements de braises.
func _fire_raw(dur: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var lp := 0.0
	var prev := 0.0
	var click := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var k := t / dur
		lp += (0.04 + 0.3 * sin(PI * k)) * (randf_range(-1.0, 1.0) - lp)
		if randf() < 0.004 * k + 0.001:
			click = randf_range(-1.0, 1.0)
		click *= 0.6
		var hp := click - prev
		prev = click
		s[i] = lp * pow(sin(PI * k), 0.6) * 1.4 + hp * 0.5 * (1.0 - k * 0.5)
	return _norm(s, 0.8)


func _crackle_raw() -> PackedFloat32Array:
	var dur := 0.32
	var s := _buf(dur)
	var click := 0.0
	var prev := 0.0
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		if randf() < 0.006:
			click = randf_range(-1.0, 1.0)
		click *= 0.55
		var hp := click - prev
		prev = click
		lp += 0.05 * (randf_range(-1.0, 1.0) - lp)
		s[i] = (hp * 0.8 + lp * 0.8) * sin(PI * t / dur)
	return _norm(s, 0.6)


## Eau : gerbe filtrée qui descend, bulles qui montent.
func _splash_raw() -> PackedFloat32Array:
	var s := _buf(0.38)
	var low := 0.0
	var band := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var fc := lerpf(2400.0, 600.0, minf(1.0, t / 0.25))
		var f := 2.0 * sin(PI * fc / RATE)
		low += f * band
		var high := randf_range(-1.0, 1.0) - low - 0.7 * band
		band += f * high
		s[i] = band * exp(-t * 9.0) * minf(1.0, t * 300.0)
	for k in 4:
		s = _add(s, _bubble(randf_range(500.0, 1300.0)), randf_range(0.04, 0.24), 0.35)
	return _norm(s, 0.8)


func _bubble(f0: float) -> PackedFloat32Array:
	var dur := 0.05
	var s := _buf(dur)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		ph += TAU * f0 * (1.0 + t * 14.0) / RATE
		s[i] = sin(ph) * sin(PI * t / dur)
	return s


## Vent : bruit passé dans un filtre résonant qui balaie (fc ≤ 2500 Hz : filtre stable).
func _swish_raw(dur: float, f_lo: float, f_hi: float, q: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var low := 0.0
	var band := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var k := t / dur
		var fc := lerpf(f_lo, f_hi, sin(PI * k))
		var f := 2.0 * sin(PI * fc / RATE)
		low += f * band
		var high := randf_range(-1.0, 1.0) - low - q * band
		band += f * high
		s[i] = band * pow(sin(PI * k), 1.5)
	return _norm(s, 0.7)


func _gust_raw() -> PackedFloat32Array:
	var s := _swish_raw(0.45, 350.0, 1500.0, 0.6)
	for i in s.size():
		var t := float(i) / RATE
		s[i] *= 0.75 + 0.25 * sin(TAU * 13.0 * t)
	return _norm(s, 0.75)


## Ombre : bouffée sourde et feutrée.
func _puff_raw() -> PackedFloat32Array:
	var dur := 0.24
	var s := _buf(dur)
	var lp := 0.0
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += 0.07 * (randf_range(-1.0, 1.0) - lp)
		ph += TAU * lerpf(120.0, 60.0, t / dur) / RATE
		var env := minf(1.0, t * 70.0) * exp(-t * 13.0)
		s[i] = (lp * 2.5 + sin(ph) * 0.25) * env
	return _norm(s, 0.6)


## Estoc d'ombre : souffle qui plonge puis coup sourd.
func _stab_raw() -> PackedFloat32Array:
	var dur := 0.24
	var s := _buf(dur)
	var low := 0.0
	var band := 0.0
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var fc := lerpf(2400.0, 400.0, minf(1.0, t / 0.12))
		var f := 2.0 * sin(PI * fc / RATE)
		low += f * band
		var high := randf_range(-1.0, 1.0) - low - 0.6 * band
		band += f * high
		var th := 0.0
		if t > 0.04:
			ph += TAU * lerpf(130.0, 55.0, (t - 0.04) / (dur - 0.04)) / RATE
			th = sin(ph) * exp(-(t - 0.04) * 18.0)
		s[i] = band * exp(-t * 15.0) * minf(1.0, t * 500.0) + th * 0.6
	return _norm(s, 0.8)


## Encre : claque humide et gouttes.
func _ink_raw() -> PackedFloat32Array:
	var s := _buf(0.28)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += 0.25 * (randf_range(-1.0, 1.0) - lp)
		s[i] = lp * exp(-t * 28.0) * minf(1.0, t * 800.0) * 1.6
	s = _drops(s, 4, 0.05, 0.22, 0.4)
	return _norm(s, 0.75)


## Iaï : long « shing » métallique qui résonne.
func _iai_raw() -> PackedFloat32Array:
	var s := _buf(0.6)
	var prev := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		var hp := n - prev
		prev = n
		var ring := sin(TAU * 3150.0 * t) * 0.5 + sin(TAU * 4790.0 * t) * 0.3 + sin(TAU * 2210.0 * t) * 0.25
		s[i] = hp * 0.6 * exp(-t * 22.0) + ring * exp(-t * 5.5) * minf(1.0, t * 1500.0) * 0.6
	return _norm(s, 0.85)


## Pacte : bourdon grave et dissonant (secondes mineures qui battent), souffle sombre.
func _pact_raw() -> PackedFloat32Array:
	var dur := 0.8
	var s := _buf(dur)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var k := t / dur
		lp += 0.03 * (randf_range(-1.0, 1.0) - lp)
		var drone := sin(TAU * 73.4 * t) + sin(TAU * 77.8 * t) * 0.8 + sin(TAU * 146.8 * t) * 0.4 + sin(TAU * 155.6 * t) * 0.3
		s[i] = (drone * 0.4 + lp * 3.0) * minf(1.0, t * 8.0) * (1.0 - k) * (1.0 - k)
	return _norm(s, 0.8)
